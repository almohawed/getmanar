import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// A. Bathroom Red Repeat
// Trigger: On BathroomPass write (create/update)
export const onBathroomPassWritten = functions.firestore
  .document("Schools/{schoolId}/BathroomPasses/{passId}")
  .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after) return; // Deleted

    const schoolId = context.params.schoolId;
    const studentId = after.studentId;
    const status = after.status;

    // Only care if status is 'locked_red'
    if (status !== "locked_red") return;

    // Check history (last 14 days)
    const now = new Date();
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

    const snapshot = await db
      .collection(`Schools/${schoolId}/BathroomPasses`)
      .where("studentId", "==", studentId)
      .where("status", "==", "locked_red")
      .where("startTime", ">=", admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
      .get();

    const count = snapshot.size; // Includes current one if it matches query

    // Thresholds
    if (count >= 5) {
        // Counselor Task
        await createAdminTask(schoolId, {
            title: `إحالة سلوكية - تكرار حمام (أحمر) - طالب ${studentId}`,
            description: `تكرر تجاوز وقت الحمام (الحالة الحمراء) ${count} مرات خلال 14 يوم.`,
            priority: "high",
            assignedTo: "counselor", // Role
            type: "behavior_referral",
            relatedStudentId: studentId,
        });
    } else if (count >= 3) {
        // Deputy Task
        await createAdminTask(schoolId, {
            title: `تكرار حالة حمراء - طالب ${studentId}`,
            description: `تكرر تجاوز وقت الحمام (الحالة الحمراء) ${count} مرات خلال 14 يوم.`,
            priority: "medium",
            assignedTo: "deputy_students", // Role
            type: "behavior_warning",
            relatedStudentId: studentId,
        });
    }
  });

// B. Unexcused Late Repeat
// Trigger: On StudentAttendance write
export const onAttendanceWritten = functions.firestore
  .document("StudentAttendance/{attendanceId}")
  .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after) return;

    const studentId = after.studentId;
    const schoolId = after.schoolId;
    const status = after.status;

    if (status !== "late") return;

    const now = new Date();
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

    // Query Top-Level Collection
    const snapshot = await db
      .collection("StudentAttendance")
      .where("schoolId", "==", schoolId)
      .where("studentId", "==", studentId)
      .where("status", "==", "late")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
      .get();

    const count = snapshot.size;

    if (count >= 5) {
        // Counselor
        await createAdminTask(schoolId, {
            title: `إحالة سلوكية - تكرار تأخر - طالب ${studentId}`,
            description: `تكرر التأخر الصباحي ${count} مرات خلال 14 يوم.`,
            priority: "high",
            assignedTo: "counselor",
            type: "attendance_referral",
            relatedStudentId: studentId,
        });
    } else if (count >= 3) {
        // Deputy
        await createAdminTask(schoolId, {
            title: `تكرار تأخر صباحي - طالب ${studentId}`,
            description: `تكرر التأخر الصباحي ${count} مرات خلال 14 يوم.`,
            priority: "medium",
            assignedTo: "deputy_students",
            type: "attendance_warning",
            relatedStudentId: studentId,
        });
    }
  });

// C. Behavior Stale Escalation
// Scheduled: Daily
export const checkBehaviorEscalation = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    // Query Top-Level Collection 'behavior_records'
    // We need to group by schoolId to create tasks in correct school path.
    // Since we can't easily group by schoolId in one query without iterating all,
    // we'll query all active stale records and iterate.
    
    const snapshot = await db
      .collection("behavior_records")
      .where("status", "==", "active")
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    const batch = db.batch();
    
    // To avoid creating duplicate tasks every day for the same stale record,
    // we should check if a task exists or mark the record as 'escalated'.
    // For this requirement, we'll assume we create a task if not already escalated.
    // Or we can check if an AdminTask exists for this violationId.
    
    for (const doc of snapshot.docs) {
      const record = doc.data();
      const schoolId = record.schoolId;
      if (!schoolId) continue;

      // Check for existing escalation task
      const taskQuery = await db
        .collection(`Schools/${schoolId}/AdminTasks`)
        .where("relatedViolationId", "==", doc.id)
        .where("type", "==", "escalation")
        .limit(1)
        .get();

      if (taskQuery.empty) {
        const newTaskRef = db.collection(`Schools/${schoolId}/AdminTasks`).doc();
        batch.set(newTaskRef, {
            title: `تصعيد مخالفة: ${record.description ?? 'مخالفة سلوكية'}`,
            description: `مخالفة مفتوحة منذ أكثر من 7 أيام بدون إغلاق.`,
            priority: "high",
            assignedTo: "manager", // Escalate to Manager/Admin
            status: "open",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "escalation",
            relatedViolationId: doc.id,
        });
      }
    }

    await batch.commit();
    console.log(`Checked ${snapshot.size} stale behavior records.`);
  });

// D. Schedule Runs Expiry (Collaborative Preferences)
// Scheduled: Every 5 minutes
export const checkScheduleRunsExpiry = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collectionGroup("ScheduleRuns")
      .where("status", "==", "collecting")
      .where("collectUntil", "<=", now)
      .get();

    if (snapshot.empty) {
      console.log("No ScheduleRuns to lock.");
      return;
    }

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const schoolId = data.schoolId as string | undefined;
      if (!schoolId) continue;

      batch.update(doc.ref, {
        status: "locked",
      });

      const notificationsRef = db.collection(
        `Schools/${schoolId}/Notifications`
      );
      const notificationDoc = notificationsRef.doc();

      batch.set(notificationDoc, {
        id: notificationDoc.id,
        schoolId,
        userId: null,
        title: "انتهت مهلة استقبال رغبات الجدول",
        body:
          "انتهت المهلة المحددة لاستقبال رغبات المعلمين للجدول التشاركي. يمكنك الآن توليد الجدول الذكي من شاشة إنشاء الجدول، مع مراعاة العدالة بين المعلمين، وعدم اعتبار عدم الرد عذراً للتغيب عن الحصص.",
        timestamp: new Date().toISOString(),
        isRead: false,
        route: "/create-schedule",
        data: {
          scheduleRunId: doc.id,
        },
        targetRole: "deputy",
        targetClassId: null,
      });
    }

    await batch.commit();
    console.log(`Locked ${snapshot.size} ScheduleRuns and notified deputies.`);
  });

// Helper
async function createAdminTask(schoolId: string, taskData: any) {
    // Check for duplicate open task of same type for same student to avoid spam
    // (Optional optimization, but good for "Repeat" logic)
    const existing = await db.collection(`Schools/${schoolId}/AdminTasks`)
        .where("relatedStudentId", "==", taskData.relatedStudentId)
        .where("type", "==", taskData.type)
        .where("status", "==", "open")
        .limit(1)
        .get();

    if (!existing.empty) return;

    await db.collection(`Schools/${schoolId}/AdminTasks`).add({
        ...taskData,
        status: "open",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function getUserRoleAndSchool(uid: string) {
  const snap = await db.collection("GlobalUsers").doc(uid).get();
  if (!snap.exists) {
    return null;
  }
  const data = snap.data() || {};
  return {
    role: (data.role as string) || "",
    schoolId: (data.schoolId as string) || "",
  };
}

export const sendSchoolNotification = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const title = (data.title as string) || "";
    const body = (data.body as string) || "";
    const targetUserId = (data.targetUserId as string | undefined) ?? null;
    const targetRole = (data.targetRole as string | undefined) ?? null;
    const targetClassId =
      (data.targetClassId as string | undefined) ?? null;
    const route = (data.route as string | undefined) ?? null;
    const extraData = (data.data as any | undefined) ?? null;

    if (!schoolId || !title || !body) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الإشعار غير مكتملة",
      );
    }

    const userInfo = await getUserRoleAndSchool(uid);
    if (!userInfo || userInfo.schoolId !== schoolId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "صلاحيات غير كافية لهذه المدرسة",
      );
    }

    const allowedRoles = [
      "manager",
      "admin",
      "principal",
      "deputy",
      "deputy_students",
      "deputy_academic",
      "teacher",
      "counselor",
    ];
    if (!allowedRoles.includes(userInfo.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "صلاحيات غير كافية لإرسال الإشعارات",
      );
    }

    const notificationsRef = db.collection(
      `Schools/${schoolId}/Notifications`,
    );
    const notificationDoc = notificationsRef.doc();

    await notificationDoc.set({
      id: notificationDoc.id,
      schoolId,
      userId: targetUserId,
      title,
      body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      route,
      data: extraData,
      targetRole,
      targetClassId,
      createdBy: uid,
    });

    return { id: notificationDoc.id };
  },
);
