import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

function toRiyadh(date: Date): Date {
  return new Date(
    date.toLocaleString("en-US", { timeZone: "Asia/Riyadh" }),
  );
}

function getWeekKeyForDate(date: Date): string {
  const d = toRiyadh(date);
  const target = new Date(d.valueOf());
  const day = target.getDay();
  const diff = (day + 7 - 0) % 7;
  target.setDate(target.getDate() - diff);
  const year = target.getFullYear();
  const startOfYear = new Date(year, 0, 1);
  const daysSinceYearStart =
    (target.getTime() - startOfYear.getTime()) / 86400000;
  const weekNumber = Math.floor((daysSinceYearStart + startOfYear.getDay()) / 7) + 1;
  return `${year}-W${weekNumber.toString().padStart(2, "0")}`;
}

function getPreviousWeekKey(fromStart: Date): string {
  const prevStart = new Date(fromStart.getTime() - 7 * 24 * 60 * 60 * 1000);
  return getWeekKeyForDate(prevStart);
}

function classifyLevel(score: number): string {
  if (score >= 85) return "ممتاز";
  if (score >= 70) return "جيد جدًا";
  return "يحتاج تعزيز";
}

function classifyRisk(score: number): "LOW" | "MED" | "HIGH" {
  if (score >= 80) return "LOW";
  if (score >= 60) return "MED";
  return "HIGH";
}

function deriveSeverity(
  type: string,
  points: number,
): "low" | "medium" | "high" {
  if (type === "positive" || type === "distinguished") return "low";
  if (points <= -5) return "high";
  if (points < 0) return "medium";
  return "low";
}

function deriveContext(data: any): string {
  if (data.type === "bathroom" || data.type === "escape") return "outside";
  if (data.type === "permission") return "attendance";
  if (data.classId) return "in_class";
  return "other";
}

function buildDrivers(incidents: admin.firestore.QueryDocumentSnapshot[]): string[] {
  const drivers: string[] = [];
  let positive = 0;
  let negative = 0;
  let bathroom = 0;
  let escape = 0;
  let morningNegative = 0;
  let lateNegative = 0;

  incidents.forEach((doc) => {
    const d = doc.data();
    const type = d.type as string;
    const ts = d.timestamp as admin.firestore.Timestamp | undefined;
    const date = ts ? ts.toDate() : new Date();
    if (type === "positive" || type === "distinguished") positive += 1;
    if (type === "negative") {
      negative += 1;
      const hour = date.getHours();
      if (hour < 10) {
        morningNegative += 1;
      } else if (hour >= 12) {
        lateNegative += 1;
      }
    }
    if (type === "bathroom") bathroom += 1;
    if (type === "escape") escape += 1;
  });

  if (positive >= negative && positive > 0) {
    drivers.push("تعزيزات إيجابية متكررة خلال الأسبوع");
  }
  if (negative > positive && negative > 0) {
    drivers.push("تحديات سلوكية تحتاج إلى تعزيز إيجابي مركز");
  }
  if (morningNegative > lateNegative && morningNegative > 2) {
    drivers.push("تحديات ملحوظة في بداية اليوم الدراسي");
  }
  if (lateNegative > morningNegative && lateNegative > 2) {
    drivers.push("تحديات ملحوظة في الحصص الأخيرة من اليوم");
  }
  if (bathroom >= 3) {
    drivers.push("استئذان متكرر لدورات المياه يحتاج إلى إدارة مختلفة");
  }
  if (escape >= 1) {
    drivers.push("سجل سابق لمحاولات هروب من الحصة أو المدرسة");
  }

  return drivers.slice(0, 3);
}

function computeScore(
  incidents: admin.firestore.QueryDocumentSnapshot[],
): { score: number; positiveCount: number; negativeCount: number } {
  let base = 80;
  let positive = 0;
  let negative = 0;

  incidents.forEach((doc) => {
    const d = doc.data();
    const type = d.type as string;
    const points = (d.points as number | undefined) ?? 0;
    if (type === "positive" || type === "distinguished") {
      base += Math.max(points, 1);
      positive += 1;
    } else if (
      type === "negative" ||
      type === "escape" ||
      type === "bathroom"
    ) {
      base += Math.min(points, -1);
      negative += 1;
    }
  });

  const score = Math.max(0, Math.min(100, base));
  return { score, positiveCount: positive, negativeCount: negative };
}

function buildSmartNotice(
  atRiskCount: number,
  risingCount: number,
): string {
  if (atRiskCount === 0 && risingCount === 0) {
    return "ممتاز: لا توجد حالات تستدعي تدخلًا الآن.";
  }
  if (risingCount === 1 && atRiskCount <= 3) {
    return "ملاحظة: طالب واحد ظهرت لديه مؤشرات تصاعد خلال آخر 7 أيام.";
  }
  if (atRiskCount > 0) {
    return `تنبيه هادئ: ${atRiskCount} طلاب يحتاجون متابعة مبكرة هذا الأسبوع.`;
  }
  return "تنبيه هادئ: توجد مؤشرات تحتاج متابعة خلال هذا الأسبوع.";
}

function getNextWeekKey(weekKey: string): string {
  const [yearPart, weekPart] = weekKey.split("-W");
  const year = parseInt(yearPart, 10);
  const week = parseInt(weekPart, 10);
  const jan1 = new Date(year, 0, 1);
  const dayOffset = jan1.getDay();
  const start = new Date(
    jan1.getTime() +
      (week - 1) * 7 * 24 * 60 * 60 * 1000 -
      dayOffset * 24 * 60 * 60 * 1000,
  );
  const nextStart = new Date(start.getTime() + 7 * 24 * 60 * 60 * 1000);
  return getWeekKeyForDate(nextStart);
}

async function computeSchoolWeekProfiles(
  schoolId: string,
  weekKey: string,
  previousWeekKey: string,
  start: Date,
  end: Date,
) {
  const startTs = admin.firestore.Timestamp.fromDate(start);
  const endTs = admin.firestore.Timestamp.fromDate(end);

  const incidentsSnap = await db
    .collection(`Schools/${schoolId}/BehaviorIncidents`)
    .where("timestamp", ">=", startTs)
    .where("timestamp", "<", endTs)
    .get();

  if (incidentsSnap.empty) return;

  const byStudent = new Map<string, admin.firestore.QueryDocumentSnapshot[]>();

  incidentsSnap.docs.forEach((doc) => {
    const d = doc.data();
    const studentId = d.studentId as string | undefined;
    if (!studentId) return;
    const list = byStudent.get(studentId) ?? [];
    list.push(doc);
    byStudent.set(studentId, list);
  });

  const profilesRef = db.collection(
    `Schools/${schoolId}/StudentWeeklyBehaviorProfiles`,
  );
  const suggestionsRef = db.collection(
    `Schools/${schoolId}/StudentEnhancementSuggestions`,
  );

  const prevDocs = await profilesRef
    .where("weekKey", "==", previousWeekKey)
    .get();
  const prevByStudent = new Map<string, admin.firestore.DocumentData>();
  prevDocs.docs.forEach((d) => {
    const data = d.data();
    prevByStudent.set(data.studentId as string, data);
  });

  const batch = db.batch();

  for (const [studentId, docs] of byStudent.entries()) {
    const { score, positiveCount, negativeCount } = computeScore(docs);
    const level = classifyLevel(score);
    const riskTier = classifyRisk(score);
    const drivers = buildDrivers(docs);

    const prevData = prevByStudent.get(studentId);
    let trend = "stable";
    if (prevData && typeof prevData.behaviorScore === "number") {
      const prevScore = prevData.behaviorScore as number;
      if (score >= prevScore + 3) trend = "improving";
      else if (score <= prevScore - 3) trend = "declining";
    }

    const profileId = `${weekKey}_${studentId}`;
    const profileRef = profilesRef.doc(profileId);

    batch.set(profileRef, {
      id: profileId,
      schoolId,
      studentId,
      weekKey,
      behaviorScore: score,
      level,
      trend,
      drivers,
      riskTier,
      positiveCount,
      negativeCount,
      incidentCount: docs.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const friendsImpact = await computeFriendsImpact(
      schoolId,
      studentId,
      weekKey,
    );

    const suggestionId = `${weekKey}_${studentId}`;
    const suggestionRef = suggestionsRef.doc(suggestionId);

    const predictedNextIssue =
      riskTier === "HIGH"
        ? "احتمال تكرار مخالفات سلوكية خلال الأسبوع القادم"
        : riskTier === "MED"
        ? "احتمال استمرار التذبذب السلوكي دون تدخل داعم"
        : "استقرار متوقع مع الحاجة لاستمرار التعزيز الإيجابي";

    const recommendations = buildRecommendations(riskTier, drivers, friendsImpact);

    batch.set(suggestionRef, {
      id: suggestionId,
      schoolId,
      studentId,
      weekKey,
      behaviorScore: score,
      riskTier,
      topDrivers: drivers,
      predictedNextIssue,
      recommendations,
      friendsImpactScore: friendsImpact.score,
      friendsImpactLevel: friendsImpact.level,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

async function computeFriendsImpact(
  schoolId: string,
  studentId: string,
  weekKey: string,
): Promise<{ score: number; level: "LOW" | "MED" | "HIGH" }> {
  const friendsSnap = await db
    .collection(`Schools/${schoolId}/StudentFriends/${studentId}/Friends`)
    .get();

  if (friendsSnap.empty) {
    return { score: 0, level: "LOW" };
  }

  const profilesRef = db.collection(
    `Schools/${schoolId}/StudentWeeklyBehaviorProfiles`,
  );
  let totalRisk = 0;
  let count = 0;

  for (const doc of friendsSnap.docs) {
    const friendId = doc.id;
    const profileId = `${weekKey}_${friendId}`;
    const profileSnap = await profilesRef.doc(profileId).get();
    if (!profileSnap.exists) continue;
    const data = profileSnap.data();
    if (!data) continue;
    const friendScore = (data.behaviorScore as number) ?? 80;
    const friendRisk = 100 - Math.max(0, Math.min(100, friendScore));
    totalRisk += friendRisk;
    count += 1;
  }

  if (count === 0) {
    return { score: 0, level: "LOW" };
  }

  const avgRisk = totalRisk / count;
  let level: "LOW" | "MED" | "HIGH" = "LOW";
  if (avgRisk >= 60) level = "HIGH";
  else if (avgRisk >= 30) level = "MED";

  return { score: avgRisk, level };
}

function buildRecommendations(
  riskTier: "LOW" | "MED" | "HIGH",
  drivers: string[],
  friendsImpact: { score: number; level: "LOW" | "MED" | "HIGH" },
): { actionType: string; text: string }[] {
  const recs: { actionType: string; text: string }[] = [];

  if (riskTier === "HIGH") {
    recs.push({
      actionType: "focused_meeting",
      text: "لقاء قصير مع الطالب لتثبيت قواعد الصف والوصول إلى اتفاق واضح.",
    });
    recs.push({
      actionType: "positive_tracking",
      text: "تسجيل أي سلوك إيجابي بسيط هذا الأسبوع وإشعاره بالتقدير مباشرة.",
    });
  } else if (riskTier === "MED") {
    recs.push({
      actionType: "seat_adjustment",
      text: "إعادة ضبط مكان جلوس الطالب بالقرب من طالب هادئ ومتعاون.",
    });
  } else {
    recs.push({
      actionType: "public_praise",
      text: "منح الطالب ثناء علني بسيط عند ثبات السلوك الإيجابي.",
    });
  }

  if (friendsImpact.level === "HIGH") {
    recs.push({
      actionType: "peer_group_reshaping",
      text: "تشكيل مجموعات عمل تخلط بين أصدقاء إيجابيين والطالب بشكل متوازن.",
    });
  } else if (friendsImpact.level === "MED") {
    recs.push({
      actionType: "positive_peer_pairing",
      text: "إقران الطالب بزميل إيجابي في المهام الثنائية داخل الصف.",
    });
  }

  return recs.slice(0, 3);
}

export const mirrorBehaviorIncident = functions.firestore
  .document("behavior_records/{recordId}")
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    const recordId = context.params.recordId as string;

    const targetSchoolId = (after && after.schoolId) || (before && before.schoolId);
    if (!targetSchoolId) return;

    const targetRef = db.doc(
      `Schools/${targetSchoolId}/BehaviorIncidents/${recordId}`,
    );

    if (!after) {
      await targetRef.delete();
      return;
    }

    const severity = deriveSeverity(after.type, after.points ?? 0);
    const contextLabel = deriveContext(after);
    const ts =
      after.timestamp instanceof admin.firestore.Timestamp
        ? after.timestamp
        : admin.firestore.Timestamp.fromMillis(
            typeof after.timestamp === "number"
              ? after.timestamp
              : Date.now(),
          );

    await targetRef.set({
      id: recordId,
      schoolId: targetSchoolId,
      studentId: after.studentId,
      teacherId: after.teacherId,
      classId: after.classId ?? null,
      type: after.type,
      severity,
      timestamp: ts,
      context: contextLabel,
      points: after.points ?? 0,
    });
  });

export const computeWeeklyBehaviorProfiles = functions.pubsub
  .schedule("0 3 * * SUN")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    const now = new Date();
    const tzNow = toRiyadh(now);
    const end = tzNow;
    const start = new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
    const weekKey = getWeekKeyForDate(start);
    const previousWeekKey = getPreviousWeekKey(start);

    const schoolsSnap = await db.collection("Schools").get();
    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      await computeSchoolWeekProfiles(
        schoolId,
        weekKey,
        previousWeekKey,
        start,
        end,
      );
    }
  });

export const logBehaviorEnhancementAction = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required",
      );
    }

    const uid = context.auth.uid;
    const schoolId = data.schoolId as string;
    const studentId = data.studentId as string;
    const actionType = data.actionType as string;
    const weekKey = data.weekKey as string;
    const personaKey = data.personaKey as string | undefined;

    if (!schoolId || !studentId || !actionType || !weekKey) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields",
      );
    }

    const userSnap = await db.collection("GlobalUsers").doc(uid).get();
    if (!userSnap.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "User not found",
      );
    }
    const user = userSnap.data()!;

    if (user.schoolId !== schoolId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cross-school access is not allowed",
      );
    }

    const allowedRoles = ["teacher", "deputy_students", "counselor"];
    if (!allowedRoles.includes(user.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Role not allowed to log actions",
      );
    }

    const actionsRef = db.collection(
      `Schools/${schoolId}/BehaviorActions`,
    );
    const actionDoc = actionsRef.doc();
    const actionData = {
      id: actionDoc.id,
      studentId,
      schoolId,
      actorRole: user.role,
      actorId: uid,
      actionType,
      weekKey,
      personaKey: personaKey ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      effectComputed: false,
    };

    await actionDoc.set(actionData);
    await updateEffectivenessForAction(actionData);
    return { id: actionDoc.id };
  },
);

async function updateEffectivenessForAction(action: any) {
  const schoolId = action.schoolId as string;
  const studentId = action.studentId as string;
  const actionType = action.actionType as string;
  const weekKey = action.weekKey as string;
  const personaKey =
    (action.personaKey as string | undefined) ?? "generic";

  const profilesRef = db.collection(
    `Schools/${schoolId}/StudentWeeklyBehaviorProfiles`,
  );
  const currentId = `${weekKey}_${studentId}`;

  const currentSnap = await profilesRef.doc(currentId).get();
  if (!currentSnap.exists) return;
  const current = currentSnap.data();
  if (!current) return;

  const nextWeekKey = getNextWeekKey(weekKey);
  const nextId = `${nextWeekKey}_${studentId}`;
  const nextSnap = await profilesRef.doc(nextId).get();
  if (!nextSnap.exists) return;
  const next = nextSnap.data();
  if (!next) return;

  const currentScore = (current.behaviorScore as number) ?? 80;
  const nextScore = (next.behaviorScore as number) ?? currentScore;
  const delta = nextScore - currentScore;

  const key = `${actionType}__${personaKey}`;
  const effRef = db.doc(
    `Schools/${schoolId}/ActionEffectiveness/${key}`,
  );
  const effSnap = await effRef.get();

  let totalCount = 0;
  let successCount = 0;
  let sumImprovement = 0;

  if (effSnap.exists) {
    const data = effSnap.data()!;
    totalCount = (data.totalCount as number) ?? 0;
    successCount = (data.successCount as number) ?? 0;
    sumImprovement = (data.sumImprovement as number) ?? 0;
  }

  totalCount += 1;
  if (delta >= 3) {
    successCount += 1;
    sumImprovement += delta;
  }

  const successRate = totalCount > 0 ? successCount / totalCount : 0;
  const avgImprovement = totalCount > 0 ? sumImprovement / totalCount : 0;

  await effRef.set(
    {
      actionType,
      personaKey,
      totalCount,
      successCount,
      sumImprovement,
      successRate,
      avgImprovement,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const actionsRef = db.collection(
    `Schools/${schoolId}/BehaviorActions`,
  );
  const query = await actionsRef
    .where("studentId", "==", studentId)
    .where("actionType", "==", actionType)
    .where("weekKey", "==", weekKey)
    .where("effectComputed", "==", false)
    .limit(1)
    .get();

  if (!query.empty) {
    await query.docs[0].ref.update({
      effectComputed: true,
      deltaScore: delta,
    });
  }
}

export const recomputePendingActionEffectiveness = functions.pubsub
  .schedule("every 24 hours")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    const schoolsSnap = await db.collection("Schools").get();
    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const actionsRef = db.collection(
        `Schools/${schoolId}/BehaviorActions`,
      );
      const pendingSnap = await actionsRef
        .where("effectComputed", "==", false)
        .limit(50)
        .get();

      for (const actionDoc of pendingSnap.docs) {
        await updateEffectivenessForAction(actionDoc.data());
      }
    }
  });
