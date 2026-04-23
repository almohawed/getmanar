import '../domain/schedule_slot.dart';
import '../domain/schedule_stats.dart';
import '../domain/teacher_constraints_profile.dart';
import 'schedule_repository.dart';

class MockScheduleRepository implements ScheduleRepository {
  // In-memory constraints
  final Map<String, TeacherConstraintsProfile> _constraints = {};

  @override
  Future<List<ScheduleSlot>> getSchedule(
    String schoolId,
    String teacherId,
  ) async {
    return [];
  }

  @override
  Future<void> saveSchedule(
    String schoolId,
    String teacherId,
    List<ScheduleSlot> schedule,
  ) async {
    // no-op
  }

  @override
  Future<void> saveClassSchedule(
    String schoolId,
    String classId,
    List<ScheduleSlot> schedule,
  ) async {
    // no-op
  }

  @override
  Future<List<ScheduleSlot>> getClassSchedule(
    String schoolId,
    String classId,
  ) async {
    return [];
  }

  @override
  Future<String> saveFullSchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> scheduleMap,
  ) async {
    return 'mock_timetable_id';
  }

  @override
  Future<String> saveEmergencySchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> teacherScheduleMap,
    Map<String, List<ScheduleSlot>> classScheduleMap, {
    required Map<String, dynamic> metadata,
  }) async {
    return 'mock_emergency_timetable_id';
  }

  @override
  Future<void> setActiveScheduleVariant(
    String schoolId,
    String variant, {
    String? emergencyTimetableId,
  }) async {}

  @override
  Future<String> getActiveScheduleVariant(String schoolId) async {
    return 'base';
  }

  @override
  Future<void> publishSchedule(String schoolId) async {
    // no-op
  }

  @override
  Future<bool> isSchedulePublished(String schoolId) async {
    return false;
  }

  @override
  Future<int> getTeacherLoad(String schoolId, String teacherId) async {
    return 0;
  }

  @override
  Future<ScheduleStats> getScheduleStats(String schoolId) async {
    return ScheduleStats(
      classesCount: 10,
      teachersCount: 20,
      hasActiveSchedule: false,
      lastUpdate: null,
      activeSchedulesCount: 0,
    );
  }

  @override
  Future<List<TeacherConstraintsProfile>> getTeacherConstraints(
      String schoolId) async {
    return _constraints.values.toList();
  }

  @override
  Future<void> saveTeacherConstraints(TeacherConstraintsProfile profile) async {
    _constraints[profile.teacherId] = profile;
  }
}
