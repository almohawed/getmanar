// Using 'any' types to keep local type checking silent without installed deps
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// -----------------------------------------------------------------------------
// 1. Evidence Count Automation
// -----------------------------------------------------------------------------

async function updateEvidenceCount(
  change: any,
  context: any,
  collectionName: string
) {
  // context.params: { schoolId, id, evidenceId }
  const schoolId = context.params.schoolId;
  const parentId = context.params.id;

  if (!schoolId || !parentId) return;

  const parentRef = db.doc(`Schools/${schoolId}/${collectionName}/${parentId}`);
  
  try {
    const snapshot = await parentRef.collection('Evidence').get();
    const count = snapshot.size;
    await parentRef.update({ evidenceCount: count });
    console.log(`Updated evidenceCount for ${collectionName}/${parentId} to ${count}`);
  } catch (error) {
    console.error(`Error updating evidence count for ${collectionName}/${parentId}:`, error);
  }
}

export const onStudentCaseEvidenceWrite = functions.firestore
  .document('Schools/{schoolId}/StudentCases/{id}/Evidence/{evidenceId}')
  .onWrite((change: any, context: any) =>
    updateEvidenceCount(change, context, 'StudentCases'),
  );

export const onSessionEvidenceWrite = functions.firestore
  .document('Schools/{schoolId}/CounselorSessions/{id}/Evidence/{evidenceId}')
  .onWrite((change: any, context: any) =>
    updateEvidenceCount(change, context, 'CounselorSessions'),
  );

export const onPlanEvidenceWrite = functions.firestore
  .document('Schools/{schoolId}/BehaviorPlans/{id}/Evidence/{evidenceId}')
  .onWrite((change: any, context: any) =>
    updateEvidenceCount(change, context, 'BehaviorPlans'),
  );


// -----------------------------------------------------------------------------
// 2. Plan Review Deadline Checker (Daily)
// -----------------------------------------------------------------------------

export const checkPlanReviewDeadlines = functions.pubsub.schedule('every 24 hours').onRun(async (context: any) => {
  const now = admin.firestore.Timestamp.now();
  
  // Find active plans where reviewAt <= now
  // Using collectionGroup query
  const plansSnapshot = await db.collectionGroup('BehaviorPlans')
    .where('status', '==', 'active')
    .where('reviewAt', '<=', now)
    .get();

  const batch = db.batch();
  let taskCount = 0;

  for (const doc of plansSnapshot.docs) {
    const plan = doc.data();
    const schoolId = plan.schoolId;
    const relatedStudentId = (plan as any).studentId || null;
    const relatedCaseId = (plan as any).caseId || null;
    
    if (!schoolId) continue;

    // Optional: Check if a review task was already created recently to avoid duplicates
    // For now, we assume the user will close the task or update the plan (changing reviewAt)

    const taskId = db.collection(`Schools/${schoolId}/AdminTasks`).doc().id;
    const taskRef = db.doc(`Schools/${schoolId}/AdminTasks/${taskId}`);
    
    const taskData = {
      id: taskId,
      schoolId: schoolId,
      title: `مراجعة خطة سلوكية: ${plan.studentName}`,
      description: `حان موعد مراجعة الخطة السلوكية للطالب ${plan.studentName}. يرجى تقييم التقدم واتخاذ الإجراء اللازم.`,
      assignedToRole: 'counselor',
      status: 'open',
      priority: 'high',
      type: 'general',
      dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24h from now
      createdAt: now,
      evidenceCount: 0,
      notes: `Plan ID: ${doc.id}`,
      escalationLevel: 0,
      relatedStudentId,
      relatedCaseId,
    };
    
    batch.set(taskRef, taskData);
    taskCount++;
  }
  
  if (taskCount > 0) {
    await batch.commit();
  }
  
  console.log(`Checked plans. Created ${taskCount} review tasks.`);
});
