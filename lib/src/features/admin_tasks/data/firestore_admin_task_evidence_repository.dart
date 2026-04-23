import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_task_evidence_entity.dart';
import '../domain/admin_task_evidence_repository.dart';
import 'admin_task_evidence_model.dart';

class FirestoreAdminTaskEvidenceRepository
    implements AdminTaskEvidenceRepository {
  final FirebaseFirestore _firestore;

  FirestoreAdminTaskEvidenceRepository(this._firestore);

  CollectionReference _getEvidenceCollection(String schoolId, String taskId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('AdminTasks')
        .doc(taskId)
        .collection('Evidence');
  }

  @override
  Future<void> addEvidence(
    String schoolId,
    AdminTaskEvidenceEntity evidence,
  ) async {
    final model = AdminTaskEvidenceModel(
      id: evidence.id,
      taskId: evidence.taskId,
      addedByUserId: evidence.addedByUserId,
      addedByUserName: evidence.addedByUserName,
      type: evidence.type,
      url: evidence.url,
      description: evidence.description,
      createdAt: evidence.createdAt,
    );

    // Just add the document. evidenceCount is managed by Cloud Functions.
    final evidenceRef = _getEvidenceCollection(
      schoolId,
      evidence.taskId,
    ).doc(evidence.id);
    await evidenceRef.set(model.toMap());
  }

  @override
  Stream<List<AdminTaskEvidenceEntity>> watchEvidence(
    String schoolId,
    String taskId,
  ) {
    return _getEvidenceCollection(
      schoolId,
      taskId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminTaskEvidenceModel.fromFirestore(doc);
      }).toList();
    });
  }

  @override
  Future<void> deleteEvidence(
    String schoolId,
    String taskId,
    String evidenceId,
  ) async {
    // Just delete the document. evidenceCount is managed by Cloud Functions.
    final evidenceRef = _getEvidenceCollection(
      schoolId,
      taskId,
    ).doc(evidenceId);
    await evidenceRef.delete();
  }
}
