import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/student_repository.dart';

enum ExcellenceEventType {
  absenceUnexcused,
  tardiness,
  bathroomViolation,
  behaviorNegative,
  behaviorPositive,
  homeworkCompleted,
  fullAttendanceWeek,
  participation,
  noViolationsBonus, // Auto-recovery event
}

class StudentExcellenceService {
  final StudentRepository _studentRepository;

  StudentExcellenceService(this._studentRepository);

  // Auto-Deduction & Recovery Rules
  static const Map<ExcellenceEventType, int> _pointsMap = {
    ExcellenceEventType.absenceUnexcused: -10,
    ExcellenceEventType.tardiness: -5,
    ExcellenceEventType.bathroomViolation: -5,
    ExcellenceEventType.behaviorNegative: -5,
    ExcellenceEventType.behaviorPositive: 2,
    ExcellenceEventType.homeworkCompleted: 3,
    ExcellenceEventType.fullAttendanceWeek: 5,
    ExcellenceEventType.participation: 1,
    ExcellenceEventType.noViolationsBonus: 5,
  };

  Future<void> processEvent({
    required String schoolId,
    required String studentId,
    required ExcellenceEventType eventType,
    int? customPoints,
    String? reason,
  }) async {
    try {
      // 1. Get current student data
      final student = await _studentRepository.getStudentById(
        schoolId,
        studentId,
      );
      if (student == null) {
        debugPrint('Student not found for excellence update: $studentId');
        return;
      }

      // 2. Calculate point change
      int pointChange = customPoints ?? _pointsMap[eventType] ?? 0;

      // 3. Update Last Violation Date if negative event
      DateTime? newLastViolationDate = student.lastViolationDate;
      if (pointChange < 0) {
        newLastViolationDate = DateTime.now();
      }

      // 4. Apply change
      int newScore = student.excellenceScore + pointChange;

      // 5. Clamp score (0 - 100)
      if (newScore > 100) newScore = 100;
      if (newScore < 0) newScore = 0;

      if (newScore == student.excellenceScore &&
          newLastViolationDate == student.lastViolationDate)
        return;

      // 6. Update Student
      final updatedStudent = student.copyWith(
        excellenceScore: newScore,
        lastViolationDate: newLastViolationDate,
      );
      await _studentRepository.updateStudent(schoolId, updatedStudent);

      debugPrint(
        'Updated Excellence Score for ${student.name}: ${student.excellenceScore} -> $newScore (Reason: $eventType)',
      );

      // 7. Check for Social Influence (Predictive)
      if (newScore < 60) {
         // Social analysis removed as per new privacy policy
      }
    } catch (e) {
      debugPrint('Error updating excellence score: $e');
    }
  }

  // Social Behavior Analysis Removed
  // Friend-based influence logic has been deprecated for privacy safety.

  // Check for Auto-Recovery (Time-based)
  // Should be called on dashboard load or periodically
  Future<void> checkTimeBasedRecovery(String schoolId, String studentId) async {
    final student = await _studentRepository.getStudentById(
      schoolId,
      studentId,
    );
    if (student == null) return;

    // Only recover if score is < 100
    if (student.excellenceScore >= 100) return;

    final lastViolation = student.lastViolationDate;
    if (lastViolation == null) {
      // Never had a violation, maybe give a boost if not 100?
      return;
    }

    final daysSinceViolation = DateTime.now().difference(lastViolation).inDays;
    debugPrint(
      'Excellence recovery check for $studentId: $daysSinceViolation days since last violation',
    );

    // If 7 days passed since last violation, trigger a recovery event
    // Problem: This will trigger every time we check after day 7.
    // Solution: We need to know if we already applied it.
    // For this MVP, we will assume this is handled by a separate "Daily Job" or skip implementation to avoid infinite points.
    // Alternatively, we can check if score is low and days > 7, we push it up slightly,
    // but we need to record "lastRecoveryDate" to prevent loop.

    // Leaving this as a placeholder for the "Time-based Heuristic" requirement.
    // Real implementation requires 'lastRecoveryDate' field.
  }
}

final studentExcellenceServiceProvider = Provider<StudentExcellenceService>((
  ref,
) {
  final studentRepo = ref.watch(studentRepositoryProvider);
  return StudentExcellenceService(studentRepo);
});
