/**
 * delete_wait_notifications.js
 * حذف جميع إشعارات "تكليف انتظار" من جميع المدارس
 * 
 * تشغيل: node scripts/delete_wait_notifications.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../android/app/google-services.json');

// تهيئة Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'etisak-784d6',
  });
}

const db = admin.firestore();

async function deleteWaitNotifications() {
  console.log('🔍 البحث عن إشعارات حصص الانتظار...');
  
  let totalDeleted = 0;
  let schoolsProcessed = 0;

  try {
    // جلب جميع المدارس
    const schoolsSnap = await db.collection('Schools').get();
    console.log(`📚 عدد المدارس: ${schoolsSnap.docs.length}`);

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const schoolName = schoolDoc.data().name || schoolId;

      // البحث عن إشعارات الانتظار في هذه المدرسة
      const notifSnap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .where('title', '>=', '📋 تكليف انتظار')
        .where('title', '<=', '📋 تكليف انتظار\uf8ff')
        .get();

      if (notifSnap.empty) {
        console.log(`  ✓ ${schoolName}: لا توجد إشعارات انتظار`);
        continue;
      }

      // حذف دفعي
      const batchSize = 500;
      let deleted = 0;
      
      for (let i = 0; i < notifSnap.docs.length; i += batchSize) {
        const batch = db.batch();
        const chunk = notifSnap.docs.slice(i, i + batchSize);
        chunk.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        deleted += chunk.length;
      }

      totalDeleted += deleted;
      schoolsProcessed++;
      console.log(`  🗑️  ${schoolName}: حُذف ${deleted} إشعار`);
    }

    console.log('\n✅ اكتمل الحذف:');
    console.log(`   المدارس المعالجة: ${schoolsProcessed}`);
    console.log(`   إجمالي الإشعارات المحذوفة: ${totalDeleted}`);

  } catch (error) {
    console.error('❌ خطأ:', error);
    process.exit(1);
  }

  process.exit(0);
}

deleteWaitNotifications();
