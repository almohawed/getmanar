import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Migration Function: Generate Global Entry Codes for all existing users
 * who don't have one yet.
 */
export const migrateExistingUsersToCodes = functions.https.onCall(async (data, context) => {
  // 1. Only SuperAdmin (Owner) can trigger this
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = context.auth.uid;
  const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
  const callerData = callerDoc.data();
  if (callerData?.role !== 'superAdmin' && callerData?.role !== 'Owner') {
    throw new functions.https.HttpsError("permission-denied", "Only SuperAdmin can run migration.");
  }

  const results = {
    totalMigrated: 0,
    errors: [] as string[],
  };

  try {
    // 2. Fetch all users from GlobalUsers
    const usersSnapshot = await db.collection("GlobalUsers").get();

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const currentIdentity = userData.identityNumber;
      
      // Check if it's an old numeric ID (National ID)
      const isNumeric = /^\d+$/.test(currentIdentity || "");
      
      if (isNumeric || !currentIdentity) {
        // This user needs migration!
        const newCode = generateGlobalEntryCode();
        
        // Use a Transaction to update GlobalUser AND UserCodes registry
        await db.runTransaction(async (transaction) => {
          // Check if code is already taken in UserCodes
          const codeRef = db.collection("UserCodes").doc(newCode);
          const codeDoc = await transaction.get(codeRef);
          
          if (codeDoc.exists) {
            // Should be rare with Base32 6-chars, but let's be safe
            throw new Error("Generated code already exists, retry needed.");
          }

          // Update GlobalUser: move old ID to nationalId, set new identityNumber
          transaction.update(userDoc.ref, {
            nationalId: currentIdentity, // Preserve old ID
            identityNumber: newCode,      // New Global Code
          });

          // Create UserCodes registry entry
          transaction.set(codeRef, {
            email: userData.email,
            schoolId: userData.schoolId,
            role: userData.role,
            name: userData.name,
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isMigrated: true,
          });
        });

        results.totalMigrated++;
      }
    }

    return { success: true, ...results };
  } catch (e: any) {
    console.error("Migration failed:", e);
    throw new functions.https.HttpsError("internal", e.message || "Migration failed.");
  }
});

function generateGlobalEntryCode(length = 6): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
