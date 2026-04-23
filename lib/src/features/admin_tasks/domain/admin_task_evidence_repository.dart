import 'admin_task_evidence_entity.dart';

abstract class AdminTaskEvidenceRepository {
  Future<void> addEvidence(String schoolId, AdminTaskEvidenceEntity evidence);
  Stream<List<AdminTaskEvidenceEntity>> watchEvidence(String schoolId, String taskId);
  Future<void> deleteEvidence(String schoolId, String taskId, String evidenceId);
}
