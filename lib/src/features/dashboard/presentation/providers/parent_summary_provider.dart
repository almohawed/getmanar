import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../behavior/presentation/behavior_controller.dart';
import '../../../attendance/data/student_attendance_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../behavior/domain/behavior_repository.dart';
import '../../../attendance/domain/student_attendance.dart';
import '../../../../core/domain/models/behavior_record.dart'; // Import for BehaviorRecord if needed

class ParentWeeklySummary {
  final String behaviorStatus; // 'stable', 'needs_followup'
  final String attendanceStatus; // 'excellent', 'notes'
  final String homeworkStatus; // 'regular', 'late' (Mocked for now if no data)

  ParentWeeklySummary({
    required this.behaviorStatus,
    required this.attendanceStatus,
    required this.homeworkStatus,
  });

  factory ParentWeeklySummary.empty() {
    return ParentWeeklySummary(
      behaviorStatus: 'stable',
      attendanceStatus: 'excellent',
      homeworkStatus: 'regular',
    );
  }
}

final parentWeeklySummaryProvider =
    FutureProvider.family<ParentWeeklySummary, String>((ref, studentId) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null)
        return ParentWeeklySummary.empty();

      final schoolId = user.schoolId!;

      // 1. Fetch Behavior (Last 7 Days)
      final behaviorRepo = ref.watch(behaviorRepositoryProvider);
      final behaviors = await behaviorRepo.getStudentBehavior(
        studentId,
        schoolId: schoolId,
      );

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final recentNegativeBehaviors = behaviors.where((b) {
        return b.timestamp.isAfter(weekAgo) &&
            b.points < 0; // Negative behavior
      }).toList();

      String behaviorStatus = 'stable';
      if (recentNegativeBehaviors.length > 2) {
        behaviorStatus = 'needs_followup';
      } else if (recentNegativeBehaviors.any((b) => b.points <= -10)) {
        // Major violation
        behaviorStatus = 'needs_followup';
      }

      // 2. Fetch Attendance (Last 7 Days)
      final attendanceRepo = ref.watch(studentAttendanceRepositoryProvider);
      final attendanceHistory = await attendanceRepo
          .getStudentAttendanceHistory(studentId, schoolId);

      final recentAbsence = attendanceHistory.where((a) {
        // Check date and status
        // Assuming 'date' is DateTime
        // Assuming status is enum or string. Based on search result: StudentAttendanceStatus.absent
        final isRecent = a.date.isAfter(weekAgo);
        final isAbsent = a.status == StudentAttendanceStatus.absent;
        return isRecent && isAbsent;
      }).toList();

      String attendanceStatus = 'excellent';
      if (recentAbsence.isNotEmpty) {
        attendanceStatus = 'notes';
      }

      // 3. Homework (Mock/Placeholder for now as requested "Regular/Late")
      // In a real app, this would query a HomeworkRepository
      String homeworkStatus = 'regular';

      return ParentWeeklySummary(
        behaviorStatus: behaviorStatus,
        attendanceStatus: attendanceStatus,
        homeworkStatus: homeworkStatus,
      );
    });
