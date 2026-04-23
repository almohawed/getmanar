const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

// 1. onMaintenanceCreated: Calculate dueAt & Repeat Detection
exports.onMaintenanceCreated = functions.firestore
  .document("Schools/{schoolId}/MaintenanceReports/{reportId}")
  .onCreate(async (snap, context) => {
    const report = snap.data();
    const schoolId = context.params.schoolId;
    const reportId = context.params.reportId;

    if (!report) return;

    // A. Calculate dueAt based on Priority
    let hoursToAdd = 24 * 7; // Default Low = 7 days
    switch (report.priority) {
      case "critical":
        hoursToAdd = 6;
        break;
      case "high":
        hoursToAdd = 24;
        break;
      case "medium":
        hoursToAdd = 72;
        break;
      case "low":
        hoursToAdd = 24 * 7;
        break;
    }

    // Handle Timestamp or Date
    const createdAt = report.createdAt && report.createdAt.toDate ? report.createdAt.toDate() : new Date();
    const dueAt = new Date(createdAt.getTime() + hoursToAdd * 60 * 60 * 1000);

    // Update dueAt
    // Use snap.ref directly
    await snap.ref.update({
      dueAt: admin.firestore.Timestamp.fromDate(dueAt),
    });

    // B. Repeat Detection (Same location + title within 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const repeatsQuery = await db
      .collection(`Schools/${schoolId}/MaintenanceReports`)
      .where("location", "==", report.location)
      .where("title", "==", report.title)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    if (repeatsQuery.size >= 3) {
      // Create Admin Task for "Root Cause Analysis"
      await db.collection(`Schools/${schoolId}/AdminTasks`).add({
        title: `حل جذري: تكرار عطل ${report.title} في ${report.location}`,
        description: `تم رصد تكرار نفس العطل 3 مرات خلال 30 يوم. يجب التحقيق في الأسباب الجذرية.`,
        priority: "high",
        status: "open",
        assignedTo: "manager",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: "maintenance_repeat",
        relatedReportId: reportId,
      });
    }
  });

// 2. checkMaintenanceOverdue: Hourly Cron Job
exports.checkMaintenanceOverdue = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    // Find all schools (or iterate if needed, but Collection Group is better if structured right)
    // Here assuming we query by collection group if possible, or just iterate known schools.
    // For simplicity, let's assume we do a collection group query for 'MaintenanceReports'
    // where status is pending/inProgress and dueAt < now.
    
    // Note: Collection Group queries require index.
    const overdueQuery = await db
      .collectionGroup("MaintenanceReports")
      .where("status", "in", ["pending", "inProgress"])
      .where("dueAt", "<", now)
      .get();

    const batch = db.batch();
    const escalationThreshold = 48 * 60 * 60 * 1000; // 48 hours

    for (const doc of overdueQuery.docs) {
      const report = doc.data();
      const ref = doc.ref;
      
      // Update status to overdue
      batch.update(ref, { status: "overdue" });

      // 3. Escalation Logic
      // Check how long it has been overdue (or since creation if dueAt wasn't set correctly, but we use dueAt)
      if (report.dueAt) {
          const dueAtDate = report.dueAt.toDate();
          const timeOverdue = now.toDate().getTime() - dueAtDate.getTime();
          
          if (timeOverdue > escalationThreshold) {
            // Escalate to Manager
            // Need schoolId, which is in path. doc.ref.parent.parent.id
            const schoolId = doc.ref.parent.parent.id;
            
            // Create Admin Task
            const taskRef = db.collection(`Schools/${schoolId}/AdminTasks`).doc();
            batch.set(taskRef, {
                title: `تصعيد صيانة: ${report.title}`,
                description: `تأخر البلاغ أكثر من 48 ساعة عن الموعد المحدد.`,
                priority: "urgent",
                status: "open",
                assignedTo: "manager",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                type: "maintenance_escalation",
                relatedReportId: doc.id,
            });
          }
      }
    }

    await batch.commit();
    console.log(`Checked overdue maintenance reports. Processed ${overdueQuery.size}.`);
  });
