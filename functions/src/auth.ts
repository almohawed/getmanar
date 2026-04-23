import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// Register New School (Public - For New School Registration)
// This allows unauthenticated calls for new schools to register
export const registerNewSchool = functions.https.onCall(async (data, context) => {
  // Allow unauthenticated calls for new school registration
  // If authenticated, verify they are Super Admin
  if (context.auth) {
    const callerUid = context.auth.uid;
    const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
    
    if (callerDoc.exists) {
      const callerData = callerDoc.data();
      const callerRole = callerData?.role;
      const callerEmail = context.auth.token.email;

      // Check if user is Super Admin
      const isSuperAdmin = 
        callerRole === 'superAdmin' || 
        callerRole === 'Owner' || 
        callerRole === 'owner' ||
        callerEmail === 'mohwed32@getmanar.com' ||
        callerEmail === 'mohawed32@manar.com' ||
        callerEmail === 'mohwed32@manar.com' ||
        callerEmail === 'mohawed32@getmanar.com';

      // If authenticated but not Super Admin, deny
      if (!isSuperAdmin) {
        throw new functions.https.HttpsError(
          "permission-denied", 
          "هذه العملية مقتصرة على مدير التطبيق فقط أو التسجيل الجديد"
        );
      }
    }
  }

  // 1. Validate Input
  const { schoolName, principalName, email, mobile, password, identityNumber, adminRegion, city, schoolType, schoolStage } = data;
  if (!schoolName || !principalName || !email || !password || !identityNumber) {
    throw new functions.https.HttpsError("invalid-argument", "البيانات المطلوبة ناقصة");
  }

  // Normalize digits
  let normalizedId = identityNumber;
  try {
      normalizedId = identityNumber.replace(/[٠-٩]/g, (d: string) => "0123456789"["٠١٢٣٤٥٦٧٨٩".indexOf(d)])
                                   .replace(/[۰-۹]/g, (d: string) => "0123456789"["۰۱۲۳۴۵۶۷۸۹".indexOf(d)]);
  } catch (e) {
      console.warn("Normalization failed", e);
  }

  // 2. Check Identity Uniqueness in GlobalUsers
  // We use GlobalUsers to ensure one account per identity across the platform
  const existingUserQuery = await db.collection("GlobalUsers").where("identityNumber", "==", normalizedId).limit(1).get();
  if (!existingUserQuery.empty) {
    throw new functions.https.HttpsError("already-exists", "رقم الهوية مستخدم بالفعل");
  }

  // 3. Generate Email (mg[ID]@getmanar.com)
  // This standardizes the login credential for managers
  const userEmail = `mg${normalizedId}@getmanar.com`;

  // 4. Create Auth User
  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: userEmail,
      password: password,
      displayName: principalName,
      // Only set phoneNumber if valid E.164, otherwise skip to avoid error
      // phoneNumber: mobile ? `+966${mobile.replace(/^0+/, "")}` : undefined, 
    });
  } catch (error: any) {
    if (error.code === 'auth/email-already-exists') {
        // If Auth user exists, try to update password
        try {
            userRecord = await admin.auth().getUserByEmail(userEmail);
            await admin.auth().updateUser(userRecord.uid, {
                password: password,
                displayName: principalName
            });
        } catch (updateError) {
             throw new functions.https.HttpsError("internal", `Failed to update existing user: ${updateError}`);
        }
    } else {
        throw new functions.https.HttpsError("internal", `Failed to create user: ${error.message}`);
    }
  }

  const uid = userRecord!.uid;

  // 5. Create School Document
  // Generate a random 6-character alphanumeric code for the school
  const generateSchoolCode = () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluding I, O, 0, 1 for clarity
    let result = '';
    for (let i = 0; i < 6; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  };

  const schoolCode = generateSchoolCode();
  const schoolRef = db.collection("Schools").doc(schoolCode); // Use School Code as ID
  const schoolId = schoolCode;

  // Use a batch for atomicity of Firestore writes
  const batch = db.batch();

  batch.set(schoolRef, {
    id: schoolCode, // Store ID explicitly
    code: schoolCode, // Also store as 'code' for clarity
    name: schoolName,
    city: city || "",
    adminRegion: adminRegion || "",
    type: schoolType || "government",
    stage: schoolStage || "primary",
    email: email, // Contact Email
    mobile: mobile,
    managerId: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true,
  });

  // 6. Create Global User Document
  const globalUserRef = db.collection("GlobalUsers").doc(uid);
  batch.set(globalUserRef, {
    email: userEmail,
    name: principalName,
    role: "manager", // "manager" maps to Admin Dashboard access
    schoolId: schoolId,
    identityNumber: identityNumber,
    phoneNumber: mobile,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isPasswordChangeRequired: false,
  });

  // 7. Create Staff Document (Manager Profile)
  const staffRef = schoolRef.collection("Staff").doc(uid);
  batch.set(staffRef, {
    id: uid,
    name: principalName,
    email: userEmail,
    role: "manager",
    identityNumber: identityNumber,
    phoneNumber: mobile,
    schoolId: schoolId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // 8. Return Success
  return { success: true, schoolId: schoolId, userId: uid, email: userEmail };
});

// Get User Email By Identity
// Used for login fallback when users enter Identity Number
export const getUserEmailByIdentity = functions.https.onCall(async (data, context) => {
  const { identityNumber } = data;
  if (!identityNumber) {
     throw new functions.https.HttpsError("invalid-argument", "رقم الهوية مطلوب");
  }

  // Normalize digits
  let normalizedId = identityNumber;
  try {
      normalizedId = identityNumber.replace(/[٠-٩]/g, (d: string) => "0123456789"["٠١٢٣٤٥٦٧٨٩".indexOf(d)])
                                   .replace(/[۰-۹]/g, (d: string) => "0123456789"["۰۱۲۳۴۵۶۷۸۹".indexOf(d)]);
  } catch (e) {
      console.warn("Normalization failed", e);
  }
  
  // Search in GlobalUsers
  const query = await db.collection("GlobalUsers").where("identityNumber", "==", normalizedId).limit(1).get();
  if (query.empty) {
     throw new functions.https.HttpsError("not-found", "لم يتم العثور على مستخدم بهذا الرقم");
  }
  
  const user = query.docs[0].data();
  return { email: user.email };
});

// Create School Admin Provision
// Used to create users (managers, staff, teachers, etc.) with proper Auth and Firestore setup
export const createSchoolAdminProvision = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  // Check if caller is Super Admin or School Admin/Manager
  const callerUid = context.auth.uid;
  const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
  
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const callerData = callerDoc.data();
  const callerRole = callerData?.role;
  const callerEmail = context.auth.token.email;

  // Check if user is Super Admin or School Admin
  const isSuperAdmin = 
    callerRole === 'superAdmin' || 
    callerRole === 'Owner' || 
    callerRole === 'owner' ||
    callerEmail === 'mohwed32@getmanar.com' ||
    callerEmail === 'mohawed32@manar.com' ||
    callerEmail === 'mohwed32@manar.com' ||
    callerEmail === 'mohawed32@getmanar.com';

  const isSchoolAdmin = callerRole === 'admin' || callerRole === 'manager' || callerRole === 'principal';

  if (!isSuperAdmin && !isSchoolAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied", 
      "ليس لديك صلاحية لإنشاء مستخدمين جدد"
    );
  }

  // Validate input
  const { email, password, name, schoolId, role, identityNumber, mobile, delegatedPermissions, deputyType } = data;
  const phoneNumber = mobile || data.phoneNumber;
  
  if (!email || !password || !name || !schoolId || !role) {
    throw new functions.https.HttpsError("invalid-argument", "البيانات المطلوبة ناقصة");
  }

  // If caller is School Admin, verify they can only create users for their school
  if (isSchoolAdmin && !isSuperAdmin) {
    const callerSchoolId = callerData?.schoolId;
    if (callerSchoolId !== schoolId) {
      throw new functions.https.HttpsError(
        "permission-denied", 
        "لا يمكنك إنشاء مستخدمين لمدرسة أخرى"
      );
    }
  }

  // Normalize identity number if provided
  let normalizedId = identityNumber;
  if (identityNumber) {
    try {
      normalizedId = identityNumber.replace(/[٠-٩]/g, (d: string) => "0123456789"["٠١٢٣٤٥٦٧٨٩".indexOf(d)])
                                   .replace(/[۰-۹]/g, (d: string) => "0123456789"["۰۱۲۳۴۵۶۷۸۹".indexOf(d)]);
    } catch (e) {
      console.warn("Normalization failed", e);
    }
  }

  // Check if identity number already exists (if provided)
  let existingUid: string | null = null;

  if (normalizedId) {
    const existingUserQuery = await db.collection("GlobalUsers")
      .where("identityNumber", "==", normalizedId)
      .limit(1)
      .get();
    
    if (!existingUserQuery.empty) {
      // If user exists, we might want to link them instead of failing
      // For Parents and Students, this is common (siblings, multiple schools)
      // For Teachers/Admins, it might be a transfer
      
      // Instead of throwing, we capture the UID to link it
      existingUid = existingUserQuery.docs[0].id;
      
      // Optional: Check if we want to allow this. For now, we allow linking.
      console.log(`User with identity ${normalizedId} already exists (UID: ${existingUid}). Linking to new school...`);
    }
  }

  // Create Auth User (Only if not existing)
  let uid: string;
  
  if (existingUid) {
    uid = existingUid;
    // We don't update password/email for existing global users to avoid disrupting their other access
    // But we might want to ensure they have the new role in their custom claims? (Complex)
  } else {
    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: name,
      });
    } catch (error: any) {
      if (error.code === 'auth/email-already-exists') {
        // If email exists in Auth but not in GlobalUsers (rare inconsistency), try to find it
        try {
            const existingAuthUser = await admin.auth().getUserByEmail(email);
            uid = existingAuthUser.uid;
            console.log(`Email ${email} exists in Auth. Linking UID: ${uid}`);
        } catch (e) {
            throw new functions.https.HttpsError("already-exists", "البريد الإلكتروني مستخدم بالفعل");
        }
      } else {
        throw new functions.https.HttpsError("internal", `فشل إنشاء المستخدم: ${error.message}`);
      }
    }
    
    if (!uid!) { // Should be set by now
        // Fallback if createUser succeeded
        // @ts-ignore
        uid = userRecord.uid; 
    }
  }

  // Use a batch for atomicity
  const batch = db.batch();

  // Create/Update Global User Document
  // We use set with merge to ensure we don't overwrite existing critical data, but add new info if missing
  const globalUserRef = db.collection("GlobalUsers").doc(uid);
  batch.set(globalUserRef, {
    email: email,
    name: name,
    // We don't overwrite role if it exists? Or do we promote?
    // For simplicity, we assume the latest role is valid or it's an array.
    // Here we just set it. A user might be 'parent' in one context.
    role: role, 
    schoolId: schoolId, // Note: This overwrites 'primary' school. This is a limitation of current model.
    identityNumber: normalizedId || null,
    phoneNumber: phoneNumber || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Create appropriate school collection document based on role
  let collectionName = 'Staff';
  if (role === 'teacher') {
    collectionName = 'Teachers';
  } else if (role === 'student') {
    collectionName = 'Students';
  } else if (role === 'parent') {
    collectionName = 'Parents';
  }

  const schoolUserRef = db.collection('Schools').doc(schoolId).collection(collectionName).doc(uid);
  batch.set(schoolUserRef, {
    id: uid,
    name: name,
    email: email,
    role: role,
    identityNumber: normalizedId || null,
    phoneNumber: phoneNumber || null,
    schoolId: schoolId,
    deputyType: deputyType || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    // Save delegated permissions directly if provided
    ...(delegatedPermissions ? { delegatedPermissions } : {}),
  });

  try {
    await batch.commit();
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", `فشل حفظ بيانات المستخدم في قاعدة البيانات: ${error.message}`);
  }

  return { success: true, uid: uid };
});



// Delete School Deep
// Deletes a school and all its related data (only Super Admin)
export const deleteSchoolDeep = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  // Check if caller is Super Admin
  const callerUid = context.auth.uid;
  const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
  
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const callerData = callerDoc.data();
  const callerRole = callerData?.role;
  const callerEmail = context.auth.token.email;

  // Only Super Admin can delete schools
  const isSuperAdmin = 
    callerRole === 'superAdmin' || 
    callerRole === 'Owner' || 
    callerRole === 'owner' ||
    callerEmail === 'mohwed32@getmanar.com' ||
    callerEmail === 'mohawed32@manar.com' ||
    callerEmail === 'mohwed32@manar.com' ||
    callerEmail === 'mohawed32@getmanar.com';

  if (!isSuperAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied", 
      "هذه العملية مقتصرة على مدير التطبيق فقط"
    );
  }

  const { schoolId } = data;
  
  if (!schoolId) {
    throw new functions.https.HttpsError("invalid-argument", "معرف المدرسة مطلوب");
  }

  try {
    // Delete school document
    await db.collection('Schools').doc(schoolId).delete();

    // Delete all GlobalUsers associated with this school
    const globalUsersQuery = await db.collection('GlobalUsers')
      .where('schoolId', '==', schoolId)
      .get();

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of globalUsersQuery.docs) {
      batch.delete(doc.ref);
      batchCount++;

      // Firestore batch limit is 500 operations
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }

      // Also delete from Auth (optional, can be done separately)
      try {
        await admin.auth().deleteUser(doc.id);
      } catch (error) {
        console.warn(`Failed to delete auth user ${doc.id}:`, error);
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    // Note: Subcollections (Staff, Teachers, Students, etc.) are not automatically deleted
    // You may want to use a recursive delete function or handle them separately
    // For now, we'll leave them as they'll be inaccessible without the parent school doc

    return { success: true, message: 'تم حذف المدرسة بنجاح' };
  } catch (error: any) {
    console.error('Error deleting school:', error);
    throw new functions.https.HttpsError("internal", `فشل حذف المدرسة: ${error.message}`);
  }
});
