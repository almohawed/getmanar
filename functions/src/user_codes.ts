import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const manageUserCode = functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }

  const callerUid = context.auth.uid;
  const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();

  if (!callerDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "المستخدم غير موجود.");
  }

  const callerData = callerDoc.data();
  const callerRole = callerData?.role;
  const callerSchoolId = callerData?.schoolId;

  // Only Admin/Manager/SuperAdmin can manage user codes
  const isAdmin = callerRole === 'admin' || callerRole === 'manager' || callerRole === 'superAdmin' || callerRole === 'Owner' || callerRole === 'owner';
  
  if (!isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لإدارة أكواد المستخدمين.");
  }

  // 2. Validate Input
  const { code, email, schoolId, role, name, action } = data;

  if (!code || !email || !schoolId || !role || !name || !action) {
    throw new functions.https.HttpsError("invalid-argument", "البيانات المطلوبة ناقصة.");
  }

  const userCodeRef = db.collection("UserCodes").doc(code.toUpperCase());

  switch (action) {
    case 'create':
      // Ensure the code is unique using a transaction
      await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(userCodeRef);
        if (doc.exists) {
          throw new functions.https.HttpsError("already-exists", "هذا الكود مستخدم بالفعل.");
        }
        transaction.set(userCodeRef, {
          email: email,
          schoolId: schoolId,
          role: role,
          name: name,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isActive: true,
        });
      });
      return { success: true, message: "تم إنشاء الكود بنجاح." };

    case 'update':
      // Ensure the caller has permission to update this code (e.g., belongs to their school)
      const existingCodeDoc = await userCodeRef.get();
      if (!existingCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const existingCodeData = existingCodeDoc.data();
      if (existingCodeData?.schoolId !== callerSchoolId && callerRole !== 'superAdmin') {
        throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لتعديل هذا الكود.");
      }
      // Prevent changing schoolId
      if (existingCodeData?.schoolId !== schoolId) {
        throw new functions.https.HttpsError("permission-denied", "لا يمكن تغيير المدرسة المرتبطة بالكود.");
      }

      await userCodeRef.update({
        email: email,
        schoolId: schoolId,
        role: role,
        name: name,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم تحديث الكود بنجاح." };

    case 'disable':
      // Ensure the caller has permission to disable this code
      const disableCodeDoc = await userCodeRef.get();
      if (!disableCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const disableCodeData = disableCodeDoc.data();
      if (disableCodeData?.schoolId !== callerSchoolId && callerRole !== 'superAdmin') {
        throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لتعطيل هذا الكود.");
      }

      await userCodeRef.update({
        isActive: false,
        disabledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم تعطيل الكود بنجاح." };

    case 'enable':
      // Ensure the caller has permission to enable this code
      const enableCodeDoc = await userCodeRef.get();
      if (!enableCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const enableCodeData = enableCodeDoc.data();
      if (enableCodeData?.schoolId !== callerSchoolId && callerRole !== 'superAdmin') {
        throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لتفعيل هذا الكود.");
      }

      await userCodeRef.update({
        isActive: true,
        enabledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم تفعيل الكود بنجاح." };

    case 'rotate':
      // This action would typically involve generating a new code and disabling the old one.
      // For simplicity, we'll just disable the old one here. The client would then create a new one.
      const rotateCodeDoc = await userCodeRef.get();
      if (!rotateCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const rotateCodeData = rotateCodeDoc.data();
      if (rotateCodeData?.schoolId !== callerSchoolId && callerRole !== 'superAdmin') {
        throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لإعادة إصدار هذا الكود.");
      }

      await userCodeRef.update({
        isActive: false,
        rotatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم تعطيل الكود القديم بنجاح. يرجى إنشاء كود جديد." };

    case 'bind':
      // Bind device ID to code
      const bindCodeDoc = await userCodeRef.get();
      if (!bindCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const { deviceId } = data;
      if (!deviceId) {
        throw new functions.https.HttpsError("invalid-argument", "معرف الجهاز مطلوب.");
      }

      await userCodeRef.update({
        deviceId: deviceId,
        lastBindAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم ربط الجهاز بنجاح." };

    case 'unbind':
      // Clear device binding
      const unbindCodeDoc = await userCodeRef.get();
      if (!unbindCodeDoc.exists) {
        throw new functions.https.HttpsError("not-found", "الكود غير موجود.");
      }
      const unbindData = unbindCodeDoc.data();
      if (unbindData?.schoolId !== callerSchoolId && callerRole !== 'superAdmin') {
        throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية لإلغاء ربط هذا الجهاز.");
      }

      await userCodeRef.update({
        deviceId: admin.firestore.FieldValue.delete(),
        lastUnbindAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "تم إلغاء ربط الجهاز بنجاح." };

    default:
      throw new functions.https.HttpsError("invalid-argument", "الإجراء غير صالح.");
  }
});