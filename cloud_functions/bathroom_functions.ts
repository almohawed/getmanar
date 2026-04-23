import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

// 1. Scheduled Cloud Function (Every 5 Minutes)
export const checkRedBathroomPasses = functions.pubsub
    .schedule('every 5 minutes')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        
        // Query active passes that exceeded red time
        const snapshot = await db.collectionGroup('BathroomPasses')
            .where('status', '==', 'approved')
            .where('redAt', '<', now)
            .where('redNotified', '==', false)
            .get();

        const batch = db.batch();
        
        for (const doc of snapshot.docs) {
            const data = doc.data();
            const passId = doc.id;
            const schoolId = data.schoolId;
            const studentId = data.studentId;
            const teacherId = data.teacherId;
            
            // A. Update Pass Status
            batch.update(doc.ref, {
                status: 'locked_red',
                redNotified: true,
                lockedAt: now
            });

            // B. Write Teacher Delay Log
            // Path: Schools/{schoolId}/TeacherDelayLogs/{teacherId}/Records/{id}
            const delayLogRef = db.doc(`Schools/${schoolId}/TeacherDelayLogs/${teacherId}/Records/${passId}`);
            batch.set(delayLogRef, {
                passId: passId,
                studentId: studentId,
                teacherId: teacherId,
                schoolId: schoolId,
                timestamp: now,
                reason: 'Pass exceeded red limit (15 mins)',
                redAt: data.redAt,
                lockedAt: now
            });

            // C. Send Notifications (via Notification Collection Trigger)
            // We create notification records in Firestore, which the system should handle (e.g., via onNotificationCreated)
            // Notify: Parent, Teacher, Deputy Academic, Deputy Students
            
            // 1. Parent Notification
            const parentNotifRef = db.collection(`Schools/${schoolId}/Notifications`).doc();
            batch.set(parentNotifRef, {
                id: parentNotifRef.id,
                userId: studentId, // Targeted at student (parent watches student)
                schoolId: schoolId,
                targetRole: 'parent',
                title: 'تنبيه تأخير',
                body: 'تجاوز الطالب المدة المسموحة في دورة المياه (الحالة الحمراء).',
                timestamp: now,
                data: {'passId': passId, 'type': 'bathroom_red'},
                read: false
            });

            // 2. Teacher Notification
            const teacherNotifRef = db.collection(`Schools/${schoolId}/Notifications`).doc();
            batch.set(teacherNotifRef, {
                id: teacherNotifRef.id,
                userId: teacherId,
                schoolId: schoolId,
                targetRole: 'teacher',
                title: 'تنبيه تأخير طالب',
                body: 'تجاوز الطالب المدة المسموحة. الإذن مغلق الآن (أحمر).',
                timestamp: now,
                data: {'passId': passId, 'type': 'bathroom_red'},
                read: false
            });

            // 3. Deputy Notifications (Academic & Students)
            // We send to roles 'deputy' generally, or specific users if we knew them.
            // Using targetRole 'deputy' usually broadcasts to all deputies.
            const deputyNotifRef = db.collection(`Schools/${schoolId}/Notifications`).doc();
            batch.set(deputyNotifRef, {
                id: deputyNotifRef.id,
                schoolId: schoolId,
                targetRole: 'deputy', // Covers both academic and students usually
                title: 'تجاوز مدة دورة المياه',
                body: 'طالب تجاوز 15 دقيقة (الحالة الحمراء). يرجى المتابعة.',
                timestamp: now,
                data: {'passId': passId, 'type': 'bathroom_red'},
                read: false
            });
        }
        
        await batch.commit();
        console.log(`Processed ${snapshot.size} red bathroom passes.`);
    });

// 2. OnCreate BathroomPass Guard
export const onBathroomPassCreated = functions.firestore
    .document('Schools/{schoolId}/BathroomPasses/{passId}')
    .onCreate(async (snap, context) => {
        const newData = snap.data();
        const studentId = newData.studentId;
        const schoolId = context.params.schoolId;
        const currentPassId = context.params.passId;
        
        // Active Pass Guard: Prevent duplicate active passes
        const activePasses = await db.collection(`Schools/${schoolId}/BathroomPasses`)
            .where('studentId', '==', studentId)
            .where('status', 'in', ['approved', 'locked_red'])
            .get();
            
        // If we find ANY other pass that is not THIS one
        const duplicates = activePasses.docs.filter(doc => doc.id !== currentPassId);
        
        if (duplicates.length > 0) {
            console.log(`Found ${duplicates.length} active passes for student ${studentId}. Deleting new pass ${currentPassId}.`);
            
            // Delete the newly created pass to enforce 1-active-pass rule
            await snap.ref.delete();
            
            // Optionally notify the teacher who tried to create it?
            // This might be hard since the request is already done.
            // Client-side checks should prevent this, this is a safety net.
        }
    });
