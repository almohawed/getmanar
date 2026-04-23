/**
 * Script to delete all pending SMS messages
 * Run this script to clean up old pending messages
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deletePendingSmsMessages(schoolId) {
    console.log(`Deleting pending SMS messages for school: ${schoolId}`);
    
    try {
        // Get all pending messages
        const pendingMessages = await db.collection('Schools')
            .doc(schoolId)
            .collection('SmsOutbox')
            .where('status', '==', 'pending')
            .get();

        if (pendingMessages.empty) {
            console.log('No pending messages found.');
            return 0;
        }

        console.log(`Found ${pendingMessages.size} pending messages`);

        // Delete in batches (Firestore limit: 500 operations per batch)
        const batchSize = 500;
        let deletedCount = 0;
        
        for (let i = 0; i < pendingMessages.docs.length; i += batchSize) {
            const batch = db.batch();
            const batchDocs = pendingMessages.docs.slice(i, i + batchSize);
            
            batchDocs.forEach(doc => {
                batch.delete(doc.ref);
            });
            
            await batch.commit();
            deletedCount += batchDocs.length;
            
            console.log(`Deleted batch of ${batchDocs.length} messages (Total: ${deletedCount})`);
        }

        console.log(`✓ Successfully deleted ${deletedCount} pending messages`);
        return deletedCount;

    } catch (error) {
        console.error('Error deleting messages:', error);
        throw error;
    }
}

// Get schoolId from command line argument
const schoolId = process.argv[2];

if (!schoolId) {
    console.error('Usage: node delete_pending_sms.js <schoolId>');
    console.error('Example: node delete_pending_sms.js school123');
    process.exit(1);
}

// Run the deletion
deletePendingSmsMessages(schoolId)
    .then(count => {
        console.log(`\n✅ Done! Deleted ${count} messages.`);
        process.exit(0);
    })
    .catch(error => {
        console.error('\n❌ Error:', error.message);
        process.exit(1);
    });
