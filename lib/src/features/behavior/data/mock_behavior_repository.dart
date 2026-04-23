import '../../../core/domain/models/behavior_record.dart';
import '../domain/behavior_repository.dart';

class MockBehaviorRepository implements BehaviorRepository {
  final List<BehaviorRecord> _records = [];

  @override
  Future<List<BehaviorRecord>> getStudentBehavior(
    String studentId, {
    String? schoolId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records
        .where(
          (r) =>
              r.studentId == studentId &&
              (schoolId == null || r.schoolId == schoolId),
        )
        .toList();
  }

  @override
  Future<void> addBehaviorRecord(BehaviorRecord record) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _records.add(record);
  }

  @override
  Future<List<BehaviorRecord>> getClassBehavior(String classId) async {
    return _records;
  }

  @override
  Future<void> updateBehaviorRecord(BehaviorRecord record) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
    }
  }

  @override
  Future<BehaviorRecord?> getActiveBathroomTrip(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 50)); // Fast check
    try {
      return _records.firstWhere(
        (r) =>
            r.studentId == studentId &&
            r.type == BehaviorType.bathroom &&
            r.bathroomReturnTime == null,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<BehaviorRecord>> getPendingViolations({String? schoolId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records
        .where(
          (r) =>
              r.status == BehaviorStatus.pending &&
              (schoolId == null || r.schoolId == schoolId),
        )
        .toList();
  }

  @override
  Future<List<BehaviorRecord>> getRejectedViolations(String teacherId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records
        .where(
          (r) =>
              r.teacherId == teacherId && r.status == BehaviorStatus.rejected,
        )
        .toList();
  }

  @override
  Future<List<BehaviorRecord>> getTeacherDrafts(String teacherId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records
        .where(
          (r) => r.teacherId == teacherId && r.status == BehaviorStatus.draft,
        )
        .toList();
  }

  @override
  Future<List<BehaviorRecord>> getTeacherRecords(String teacherId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records.where((r) => r.teacherId == teacherId).toList();
  }

  @override
  Future<void> deleteBehaviorRecord(String recordId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _records.removeWhere((r) => r.id == recordId);
  }

  @override
  Future<List<BehaviorRecord>> getRecordsByType(BehaviorType type) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records.where((r) => r.type == type).toList();
  }

  @override
  Future<String?> getParentIdForStudent(String studentId) async {
    return null;
  }

  @override
  Future<List<BehaviorRecord>> getSchoolBehavior(
    String schoolId, {
    DateTime? since,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _records
        .where(
          (r) =>
              r.schoolId == schoolId &&
              (since == null || r.timestamp.isAfter(since)),
        )
        .toList();
  }
}
