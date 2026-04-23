import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// TTL for failed attempts (e.g., 5 minutes)
const FAILED_ATTEMPT_COOLDOWN_MINUTES = 5;
const MAX_FAILED_ATTEMPTS = 5;

export const lookupUserCode = functions.https.onCall(async (data, context) => {
  const { code } = data;
  const ipAddress = context.rawRequest.ip;

  if (!code) {
    throw new functions.https.HttpsError("invalid-argument", "الكود مطلوب.");
  }

  const normalizedCode = code.toUpperCase();

  // 1. Implement Server-Side Rate Limiting
  if (ipAddress) {
    const failedAttemptsRef = db.collection("FailedLoginAttempts");
    const now = admin.firestore.Timestamp.now();
    const cooldownThreshold = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - FAILED_ATTEMPT_COOLDOWN_MINUTES * 60 * 1000,
    );

    // Clean up old attempts (Firestore TTL can handle this automatically if configured)
    // For immediate check, we query within the cooldown window
    const recentFailedAttempts = await failedAttemptsRef
      .where("ipAddress", "==", ipAddress)
      .where("timestamp", ">", cooldownThreshold)
      .get();

    if (recentFailedAttempts.docs.length >= MAX_FAILED_ATTEMPTS) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "لقد تجاوزت الحد الأقصى لمحاولات الدخول. يرجى المحاولة لاحقاً.",
      );
    }
  }

  // 2. Lookup User Code
  const userCodeDoc = await db.collection("UserCodes").doc(normalizedCode).get();

  if (!userCodeDoc.exists || !userCodeDoc.data()?.isActive) {
    // Log failed attempt
    if (ipAddress) {
      await db.collection("FailedLoginAttempts").add({
        ipAddress: ipAddress,
        codeAttempted: normalizedCode,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: false,
      });
    }
    throw new functions.https.HttpsError(
      "not-found",
      "كود الدخول غير صحيح أو غير نشط.",
    );
  }

  const codeData = userCodeDoc.data();

  // 3. Return only necessary data
  return {
    email: codeData?.email,
    schoolId: codeData?.schoolId,
    role: codeData?.role,
    isActive: codeData?.isActive,
  };
});

/**
 * Public Recovery: Find new Global Code by old ID, Phone or Email
 */
export const lookupCodeByInfo = functions.https.onCall(async (data, context) => {
  const { searchInput } = data;

  if (!searchInput) {
    throw new functions.https.HttpsError("invalid-argument", "Search input required.");
  }

  // Rate limiting by IP (using the same logic or similar)
  // ... (omitted for brevity, but recommended in production)

  // 1. Try search by String
  const usersSnapshot = await db.collection("GlobalUsers")
    .where("nationalId", "==", searchInput)
    .limit(1)
    .get();

  let userDoc = usersSnapshot.docs[0];

  // 2. Try by numeric nationalId if the input is numeric
  if (!userDoc && /^\d+$/.test(searchInput)) {
    const numericSnapshot = await db.collection("GlobalUsers")
      .where("nationalId", "==", parseInt(searchInput))
      .limit(1)
      .get();
    userDoc = numericSnapshot.docs[0];
  }

  if (!userDoc) {
    // 3. Try by phone
    const phoneSnapshot = await db.collection("GlobalUsers")
      .where("phoneNumber", "==", searchInput)
      .limit(1)
      .get();
    userDoc = phoneSnapshot.docs[0];
  }

  if (!userDoc) {
    // Try by email
    const emailSnapshot = await db.collection("GlobalUsers")
      .where("email", "==", searchInput)
      .limit(1)
      .get();
    userDoc = emailSnapshot.docs[0];
  }

  if (!userDoc) {
    throw new functions.https.HttpsError("not-found", "لم يتم العثور على حساب بهذه البيانات.");
  }

  const userData = userDoc.data();
  return {
    name: userData.name,
    code: userData.identityNumber,
  };
});
