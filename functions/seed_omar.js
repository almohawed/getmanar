/**
 * seed_omar.js — Cloud Functions مساعدة
 * 1. seedOmarSchool — إنشاء مدرسة عمر بن أبي سلمة
 * 2. listGlobalAccounts — قراءة GlobalUsers للسوبر أدمن
 * 3. deleteSchoolSafe — حذف مدرسة بصلاحية السوبر أدمن
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
const auth = admin.auth();

// ─── Helper: التحقق من صلاحية Super Admin ────────────────────────────────────
async function assertSuperAdmin(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const doc = await db.collection('GlobalUsers').doc(context.auth.uid).get();
    const role = doc.exists ? doc.data().role : null;
    // السماح لـ superAdmin أو صاحب التطبيق
    const ownerEmails = ['mohawed32@getmanar.com', 'almohawed@gmail.com', 'mohwed32@getmanar.com'];
    const email = context.auth.token.email || '';
    if (role !== 'superAdmin' && !ownerEmails.includes(email.toLowerCase())) {
        throw new functions.https.HttpsError('permission-denied', 'Super Admin فقط');
    }
}

// ─── listGlobalAccounts ───────────────────────────────────────────────────────
exports.listGlobalAccounts = functions.https.onCall(async (data, context) => {
    await assertSuperAdmin(context);
    const snap = await db.collection('GlobalUsers').get();
    const users = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    return { users };
});

// ─── deleteSchoolSafe ─────────────────────────────────────────────────────────
exports.deleteSchoolSafe = functions
    .runWith({ timeoutSeconds: 300, memory: '512MB' })
    .https.onCall(async (data, context) => {
    await assertSuperAdmin(context);

    const { schoolId } = data || {};
    if (!schoolId) throw new functions.https.HttpsError('invalid-argument', 'schoolId مطلوب');

    console.log(`[deleteSchoolSafe] Starting deletion of school: ${schoolId}`);

    // 1. حذف sub-collections
    const collections = ['Staff', 'Teachers', 'Students', 'Parents', 'Classes',
        'Violations', 'BehaviorRecords', 'Notifications', 'Settings',
        'AcademicCalendar', 'System', 'SeedResults'];

    for (const col of collections) {
        try {
            const snap = await db.collection('Schools').doc(schoolId).collection(col).limit(500).get();
            if (!snap.empty) {
                const batch = db.batch();
                snap.docs.forEach(d => batch.delete(d.ref));
                await batch.commit();
                console.log(`[deleteSchoolSafe] Deleted ${snap.size} docs from ${col}`);
            }
        } catch (e) {
            console.warn(`[deleteSchoolSafe] Error deleting ${col}:`, e.message);
        }
    }

    // 2. حذف مستخدمي المدرسة من GlobalUsers + Firebase Auth
    try {
        const usersSnap = await db.collection('GlobalUsers')
            .where('schoolId', '==', schoolId).get();
        const batch = db.batch();
        const authDeletes = [];
        usersSnap.docs.forEach(doc => {
            batch.delete(doc.ref);
            authDeletes.push(
                auth.deleteUser(doc.id).catch(e =>
                    console.warn(`Auth delete failed for ${doc.id}:`, e.message))
            );
        });
        await batch.commit();
        await Promise.all(authDeletes);
        console.log(`[deleteSchoolSafe] Deleted ${usersSnap.size} users`);
    } catch (e) {
        console.warn('[deleteSchoolSafe] Error deleting users:', e.message);
    }

    // 3. حذف UserCodes المرتبطة
    try {
        const codesSnap = await db.collection('UserCodes')
            .where('schoolId', '==', schoolId).get();
        if (!codesSnap.empty) {
            const batch = db.batch();
            codesSnap.docs.forEach(d => batch.delete(d.ref));
            await batch.commit();
        }
    } catch (e) {
        console.warn('[deleteSchoolSafe] Error deleting UserCodes:', e.message);
    }

    // 4. حذف وثيقة المدرسة نفسها
    await db.collection('Schools').doc(schoolId).delete();
    console.log(`[deleteSchoolSafe] School ${schoolId} deleted successfully`);

    return { success: true, schoolId };
});

function genCode(prefix) {
    const d = Math.floor(100000 + Math.random() * 900000).toString();
    return `${prefix}${d}`;
}
function genPass(len = 8) {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let p = '';
    for (let i = 0; i < len; i++) p += c[Math.floor(Math.random() * c.length)];
    return p;
}
function phone(n) {
    if (!n) return null;
    n = n.replace(/\s/g, '');
    if (n.startsWith('05') && n.length === 10) return '+966' + n.slice(1);
    if (n.startsWith('5') && n.length === 9) return '+9665' + n.slice(1);
    return n;
}
function uuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0;
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
}

const TEACHERS = [
    { name: 'إبراهيم الوابل',       subject: 'لغتي',             hours: 21 },
    { name: 'احمد المهود',           subject: 'اجتماعيات',        hours: 19 },
    { name: 'بجاد العتيبي',          subject: 'تربية فنية',       hours: 19 },
    { name: 'بندر الدوسري',          subject: 'تربية بدنية',      hours: 24 },
    { name: 'خالد العتيبي',          subject: 'اجتماعيات',        hours: 24 },
    { name: 'راشد الشهري',           subject: 'تربية إسلامية',    hours: 24 },
    { name: 'سامي القحطاني',         subject: 'لغة إنجليزية',     hours: 24 },
    { name: 'سطام العضياني',         subject: 'برايل',            hours: 10 },
    { name: 'سعد آل',                subject: 'رياضيات',          hours: 24 },
    { name: 'سعود القريني',          subject: 'علوم',             hours: 12 },
    { name: 'سلطان الشنيفي',         subject: 'علوم',             hours: 12 },
    { name: 'سلطان العتيبي',         subject: 'رياضيات',          hours: 24 },
    { name: 'طلال الردادي',          subject: 'لغة إنجليزية',     hours: 24 },
    { name: 'طلال المهباش',          subject: 'تربية إسلامية',    hours: 15 },
    { name: 'عبدالرحمن الديوان',     subject: 'لغة إنجليزية',     hours: 24 },
    { name: 'عبدالرحمن الربيعة',     subject: 'تربية إسلامية',    hours: 21 },
    { name: 'عبدالعزيز العتيبي',     subject: 'رياضيات',          hours: 19 },
    { name: 'عبدالعزيز المهوس',      subject: 'لغة إنجليزية',     hours: 12 },
    { name: 'عبدالله المطيري',       subject: 'لغتي',             hours: 17 },
    { name: 'عبدالملك الشمري',       subject: 'تربية فنية',       hours: 19 },
    { name: 'عصام عز',               subject: 'لغتي',             hours: 11 },
    { name: 'علي الحربي',            subject: 'لغتي',             hours: 21 },
    { name: 'علي الغامدي',           subject: 'برايل',            hours: 5  },
    { name: 'عماد العتيبي',          subject: 'رياضيات',          hours: 19 },
    { name: 'فيصل العسيري',          subject: 'علوم',             hours: 17 },
    { name: 'فيصل القحطاني',         subject: 'تقنية رقمية',      hours: 21 },
    { name: 'ماجد الأسمري',          subject: 'تقنية رقمية',      hours: 22 },
    { name: 'متعب العتيبي',          subject: 'علوم',             hours: 21 },
    { name: 'محمد الحربي',           subject: 'رياضيات',          hours: 19 },
    { name: 'محمد العتيبي',          subject: 'لغتي',             hours: 19 },
    { name: 'محمد الفايز',           subject: 'تربية إسلامية',    hours: 21 },
    { name: 'مهنا الشيباني',         subject: 'رياضيات',          hours: 24 },
    { name: 'نايف الأدهم',           subject: 'تربية بدنية',      hours: 13 },
    { name: 'وليد العتيبي',          subject: 'اجتماعيات',        hours: 24 },
    { name: 'ياسر البقمي',           subject: 'علوم',             hours: 24 },
    { name: 'يوسف آل',               subject: 'تربية إسلامية',    hours: 24 },
];

const COUNSELORS = [
    { name: 'عبده',               phone: '0503677132', identity: '1234567890' },
    { name: 'فهد محمد الحربي',    phone: '0553204439', identity: '1008992313' },
    { name: 'فيصل نايف العتيبي', phone: '0566927918', identity: '1032678011' },
    { name: 'علي الشهراني',       phone: '0503117994', identity: '1025096999' },
];

const CLASSES = [
    { grade: 1, section: '1',   label: '1/1',   hours: 35 },
    { grade: 1, section: '2',   label: '1/2',   hours: 35 },
    { grade: 1, section: '3',   label: '1/3',   hours: 35 },
    { grade: 1, section: '4',   label: '1/4',   hours: 35 },
    { grade: 1, section: '5',   label: '1/5',   hours: 35 },
    { grade: 1, section: '6',   label: '1/6',   hours: 35 },
    { grade: 1, section: 'عوق', label: '1/عوق', hours: 21 },
    { grade: 2, section: '1',   label: '2/1',   hours: 35 },
    { grade: 2, section: '2',   label: '2/2',   hours: 35 },
    { grade: 2, section: '3',   label: '2/3',   hours: 35 },
    { grade: 2, section: '4',   label: '2/4',   hours: 35 },
    { grade: 2, section: '5',   label: '2/5',   hours: 35 },
    { grade: 2, section: '6',   label: '2/6',   hours: 35 },
    { grade: 2, section: 'عوق', label: '2/عوق', hours: 21 },
    { grade: 3, section: '1',   label: '3/1',   hours: 35 },
    { grade: 3, section: '2',   label: '3/2',   hours: 35 },
    { grade: 3, section: '3',   label: '3/3',   hours: 35 },
    { grade: 3, section: '4',   label: '3/4',   hours: 35 },
    { grade: 3, section: '5',   label: '3/5',   hours: 35 },
    { grade: 3, section: '6',   label: '3/6',   hours: 35 },
    { grade: 3, section: 'عوق', label: '3/عوق', hours: 21 },
];

exports.seedOmarSchool = functions.https.onCall(async (data, context) => {
    // Super Admin فقط
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    const callerDoc = await db.collection('GlobalUsers').doc(context.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().role !== 'superAdmin') {
        throw new functions.https.HttpsError('permission-denied', 'Super Admin فقط');
    }

    const results = [];
    const schoolId = uuid();
    const ts = admin.firestore.FieldValue.serverTimestamp();

    // ── 1. المدير ──────────────────────────────────────────────────────────
    const adminPass = genPass();
    const adminCode = genMNCode('AD');
    const adminEmail = 'omar.abn.abisalama@getmanar.com';
    let adminUid;
    try {
        const r = await auth.createUser({ email: adminEmail, password: adminPass, displayName: 'عمر عبدالله الأموي' });
        adminUid = r.uid;
    } catch (e) {
        if (e.code === 'auth/email-already-exists') {
            adminUid = (await auth.getUserByEmail(adminEmail)).uid;
        } else throw e;
    }
    const batch1 = db.batch();
    batch1.set(db.collection('Schools').doc(schoolId), {
        id: schoolId, name: 'مدرسة عمر بن أبي سلمة المتوسطة',
        type: 'government', stage: 'المتوسطة', city: 'الرياض',
        adminRegion: 'إدارة التعليم بمنطقة الرياض',
        ownerId: adminUid, countryCode: 'SA', policyVersion: 'v1',
        subscriptionPlan: 'elite', isLifetimeAccess: false,
        hasSpecialEducation: true, startTime: '07:00',
        daysPerWeek: 5, periodsPerDay: 7,
        showSubscriptionSection: true, createdAt: ts,
    });
    batch1.set(db.collection('GlobalUsers').doc(adminUid), {
        email: adminEmail, role: 'admin', schoolId,
        displayName: 'عمر عبدالله الأموي',
        phoneNumber: '+966555110822', mnCode: adminCode,
        isPasswordChangeRequired: true, isActive: true, createdAt: ts,
    });
    batch1.set(db.collection('UserCodes').doc(adminCode), {
        uid: adminUid, email: adminEmail, schoolId, role: 'admin',
        name: 'عمر عبدالله الأموي', prefix: 'AD', formatVersion: 2,
        createdAt: ts, isActive: true,
    });
    batch1.set(db.collection('Schools').doc(schoolId).collection('Staff').doc(adminUid), {
        uid: adminUid, name: 'عمر عبدالله الأموي', role: 'admin',
        email: adminEmail, mobile: '+966555110822', mnCode: adminCode,
        schoolId, isActive: true, createdAt: ts,
    });
    await batch1.commit();
    results.push({ name: 'عمر عبدالله الأموي', role: 'مدير المدرسة', username: adminCode, password: adminPass });

    // ── 2. الفصول ──────────────────────────────────────────────────────────
    const classBatch = db.batch();
    for (const cls of CLASSES) {
        const cid = uuid();
        const gradeLabel = cls.grade === 1 ? 'أول' : cls.grade === 2 ? 'ثاني' : 'ثالث';
        classBatch.set(db.collection('Schools').doc(schoolId).collection('Classes').doc(cid), {
            id: cid, name: cls.label, gradeLevel: cls.grade,
            sectionNumber: cls.section, preferredLabel: cls.label,
            stage: `${gradeLabel} متوسط`, periodsPerWeek: cls.hours,
            schoolId, isSpecialEducation: cls.section === 'عوق', createdAt: ts,
        });
    }
    await classBatch.commit();

    // ── 3. المعلمون (دفعات من 10) ──────────────────────────────────────────
    for (let i = 0; i < TEACHERS.length; i += 10) {
        const batch = db.batch();
        const chunk = TEACHERS.slice(i, i + 10);
        for (const t of chunk) {
            const uid = uuid();
            const pass = genPass();
            const code = genCode('TC');
            const email = `tc.${uid.slice(0, 8)}@getmanar.com`;
            try { await auth.createUser({ email, password: pass, displayName: t.name }); } catch (_) {}
            batch.set(db.collection('GlobalUsers').doc(uid), {
                email, role: 'teacher', schoolId, displayName: t.name,
                mnCode: code, isPasswordChangeRequired: true, isActive: true, createdAt: ts,
            });
            batch.set(db.collection('UserCodes').doc(code), {
                uid, email, schoolId, role: 'teacher', name: t.name,
                prefix: 'TC', formatVersion: 2, createdAt: ts, isActive: true,
            });
            batch.set(db.collection('Schools').doc(schoolId).collection('Teachers').doc(uid), {
                uid, name: t.name, role: 'teacher', email,
                primarySubjectId: t.subject, maxWeeklyClasses: t.hours,
                mnCode: code, schoolId, isActive: true, createdAt: ts,
            });
            results.push({ name: t.name, role: `معلم ${t.subject}`, username: code, password: pass });
        }
        await batch.commit();
    }

    // ── 4. المرشدون ────────────────────────────────────────────────────────
    const cBatch = db.batch();
    for (const c of COUNSELORS) {
        const uid = uuid();
        const pass = genPass();
        const code = genCode('CN');
        const ph = phone(c.phone);
        const email = `cn.${c.identity}@getmanar.com`;
        try { await auth.createUser({ email, password: pass, displayName: c.name }); } catch (_) {}
        cBatch.set(db.collection('GlobalUsers').doc(uid), {
            email, role: 'counselor', schoolId, displayName: c.name,
            phoneNumber: ph, identityNumber: c.identity,
            mnCode: code, isPasswordChangeRequired: true, isActive: true, createdAt: ts,
        });
        cBatch.set(db.collection('UserCodes').doc(code), {
            uid, email, schoolId, role: 'counselor', name: c.name,
            prefix: 'CN', formatVersion: 2, createdAt: ts, isActive: true,
        });
        cBatch.set(db.collection('Schools').doc(schoolId).collection('Staff').doc(uid), {
            uid, name: c.name, role: 'counselor', email,
            mobile: ph, identityNumber: c.identity,
            mnCode: code, schoolId, isActive: true, createdAt: ts,
        });
        results.push({ name: c.name, role: 'مرشد طلابي', username: code, password: pass });
    }
    await cBatch.commit();

    // ── 5. حفظ النتائج في Firestore للرجوع إليها ──────────────────────────
    await db.collection('SeedResults').doc(schoolId).set({
        schoolId, schoolName: 'مدرسة عمر بن أبي سلمة المتوسطة',
        createdAt: ts, staff: results,
    });

    return { success: true, schoolId, staffCount: results.length, staff: results };
});

// helper داخلي
function genMNCode(prefix) {
    const d = Math.floor(100000 + Math.random() * 900000).toString();
    return `${prefix}${d}`;
}
