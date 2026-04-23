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

async function resolvePlanAmount(
  planId: string,
  billingCycle: string,
): Promise<number> {
  const doc = await db
    .collection("SystemSettings")
    .doc("SubscriptionPrices")
    .get();
  const defaults: Record<string, { monthly: number; yearly: number }> = {
    starter: { monthly: 49, yearly: 490 },
    smart: { monthly: 99, yearly: 990 },
    elite: { monthly: 199, yearly: 1990 },
  };
  const data = (doc.exists ? doc.data() : null) || {};
  const entry =
    (data[planId] as { monthly?: number; yearly?: number } | undefined) ||
    defaults[planId] ||
    defaults["starter"];
  const monthly = entry.monthly ?? defaults[planId]?.monthly ?? 49;
  const yearly = entry.yearly ?? defaults[planId]?.yearly ?? 490;
  return billingCycle === "yearly" ? yearly : monthly;
}

function addMonths(base: Date, months: number): Date {
  const d = new Date(base.getTime());
  const targetMonth = d.getMonth() + months;
  const expectedMonth = ((targetMonth % 12) + 12) % 12;
  d.setMonth(targetMonth);
  if (d.getMonth() !== expectedMonth) {
    d.setDate(0);
  }
  return d;
}

function addYears(base: Date, years: number): Date {
  const d = new Date(base.getTime());
  d.setFullYear(d.getFullYear() + years);
  return d;
}

export const createSubscriptionCheckout = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const planId = (data.planId as string) || "";
    const billingCycle = (data.billingCycle as string) || "";

    if (!schoolId || !planId || !billingCycle) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الاشتراك غير مكتملة",
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
        "صلاحيات غير كافية لإنشاء اشتراك",
      );
    }

    const amount = await resolvePlanAmount(planId, billingCycle);

    const txRef = db.collection("PaymentTransactions").doc();
    const transactionId = txRef.id;
    const checkoutSessionId = `chk_${transactionId}`;

    await txRef.set({
      id: transactionId,
      schoolId,
      planId,
      billingCycle,
      amount,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
      checkoutSessionId,
    });

    return {
      transactionId,
      checkoutSessionId,
      status: "pending",
    };
  },
);

export const confirmSubscriptionPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const transactionId = (data.transactionId as string) || "";

    if (!schoolId || !transactionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات التأكيد غير مكتملة",
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
        "صلاحيات غير كافية لتأكيد الدفع",
      );
    }

    const txRef = db.collection("PaymentTransactions").doc(transactionId);
    const schoolRef = db.collection("Schools").doc(schoolId);
    const subscriptionRef = schoolRef.collection("Subscription").doc("current");

    let planId = "";
    let billingCycle = "";
    let expiresAtIso = "";

    await db.runTransaction(async (t) => {
      const txSnap = await t.get(txRef);
      if (!txSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "لم يتم العثور على عملية الدفع",
        );
      }
      const tx = txSnap.data() || {};
      if ((tx.schoolId as string) !== schoolId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "عدم تطابق بيانات المدرسة",
        );
      }
      const currentStatus = (tx.status as string) || "pending";
      if (currentStatus === "failed") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "عملية الدفع مرفوضة",
        );
      }

      planId = (tx.planId as string) || "";
      billingCycle = (tx.billingCycle as string) || "";

      const now = new Date();
      let endDate: Date;
      if (billingCycle === "yearly") {
        endDate = addYears(now, 1);
      } else {
        endDate = addMonths(now, 1);
      }
      expiresAtIso = endDate.toISOString();

      t.update(txRef, {
        status: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        confirmedBy: uid,
      });

      t.update(schoolRef, {
        subscriptionPlan: planId,
        subscriptionEndsAt: expiresAtIso,
        isLifetimeAccess: false,
      });

      t.set(
        subscriptionRef,
        {
          planId,
          billingCycle,
          status: "active",
          expiresAt: admin.firestore.Timestamp.fromDate(endDate),
          isLifetime: false,
          lastTransactionId: transactionId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return {
      status: "activated",
      planId,
      billingCycle,
      subscriptionEndsAt: expiresAtIso,
    };
  },
);

