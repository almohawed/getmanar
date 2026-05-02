/**
 * fix_aliases.js
 * يحذف الـ aliases الخاطئة من Firestore ويضيف الصحيحة
 * التشغيل: node scripts/fix_aliases.js
 */
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function main() {
  console.log('🔧 إصلاح aliases المواد...\n');

  const schoolsSnap = await db.collection('Schools').get();

  for (const schoolDoc of schoolsSnap.docs) {
    const schoolId = schoolDoc.id;
    const schoolName = schoolDoc.data().name || schoolId;
    console.log(`\n🏫 ${schoolName}`);

    const aliasesSnap = await db.collection('Schools').doc(schoolId)
        .collection('SubjectAliases').get();

    if (aliasesSnap.empty) {
      console.log('  لا توجد aliases');
      continue;
    }

    const batch = db.batch();
    let deleted = 0;

    for (const doc of aliasesSnap.docs) {
      const alias = doc.id;
      const subjectId = doc.data().subjectId;
      
      // حذف الـ aliases الخاطئة
      const wrongMappings = [
        { alias: 'حياتية', wrongId: 'math' },
        { alias: 'حياتيه', wrongId: 'math' },
        { alias: 'مهارات حياتية', wrongId: 'math' },
        { alias: 'مهارات حياتيه', wrongId: 'math' },
      ];
      
      const isWrong = wrongMappings.some(m => 
        (alias === m.alias || alias.includes(m.alias)) && subjectId === m.wrongId
      );
      
      if (isWrong) {
        batch.delete(doc.ref);
        console.log(`  ❌ حذف: "${alias}" → ${subjectId} (خاطئ)`);
        deleted++;
      } else {
        console.log(`  ✅ صحيح: "${alias}" → ${subjectId}`);
      }
    }

    if (deleted > 0) {
      await batch.commit();
      console.log(`  🗑️ تم حذف ${deleted} alias خاطئ`);
    }

    // إضافة الـ aliases الصحيحة
    const correctAliases = [
      { alias: 'حياتية', subjectId: 'life_skills' },
      { alias: 'حياتيه', subjectId: 'life_skills' },
      { alias: 'مهارات حياتية', subjectId: 'life_skills' },
      { alias: 'مهارات حياتيه', subjectId: 'life_skills' },
      { alias: 'منتظر', subjectId: null }, // تجاهل
    ];

    const addBatch = db.batch();
    let added = 0;
    for (const ca of correctAliases) {
      if (ca.subjectId === null) continue;
      const ref = db.collection('Schools').doc(schoolId)
          .collection('SubjectAliases').doc(ca.alias);
      addBatch.set(ref, {
        subjectId: ca.subjectId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        source: 'fix_script',
      });
      console.log(`  ✅ أضيف: "${ca.alias}" → ${ca.subjectId}`);
      added++;
    }
    if (added > 0) await addBatch.commit();
  }

  console.log('\n✅ تم الإصلاح');
  process.exit(0);
}

main().catch(e => { console.error('❌', e); process.exit(1); });
