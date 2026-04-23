import '../../../core/domain/models/behavior_record.dart';

abstract class BehaviorRepository {
  Future<List<BehaviorRecord>> getStudentBehavior(
    String studentId, {
    String? schoolId,
  });
  Future<void> addBehaviorRecord(BehaviorRecord record);
  Future<List<BehaviorRecord>> getClassBehavior(String classId);
  Future<void> updateBehaviorRecord(
    BehaviorRecord record,
  ); // For setting return time
  Future<BehaviorRecord?> getActiveBathroomTrip(String studentId);
  Future<List<BehaviorRecord>> getPendingViolations({String? schoolId});
  Future<List<BehaviorRecord>> getRejectedViolations(String teacherId);
  Future<List<BehaviorRecord>> getTeacherDrafts(String teacherId);
  Future<List<BehaviorRecord>> getTeacherRecords(String teacherId);
  Future<void> deleteBehaviorRecord(String recordId);
  Future<List<BehaviorRecord>> getRecordsByType(BehaviorType type);
  Future<String?> getParentIdForStudent(String studentId);
  Future<List<BehaviorRecord>> getSchoolBehavior(
    String schoolId, {
    DateTime? since,
  });
}
