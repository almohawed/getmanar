import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";

const db = admin.firestore();

type AndroidPublisher = ReturnType<typeof google.androidpublisher>;

function getAndroidPublisherClient(): AndroidPublisher {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  google.options({ auth });
  return google.androidpublisher("v3");
}

async function getUserSchool(uid: string) {
  const snap = await db.collection("GlobalUsers").doc(uid).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return {
    schoolId: (data.schoolId as string) || "",
    role: (data.role as string) || "",
  };
}

function isAllowedRole(role: string): boolean {
  return [
    "manager",
    "admin",
    "principal",
    "deputy",
    "deputy_students",
    "deputy_academic",
  ].includes(role);
}

export const verifyGooglePlaySubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const userId = (data.userId as string) || uid;
    const productId = (data.productId as string) || "";
    const basePlanId = (data.basePlanId as string) || "";
    const purchaseToken = (data.purchaseToken as string) || "";

    if (!schoolId || !productId || !basePlanId || !purchaseToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الاشتراك غير مكتملة",
      );
    }

    const userInfo = await getUserSchool(uid);
    if (!userInfo || userInfo.schoolId !== schoolId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "صلاحيات غير كافية لهذه المدرسة",
      );
    }
    if (!isAllowedRole(userInfo.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "صلاحيات غير كافية لتفعيل الاشتراك",
      );
    }

    const packageName =
      process.env.GP_PACKAGE_NAME || "com.getmanar.schoolapp";

    const publisher = getAndroidPublisherClient();

    let purchase;
    try {
      const res =
        await publisher.purchases.subscriptionsv2.get({
          packageName,
          token: purchaseToken,
        });
      purchase = res.data;
    } catch (error) {
      console.error("Google Play API error", error);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "تعذر التحقق من الاشتراك من Google Play",
      );
    }

    const lineItem =
      purchase?.lineItems && purchase.lineItems.length > 0
        ? purchase.lineItems[0]
        : undefined;

    const product =
      lineItem?.productId || purchase?.subscriptionPurchase?.productId;

    if (!product || product !== productId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "المنتج لا يطابق باقة الاشتراك",
      );
    }

    const basePlan =
      lineItem?.offerDetails?.basePlanId ||
      purchase?.subscriptionPurchase?.lineItems?.[0]?.offerDetails
        ?.basePlanId;

    if (!basePlan || basePlan !== basePlanId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "خطة الاشتراك لا تطابق نوع الفوترة المختار",
      );
    }

    const nowMs = Date.now();
    const expireTimeMs =
      typeof purchase?.subscriptionPurchase?.expiryTime?.seconds ===
      "number"
        ? purchase.subscriptionPurchase.expiryTime.seconds * 1000
        : purchase?.subscriptionPurchase?.expiryTimeMillis
        ? parseInt(purchase.subscriptionPurchase.expiryTimeMillis, 10)
        : nowMs;

    if (expireTimeMs <= nowMs) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "الاشتراك منتهي الصلاحية",
      );
    }

    const planId =
      productId === "sub_smart"
        ? "smart"
        : productId === "sub_elite"
        ? "elite"
        : "starter";

    const amountMicros =
      lineItem?.pricingDetails?.price?.amountMicros ??
      purchase?.subscriptionPurchase?.lineItems?.[0]?.pricingDetails?.price
        ?.amountMicros;
    const currencyCode =
      lineItem?.pricingDetails?.price?.currencyCode ??
      purchase?.subscriptionPurchase?.lineItems?.[0]?.pricingDetails?.price
        ?.currencyCode ??
      "SAR";

    const amount =
      typeof amountMicros === "number"
        ? amountMicros / 1_000_000
        : 0;

    const schoolRef = db.collection("Schools").doc(schoolId);
    const subscriptionRef = schoolRef
      .collection("Subscription")
      .doc("current");
    const txRef = schoolRef
      .collection("PaymentTransactions")
      .doc();

    const expiresAt = new Date(expireTimeMs);

    await db.runTransaction(async (t) => {
      t.set(txRef, {
        id: txRef.id,
        schoolId,
        planId,
        amount,
        currency: currencyCode,
        status: "verified",
        platform: "googlePlay",
        productId,
        basePlanId,
        purchaseToken,
        expiresAt: expiresAt.toISOString(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        userId,
      });

      t.set(
        subscriptionRef,
        {
          planId,
          billingCycle: basePlanId,
          status: "active",
          platform: "googlePlay",
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          purchase: {
            productId,
            basePlanId,
            purchaseToken,
            orderId:
              purchase?.subscriptionPurchase?.latestOrderId ?? null,
          },
        },
        { merge: true },
      );
    });

    try {
      const purchaseTokenToAck =
        purchase?.subscriptionPurchase?.latestOrderId
          ? purchase.subscriptionPurchase.latestOrderId
          : purchaseToken;

      await publisher.purchases.subscriptionsv2.acknowledge({
        packageName,
        token: purchaseTokenToAck,
        requestBody: {},
      });
    } catch (error) {
      console.error("Error acknowledging purchase", error);
    }

    return {
      status: "verified",
      planId,
      basePlanId,
      expiresAt: expiresAt.toISOString(),
    };
  },
);

export const dailySubscriptionValidation = functions.pubsub
  .schedule("0 3 * * *")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    const now = new Date();

    const schoolsSnap = await db.collection("Schools").get();
    const batch = db.batch();

    for (const schoolDoc of schoolsSnap.docs) {
      const schoolId = schoolDoc.id;
      const subRef = schoolDoc.ref
        .collection("Subscription")
        .doc("current");
      const subSnap = await subRef.get();
      if (!subSnap.exists) continue;
      const data = subSnap.data() || {};
      const expiresAt = data.expiresAt as admin.firestore.Timestamp | undefined;
      if (!expiresAt) continue;
      if (expiresAt.toDate() <= now) {
        batch.update(subRef, {
          status: "expired",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return null;
  });

