const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

// A. Bathroom Red Repeat
// Trigger: On BathroomPasses write
// Path: Schools/{schoolId}/BathroomPasses/{passId}
exports.onBathroomPassWritten = functions.firestore
  .document("Schools/{schoolId}/BathroomPasses/{passId}")
  .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after) return; // Deleted

    const schoolId = context.params.schoolId;
    const studentId = after.studentId;
    const status = after.status;

    // Filter: status must be locked_red
    if (status !== "locked_red") return;

    // Check history (last 14 days)
    const now = new Date();
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
    
    // Determine which field to use for time. Assuming 'startTime' or 'createdAt'
    // We should support Timestamp or Millis or ISO string if legacy data exists, 
    // but for query we usually need consistent type. 
    // New writes should be Timestamp.
    // For query, we will try to query by 'startTime' (Timestamp).
    
    const snapshot = await db
      .collection(`Schools/${schoolId}/BathroomPasses`)
      .where("studentId", "==", studentId)
      .where("status", "==", "locked_red")
      .where("startTime", ">=", admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
      .get();

    const count = snapshot.size;

    // Thresholds
    if (count >= 5) {
        // Counselor Task
        await createAdminTask(schoolId, {
            title: `إحالة سلوكية - تكرار حمام (أحمر) - طالب ${studentId}`,
            description: `تكرر تجاوز وقت الحمام (الحالة الحمراء) ${count} مرات خلال 14 يوم.`,
            priority: "high",
            assignedTo: "counselor",
            type: "behavior_referral",
            relatedStudentId: studentId,
        });
    } else if (count >= 3) {
        // Deputy Task
        await createAdminTask(schoolId, {
            title: `تكرار حالة حمراء - طالب ${studentId}`,
            description: `تكرر تجاوز وقت الحمام (الحالة الحمراء) ${count} مرات خلال 14 يوم.`,
            priority: "medium",
            assignedTo: "deputy_students",
            type: "behavior_warning",
            relatedStudentId: studentId,
        });
    }
  });

// B. Unexcused Late Repeat
// Trigger: On StudentAttendance write
exports.onAttendanceWritten = functions.firestore
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
    // StudentAttendance uses ISO String for date
    const fourteenDaysAgoIso = fourteenDaysAgo.toISOString();

    // Query Top-Level Collection
    const snapshot = await db
      .collection("StudentAttendance")
      .where("schoolId", "==", schoolId)
      .where("studentId", "==", studentId)
      .where("status", "==", "late")
      .where("date", ">=", fourteenDaysAgoIso)
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
exports.checkBehaviorEscalation = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const sevenDaysAgoTimestamp = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

    const snapshot = await db
      .collection("behavior_records")
      .where("status", "==", "active")
      .where("timestamp", "<", sevenDaysAgoTimestamp)
      .get();

    const batch = db.batch();
    
    for (const doc of snapshot.docs) {
      const record = doc.data();
      const schoolId = record.schoolId;
      if (!schoolId) continue;

      const taskQuery = await db
        .collection(`Schools/${schoolId}/AdminTasks`)
        .where("relatedViolationId", "==", doc.id)
        .where("type", "==", "escalation")
        .limit(1)
        .get();

      if (taskQuery.empty) {
        const newTaskRef = db.collection(`Schools/${schoolId}/AdminTasks`).doc();
        batch.set(newTaskRef, {
            title: `تصعيد مخالفة: ${record.description || 'مخالفة سلوكية'}`,
            description: `مخالفة مفتوحة منذ أكثر من 7 أيام بدون إغلاق.`,
            priority: "high",
            assignedTo: "manager",
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

exports.computeWeeklyFirstAction = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - 6);

    const schoolsSnap = await db.collection("Schools").get();
    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;

      const incidentsSnap = await db
        .collectionGroup("BehaviorIncidents")
        .where("schoolId", "==", schoolId)
        .where(
          "timestamp",
          ">=",
          admin.firestore.Timestamp.fromDate(weekStart)
        )
        .get();

      if (incidentsSnap.empty) {
        continue;
      }

      const sources = {};

      const upsert = (key, type, label, severity, speed) => {
        if (!sources[key]) {
          sources[key] = {
            type,
            label,
            count: 0,
            severitySum: 0,
            speedSum: 0,
          };
        }
        sources[key].count += 1;
        sources[key].severitySum += severity;
        sources[key].speedSum += speed;
      };

      incidentsSnap.forEach((doc) => {
        const d = doc.data();
        const severity = d.severity || 1;
        const trend = d.trendFactor || 1;

        if (d.studentId) {
          upsert(
            `student_${d.studentId}`,
            "student",
            d.studentName || d.studentId,
            severity,
            trend
          );
        }

        if (d.classId) {
          upsert(
            `class_${d.classId}`,
            "class",
            d.className || d.classId,
            severity,
            trend
          );
        }
      });

      let best = null;
      Object.keys(sources).forEach((key) => {
        const s = sources[key];
        const impacted = s.count;
        const sev = s.severitySum / s.count;
        const speed = s.speedSum / s.count;
        const impactScore = impacted * sev * speed;
        if (!best || impactScore > best.impactScore) {
          best = {
            key,
            impactScore,
            type: s.type,
            label: s.label,
            impacted,
            severity: sev,
            speed,
          };
        }
      });

      if (!best) continue;

      const pattern =
        best.type === "friends"
          ? "peer_group"
          : best.type === "class"
          ? "class_pattern"
          : "student_pattern";

      const effKey = `${schoolId}_${pattern}`;
      const effSnap = await db
        .collection("InterventionEffectiveness")
        .doc(effKey)
        .get();

      let actionId = "group_counseling";
      let actionTitle = "جلسة دعم سلوكي جماعية";

      if (effSnap.exists) {
        const data = effSnap.data() || {};
        const ranked = data.rankedActions || [];
        if (ranked.length > 0) {
          actionId = ranked[0].actionId || actionId;
          actionTitle = ranked[0].title || actionTitle;
        }
      }

      const priorityReason =
        best.type === "friends"
          ? "مجموعة أصدقاء بحاجة دعم إضافي بسبب نمط سلوكي متكرر"
          : best.type === "class"
          ? "فصل دراسي بحاجة دعم إضافي لوجود نمط سلوكي متصاعد"
          : "طالب أو أكثر بحاجة دعم إضافي بسبب تكرار الملاحظات";

      const todayStep =
        best.type === "friends"
          ? "التواصل مع المرشد الطلابي لتحديد الطلاب المتأثرين وتثبيت موعد جلسة دعم جماعية"
          : best.type === "class"
          ? "مراجعة سجل السلوك للفصل والتنسيق مع معلمي الفصل حول أبرز المواقف"
          : "مراجعة سجل الطالب والتواصل مع المرشد لمراجعة حالته السلوكية";

      const tomorrowStep =
        best.type === "friends"
          ? "تنفيذ جلسة نقاش موجهة تركز على بناء بيئة أصدقاء داعمة ومحترمة"
          : best.type === "class"
          ? "تنفيذ نشاط صفي يعزز قواعد السلوك والتعاون داخل الفصل"
          : "الاتصال بولي الأمر لإشراكه في خطة دعم هادئة وبنّاءة";

      const endOfWeekStep =
        best.type === "friends"
          ? "متابعة سجل السلوك للمجموعة وتوثيق التغيّر في عدد الملاحظات"
          : best.type === "class"
          ? "متابعة مؤشرات السلوك في الفصل وتوثيق التغيّر في عدد الحوادث"
          : "متابعة سلوك الطالب داخل الفصل ومع معلميه وتوثيق التحسن أو الاستقرار";

      const successMetric =
        best.type === "friends"
          ? "انخفاض عدد الملاحظات المرتبطة بالمجموعة بنسبة 30٪ خلال أسبوع"
          : best.type === "class"
          ? "انخفاض عدد الحوادث السلوكية في الفصل بنسبة 30٪ خلال أسبوع"
          : "انخفاض ملاحظات السلوك السلبية للطالب بنسبة 30٪ خلال أسبوع";

      const weekKey = `${weekStart.getFullYear()}-W${weekStart.getMonth() + 1}-${weekStart.getDate()}`;

      await db
        .collection("Schools")
        .doc(schoolId)
        .collection("BehaviorFirstActions")
        .doc(weekKey)
        .set({
          schoolId,
          weekKey,
          sourceType: best.type,
          sourceName: best.label,
          priorityReason,
          timeWindowHours: 48,
          actionId,
          actionTitle,
          todayStep,
          tomorrowStep,
          endOfWeekStep,
          successMetric,
          impactScore: best.impactScore,
          impactedCount: best.impacted,
          severity: best.severity,
          speed: best.speed,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
  });

exports.updateInterventionEffectiveness = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const schoolsSnap = await db.collection("Schools").get();
    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;

      const actionsSnap = await db
        .collection("Schools")
        .doc(schoolId)
        .collection("DeputyActions")
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .where("channel", "==", "behavior_index")
        .get();

      for (const actionDoc of actionsSnap.docs) {
        const action = actionDoc.data();
        const pattern = action.sourceType === "friends"
          ? "peer_group"
          : action.sourceType === "class"
          ? "class_pattern"
          : "student_pattern";

        const key = `${schoolId}_${pattern}`;
        const effRef = db.collection("InterventionEffectiveness").doc(key);
        const effSnap = await effRef.get();
        let ranked = [];
        if (effSnap.exists) {
          const data = effSnap.data() || {};
          ranked = data.rankedActions || [];
        }

        const existingIndex = ranked.findIndex(
          (r) => r.actionId === action.actionId
        );

        if (existingIndex >= 0) {
          ranked[existingIndex].successCount =
            (ranked[existingIndex].successCount || 0) + 1;
        } else {
          ranked.push({
            actionId: action.actionId,
            title: action.actionTitle,
            successCount: 1,
          });
        }

        ranked.sort((a, b) => (b.successCount || 0) - (a.successCount || 0));

        await effRef.set(
          {
            schoolId,
            pattern,
            rankedActions: ranked,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }
  });

exports.notifyBehaviorPriorityChange = functions.pubsub
  .schedule("0 6 * * 0")
  .timeZone("Asia/Riyadh")
  .onRun(async (context) => {
    const schoolsSnap = await db.collection("Schools").get();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;

      const firstActionsSnap = await db
        .collection("Schools")
        .doc(schoolId)
        .collection("BehaviorFirstActions")
        .orderBy("weekKey", "desc")
        .limit(2)
        .get();

      if (firstActionsSnap.empty) {
        continue;
      }

      const currentDoc = firstActionsSnap.docs[0];
      const current = currentDoc.data();
      const currentWeekKey = current.weekKey || currentDoc.id;
      const currentImpact = current.impactScore || 0;
      const currentSourceType = current.sourceType || "";
      const currentSourceName = current.sourceName || "";
      const currentActionId = current.actionId || "";
      const currentPattern =
        currentSourceType === "friends"
          ? "peer_group"
          : currentSourceType === "class"
          ? "class_pattern"
          : "student_pattern";

      let priorityChanged = false;
      let impactSpike = false;
      let newPattern = false;
      let interventionFailed = false;

      if (firstActionsSnap.docs.length > 1) {
        const prevDoc = firstActionsSnap.docs[1];
        const prev = prevDoc.data();
        const prevImpact = prev.impactScore || 0;
        const prevSourceType = prev.sourceType || "";
        const prevSourceName = prev.sourceName || "";
        const prevActionId = prev.actionId || "";
        const prevPattern =
          prevSourceType === "friends"
            ? "peer_group"
            : prevSourceType === "class"
            ? "class_pattern"
            : "student_pattern";

        if (
          prevSourceType !== currentSourceType ||
          prevSourceName !== currentSourceName ||
          prevActionId !== currentActionId
        ) {
          priorityChanged = true;
        }

        if (prevImpact > 0 && currentImpact >= prevImpact * 1.3) {
          impactSpike = true;
        }

        if (
          currentPattern !== prevPattern &&
          (currentPattern === "peer_group" || currentPattern === "class_pattern")
        ) {
          newPattern = true;
        }

        const actionsSnap = await db
          .collection("Schools")
          .doc(schoolId)
          .collection("DeputyActions")
          .where("firstActionId", "==", prevDoc.id)
          .where("channel", "==", "behavior_index")
          .get();

        if (!actionsSnap.empty && prevImpact > 0) {
          if (currentImpact >= prevImpact * 0.9) {
            interventionFailed = true;
          }
        }
      } else {
        priorityChanged = true;
      }

      const hasChange =
        priorityChanged || impactSpike || newPattern || interventionFailed;

      if (!hasChange) {
        continue;
      }

      const alertRef = db
        .collection("Schools")
        .doc(schoolId)
        .collection("BehaviorAlertState")
        .doc("studentBehaviorIndex");

      const alertSnap = await alertRef.get();
      const stateSignature = `${currentWeekKey}|${currentSourceType}|${currentSourceName}|${currentActionId}|${(currentImpact || 0).toFixed(1)}`;

      let lastSignature = null;
      if (alertSnap.exists) {
        const data = alertSnap.data() || {};
        lastSignature = data.lastAlertSignature || null;
      }

      if (lastSignature && lastSignature === stateSignature) {
        continue;
      }

      const notificationsRef = db.collection(
        `Schools/${schoolId}/Notifications`
      );
      const notificationDoc = notificationsRef.doc();

      await notificationDoc.set({
        id: notificationDoc.id,
        schoolId,
        userId: null,
        title: "تحديث أولوية المتابعة",
        body:
          "تغيرت أولوية المتابعة هذا الأسبوع بناءً على تحليل البيانات السلوكية. يُنصح بمراجعة مؤشر السلوك الطلابي.",
        timestamp: new Date().toISOString(),
        isRead: false,
        route: "/behavior-analysis",
        data: {
          sourceType: currentSourceType,
          sourceName: currentSourceName,
          weekKey: currentWeekKey,
        },
        targetRole: "deputy",
        targetClassId: null,
        channel: "behavior_index",
      });

      await alertRef.set(
        {
          lastAlertSignature: stateSignature,
          lastWeekKey: currentWeekKey,
          lastSourceType: currentSourceType,
          lastSourceName: currentSourceName,
          lastActionId: currentActionId,
          lastImpactScore: currentImpact,
          lastPattern: currentPattern,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  });

// D. Schedule Runs Expiry (Collaborative Preferences)
// Scheduled: Every 5 minutes
exports.checkScheduleRunsExpiry = functions.pubsub
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
      const schoolId = data.schoolId;
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

async function createAdminTask(schoolId, taskData) {
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
