import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/student_attendance.dart';
import 'mock_student_attendance_repository.dart';
import 'firestore_student_attendance_repository.dart';

abstract class StudentAttendanceRepository {
  Future<List<StudentAttendance>> getStudentAttendance(
    String classId,
    DateTime date,
  );
  Future<void> saveStudentAttendance(List<StudentAttendance> attendanceList);
  Future<List<StudentAttendance>> getStudentAttendanceHistory(
    String studentId,
    String schoolId,
  );
  Stream<List<StudentAttendance>> watchDailyAttendance(
    String schoolId,
    DateTime date,
  );
}

final studentAttendanceRepositoryProvider =
    Provider<StudentAttendanceRepository>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user != null && (user.schoolId?.isNotEmpty ?? false)) {
        return FirestoreStudentAttendanceRepository(FirebaseFirestore.instance);
      }
      return MockStudentAttendanceRepository();
    });

final studentAttendanceHistoryProvider =
    FutureProvider.family<List<StudentAttendance>, User>((ref, student) async {
      final repo = ref.watch(studentAttendanceRepositoryProvider);
      if (student.schoolId == null) return [];
      return repo.getStudentAttendanceHistory(student.id, student.schoolId!);
    });
