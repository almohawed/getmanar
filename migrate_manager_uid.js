const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json'); // Download from Firebase Console

// Initialize Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateManagerUid() {
  console.log('🚀 Starting Migration: Schools managerUid...');
  
  try {
    const schoolsSnapshot = await db.collection('Schools').get();
    
    if (schoolsSnapshot.empty) {
      console.log('No schools found.');
      return;
    }

    let updatedCount = 0;
    const batch = db.batch();

    for (const doc of schoolsSnapshot.docs) {
      const data = doc.data();
      
      // Check if migration is needed
      if (!data.managerUid && data.ownerId) {
        const schoolRef = db.collection('Schools').doc(doc.id);
        
        // Add update to batch
        batch.update(schoolRef, { 
          managerUid: data.ownerId,
          _migrationTimestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`[QUEUE] Migrating School: ${doc.id} (ownerId: ${data.ownerId})`);
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`✅ Successfully migrated ${updatedCount} schools.`);
    } else {
      console.log('🎉 All schools are already up to date.');
    }

  } catch (error) {
    console.error('❌ Migration Failed:', error);
  }
}

migrateManagerUid();