import '../domain/schedule_run.dart';
import '../domain/teacher_preference_entity.dart';

abstract class ScheduleRunRepository {
  Future<String> createScheduleRun(ScheduleRun run);
  Future<void> updateScheduleRun(ScheduleRun run);
  Future<ScheduleRun?> getScheduleRun(String schoolId, String runId);
  Stream<ScheduleRun?> watchScheduleRun(String schoolId, String runId);
  Future<List<ScheduleRun>> listScheduleRuns(
    String schoolId, {
    ScheduleMode? mode,
    int limit,
  });
  
  // Teacher Preferences
  Future<void> saveTeacherPreference(String schoolId, TeacherPreferenceEntity preference);
  Future<TeacherPreferenceEntity?> getTeacherPreference(String schoolId, String runId, String teacherId);
  Future<List<TeacherPreferenceEntity>> getAllPreferences(String schoolId, String runId);
}
