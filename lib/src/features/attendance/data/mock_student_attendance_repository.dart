import '../domain/student_attendance.dart';
import 'student_attendance_repository.dart';

class MockStudentAttendanceRepository implements StudentAttendanceRepository {
  final List<StudentAttendance> _records = [];

  @override
  Future<List<StudentAttendance>> getStudentAttendance(
    String classId,
    DateTime date,
  ) async {
    return _records
        .where(
          (r) =>
              r.classId == classId &&
              r.date.year == date.year &&
              r.date.month == date.month &&
              r.date.day == date.day,
        )
        .toList();
  }

  @override
  Future<void> saveStudentAttendance(
    List<StudentAttendance> attendanceList,
  ) async {
    for (var newRecord in attendanceList) {
      _records.removeWhere(
        (r) =>
            r.studentId == newRecord.studentId &&
            r.date.year == newRecord.date.year &&
            r.date.month == newRecord.date.month &&
            r.date.day == newRecord.date.day,
      );
      _records.add(newRecord);
    }
  }

  @override
  Future<List<StudentAttendance>> getStudentAttendanceHistory(
    String studentId,
    String schoolId,
  ) async {
    return _records.where((r) => r.studentId == studentId).toList();
  }

  @override
  Stream<List<StudentAttendance>> watchDailyAttendance(
    String schoolId,
    DateTime date,
  ) {
    return Stream.value(
      _records
          .where(
            (r) =>
                r.schoolId == schoolId &&
                r.date.year == date.year &&
                r.date.month == date.month &&
                r.date.day == date.day,
          )
          .toList(),
    );
  }
}
