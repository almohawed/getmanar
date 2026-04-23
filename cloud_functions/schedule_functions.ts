import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

/**
 * Trigger: When a new ScheduleRun is created.
 * Logic: If mode is collaborative, notify all teachers to submit preferences.
 */
export const onScheduleRunCreated = functions.firestore
    .document('Schools/{schoolId}/ScheduleRuns/{runId}')
    .onCreate(async (snap, context) => {
        const runData = snap.data();
        const schoolId = context.params.schoolId;

        if (!runData) return;

        // Check if mode is collaborative and status is collecting
        if (runData.mode === 'collaborative' && runData.status === 'collecting') {
            console.log(`New Collaborative Schedule Run for School ${schoolId}. Notifying teachers...`);

            // 1. Get all teachers in the school
            // Assuming users are stored in 'Schools/{schoolId}/Teachers' or handled via Auth
            // Based on memory: Teachers are in `Schools/{schoolId}/Teachers`
            const teachersSnap = await db.collection('Schools')
                .doc(schoolId)
                .collection('Teachers')
                .get();

            const tokens: string[] = [];

            // 2. Collect FCM tokens
            // Assuming token is stored in teacher document or a separate tokens collection
            // We'll assume a field 'fcmToken' exists on the teacher profile for simplicity,
            // or we might need to look up in a separate collection.
            for (const doc of teachersSnap.docs) {
                const teacherData = doc.data();
                if (teacherData.fcmToken) {
                    tokens.push(teacherData.fcmToken);
                }
            }

            if (tokens.length === 0) {
                console.log('No teacher tokens found.');
                return;
            }

            // 3. Send Notification
            const message = {
                notification: {
                    title: 'جمع رغبات الجدول المدرسي',
                    body: 'تم فتح باب تقديم الرغبات للجدول الجديد. يرجى الدخول وإرسال رغباتك قبل الموعد المحدد.',
                },
                data: {
                    type: 'schedule_collection',
                    runId: context.params.runId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
            };

            // Send to device groups or topics is better, but here we multicast to tokens
            // Batching if > 500
            const response = await fcm.sendToDevice(tokens, message);
            console.log(`Notifications sent: ${response.successCount} success, ${response.failureCount} failure.`);
        }
    });

/**
 * Trigger: Scheduled every hour.
 * Logic: Check for expired 'collecting' runs, lock them, and notify Deputy.
 */
export const checkScheduleRunDeadlines = functions.pubsub
    .schedule('every 60 minutes')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();

        // Query all Schools (Collection Group might be better if ScheduleRuns is subcollection)
        // Using collectionGroup query for 'ScheduleRuns'
        const runsSnap = await db.collectionGroup('ScheduleRuns')
            .where('status', '==', 'collecting')
            .where('collectUntil', '<=', now)
            .get();

        if (runsSnap.empty) {
            return null;
        }

        const batch = db.batch();
        const notifications: Promise<any>[] = [];

        for (const doc of runsSnap.docs) {
            // Update status to locked
            batch.update(doc.ref, { status: 'locked' });

            // Notify Deputy/Admin (Creator)
            const runData = doc.data();
            const creatorId = runData.createdBy;
            const schoolId = doc.ref.parent.parent!.id;

            if (creatorId) {
                // Fetch creator's token
                // Trying to find user in Staff or Teachers
                // We'll check Staff first
                let userDoc = await db.doc(`Schools/${schoolId}/Staff/${creatorId}`).get();
                if (!userDoc.exists) {
                    userDoc = await db.doc(`Schools/${schoolId}/Teachers/${creatorId}`).get();
                }

                if (userDoc.exists) {
                    const userData = userDoc.data();
                    if (userData && userData.fcmToken) {
                        const message = {
                            notification: {
                                title: 'انتهاء فترة تجميع الرغبات',
                                body: 'انتهت المهلة المحددة لتجميع رغبات المعلمين. يمكنك الآن البدء في توليد الجدول.',
                            },
                            data: {
                                type: 'schedule_locked',
                                runId: doc.id,
                                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                            },
                            token: userData.fcmToken,
                        };
                        notifications.push(fcm.send(message));
                    }
                }
            }
        }

        await batch.commit();
        await Promise.all(notifications);
        console.log(`Processed ${runsSnap.size} expired schedule runs.`);
        return null;
    });
