
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // I'll need to check if this exists or use default creds if running in cloud functions env context, but locally I might need to login.
// Actually, I can run this via `firebase functions:shell` or just use the existing `functions/index.js` by adding a temporary http function to debug.
// Better: Add a temporary debug function to `functions/index.js` that I can call via curl or browser.

// Wait, I can't easily invoke a new HTTP function without deploying.
// I can use the existing `repairOrphanAdmins` or `getUserEmailByIdentity` but they are callables.
// I can write a script that uses the local admin SDK if I have credentials.
// Let's check if I have serviceAccountKey.json or if I can use `firebase-admin` with default credentials (if I run `firebase login` I might be able to use `gcloud` auth).

// Alternative: I will modify `functions/index.js` to include a `debugUser` function and deploy it. It's fast enough.
// Or better, I'll use the `RunCommand` to inspect Firestore if I can.
// I don't have a direct Firestore CLI tool installed usually.

// Let's try to Read `functions/index.js` again to see where to add the debug function.
// actually, I can just use `getUserEmailByIdentity` which I just deployed.
// It returns the email.
// I want to know if the Auth user exists.

// I'll add `checkAuthStatus` function to `functions/index.js` and deploy.
// It will take `identityNumber` and check both GlobalUsers and Auth.

exports.debugAuthUser = functions.https.onCall(async (data, context) => {
    const { identityNumber } = data;
    const db = admin.firestore();
    const auth = admin.auth();
    
    const results = {
        identityNumber,
        globalUser: null,
        authUser: null,
        emailMismatch: false
    };

    try {
        // 1. Check GlobalUsers
        const snap = await db.collection('GlobalUsers').where('identityNumber', '==', identityNumber).get();
        if (!snap.empty) {
            const doc = snap.docs[0];
            results.globalUser = doc.data();
            results.globalUser.uid = doc.id;
        }

        // 2. Check Auth (if email found)
        if (results.globalUser && results.globalUser.email) {
            try {
                const userRecord = await auth.getUserByEmail(results.globalUser.email);
                results.authUser = {
                    uid: userRecord.uid,
                    email: userRecord.email,
                    emailVerified: userRecord.emailVerified,
                    disabled: userRecord.disabled
                };
            } catch (e) {
                results.authError = e.message;
            }
        }
        
        return results;
    } catch (error) {
        return { error: error.message };
    }
});
