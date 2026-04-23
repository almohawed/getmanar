import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

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

type AttendanceBuckets = {
  present: number;
  absent: number;
  late: number;
  excused: number;
};

async function computeSchoolIntelligenceInternal(
  schoolId: string,
  termId: string,
) {
  const studentsSnap = await db
    .collection("Schools")
    .doc(schoolId)
    .collection("Students")
    .get();
  const studentIds = studentsSnap.docs.map((d) => d.id);

  const thirtyDaysAgo = new Date(
    Date.now() - 30 * 24 * 60 * 60 * 1000,
  );

  const attendanceSnap = await db
    .collection("Schools")
    .doc(schoolId)
    .collection("StudentAttendance")
    .where(
      "date",
      ">=",
      admin.firestore.Timestamp.fromDate(thirtyDaysAgo),
    )
    .get();

  const attendByStudent: Record<string, AttendanceBuckets> = {};
  for (const d of attendanceSnap.docs) {
    const m = d.data() as {
      studentId?: string;
      status?: string;
    };
    const sid = (m.studentId as string) || "";
    if (!sid) continue;
    const status = (m.status as string) || "present";
    if (!attendByStudent[sid]) {
      attendByStudent[sid] = {
        present: 0,
        absent: 0,
        late: 0,
        excused: 0,
      };
    }
    if (status === "present") {
      attendByStudent[sid].present += 1;
    } else if (status === "absent") {
      attendByStudent[sid].absent += 1;
    } else if (status === "late") {
      attendByStudent[sid].late += 1;
    } else if (status === "excused") {
      attendByStudent[sid].excused += 1;
    } else {
      attendByStudent[sid].present += 1;
    }
  }

  const tracksSnap = await db
    .collection("Schools")
    .doc(schoolId)
    .collection("ExamGradesTracking")
    .where("termId", "==", termId)
    .get();

  const entriesByStudentSubject: Record<string, number[]> = {};
  const classPerf: Record<string, number[]> = {};

  for (const t of tracksSnap.docs) {
    const track = t.data() as {
      subjectId?: string;
      classId?: string;
    };
    const subjectId = (track.subjectId as string) || "";
    const classId = (track.classId as string) || "";

    const entriesSnap = await t.ref
      .collection("Entries")
      .where("termId", "==", termId)
      .get();

    if (!entriesSnap.empty) {
      const scores: number[] = [];
      for (const e of entriesSnap.docs) {
        const m = e.data() as {
          studentId?: string;
          score?: number | string;
        };
        const sid = ((m.studentId as string) || e.id) as string;
        const key = `${sid}::${subjectId}`;
        const rawScore = m.score;
        const sc =
          typeof rawScore === "number"
            ? rawScore
            : Number(rawScore) || 0;
        if (!entriesByStudentSubject[key]) {
          entriesByStudentSubject[key] = [];
        }
        entriesByStudentSubject[key].push(sc);
        scores.push(sc);
      }

      if (classId && subjectId && scores.length > 0) {
        const avg =
          scores.reduce((a, b) => a + b, 0) / scores.length;
        const classKey = `${classId}::${subjectId}`;
        if (!classPerf[classKey]) {
          classPerf[classKey] = [];
        }
        classPerf[classKey].push(avg);
      }
    }
  }

  const riskClasses: string[] = [];
  const riskSubjects: string[] = [];
  const riskTeachers: string[] = [];

  Object.entries(classPerf).forEach(([k, v]) => {
    if (v.length >= 2) {
      const last = v[v.length - 1];
      const prev = v[v.length - 2];
      if (last + 1e-6 < prev) {
        const parts = k.split("::");
        if (parts.length === 2) {
          riskClasses.push(parts[0]);
          riskSubjects.push(parts[1]);
        }
      }
    }
  });

  const predictions: {
    docId: string;
    studentId: string;
    subjectId: string;
    riskLevel: string;
    riskFactors: string[];
    generatedActions: string[];
  }[] = [];

  const attendanceThreshold = 0.9;
  const lowScoreThreshold = 50.0;

  for (const sid of studentIds) {
    const att = attendByStudent[sid] || {
      present: 0,
      absent: 0,
      late: 0,
      excused: 0,
    };
    const total =
      att.present + att.absent + att.late + att.excused;
    const attendanceRate =
      total === 0
        ? 1.0
        : (att.present + 0.5 * att.late) / total;

    const subjects = Object.keys(entriesByStudentSubject)
      .filter((k) => k.startsWith(`${sid}::`))
      .map((k) => k.split("::")[1]);

    const uniqueSubjects = Array.from(new Set(subjects));
    if (uniqueSubjects.length === 0) continue;

    for (const subj of uniqueSubjects) {
      const key = `${sid}::${subj}`;
      const scores = entriesByStudentSubject[key] || [];
      const avg =
        scores.length === 0
          ? 100.0
          : scores.reduce((a, b) => a + b, 0) /
            scores.length;

      let risk = "GREEN";
      const factors: string[] = [];

      if (attendanceRate < attendanceThreshold && avg < 70.0) {
        risk = "RED";
        factors.push("attendance_issue");
        factors.push("low_scores");
      } else if (avg < lowScoreThreshold) {
        risk = "YELLOW";
        factors.push("low_scores");
      } else if (attendanceRate < attendanceThreshold) {
        risk = "YELLOW";
        factors.push("attendance_issue");
      }

      if (risk !== "GREEN") {
        predictions.push({
          docId: `${sid}_${subj}`,
          studentId: sid,
          subjectId: subj,
          riskLevel: risk,
          riskFactors: factors,
          generatedActions:
            risk === "RED"
              ? [
                  "create_remedial_plan",
                  "notify_agent",
                  "notify_teacher",
                ]
              : ["monitor"],
        });
      }
    }
  }

  let health = 100.0;
  const attRates = studentIds.map((s) => {
    const a = attendByStudent[s] || {
      present: 0,
      absent: 0,
      late: 0,
      excused: 0,
    };
    const total =
      a.present + a.absent + a.late + a.excused;
    return total === 0
      ? 1.0
      : (a.present + 0.5 * a.late) / total;
  });

  if (attRates.length > 0) {
    const avgAtt =
      attRates.reduce((a, b) => a + b, 0) / attRates.length;
    health = health * 0.6 * avgAtt;
  }

  if (Object.keys(classPerf).length > 0) {
    const latestAvgs = Object.values(classPerf).map((v) =>
      v.length === 0 ? 100.0 : v[v.length - 1],
    );
    const avgScore =
      latestAvgs.reduce((a, b) => a + b, 0) / latestAvgs.length;
    health = health * 0.4 + avgScore * 0.6;
  }

  const snapshotData = {
    termId,
    schoolHealthScore: Math.max(0, Math.min(100, health)),
    riskClasses: Array.from(new Set(riskClasses)),
    riskSubjects: Array.from(new Set(riskSubjects)),
    riskTeachers,
    generatedAt: admin.firestore.Timestamp.now(),
  };

  await db
    .collection("Schools")
    .doc(schoolId)
    .collection("SchoolIntelligence")
    .add(snapshotData);

  for (const p of predictions) {
    const predRef = db
      .collection("Schools")
      .doc(schoolId)
      .collection("RiskPredictions")
      .doc(p.docId);
    await predRef.set({
      studentId: p.studentId,
      subjectId: p.subjectId,
      riskLevel: p.riskLevel,
      riskFactors: p.riskFactors,
      generatedActions: p.generatedActions,
      generatedAt: admin.firestore.Timestamp.now(),
    });

    if (p.riskLevel === "RED") {
      const causeType = p.riskFactors.includes("attendance_issue")
        ? "attendance_issue"
        : "academic_weakness";
      await db
        .collection("Schools")
        .doc(schoolId)
        .collection("RemedialPlans")
        .add({
          studentIds: [p.studentId],
          causeType,
          strategy: "targeted_support_sessions",
          teacherId: "",
          baselineMetrics: { avgScore: 0, attendanceRate: 0 },
          targetMetrics: { avgScore: 70, attendanceRate: 0.9 },
          status: "active",
          improvementScore: 0.0,
        });
    }
  }

  return {
    predictionsCount: predictions.length,
    schoolHealthScore: snapshotData.schoolHealthScore,
  };
}

export const computeSchoolIntelligenceNow = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const termId = (data.termId as string) || "current";

    if (!schoolId || !termId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات التحليل غير مكتملة",
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
    ];
    if (!allowedRoles.includes(userInfo.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "صلاحيات غير كافية لتشغيل التحليل",
      );
    }

    return computeSchoolIntelligenceInternal(schoolId, termId);
  },
);

export const recomputeSchoolIntelligenceDaily = functions.pubsub
  .schedule("0 3 * * *")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    const termId = "current";
    const now = new Date();
    const schoolsSnap = await db.collection("Schools").get();
    for (const doc of schoolsSnap.docs) {
      const schoolId = doc.id;
      const data = doc.data() as {
        isLifetimeAccess?: boolean;
        subscriptionEndsAt?: string;
      };

      let isActive = !!data.isLifetimeAccess;

      if (!isActive && data.subscriptionEndsAt) {
        const endsAt = new Date(data.subscriptionEndsAt);
        if (!Number.isNaN(endsAt.getTime()) && endsAt.getTime() > now.getTime()) {
          isActive = true;
        }
      }

      if (!isActive) {
        const subSnap = await doc.ref
          .collection("Subscription")
          .doc("current")
          .get();
        if (subSnap.exists) {
          const s = subSnap.data() as {
            status?: string;
            isLifetime?: boolean;
            expiresAt?: admin.firestore.Timestamp;
          } | undefined;
          if (s) {
            if (s.isLifetime) {
              isActive = true;
            } else if (s.status === "active" && s.expiresAt) {
              const endsAt = s.expiresAt.toDate();
              if (endsAt.getTime() > now.getTime()) {
                isActive = true;
              }
            }
          }
        }
      }

      if (!isActive) {
        continue;
      }

      try {
        await computeSchoolIntelligenceInternal(schoolId, termId);
      } catch (e) {
        console.error(
          "Failed to compute intelligence for school",
          schoolId,
          e,
        );
      }
    }
    return null;
  });
