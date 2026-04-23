import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/data/firestore_class_repository.dart';
import '../../../academic/data/student_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/student_attendance_repository.dart';
import '../../domain/student_attendance.dart';
import '../../domain/models/daily_absence_model.dart';

final dailyAbsenceProvider = StreamProvider.autoDispose<List<DailyAbsenceModel>>((
  ref,
) {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.value;

  if (user == null || user.schoolId == null) {
    return Stream.value([]);
  }

  final attendanceRepo = ref.watch(studentAttendanceRepositoryProvider);
  final studentRepo = ref.watch(studentRepositoryProvider);
  final classRepo = ref.watch(classRepositoryProvider);

  // Watch daily attendance for today
  return attendanceRepo
      .watchDailyAttendance(user.schoolId!, DateTime.now())
      .asyncMap((attendanceList) async {
        // Filter for absent students in periods 1, 2, or daily (null)
        final relevantAbsences = attendanceList
            .where(
              (a) =>
                  a.status == StudentAttendanceStatus.absent &&
                  (a.period == null || a.period == 1 || a.period == 2),
            )
            .toList();

        // Group by Student ID to combine multiple periods
        final Map<String, List<StudentAttendance>> grouped = {};
        for (var r in relevantAbsences) {
          grouped.putIfAbsent(r.studentId, () => []).add(r);
        }

        final List<DailyAbsenceModel> result = [];

        for (final entry in grouped.entries) {
          final studentId = entry.key;
          final records = entry.value;

          // 1. Fetch Student details
          final student = await studentRepo.getStudentById(
            user.schoolId!,
            studentId,
          );
          if (student == null) continue;

          // 2. Fetch Class Name (use first record's class, assuming same class for same day usually)
          String className = records.first.classId;
          final classroom = await classRepo.getClassById(
            user.schoolId!,
            records.first.classId,
          );
          if (classroom != null) {
            className = classroom.name;
          }

          // 3. Determine Period String
          final periods =
              records
                  .map((r) => r.period)
                  .where((p) => p != null)
                  .toSet()
                  .toList()
                ..sort();
          String periodStr = periods.isEmpty ? 'يومي' : periods.join(' و ');

          // 4. Parent Phone
          String parentPhone = student.phoneNumber ?? '';

          // 5. Teacher Name (Placeholder)
          String teacherName = 'نظام المدرسة';

          result.add(
            DailyAbsenceModel(
              studentName: student.name,
              className: className,
              period: periodStr,
              teacherName: teacherName,
              parentPhone: parentPhone,
              status: 'absent',
              student: student,
            ),
          );
        }

        return result;
      });
});
