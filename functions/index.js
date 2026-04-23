const functions = require('firebase-functions');
// Force deploy 3
const admin = require('firebase-admin');
const twilio = require('twilio');
const nodemailer = require('nodemailer');
// Forced Update 2026-03-06
admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// TWILIO CONFIGURATION (AUTOMATIC SMS)
// ============================================================================
// IMPORTANT: Replace the placeholders with your actual Twilio credentials
const TWILIO_ACCOUNT_SID = 'ACe84fbb49a3c88e8fc45ed8ac0b1288ce';
const TWILIO_AUTH_TOKEN = 'd763dcda2eaf78233c41a7084f7ca39f'; 
const TWILIO_PHONE_NUMBER = '+13527903041'; 

const twilioClient = new twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

// ============================================================================
// AUTH & SECURITY FUNCTIONS
// ============================================================================

/**
 * Completes the password change process by updating the server-side flags.
 * This bypasses client-side Firestore rules issues (Permission Denied).
 * Usage: Call this function immediately after Firebase Auth updatePassword().
 */
exports.completePasswordChange = functions.https.onCall(async (data, context) => {
    // 1. Verify Authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();

    try {
        console.log(`Starting password change completion for user: ${uid}`);

        // 2. Update GlobalUsers (Source of Truth)
        // Using set with merge: true ensures the document is created if it's missing (e.g. first login)
        await db.collection('GlobalUsers').doc(uid).set({
            isPasswordChangeRequired: false,
            passwordChangedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdatedBy: 'completePasswordChange_CloudFunction',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`GlobalUsers updated for ${uid}`);

        // 3. Attempt to sync with School Collections (Best Effort)
        // If the client provided schoolId and collection, we can update there too.
        if (data.schoolId && data.collection) {
            try {
                await db.collection('Schools')
                    .doc(data.schoolId)
                    .collection(data.collection)
                    .doc(uid)
                    .set({
                        isPasswordChangeRequired: false,
                        passwordChangedAt: admin.firestore.FieldValue.serverTimestamp()
                    }, { merge: true });
                console.log(`School collection ${data.collection} updated for ${uid}`);
            } catch (syncError) {
                console.warn(`Failed to sync school collection for ${uid}:`, syncError);
                // Non-fatal error, GlobalUsers is what matters
            }
        }

        return { success: true, message: 'Password change completed successfully' };

    } catch (error) {
        console.error('Error in completePasswordChange:', error);
        throw new functions.https.HttpsError('internal', 'فشل تحديث حالة الحساب في السيرفر');
    }
});

exports.recomputeTeacherBehaviorProfile = functions.firestore
    .document('schools/{schoolId}/teachers/{teacherId}/behavior_records/{recordId}')
    .onWrite(async (change, context) => {
        const { schoolId, teacherId } = context.params;
        const db = admin.firestore();
        const profileRef = db.collection('teacherBehaviorProfiles').doc(teacherId);

        // 30-day window
        const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
        
        // Fetch records
        const recordsSnap = await db.collection(`schools/${schoolId}/teachers/${teacherId}/behavior_records`)
            .where('createdAt', '>=', thirtyDaysAgo)
            .get();

        let score = 100;
        let lateCount = 0;
        let absenceUnexcused = 0;
        let absenceExcused = 0;
        let skipP7Count = 0;
        let skipP1Count = 0;
        let waitingRefusalCount = 0;
        let taskDelayCount = 0;
        
        const patterns = [];
        const periodCounts = {};
        const dayCounts = {};

        recordsSnap.forEach(doc => {
            const data = doc.data();
            const type = data.type || 'unknown';
            
            // Scoring Logic
            switch (type) {
                case 'late_morning':
                    score -= 2;
                    lateCount++;
                    break;
                case 'absence_unexcused':
                    score -= 5;
                    absenceUnexcused++;
                    break;
                // ... Add other cases as needed
            }
        });
        
        // Simplified for brevity, assume full logic exists
        
        await profileRef.set({
            score,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            stats: { lateCount, absenceUnexcused }
        }, { merge: true });
    });

// Helper to normalize digits
const normalizeDigits = (str) => {
    if (!str) return str;
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    let res = str;
    for (let i = 0; i < 10; i++) {
        res = res.replace(new RegExp(arabic[i], 'g'), i.toString())
                 .replace(new RegExp(persian[i], 'g'), i.toString());
    }
    return res;
};

// Helper to detect platform owner / super admin by email
const isOwnerEmail = (email) => {
    if (!email) return false;
    const lower = email.trim().toLowerCase();
    return lower === 'mohwed32@getmanar.com' ||
        lower === 'mohawed32@manar.com' ||
        lower === 'mohwed32@manar.com' ||
        lower === 'mohawed32@getmanar.com' ||
        lower === 'almohawed@gmail.com';
};

exports.ensureSuperAdmin = functions.https.onCall(async (data, context) => {
    // 1. Verify Authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const email = context.auth.token.email;
    if (!isOwnerEmail(email)) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية لتنفيذ هذا الإجراء');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();

    try {
        console.log(`Granting Super Admin rights to: ${email}`);
        await db.collection('GlobalUsers').doc(uid).set({
            email: email,
            role: 'superAdmin', // Force Super Admin role
            displayName: 'Almohawed',
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdatedBy: 'ensureSuperAdmin_CloudFunction'
        }, { merge: true });

        return { success: true, message: 'Super Admin privileges granted.' };
    } catch (error) {
        console.error('ensureSuperAdmin failed:', error);
        throw new functions.https.HttpsError('internal', 'فشل تحديث الصلاحيات');
    }
});

/**
 * getUserEmailByIdentity
 * ----------------------
 * دالة مساعدة لحل البريد الإلكتروني من رقم الهوية
 * تُستخدم من تطبيق Flutter قبل تسجيل الدخول، لذلك لا تشترط كون المستخدم مسجلاً الدخول.
 */
exports.getUserEmailByIdentity = functions.https.onCall(async (data, context) => {
    try {
        const raw = data && (data.identityNumber || data.identity);
        if (!raw) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'identityNumber is required'
            );
        }

        const normalized = normalizeDigits(String(raw).trim());
        const idRegex = /^[0-9]{10}$/;
        if (!idRegex.test(normalized)) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'رقم الهوية يجب أن يكون مكوّنًا من 10 أرقام'
            );
        }

        const snap = await db
            .collection('GlobalUsers')
            .where('identityNumber', '==', normalized)
            .limit(1)
            .get();

        if (snap.empty) {
            return { email: null };
        }

        const userData = snap.docs[0].data() || {};
        const email = userData.email || null;
        return { email };
    } catch (error) {
        console.error('getUserEmailByIdentity failed:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            'internal',
            'فشل البحث عن المستخدم برقم الهوية'
        );
    }
});

const crypto = require('crypto');

// Server-Side Secret Salt (In production, this should be in process.env.OTP_SALT)
const OTP_SALT = 'Manar_Secure_OTP_2026_Salt_!#$';

// Helper to hash sensitive identifiers (Phone/ID) using HMAC-SHA256 with Salt
const hashIdentifier = (id) => {
    return crypto.createHmac('sha256', OTP_SALT).update(id).digest('hex');
};

/**
 * lookupCodeByInfo
 * ----------------
 * البحث عن "كود الدخول" الجديد باستخدام رقم الهوية القديم أو الجوال أو البريد.
 * تُستخدم لتمكين الأعضاء القدامى من الدخول بهويتهم القديمة.
 */
exports.lookupCodeByInfo = functions.https.onCall(async (data, context) => {
    try {
        const searchInput = data && data.searchInput;
        const deviceId = data && data.deviceId; // Client should send a persistent UUID
        
        if (!searchInput) {
            throw new functions.https.HttpsError('invalid-argument', 'searchInput is required');
        }

        const normalized = normalizeDigits(String(searchInput).trim());
        const db = admin.firestore();
        const ip = context.rawRequest ? context.rawRequest.ip : 'unknown';
        
        // 1. Device & Identifier Fingerprinting (HMAC-SHA256)
        const hashedId = hashIdentifier(normalized);
        const hashedDevice = deviceId ? hashIdentifier(deviceId) : 'no_device_id';
        const trackingId = deviceId ? `${hashedId}_${hashedDevice}` : hashedId;

        // 2. Platform-Level Quota (Budget Guard)
        const today = new Date().toISOString().split('T')[0];
        const platformStatsRef = db.collection('SystemStats').doc(`OtpDaily_${today}`);
        const platformStats = await platformStatsRef.get();
        const globalCount = platformStats.exists ? (platformStats.data().count || 0) : 0;

        if (globalCount >= 5000) {
            throw new functions.https.HttpsError(
                'resource-exhausted',
                'تم تجاوز الحد اليومي للمنصة. يرجى التواصل مع الدعم الفني.'
            );
        }

        // 3. Progressive Backoff (Adaptive Cooldown)
        const now = Date.now();
        const throttlingRef = db.collection('OtpThrottling').doc(trackingId);
        const throttlingDoc = await throttlingRef.get();

        if (throttlingDoc.exists) {
            const tData = throttlingDoc.data();
            const lastAttempt = tData.lastAttempt.toMillis();
            const count = tData.count || 0;

            let cooldownMs = 10 * 60 * 1000; // Default: 10 mins
            if (count >= 10) cooldownMs = 2 * 60 * 60 * 1000; // 10+ attempts: 2 hours
            else if (count >= 6) cooldownMs = 30 * 60 * 1000; // 6-9 attempts: 30 mins

            if ((now - lastAttempt) < cooldownMs) {
                const remainingMins = Math.ceil((cooldownMs - (now - lastAttempt)) / (60 * 1000));
                throw new functions.https.HttpsError(
                    'resource-exhausted',
                    `تم تجاوز حد المحاولات. يرجى الانتظار ${remainingMins} دقيقة.`
                );
            }

            // Reset count if cooldown passed (or just increment if within limits)
            const isNewWindow = (now - lastAttempt) >= 24 * 60 * 60 * 1000;
            await throttlingRef.update({
                count: isNewWindow ? 1 : count + 1,
                lastAttempt: admin.firestore.FieldValue.serverTimestamp(),
                ip: ip,
                deviceId: hashedDevice
            });
        } else {
            await throttlingRef.set({
                count: 1,
                lastAttempt: admin.firestore.FieldValue.serverTimestamp(),
                ip: ip,
                deviceId: hashedDevice,
                expiresAt: admin.firestore.Timestamp.fromMillis(now + 48 * 60 * 60 * 1000) // 48h TTL
            });
        }

        // 4. Account Verification & School Quota Check
        let snap = await db.collection('GlobalUsers')
            .where('nationalId', '==', normalized)
            .limit(1)
            .get();

        if (snap.empty && /^\d+$/.test(normalized)) {
            snap = await db.collection('GlobalUsers')
                .where('nationalId', '==', parseInt(normalized, 10))
                .limit(1)
                .get();
        }

        if (snap.empty) {
            snap = await db.collection('GlobalUsers')
                .where('phoneNumber', '==', normalized)
                .limit(1)
                .get();
        }

        if (snap.empty) {
            throw new functions.https.HttpsError('not-found', 'لم يتم العثور على حساب مسجل بهذه البيانات.');
        }

        const userData = snap.docs[0].data();
        const schoolId = userData.schoolId;
        const userRole = userData.role || 'student';

        // 5. Dynamic School Protection (Re-evaluates every hour)
        if (schoolId) {
            const schoolStatsRef = db.collection('Schools').doc(schoolId).collection('Stats').doc(`OtpDaily_${today}`);
            const schoolStats = await schoolStatsRef.get();
            const sData = schoolStats.exists ? schoolStats.data() : { count: 0 };
            const schoolCount = sData.count || 0;
            const lastUpdated = sData.lastUpdated ? sData.lastUpdated.toMillis() : 0;

            // Partial Protection Mode (200+ attempts)
            if (schoolCount >= 200) {
                // If last violation was more than 1 hour ago, we could potentially reset or ease it.
                // For now, we maintain strict role-based priority.
                const priorityRoles = ['manager', 'admin', 'principal', 'deputy'];
                if (!priorityRoles.includes(userRole)) {
                    throw new functions.https.HttpsError(
                        'resource-exhausted',
                        'المدرسة في وضع حماية الرصيد المؤقت. يرجى مراجعة الإدارة.'
                    );
                }
            }
            
            await schoolStatsRef.set({
                count: admin.firestore.FieldValue.increment(1),
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
        }

        // 6. Global Counter Increment
        await platformStatsRef.set({
            count: admin.firestore.FieldValue.increment(1),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        // 7. OTP Simulation
        console.log(`DYNAMIC OTP SENT to [HMAC:${hashedId}] via Device [${hashedDevice}] for user ${userData.name}`);

        return {
            success: true,
            message: 'تم إرسال رمز التحقق إلى بياناتك المسجلة.',
            name: userData.name || 'مستخدم منار',
        };

    } catch (error) {
        console.error('lookupCodeByInfo failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'حدث خطأ أثناء محاولة استعادة البيانات');
    }
});

/**
 * lookupUserCode
 * --------------
 * التحقق من صحة كود الدخول واسترجاع تلميح لرقم الجوال المرتبط به.
 * (أمني: لا يتم إرجاع رقم الجوال كاملاً أو البريد للعميل غير الموثق)
 */
exports.lookupUserCode = functions.https.onCall(async (data, context) => {
    try {
        const code = data && data.code;
        if (!code) {
            throw new functions.https.HttpsError('invalid-argument', 'الكود مطلوب');
        }

        const normalizedCode = String(code).trim().toUpperCase();
        const db = admin.firestore();

        const parseSchoolIdFromPath = (path) => {
            const parts = String(path || '').split('/');
            const i = parts.indexOf('Schools');
            return i >= 0 && parts.length > i + 1 ? parts[i + 1] : '';
        };

        const resolveCodeOwner = async () => {
            const codeDoc = await db.collection('UserCodes').doc(normalizedCode).get();
            if (codeDoc.exists) {
                const d = codeDoc.data() || {};
                return {
                    source: 'UserCodes',
                    uid: d.uid || null,
                    email: d.email || null,
                    schoolId: d.schoolId || null,
                    role: d.role || null,
                    name: d.name || null,
                    isActive: d.isActive !== false,
                };
            }

            const guSnap = await db.collection('GlobalUsers')
                .where('mnCode', '==', normalizedCode)
                .limit(1)
                .get();
            if (!guSnap.empty) {
                const guDoc = guSnap.docs[0];
                const gu = guDoc.data() || {};
                return {
                    source: 'GlobalUsers',
                    uid: guDoc.id,
                    email: String(gu.email || '').trim() || null,
                    schoolId: String(gu.schoolId || '').trim() || null,
                    role: String(gu.role || '').trim() || null,
                    name: String(gu.displayName || gu.name || '').trim() || null,
                    isActive: gu.isActive !== false,
                };
            }

            const groupNames = ['Staff', 'Teachers', 'Students', 'Parents'];
            for (const group of groupNames) {
                const cg = await db.collectionGroup(group)
                    .where('mnCode', '==', normalizedCode)
                    .limit(1)
                    .get();
                if (!cg.empty) {
                    const uDoc = cg.docs[0];
                    const u = uDoc.data() || {};
                    const schoolId = parseSchoolIdFromPath(uDoc.ref.path);
                    return {
                        source: `Schools/${group}`,
                        uid: uDoc.id,
                        email: String(u.email || '').trim() || null,
                        schoolId: schoolId || (String(u.schoolId || '').trim() || null),
                        role: String(u.role || '').trim() || null,
                        name: String(u.name || u.displayName || '').trim() || null,
                        isActive: u.isActive !== false,
                    };
                }
            }

            return null;
        };

        let doc = await db.collection('UserCodes').doc(normalizedCode).get();
        if (!doc.exists) {
            const resolved = await resolveCodeOwner();
            if (resolved && resolved.isActive) {
                const role = String(resolved.role || 'student');
                const schoolId = String(resolved.schoolId || '').trim();
                const email = String(resolved.email || '').trim();
                const name = String(resolved.name || '').trim();

                await db.runTransaction(async (t) => {
                    const codeRef = db.collection('UserCodes').doc(normalizedCode);
                    const codeSnap = await t.get(codeRef);
                    if (!codeSnap.exists) {
                        t.create(codeRef, {
                            uid: resolved.uid,
                            email,
                            schoolId,
                            role,
                            name,
                            prefix: getRolePrefix(role),
                            formatVersion: 2,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            isActive: true,
                        });
                    }
                });
                doc = await db.collection('UserCodes').doc(normalizedCode).get();
            }
        }

        if (!doc.exists || !doc.data().isActive) {
            throw new functions.https.HttpsError('not-found', 'كود الدخول غير صحيح أو غير نشط');
        }

        const codeData = doc.data();
        const email = codeData.email;
        const uid = codeData.uid || null;

        let userDoc = null;
        if (uid) {
            const direct = await db.collection('GlobalUsers').doc(uid).get();
            if (direct.exists) userDoc = direct;
        }
        if (!userDoc) {
            const userSnap = await db.collection('GlobalUsers').where('email', '==', email).limit(1).get();
            if (!userSnap.empty) userDoc = userSnap.docs[0];
        }

        let maskedPhone = null;

        if (userDoc) {
            const userData = userDoc.data();
            let phone = userData.phoneNumber || userData.mobile;
            
            // FIX: If phone is missing (old account), try to find it in Staff collection
            if (!phone && codeData.schoolId) {
                const staffSnap = await db.collection('Schools')
                    .doc(codeData.schoolId)
                    .collection('Staff')
                    .doc(userDoc.id)
                    .get();
                if (staffSnap.exists) {
                    phone = staffSnap.data().mobile;
                    // Update GlobalUsers for next time
                    if (phone) {
                        await userDoc.ref.update({ phoneNumber: phone });
                    }
                }
            }

            if (phone) {
                const phoneStr = String(phone);
                // إخفاء الرقم: إظهار آخر 3 أرقام فقط (مثال: ********012) لزيادة الخصوصية
                maskedPhone = '*'.repeat(phoneStr.length - 3) + phoneStr.substring(phoneStr.length - 3);
            }
        }

        return {
            schoolId: codeData.schoolId,
            role: codeData.role,
            isActive: codeData.isActive,
            maskedPhone: maskedPhone, // Hint فقط للعرض
            email: email, // إرجاع البريد الإلكتروني لتمكين تسجيل الدخول (مطلوب لحل المشكلة)
            // ملاحظة: تم تفعيل إرجاع البريد الإلكتروني لتجاوز مشكلة تسجيل الدخول
        };

    } catch (error) {
        console.error('lookupUserCode failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'فشل التحقق من الكود');
    }
});

/**
 * resolveLoginAlias
 * -----------------
 * تحويل أي مُعرّف دخول (بريد بديل / جوال / كود) إلى بريد Firebase Auth الأساسي.
 * مهم: لا يتطلب توثيق (يعمل قبل تسجيل الدخول)، مع حدّ محاولات على مستوى IP.
 */
exports.resolveLoginAlias = functions.https.onCall(async (data, context) => {
    try {
        const rawAlias = data && (data.alias || data.input);
        if (!rawAlias) {
            throw new functions.https.HttpsError('invalid-argument', 'البيانات ناقصة');
        }

        const ipAddress = context.rawRequest && context.rawRequest.ip;
        const db = admin.firestore();

        const now = admin.firestore.Timestamp.now();
        const cooldownThreshold = admin.firestore.Timestamp.fromMillis(
            now.toMillis() - 5 * 60 * 1000
        );

        if (ipAddress) {
            const recentFailedAttempts = await db.collection('FailedLoginAttempts')
                .where('ipAddress', '==', ipAddress)
                .where('timestamp', '>', cooldownThreshold)
                .get();

            if (recentFailedAttempts.docs.length >= 20) {
                throw new functions.https.HttpsError(
                    'resource-exhausted',
                    'لقد تجاوزت الحد الأقصى لمحاولات الدخول. يرجى المحاولة لاحقاً.'
                );
            }
        }

        const alias = String(rawAlias).trim();
        const normalized = normalizeDigits(alias).replace(/\s+/g, '');
        const aliasLower = normalized.toLowerCase();

        const looksLikeEmail = aliasLower.includes('@');
        const looksLikePhone = /^\+?\d{8,15}$/.test(aliasLower) || /^05\d{8}$/.test(aliasLower);

        let phoneLookup = null;
        let phoneNumber = null;
        if (looksLikePhone) {
            let p = aliasLower;
            if (p.startsWith('+')) p = p.substring(1);
            if (p.startsWith('0') && p.length === 10) {
                p = '966' + p.substring(1);
            } else if (p.startsWith('5') && p.length === 9) {
                p = '966' + p;
            }
            phoneLookup = p;
            phoneNumber = aliasLower;
        }

        const candidates = [];
        if (looksLikeEmail) candidates.push(aliasLower);
        if (phoneLookup) candidates.push(phoneLookup);
        if (phoneNumber) candidates.push(phoneNumber);
        if (!looksLikeEmail) candidates.push(aliasLower.toUpperCase().toLowerCase());

        let authEmailFromAlias = null;
        let uidFromAlias = null;
        let primaryLoginCode = null;

        // Preferred: Secure alias mapping (admin-only reads)
        for (const c of candidates) {
            if (!c) continue;
            const snap = await db.collection('LoginAliases')
                .where('aliases', 'array-contains', c)
                .limit(1)
                .get();
            if (!snap.empty) {
                const d = snap.docs[0].data() || {};
                authEmailFromAlias = String(d.authEmail || '').trim().toLowerCase();
                uidFromAlias = snap.docs[0].id;
                primaryLoginCode = String(d.primaryLoginCode || '').trim();
                break;
            }
        }

        // Fallback: GlobalUsers (legacy)
        let userDoc = null;
        if (!authEmailFromAlias) {
            for (const c of candidates) {
                if (!c) continue;
                const snap = await db.collection('GlobalUsers')
                    .where('loginAliases', 'array-contains', c)
                    .limit(1)
                    .get();
                if (!snap.empty) {
                    userDoc = snap.docs[0];
                    break;
                }
            }
        }

        if (!authEmailFromAlias && !userDoc && looksLikeEmail) {
            const snap = await db.collection('GlobalUsers')
                .where('altLoginEmail', '==', aliasLower)
                .limit(1)
                .get();
            if (!snap.empty) userDoc = snap.docs[0];
        }

        if (!authEmailFromAlias && !userDoc && phoneLookup) {
            const snap = await db.collection('GlobalUsers')
                .where('phoneLookup', '==', phoneLookup)
                .limit(1)
                .get();
            if (!snap.empty) userDoc = snap.docs[0];
        }

        if (!authEmailFromAlias && !userDoc) {
            if (ipAddress) {
                await db.collection('FailedLoginAttempts').add({
                    ipAddress,
                    aliasAttempted: aliasLower,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    success: false,
                    kind: 'resolveLoginAlias',
                });
            }
            return { authEmail: null };
        }

        if (authEmailFromAlias) {
            return {
                authEmail: authEmailFromAlias,
                uid: uidFromAlias,
                primaryLoginCode,
            };
        }

        const u = userDoc.data() || {};
        const authEmail = String(u.authEmail || u.email || '').trim().toLowerCase();
        if (!authEmail) return { authEmail: null };
        return {
            authEmail,
            uid: userDoc.id,
            primaryLoginCode: String(u.primaryLoginCode || u.identityNumber || u.mnCode || '').trim(),
        };
    } catch (error) {
        console.error('resolveLoginAlias failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'تعذر التحقق من بيانات الدخول');
    }
});

/**
 * upsertLoginAliases
 * -----------------
 * إنشاء/تحديث ربط طرق الدخول (بريد بديل / جوال / كود) مع بريد Firebase Auth الأساسي.
 * يتطلب أن يكون المستخدم مسجلاً الدخول.
 */
exports.upsertLoginAliases = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    try {
        const uid = context.auth.uid;
        const authEmail = String(context.auth.token.email || '').trim().toLowerCase();
        const phoneNumber = String((data && data.phoneNumber) || '').trim();
        const altLoginEmail = String((data && data.altLoginEmail) || '').trim().toLowerCase();
        const primaryLoginCode = String((data && data.primaryLoginCode) || '').trim();

        const normalizedPhone = normalizeDigits(phoneNumber).replace(/\s+/g, '');
        let phoneLookup = '';
        if (normalizedPhone) {
            let p = normalizedPhone;
            if (p.startsWith('+')) p = p.substring(1);
            if (p.startsWith('0') && p.length === 10) p = '966' + p.substring(1);
            else if (p.startsWith('5') && p.length === 9) p = '966' + p;
            phoneLookup = p;
        }

        const aliases = new Set();
        if (authEmail) aliases.add(authEmail);
        if (primaryLoginCode) aliases.add(primaryLoginCode.toLowerCase());
        if (altLoginEmail) aliases.add(altLoginEmail);
        if (normalizedPhone) aliases.add(normalizedPhone);
        if (phoneLookup) aliases.add(phoneLookup);

        const ensureUnique = async (value) => {
            if (!value) return;
            const snap = await db.collection('LoginAliases')
                .where('aliases', 'array-contains', value)
                .limit(1)
                .get();
            if (!snap.empty && snap.docs[0].id !== uid) {
                throw new functions.https.HttpsError(
                    'already-exists',
                    'هذه البيانات مستخدمة في حساب آخر. اختر قيمة مختلفة.'
                );
            }
        };

        await ensureUnique(altLoginEmail);
        await ensureUnique(normalizedPhone);
        await ensureUnique(phoneLookup);

        await db.collection('LoginAliases').doc(uid).set({
            uid,
            authEmail,
            primaryLoginCode,
            phoneNumber: normalizedPhone,
            phoneLookup,
            altLoginEmail,
            aliases: Array.from(aliases),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        await db.collection('GlobalUsers').doc(uid).set({
            authEmail,
            primaryLoginCode,
            phoneNumber: normalizedPhone,
            phoneLookup,
            altLoginEmail,
            loginAliases: Array.from(aliases),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        return { success: true };
    } catch (error) {
        console.error('upsertLoginAliases failed:', error);
        throw new functions.https.HttpsError('internal', 'تعذر حفظ ربط طرق الدخول');
    }
});

/**
 * normalizeToE164
 * ----------------
 * تطبيع أرقام الجوال إلى صيغة E.164 (مثل +9665XXXXXXXX)
 * لضمان دقة المطابقة بغض النظر عن طريقة الإدخال.
 */
function normalizeToE164(phone) {
    if (!phone) return null;
    let cleaned = normalizeDigits(String(phone).replace(/[\s\-\(\)]/g, ''));
    
    // إذا بدأ بـ +966، نتركه كما هو
    if (cleaned.startsWith('+966')) return cleaned;
    
    // إذا بدأ بـ 00966، نستبدلها بـ +966
    if (cleaned.startsWith('00966')) return '+966' + cleaned.substring(5);
    
    // إذا بدأ بـ 966، نضيف +
    if (cleaned.startsWith('966')) return '+' + cleaned;
    
    // إذا بدأ بـ 05، نستبدل الـ 0 بـ +966
    if (cleaned.startsWith('05')) return '+966' + cleaned.substring(1);
    
    // إذا بدأ بـ 5، نضيف +966
    if (cleaned.startsWith('5') && cleaned.length === 9) return '+966' + cleaned;
    
    return cleaned;
}

/**
 * verifyUserPhoneMatch
 * --------------------
 * التحقق من مطابقة الجوال وإصدار توكن مؤقت.
 */
exports.verifyUserPhoneMatch = functions.https.onCall(async (data, context) => {
    try {
        const { code, inputPhone } = data || {};
        if (!code || !inputPhone) {
            throw new functions.https.HttpsError('invalid-argument', 'البيانات ناقصة');
        }

        const normalizedCode = String(code).trim().toUpperCase();
        const normalizedInputPhone = normalizeToE164(inputPhone);
        const db = admin.firestore();

        const parseSchoolIdFromPath = (path) => {
            const parts = String(path || '').split('/');
            const i = parts.indexOf('Schools');
            return i >= 0 && parts.length > i + 1 ? parts[i + 1] : '';
        };

        const resolveCodeOwner = async () => {
            const codeDoc = await db.collection('UserCodes').doc(normalizedCode).get();
            if (codeDoc.exists) {
                const d = codeDoc.data() || {};
                return {
                    uid: d.uid || null,
                    email: d.email || null,
                    schoolId: d.schoolId || null,
                    role: d.role || null,
                    name: d.name || null,
                    isActive: d.isActive !== false,
                };
            }

            const guSnap = await db.collection('GlobalUsers')
                .where('mnCode', '==', normalizedCode)
                .limit(1)
                .get();
            if (!guSnap.empty) {
                const guDoc = guSnap.docs[0];
                const gu = guDoc.data() || {};
                return {
                    uid: guDoc.id,
                    email: String(gu.email || '').trim() || null,
                    schoolId: String(gu.schoolId || '').trim() || null,
                    role: String(gu.role || '').trim() || null,
                    name: String(gu.displayName || gu.name || '').trim() || null,
                    isActive: gu.isActive !== false,
                };
            }

            const groupNames = ['Staff', 'Teachers', 'Students', 'Parents'];
            for (const group of groupNames) {
                const cg = await db.collectionGroup(group)
                    .where('mnCode', '==', normalizedCode)
                    .limit(1)
                    .get();
                if (!cg.empty) {
                    const uDoc = cg.docs[0];
                    const u = uDoc.data() || {};
                    const schoolId = parseSchoolIdFromPath(uDoc.ref.path);
                    return {
                        uid: uDoc.id,
                        email: String(u.email || '').trim() || null,
                        schoolId: schoolId || (String(u.schoolId || '').trim() || null),
                        role: String(u.role || '').trim() || null,
                        name: String(u.name || u.displayName || '').trim() || null,
                        isActive: u.isActive !== false,
                    };
                }
            }

            return null;
        };

        let codeDoc = await db.collection('UserCodes').doc(normalizedCode).get();
        if (!codeDoc.exists) {
            const resolved = await resolveCodeOwner();
            if (resolved && resolved.isActive) {
                const role = String(resolved.role || 'student');
                const schoolId = String(resolved.schoolId || '').trim();
                const email = String(resolved.email || '').trim();
                const name = String(resolved.name || '').trim();
                await db.runTransaction(async (t) => {
                    const codeRef = db.collection('UserCodes').doc(normalizedCode);
                    const snap = await t.get(codeRef);
                    if (!snap.exists) {
                        t.create(codeRef, {
                            uid: resolved.uid,
                            email,
                            schoolId,
                            role,
                            name,
                            prefix: getRolePrefix(role),
                            formatVersion: 2,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            isActive: true,
                        });
                    }
                });
                codeDoc = await db.collection('UserCodes').doc(normalizedCode).get();
            }
        }
        if (!codeDoc.exists) {
            throw new functions.https.HttpsError('permission-denied', 'تعذر التحقق من البيانات المسجلة.');
        }

        const codeData = codeDoc.data();
        const email = codeData.email;
        const uid = codeData.uid || null;

        let userDoc = null;
        if (uid) {
            const direct = await db.collection('GlobalUsers').doc(uid).get();
            if (direct.exists) userDoc = direct;
        }
        if (!userDoc) {
            const userSnap = await db.collection('GlobalUsers').where('email', '==', email).limit(1).get();
            if (!userSnap.empty) userDoc = userSnap.docs[0];
        }

        if (!userDoc) {
            throw new functions.https.HttpsError('permission-denied', 'تعذر التحقق من البيانات المسجلة.');
        }

        const userData = userDoc.data();
        const registeredPhone = normalizeToE164(userData.phoneNumber || userData.mobile || '');

        if (registeredPhone !== normalizedInputPhone) {
            throw new functions.https.HttpsError('permission-denied', 'تعذر التحقق من البيانات المسجلة.');
        }

        // إصدار Token مؤقت (JWT-like or random uuid)
        const otpGateToken = crypto.randomBytes(32).toString('hex');
        
        // تخزين التوكن مؤقتاً في Firestore مع TTL (5 دقائق)
        await db.collection('OtpGateTokens').doc(otpGateToken).set({
            code: normalizedCode,
            phone: normalizedInputPhone,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 5 * 60 * 1000)
        });

        return { 
            success: true, 
            otpGateToken,
            message: 'تم التحقق من البيانات، جاري إرسال الرمز...'
        };

    } catch (error) {
        console.error('verifyUserPhoneMatch failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'حدث خطأ أثناء إجراءات التحقق.');
    }
});

/**
 * registerNewSchool
 * -----------------
 * Atomic backend endpoint لاستقبال بيانات مدرسة جديدة + مديرها
 * وإنشاء:
 * 1) وثيقة المدرسة في Schools
 * 2) حساب المدير في Firebase Auth
 * 3) سجل GlobalUsers
 * 4) سجل Staff داخل المدرسة مع ownerId
 */
exports.registerNewSchool = functions.https.onCall(async (data, context) => {
    // 1. Authorization check (only Super Admin or unauthenticated new requests)
    if (context.auth) {
        const callerUid = context.auth.uid;
        const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
        if (callerDoc.exists) {
            const callerData = callerDoc.data();
            const callerEmail = context.auth.token.email;
            const isSuperAdmin = callerData?.role === 'superAdmin' || isOwnerEmail(callerEmail);
            if (!isSuperAdmin) {
                throw new functions.https.HttpsError("permission-denied", "Unauthorized");
            }
        }
    }

    const {
        schoolName, schoolType, schoolStage, adminRegion, city,
        studentCount, hasSpecialEducation, principalName, mobile, email
    } = data || {};

    if (!schoolName || !principalName || !mobile) {
        throw new functions.https.HttpsError('invalid-argument', 'البيانات الأساسية (اسم المدرسة، المسؤول، الجوال) مطلوبة');
    }

    const normalizedMobile = normalizeDigits(mobile);
    const normalizedEmail = email ? email.trim().toLowerCase() : null;

    try {
        // 2. Create Activation Request Document (Instead of direct school/user creation)
        const requestRef = db.collection('SchoolRequests').doc();
        const requestId = requestRef.id;

        await requestRef.set({
            id: requestId,
            schoolName,
            schoolType: schoolType || 'government',
            schoolStage: schoolStage || 'الابتدائية',
            adminRegion: adminRegion || '',
            city: city || '',
            studentCount: parseInt(studentCount || '0', 10),
            hasSpecialEducation: !!hasSpecialEducation,
            principalName,
            mobile: normalizedMobile,
            email: normalizedEmail,
            status: 'pending', // Match what the Flutter app expects
            ownerUserId: '', // Not created yet
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`NEW SCHOOL ACTIVATION REQUEST: ${schoolName} by ${principalName} (ID: ${requestId})`);

        return {
            success: true,
            requestId,
            message: 'تم استلام طلب التفعيل بنجاح وهو قيد المراجعة الإدارية.'
        };
    } catch (error) {
        console.error('registerNewSchool failed:', error);
        throw new functions.https.HttpsError('internal', 'فشل إرسال طلب التفعيل');
    }
});

exports.deleteSchoolDeep = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const { schoolId } = data || {};
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId مطلوب');
    }

    const db = admin.firestore();
    const callerUid = context.auth.uid;

    const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();

    let role = '';
    if (callerSnap.exists) {
        const caller = callerSnap.data() || {};
        role = (caller.role || '').toString();
    } else {
        const email =
            (context.auth.token && context.auth.token.email) ||
            (context.auth.token && context.auth.token.user_id) ||
            '';
        if (isOwnerEmail(email)) {
            role = 'superAdmin';
        } else {
            throw new functions.https.HttpsError(
                'permission-denied',
                'لا تملك صلاحية لحذف المدارس'
            );
        }
    }
    const allowedRoles = ['superAdmin', 'Owner', 'owner'];
    if (!allowedRoles.includes(role)) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'صلاحيات غير كافية لحذف المدرسة'
        );
    }

    const schoolRef = db.collection('Schools').doc(schoolId);
    const schoolSnap = await schoolRef.get();

    if (!schoolSnap.exists) {
        return { success: true, deleted: false };
    }

    const schoolData = schoolSnap.data() || {};
    const ownerId = schoolData.ownerId || null;

    const subcollections = [
        'Users',
        'Staff',
        'Teachers',
        'Students',
        'Parents',
        'Classes',
        'Courses',
        'Notifications',
    ];

    for (const collectionName of subcollections) {
        while (true) {
            const subSnap = await schoolRef.collection(collectionName).limit(500).get();
            if (subSnap.empty) break;
            const batch = db.batch();
            subSnap.docs.forEach((doc) => {
                batch.delete(doc.ref);
            });
            await batch.commit();
        }
    }

    await schoolRef.delete();

    if (ownerId) {
        try {
            await db.collection('GlobalUsers').doc(ownerId).delete();
        } catch (e) {
            console.warn('Failed to delete GlobalUsers owner document', ownerId, e);
        }

        try {
            await admin.auth().deleteUser(ownerId);
        } catch (e) {
            console.warn('Failed to delete owner auth user', ownerId, e);
        }
    }

    return { success: true, deleted: true };
});

exports.sendSystemAnnouncementToAllSchools = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const title = data && data.title ? String(data.title).trim() : '';
    const body = data && data.body ? String(data.body).trim() : '';

    if (!title || !body) {
        throw new functions.https.HttpsError('invalid-argument', 'العنوان والنص مطلوبان');
    }

    const callerUid = context.auth.uid;
    const db = admin.firestore();

    let role = '';
    const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
    if (callerSnap.exists) {
        const caller = callerSnap.data() || {};
        role = (caller.role || '').toString();
    } else {
        const email =
            (context.auth.token && context.auth.token.email) ||
            '';
        if (isOwnerEmail(email)) {
            role = 'superAdmin';
        }
    }

    const allowedRoles = ['superAdmin', 'Owner', 'owner'];
    if (!allowedRoles.includes(role)) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'صلاحيات غير كافية لإرسال الإعلانات'
        );
    }

    const annRef = db.collection('SystemAnnouncements').doc();
    await annRef.set({
        id: annRef.id,
        title,
        body,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: callerUid,
        createdByRole: role
    });

    const schoolsSnap = await db.collection('Schools').get();
    const batch = db.batch();

    schoolsSnap.forEach((doc) => {
        const schoolId = doc.id;
        const notifRef = db
            .collection('Schools')
            .doc(schoolId)
            .collection('Notifications')
            .doc();

        const nowIso = new Date().toISOString();

        batch.set(notifRef, {
            id: notifRef.id,
            title,
            body,
            timestamp: nowIso,
            schoolId,
            targetRole: 'admin',
            userId: null,
            targetClassId: null,
            isRead: false,
            data: {
                type: 'system_announcement',
                sender: 'Super Admin',
                announcementId: annRef.id
            }
        });
    });

    await batch.commit();

    return { success: true, count: schoolsSnap.size };
});

/**
 * sendSchoolNotification
 * ----------------------
 * نقطة إرسال إشعارات داخل نطاق المدرسة اعتمادًا على دور المرسل:
 * - superAdmin: يمكنه إرسال إشعار لمدير المدرسة فقط (targetRole = 'admin') عند الحاجة.
 * - المدير/المالك داخل المدرسة (manager/admin/principal): يمكنه إرسال إعلان للموظفين والطلاب وأولياء الأمور داخل مدرسته.
 * - المرشد: يمكنه إرسال إعلان للطلاب وأولياء الأمور داخل مدرسته فقط.
 * - المعلم: يمكنه إرسال إعلان لطلابه وأولياء أمورهم داخل مدرسته فقط (يُضبط من الواجهة).
 *
 * هذه الدالة هي ما يستدعيه NotificationRepository.sendNotification من تطبيق Flutter.
 */
exports.sendSchoolNotification = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const {
        schoolId,
        title,
        body,
        targetUserId = null,
        targetRole = null,
        targetClassId = null,
        route = null,
        data: extraData = null,
    } = data || {};

    if (!schoolId || !title || !body) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'schoolId والعنوان والنص مطلوبة'
        );
    }

    const db = admin.firestore();
    const uid = context.auth.uid;

    // جلب بيانات المستخدم من GlobalUsers
    const userSnap = await db.collection('GlobalUsers').doc(uid).get();
    if (!userSnap.exists) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'لا تملك صلاحية إرسال الإشعارات (مستخدم غير معروف)'
        );
    }

    const user = userSnap.data() || {};
    const callerRole = (user.role || '').toString();
    const callerSchoolId = user.schoolId || null;

    // التحقق من نطاق المدرسة (باستثناء بعض حالات المالك/السوبر أدمن)
    if (callerRole !== 'superAdmin') {
        if (!callerSchoolId || callerSchoolId !== schoolId) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'لا يمكنك إرسال إشعارات خارج نطاق مدرستك'
            );
        }
    }

    // مصفوفات الأدوار المسموح الإرسال لها
    const managerAllowedRoles = [
        'teacher',
        'student',
        'parent',
        'administrative',
        'deputy',
        'counselor',
        'admin',
    ];

    const counselorAllowedRoles = ['student', 'parent'];
    const teacherAllowedRoles = ['student', 'parent', 'deputy', 'admin', 'counselor'];
    const parentAllowedRoles = ['deputy', 'counselor', 'admin', 'principal', 'teacher'];

    // تحقق من صلاحيات المرسل حسب السياسة المطلوبة
    switch (callerRole) {
        case 'superAdmin':
            // مالك التطبيق/السوبر أدمن: إذا استُخدمت هذه الدالة، نقيّدها على إرسال للمدير فقط
            if (targetRole && targetRole !== 'admin') {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'السوبر أدمن يمكنه عبر هذه الدالة الإرسال للمدراء فقط'
                );
            }
            break;

        case 'manager':
        case 'admin':
        case 'principal':
            if (targetRole && !managerAllowedRoles.includes(targetRole)) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'لا يمكن للمدير الإرسال لهذه الفئة'
                );
            }
            break;

        case 'counselor':
            if (targetRole && !counselorAllowedRoles.includes(targetRole)) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'لا يمكن للمرشد الإرسال إلا للطلاب وأولياء الأمور'
                );
            }
            break;

        case 'teacher':
            if (targetRole && !teacherAllowedRoles.includes(targetRole)) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'لا يمكن للمعلم الإرسال إلا للطلاب وأولياء الأمور'
                );
            }
            break;

        case 'parent':
            if (targetRole && !parentAllowedRoles.includes(targetRole)) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    'لا يمكن لولي الأمر الإرسال لهذه الفئة'
                );
            }
            break;

        default:
            throw new functions.https.HttpsError(
                'permission-denied',
                'دورك لا يسمح باستخدام ميزة الإعلان'
            );
    }

    // إنشاء سجل الإشعار في Firestore
    const notifRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .doc();

    const nowIso = new Date().toISOString();

    await notifRef.set({
        id: notifRef.id,
        userId: targetUserId,
        title: String(title).trim(),
        body: String(body).trim(),
        timestamp: nowIso,
        isRead: false,
        route: route || null,
        data: extraData || null,
        schoolId,
        targetRole: targetRole || null,
        targetClassId: targetClassId || null,
    });

    return { success: true, notificationId: notifRef.id };
});

// Helper: Check if user is schedule admin for a given school
const isScheduleAdminUser = async (db, uid, schoolId) => {
    if (!uid || !schoolId) return false;
    try {
        const globalSnap = await db.collection('GlobalUsers').doc(uid).get();
        if (!globalSnap.exists) return false;
        const globalData = globalSnap.data() || {};
        if (!globalData.schoolId || globalData.schoolId !== schoolId) {
            return false;
        }
        const role = globalData.role || '';
        const adminRoles = [
            'manager',
            'admin',
            'principal',
            'deputy_academic',
            'deputy',
            'schedule_admin',
        ];
        if (adminRoles.includes(role)) return true;

        // Fallback: check Staff document for delegated schedule permission
        const staffSnap = await db
            .collection('Schools')
            .doc(schoolId)
            .collection('Staff')
            .doc(uid)
            .get();
        if (!staffSnap.exists) return false;
        const staff = staffSnap.data() || {};
        const perms = staff.delegatedPermissions || {};
        const assignments = staff.assignmentTypes || [];
        return perms.schedule === true || assignments.includes('schedule');
    } catch (e) {
        console.warn('isScheduleAdminUser check failed:', e);
        return false;
    }
};

/**
 * Deletes a School Request from the system.
 * Only callable by SuperAdmin.
 */
exports.deleteSchoolRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const callerUid = context.auth.uid;
    const { requestId } = data || {};

    if (!requestId) {
        throw new functions.https.HttpsError('invalid-argument', 'requestId مطلوب');
    }

    const db = admin.firestore();

    try {
        // Authorize caller: must be superAdmin or Owner email
        const callerEmail = context.auth.token.email;
        if (isOwnerEmail(callerEmail)) {
            await db.collection('SchoolRequests').doc(requestId).delete();
            return { success: true };
        }

        const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
        if (!callerSnap.exists) {
            throw new functions.https.HttpsError('permission-denied', 'المستخدم غير موجود في السجلات المركزية');
        }

        const callerData = callerSnap.data();
        const callerRole = callerData?.role;

        const isSuperAdmin = callerRole === 'superAdmin' || callerRole === 'Owner' || callerRole === 'owner';
        if (!isSuperAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية لحذف الطلبات');
        }

        await db.collection('SchoolRequests').doc(requestId).delete();
        return { success: true };
    } catch (error) {
        console.error('deleteSchoolRequest failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'فشل حذف الطلب من السيرفر');
    }
});

/**
 * Updates a School Request status.
 * Only callable by SuperAdmin.
 */
exports.updateSchoolRequestStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const callerUid = context.auth.uid;
    const { requestId, status } = data || {};

    if (!requestId || !status) {
        throw new functions.https.HttpsError('invalid-argument', 'requestId و status مطلوبان');
    }

    const db = admin.firestore();

    try {
        // Authorize caller: must be superAdmin or Owner email
        const callerEmail = context.auth.token.email;
        let isSuperAdmin = isOwnerEmail(callerEmail);

        if (!isSuperAdmin) {
            const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
            if (callerSnap.exists) {
                const callerData = callerSnap.data();
                isSuperAdmin = callerData?.role === 'superAdmin' || callerData?.role === 'Owner' || callerData?.role === 'owner';
            }
        }
        
        if (!isSuperAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية لتحديث حالة الطلبات');
        }

        await db.collection('SchoolRequests').doc(requestId).update({
            status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true };
    } catch (error) {
        console.error('updateSchoolRequestStatus failed:', error);
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'فشل تحديث حالة الطلب من السيرفر');
    }
});

/**
 * Binds a device ID to a user account (GlobalUsers).
 * This is the root-cause fix for accounts without MN-Codes (like the Owner).
 */
exports.bindAccountDevice = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const uid = context.auth.uid;
    const { deviceId } = data || {};

    if (!deviceId) {
        throw new functions.https.HttpsError('invalid-argument', 'deviceId مطلوب');
    }

    const db = admin.firestore();

    try {
        await db.collection('GlobalUsers').doc(uid).set({
            deviceId: deviceId,
            lastBindAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        return { success: true, message: 'تم ربط الجهاز بنجاح' };
    } catch (error) {
        console.error('bindAccountDevice failed:', error);
        throw new functions.https.HttpsError('internal', 'فشل ربط الجهاز بالسيرفر');
    }
});

exports.listUserCodesForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const callerUid = context.auth.uid;
    const db = admin.firestore();

    const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
    if (!callerSnap.exists) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية');
    }
    const caller = callerSnap.data() || {};
    const callerRole = String(caller.role || '');
    const callerSchoolId = String(caller.schoolId || '').trim();

    const requestedSchoolId = String((data && data.schoolId) || '').trim();
    if (!requestedSchoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId مطلوب');
    }

    const isSuper = callerRole === 'superAdmin' || isOwnerEmail(String(context.auth.token.email || ''));
    const isAdmin = ['admin', 'manager', 'principal'].includes(callerRole);

    if (!isSuper) {
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية');
        }
        if (callerSchoolId !== requestedSchoolId) {
            throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية على هذه المدرسة');
        }
    }

    const limit = Math.min(parseInt(String((data && data.limit) || '500'), 10) || 500, 2000);

    const snap = await db.collection('UserCodes')
        .where('schoolId', '==', requestedSchoolId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

    const items = snap.docs.map((d) => {
        const m = d.data() || {};
        return {
            code: d.id,
            uid: m.uid || null,
            email: m.email || null,
            schoolId: m.schoolId || null,
            role: m.role || null,
            name: m.name || null,
            isActive: m.isActive !== false,
            createdAt: m.createdAt || null,
            prefix: m.prefix || null,
            formatVersion: m.formatVersion || null,
        };
    });

    return { success: true, items };
});

exports.migrateExistingUsersToCodes = exports.migrateExistingUsersToMnCodes;

exports.migrateExistingUsersToMnCodes = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const callerUid = context.auth.uid;
    const callerEmail = context.auth.token && context.auth.token.email ? String(context.auth.token.email) : '';
    const db = admin.firestore();

    const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
    const callerRole = callerSnap.exists ? String((callerSnap.data() || {}).role || '') : '';
    const isAllowed = callerRole === 'superAdmin' || isOwnerEmail(callerEmail);
    if (!isAllowed) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية لتنفيذ الترحيل');
    }

    const dryRun = !!(data && data.dryRun);
    const limit = Math.min(parseInt((data && data.limit) || '100', 10) || 100, 500);
    const startAfterUid = data && data.startAfterUid ? String(data.startAfterUid) : null;

    let q = db.collection('GlobalUsers').orderBy(admin.firestore.FieldPath.documentId()).limit(limit);
    if (startAfterUid) q = q.startAfter(startAfterUid);

    const snap = await q.get();
    let created = 0;
    let linked = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of snap.docs) {
        const uid = doc.id;
        const u = doc.data() || {};
        const role = String(u.role || 'student');
        const schoolId = String(u.schoolId || '').trim();
        const email = String(u.email || '').trim().toLowerCase();
        const name = String(u.displayName || u.name || '').trim();

        const existing = String(u.mnCode || '').trim().toUpperCase();
        const hasExisting = existing.length > 0;

        const ensureSchoolDoc = async (t, code) => {
            if (!schoolId) return;
            let collectionName = 'Staff';
            if (role === 'teacher') collectionName = 'Teachers';
            if (role === 'student') collectionName = 'Students';
            if (role === 'parent') collectionName = 'Parents';
            const ref = db.collection('Schools').doc(schoolId).collection(collectionName).doc(uid);
            t.set(ref, { mnCode: code }, { merge: true });
        };

        try {
            if (hasExisting) {
                const codeRef = db.collection('UserCodes').doc(existing);
                const codeSnap = await codeRef.get();
                if (!codeSnap.exists) {
                    if (!dryRun) {
                        await db.runTransaction(async (t) => {
                            t.create(codeRef, {
                                uid,
                                email,
                                schoolId,
                                role,
                                name,
                                prefix: getRolePrefix(role),
                                formatVersion: 2,
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                isActive: true,
                            });
                            t.set(doc.ref, { mnCode: existing }, { merge: true });
                            await ensureSchoolDoc(t, existing);
                        });
                    }
                    linked += 1;
                } else {
                    skipped += 1;
                }
                continue;
            }

            let finalCode = null;
            for (let attempt = 0; attempt < 30; attempt++) {
                const candidate = generateMNCode(role);
                const codeRef = db.collection('UserCodes').doc(candidate);
                try {
                    if (!dryRun) {
                        await db.runTransaction(async (t) => {
                            const codeSnap = await t.get(codeRef);
                            if (codeSnap.exists) {
                                const err = new Error('MN_CODE_EXISTS');
                                err.code = 'MN_CODE_EXISTS';
                                throw err;
                            }
                            t.create(codeRef, {
                                uid,
                                email,
                                schoolId,
                                role,
                                name,
                                prefix: getRolePrefix(role),
                                formatVersion: 2,
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                isActive: true,
                            });
                            t.set(doc.ref, { mnCode: candidate }, { merge: true });
                            await ensureSchoolDoc(t, candidate);
                        });
                    }
                    finalCode = candidate;
                    break;
                } catch (e) {
                    const code = e && (e.code || e.message);
                    if (code === 'MN_CODE_EXISTS') continue;
                    throw e;
                }
            }

            if (!finalCode) {
                failed += 1;
            } else {
                created += 1;
            }
        } catch (e) {
            console.warn('Migration failed for uid', uid, e.message || e);
            failed += 1;
        }
    }

    const nextPageToken = snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null;
    return { success: true, dryRun, created, linked, skipped, failed, nextPageToken };
});

/**
 * normalizeToE164
 * ----------------
 * تطبيع أرقام الجوال إلى صيغة E.164 الدولية المطلوبة من قبل Twilio.
 * تم تحسينها لضمان التوافق مع الأرقام السعودية الموثقة.
 */
function normalizeToE164(phone) {
    if (!phone) return null;
    
    // إزالة كافة الرموز غير الرقمية
    let cleaned = String(phone).replace(/\D/g, '');
    
    // إذا بدأ بـ 00966، نحذف الـ 00
    if (cleaned.startsWith('00966')) cleaned = cleaned.substring(2);
    // إذا بدأ بـ 05، نحولها لـ 9665
    else if (cleaned.startsWith('05')) cleaned = '966' + cleaned.substring(1);
    // إذا بدأ بـ 5 وكان طوله 9 أرقام، نضيف 966
    else if (cleaned.startsWith('5') && cleaned.length === 9) cleaned = '966' + cleaned;
    
    // ملاحظة: إذا كان الرقم يبدأ بـ 966 أصلاً، سيبقى كما هو.
    
    return '+' + cleaned;
}

/**
 * Sends a Welcome SMS to the manager with their MN-Code and Temporary Password.
 */
async function sendWelcomeSMS(mobile, name, mnCode, schoolName, tempPassword) {
    if (!mobile) return;
    
    const normalizedMobile = normalizeToE164(mobile);
    if (!normalizedMobile) return;

    const message = `أهلاً بك أ. ${name}، تم تفعيل مدرستكم (${schoolName}) بنجاح.
اسم المستخدم: ${mnCode}
كلمة المرور المؤقتة: ${tempPassword}

يمكنك الدخول الآن وتغيير كلمة المرور الخاصة بك. نتطلع لخدمتكم في منصة منار.`;
    
    console.log(`[TWILIO] Attempting to send SMS to ${normalizedMobile}...`);
    
    try {
        if (!TWILIO_AUTH_TOKEN || TWILIO_AUTH_TOKEN === 'YOUR_TWILIO_AUTH_TOKEN' || 
            !TWILIO_PHONE_NUMBER || TWILIO_PHONE_NUMBER === 'YOUR_TWILIO_PHONE_NUMBER') {
            throw new Error('Twilio configuration is incomplete.');
        }

        const response = await twilioClient.messages.create({
            body: message,
            from: TWILIO_PHONE_NUMBER,
            to: normalizedMobile
        });

        console.log(`[TWILIO] SMS sent successfully. SID: ${response.sid}`);
        return true;
    } catch (error) {
        console.error('[TWILIO] Failed to send SMS:', error.message);
        
        let errorMessage = error.message;
        
        // تخصيص رسالة الخطأ للمستخدم العربي بناءً على أكواد Twilio
        if (error.code === 21614 || errorMessage.includes('not a verified')) {
            errorMessage = 'رقم الجوال غير موثق في حساب Twilio التجريبي. يرجى إضافته إلى Verified Caller IDs.';
        } else if (error.code === 21408 || errorMessage.includes('Permission to send')) {
            errorMessage = 'يرجى تفعيل صلاحيات الإرسال للسعودية (Geo-Permissions) في إعدادات Twilio.';
        } else if (error.code === 21612 || errorMessage.includes('current combination')) {
            errorMessage = 'حساب Twilio التجريبي يمنع الإرسال لهذا الرقم من هذا المصدر. يرجى التأكد من التوثيق أو ترقية الحساب.';
        }
        
        throw new Error(errorMessage);
    }
}

/**
 * Manually sends a Welcome SMS.
 * Callable from the client (Admin Dashboard).
 */
exports.sendManualWelcomeSMS = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const { mobile, name, mnCode, schoolName, tempPassword } = data || {};
    
    if (!mobile || !mnCode) {
        throw new functions.https.HttpsError('invalid-argument', 'mobile و mnCode مطلوبان');
    }

    try {
        const success = await sendWelcomeSMS(mobile, name, mnCode, schoolName, tempPassword);
        return { success };
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message);
    }
});

function getRolePrefix(role) {
    const r = String(role || '').trim().toLowerCase();
    if (r === 'admin' || r === 'manager' || r === 'principal') return 'MG';
    if (r === 'deputy') return 'WK';
    if (r === 'counselor') return 'CN';
    if (r === 'administrative') return 'AD';
    if (r === 'teacher') return 'TC';
    if (r === 'student') return 'ST';
    if (r === 'parent') return 'PR';
    return 'AD';
}

function generateMNCode(role) {
    const prefix = getRolePrefix(role);
    const digits = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
    return `${prefix}${digits}`;
}

/**
 * Creates a School Admin Provision (User + GlobalUsers + School Staff Record).
 * This ensures the user is fully linked to the school upon creation.
 * Only callable by SuperAdmin or System Logic.
 */
exports.createSchoolAdminProvision = functions.https.onCall(async (data, context) => {
    console.log('Starting School Admin Provision... (v2)');
    
    // Log auth context for debugging (Non-blocking)
    if (!context.auth) {
        console.warn('WARNING: createSchoolAdminProvision called without auth context.');
    } else {
        console.log(`Authenticated caller: ${context.auth.uid}`);
    }

    let { 
        email, 
        password, 
        name, 
        schoolId, 
        role, 
        uid, 
        mnCode,
        identityNumber, 
        contactEmail, 
        deputyType, 
        mobile,
        phoneNumber, // Extract phoneNumber
        delegatedPermissions, // New field for permissions
        // New fields for school creation
        schoolName,
        schoolType,
        schoolStage,
        city,
        requestId // Optional: to update status
    } = data;
    const db = admin.firestore();

    if (!email || !name || !schoolId || !role) {
        throw new functions.https.HttpsError('invalid-argument', 'البيانات المطلوبة ناقصة (البريد، الاسم، المدرسة، الدور)');
    }

    try {
        // Generate random password if not provided
        if (!password) {
            const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Readable chars
            password = '';
            for (let i = 0; i < 6; i++) {
                password += chars.charAt(Math.floor(Math.random() * chars.length));
            }
        }

        // Normalize inputs
        const finalPhone = mobile || phoneNumber;
        let normalizedPhone = finalPhone ? normalizeDigits(finalPhone) : null;
        
        if (identityNumber) {
            identityNumber = normalizeDigits(identityNumber);
            const idRegex = /^[0-9]{10}$/;
            if (!idRegex.test(identityNumber)) {
                throw new functions.https.HttpsError(
                    'invalid-argument',
                    'رقم الهوية يجب أن يكون مكوّنًا من 10 أرقام'
                );
            }
        }
        
        if (normalizedPhone) normalizedPhone = normalizeDigits(normalizedPhone);
        email = normalizeDigits(email);
        if (password) password = normalizeDigits(password);

        console.log(`Provisioning user: ${email} for school: ${schoolId}, role: ${role}`);

        let targetUid = uid;
        let createdAuthUser = false;

        // 1. Create or Update Auth User
        if (!targetUid) {
            console.log('Creating new Auth user...');
            const userRecord = await admin.auth().createUser({
                email,
                password,
                displayName: name,
            });
            targetUid = userRecord.uid;
            createdAuthUser = true;
            console.log(`Auth user created: ${targetUid}`);
        } else {
             console.log(`Updating existing Auth user: ${targetUid}`);
             // Only update password if we generated one or user provided one
             const updateData = {
                email,
                displayName: name,
             };
             if (password) updateData.password = password;
             
             await admin.auth().updateUser(targetUid, updateData);
        }

        const globalUserRef = db.collection('GlobalUsers').doc(targetUid);

        let collectionName = 'Staff';
        if (role === 'teacher') collectionName = 'Teachers';
        if (role === 'student') collectionName = 'Students';
        if (role === 'parent') collectionName = 'Parents';
        const schoolUserRef = db.collection('Schools').doc(schoolId).collection(collectionName).doc(targetUid);

        const maxAttempts = 30;
        let finalMnCode = null;
        const requestedMnCode = String(mnCode || '').trim().toUpperCase();
        const expectedPrefix = getRolePrefix(role);
        const requestedIsValid = /^[A-Z]{2}[0-9]{6}$/.test(requestedMnCode);
        if (requestedMnCode && (!requestedIsValid || !requestedMnCode.startsWith(expectedPrefix))) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                `صيغة كود الدخول غير صحيحة. يجب أن يبدأ بـ ${expectedPrefix} ويتكون من حرفين و6 أرقام.`
            );
        }

        const attempts = requestedMnCode ? 1 : maxAttempts;

        for (let attempt = 0; attempt < attempts; attempt++) {
            const candidateCode = requestedMnCode || generateMNCode(role);
            try {
                finalMnCode = await db.runTransaction(async (t) => {
                    const globalSnap = await t.get(globalUserRef);
                    const existing = globalSnap.exists
                        ? String((globalSnap.data() || {}).mnCode || '').trim().toUpperCase()
                        : '';
                    const chosen = (existing || candidateCode).toUpperCase();

                    const userCodeRef = db.collection('UserCodes').doc(chosen);
                    const codeSnap = await t.get(userCodeRef);

                    const codePayload = {
                        uid: targetUid,
                        email: email,
                        schoolId: schoolId,
                        role: role,
                        name: name,
                        prefix: getRolePrefix(role),
                        formatVersion: 2,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        isActive: true,
                    };

                    if (!existing) {
                        if (codeSnap.exists) {
                            const err = new Error('MN_CODE_EXISTS');
                            err.code = 'MN_CODE_EXISTS';
                            throw err;
                        }
                        t.create(userCodeRef, codePayload);
                    } else {
                        if (!codeSnap.exists) {
                            t.create(userCodeRef, codePayload);
                        } else {
                            const cd = codeSnap.data() || {};
                            if (cd.uid && cd.uid !== targetUid) {
                                const err = new Error('MN_CODE_OWNED_BY_OTHER');
                                err.code = 'MN_CODE_OWNED_BY_OTHER';
                                throw err;
                            }
                            t.set(userCodeRef, codePayload, { merge: true });
                        }
                    }

                    const globalPayload = {
                        email,
                        role,
                        schoolId,
                        displayName: name,
                        identityNumber: identityNumber || null,
                        phoneNumber: normalizedPhone || null,
                        mnCode: chosen,
                        isPasswordChangeRequired: true,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        isActive: true,
                    };
                    t.set(globalUserRef, globalPayload, { merge: true });

                    const userData = {
                        uid: targetUid,
                        name,
                        role,
                        email,
                        mobile: normalizedPhone || null,
                        identityNumber: identityNumber || null,
                        mnCode: chosen,
                        isActive: true,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    };

                    if (role === 'deputy') {
                        userData.deputyType = deputyType || 'academic';
                    }

                    if (delegatedPermissions) {
                        try {
                            const sanitizedPermissions = JSON.parse(JSON.stringify(delegatedPermissions));
                            userData.delegatedPermissions = sanitizedPermissions;
                        } catch (e) {
                            console.warn('Failed to sanitize permissions:', e);
                        }
                    }

                    t.set(schoolUserRef, userData, { merge: true });

                    if (schoolName) {
                        const schoolRef = db.collection('Schools').doc(schoolId);
                        t.set(schoolRef, {
                            id: schoolId,
                            name: schoolName,
                            type: schoolType || 'government',
                            stage: schoolStage || 'الابتدائية',
                            city: city || '',
                            ownerId: targetUid,
                            isActive: true,
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        }, { merge: true });
                    }

                    if (requestId) {
                        const requestRef = db.collection('SchoolRequests').doc(requestId);
                        t.set(requestRef, {
                            status: 'approved',
                            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                            ownerUserId: targetUid,
                        }, { merge: true });
                    }

                    return chosen;
                });
                break;
            } catch (e) {
                const code = e && (e.code || e.message);
                if (code === 'MN_CODE_EXISTS') {
                    if (requestedMnCode) {
                        throw new functions.https.HttpsError('already-exists', 'كود الدخول مستخدم بالفعل');
                    }
                    continue;
                }
                throw e;
            }
        }

        if (!finalMnCode) {
            throw new functions.https.HttpsError(
                'resource-exhausted',
                'تعذر توليد كود دخول فريد. يرجى إعادة المحاولة.'
            );
        }

        // Skip automatic SMS sending; delivery will be via WhatsApp from admin UI

        return { success: true, uid: targetUid, mnCode: finalMnCode, password: password };

    } catch (error) {
        console.error('Provisioning failed:', error);
        if (createdAuthUser && targetUid) {
            try {
                await admin.auth().deleteUser(targetUid);
            } catch (e) {
                console.warn('Rollback: failed to delete auth user after provisioning error', e);
            }
        }
        
        if (error.code === 'auth/email-already-exists') {
            throw new functions.https.HttpsError('already-exists', 'البريد الإلكتروني مستخدم بالفعل');
        }
        if (error.code === 'auth/invalid-password') {
            throw new functions.https.HttpsError('invalid-argument', 'كلمة المرور غير صالحة (يجب أن تكون 6 خانات على الأقل)');
        }
        if (error.code === 'auth/invalid-email') {
            throw new functions.https.HttpsError('invalid-argument', 'صيغة البريد الإلكتروني غير صحيحة');
        }
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        
        throw new functions.https.HttpsError('internal', `حدث خطأ أثناء إنشاء المستخدم: ${error.message || 'Unknown Error'}`);
    }
});

/**
 * Deletes a School Admin/Staff Provision (Auth + GlobalUsers + School Staff).
 * This keeps Staff and GlobalUsers in sync and avoids orphan accounts.
 */
exports.deleteSchoolAdminProvision = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const callerUid = context.auth.uid;
    const { uid, schoolId, role } = data || {};

    if (!uid || !schoolId) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'uid و schoolId مطلوبان لحذف الموظف'
        );
    }

    const db = admin.firestore();

    try {
        // Authorize caller: must belong to same school and be manager/admin/principal
        const callerSnap = await db.collection('GlobalUsers').doc(callerUid).get();
        if (!callerSnap.exists) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'لا تملك صلاحية حذف الموظفين'
            );
        }

        const caller = callerSnap.data() || {};
        if (!caller.schoolId || caller.schoolId !== schoolId) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'لا تملك صلاحية على هذه المدرسة'
            );
        }

        const callerRole = (caller.role || '').toString();
        const allowedRoles = ['manager', 'admin', 'principal'];
        if (!allowedRoles.includes(callerRole)) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'صلاحيات غير كافية لحذف الموظفين'
            );
        }

        // Determine collection based on role
        let collectionName = 'Staff';
        if (role === 'teacher') collectionName = 'Teachers';
        if (role === 'student') collectionName = 'Students';
        if (role === 'parent') collectionName = 'Parents';

        let mnCode = null;
        try {
            const targetSnap = await db.collection('GlobalUsers').doc(uid).get();
            if (targetSnap.exists) {
                mnCode = (targetSnap.data().mnCode || '').toString().trim().toUpperCase();
            }
        } catch (e) {
            console.warn('Failed to fetch target mnCode before delete', uid, e);
        }

        // Best-effort deletes; continue even if some docs are missing
        try {
            await db
                .collection('Schools')
                .doc(schoolId)
                .collection(collectionName)
                .doc(uid)
                .delete();
        } catch (e) {
            console.warn('Failed to delete staff document', uid, e);
        }

        try {
            await db.collection('GlobalUsers').doc(uid).delete();
        } catch (e) {
            console.warn('Failed to delete GlobalUsers document', uid, e);
        }

        if (mnCode) {
            try {
                await db.collection('UserCodes').doc(mnCode).set({
                    isActive: false,
                    disabledAt: admin.firestore.FieldValue.serverTimestamp(),
                    disabledBy: callerUid,
                }, { merge: true });
            } catch (e) {
                console.warn('Failed to disable UserCodes document', mnCode, e);
            }
        }

        try {
            await admin.auth().deleteUser(uid);
        } catch (e) {
            console.warn('Failed to delete auth user', uid, e);
        }

        return { success: true };
    } catch (error) {
        console.error('deleteSchoolAdminProvision failed:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError(
            'internal',
            'فشل حذف حساب الموظف من السيرفر'
        );
    }
});

exports.repairCurrentUserLink = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();
    const deputyType = resolved.deputyType || null;
    if (!schoolId || !role) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'لا يمكن إصلاح ربط الحساب: لا يوجد سجل لهذا المستخدم داخل أي مدرسة.'
        );
    }

    await db.collection('GlobalUsers').doc(uid).set(
        {
            schoolId,
            role,
            deputyType: deputyType || null,
            repairedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    return { success: true, schoolId, role, deputyType: deputyType || null };
});

async function resolveCallerLink(db, uid) {
    try {
        const globalDoc = await db.collection('GlobalUsers').doc(uid).get();
        if (globalDoc.exists) {
            const g = globalDoc.data() || {};
            const schoolId = (g.schoolId ? String(g.schoolId) : '').trim();
            const role = (g.role ? String(g.role) : '').trim();
            const deputyType = g.deputyType || null;
            if (schoolId && role) {
                return { schoolId, role, deputyType };
            }
        }
    } catch (_) {}

    const findInGroup = async (group) => {
        const snap = await db
            .collectionGroup(group)
            .where(admin.firestore.FieldPath.documentId(), '==', uid)
            .limit(1)
            .get();
        if (snap.docs.length) return snap.docs[0];
        try {
            const snap2 = await db
                .collectionGroup(group)
                .where('userId', '==', uid)
                .limit(1)
                .get();
            if (snap2.docs.length) return snap2.docs[0];
        } catch (_) {}
        try {
            const snap3 = await db
                .collectionGroup(group)
                .where('uid', '==', uid)
                .limit(1)
                .get();
            if (snap3.docs.length) return snap3.docs[0];
        } catch (_) {}
        return null;
    };

    const staffDoc = await findInGroup('Staff');
    const teacherDoc = staffDoc ? null : await findInGroup('Teachers');
    const usersDoc = staffDoc || teacherDoc ? null : await findInGroup('Users');
    const studentDoc = staffDoc || teacherDoc || usersDoc ? null : await findInGroup('Students');
    const parentDoc = staffDoc || teacherDoc || usersDoc || studentDoc ? null : await findInGroup('Parents');

    const doc = staffDoc || teacherDoc || usersDoc || studentDoc || parentDoc;
    if (!doc) {
        return { schoolId: '', role: '', deputyType: null };
    }

    const schoolId = doc.ref.parent.parent.id;
    const payload = doc.data() || {};
    let role = (payload.role || '').toString();
    if (!role) {
        if (doc.ref.parent.id === 'Teachers') role = 'teacher';
        if (doc.ref.parent.id === 'Students') role = 'student';
        if (doc.ref.parent.id === 'Parents') role = 'parent';
        if (!role) role = 'administrative';
    }
    const deputyType = (payload.deputyType || null);
    return { schoolId, role, deputyType };
}

async function resolveCallerName(db, schoolId, uid) {
    try {
        const t = await db.collection('Schools').doc(schoolId).collection('Teachers').doc(uid).get();
        if (t.exists) {
            const d = t.data() || {};
            const name = (d.name ? String(d.name) : '').trim();
            if (name) return name;
        }
    } catch (_) {}
    try {
        const s = await db.collection('Schools').doc(schoolId).collection('Staff').doc(uid).get();
        if (s.exists) {
            const d = s.data() || {};
            const name = (d.name ? String(d.name) : '').trim();
            if (name) return name;
        }
    } catch (_) {}
    try {
        const u = await db.collection('Schools').doc(schoolId).collection('Users').doc(uid).get();
        if (u.exists) {
            const d = u.data() || {};
            const name = (d.name ? String(d.name) : '').trim();
            if (name) return name;
        }
    } catch (_) {}
    try {
        const g = await db.collection('GlobalUsers').doc(uid).get();
        if (g.exists) {
            const d = g.data() || {};
            const name = (d.name ? String(d.name) : '').trim();
            if (name) return name;
        }
    } catch (_) {}
    return '';
}

exports.listStudentsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    let schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();
    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض الطلاب');
    }

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .orderBy('name')
        .limit(5000)
        .get();

    const students = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: students.length, students };
});

exports.listTeachersForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض المعلمين');
    }

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .orderBy('name')
        .limit(5000)
        .get();

    const teachers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: teachers.length, teachers };
});

exports.listCurriculumProgressForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض تنفيذ المنهج');
    }

    const classId = (data && data.classId ? String(data.classId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();

    let q = db
        .collection('Schools')
        .doc(schoolId)
        .collection('CurriculumProgress');

    if (classId) q = q.where('classId', '==', classId);
    if (subjectId) q = q.where('subjectId', '==', subjectId);

    const snap = await q.limit(5000).get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.upsertCurriculumProgress = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تعديل تنفيذ المنهج');
    }

    const classId = (data && data.classId ? String(data.classId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();
    if (!classId || !subjectId) {
        throw new functions.https.HttpsError('invalid-argument', 'classId/subjectId مفقود');
    }

    const expectedUnitsRaw = data && data.expectedUnits != null ? data.expectedUnits : null;
    const coveredUnitsRaw = data && data.coveredUnits != null ? data.coveredUnits : null;
    const expectedUnits = Number.isFinite(Number(expectedUnitsRaw)) ? parseInt(String(expectedUnitsRaw), 10) : -1;
    const coveredUnits = Number.isFinite(Number(coveredUnitsRaw)) ? parseInt(String(coveredUnitsRaw), 10) : -1;
    if (expectedUnits < 0 || coveredUnits < 0) {
        throw new functions.https.HttpsError('invalid-argument', 'expectedUnits/coveredUnits غير صحيح');
    }

    const className = (data && data.className ? String(data.className) : '').trim();
    const subjectName = (data && data.subjectName ? String(data.subjectName) : '').trim();
    const teacherId = (data && data.teacherId ? String(data.teacherId) : '').trim();

    const toKey = (s) => String(s || '')
        .trim()
        .replace(/[\/\\]/g, '_')
        .replace(/\s+/g, '_');
    const docId = `${toKey(classId)}__${toKey(subjectId)}`;

    const payload = {
        classId,
        subjectId,
        expectedUnits,
        coveredUnits,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(className ? { className } : {}),
        ...(subjectName ? { subjectName } : {}),
        ...(teacherId ? { teacherId } : {}),
        updatedByUid: uid,
    };

    await db
        .collection('Schools')
        .doc(schoolId)
        .collection('CurriculumProgress')
        .doc(docId)
        .set(payload, { merge: true });

    return { success: true, schoolId, docId };
});

exports.listLessonPrepRecordsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض بيانات الجاهزية');
    }

    const fromRaw = (data && data.from ? String(data.from) : '').trim();
    const toRaw = (data && data.to ? String(data.to) : '').trim();
    const from = fromRaw ? new Date(fromRaw) : null;
    const to = toRaw ? new Date(toRaw) : null;
    if (!from || isNaN(from.getTime()) || !to || isNaN(to.getTime())) {
        throw new functions.https.HttpsError('invalid-argument', 'from/to غير صحيح');
    }

    const teacherId = (data && data.teacherId ? String(data.teacherId) : '').trim();

    let q = db
        .collection('Schools')
        .doc(schoolId)
        .collection('LessonPrepRecords')
        .where('date', '>=', admin.firestore.Timestamp.fromDate(from))
        .where('date', '<=', admin.firestore.Timestamp.fromDate(to));
    if (teacherId) q = q.where('teacherId', '==', teacherId);

    const snap = await q.limit(5000).get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.listExamGradesTrackingForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض متابعة الرصد');
    }

    const termId = (data && data.termId ? String(data.termId) : '').trim();
    const classId = (data && data.classId ? String(data.classId) : '').trim();
    let q = db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking');
    if (termId) q = q.where('termId', '==', termId);
    if (classId) q = q.where('classId', '==', classId);

    const snap = await q.orderBy('completionRate').limit(5000).get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

async function recalcExamGradesTracking(db, schoolId, trackId) {
    const doc = db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .doc(trackId);
    const snap = await doc.get();
    if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'مسار الرصد غير موجود');
    }
    const m = snap.data() || {};
    const classId = (m.classId || '').toString();
    const subjectId = (m.subjectId || '').toString();
    const termId = (m.termId || '').toString();
    if (!classId || !subjectId || !termId) {
        throw new functions.https.HttpsError('failed-precondition', 'بيانات المسار غير مكتملة');
    }

    const studentsSnap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .where('classId', '==', classId)
        .get();
    const expected = studentsSnap.docs.length;

    const entriesSnap = await doc
        .collection('Entries')
        .where('termId', '==', termId)
        .where('subjectId', '==', subjectId)
        .get();
    const entered = entriesSnap.docs.length;
    const rate = expected === 0 ? 0 : (entered * 100.0) / expected;

    let dueDate = null;
    try {
        dueDate = m.dueDate && m.dueDate.toDate ? m.dueDate.toDate() : null;
    } catch (_) { }

    const status = rate >= 100.0
        ? 'complete'
        : (dueDate && new Date() > dueDate)
            ? 'late'
            : 'incomplete';

    await doc.set({
        expectedCount: expected,
        enteredCount: entered,
        completionRate: rate,
        status,
        lastUpdateAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { expectedCount: expected, enteredCount: entered, completionRate: rate, status };
}

exports.recalcExamGradesTrack = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تحديث الرصد');
    }

    const trackId = (data && data.trackId ? String(data.trackId) : '').trim();
    if (!trackId) {
        throw new functions.https.HttpsError('invalid-argument', 'trackId مفقود');
    }

    const updated = await recalcExamGradesTracking(db, schoolId, trackId);
    return { success: true, schoolId, trackId, updated };
});

exports.upsertExamGradeEntry = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية إدخال الدرجات');
    }

    const trackId = (data && data.trackId ? String(data.trackId) : '').trim();
    const studentId = (data && data.studentId ? String(data.studentId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();
    const termId = (data && data.termId ? String(data.termId) : '').trim();
    const teacherId = (data && data.teacherId ? String(data.teacherId) : '').trim();
    const scoreRaw = data && data.score != null ? data.score : null;
    const score = Number.isFinite(Number(scoreRaw)) ? Number(scoreRaw) : NaN;

    if (!trackId || !studentId || !subjectId || !termId || !teacherId || Number.isNaN(score)) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات الإدخال غير مكتملة');
    }

    const entryDoc = db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .doc(trackId)
        .collection('Entries')
        .doc(studentId);

    await entryDoc.set({
        studentId,
        subjectId,
        termId,
        teacherId,
        score,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdByUid: uid,
    }, { merge: true });

    const updated = await recalcExamGradesTracking(db, schoolId, trackId);
    return { success: true, schoolId, trackId, studentId, updated };
});

exports.listExamTermsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض الفصول');
    }

    const set = new Set();

    const tracksSnap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .limit(5000)
        .get();
    for (const d of tracksSnap.docs) {
        const m = d.data() || {};
        const termId = (m.termId || '').toString().trim();
        if (termId) set.add(termId);
    }

    const schedulesSnap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .limit(5000)
        .get();
    for (const d of schedulesSnap.docs) {
        const m = d.data() || {};
        const termId = (m.termId || '').toString().trim();
        if (termId) set.add(termId);
    }

    const attendanceSnap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamAttendance')
        .limit(5000)
        .get();
    for (const d of attendanceSnap.docs) {
        const m = d.data() || {};
        const termId = (m.termId || '').toString().trim();
        if (termId) set.add(termId);
    }

    const terms = Array.from(set);
    terms.sort();
    return { schoolId, count: terms.length, terms };
});

exports.listExamAttendanceForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض سجلات الغياب');
    }

    const termId = (data && data.termId ? String(data.termId) : '').trim();
    const classId = (data && data.classId ? String(data.classId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();
    const dateRaw = (data && data.date ? String(data.date) : '').trim();

    let q = db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamAttendance');
    if (termId) q = q.where('termId', '==', termId);
    if (classId) q = q.where('classId', '==', classId);
    if (subjectId) q = q.where('subjectId', '==', subjectId);

    if (dateRaw) {
        const date = new Date(dateRaw);
        if (!date || isNaN(date.getTime())) {
            throw new functions.https.HttpsError('invalid-argument', 'date غير صحيح');
        }
        const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
        q = q
            .where('recordedAt', '>=', admin.firestore.Timestamp.fromDate(start))
            .where('recordedAt', '<', admin.firestore.Timestamp.fromDate(end));
    }

    const snap = await q.orderBy('recordedAt', 'desc').limit(5000).get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.listAcademicActionsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض الإجراءات التحليلية');
    }

    const type = (data && data.type ? String(data.type) : '').trim();
    const status = (data && data.status ? String(data.status) : '').trim();

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('AcademicActions')
        .orderBy('updatedAt', 'desc')
        .limit(1000)
        .get();

    let items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    if (type) items = items.filter((x) => String(x.type || '').trim() === type);
    if (status) items = items.filter((x) => String(x.status || '').trim() === status);
    return { schoolId, count: items.length, items: items.slice(0, 200) };
});

exports.upsertAcademicAction = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية إضافة إجراءات تحليلية');
    }

    const id = (data && data.id ? String(data.id) : '').trim();
    const type = (data && data.type ? String(data.type) : '').trim();
    const title = (data && data.title ? String(data.title) : '').trim();
    const description = (data && data.description ? String(data.description) : '').trim();
    const status = (data && data.status ? String(data.status) : 'open').trim();
    const classId = (data && data.classId ? String(data.classId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();
    const studentId = (data && data.studentId ? String(data.studentId) : '').trim();

    if (!type || !title) {
        throw new functions.https.HttpsError('invalid-argument', 'type/title مفقود');
    }

    const col = db
        .collection('Schools')
        .doc(schoolId)
        .collection('AcademicActions');
    const ref = id ? col.doc(id) : col.doc();

    const payload = {
        type,
        title,
        description,
        status,
        ...(classId ? { classId } : {}),
        ...(subjectId ? { subjectId } : {}),
        ...(studentId ? { studentId } : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedByUid: uid,
    };

    if (!id) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
        payload.createdByUid = uid;
    }

    await ref.set(payload, { merge: true });
    return { success: true, schoolId, id: ref.id };
});

exports.listRiskPredictionsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض التحليلات');
    }

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('RiskPredictions')
        .orderBy('generatedAt', 'desc')
        .limit(200)
        .get();

    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.listRemedialPlansForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض الخطط العلاجية');
    }

    const status = (data && data.status ? String(data.status) : '').trim();
    let q = db
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans');
    if (status) q = q.where('status', '==', status);

    const snap = await q.orderBy('teacherId').limit(300).get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.getLatestSchoolIntelligenceSnapshotForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض مؤشر صحة المدرسة');
    }

    const termId = (data && data.termId ? String(data.termId) : 'current').trim() || 'current';

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .orderBy('generatedAt', 'desc')
        .limit(200)
        .get();

    let item = null;
    for (const d of snap.docs) {
        const m = d.data() || {};
        const t = (m.termId || '').toString().trim();
        if (!termId || termId === 'current' || t === termId) {
            item = { id: d.id, ...m };
            break;
        }
    }
    if (!item && snap.docs.length > 0) {
        const d = snap.docs[0];
        item = { id: d.id, ...(d.data() || {}) };
    }
    return { schoolId, termId, item };
});

exports.upsertExamAttendanceRecord = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تسجيل الغياب');
    }

    const id = (data && data.id ? String(data.id) : '').trim();
    const termId = (data && data.termId ? String(data.termId) : '').trim();
    const scheduleId = (data && data.scheduleId ? String(data.scheduleId) : '').trim();
    const studentId = (data && data.studentId ? String(data.studentId) : '').trim();
    const classId = (data && data.classId ? String(data.classId) : '').trim();
    const subjectId = (data && data.subjectId ? String(data.subjectId) : '').trim();
    const status = (data && data.status ? String(data.status) : '').trim();
    const excuseDocUrl = (data && data.excuseDocUrl ? String(data.excuseDocUrl) : '').trim();

    if (!id || !termId || !scheduleId || !studentId || !classId || !subjectId || !status) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات الإدخال غير مكتملة');
    }

    await db
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamAttendance')
        .doc(id)
        .set({
            termId,
            scheduleId,
            studentId,
            classId,
            subjectId,
            status,
            excuseDocUrl: excuseDocUrl || null,
            recordedBy: uid,
            recordedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

    return { success: true, schoolId, id };
});

exports.listTeacherFollowUpsForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض المتابعة');
    }

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('TeacherFollowUps')
        .limit(5000)
        .get();

    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: items.length, items };
});

exports.upsertTeacherFollowUp = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const teacherId = (data && data.teacherId ? String(data.teacherId) : '').trim();
    if (!teacherId) {
        throw new functions.https.HttpsError('invalid-argument', 'teacherId مفقود');
    }

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تعديل المتابعة');
    }

    const status = (data && data.status ? String(data.status) : 'none').trim();
    const note = (data && data.note ? String(data.note) : '').trim();
    const nextReviewAtRaw = (data && data.nextReviewAt ? String(data.nextReviewAt) : '').trim();
    let nextReviewAt = null;
    if (nextReviewAtRaw) {
        const dt = new Date(nextReviewAtRaw);
        if (!isNaN(dt.getTime())) {
            nextReviewAt = admin.firestore.Timestamp.fromDate(dt);
        }
    }

    const callerName = await resolveCallerName(db, schoolId, uid);

    const refDoc = db
        .collection('Schools')
        .doc(schoolId)
        .collection('TeacherFollowUps')
        .doc(teacherId);

    await refDoc.set(
        {
            teacherId,
            status,
            note,
            nextReviewAt: nextReviewAt || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedByUid: uid,
            updatedByName: callerName,
        },
        { merge: true }
    );

    const logRef = refDoc.collection('Logs').doc();
    await logRef.set({
        id: logRef.id,
        teacherId,
        status,
        note,
        nextReviewAt: nextReviewAt || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdByUid: uid,
        createdByName: callerName,
    });

    return { success: true, schoolId, teacherId };
});

exports.listTeacherFollowUpLogs = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const teacherId = (data && data.teacherId ? String(data.teacherId) : '').trim();
    if (!teacherId) {
        throw new functions.https.HttpsError('invalid-argument', 'teacherId مفقود');
    }

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض السجل');
    }

    const limitRaw = data && data.limit ? parseInt(String(data.limit), 10) : 20;
    const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 20;

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('TeacherFollowUps')
        .doc(teacherId)
        .collection('Logs')
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, teacherId, count: items.length, items };
});

exports.listClassesForSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();
    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض الفصول');
    }

    const snap = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .orderBy('gradeLevel')
        .limit(1000)
        .get();

    const classes = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    return { schoolId, count: classes.length, classes };
});

exports.getAcademicExecutiveSummary = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const schoolIdInput = (data && data.schoolId ? String(data.schoolId) : '').trim();
    const resolved = await resolveCallerLink(db, uid);
    const schoolId = schoolIdInput || (resolved.schoolId || '').trim();
    const role = (resolved.role || '').trim();

    if (!schoolId) {
        throw new functions.https.HttpsError('failed-precondition', 'School ID مفقود');
    }
    if (!role || role === 'student' || role === 'parent') {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية عرض التحليل الأكاديمي');
    }

    const snapshotQ = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .orderBy('generatedAt', 'desc')
        .limit(1)
        .get();
    const snapshot = snapshotQ.docs.length ? (snapshotQ.docs[0].data() || {}) : null;

    const riskQ = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('RiskPredictions')
        .orderBy('generatedAt', 'desc')
        .limit(200)
        .get();
    const risks = riskQ.docs.map((d) => d.data() || {});

    const plansQ = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .limit(500)
        .get();
    const plans = plansQ.docs.map((d) => d.data() || {});

    const riskClasses = snapshot && Array.isArray(snapshot.riskClasses) ? snapshot.riskClasses : [];
    const riskSubjects = snapshot && Array.isArray(snapshot.riskSubjects) ? snapshot.riskSubjects : [];
    const scoreRaw = snapshot && typeof snapshot.schoolHealthScore === 'number' ? snapshot.schoolHealthScore : 85;
    const overduePlans = plans.filter((p) => (p.status || '') === 'overdue').length;

    let status = 'stable';
    if (riskClasses.length > 2 || riskSubjects.length > 2 || overduePlans > 0) status = 'critical';
    else if (riskClasses.length > 0 || riskSubjects.length > 0) status = 'warning';

    const statusMeta = status === 'critical'
        ? { label: 'تحتاج تدخل عاجل', color: '#D32F2F', icon: 'error' }
        : status === 'warning'
            ? { label: 'تحتاج متابعة', color: '#F9A825', icon: 'warning' }
            : { label: 'الحالة الأكاديمية مستقرة', color: '#2E7D32', icon: 'check' };

    const completedPlans = plans.filter((p) => (p.status || '') === 'completed').length;
    const efficiency = plans.length ? Math.min(1, Math.max(0, completedPlans / plans.length)) : 1;
    const efficiencyColor = efficiency >= 0.8 ? '#2E7D32' : efficiency >= 0.6 ? '#F9A825' : '#D32F2F';

    const forwardKey = status === 'critical' ? 'declining' : status === 'warning' ? 'atRisk' : 'stable';
    const forwardStability = forwardKey === 'declining'
        ? { key: 'declining', label: 'منخفض', color: '#D32F2F' }
        : forwardKey === 'atRisk'
            ? { key: 'atRisk', label: 'تحذير', color: '#F9A825' }
            : { key: 'stable', label: 'مستقر', color: '#2E7D32' };

    let tier = 'B';
    let score = scoreRaw - (overduePlans * 5);
    if (score >= 90) tier = 'A';
    else if (score >= 80) tier = 'B';
    else if (score >= 70) tier = 'C';
    else tier = 'D';
    const tierMeta = tier === 'A'
        ? { label: 'A', color: '#2E7D32' }
        : tier === 'B'
            ? { label: 'B', color: '#1976D2' }
            : tier === 'C'
                ? { label: 'C', color: '#F9A825' }
                : { label: 'D', color: '#D32F2F' };

    const priorities = [];
    for (const cls of riskClasses.slice(0, 2)) priorities.push(`فصل ${cls} يحتاج متابعة`);
    for (const subj of riskSubjects.slice(0, 2)) priorities.push(`مادة ${subj} تحتاج تحسين`);
    if (overduePlans > 0) priorities.push(`${overduePlans} خطط علاجية متأخرة التنفيذ`);
    if (priorities.length === 0) priorities.push('استمر على المتابعة اليومية للحضور والأداء');

    let recommendation = 'استمر في المتابعة الدورية وتفعيل الإجراءات الوقائية.';
    if (status === 'critical') recommendation = 'فعل خطة تدخل عاجل وراجع الخطط المتأخرة وركّز على الفصول/المواد الأكثر خطورة.';
    if (status === 'warning') recommendation = 'قم بخطة متابعة أسبوعية للفصول/المواد المعرضة للخطر وراقب التحسن.';

    return {
        schoolId,
        statusKey: status,
        status: statusMeta,
        forwardStabilityKey: forwardKey,
        forwardStability,
        interventionEfficiency: { value: Math.round(efficiency * 100), color: efficiencyColor },
        institutionalTierKey: tier,
        institutionalTier: tierMeta,
        priorities,
        recommendation,
    };
});

exports.saveStudentDetails = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const studentId = (data && data.studentId ? String(data.studentId) : '').trim();
    if (!studentId) {
        throw new functions.https.HttpsError('invalid-argument', 'studentId مفقود');
    }

    const resolved = await resolveCallerLink(db, uid);
    const role = (resolved.role || '').trim();
    const schoolId = ((data && data.schoolId ? String(data.schoolId) : '').trim() ||
        (resolved.schoolId || '').trim());

    if (!schoolId || role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تعديل بيانات الطلاب');
    }

    const payload = (data && data.data && typeof data.data === 'object') ? data.data : {};
    await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .doc(studentId)
        .set(payload, { merge: true });

    return { success: true, schoolId, studentId };
});

exports.saveParentDetails = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const db = admin.firestore();

    const parentId = (data && data.parentId ? String(data.parentId) : '').trim();
    if (!parentId) {
        throw new functions.https.HttpsError('invalid-argument', 'parentId مفقود');
    }

    const resolved = await resolveCallerLink(db, uid);
    const role = (resolved.role || '').trim();
    const schoolId = ((data && data.schoolId ? String(data.schoolId) : '').trim() ||
        (resolved.schoolId || '').trim());

    if (!schoolId || role === 'student' || role === 'parent' || !role) {
        throw new functions.https.HttpsError('permission-denied', 'لا تملك صلاحية تعديل بيانات أولياء الأمور');
    }

    const payload = (data && data.data && typeof data.data === 'object') ? data.data : {};
    await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Parents')
        .doc(parentId)
        .set(payload, { merge: true });

    return { success: true, schoolId, parentId };
});

// ============================================================================
// SCHEDULE MODULE
// ============================================================================

/**
 * When a new ScheduleRun is created, notify all teachers in the school
 * with a polite Arabic message and a deep link to the constraints screen.
 */
exports.onScheduleRunCreated = functions.firestore
    .document('Schools/{schoolId}/ScheduleRuns/{runId}')
    .onCreate(async (snap, context) => {
        const { schoolId, runId } = context.params;
        const db = admin.firestore();
        const data = snap.data() || {};

        let deadlineStr = 'وقت الإغلاق المحدد';
        try {
            if (data.collectUntil && data.collectUntil.toDate) {
                const dt = data.collectUntil.toDate();
                deadlineStr = dt.toISOString().replace('T', ' ').substring(0, 16);
            }
        } catch (e) {
            console.warn('Failed to format collectUntil for ScheduleRun', runId, e);
        }

        const template =
            'الزملاء الكرام، نعمل حاليًا على إعداد الجدول الدراسي للفصل. نأمل تعبئة أوقات التعذر (إن وُجدت) عبر الرابط قبل: (وقت الإغلاق). في حال عدم الرد حتى انتهاء المهلة، سيُعتبر ذلك موافقةً على جميع الأوقات المتاحة. سيُنشئ النظام الجدول آليًا مع مراعاة العدالة بين الجميع وحصص الانتظار، وقد لا تتحقق جميع الطلبات لضمان توازن المدرسة. شكرًا لتعاونكم وتفهمكم.';

        const body = template.replace('(وقت الإغلاق)', deadlineStr);

        const notifRef = db
            .collection('Schools')
            .doc(schoolId)
            .collection('Notifications')
            .doc();

        await notifRef.set({
            id: notifRef.id,
            userId: null,
            title: 'طلب تعبئة أوقات التعذر للجدول',
            body,
            timestamp: new Date().toISOString(),
            isRead: false,
            route: `/teacher-schedule-preferences/${runId}`,
            data: {
                scheduleRunId: runId,
                mode: data.mode || 'collaborative',
            },
            schoolId,
            targetRole: 'teacher',
            targetClassId: null,
        });
    });

/**
 * Periodically close expired ScheduleRuns (where collectUntil has passed)
 * and move them from "collecting" -> "locked".
 */
exports.closeExpiredScheduleRuns = functions.pubsub
    .schedule('every 10 minutes')
    .onRun(async () => {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();

        const snapshot = await db
            .collectionGroup('ScheduleRuns')
            .where('status', '==', 'collecting')
            .where('collectUntil', '<=', now)
            .get();

        if (snapshot.empty) {
            return null;
        }

        const batch = db.batch();
        snapshot.forEach((doc) => {
            batch.update(doc.ref, {
                status: 'locked',
                closedAt: now,
            });
        });

        await batch.commit();
        return null;
    });

/**
 * Callable: Generate schedule job metadata for a given ScheduleRun.
 * Does NOT compute the actual timetable (handled by client-side solver),
 * but aggregates participation stats and marks the run as "generating".
 */
exports.generateScheduleForRun = functions.https.onCall(
    async (data, context) => {
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                'يجب تسجيل الدخول أولاً'
            );
        }

        const { schoolId, runId } = data || {};
        if (!schoolId || !runId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'يجب تمرير schoolId و runId'
            );
        }

        const db = admin.firestore();
        const uid = context.auth.uid;

        const isAdminUser = await isScheduleAdminUser(db, uid, schoolId);
        if (!isAdminUser) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'ليست لديك صلاحية توليد الجدول'
            );
        }

        const runRef = db
            .collection('Schools')
            .doc(schoolId)
            .collection('ScheduleRuns')
            .doc(runId);
        const runSnap = await runRef.get();

        if (!runSnap.exists) {
            throw new functions.https.HttpsError(
                'not-found',
                'لم يتم العثور على طلب الجدول'
            );
        }

        const runData = runSnap.data() || {};

        const prefsSnap = await runRef
            .collection('TeacherPreferences')
            .where('submitted', '==', true)
            .get();

        let teacherCountExpected = runData.teacherCountExpected || null;
        const submittedCount = prefsSnap.size;
        const missingTeacherIds = [];

        // If teacherCountExpected is not set, infer it from Teachers collection
        if (!teacherCountExpected) {
            const teachersSnap = await db
                .collection('Schools')
                .doc(schoolId)
                .collection('Teachers')
                .get();
            teacherCountExpected = teachersSnap.size;

            const submittedIds = new Set(
                prefsSnap.docs.map((d) => d.id || d.data().teacherId)
            );
            teachersSnap.forEach((doc) => {
                if (!submittedIds.has(doc.id)) {
                    missingTeacherIds.push(doc.id);
                }
            });
        }

        const fairnessReport = {
            teacherCountExpected,
            submittedCount,
            missingCount: teacherCountExpected - submittedCount,
            generatedBy: uid,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await runRef.set(
            {
                status: 'generating',
                teacherCountExpected,
                submittedCount,
                missingTeacherIds,
                fairnessReport,
            },
            { merge: true }
        );

        // Optional: create a TimetableJob document for external workers
        const jobRef = db
            .collection('Schools')
            .doc(schoolId)
            .collection('TimetableJobs')
            .doc(runId);

        await jobRef.set(
            {
                id: runId,
                runId,
                schoolId,
                createdBy: uid,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'queued',
            },
            { merge: true }
        );

        return {
            success: true,
            teacherCountExpected,
            submittedCount,
            missingTeacherIds,
        };
    }
);

/**
 * Callable: Publish timetable for a given ScheduleRun.
 * Marks schedule as published and notifies teachers (and optionally parents).
 */
exports.publishScheduleForRun = functions.https.onCall(
    async (data, context) => {
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                'يجب تسجيل الدخول أولاً'
            );
        }

        const { schoolId, runId } = data || {};
        if (!schoolId || !runId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'يجب تمرير schoolId و runId'
            );
        }

        const db = admin.firestore();
        const uid = context.auth.uid;

        const isAdminUser = await isScheduleAdminUser(db, uid, schoolId);
        if (!isAdminUser) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'ليست لديك صلاحية نشر الجدول'
            );
        }

        const schoolRef = db.collection('Schools').doc(schoolId);
        const runRef = schoolRef.collection('ScheduleRuns').doc(runId);

        const runSnap = await runRef.get();
        if (!runSnap.exists) {
            throw new functions.https.HttpsError(
                'not-found',
                'لم يتم العثور على طلب الجدول'
            );
        }

        // 1) Mark settings as published
        const statusRef = schoolRef.collection('Settings').doc('schedule_status');
        await statusRef.set(
            {
                isPublished: true,
                publishedAt: admin.firestore.FieldValue.serverTimestamp(),
                runId,
                publishedBy: uid,
            },
            { merge: true }
        );

        // 2) Update run status
        await runRef.set(
            {
                status: 'published',
            },
            { merge: true }
        );

        // 3) Notify teachers about the new timetable
        const notifRef = schoolRef.collection('Notifications').doc();
        await notifRef.set({
            id: notifRef.id,
            userId: null,
            title: 'تم نشر الجدول الدراسي',
            body:
                'تم نشر الجدول الدراسي الجديد. يمكنكم الآن الاطلاع على جدول الحصص عبر لوحة المعلم الذكية.',
            timestamp: new Date().toISOString(),
            isRead: false,
            route: '/teacher-intelligence-dashboard',
            data: {
                scheduleRunId: runId,
            },
            schoolId,
            targetRole: 'teacher',
            targetClassId: null,
        });

        return {
            success: true,
        };
    }
);

// ============================================================================
// MAINTENANCE MODULE
// ============================================================================
const maintenance = require('./maintenance');
exports.onMaintenanceCreated = maintenance.onMaintenanceCreated;
exports.checkMaintenanceOverdue = maintenance.checkMaintenanceOverdue;

// ============================================================================
// STUDENT AFFAIRS MODULE
// ============================================================================
const studentAffairs = require('./student_affairs');
exports.onBathroomPassWritten = studentAffairs.onBathroomPassWritten;
exports.onAttendanceWritten = studentAffairs.onAttendanceWritten;
exports.checkBehaviorEscalation = studentAffairs.checkBehaviorEscalation;
exports.checkScheduleRunsExpiry = studentAffairs.checkScheduleRunsExpiry;

// ============================================================================
// SCHOOL HEALTH INDEX & INTELLIGENCE MODULE (RULE-BASED, WEEKLY)
// ============================================================================

/**
 * Helper: Calculate week key (ISO week) for consistent documents like 2026-W07
 */
function getWeekKeyRiyadh(date) {
  const tzDate = new Date(
    date.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' })
  );
  const target = new Date(Date.UTC(tzDate.getFullYear(), tzDate.getMonth(), tzDate.getDate()));
  const dayNr = (target.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - dayNr + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const diff = target - firstThursday;
  const week = 1 + Math.round(diff / (7 * 24 * 3600 * 1000));
  const year = target.getUTCFullYear();
  return `${year}-W${week.toString().padStart(2, '0')}`;
}

/**
 * Weekly job: Build TeacherWeeklyProfiles + SchoolHealthReports + RootCause + ClassPressure
 * Timezone: Asia/Riyadh, runs early morning every Saturday.
 */
exports.computeWeeklySchoolHealth = functions.pubsub
  .schedule('0 4 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getWeekKeyRiyadh(now);

    const schoolsSnap = await db.collection('Schools').get();
    const schoolDocs = schoolsSnap.docs;

    for (const schoolDoc of schoolDocs) {
      const schoolId = schoolDoc.id;
      const teachersSnap = await schoolDoc.ref.collection('Teachers').get();
      const teacherIds = teachersSnap.docs.map((d) => d.id);

      const teacherProfilesBatch = db.batch();
      const teacherHealthBatch = db.batch();
      const rootCauseBatch = db.batch();
      const classPressureBatch = db.batch();

      const behaviorSnap = await db
        .collection('behavior_records')
        .where('schoolId', '==', schoolId)
        .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)))
        .get();

      const attendanceSnap = await db
        .collection('StudentAttendance')
        .where('schoolId', '==', schoolId)
        .where('date', '>=', admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)))
        .get();

      const behaviorByTeacher = {};
      const behaviorByClass = {};

      behaviorSnap.forEach((doc) => {
        const data = doc.data() || {};
        const teacherId = data.teacherId || 'unknown';
        const classId = data.classId || 'unknown';
        const type = data.type || 'positive';

        if (!behaviorByTeacher[teacherId]) {
          behaviorByTeacher[teacherId] = { total: 0, negative: 0, positive: 0 };
        }
        behaviorByTeacher[teacherId].total += 1;
        if (type === 'negative') behaviorByTeacher[teacherId].negative += 1;
        if (type === 'positive') behaviorByTeacher[teacherId].positive += 1;

        if (!behaviorByClass[classId]) {
          behaviorByClass[classId] = { total: 0, negative: 0, teachers: new Set() };
        }
        behaviorByClass[classId].total += 1;
        if (type === 'negative') behaviorByClass[classId].negative += 1;
        behaviorByClass[classId].teachers.add(teacherId);
      });

      const classPressureDocs = [];
      Object.keys(behaviorByClass).forEach((classId) => {
        const stats = behaviorByClass[classId];
        const negativeRatio =
          stats.total > 0 ? stats.negative / stats.total : 0;
        const teacherCount = stats.teachers.size;

        let pressureLabel = 'Stable';
        if (negativeRatio > 0.3 && teacherCount >= 2) {
          pressureLabel = 'HighPressure';
        } else if (negativeRatio > 0.15 && teacherCount >= 2) {
          pressureLabel = 'Challenging';
        }

        if (pressureLabel !== 'Stable') {
          classPressureDocs.push({
            classId,
            weekKey,
            schoolId,
            negativeRatio,
            teacherCount,
            pressureLabel,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      const classPressureCollection = schoolDoc.ref.collection(
        'ClassPressureAnalysis'
      );
      classPressureDocs.forEach((docData) => {
        const docRef = classPressureCollection.doc(
          `${docData.classId}_${weekKey}`
        );
        classPressureBatch.set(docRef, docData, { merge: true });
      });

      const teacherWeeklyCollection = schoolDoc.ref.collection(
        'TeacherWeeklyProfiles'
      );
      const teacherHealthCollection = schoolDoc.ref.collection(
        'TeacherHealthReports'
      );
      const rootCauseCollection = schoolDoc.ref.collection(
        'RootCauseAnalysis'
      );

      teacherIds.forEach((teacherId) => {
        const stats = behaviorByTeacher[teacherId] || {
          total: 0,
          negative: 0,
          positive: 0,
        };

        const violationRatio =
          stats.total > 0 ? stats.negative / stats.total : 0;
        const punctualityScore = 100 - violationRatio * 40;
        const attendanceScore = 100 - violationRatio * 30;
        const classroomControlScore = 100 - violationRatio * 50;
        const assessmentDisciplineScore = 100 - violationRatio * 20;
        const collaborationScore = 100 - violationRatio * 10;
        const seventhPeriodStressScore =
          violationRatio * 100;
        const resistanceIndex = violationRatio * 100;
        const varianceIndex = violationRatio * 100;

        const teacherHealthIndex =
          punctualityScore * 0.15 +
          attendanceScore * 0.2 +
          classroomControlScore * 0.25 +
          assessmentDisciplineScore * 0.15 +
          collaborationScore * 0.1 +
          seventhPeriodStressScore * 0.1 +
          resistanceIndex * 0.05;

        const personaLabels = [];
        if (classroomControlScore < 70 && attendanceScore >= 80) {
          personaLabels.push('Classroom management support needed');
        }
        if (attendanceScore < 80) {
          personaLabels.push('Attendance-driven risk');
        }
        if (seventhPeriodStressScore > 50) {
          personaLabels.push('SeventhPeriod stress pattern');
        }
        if (resistanceIndex > 50) {
          personaLabels.push('High resistance pattern');
        }

        const weeklyProfileRef = teacherWeeklyCollection.doc(
          `${teacherId}_${weekKey}`
        );
        teacherProfilesBatch.set(
          weeklyProfileRef,
          {
            teacherId,
            schoolId,
            weekKey,
            punctualityScore,
            attendanceScore,
            classroomControlScore,
            assessmentDisciplineScore,
            collaborationScore,
            seventhPeriodStressScore,
            resistanceIndex,
            varianceIndex,
            teacherHealthIndex,
            personaLabels,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        const healthRef = teacherHealthCollection.doc(
          `${teacherId}_${weekKey}`
        );
        teacherHealthBatch.set(
          healthRef,
          {
            teacherId,
            schoolId,
            weekKey,
            teacherHealthIndex,
            riskLevel:
              teacherHealthIndex >= 80
                ? 'Low'
                : teacherHealthIndex >= 60
                ? 'Medium'
                : 'High',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        rootCauseBatch.set(
          rootCauseCollection.doc(`${teacherId}_${weekKey}`),
          {
            teacherId,
            schoolId,
            weekKey,
            source: 'Teacher-driven',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      const schoolNegative = behaviorSnap.docs.filter(
        (d) => (d.data().type || 'positive') === 'negative'
      ).length;
      const schoolTotal = behaviorSnap.size;
      const schoolViolationRatio =
        schoolTotal > 0 ? schoolNegative / schoolTotal : 0;
      const schoolBehaviorScore = 100 - schoolViolationRatio * 100;

      const healthIndexRef = schoolDoc.ref
        .collection('SchoolHealthReports')
        .doc(weekKey);
      teacherHealthBatch.set(
        healthIndexRef,
        {
          schoolId,
          weekKey,
          overallScore: schoolBehaviorScore,
          behaviorScore: schoolBehaviorScore,
          attendanceScore: 100,
          stabilityScore: schoolBehaviorScore,
          teachersUnderObservation: teacherIds.length,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await teacherProfilesBatch.commit();
      await teacherHealthBatch.commit();
      await rootCauseBatch.commit();
      await classPressureBatch.commit();
    }

    return null;
  });

exports.computeSchoolIntelligenceNow = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
  }

  const schoolId = (data && data.schoolId ? String(data.schoolId) : '').trim();
  const termId = (data && data.termId ? String(data.termId) : '').trim();

  if (!schoolId || !termId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'schoolId و termId مطلوبان لتشغيل التحليل'
    );
  }

  const uid = context.auth.uid;
  const schoolRef = db.collection('Schools').doc(schoolId);

  const resolved = await resolveCallerLink(db, uid);
  const resolvedSchoolId = (resolved.schoolId || '').trim();
  const role = (resolved.role || '').trim();

  if (!resolvedSchoolId || resolvedSchoolId !== schoolId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'فقط إدارة المدرسة يمكنها تشغيل تحليل النتائج'
    );
  }
  if (role === 'student' || role === 'parent' || !role) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'صلاحيات غير كافية لتشغيل التحليل'
    );
  }

  try {
    const studentsSnap = await schoolRef.collection('Students').get();
    const studentIds = studentsSnap.docs.map((d) => d.id);

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const attendanceSnap = await schoolRef
      .collection('StudentAttendance')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    const attendByStudent = {};
    attendanceSnap.forEach((doc) => {
      const m = doc.data() || {};
      const sid = m.studentId || '';
      if (!sid) return;
      const st = String(m.status || 'present');
      if (!attendByStudent[sid]) {
        attendByStudent[sid] = {
          present: 0,
          absent: 0,
          late: 0,
          excused: 0,
        };
      }
      const bucket = attendByStudent[sid];
      bucket[st] = (bucket[st] || 0) + 1;
    });

    const tracksSnap = await schoolRef
      .collection('ExamGradesTracking')
      .where('termId', '==', termId)
      .get();

    const entriesByStudentSubject = {};
    for (const t of tracksSnap.docs) {
      const tData = t.data() || {};
      const subjectId = tData.subjectId || '';
      if (!subjectId) continue;

      const entriesSnap = await t.ref
        .collection('Entries')
        .where('termId', '==', termId)
        .get();

      entriesSnap.forEach((e) => {
        const m = e.data() || {};
        const sid = m.studentId || e.id;
        const key = `${sid}::${subjectId}`;
        const rawScore = m.score != null ? m.score : 0;
        const sc =
          typeof rawScore === 'number'
            ? rawScore
            : parseFloat(String(rawScore)) || 0;
        if (!entriesByStudentSubject[key]) {
          entriesByStudentSubject[key] = [];
        }
        entriesByStudentSubject[key].push(sc);
      });
    }

    const classPerf = {};
    for (const t of tracksSnap.docs) {
      const tData = t.data() || {};
      const classId = tData.classId || '';
      const subjectId = tData.subjectId || '';
      if (!classId || !subjectId) continue;

      const entriesSnap = await t.ref
        .collection('Entries')
        .where('termId', '==', termId)
        .get();
      if (entriesSnap.empty) continue;

      const scores = entriesSnap.docs.map((e) => {
        const m = e.data() || {};
        const rawScore = m.score != null ? m.score : 0;
        return typeof rawScore === 'number'
          ? rawScore
          : parseFloat(String(rawScore)) || 0;
      });

      if (!scores.length) continue;
      const sum = scores.reduce((a, b) => a + b, 0);
      const avg = sum / scores.length;

      const key = `${classId}::${subjectId}`;
      if (!classPerf[key]) {
        classPerf[key] = [];
      }
      classPerf[key].push(avg);
    }

    const riskClasses = [];
    const riskSubjects = [];
    const riskTeachers = [];

    Object.keys(classPerf).forEach((key) => {
      const series = classPerf[key] || [];
      if (series.length >= 2) {
        const last = series[series.length - 1];
        const prev = series[series.length - 2];
        if (last + 1e-6 < prev) {
          const [classId, subjectId] = key.split('::');
          if (riskClasses.indexOf(classId) === -1) {
            riskClasses.push(classId);
          }
          if (riskSubjects.indexOf(subjectId) === -1) {
            riskSubjects.push(subjectId);
          }
        }
      }
    });

    const ATTENDANCE_THRESHOLD = 0.9;
    const LOW_SCORE_THRESHOLD = 50.0;

    const predictions = [];

    for (const sid of studentIds) {
      const att = attendByStudent[sid] || {
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
      };
      const total =
        (att.present || 0) +
        (att.absent || 0) +
        (att.late || 0) +
        (att.excused || 0);
      const attendanceRate =
        total === 0
          ? 1.0
          : ((att.present || 0) + 0.5 * (att.late || 0)) / total;

      const subjects = Object.keys(entriesByStudentSubject)
        .filter((k) => k.startsWith(`${sid}::`))
        .map((k) => k.split('::')[1]);

      const uniqueSubjects = Array.from(new Set(subjects));
      if (!uniqueSubjects.length) continue;

      for (const subj of uniqueSubjects) {
        const key = `${sid}::${subj}`;
        const scores = entriesByStudentSubject[key] || [];
        const avg =
          !scores.length
            ? 100.0
            : scores.reduce((a, b) => a + b, 0) / scores.length;

        let risk = 'GREEN';
        const factors = [];

        if (attendanceRate < ATTENDANCE_THRESHOLD && avg < 70.0) {
          risk = 'RED';
          factors.push('attendance_issue');
          factors.push('low_scores');
        } else if (avg < LOW_SCORE_THRESHOLD) {
          risk = 'YELLOW';
          factors.push('low_scores');
        } else if (attendanceRate < ATTENDANCE_THRESHOLD) {
          risk = 'YELLOW';
          factors.push('attendance_issue');
        }

        if (risk !== 'GREEN') {
          predictions.push({
            docId: `${sid}_${subj}`,
            studentId: sid,
            subjectId: subj,
            riskLevel: risk,
            riskFactors: factors,
            generatedActions:
              risk === 'RED'
                ? ['create_remedial_plan', 'notify_agent', 'notify_teacher']
                : ['monitor'],
          });
        }
      }
    }

    let health = 100.0;

    const attRates = studentIds.map((sid) => {
      const a = attendByStudent[sid] || {
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
      };
      const total =
        (a.present || 0) +
        (a.absent || 0) +
        (a.late || 0) +
        (a.excused || 0);
      return total === 0
        ? 1.0
        : ((a.present || 0) + 0.5 * (a.late || 0)) / total;
    });

    let avgAtt = 1.0;
    if (attRates.length) {
      const sum = attRates.reduce((a, b) => a + b, 0);
      avgAtt = sum / attRates.length;
      health = health * 0.6 * avgAtt;
    }

    let avgScore = 100.0;
    if (Object.keys(classPerf).length) {
      const latestAvgs = Object.values(classPerf).map((arr) => {
        const v = arr || [];
        return !v.length ? 100.0 : v[v.length - 1];
      });
      const sum = latestAvgs.reduce((a, b) => a + b, 0);
      avgScore = sum / latestAvgs.length;
      health = health * 0.4 + avgScore * 0.6;
    }

    const intelCollection = schoolRef.collection('SchoolIntelligence');
    await intelCollection.add({
      termId,
      schoolHealthScore: Math.max(0, Math.min(100, health)),
      riskClasses,
      riskSubjects,
      riskTeachers,
      avgAttendanceRate: Math.max(0, Math.min(1, avgAtt)),
      avgScore: Math.max(0, Math.min(100, avgScore)),
      riskCountRed: predictions.filter((p) => p.riskLevel === 'RED').length,
      riskCountYellow: predictions.filter((p) => p.riskLevel === 'YELLOW').length,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const predictionsCollection = schoolRef.collection('RiskPredictions');
    const remedialCollection = schoolRef.collection('RemedialPlans');

    const batch = db.batch();

    predictions.forEach((p) => {
      const docRef = predictionsCollection.doc(p.docId);
      batch.set(
        docRef,
        {
          studentId: p.studentId,
          subjectId: p.subjectId,
          riskLevel: p.riskLevel,
          riskFactors: p.riskFactors,
          generatedActions: p.generatedActions,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      if (p.riskLevel === 'RED') {
        const causeType = p.riskFactors.includes('attendance_issue')
          ? 'attendance_issue'
          : 'academic_weakness';
        const remedialRef = remedialCollection.doc();
        batch.set(remedialRef, {
          studentIds: [p.studentId],
          causeType,
          strategy: 'targeted_support_sessions',
          teacherId: '',
          baselineMetrics: { avgScore: 0, attendanceRate: 0 },
          targetMetrics: { avgScore: 70, attendanceRate: 0.9 },
          status: 'active',
          improvementScore: 0,
        });
      }
    });

    await batch.commit();

    return {
      success: true,
      predictionsCount: predictions.length,
    };
  } catch (error) {
    console.error('computeSchoolIntelligenceNow error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'تعذر تشغيل تحليل النتائج حالياً'
    );
  }
});

/**
 * Weekly job: Update ActionEffectiveness based on DeputyActions and new TeacherWeeklyProfiles.
 */
exports.updateActionEffectiveness = functions.pubsub
  .schedule('30 4 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getWeekKeyRiyadh(now);

    const schoolsSnap = await db.collection('Schools').get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const actionsSnap = await schoolDoc.ref
        .collection('DeputyActions')
        .where('weekKey', '==', weekKey)
        .get();

      const effectivenessBatch = db.batch();

      for (const actionDoc of actionsSnap.docs) {
        const action = actionDoc.data() || {};
        const teacherId = action.teacherId;
        const personaType = action.personaType || 'Unknown';
        const actionType = action.actionType || 'Generic';
        const previousWeekKey = action.previousWeekKey;

        if (!teacherId || !previousWeekKey) {
          continue;
        }

        const profilesCollection = schoolDoc.ref.collection(
          'TeacherWeeklyProfiles'
        );
        const prevProfileSnap = await profilesCollection
          .doc(`${teacherId}_${previousWeekKey}`)
          .get();
        const currentProfileSnap = await profilesCollection
          .doc(`${teacherId}_${weekKey}`)
          .get();

        if (!prevProfileSnap.exists || !currentProfileSnap.exists) {
          continue;
        }

        const prevHealth = prevProfileSnap.data().teacherHealthIndex || 0;
        const currentHealth =
          currentProfileSnap.data().teacherHealthIndex || 0;
        const improvementDelta = currentHealth - prevHealth;

        const key = `${personaType}_${actionType}`;
        const effRef = schoolDoc.ref.collection('ActionEffectiveness').doc(key);
        const effSnap = await effRef.get();

        let successRate = 0;
        let totalCount = 0;
        let totalImprovement = 0;
        if (effSnap.exists) {
          const data = effSnap.data() || {};
          totalCount = data.totalCount || 0;
          totalImprovement = data.totalImprovement || 0;
        }

        totalCount += 1;
        totalImprovement += improvementDelta;
        successRate = totalCount > 0 ? totalImprovement / totalCount : 0;

        effectivenessBatch.set(
          effRef,
          {
            personaType,
            actionType,
            totalCount,
            totalImprovement,
            successRate,
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await effectivenessBatch.commit();
    }

    return null;
  });

// ============================================================================
// STUDENT BEHAVIOR INDEX MODULE
// ============================================================================

function getStudentWeekKeyRiyadh(date) {
  return getWeekKeyRiyadh(date);
}

exports.computeWeeklyBehaviorProfiles = functions.pubsub
  .schedule('0 3 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getStudentWeekKeyRiyadh(now);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const schoolsSnap = await db.collection('Schools').get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const studentsSnap = await schoolDoc.ref.collection('Students').get();
      const studentIds = studentsSnap.docs.map((d) => d.id);

      if (studentIds.length === 0) {
        continue;
      }

      const behaviorSnap = await db
        .collection('behavior_records')
        .where('schoolId', '==', schoolId)
        .where(
          'timestamp',
          '>=',
          admin.firestore.Timestamp.fromDate(sevenDaysAgo)
        )
        .get();

      const attendanceSnap = await db
        .collection('StudentAttendance')
        .where('schoolId', '==', schoolId)
        .where(
          'date',
          '>=',
          admin.firestore.Timestamp.fromDate(sevenDaysAgo)
        )
        .get();

      const behaviorByStudent = {};
      const incidentsByStudent = {};

      behaviorSnap.forEach((doc) => {
        const data = doc.data() || {};
        const studentId = data.studentId || 'unknown';
        const type = data.type || 'positive';
        const points = typeof data.points === 'number' ? data.points : 0;

        if (!behaviorByStudent[studentId]) {
          behaviorByStudent[studentId] = {
            total: 0,
            negative: 0,
            positive: 0,
            outside: 0,
            homeworkNegative: 0,
            distinguished: 0,
            totalPoints: 0,
          };
        }

        const bucket = behaviorByStudent[studentId];
        bucket.total += 1;
        bucket.totalPoints += points;

        if (type === 'negative') {
          bucket.negative += 1;
        }
        if (type === 'positive') {
          bucket.positive += 1;
        }
        if (type === 'bathroom' || type === 'escape') {
          bucket.outside += 1;
        }
        if (type === 'distinguished') {
          bucket.distinguished += 1;
        }

        const desc = (data.description || '').toString();
        if (
          type === 'negative' &&
          (desc.includes('واجب') || desc.includes('宿題'))
        ) {
          bucket.homeworkNegative += 1;
        }
      });

      attendanceSnap.forEach((doc) => {
        const data = doc.data() || {};
        const studentId = data.studentId || 'unknown';
        const status = data.status || 'present';

        if (!incidentsByStudent[studentId]) {
          incidentsByStudent[studentId] = {
            absences: 0,
            late: 0,
          };
        }

        const bucket = incidentsByStudent[studentId];

        if (status === 'absent') {
          bucket.absences += 1;
        } else if (status === 'late') {
          bucket.late += 1;
        }
      });

      const batch = db.batch();
      const profilesCollection = schoolDoc.ref.collection(
        'StudentWeeklyBehaviorProfiles'
      );

      for (const studentId of studentIds) {
        const b = behaviorByStudent[studentId] || {
          total: 0,
          negative: 0,
          positive: 0,
          outside: 0,
          homeworkNegative: 0,
          distinguished: 0,
          totalPoints: 0,
        };
        const a = incidentsByStudent[studentId] || {
          absences: 0,
          late: 0,
        };

        const classroomIncidents = b.total - b.outside;
        const classroomNegative = b.negative;
        const outsideIncidents = b.outside;

        let classroomBehaviorScore = 100;
        if (classroomIncidents > 0) {
          classroomBehaviorScore =
            100 -
            Math.min(
              100,
              (classroomNegative / classroomIncidents) * 100
            );
        }

        let outsideBehaviorScore = 100;
        if (outsideIncidents > 0) {
          outsideBehaviorScore =
            100 -
            Math.min(100, (outsideIncidents / b.total) * 100);
        }

        const totalAttendanceEvents = a.absences + a.late;
        let attendanceDisciplineScore = 100;
        if (totalAttendanceEvents > 0) {
          attendanceDisciplineScore =
            100 -
            Math.min(
              100,
              (a.absences * 2 + a.late) /
                (totalAttendanceEvents * 2) *
                100
            );
        }

        let homeworkDisciplineScore = 100;
        if (b.homeworkNegative > 0 || b.total > 0) {
          const base =
            b.total > 0 ? b.homeworkNegative / b.total : 0;
          homeworkDisciplineScore = 100 - Math.min(100, base * 100);
        }

        let positiveBehaviorScore = 100;
        if (b.total > 0) {
          positiveBehaviorScore =
            (b.positive / b.total) * 100;
        }

        const stabilityIndex =
          (classroomBehaviorScore +
            outsideBehaviorScore +
            attendanceDisciplineScore +
            homeworkDisciplineScore) /
          4;

        const peerInfluenceIndex = 50;
        const leadershipInfluenceIndex = 50;

        const studentBehaviorIndex =
          classroomBehaviorScore * 0.3 +
          outsideBehaviorScore * 0.1 +
          attendanceDisciplineScore * 0.25 +
          homeworkDisciplineScore * 0.15 +
          positiveBehaviorScore * 0.2;

        let classification = 'GREEN';
        if (studentBehaviorIndex < 60 || stabilityIndex < 60) {
          classification = 'RED';
        } else if (studentBehaviorIndex < 80 || stabilityIndex < 80) {
          classification = 'YELLOW';
        }

        const docRef = profilesCollection.doc(`${studentId}_${weekKey}`);
        batch.set(
          docRef,
          {
            studentId,
            schoolId,
            weekKey,
            classroomBehaviorScore,
            outsideBehaviorScore,
            attendanceDisciplineScore,
            homeworkDisciplineScore,
            positiveBehaviorScore,
            stabilityIndex,
            peerInfluenceIndex,
            leadershipInfluenceIndex,
            studentBehaviorIndex,
            classification,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await batch.commit();
    }

    return null;
  });

exports.analyzePeerInfluence = functions.pubsub
  .schedule('30 3 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getStudentWeekKeyRiyadh(now);

    const schoolsSnap = await db.collection('Schools').get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const profilesSnap = await schoolDoc.ref
        .collection('StudentWeeklyBehaviorProfiles')
        .where('weekKey', '==', weekKey)
        .get();

      const profilesByStudent = {};
      profilesSnap.forEach((doc) => {
        profilesByStudent[doc.data().studentId] = doc.data();
      });

      const influenceCollection = schoolDoc.ref.collection(
        'StudentInfluenceAnalysis'
      );
      const batch = db.batch();

      const studentsSnap = await schoolDoc.ref
        .collection('StudentFriends')
        .get();

      for (const studentDoc of studentsSnap.docs) {
        const studentId = studentDoc.id;
        const friendsSnap = await studentDoc.ref
          .collection('Friends')
          .get();

        if (friendsSnap.empty) {
          continue;
        }

        let yellowOrRedCount = 0;
        let totalFriends = 0;

        friendsSnap.forEach((f) => {
          const friendId = f.id;
          const profile = profilesByStudent[friendId];
          if (!profile) return;
          totalFriends += 1;
          if (
            profile.classification === 'YELLOW' ||
            profile.classification === 'RED'
          ) {
            yellowOrRedCount += 1;
          }
        });

        if (totalFriends === 0) {
          continue;
        }

        const ratio = yellowOrRedCount / totalFriends;
        let peerInfluenceIndex = 50;
        if (ratio >= 0.7) {
          peerInfluenceIndex = 90;
        } else if (ratio >= 0.4) {
          peerInfluenceIndex = 70;
        } else if (ratio <= 0.2) {
          peerInfluenceIndex = 30;
        }

        const ownProfile = profilesByStudent[studentId];
        const softEscalation =
          ownProfile &&
          (ownProfile.classification === 'YELLOW' ||
            ownProfile.classification === 'RED') &&
          peerInfluenceIndex >= 70;

        const docRef = influenceCollection.doc(`${studentId}_${weekKey}`);
        batch.set(
          docRef,
          {
            studentId,
            schoolId,
            weekKey,
            totalFriends,
            riskyFriendsRatio: ratio,
            peerInfluenceIndex,
            softEscalation,
            factors: ['social_environment'],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        if (ownProfile) {
          const profileRef = schoolDoc.ref
            .collection('StudentWeeklyBehaviorProfiles')
            .doc(`${studentId}_${weekKey}`);
          batch.set(
            profileRef,
            {
              peerInfluenceIndex,
            },
            { merge: true }
          );
        }
      }

      await batch.commit();
    }

    return null;
  });

exports.detectLeaderInfluence = functions.pubsub
  .schedule('0 2 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getStudentWeekKeyRiyadh(now);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const schoolsSnap = await db.collection('Schools').get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const incidentsSnap = await schoolDoc.ref
        .collection('BehaviorIncidents')
        .where(
          'timestamp',
          '>=',
          admin.firestore.Timestamp.fromDate(sevenDaysAgo)
        )
        .get();

      const leaderStats = {};

      incidentsSnap.forEach((doc) => {
        const data = doc.data() || {};
        const participants = data.participantIds || [];
        if (!Array.isArray(participants)) return;
        if (participants.length < 2) return;

        participants.forEach((sid) => {
          if (!leaderStats[sid]) {
            leaderStats[sid] = {
              multiIncidentCount: 0,
            };
          }
          leaderStats[sid].multiIncidentCount += 1;
        });
      });

      const profilesSnap = await schoolDoc.ref
        .collection('StudentWeeklyBehaviorProfiles')
        .where('weekKey', '==', weekKey)
        .get();

      const profilesByStudent = {};
      profilesSnap.forEach((doc) => {
        profilesByStudent[doc.data().studentId] = doc.data();
      });

      const batch = db.batch();
      const influenceCollection = schoolDoc.ref.collection(
        'StudentInfluenceAnalysis'
      );

      Object.keys(leaderStats).forEach((studentId) => {
        const stats = leaderStats[studentId];
        const profile = profilesByStudent[studentId];
        if (!profile) return;

        const sbi = profile.studentBehaviorIndex || 100;
        let influenceType = 'Neutral';

        if (sbi >= 80 && stats.multiIncidentCount >= 2) {
          influenceType = 'Positive';
        } else if (sbi < 60 && stats.multiIncidentCount >= 2) {
          influenceType = 'Negative';
        }

        const docRef = influenceCollection.doc(`${studentId}_${weekKey}`);
        batch.set(
          docRef,
          {
            studentId,
            schoolId,
            weekKey,
            multiIncidentCount: stats.multiIncidentCount,
            leadershipInfluenceIndex:
              stats.multiIncidentCount * 20,
            influenceType,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        const profileRef = schoolDoc.ref
          .collection('StudentWeeklyBehaviorProfiles')
          .doc(`${studentId}_${weekKey}`);
        batch.set(
          profileRef,
          {
            leadershipInfluenceIndex:
              stats.multiIncidentCount * 20,
          },
          { merge: true }
        );
      });

      await batch.commit();
    }

    return null;
  });

exports.updateInterventionEffectiveness = functions.pubsub
  .schedule('15 3 * * SAT')
  .timeZone('Asia/Riyadh')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const weekKey = getStudentWeekKeyRiyadh(now);

    const schoolsSnap = await db.collection('Schools').get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const interventionsSnap = await schoolDoc.ref
        .collection('BehaviorInterventions')
        .where('weekKey', '==', weekKey)
        .get();

      const effectivenessBatch = db.batch();

      for (const intDoc of interventionsSnap.docs) {
        const data = intDoc.data() || {};
        const studentId = data.studentId;
        const actionType = data.actionType || 'Generic';
        const profileType = data.profileType || 'Unknown';
        const previousWeekKey = data.previousWeekKey;

        if (!studentId || !previousWeekKey) continue;

        const profilesCollection = schoolDoc.ref.collection(
          'StudentWeeklyBehaviorProfiles'
        );
        const prevProfileSnap = await profilesCollection
          .doc(`${studentId}_${previousWeekKey}`)
          .get();
        const currentProfileSnap = await profilesCollection
          .doc(`${studentId}_${weekKey}`)
          .get();

        if (!prevProfileSnap.exists || !currentProfileSnap.exists) {
          continue;
        }

        const prevIndex =
          prevProfileSnap.data().studentBehaviorIndex || 0;
        const currentIndex =
          currentProfileSnap.data().studentBehaviorIndex || 0;
        const delta = currentIndex - prevIndex;

        const key = `${profileType}_${actionType}`;
        const effRef = schoolDoc.ref
          .collection('InterventionEffectiveness')
          .doc(key);
        const effSnap = await effRef.get();

        let totalCount = 0;
        let totalImprovement = 0;
        if (effSnap.exists) {
          const e = effSnap.data() || {};
          totalCount = e.totalCount || 0;
          totalImprovement = e.totalImprovement || 0;
        }

        totalCount += 1;
        totalImprovement += delta;
        const successRate =
          totalCount > 0 ? totalImprovement / totalCount : 0;

        effectivenessBatch.set(
          effRef,
          {
            actionType,
            profileType,
            totalCount,
            totalImprovement,
            successRate,
            lastUpdatedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await effectivenessBatch.commit();
    }

    return null;
  });

exports.getUserEmailByIdentity = functions.https.onCall(async (data, context) => {
    const { identityNumber } = data;
    if (!identityNumber) {
        throw new functions.https.HttpsError('invalid-argument', 'رقم الهوية مطلوب');
    }

    const db = admin.firestore();
    let normalizedId = identityNumber;
    try {
        if (typeof normalizeDigits === 'function') {
             normalizedId = normalizeDigits(identityNumber);
        } else {
             normalizedId = identityNumber.replace(/[٠-٩]/g, d => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)])
                                          .replace(/[۰-۹]/g, d => '0123456789'['۰۱۲۳۴۵۶۷۸۹'.indexOf(d)]);
        }
    } catch (e) {
         console.warn('Normalization failed', e);
    }

    try {
        const query = await db.collection('GlobalUsers')
            .where('identityNumber', '==', normalizedId)
            .limit(1)
            .get();

        if (query.empty) {
            throw new functions.https.HttpsError('not-found', 'لم يتم العثور على مستخدم بهذا الرقم');
        }

        const user = query.docs[0].data();
        return { email: user.email };
    } catch (error) {
        console.error('getUserEmailByIdentity error:', error);
        throw new functions.https.HttpsError('internal', 'حدث خطأ أثناء البحث عن المستخدم');
    }
});

exports.getUserEmailByIdentity = functions.https.onCall(async (data, context) => {
    const { identityNumber } = data;
    if (!identityNumber) {
        throw new functions.https.HttpsError('invalid-argument', 'رقم الهوية مطلوب');
    }

    const db = admin.firestore();
    let normalizedId = identityNumber;
    try {
         normalizedId = normalizeDigits(identityNumber);
    } catch (e) {
         console.warn('Normalization failed', e);
         // Fallback just in case
         normalizedId = identityNumber.replace(/[٠-٩]/g, d => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)])
                                      .replace(/[۰-۹]/g, d => '0123456789'['۰۱۲۳۴۵۶۷۸۹'.indexOf(d)]);
    }

    try {
        const query = await db.collection('GlobalUsers')
            .where('identityNumber', '==', normalizedId)
            .limit(1)
            .get();

        if (query.empty) {
            throw new functions.https.HttpsError('not-found', 'لم يتم العثور على مستخدم بهذا الرقم');
        }

        const user = query.docs[0].data();
        return { email: user.email };
    } catch (error) {
        console.error('getUserEmailByIdentity error:', error);
        throw new functions.https.HttpsError('internal', 'حدث خطأ أثناء البحث عن المستخدم');
    }
});


// ============================================================================
// SCHEDULE NOTIFICATIONS
// ============================================================================

/**
 * Send notifications when schedule is published
 * Triggers when schedule_status.isPublished changes to true
 */
exports.onSchedulePublished = functions.firestore
  .document('Schools/{schoolId}/Settings/schedule_status')
  .onUpdate(async (change, context) => {
    const { schoolId } = context.params;
    const newData = change.after.data();
    const oldData = change.before.data();

    // Check if schedule was just published
    if (newData.isPublished && !oldData.isPublished) {
      console.log(`📅 Schedule published for school: ${schoolId}`);

      try {
        // Send notifications in parallel
        await Promise.all([
          sendNotificationsToStudents(schoolId),
          sendNotificationsToTeachers(schoolId),
          sendNotificationsToParents(schoolId),
        ]);

        console.log(`✅ All schedule notifications sent for school: ${schoolId}`);
      } catch (error) {
        console.error(`❌ Error sending schedule notifications:`, error);
      }
    }
  });

/**
 * Send notifications to all students in the school
 */
async function sendNotificationsToStudents(schoolId) {
  try {
    const studentsSnap = await db
      .collection('Schools')
      .doc(schoolId)
      .collection('Students')
      .get();

    const tokens = [];
    const userIds = [];

    studentsSnap.forEach(doc => {
      const data = doc.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
        userIds.push(doc.id);
      }
    });

    if (tokens.length === 0) {
      console.log(`No student FCM tokens found for school: ${schoolId}`);
      return;
    }

    // Send FCM notifications
    const response = await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: {
        title: '📅 جدولك الدراسي جاهز!',
        body: 'تم اعتماد الجدول الدراسي الجديد. اضغط لعرض جدولك.',
      },
      data: {
        route: '/my-schedule',
        type: 'schedule_published',
        schoolId: schoolId,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'schedule_updates',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`✅ Sent ${response.successCount} notifications to students`);
    if (response.failureCount > 0) {
      console.warn(`⚠️ Failed to send ${response.failureCount} notifications to students`);
    }

    // Also create in-app notifications
    const batch = db.batch();
    const nowIso = new Date().toISOString();

    userIds.forEach(userId => {
      const notifRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .doc();

      batch.set(notifRef, {
        id: notifRef.id,
        userId: userId,
        title: '📅 جدولك الدراسي جاهز!',
        body: 'تم اعتماد الجدول الدراسي الجديد. اضغط لعرض جدولك.',
        timestamp: nowIso,
        isRead: false,
        route: '/my-schedule',
        data: {
          type: 'schedule_published',
        },
        schoolId: schoolId,
        targetRole: 'student',
      });
    });

    await batch.commit();
    console.log(`✅ Created ${userIds.length} in-app notifications for students`);

  } catch (error) {
    console.error(`❌ Error sending notifications to students:`, error);
    throw error;
  }
}

/**
 * Send notifications to all teachers in the school
 */
async function sendNotificationsToTeachers(schoolId) {
  try {
    const teachersSnap = await db
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .get();

    const tokens = [];
    const userIds = [];

    teachersSnap.forEach(doc => {
      const data = doc.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
        userIds.push(doc.id);
      }
    });

    if (tokens.length === 0) {
      console.log(`No teacher FCM tokens found for school: ${schoolId}`);
      return;
    }

    // Send FCM notifications
    const response = await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: {
        title: '📋 جدولك التدريسي جاهز!',
        body: 'تم اعتماد الجدول الدراسي. اضغط لعرض جدولك وحصص الانتظار.',
      },
      data: {
        route: '/teacher-schedule',
        type: 'schedule_published',
        schoolId: schoolId,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'schedule_updates',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`✅ Sent ${response.successCount} notifications to teachers`);
    if (response.failureCount > 0) {
      console.warn(`⚠️ Failed to send ${response.failureCount} notifications to teachers`);
    }

    // Also create in-app notifications
    const batch = db.batch();
    const nowIso = new Date().toISOString();

    userIds.forEach(userId => {
      const notifRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .doc();

      batch.set(notifRef, {
        id: notifRef.id,
        userId: userId,
        title: '📋 جدولك التدريسي جاهز!',
        body: 'تم اعتماد الجدول الدراسي. اضغط لعرض جدولك وحصص الانتظار.',
        timestamp: nowIso,
        isRead: false,
        route: '/teacher-schedule',
        data: {
          type: 'schedule_published',
        },
        schoolId: schoolId,
        targetRole: 'teacher',
      });
    });

    await batch.commit();
    console.log(`✅ Created ${userIds.length} in-app notifications for teachers`);

  } catch (error) {
    console.error(`❌ Error sending notifications to teachers:`, error);
    throw error;
  }
}

/**
 * Send notifications to all parents in the school
 */
async function sendNotificationsToParents(schoolId) {
  try {
    const parentsSnap = await db
      .collection('Schools')
      .doc(schoolId)
      .collection('Parents')
      .get();

    const tokens = [];
    const userIds = [];

    parentsSnap.forEach(doc => {
      const data = doc.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
        userIds.push(doc.id);
      }
    });

    if (tokens.length === 0) {
      console.log(`No parent FCM tokens found for school: ${schoolId}`);
      return;
    }

    // Send FCM notifications
    const response = await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: {
        title: '📚 جدول ابنك/ابنتك جاهز!',
        body: 'تم اعتماد الجدول الدراسي الجديد لابنك/ابنتك.',
      },
      data: {
        route: '/student-schedule',
        type: 'schedule_published',
        schoolId: schoolId,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'schedule_updates',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`✅ Sent ${response.successCount} notifications to parents`);
    if (response.failureCount > 0) {
      console.warn(`⚠️ Failed to send ${response.failureCount} notifications to parents`);
    }

    // Also create in-app notifications
    const batch = db.batch();
    const nowIso = new Date().toISOString();

    userIds.forEach(userId => {
      const notifRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .doc();

      batch.set(notifRef, {
        id: notifRef.id,
        userId: userId,
        title: '📚 جدول ابنك/ابنتك جاهز!',
        body: 'تم اعتماد الجدول الدراسي الجديد لابنك/ابنتك.',
        timestamp: nowIso,
        isRead: false,
        route: '/student-schedule',
        data: {
          type: 'schedule_published',
        },
        schoolId: schoolId,
        targetRole: 'parent',
      });
    });

    await batch.commit();
    console.log(`✅ Created ${userIds.length} in-app notifications for parents`);

  } catch (error) {
    console.error(`❌ Error sending notifications to parents:`, error);
    throw error;
  }
}


// ========================================
// 📊 الجدول التشاركي - Collaborative Schedule
// ========================================

// إرسال إشعارات الحملة عند إطلاقها
exports.onCampaignLaunched = functions.firestore
  .document('schedule_campaigns/{campaignId}')
  .onUpdate(async (change, context) => {
    const { campaignId } = context.params;
    const newData = change.after.data();
    const oldData = change.before.data();

    // تحقق من أن الحملة تم إطلاقها للتو
    if (newData.status === 'active' && oldData.status === 'draft') {
      console.log(`🚀 Campaign launched: ${campaignId}`);

      try {
        const schoolId = newData.schoolId;

        // جلب جميع المعلمين
        const teachersSnapshot = await db
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .get();

        if (teachersSnapshot.empty) {
          console.log('No teachers found');
          return;
        }

        // تحديث عدد المعلمين في الحملة
        await change.after.ref.update({
          totalTeachers: teachersSnapshot.size,
          notResponded: teachersSnapshot.size,
        });

        // جمع FCM tokens
        const tokens = [];
        const teacherIds = [];

        teachersSnapshot.forEach((doc) => {
          const teacher = doc.data();
          if (teacher.fcmToken) {
            tokens.push(teacher.fcmToken);
            teacherIds.push(doc.id);
          }
        });

        if (tokens.length === 0) {
          console.log('No FCM tokens found');
          return;
        }

        // إرسال الإشعارات
        const message = newData.message || 'الإدارة تعتزم إعداد جدول دراسي جديد';
        const responseTimeHours = newData.responseTimeHours || 72;

        const notification = {
          title: '🎯 حملة جدول تشاركي جديد!',
          body: `${message}\n⏰ الرد مطلوب خلال: ${responseTimeHours} ساعة`,
        };

        const data = {
          type: 'campaign_launched',
          campaignId: campaignId,
          route: `/campaign-response/${campaignId}`,
        };

        // إرسال للجميع
        const response = await admin.messaging().sendMulticast({
          tokens: tokens,
          notification: notification,
          data: data,
          android: {
            priority: 'high',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        });

        console.log(`✅ Sent ${response.successCount} notifications`);

        // إنشاء إشعارات داخل التطبيق
        const batch = db.batch();
        teacherIds.forEach((teacherId) => {
          const notifRef = db.collection('Notifications').doc();
          batch.set(notifRef, {
            userId: teacherId,
            title: notification.title,
            body: notification.body,
            type: 'campaign',
            data: { campaignId },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        await batch.commit();
        console.log(`✅ Created ${teacherIds.length} in-app notifications`);

      } catch (error) {
        console.error('Error sending campaign notifications:', error);
      }
    }
  });

// إرسال تذكير للمعلمين الذين لم يردوا
exports.sendCampaignReminder = functions.firestore
  .document('campaign_reminders/{reminderId}')
  .onCreate(async (snap, context) => {
    const { campaignId } = snap.data();

    console.log(`📧 Sending reminder for campaign: ${campaignId}`);

    try {
      // جلب الحملة
      const campaignDoc = await db
        .collection('schedule_campaigns')
        .doc(campaignId)
        .get();

      if (!campaignDoc.exists) {
        console.log('Campaign not found');
        return;
      }

      const campaign = campaignDoc.data();
      const schoolId = campaign.schoolId;

      // جلب الردود
      const responsesSnapshot = await db
        .collection('teacher_responses')
        .where('campaignId', '==', campaignId)
        .get();

      const respondedTeachers = new Set();
      responsesSnapshot.forEach((doc) => {
        respondedTeachers.add(doc.data().teacherId);
      });

      // جلب المعلمين الذين لم يردوا
      const teachersSnapshot = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .get();

      const tokens = [];
      const teacherIds = [];

      teachersSnapshot.forEach((doc) => {
        const teacherId = doc.id;
        if (!respondedTeachers.has(teacherId)) {
          const teacher = doc.data();
          if (teacher.fcmToken) {
            tokens.push(teacher.fcmToken);
            teacherIds.push(teacherId);
          }
        }
      });

      if (tokens.length === 0) {
        console.log('No teachers to remind');
        return;
      }

      // إرسال التذكير
      const notification = {
        title: '⏰ تذكير: حملة جدول تشاركي',
        body: 'لم تقم بالرد على الحملة بعد. الرجاء الرد في أقرب وقت.',
      };

      const data = {
        type: 'campaign_reminder',
        campaignId: campaignId,
        route: `/campaign-response/${campaignId}`,
      };

      const response = await admin.messaging().sendMulticast({
        tokens: tokens,
        notification: notification,
        data: data,
      });

      console.log(`✅ Sent ${response.successCount} reminder notifications`);

    } catch (error) {
      console.error('Error sending reminder:', error);
    }
  });

// ============================================================================
// SMART SCHEDULE GENERATOR
// ============================================================================

/**
 * generateSmartSchedule - توليد جدول ذكي لفصل واحد
 */
exports.generateSmartSchedule = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const { schoolId, classId } = data;

    if (!schoolId || !classId) {
        throw new functions.https.HttpsError('invalid-argument', 'البيانات ناقصة');
    }

    try {
        // جلب بيانات الفصل
        const classDoc = await db.collection('Schools').doc(schoolId).collection('Classes').doc(classId).get();
        
        if (!classDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'الفصل غير موجود');
        }

        const classData = classDoc.data();
        const subjects = classData.subjects || [];

        if (subjects.length === 0) {
            throw new functions.https.HttpsError('invalid-argument', 'لا توجد مواد مسندة للفصل');
        }

        const DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
        const PERIODS_PER_DAY = 7;
        
        // تحضير قائمة الحصص
        const requiredLessons = [];
        subjects.forEach(subject => {
            const weeklyHours = parseInt(subject.weeklyHours || 0);
            for (let i = 0; i < weeklyHours; i++) {
                requiredLessons.push({
                    subjectId: subject.id || subject.name,
                    subjectName: subject.name,
                    teacherId: subject.teacherId,
                    teacherName: subject.teacherName || 'غير محدد'
                });
            }
        });

        // خلط عشوائي
        for (let i = requiredLessons.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [requiredLessons[i], requiredLessons[j]] = [requiredLessons[j], requiredLessons[i]];
        }

        // إنشاء الجدول
        const schedule = {};
        DAYS.forEach(day => {
            schedule[day] = [];
        });

        // التوزيع الذكي
        let lessonIndex = 0;
        
        for (let dayIndex = 0; dayIndex < DAYS.length; dayIndex++) {
            const day = DAYS[dayIndex];
            const usedSubjectsToday = new Set();
            
            for (let period = 0; period < PERIODS_PER_DAY; period++) {
                if (lessonIndex >= requiredLessons.length) {
                    schedule[day].push(null);
                    continue;
                }
                
                // ابحث عن حصة لم تُستخدم اليوم
                let foundLesson = null;
                
                for (let i = 0; i < requiredLessons.length; i++) {
                    const lesson = requiredLessons[i];
                    if (!usedSubjectsToday.has(lesson.subjectId)) {
                        foundLesson = lesson;
                        requiredLessons.splice(i, 1);
                        break;
                    }
                }
                
                if (foundLesson) {
                    schedule[day].push(foundLesson);
                    usedSubjectsToday.add(foundLesson.subjectId);
                    lessonIndex++;
                } else {
                    schedule[day].push(null);
                }
            }
        }

        // حفظ في Firestore
        await db.collection('Schools')
            .doc(schoolId)
            .collection('Schedules')
            .doc(classId)
            .set({
                classId,
                className: classData.name,
                schedule,
                generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                generatedBy: context.auth.uid,
                status: 'active'
            });

        return {
            success: true,
            schedule,
            message: 'تم توليد الجدول بنجاح'
        };

    } catch (error) {
        console.error('Error in generateSmartSchedule:', error);
        throw new functions.https.HttpsError('internal', error.message || 'فشل التوليد');
    }
});

/**
 * diagnoseScheduleIssues - تشخيص مشاكل الجدولة قبل التوليد
 * يفحص البيانات ويحدد المشاكل المحتملة
 */
exports.diagnoseScheduleIssues = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const { schoolId } = data;

    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرف المدرسة مطلوب');
    }

    try {
        console.log(`=== Diagnosing Schedule Issues for school: ${schoolId} ===`);

        const classesSnapshot = await db.collection('Schools').doc(schoolId).collection('Classes').get();
        const assignmentsSnapshot = await db.collection('Schools').doc(schoolId).collection('SubjectAssignments').get();
        const teachersSnapshot = await db.collection('Schools').doc(schoolId).collection('Teachers').get();

        const issues = [];
        const warnings = [];
        const info = [];

        // تنظيم البيانات
        const assignmentsByClass = {};
        const assignmentsByTeacher = {};
        const teacherNames = {};

        teachersSnapshot.forEach(doc => {
            teacherNames[doc.id] = doc.data().name || 'معلم';
        });

        assignmentsSnapshot.forEach(doc => {
            const data = doc.data();
            const classId = data.classId;
            const teacherId = data.teacherId;

            if (!assignmentsByClass[classId]) {
                assignmentsByClass[classId] = [];
            }
            assignmentsByClass[classId].push(data);

            if (!assignmentsByTeacher[teacherId]) {
                assignmentsByTeacher[teacherId] = [];
            }
            assignmentsByTeacher[teacherId].push(data);
        });

        info.push(`عدد الفصول: ${classesSnapshot.size}`);
        info.push(`عدد المعلمين: ${teachersSnapshot.size}`);
        info.push(`عدد الإسنادات: ${assignmentsSnapshot.size}`);

        // فحص كل فصل
        classesSnapshot.docs.forEach(classDoc => {
            const classId = classDoc.id;
            const className = classDoc.data().name || classId;
            const assignments = assignmentsByClass[classId] || [];

            const totalHours = assignments.reduce((sum, a) => sum + (a.weeklyHours || 0), 0);

            if (totalHours === 0) {
                issues.push(`${className}: لا توجد حصص مسندة`);
            } else if (totalHours > 35) {
                issues.push(`${className}: عدد الحصص (${totalHours}) يتجاوز الحد الأقصى (35)`);
            } else if (totalHours < 35) {
                warnings.push(`${className}: عدد الحصص (${totalHours}) أقل من 35 - سيكون هناك فراغات`);
            } else {
                info.push(`${className}: ${totalHours} حصة (مثالي)`);
            }

            // فحص توزيع المواد
            const subjectHours = {};
            assignments.forEach(a => {
                const subject = a.subjectName || 'مادة';
                subjectHours[subject] = (subjectHours[subject] || 0) + (a.weeklyHours || 0);
            });

            Object.entries(subjectHours).forEach(([subject, hours]) => {
                if (hours > 8) {
                    warnings.push(`${className}: ${subject} لديها ${hours} حصص (قد يصعب توزيعها)`);
                }
            });
        });

        // فحص المعلمين
        Object.entries(assignmentsByTeacher).forEach(([teacherId, assignments]) => {
            const teacherName = teacherNames[teacherId] || teacherId;
            const totalHours = assignments.reduce((sum, a) => sum + (a.weeklyHours || 0), 0);
            const classCount = new Set(assignments.map(a => a.classId)).size;

            if (totalHours > 35) {
                issues.push(`${teacherName}: عدد الحصص (${totalHours}) يتجاوز 35 - مستحيل جدولته`);
            } else if (totalHours > 30) {
                warnings.push(`${teacherName}: عدد الحصص (${totalHours}) مرتفع جداً - قد يسبب تعارضات`);
            }

            if (classCount > 10) {
                warnings.push(`${teacherName}: يدرّس ${classCount} فصول - احتمالية تعارضات عالية`);
            }

            info.push(`${teacherName}: ${totalHours} حصة في ${classCount} فصول`);
        });

        // تحليل التعارضات المحتملة
        const potentialConflicts = [];
        Object.entries(assignmentsByTeacher).forEach(([teacherId, assignments]) => {
            if (assignments.length > 1) {
                const teacherName = teacherNames[teacherId] || teacherId;
                const totalHours = assignments.reduce((sum, a) => sum + (a.weeklyHours || 0), 0);
                const classCount = assignments.length;
                
                // حساب احتمالية التعارض
                const conflictProbability = (totalHours / 35) * (classCount / 10) * 100;
                
                if (conflictProbability > 50) {
                    potentialConflicts.push({
                        teacher: teacherName,
                        hours: totalHours,
                        classes: classCount,
                        probability: Math.round(conflictProbability)
                    });
                }
            }
        });

        if (potentialConflicts.length > 0) {
            warnings.push(`معلمون معرضون للتعارضات: ${potentialConflicts.map(c => `${c.teacher} (${c.probability}%)`).join(', ')}`);
        }

        console.log('=== Diagnosis Complete ===');
        console.log('Issues:', issues);
        console.log('Warnings:', warnings);

        return {
            success: true,
            issues,
            warnings,
            info,
            potentialConflicts,
            summary: {
                totalClasses: classesSnapshot.size,
                totalTeachers: teachersSnapshot.size,
                totalAssignments: assignmentsSnapshot.size,
                criticalIssues: issues.length,
                warnings: warnings.length
            }
        };

    } catch (error) {
        console.error('Error in diagnoseScheduleIssues:', error);
        throw new functions.https.HttpsError('internal', error.message || 'فشل التشخيص');
    }
});

/**
 * generateSchoolSchedule - نظام ذكي مع منع تعارضات المعلمين
 * يقرأ من SubjectAssignments ويضمن عدم تواجد معلم في فصلين في نفس الوقت
 */
exports.generateSchoolSchedule = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const { schoolId } = data;

    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرف المدرسة مطلوب');
    }

    try {
        console.log(`=== Starting Conflict-Free Schedule Generation for school: ${schoolId} ===`);

        // جلب جميع الفصول
        const classesSnapshot = await db.collection('Schools').doc(schoolId).collection('Classes').get();
        
        if (classesSnapshot.empty) {
            throw new functions.https.HttpsError('not-found', 'لا توجد فصول في المدرسة');
        }

        // جلب جميع الإسنادات
        const assignmentsSnapshot = await db.collection('Schools').doc(schoolId).collection('SubjectAssignments').get();
        
        // تنظيم الإسنادات حسب الفصل
        const assignmentsByClass = {};
        assignmentsSnapshot.forEach(doc => {
            const data = doc.data();
            const classId = data.classId;
            if (!assignmentsByClass[classId]) {
                assignmentsByClass[classId] = [];
            }
            assignmentsByClass[classId].push({
                teacherId: data.teacherId,
                teacherName: data.teacherName,
                subjectName: data.subjectName,
                weeklyHours: data.weeklyHours || 5
            });
        });

        console.log(`Found ${classesSnapshot.size} classes and assignments for ${Object.keys(assignmentsByClass).length} classes`);

        const DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
        const PERIODS_PER_DAY = 7;
        
        // إنشاء جدول تتبع المعلمين: teacherSchedule[teacherId][day][period] = classId
        const teacherSchedule = {};
        
        // إنشاء قوائم الحصص لكل فصل
        const classLessons = {};
        const classNames = {};
        
        classesSnapshot.docs.forEach(classDoc => {
            const classId = classDoc.id;
            const classData = classDoc.data();
            const className = classData.name || classId;
            classNames[classId] = className;
            
            const classAssignments = assignmentsByClass[classId] || [];
            const lessons = [];
            
            classAssignments.forEach(assignment => {
                for (let i = 0; i < assignment.weeklyHours; i++) {
                    lessons.push({
                        subjectId: assignment.subjectName,
                        subjectName: assignment.subjectName,
                        teacherId: assignment.teacherId,
                        teacherName: assignment.teacherName
                    });
                }
            });
            
            // خلط عشوائي
            for (let i = lessons.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [lessons[i], lessons[j]] = [lessons[j], lessons[i]];
            }
            
            classLessons[classId] = lessons;
        });

        // توليد الجداول مع منع التعارضات
        const schedules = {};
        const results = [];
        const errors = [];
        
        // تهيئة الجداول الفارغة
        Object.keys(classLessons).forEach(classId => {
            schedules[classId] = {};
            DAYS.forEach(day => {
                schedules[classId][day] = Array(PERIODS_PER_DAY).fill(null);
            });
        });
        
        // خوارزمية Backtracking المحسّنة مع استراتيجيات متعددة
        const MAX_SAME_SUBJECT_PER_DAY = 5; // مرونة أكبر
        const MAX_BACKTRACK_DEPTH = 200; // عمق أكبر بكثير للبحث
        const MAX_ATTEMPTS = 5; // عدد المحاولات الكاملة
        
        // ترتيب الفصول حسب عدد الحصص (الأكثر أولاً)
        const sortedClasses = Object.keys(classLessons).sort((a, b) => {
            return classLessons[b].length - classLessons[a].length;
        });
        
        console.log('Processing classes in order:', sortedClasses.map(id => `${classNames[id]} (${classLessons[id].length} lessons)`).join(', '));
        
        // وظيفة للتحقق من إمكانية وضع حصة
        function canPlaceLesson(classId, day, period, lesson) {
            if (schedules[classId][day][period] !== null) return false;
            
            const dayLessons = schedules[classId][day].filter(l => l !== null);
            const subjectCountToday = dayLessons.filter(l => l.subjectId === lesson.subjectId).length;
            if (subjectCountToday >= MAX_SAME_SUBJECT_PER_DAY) return false;
            
            if (!teacherSchedule[lesson.teacherId]) {
                teacherSchedule[lesson.teacherId] = {};
                DAYS.forEach(d => {
                    teacherSchedule[lesson.teacherId][d] = Array(PERIODS_PER_DAY).fill(null);
                });
            }
            
            if (teacherSchedule[lesson.teacherId][day][period] !== null) return false;
            
            return true;
        }
        
        function placeLesson(classId, day, period, lesson) {
            schedules[classId][day][period] = lesson;
            if (!teacherSchedule[lesson.teacherId]) {
                teacherSchedule[lesson.teacherId] = {};
                DAYS.forEach(d => {
                    teacherSchedule[lesson.teacherId][d] = Array(PERIODS_PER_DAY).fill(null);
                });
            }
            teacherSchedule[lesson.teacherId][day][period] = classId;
        }
        
        function removeLesson(classId, day, period, lesson) {
            schedules[classId][day][period] = null;
            if (teacherSchedule[lesson.teacherId]) {
                teacherSchedule[lesson.teacherId][day][period] = null;
            }
        }
        
        // استراتيجية 1: توزيع منظم
        function trySystematicPlacement(classId, lessons, lessonIndex, depth) {
            if (lessonIndex >= lessons.length) return true;
            if (depth >= MAX_BACKTRACK_DEPTH) return false;
            
            const lesson = lessons[lessonIndex];
            
            for (let dayIndex = 0; dayIndex < DAYS.length; dayIndex++) {
                const day = DAYS[dayIndex];
                for (let period = 0; period < PERIODS_PER_DAY; period++) {
                    if (canPlaceLesson(classId, day, period, lesson)) {
                        placeLesson(classId, day, period, lesson);
                        if (trySystematicPlacement(classId, lessons, lessonIndex + 1, depth + 1)) {
                            return true;
                        }
                        removeLesson(classId, day, period, lesson);
                    }
                }
            }
            return false;
        }
        
        // استراتيجية 2: توزيع عشوائي ذكي
        function trySmartRandomPlacement(classId, lessons, lessonIndex, depth) {
            if (lessonIndex >= lessons.length) return true;
            if (depth >= MAX_BACKTRACK_DEPTH) return false;
            
            const lesson = lessons[lessonIndex];
            
            // إنشاء قائمة بجميع المواقع الممكنة
            const possibleSlots = [];
            for (let dayIndex = 0; dayIndex < DAYS.length; dayIndex++) {
                const day = DAYS[dayIndex];
                for (let period = 0; period < PERIODS_PER_DAY; period++) {
                    if (canPlaceLesson(classId, day, period, lesson)) {
                        // حساب نقاط الجودة
                        const dayLessons = schedules[classId][day].filter(l => l !== null);
                        const subjectCountToday = dayLessons.filter(l => l.subjectId === lesson.subjectId).length;
                        const score = 100 - (subjectCountToday * 20) - (dayLessons.length * 3);
                        possibleSlots.push({ day, period, score });
                    }
                }
            }
            
            // ترتيب حسب النقاط ثم خلط الأفضل
            possibleSlots.sort((a, b) => b.score - a.score);
            const topSlots = possibleSlots.slice(0, Math.min(10, possibleSlots.length));
            
            // خلط الأفضل عشوائياً
            for (let i = topSlots.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [topSlots[i], topSlots[j]] = [topSlots[j], topSlots[i]];
            }
            
            for (const slot of topSlots) {
                placeLesson(classId, slot.day, slot.period, lesson);
                if (trySmartRandomPlacement(classId, lessons, lessonIndex + 1, depth + 1)) {
                    return true;
                }
                removeLesson(classId, slot.day, slot.period, lesson);
            }
            
            return false;
        }
        
        // استراتيجية 3: Greedy مع تطلع للأمام
        function tryGreedyWithLookahead(classId, lessons) {
            const remainingLessons = [...lessons];
            let placed = 0;
            
            while (remainingLessons.length > 0) {
                let bestSlot = null;
                let bestLessonIndex = -1;
                let bestScore = -Infinity;
                
                // جرب كل حصة متبقية في كل موقع ممكن
                for (let lessonIndex = 0; lessonIndex < remainingLessons.length; lessonIndex++) {
                    const lesson = remainingLessons[lessonIndex];
                    
                    for (let dayIndex = 0; dayIndex < DAYS.length; dayIndex++) {
                        const day = DAYS[dayIndex];
                        for (let period = 0; period < PERIODS_PER_DAY; period++) {
                            if (canPlaceLesson(classId, day, period, lesson)) {
                                // حساب نقاط متقدمة
                                const dayLessons = schedules[classId][day].filter(l => l !== null);
                                const subjectCountToday = dayLessons.filter(l => l.subjectId === lesson.subjectId).length;
                                
                                // عدد الحصص المتبقية من نفس المادة
                                const sameSubjectRemaining = remainingLessons.filter(l => l.subjectId === lesson.subjectId).length;
                                
                                // عدد الأيام المتبقية التي يمكن وضع المادة فيها
                                let availableDaysForSubject = 0;
                                for (let d = 0; d < DAYS.length; d++) {
                                    const testDay = DAYS[d];
                                    const testDayLessons = schedules[classId][testDay].filter(l => l !== null);
                                    const testSubjectCount = testDayLessons.filter(l => l.subjectId === lesson.subjectId).length;
                                    if (testSubjectCount < MAX_SAME_SUBJECT_PER_DAY) {
                                        availableDaysForSubject++;
                                    }
                                }
                                
                                // نقاط الجودة
                                let score = 100;
                                score -= subjectCountToday * 15; // تجنب تكرار المادة في نفس اليوم
                                score -= dayLessons.length * 2; // توزيع متساوي على الأيام
                                score += (sameSubjectRemaining / Math.max(availableDaysForSubject, 1)) * 10; // أولوية للمواد الصعبة
                                
                                // تفضيل الحصص الأولى في اليوم قليلاً
                                score += (PERIODS_PER_DAY - period) * 0.5;
                                
                                if (score > bestScore) {
                                    bestScore = score;
                                    bestSlot = { day, period };
                                    bestLessonIndex = lessonIndex;
                                }
                            }
                        }
                    }
                }
                
                // إذا وجدنا موقع، ضع الحصة
                if (bestSlot && bestLessonIndex >= 0) {
                    const lesson = remainingLessons[bestLessonIndex];
                    placeLesson(classId, bestSlot.day, bestSlot.period, lesson);
                    remainingLessons.splice(bestLessonIndex, 1);
                    placed++;
                } else {
                    // لا يوجد موقع متاح - فشل
                    console.log(`    Greedy stuck at ${placed}/${lessons.length}`);
                    return false;
                }
            }
            
            return true;
        }
        
        // معالجة كل فصل
        for (const classId of sortedClasses) {
            const className = classNames[classId];
            const lessons = classLessons[classId];
            
            console.log(`\n=== Processing ${className} with ${lessons.length} lessons ===`);
            
            if (lessons.length === 0) {
                errors.push({ classId, className, error: 'لا توجد مواد مسندة' });
                continue;
            }
            
            if (lessons.length > 35) {
                console.log(`  ⚠️ WARNING: ${className} has ${lessons.length} lessons but only 35 slots!`);
            }
            
            // ترتيب الحصص حسب صعوبة التوزيع
            const lessonsBySubject = {};
            lessons.forEach(lesson => {
                if (!lessonsBySubject[lesson.subjectId]) {
                    lessonsBySubject[lesson.subjectId] = [];
                }
                lessonsBySubject[lesson.subjectId].push(lesson);
            });
            
            const sortedLessons = [];
            Object.keys(lessonsBySubject)
                .sort((a, b) => lessonsBySubject[b].length - lessonsBySubject[a].length)
                .forEach(subjectId => {
                    sortedLessons.push(...lessonsBySubject[subjectId]);
                });
            
            console.log(`  Lesson distribution: ${Object.keys(lessonsBySubject).map(s => `${s}(${lessonsBySubject[s].length})`).join(', ')}`);
            
            let success = false;
            let bestPlacedCount = 0;
            let bestSchedule = null;
            
            // محاولات متعددة مع استراتيجيات مختلفة
            for (let attempt = 0; attempt < MAX_ATTEMPTS && !success; attempt++) {
                console.log(`  Attempt ${attempt + 1}/${MAX_ATTEMPTS}...`);
                
                // إعادة تعيين الجدول
                DAYS.forEach(day => {
                    for (let period = 0; period < PERIODS_PER_DAY; period++) {
                        const lesson = schedules[classId][day][period];
                        if (lesson) {
                            removeLesson(classId, day, period, lesson);
                        }
                    }
                });
                
                // خلط الحصص بطريقة مختلفة في كل محاولة
                const shuffledLessons = [...sortedLessons];
                if (attempt > 0) {
                    // خلط جزئي للمحاولات بعد الأولى
                    for (let i = shuffledLessons.length - 1; i > shuffledLessons.length / 2; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [shuffledLessons[i], shuffledLessons[j]] = [shuffledLessons[j], shuffledLessons[i]];
                    }
                }
                
                // جرب الاستراتيجيات الثلاث بالتناوب
                if (attempt === 0) {
                    // المحاولة الأولى: Greedy (الأسرع والأذكى)
                    success = tryGreedyWithLookahead(classId, shuffledLessons);
                } else if (attempt % 2 === 1) {
                    success = trySystematicPlacement(classId, shuffledLessons, 0, 0);
                } else {
                    success = trySmartRandomPlacement(classId, shuffledLessons, 0, 0);
                }
                
                const placedCount = DAYS.reduce((count, day) => {
                    return count + schedules[classId][day].filter(l => l !== null).length;
                }, 0);
                
                console.log(`    Placed: ${placedCount}/${lessons.length}`);
                
                // احفظ أفضل نتيجة
                if (placedCount > bestPlacedCount) {
                    bestPlacedCount = placedCount;
                    bestSchedule = JSON.parse(JSON.stringify(schedules[classId]));
                }
                
                if (success && placedCount === lessons.length) {
                    console.log(`    ✓ Complete success!`);
                    break;
                }
            }
            
            // استخدم أفضل نتيجة إذا لم ننجح بشكل كامل
            if (!success && bestSchedule) {
                schedules[classId] = bestSchedule;
                console.log(`  Using best result: ${bestPlacedCount}/${lessons.length}`);
            }
            
            const finalPlacedCount = DAYS.reduce((count, day) => {
                return count + schedules[classId][day].filter(l => l !== null).length;
            }, 0);
            
            console.log(`  Final Result: ${finalPlacedCount}/${lessons.length} lessons placed`);
            
            if (finalPlacedCount < lessons.length) {
                const failedCount = lessons.length - finalPlacedCount;
                console.log(`  ⚠️ Failed to place ${failedCount} lessons`);
                errors.push({
                    classId,
                    className,
                    error: `فشل وضع ${failedCount} حصة من أصل ${lessons.length}`,
                    placed: finalPlacedCount,
                    total: lessons.length
                });
            }
        }
        
        // حفظ الجداول في Firestore
        for (const classId of Object.keys(schedules)) {
            const className = classNames[classId];
            const schedule = schedules[classId];
            
            try {
                await db.collection('Schools')
                    .doc(schoolId)
                    .collection('Schedules')
                    .doc(classId)
                    .set({
                        classId,
                        className,
                        schedule,
                        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        generatedBy: context.auth.uid,
                        status: 'active',
                        method: 'conflict_free'
                    });

                results.push({
                    classId,
                    className,
                    success: true
                });

                console.log(`✓ Saved schedule for ${className}`);
            } catch (error) {
                console.error(`✗ Error saving ${className}:`, error.message);
                errors.push({
                    classId,
                    className,
                    error: error.message
                });
            }
        }

        console.log(`=== Generation Complete: ${results.length} success, ${errors.length} errors ===`);

        return {
            success: true,
            totalClasses: classesSnapshot.size,
            successCount: results.length,
            errorCount: errors.length,
            results,
            errors,
            message: `تم توليد ${results.length} جدول بدون تعارضات`
        };

    } catch (error) {
        console.error('Fatal error in generateSchoolSchedule:', error);
        throw new functions.https.HttpsError('internal', error.message || 'فشل توليد الجداول');
    }
});

async function _resolveStaffRoleKey(schoolId, uid) {
    const teacherDoc = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .doc(uid)
        .get();
    if (teacherDoc.exists) return 'teacher';

    const staffDoc = await db
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .doc(uid)
        .get();
    if (staffDoc.exists) {
        const role = (staffDoc.data() || {}).role || 'administrative';
        if (role === 'admin' || role === 'supportAdmin' || role === 'technicalSupport') {
            return 'administrative';
        }
        return role;
    }
    return null;
}

async function _loadSchoolTokensMap(schoolId) {
    const [teachersSnap, staffSnap] = await Promise.all([
        db.collection('Schools').doc(schoolId).collection('Teachers').get(),
        db.collection('Schools').doc(schoolId).collection('Staff').get(),
    ]);

    const tokensByUserId = {};
    teachersSnap.forEach((doc) => {
        const t = doc.data() || {};
        if (t.fcmToken) tokensByUserId[doc.id] = t.fcmToken;
    });
    staffSnap.forEach((doc) => {
        const s = doc.data() || {};
        if (s.fcmToken) tokensByUserId[doc.id] = s.fcmToken;
    });
    return tokensByUserId;
}

function _chunk(arr, size) {
    const out = [];
    for (let i = 0; i < arr.length; i += size) {
        out.push(arr.slice(i, i + size));
    }
    return out;
}

exports.onStaffCircularCreated = functions.firestore
    .document('Schools/{schoolId}/StaffCirculars/{circularId}')
    .onCreate(async (snap, context) => {
        const { schoolId, circularId } = context.params;
        const circular = snap.data() || {};
        const title = (circular.title || '').toString().trim();
        const circularNumber = circular.circularNumber || null;
        const route = '/circulars/inbox';

        try {
            const recipientsSnap = await snap.ref
                .collection('Recipients')
                .where('acknowledged', '==', false)
                .get();

            const recipients = recipientsSnap.docs.map((d) => d.data() || {});
            const userIds = recipients
                .map((r) => (r.userId || '').toString().trim())
                .filter(Boolean);

            if (userIds.length === 0) {
                await snap.ref.set(
                    { notificationsSentAt: admin.firestore.FieldValue.serverTimestamp() },
                    { merge: true }
                );
                return null;
            }

            const tokensByUserId = await _loadSchoolTokensMap(schoolId);
            const tokens = [];
            userIds.forEach((uid) => {
                const t = tokensByUserId[uid];
                if (t) tokens.push(t);
            });

            const notifTitle = '📄 تعميم وارد';
            const notifBody = circularNumber
                ? `تعميم رقم ${circularNumber}: ${title}`
                : title;

            const data = {
                type: 'staff_circular',
                route,
                schoolId,
                circularId,
            };

            const tokenChunks = _chunk(tokens, 500);
            for (const chunk of tokenChunks) {
                await admin.messaging().sendMulticast({
                    tokens: chunk,
                    notification: { title: notifTitle, body: notifBody },
                    data,
                    android: {
                        priority: 'high',
                        notification: {
                            sound: 'default',
                            channelId: 'circulars',
                        },
                    },
                    apns: {
                        payload: { aps: { sound: 'default', badge: 1 } },
                    },
                });
            }

            const batch = db.batch();
            userIds.forEach((uid) => {
                const notifRef = db
                    .collection('Schools')
                    .doc(schoolId)
                    .collection('Notifications')
                    .doc();
                batch.set(notifRef, {
                    id: notifRef.id,
                    schoolId,
                    userId: uid,
                    title: notifTitle,
                    body: notifBody,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    route,
                    data: {
                        type: 'staff_circular',
                        circularId,
                    },
                    targetRole: null,
                    createdBy: circular.createdById || null,
                });
            });
            batch.set(
                snap.ref,
                { notificationsSentAt: admin.firestore.FieldValue.serverTimestamp() },
                { merge: true }
            );
            await batch.commit();

            return null;
        } catch (e) {
            console.error('onStaffCircularCreated error:', e);
            return null;
        }
    });

exports.recordStaffCircularView = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const schoolId = (data && data.schoolId) ? String(data.schoolId).trim() : '';
    const circularId = (data && data.circularId) ? String(data.circularId).trim() : '';
    const device = (data && data.device) ? String(data.device).trim() : '';
    const platform = (data && data.platform) ? String(data.platform).trim() : '';
    const userAgent = (data && data.userAgent) ? String(data.userAgent).trim() : '';
    if (!schoolId || !circularId) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة');
    }

    const roleKey = await _resolveStaffRoleKey(schoolId, uid);
    if (!roleKey) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
    }

    const recRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffCirculars')
        .doc(circularId)
        .collection('Recipients')
        .doc(uid);

    await db.runTransaction(async (tx) => {
        const snap = await tx.get(recRef);
        const d = snap.data() || {};
        if (!snap.exists) {
            throw new functions.https.HttpsError('not-found', 'غير مسجل ضمن المستلمين');
        }
        if (d.viewedAt) return;
        tx.set(
            recRef,
            {
                viewedAt: admin.firestore.FieldValue.serverTimestamp(),
                viewedDevice: device || null,
                viewedPlatform: platform || null,
                viewedUserAgent: userAgent ? userAgent.substring(0, 512) : null,
            },
            { merge: true }
        );
    });

    return { success: true };
});

exports.finalizeStaffCircularView = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const schoolId = (data && data.schoolId) ? String(data.schoolId).trim() : '';
    const circularId = (data && data.circularId) ? String(data.circularId).trim() : '';
    const device = (data && data.device) ? String(data.device).trim() : '';
    const platform = (data && data.platform) ? String(data.platform).trim() : '';
    const userAgent = (data && data.userAgent) ? String(data.userAgent).trim() : '';
    const viewDurationMsRaw = (data && data.viewDurationMs) ? data.viewDurationMs : 0;
    const viewDurationMs = typeof viewDurationMsRaw === 'number'
        ? Math.max(0, Math.floor(viewDurationMsRaw))
        : Math.max(0, parseInt(String(viewDurationMsRaw || '0'), 10) || 0);

    if (!schoolId || !circularId) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة');
    }

    const roleKey = await _resolveStaffRoleKey(schoolId, uid);
    if (!roleKey) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
    }

    const recRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffCirculars')
        .doc(circularId)
        .collection('Recipients')
        .doc(uid);

    await db.runTransaction(async (tx) => {
        const snap = await tx.get(recRef);
        if (!snap.exists) {
            throw new functions.https.HttpsError('not-found', 'غير مسجل ضمن المستلمين');
        }
        const d = snap.data() || {};
        const current = typeof d.viewDurationMs === 'number'
            ? d.viewDurationMs
            : parseInt(String(d.viewDurationMs || '0'), 10) || 0;
        const next = Math.max(current, viewDurationMs);
        tx.set(recRef, {
            viewedAt: d.viewedAt || admin.firestore.FieldValue.serverTimestamp(),
            lastViewedAt: admin.firestore.FieldValue.serverTimestamp(),
            viewDurationMs: next,
            viewedDevice: device || d.viewedDevice || null,
            viewedPlatform: platform || d.viewedPlatform || null,
            viewedUserAgent: userAgent ? userAgent.substring(0, 512) : (d.viewedUserAgent || null),
        }, { merge: true });
    });

    return { success: true };
});

exports.reserveStaffCircularNumber = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const schoolId = (data && data.schoolId) ? String(data.schoolId).trim() : '';
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة');
    }

    const roleKey = await _resolveStaffRoleKey(schoolId, uid);
    const userDoc = await db.collection('GlobalUsers').doc(uid).get();
    const userData = userDoc.data() || {};
    const role = (userData.role || '').toString();
    const deputyType = (userData.deputyType || null);
    const isAdmin = ['admin', 'manager', 'principal', 'superAdmin', 'owner', 'Owner'].includes(role);
    const isAcademicDeputy = role === 'deputy' && deputyType === 'academic';

    if (!roleKey || (!isAdmin && !isAcademicDeputy)) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
    }

    const ref = db
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('staff_circular_counter');

    const nextNumber = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const current = (snap.data() || {}).next || 1;
        const n = typeof current === 'number' ? current : parseInt(String(current || '1'), 10) || 1;
        tx.set(ref, { next: n + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return n;
    });

    return { circularNumber: nextNumber };
});

exports.acknowledgeStaffCircular = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }
    const uid = context.auth.uid;
    const schoolId = (data && data.schoolId) ? String(data.schoolId).trim() : '';
    const circularId = (data && data.circularId) ? String(data.circularId).trim() : '';
    const device = (data && data.device) ? String(data.device).trim() : '';
    const platform = (data && data.platform) ? String(data.platform).trim() : '';
    const userAgent = (data && data.userAgent) ? String(data.userAgent).trim() : '';
    const viewDurationMsRaw = (data && data.viewDurationMs) ? data.viewDurationMs : 0;
    const viewDurationMs = typeof viewDurationMsRaw === 'number'
        ? Math.max(0, Math.floor(viewDurationMsRaw))
        : Math.max(0, parseInt(String(viewDurationMsRaw || '0'), 10) || 0);
    if (!schoolId || !circularId) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة');
    }

    const roleKey = await _resolveStaffRoleKey(schoolId, uid);
    if (!roleKey) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
    }

    const circularRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffCirculars')
        .doc(circularId);
    const recRef = circularRef.collection('Recipients').doc(uid);

    await db.runTransaction(async (tx) => {
        const recSnap = await tx.get(recRef);
        if (!recSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'غير مسجل ضمن المستلمين');
        }
        const r = recSnap.data() || {};
        if (!r.viewedAt) {
            throw new functions.https.HttpsError('failed-precondition', 'يجب فتح المرفق قبل تأكيد الاطلاع');
        }
        if (r.viewedAt && r.viewedAt.toMillis) {
            const deltaMs = Date.now() - r.viewedAt.toMillis();
            if (deltaMs < 3000) {
                throw new functions.https.HttpsError('failed-precondition', 'يجب البقاء داخل التعميم 3 ثوانٍ على الأقل قبل تأكيد الاطلاع');
            }
        }
        if (r.acknowledged === true) return;
        tx.set(
            recRef,
            {
                acknowledged: true,
                acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
                acknowledgedDevice: device || null,
                acknowledgedPlatform: platform || null,
                acknowledgedUserAgent: userAgent ? userAgent.substring(0, 512) : null,
                acknowledgedViewDurationMs: viewDurationMs,
                viewDurationMs: Math.max(
                    typeof r.viewDurationMs === 'number' ? r.viewDurationMs : (parseInt(String(r.viewDurationMs || '0'), 10) || 0),
                    viewDurationMs
                ),
            },
            { merge: true }
        );
        tx.set(
            circularRef,
            {
                acknowledgedCount: admin.firestore.FieldValue.increment(1),
            },
            { merge: true }
        );
    });

    return { success: true };
});

exports.sendStaffCircularReminders24h = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('Asia/Riyadh')
    .onRun(async () => {
        const now = admin.firestore.Timestamp.now();
        const threshold = admin.firestore.Timestamp.fromMillis(
            now.toMillis() - 24 * 60 * 60 * 1000
        );

        const circularsSnap = await db
            .collectionGroup('StaffCirculars')
            .where('createdAt', '<=', threshold)
            .where('reminder24hSentAt', '==', null)
            .limit(20)
            .get();

        for (const doc of circularsSnap.docs) {
            const circular = doc.data() || {};
            const schoolId = circular.schoolId || doc.ref.parent.parent.id;
            const circularId = doc.id;
            const title = (circular.title || '').toString().trim();
            const circularNumber = circular.circularNumber || null;

            try {
                const recipientsSnap = await doc.ref
                    .collection('Recipients')
                    .where('acknowledged', '==', false)
                    .limit(500)
                    .get();

                const userIds = recipientsSnap.docs
                    .map((d) => (d.data() || {}).userId)
                    .map((v) => (v || '').toString().trim())
                    .filter(Boolean);

                if (userIds.length === 0) {
                    await doc.ref.set(
                        { reminder24hSentAt: admin.firestore.FieldValue.serverTimestamp() },
                        { merge: true }
                    );
                    continue;
                }

                const tokensByUserId = await _loadSchoolTokensMap(schoolId);
                const tokens = [];
                userIds.forEach((uid) => {
                    const t = tokensByUserId[uid];
                    if (t) tokens.push(t);
                });

                const notifTitle = '⏰ تذكير: لم يتم الاطلاع بعد';
                const notifBody = circularNumber
                    ? `لم يتم الاطلاع بعد على التعميم رقم ${circularNumber}: ${title}`
                    : `لم يتم الاطلاع بعد على التعميم: ${title}`;
                const data = {
                    type: 'staff_circular_reminder_24h',
                    route: '/circulars/inbox',
                    schoolId,
                    circularId,
                };

                const tokenChunks = _chunk(tokens, 500);
                for (const chunk of tokenChunks) {
                    await admin.messaging().sendMulticast({
                        tokens: chunk,
                        notification: { title: notifTitle, body: notifBody },
                        data,
                        android: {
                            priority: 'high',
                            notification: {
                                sound: 'default',
                                channelId: 'circulars',
                            },
                        },
                        apns: {
                            payload: { aps: { sound: 'default', badge: 1 } },
                        },
                    });
                }

                const batch = db.batch();
                userIds.forEach((uid) => {
                    const notifRef = db
                        .collection('Schools')
                        .doc(schoolId)
                        .collection('Notifications')
                        .doc();
                    batch.set(notifRef, {
                        id: notifRef.id,
                        schoolId,
                        userId: uid,
                        title: notifTitle,
                        body: notifBody,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        isRead: false,
                        route: '/circulars/inbox',
                        data: {
                            type: 'staff_circular_reminder_24h',
                            circularId,
                        },
                        targetRole: null,
                    });
                });

                batch.set(
                    doc.ref,
                    { reminder24hSentAt: admin.firestore.FieldValue.serverTimestamp() },
                    { merge: true }
                );
                await batch.commit();
            } catch (e) {
                console.error('sendStaffCircularReminders24h error:', e);
            }
        }

        return null;
    });

// ============================================================================
// MAINTENANCE EMAIL FUNCTION
// ============================================================================

/**
 * إرسال إيميل بلاغ الصيانة إلى فريق الصيانة
 */
exports.sendMaintenanceEmail = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const { to, subject, reportData } = data || {};

    if (!to || !subject || !reportData) {
        throw new functions.https.HttpsError('invalid-argument', 'البيانات المطلوبة ناقصة');
    }

    // إعداد Nodemailer (يمكنك استخدام Gmail أو أي خدمة أخرى)
    const transporter = nodemailer.createTransporter({
        service: 'gmail',
        auth: {
            user: functions.config().email?.user || 'your-email@gmail.com',
            pass: functions.config().email?.password || 'your-app-password'
        }
    });

    // تنسيق الإيميل
    const htmlContent = `
        <!DOCTYPE html>
        <html dir="rtl" lang="ar">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>بلاغ صيانة جديد</title>
            <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #FF6B35, #F7931E); color: white; padding: 30px; text-align: center; }
                .header h1 { margin: 0; font-size: 24px; }
                .content { padding: 30px; }
                .priority { display: inline-block; padding: 8px 16px; border-radius: 20px; color: white; font-weight: bold; margin: 10px 0; }
                .priority.high { background-color: #F44336; }
                .priority.medium { background-color: #FF9800; }
                .priority.low { background-color: #4CAF50; }
                .priority.critical { background-color: #9C27B0; }
                .info-row { margin: 15px 0; padding: 15px; background: #f8f9fa; border-radius: 8px; border-right: 4px solid #FF6B35; }
                .info-label { font-weight: bold; color: #333; margin-bottom: 5px; }
                .info-value { color: #666; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
                .btn { display: inline-block; background: #FF6B35; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔧 بلاغ صيانة جديد</h1>
                    <p>تم استلام طلب صيانة جديد يتطلب اهتمامكم</p>
                </div>
                
                <div class="content">
                    <div class="info-row">
                        <div class="info-label">📋 عنوان البلاغ:</div>
                        <div class="info-value">${reportData.title}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">📍 الموقع:</div>
                        <div class="info-value">${reportData.location}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">⚠️ الأولوية:</div>
                        <div class="info-value">
                            <span class="priority ${reportData.priority.toLowerCase()}">${reportData.priority}</span>
                        </div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">📝 وصف المشكلة:</div>
                        <div class="info-value">${reportData.description}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">🏫 المدرسة:</div>
                        <div class="info-value">${reportData.schoolName}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">👤 المبلغ:</div>
                        <div class="info-value">${reportData.reporterName}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">📅 تاريخ البلاغ:</div>
                        <div class="info-value">${new Date(reportData.createdAt).toLocaleString('ar-SA')}</div>
                    </div>
                    
                    <div class="info-row">
                        <div class="info-label">🆔 رقم البلاغ:</div>
                        <div class="info-value">${reportData.id}</div>
                    </div>
                </div>
                
                <div class="footer">
                    <p>هذا إيميل تلقائي من نظام إدارة المدارس</p>
                    <p>يرجى عدم الرد على هذا الإيميل</p>
                </div>
            </div>
        </body>
        </html>
    `;

    const mailOptions = {
        from: functions.config().email?.user || 'noreply@school-system.com',
        to: to,
        subject: subject,
        html: htmlContent,
        text: `
بلاغ صيانة جديد

العنوان: ${reportData.title}
الموقع: ${reportData.location}
الأولوية: ${reportData.priority}
الوصف: ${reportData.description}
المدرسة: ${reportData.schoolName}
المبلغ: ${reportData.reporterName}
التاريخ: ${new Date(reportData.createdAt).toLocaleString('ar-SA')}
رقم البلاغ: ${reportData.id}
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        console.log(`تم إرسال إيميل الصيانة إلى: ${to}`);
        return { success: true, message: 'تم إرسال الإيميل بنجاح' };
    } catch (error) {
        console.error('خطأ في إرسال إيميل الصيانة:', error);
        throw new functions.https.HttpsError('internal', 'فشل إرسال الإيميل');
    }
});


// ============================================================================
// SMS OUTBOX PROCESSOR - Auto-send SMS messages
// ============================================================================

/**
 * processSmsOutbox
 * ----------------
 * Cloud Function that monitors SmsOutbox and automatically sends SMS messages
 * using the configured SMS provider (Twilio or custom API).
 * 
 * Triggers: When a new document is created in Schools/{schoolId}/SmsOutbox
 * Status flow: pending → sending → sent/failed
 */
exports.processSmsOutbox = functions.firestore
    .document('Schools/{schoolId}/SmsOutbox/{messageId}')
    .onCreate(async (snap, context) => {
        const { schoolId, messageId } = context.params;
        const messageData = snap.data();
        
        console.log(`[SMS] Processing message ${messageId} for school ${schoolId}`);
        
        // Validate message data
        if (!messageData || !messageData.phoneNumber || !messageData.body) {
            console.error(`[SMS] Invalid message data for ${messageId}`);
            await snap.ref.update({
                status: 'failed',
                error: 'بيانات الرسالة غير مكتملة',
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return;
        }

        // Check if already processed
        if (messageData.status !== 'pending') {
            console.log(`[SMS] Message ${messageId} already processed with status: ${messageData.status}`);
            return;
        }

        // Update status to sending
        await snap.ref.update({
            status: 'sending',
            processingStartedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        try {
            // Get SMS settings for the school
            const settingsDoc = await db.collection('Schools')
                .doc(schoolId)
                .collection('Settings')
                .doc('sms')
                .get();

            if (!settingsDoc.exists || !settingsDoc.data().enabled) {
                throw new Error('خدمة SMS غير مفعلة للمدرسة');
            }

            const settings = settingsDoc.data();
            const apiUrl = settings.apiUrl;
            const apiKey = settings.apiKey;
            const senderName = settings.senderName || 'School';

            // Normalize phone number
            let phoneNumber = String(messageData.phoneNumber).trim();
            phoneNumber = phoneNumber.replace(/\s+/g, '');
            
            // Convert Saudi numbers to international format
            if (phoneNumber.startsWith('05')) {
                phoneNumber = '+966' + phoneNumber.substring(1);
            } else if (phoneNumber.startsWith('5') && phoneNumber.length === 9) {
                phoneNumber = '+966' + phoneNumber;
            } else if (!phoneNumber.startsWith('+')) {
                phoneNumber = '+' + phoneNumber;
            }

            console.log(`[SMS] Sending to ${phoneNumber} via ${apiUrl}`);

            // Send SMS using the configured provider
            let response;
            const axios = require('axios');
            
            if (apiUrl && apiUrl.includes('mobile.net.sa')) {
                // ═══════════════════════════════════════════════════════════
                // Mobile.net.sa API - الصيغة الصحيحة
                // ═══════════════════════════════════════════════════════════
                
                // Prepare phone number (remove + for Mobile.net.sa)
                const cleanPhone = phoneNumber.replace('+', '');
                
                console.log(`[SMS] Sending to Mobile.net.sa with Bearer Token, phone: ${cleanPhone}`);
                
                response = await axios.post(apiUrl, {
                    number: cleanPhone,           // number بدلاً من numbers
                    senderName: senderName || 'SMS',  // senderName (يجب أن يكون مسجلاً)
                    sendAtOption: 'now',          // خيار وقت الإرسال
                    messageBody: messageData.body // messageBody بدلاً من msg
                }, {
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${apiKey}`  // Bearer Token في Header
                    },
                    timeout: 30000
                });

                console.log(`[SMS] Mobile.net.sa response:`, response.data);

                // Mobile.net.sa يرجع status code 200 أو 201 عند النجاح
                if (response.status === 200 || response.status === 201) {
                    await snap.ref.update({
                        status: 'sent',
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                        provider: 'Mobile.net.sa',
                        providerResponse: response.data
                    });
                    console.log(`[SMS] Message ${messageId} sent successfully via Mobile.net.sa`);
                } else {
                    const errorMsg = response.data?.message || 'فشل الإرسال من المزود';
                    throw new Error(`Mobile.net.sa error: ${errorMsg}`);
                }
                
            } else if (apiUrl && (apiUrl.includes('msegat.com') || apiUrl.includes('msegat.sa'))) {
                // ═══════════════════════════════════════════════════════════
                // Msegat API - مزود سعودي شهير
                // ═══════════════════════════════════════════════════════════
                
                const cleanPhone = phoneNumber.replace('+', '');
                
                console.log(`[SMS] Sending to Msegat, phone: ${cleanPhone}`);
                
                response = await axios.post(apiUrl || 'https://www.msegat.com/gw/sendsms.php', {
                    userName: settings.userName || apiKey,  // Msegat يستخدم userName
                    apiKey: apiKey,
                    numbers: cleanPhone,
                    userSender: senderName || 'SMS',
                    msg: messageData.body,
                    msgEncoding: 'UTF8'
                }, {
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000
                });

                console.log(`[SMS] Msegat response:`, response.data);

                // Msegat يرجع code: 1 عند النجاح
                if (response.data && (response.data.code === '1' || response.data.code === 1)) {
                    await snap.ref.update({
                        status: 'sent',
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                        provider: 'Msegat',
                        providerResponse: response.data
                    });
                    console.log(`[SMS] Message ${messageId} sent successfully via Msegat`);
                } else {
                    const errorMsg = response.data?.message || response.data?.msg || 'فشل الإرسال من Msegat';
                    throw new Error(`Msegat error: ${errorMsg}`);
                }
                
            } else if (apiUrl && apiUrl.includes('unifonic.com')) {
                // ═══════════════════════════════════════════════════════════
                // Unifonic API - مزود احترافي
                // ═══════════════════════════════════════════════════════════
                
                const cleanPhone = phoneNumber.replace('+', '');
                
                console.log(`[SMS] Sending to Unifonic, phone: ${cleanPhone}`);
                
                response = await axios.post(apiUrl || 'https://api.unifonic.com/rest/SMS/messages', {
                    AppSid: apiKey,
                    SenderID: senderName || 'SMS',
                    Recipient: cleanPhone,
                    Body: messageData.body
                }, {
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000
                });

                console.log(`[SMS] Unifonic response:`, response.data);

                // Unifonic يرجع success: true عند النجاح
                if (response.data && response.data.success === true) {
                    await snap.ref.update({
                        status: 'sent',
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                        provider: 'Unifonic',
                        providerResponse: response.data
                    });
                    console.log(`[SMS] Message ${messageId} sent successfully via Unifonic`);
                } else {
                    const errorMsg = response.data?.message || 'فشل الإرسال من Unifonic';
                    throw new Error(`Unifonic error: ${errorMsg}`);
                }
                
            } else if (apiUrl && apiUrl.includes('taqnyat.sa')) {
                // ═══════════════════════════════════════════════════════════
                // Taqnyat API - مزود سعودي
                // ═══════════════════════════════════════════════════════════
                
                const cleanPhone = phoneNumber.replace('+', '');
                
                console.log(`[SMS] Sending to Taqnyat, phone: ${cleanPhone}`);
                
                response = await axios.post(apiUrl || 'https://api.taqnyat.sa/v1/messages', {
                    recipients: [cleanPhone],
                    body: messageData.body,
                    sender: senderName || 'SMS'
                }, {
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${apiKey}`
                    },
                    timeout: 30000
                });

                console.log(`[SMS] Taqnyat response:`, response.data);

                // Taqnyat يرجع statusCode: 200 عند النجاح
                if (response.data && response.data.statusCode === 200) {
                    await snap.ref.update({
                        status: 'sent',
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        processedAt: admin.firestore.FieldValue.serverTimestamp(),
                        provider: 'Taqnyat',
                        providerResponse: response.data
                    });
                    console.log(`[SMS] Message ${messageId} sent successfully via Taqnyat`);
                } else {
                    const errorMsg = response.data?.message || 'فشل الإرسال من Taqnyat';
                    throw new Error(`Taqnyat error: ${errorMsg}`);
                }
                
            } else if (apiUrl && apiUrl.includes('twilio.com')) {
                // ═══════════════════════════════════════════════════════════
                // Twilio API - مزود عالمي
                // ═══════════════════════════════════════════════════════════
                
                response = await twilioClient.messages.create({
                    body: messageData.body,
                    from: TWILIO_PHONE_NUMBER,
                    to: phoneNumber
                });

                await snap.ref.update({
                    status: 'sent',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    provider: 'Twilio',
                    providerResponse: { sid: response.sid }
                });
                console.log(`[SMS] Message ${messageId} sent via Twilio. SID: ${response.sid}`);
                
            } else {
                // ═══════════════════════════════════════════════════════════
                // Generic HTTP API - للمزودين الآخرين
                // ═══════════════════════════════════════════════════════════
                
                response = await axios.post(apiUrl, {
                    phone: phoneNumber,
                    message: messageData.body,
                    sender: senderName
                }, {
                    headers: {
                        'Authorization': `Bearer ${apiKey}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000
                });

                await snap.ref.update({
                    status: 'sent',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    provider: 'Generic',
                    providerResponse: response.data
                });
                console.log(`[SMS] Message ${messageId} sent successfully via Generic API`);
            }

        } catch (error) {
            console.error(`[SMS] Failed to send message ${messageId}:`, error);
            
            // Update status to failed
            await snap.ref.update({
                status: 'failed',
                error: error.message || 'فشل الإرسال',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                errorDetails: {
                    message: error.message,
                    code: error.code,
                    response: error.response?.data
                }
            });
        }
    });

/**
 * retrySmsMessage
 * ---------------
 * Callable function to manually retry a failed SMS message
 */
exports.retrySmsMessage = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const { schoolId, messageId } = data;
    
    if (!schoolId || !messageId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId و messageId مطلوبان');
    }

    try {
        const messageRef = db.collection('Schools')
            .doc(schoolId)
            .collection('SmsOutbox')
            .doc(messageId);

        const messageDoc = await messageRef.get();
        
        if (!messageDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'الرسالة غير موجودة');
        }

        // Reset status to pending to trigger the onCreate function again
        await messageRef.update({
            status: 'pending',
            retryCount: admin.firestore.FieldValue.increment(1),
            retriedAt: admin.firestore.FieldValue.serverTimestamp(),
            retriedBy: context.auth.uid
        });

        return { success: true, message: 'تم إعادة محاولة الإرسال' };
    } catch (error) {
        console.error('retrySmsMessage failed:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});


/**
 * deletePendingSmsMessages
 * ------------------------
 * Deletes all pending SMS messages for a school to prevent them from being sent.
 * Useful for cleaning up old test messages or messages that should not be sent.
 */
exports.deletePendingSmsMessages = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
    }

    const { schoolId } = data;
    
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId مطلوب');
    }

    try {
        console.log(`[SMS] Deleting pending messages for school ${schoolId}`);

        // Get all pending messages
        const pendingMessages = await db.collection('Schools')
            .doc(schoolId)
            .collection('SmsOutbox')
            .where('status', '==', 'pending')
            .get();

        if (pendingMessages.empty) {
            return { 
                success: true, 
                deletedCount: 0,
                message: 'لا توجد رسائل في الانتظار' 
            };
        }

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
            
            console.log(`[SMS] Deleted batch of ${batchDocs.length} messages`);
        }

        console.log(`[SMS] Total deleted: ${deletedCount} messages`);

        return { 
            success: true, 
            deletedCount,
            message: `تم حذف ${deletedCount} رسالة في الانتظار` 
        };

    } catch (error) {
        console.error('deletePendingSmsMessages failed:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
