import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const createPaymentRequest = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول أولاً",
      );
    }

    const uid = context.auth.uid;
    const schoolId = (data.schoolId as string) || "";
    const schoolName = (data.schoolName as string) || "";
    const contactName = (data.contactName as string) || "";
    const contactPhone = (data.contactPhone as string) || "";
    const notes = (data.notes as string | undefined) || undefined;
    const desiredPlanId =
      (data.desiredPlanId as string | undefined) || undefined;
    const desiredBillingCycle =
      (data.desiredBillingCycle as string | undefined) || undefined;

    if (!schoolId || !schoolName || !contactName || !contactPhone) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "يرجى تعبئة جميع الحقول المطلوبة",
      );
    }

    const schoolRef = db.collection("Schools").doc(schoolId);
    const schoolSnap = await schoolRef.get();
    if (!schoolSnap.exists) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "لم يتم العثور على المدرسة",
      );
    }

    const requestRef = schoolRef.collection("PaymentRequests").doc();

    await requestRef.set({
      id: requestRef.id,
      schoolId,
      schoolName,
      contactName,
      contactPhone,
      notes,
      desiredPlanId,
      desiredBillingCycle,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    });

    return {
      id: requestRef.id,
      status: "pending",
    };
  },
);

