/**
 * seed_omar_school.js
 * ينشئ مدرسة عمر بن أبي سلمة المتوسطة مع كامل الكادر والفصول
 * التشغيل: node scripts/seed_omar_school.js
 */

const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

// ─── تهيئة Firebase Admin ─────────────────────────────────────────────────────
const serviceAccount = require('../functions/service-account.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const auth = admin.auth();

// ─── بيانات المدرسة ───────────────────────────────────────────────────────────
const SCHOOL_NAME = 'مدرسة عمر بن أبي سلمة المتوسطة';
const SCHOOL_CITY = 'الرياض';
const SCHOOL_COUNTRY = 'SA';
const SCHOOL_STAGE = 'المتوسطة';
const SCHOOL_TYPE = 'government';

// ─── توليد كلمة مرور عشوائية ─────────────────────────────────────────────────
function genPassword(len = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let p = '';
  for (let i = 0; i < len; i++) p += chars[Math.floor(Math.random() * chars.length)];
  return p;
}

// ─── توليد MN Code ────────────────────────────────────────────────────────────
function genMNCode(prefix) {
  const digits = Math.floor(100000 + Math.random() * 900000).toString();
  return `${prefix}${digits}`;
}

// ─── تطبيع رقم الجوال ────────────────────────────────────────────────────────
function normalizePhone(phone) {
  if (!phone) return null;
  phone = phone.replace(/\s/g, '');
  if (phone.startsWith('05') && phone.length === 10) return '+966' + phone.substring(1);
  if (phone.startsWith('5') && phone.length === 9) return '+9665' + phone.substring(1);
  return phone;
}

// ─── بيانات المعلمين ──────────────────────────────────────────────────────────
const TEACHERS = [
  { name: 'إبراهيم الوابل',       subject: 'لغتي',      hours: 21 },
  { name: 'احمد المهود',           subject: 'اجتماعيات', hours: 19 },
  { name: 'بجاد العتيبي',          subject: 'تربية فنية', hours: 19 },
  { name: 'بندر الدوسري',          subject: 'تربية بدنية', hours: 24 },
  { name: 'خالد العتيبي',          subject: 'اجتماعيات', hours: 24 },
  { name: 'راشد الشهري',           subject: 'تربية إسلامية', hours: 24 },
  { name: 'سامي القحطاني',         subject: 'لغة إنجليزية', hours: 24 },
  { name: 'سطام العضياني',         subject: 'برايل',     hours: 10 },
  { name: 'سعد آل',                subject: 'رياضيات',   hours: 24 },
  { name: 'سعود القريني',          subject: 'علوم',      hours: 12 },
  { name: 'سلطان الشنيفي',         subject: 'علوم',      hours: 12 },
  { name: 'سلطان العتيبي',         subject: 'رياضيات',   hours: 24 },
  { name: 'طلال الردادي',          subject: 'لغة إنجليزية', hours: 24 },
  { name: 'طلال المهباش',          subject: 'تربية إسلامية', hours: 15 },
  { name: 'عبدالرحمن الديوان',     subject: 'لغة إنجليزية', hours: 24 },
  { name: 'عبدالرحمن الربيعة',     subject: 'تربية إسلامية', hours: 21 },
  { name: 'عبدالعزيز العتيبي',     subject: 'رياضيات',   hours: 19 },
  { name: 'عبدالعزيز المهوس',      subject: 'لغة إنجليزية', hours: 12 },
  { name: 'عبدالله المطيري',       subject: 'لغتي',      hours: 17 },
  { name: 'عبدالملك الشمري',       subject: 'تربية فنية', hours: 19 },
  { name: 'عصام عز',               subject: 'لغتي',      hours: 11 },
  { name: 'علي الحربي',            subject: 'لغتي',      hours: 21 },
  { name: 'علي الغامدي',           subject: 'برايل',     hours: 5  },
  { name: 'عماد العتيبي',          subject: 'رياضيات',   hours: 19 },
  { name: 'فيصل العسيري',          subject: 'علوم',      hours: 17 },
  { name: 'فيصل القحطاني',         subject: 'تقنية رقمية', hours: 21 },
  { name: 'ماجد الأسمري',          subject: 'تقنية رقمية', hours: 22 },
  { name: 'متعب العتيبي',          subject: 'علوم',      hours: 21 },
  { name: 'محمد الحربي',           subject: 'رياضيات',   hours: 19 },
  { name: 'محمد العتيبي',          subject: 'لغتي',      hours: 19 },
  { name: 'محمد الفايز',           subject: 'تربية إسلامية', hours: 21 },
  { name: 'مهنا الشيباني',         subject: 'رياضيات',   hours: 24 },
  { name: 'نايف الأدهم',           subject: 'تربية بدنية', hours: 13 },
  { name: 'وليد العتيبي',          subject: 'اجتماعيات', hours: 24 },
  { name: 'ياسر البقمي',           subject: 'علوم',      hours: 24 },
  { name: 'يوسف آل',               subject: 'تربية إسلامية', hours: 24 },
];

// ─── بيانات المرشدين ──────────────────────────────────────────────────────────
const COUNSELORS = [
  { name: 'عبده',                  phone: '0503677132', identity: '1234567890' },
  { name: 'فهد محمد الحربي',       phone: '0553204439', identity: '1008992313' },
  { name: 'فيصل نايف العتيبي',     phone: '0566927918', identity: '1032678011' },
  { name: 'علي الشهراني',          phone: '0503117994', identity: '1025096999' },
];

// ─── الفصول الدراسية ──────────────────────────────────────────────────────────
const CLASSES = [
  // أول متوسط
  { grade: 1, section: '1', label: '1/1', hours: 35 },
  { grade: 1, section: '2', label: '1/2', hours: 35 },
  { grade: 1, section: '3', label: '1/3', hours: 35 },
  { grade: 1, section: '4', label: '1/4', hours: 35 },
  { grade: 1, section: '5', label: '1/5', hours: 35 },
  { grade: 1, section: '6', label: '1/6', hours: 35 },
  { grade: 1, section: 'عوق', label: '1/عوق', hours: 21 },
  // ثاني متوسط
  { grade: 2, section: '1', label: '2/1', hours: 35 },
  { grade: 2, section: '2', label: '2/2', hours: 35 },
  { grade: 2, section: '3', label: '2/3', hours: 35 },
  { grade: 2, section: '4', label: '2/4', hours: 35 },
  { grade: 2, section: '5', label: '2/5', hours: 35 },
  { grade: 2, section: '6', label: '2/6', hours: 35 },
  { grade: 2, section: 'عوق', label: '2/عوق', hours: 21 },
  // ثالث متوسط
  { grade: 3, section: '1', label: '3/1', hours: 35 },
  { grade: 3, section: '2', label: '3/2', hours: 35 },
  { grade: 3, section: '3', label: '3/3', hours: 35 },
  { grade: 3, section: '4', label: '3/4', hours: 35 },
  { grade: 3, section: '5', label: '3/5', hours: 35 },
  { grade: 3, section: '6', label: '3/6', hours: 35 },
  { grade: 3, section: 'عوق', label: '3/عوق', hours: 21 },
];

// ─── الدالة الرئيسية ──────────────────────────────────────────────────────────
async function main() {
  console.log('🚀 بدء إنشاء مدرسة عمر بن أبي سلمة...\n');

  const results = []; // لجمع بيانات الكادر للجدول HTML

  // ══════════════════════════════════════════════════════════════════════════════
  // 1. إنشاء المدرسة
  // ══════════════════════════════════════════════════════════════════════════════
  const schoolId = uuidv4();
  const adminPassword = genPassword();
  const adminEmail = `omar.school.admin@getmanar.com`;
  const adminMnCode = genMNCode('AD');

  // إنشاء حساب المدير في Firebase Auth
  let adminUid;
  try {
    const adminRecord = await auth.createUser({
      email: adminEmail,
      password: adminPassword,
      displayName: 'عمر عبدالله الأموي',
    });
    adminUid = adminRecord.uid;
    console.log(`✅ تم إنشاء حساب المدير: ${adminEmail}`);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const existing = await auth.getUserByEmail(adminEmail);
      adminUid = existing.uid;
      console.log(`⚠️ المدير موجود مسبقاً: ${adminEmail}`);
    } else throw e;
  }

  // حفظ بيانات المدرسة
  await db.collection('Schools').doc(schoolId).set({
    id: schoolId,
    name: SCHOOL_NAME,
    type: SCHOOL_TYPE,
    stage: SCHOOL_STAGE,
    city: SCHOOL_CITY,
    adminRegion: 'إدارة التعليم بمنطقة الرياض',
    ownerId: adminUid,
    countryCode: SCHOOL_COUNTRY,
    policyVersion: 'v1',
    subscriptionPlan: 'elite',
    isLifetimeAccess: false,
    hasSpecialEducation: true,
    startTime: '07:00',
    daysPerWeek: 5,
    periodsPerDay: 7,
    showSubscriptionSection: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`✅ تم إنشاء المدرسة: ${SCHOOL_NAME} (${schoolId})`);

  // حفظ المدير في GlobalUsers
  await db.collection('GlobalUsers').doc(adminUid).set({
    email: adminEmail,
    role: 'admin',
    schoolId,
    displayName: 'عمر عبدالله الأموي',
    phoneNumber: normalizePhone('0555110822'),
    mnCode: adminMnCode,
    isPasswordChangeRequired: true,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // حفظ UserCode
  await db.collection('UserCodes').doc(adminMnCode).set({
    uid: adminUid, email: adminEmail, schoolId, role: 'admin',
    name: 'عمر عبدالله الأموي', prefix: 'AD', formatVersion: 2,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), isActive: true,
  });

  // حفظ في Staff
  await db.collection('Schools').doc(schoolId).collection('Staff').doc(adminUid).set({
    uid: adminUid, name: 'عمر عبدالله الأموي', role: 'admin',
    email: adminEmail, mobile: normalizePhone('0555110822'),
    mnCode: adminMnCode, schoolId, isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  results.push({
    name: 'عمر عبدالله الأموي',
    role: 'مدير المدرسة',
    username: adminMnCode,
    password: adminPassword,
    email: adminEmail,
  });

  console.log(`   كود المدير: ${adminMnCode} | كلمة المرور: ${adminPassword}\n`);

  // ══════════════════════════════════════════════════════════════════════════════
  // 2. إنشاء الفصول
  // ══════════════════════════════════════════════════════════════════════════════
  console.log('📚 إنشاء الفصول الدراسية...');
  const classIds = {};
  for (const cls of CLASSES) {
    const classId = uuidv4();
    classIds[cls.label] = classId;
    const gradeLabel = cls.grade === 1 ? 'أول' : cls.grade === 2 ? 'ثاني' : 'ثالث';
    const stageName = `${gradeLabel} متوسط`;
    await db.collection('Schools').doc(schoolId).collection('Classes').doc(classId).set({
      id: classId,
      name: cls.label,
      gradeLevel: cls.grade,
      sectionNumber: cls.section,
      preferredLabel: cls.label,
      stage: stageName,
      periodsPerWeek: cls.hours,
      schoolId,
      isSpecialEducation: cls.section === 'عوق',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`✅ تم إنشاء ${CLASSES.length} فصل\n`);

  // ══════════════════════════════════════════════════════════════════════════════
  // 3. إنشاء المعلمين
  // ══════════════════════════════════════════════════════════════════════════════
  console.log('👨‍🏫 إنشاء المعلمين...');
  for (const t of TEACHERS) {
    const uid = uuidv4();
    const password = genPassword();
    const mnCode = genMNCode('TC');
    const email = `tc.${uid.substring(0, 8)}@getmanar.com`;

    try {
      await auth.createUser({ email, password, displayName: t.name });
    } catch (e) {
      if (e.code !== 'auth/email-already-exists') console.warn(`  ⚠️ ${t.name}: ${e.message}`);
    }

    const teacherData = {
      uid, name: t.name, role: 'teacher', email,
      primarySubjectId: t.subject,
      maxWeeklyClasses: t.hours,
      mnCode, schoolId, isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('GlobalUsers').doc(uid).set({
      email, role: 'teacher', schoolId, displayName: t.name,
      mnCode, isPasswordChangeRequired: true, isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('UserCodes').doc(mnCode).set({
      uid, email, schoolId, role: 'teacher', name: t.name,
      prefix: 'TC', formatVersion: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), isActive: true,
    });
    await db.collection('Schools').doc(schoolId).collection('Teachers').doc(uid).set(teacherData);

    results.push({ name: t.name, role: `معلم ${t.subject}`, username: mnCode, password, email });
    console.log(`  ✅ ${t.name} (${t.subject}) — ${mnCode} | ${password}`);
  }
  console.log(`\n✅ تم إنشاء ${TEACHERS.length} معلم\n`);

  // ══════════════════════════════════════════════════════════════════════════════
  // 4. إنشاء المرشدين
  // ══════════════════════════════════════════════════════════════════════════════
  console.log('🧭 إنشاء المرشدين الطلابيين...');
  for (const c of COUNSELORS) {
    const uid = uuidv4();
    const password = genPassword();
    const mnCode = genMNCode('CN');
    const phone = normalizePhone(c.phone);
    const email = `cn.${c.identity}@getmanar.com`;

    try {
      await auth.createUser({ email, password, displayName: c.name, phoneNumber: phone });
    } catch (e) {
      if (e.code !== 'auth/email-already-exists') console.warn(`  ⚠️ ${c.name}: ${e.message}`);
    }

    await db.collection('GlobalUsers').doc(uid).set({
      email, role: 'counselor', schoolId, displayName: c.name,
      phoneNumber: phone, identityNumber: c.identity,
      mnCode, isPasswordChangeRequired: true, isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('UserCodes').doc(mnCode).set({
      uid, email, schoolId, role: 'counselor', name: c.name,
      prefix: 'CN', formatVersion: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), isActive: true,
    });
    await db.collection('Schools').doc(schoolId).collection('Staff').doc(uid).set({
      uid, name: c.name, role: 'counselor', email,
      mobile: phone, identityNumber: c.identity,
      mnCode, schoolId, isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    results.push({ name: c.name, role: 'مرشد طلابي', username: mnCode, password, email });
    console.log(`  ✅ ${c.name} — ${mnCode} | ${password}`);
  }
  console.log(`\n✅ تم إنشاء ${COUNSELORS.length} مرشد\n`);

  // ══════════════════════════════════════════════════════════════════════════════
  // 5. توليد صفحة HTML
  // ══════════════════════════════════════════════════════════════════════════════
  console.log('📄 توليد صفحة HTML...');
  generateHTML(results, schoolId);

  console.log('\n🎉 تم الانتهاء بنجاح!');
  console.log(`📌 معرف المدرسة: ${schoolId}`);
  console.log(`📌 تم حفظ الجدول في: scripts/omar_school_credentials.html`);
  process.exit(0);
}

// ─── توليد HTML ───────────────────────────────────────────────────────────────
function generateHTML(results, schoolId) {
  const fs = require('fs');
  const rows = results.map((r, i) => `
    <tr>
      <td>${i + 1}</td>
      <td>${r.name}</td>
      <td>${r.role}</td>
      <td class="code">${r.username}</td>
      <td class="code">${r.password}</td>
    </tr>`).join('');

  const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>بيانات دخول كادر مدرسة عمر بن أبي سلمة</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
      background: #f0f4f8;
      padding: 30px 20px;
      direction: rtl;
    }
    .container { max-width: 900px; margin: 0 auto; }
    .header {
      background: linear-gradient(135deg, #1a237e, #283593);
      color: white;
      padding: 24px 30px;
      border-radius: 12px 12px 0 0;
      text-align: center;
    }
    .header h1 { font-size: 22px; margin-bottom: 6px; }
    .header p { font-size: 13px; opacity: 0.8; }
    .meta {
      background: #e8eaf6;
      padding: 12px 20px;
      font-size: 12px;
      color: #3949ab;
      border-right: 4px solid #3949ab;
      margin-bottom: 0;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: white;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }
    thead tr {
      background: #283593;
      color: white;
    }
    thead th {
      padding: 14px 16px;
      font-size: 13px;
      font-weight: 600;
      text-align: right;
    }
    tbody tr:nth-child(even) { background: #f5f7ff; }
    tbody tr:hover { background: #e8eaf6; }
    tbody td {
      padding: 12px 16px;
      font-size: 13px;
      color: #333;
      border-bottom: 1px solid #e0e0e0;
    }
    .code {
      font-family: 'Courier New', monospace;
      font-weight: bold;
      color: #1565c0;
      letter-spacing: 1px;
      font-size: 14px;
    }
    .footer {
      background: #283593;
      color: white;
      text-align: center;
      padding: 14px;
      border-radius: 0 0 12px 12px;
      font-size: 12px;
      opacity: 0.9;
    }
    .warning {
      background: #fff3e0;
      border: 1px solid #ffb74d;
      border-radius: 8px;
      padding: 12px 16px;
      margin: 16px 0;
      font-size: 12px;
      color: #e65100;
    }
    @media print {
      body { background: white; padding: 10px; }
      .warning { display: none; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🏫 مدرسة عمر بن أبي سلمة المتوسطة</h1>
      <p>بيانات دخول الكادر التعليمي والإداري — منصة منار</p>
    </div>
    <div class="meta">
      معرف المدرسة: <strong>${schoolId}</strong> &nbsp;|&nbsp;
      الموقع: الرياض، المملكة العربية السعودية &nbsp;|&nbsp;
      تاريخ الإنشاء: ${new Date().toLocaleDateString('ar-SA')}
    </div>
    <div class="warning">
      ⚠️ <strong>تنبيه:</strong> هذه البيانات سرية. يُرجى تسليم كل موظف بياناته الخاصة فقط.
      كلمات المرور مؤقتة وسيُطلب من كل مستخدم تغييرها عند أول دخول.
    </div>
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>الاسم</th>
          <th>الدور</th>
          <th>المستخدم (كود الدخول)</th>
          <th>كلمة المرور المؤقتة</th>
        </tr>
      </thead>
      <tbody>
        ${rows}
      </tbody>
    </table>
    <div class="footer">
      منصة منار — نظام إدارة المدارس &nbsp;|&nbsp; etisak-784d6.web.app
    </div>
  </div>
</body>
</html>`;

  fs.writeFileSync('scripts/omar_school_credentials.html', html, 'utf8');
  console.log('✅ تم حفظ الجدول: scripts/omar_school_credentials.html');
}

main().catch(e => { console.error('❌ خطأ:', e); process.exit(1); });
