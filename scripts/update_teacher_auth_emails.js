/**
 * update_teacher_auth_emails.js
 * يحدّث بريد المعلمين في Firebase Auth بحيث يكون: TC{code}@getmanar.com
 * التشغيل: node scripts/update_teacher_auth_emails.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const auth = admin.auth();

const TEACHERS = [
  { name: 'محمد الفايز',        code: 'TC533119' },
  { name: 'طلال المهباش',       code: 'TC510570' },
  { name: 'يوسف آل',            code: 'TC768196' },
  { name: 'راشد الشهري',        code: 'TC155345' },
  { name: 'عبدالرحمن الربيعة',  code: 'TC986425' },
  { name: 'سعد آل',             code: 'TC341935' },
  { name: 'مهنا الشيباني',      code: 'TC001398' },
  { name: 'سلطان العتيبي',      code: 'TC907683' },
  { name: 'عبدالعزيز العتيبي',  code: 'TC191681' },
  { name: 'عماد العتيبي',       code: 'TC160006' },
  { name: 'محمد الحربي',        code: 'TC150299' },
  { name: 'محمد العتيبي',       code: 'TC651961' },
  { name: 'إبراهيم الوابل',     code: 'TC384043' },
  { name: 'عبدالله المطيري',    code: 'TC957677' },
  { name: 'عصام عز',            code: 'TC968762' },
  { name: 'علي الحربي',         code: 'TC180647' },
  { name: 'متعب العتيبي',       code: 'TC379677' },
  { name: 'سلطان الشنيفي',      code: 'TC473522' },
  { name: 'ياسر البقمي',        code: 'TC106657' },
  { name: 'سعود القريني',       code: 'TC701726' },
  { name: 'فيصل العسيري',       code: 'TC915236' },
  { name: 'سامي القحطاني',      code: 'TC853584' },
  { name: 'طلال الردادي',       code: 'TC271020' },
  { name: 'عبدالعزيز المهوس',   code: 'TC109150' },
  { name: 'عبدالرحمن الديوان',  code: 'TC502017' },
  { name: 'احمد المهود',        code: 'TC815640' },
  { name: 'وليد العتيبي',       code: 'TC520101' },
  { name: 'خالد العتيبي',       code: 'TC072158' },
  { name: 'ماجد الأسمري',       code: 'TC558023' },
  { name: 'فيصل القحطاني',      code: 'TC455077' },
  { name: 'بجاد العتيبي',       code: 'TC741438' },
  { name: 'عبدالملك الشمري',    code: 'TC136573' },
  { name: 'نايف الأدهم',        code: 'TC569624' },
  { name: 'بندر الدوسري',       code: 'TC996150' },
  { name: 'سطام العضياني',      code: 'TC686089' },
  { name: 'علي الغامدي',        code: 'TC774808' },
];

async function main() {
  console.log('🚀 بدء تحديث بريد المعلمين في Firebase Auth...\n');

  const schoolsSnap = await db.collection('Schools').get();
  let updated = 0, failed = 0, notFound = 0;

  for (const schoolDoc of schoolsSnap.docs) {
    const schoolId = schoolDoc.id;
    const schoolName = schoolDoc.data().name || schoolId;
    console.log(`\n🏫 المدرسة: ${schoolName}`);

    const teachersSnap = await db.collection('Schools').doc(schoolId).collection('Teachers').get();
    if (teachersSnap.empty) continue;

    for (const teacher of TEACHERS) {
      const newEmail = `${teacher.code}@getmanar.com`;

      const found = teachersSnap.docs.find(d => {
        const name = (d.data().name || '').trim();
        return name === teacher.name || name.includes(teacher.name) || teacher.name.includes(name);
      });

      if (!found) {
        console.log(`  ⚠️ لم يُوجد في Firestore: ${teacher.name}`);
        notFound++;
        continue;
      }

      const teacherId = found.id;

      // تحديث Firebase Auth
      try {
        await auth.updateUser(teacherId, { email: newEmail });
        console.log(`  ✅ Auth: ${teacher.name} → ${newEmail}`);
        updated++;
      } catch (e) {
        if (e.code === 'auth/email-already-exists') {
          // البريد موجود مسبقاً — ربما تم التحديث من قبل
          console.log(`  ℹ️ البريد موجود مسبقاً: ${newEmail}`);
          updated++;
        } else if (e.code === 'auth/user-not-found') {
          // إنشاء حساب جديد بكلمة مرور مؤقتة
          try {
            await auth.createUser({
              uid: teacherId,
              email: newEmail,
              password: 'Temp@' + teacher.code,
              displayName: teacher.name,
            });
            console.log(`  🆕 أُنشئ حساب جديد: ${teacher.name} → ${newEmail}`);
            updated++;
          } catch (e2) {
            console.log(`  ❌ فشل إنشاء حساب: ${teacher.name} — ${e2.message}`);
            failed++;
          }
        } else {
          console.log(`  ❌ خطأ Auth: ${teacher.name} — ${e.message}`);
          failed++;
        }
      }
    }
  }

  console.log(`\n✅ تم تحديث ${updated} معلم في Auth`);
  if (notFound > 0) console.log(`⚠️ لم يُوجد ${notFound} معلم`);
  if (failed > 0) console.log(`❌ فشل ${failed} معلم`);
  process.exit(0);
}

main().catch(e => { console.error('❌ خطأ:', e); process.exit(1); });
