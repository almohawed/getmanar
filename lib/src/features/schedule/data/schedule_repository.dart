import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/schedule_slot.dart';
import '../domain/schedule_stats.dart';
import '../domain/teacher_constraints_profile.dart'; // Added
import 'firestore_schedule_repository.dart';
import 'mock_schedule_repository.dart';

abstract class ScheduleRepository {
  Future<void> saveSchedule(
    String schoolId,
    String teacherId,
    List<ScheduleSlot> schedule,
  );
  Future<List<ScheduleSlot>> getSchedule(String schoolId, String teacherId);
  Future<void> saveClassSchedule(
    String schoolId,
    String classId,
    List<ScheduleSlot> schedule,
  );
  Future<List<ScheduleSlot>> getClassSchedule(String schoolId, String classId);
  Future<String> saveFullSchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> scheduleMap,
  );
  Future<String> saveEmergencySchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> teacherScheduleMap,
    Map<String, List<ScheduleSlot>> classScheduleMap, {
    required Map<String, dynamic> metadata,
  });
  Future<void> setActiveScheduleVariant(
    String schoolId,
    String variant, {
    String? emergencyTimetableId,
  });
  Future<String> getActiveScheduleVariant(String schoolId);
  Future<void> publishSchedule(String schoolId);
  Future<bool> isSchedulePublished(String schoolId);
  Future<int> getTeacherLoad(String schoolId, String teacherId);
  Future<ScheduleStats> getScheduleStats(String schoolId);

  // New Methods for Teacher Constraints
  Future<List<TeacherConstraintsProfile>> getTeacherConstraints(
    String schoolId,
  );
  Future<void> saveTeacherConstraints(TeacherConstraintsProfile profile);
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user != null && (user.schoolId?.isNotEmpty ?? false)) {
    return FirestoreScheduleRepository();
  }
  return MockScheduleRepository();
});

final teacherScheduleProvider =
    FutureProvider.family<List<ScheduleSlot>, String>((ref, teacherId) async {
      final repo = ref.watch(scheduleRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return [];
      return repo.getSchedule(schoolId, teacherId);
    });

final classScheduleProvider = FutureProvider.family<List<ScheduleSlot>, String>(
  (ref, classId) async {
    final repo = ref.watch(scheduleRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return [];
    return repo.getClassSchedule(schoolId, classId);
  },
);
