import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/teacher_attendance.dart';
import 'mock_attendance_repository.dart';

abstract class AttendanceRepository {
  Future<List<TeacherAttendance>> getAttendance(String day, int period);
  Future<void> saveAttendance(List<TeacherAttendance> attendanceList);
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return MockAttendanceRepository();
});
