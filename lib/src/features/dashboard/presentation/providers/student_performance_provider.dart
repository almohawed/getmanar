import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../behavior/presentation/behavior_controller.dart';
import '../../../attendance/data/student_attendance_repository.dart';
import '../../../attendance/domain/student_attendance.dart';
import '../../../assignments/data/firestore_assignments_repository.dart';
import '../../../assignments/domain/assignment.dart';
import '../../../violations/data/firestore_violations_repository.dart';
import '../../../violations/domain/behavioral_violation.dart';
import '../../../../core/domain/models/user.dart';

class StudentPerformance {
  final double score;
  final int totalBehaviorPoints;
  final int absenceDays;
  final int missingAssignments;

  StudentPerformance({
    required this.score,
    required this.totalBehaviorPoints,
    required this.absenceDays,
    required this.missingAssignments,
  });
}

final studentPerformanceProvider =
    FutureProvider.family<StudentPerformance, User>((ref, student) async {
      // 1. Behavior
      // We catch error here to prevent the whole UI from failing if one part fails
      int behaviorPoints = 0;
      try {
        final behaviorRecords = await ref.watch(
          studentBehaviorProvider(student.id).future,
        );
        behaviorPoints = behaviorRecords.fold(
          0,
          (sum, record) => sum + record.points,
        );
      } catch (e) {
        debugPrint('Error fetching behavior for performance: $e');
      }

      // 2. Absence
      int absenceDays = 0;
      try {
        final attendanceRepo = ref.watch(studentAttendanceRepositoryProvider);
        final attendanceHistory = await attendanceRepo
            .getStudentAttendanceHistory(student.id, student.schoolId ?? '');
        absenceDays = attendanceHistory
            .where((a) => a.status == StudentAttendanceStatus.absent)
            .length;
      } catch (e) {
        debugPrint('Error fetching attendance for performance: $e');
      }

      // 3. Assignments (Homework)
      int missingAssignments = 0;
      try {
        final assignmentsRecords = await ref.watch(
          studentAssignmentsProvider(student.id).future,
        );
        final now = DateTime.now();
        missingAssignments = assignmentsRecords.where((a) {
          return a.dueDate.isBefore(now) &&
              a.status != AssignmentStatus.submitted &&
              a.status != AssignmentStatus.approved;
        }).length;
      } catch (e) {
        debugPrint('Error fetching assignments for performance: $e');
      }

      // Calculation
      // Base 100
      // Each absence day: -5 (Increased penalty)
      // Each missing assignment: -2 (Increased penalty)
      // Behavior points: directly added (negative points reduce score)

      double score = 100.0;
      score += behaviorPoints; // behaviorPoints can be negative
      score -= (absenceDays * 5);
      score -= (missingAssignments * 2);

      // Clamp 0 to 100
      if (score > 100) score = 100;
      if (score < 0) score = 0;

      return StudentPerformance(
        score: score,
        totalBehaviorPoints: behaviorPoints,
        absenceDays: absenceDays,
        missingAssignments: missingAssignments,
      );
    });

final studentPledgesCountProvider =
    FutureProvider.family<int, User>((ref, student) async {
      try {
        final repo = ref.watch(violationsRepositoryProvider);
        final violations = await repo.getViolationsByStudent(student.id);
        final pledges = violations.where(
          (v) =>
              v.level == ViolationLevel.fourthDegree &&
              v.status != ViolationStatus.rejected,
        );
        return pledges.length;
      } catch (e) {
        debugPrint('Error fetching pledges for student: $e');
        return 0;
      }
    });
