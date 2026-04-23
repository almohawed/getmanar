
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Try to find this, or use default

try {
  admin.initializeApp();
} catch (e) {
  // If already initialized or other error
  if (!admin.apps.length) {
     console.error('Could not init admin', e);
     process.exit(1);
  }
}

const db = admin.firestore();
const auth = admin.auth();

async function diagnose(identityNumber) {
    console.log(`Diagnosing identity: ${identityNumber}`);
    
    // 1. Check GlobalUsers
    const snap = await db.collection('GlobalUsers').where('identityNumber', '==', identityNumber).get();
    if (snap.empty) {
        console.log('No GlobalUser found with this identity.');
    } else {
        snap.forEach(doc => {
            console.log('GlobalUser found:', doc.id, doc.data());
            const data = doc.data();
            
            // 2. Check Auth
            if (data.email) {
                auth.getUserByEmail(data.email)
                    .then(user => {
                        console.log('Auth User found:', user.toJSON());
                    })
                    .catch(e => {
                        console.log('Auth User lookup failed:', e.message);
                    });
            } else {
                console.log('GlobalUser has no email field.');
            }
        });
    }
}

diagnose('1001515150').then(() => {
    // wait a bit for async auth lookup
    setTimeout(() => process.exit(0), 2000);
});
