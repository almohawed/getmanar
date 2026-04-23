import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/src/core/domain/models/behavior_record.dart';
import 'package:masar_app/src/core/domain/models/user.dart';
import 'package:masar_app/src/features/behavior/domain/behavior_analysis_service.dart';

void main() {
  late BehaviorAnalysisService service;
  late User mockStudent;

  setUp(() {
    service = BehaviorAnalysisService();
    mockStudent = User(
      id: 'student-123',
      name: 'Ahmed',
      role: UserRole.student,
      email: 'st.ahmed@getmanar.com',
      schoolId: 'school-1',
    );
  });

  group('Behavior Analysis Engine (Client Side & Logic Verification)', () {
    // Test Case 1: Limited Data
    test('Should handle limited/empty data gracefully', () {
      final result = service.analyzeBehavior([]);

      expect(result.trend, 'stable');
      expect(result.patterns.first, contains('لا توجد بيانات'));
      expect(result.positiveCount, 0);
    });

    // Test Case 2: Medical Case (Bathroom Analysis)
    test('Should identify Medical Case and skip penalties', () {
      final medicalStudent = mockStudent.copyWith(healthStatus: 'bathroom');
      final records = [
        BehaviorRecord(
          id: '1',
          studentId: 'student-123',
          type: BehaviorType.bathroom,
          timestamp: DateTime.now(),
          description: 'Bathroom',
          points: -5,
          teacherId: 'teacher-1',
        ),
      ];

      final result = service.analyzeBathroomBehavior(medicalStudent, records);

      expect(result.isMedicalCase, true);
      expect(result.recommendations.first, contains('حالة صحية خاصة'));
      expect(result.weeklyAverage, 0); // Should be ignored
    });

    // Test Case 3: High Discipline (Bathroom)
    test('Should flag High Discipline if returns are on time', () {
      final records = List.generate(5, (index) {
        final exit = DateTime.now().subtract(Duration(days: index));
        return BehaviorRecord(
          id: '$index',
          studentId: 'student-123',
          type: BehaviorType.bathroom,
          timestamp: exit,
          description: 'Bathroom',
          bathroomExitTime: exit,
          bathroomReturnTime: exit.add(
            const Duration(minutes: 3),
          ), // 3 mins (Good)
          points: 0,
          teacherId: 'teacher-1',
        );
      });

      final result = service.analyzeBathroomBehavior(mockStudent, records);

      expect(result.isMedicalCase, false);
      expect(result.avgDurationMinutes, lessThan(5));
      expect(result.lateReturnCount, 0);
      expect(result.disciplineIndicator, 'High');
    });

    // Test Case 4: Low Discipline (Late Returns)
    test('Should flag Low Discipline if returns are late', () {
      final records = List.generate(5, (index) {
        final exit = DateTime.now().subtract(Duration(days: index));
        return BehaviorRecord(
          id: '$index',
          studentId: 'student-123',
          type: BehaviorType.bathroom,
          timestamp: exit,
          description: 'Bathroom',
          bathroomExitTime: exit,
          bathroomReturnTime: exit.add(
            const Duration(minutes: 15),
          ), // 15 mins (Bad)
          points: -5,
          teacherId: 'teacher-1',
        );
      });

      final result = service.analyzeBathroomBehavior(mockStudent, records);

      expect(result.lateReturnCount, 5);
      expect(result.disciplineIndicator, 'Low');
      expect(
        result.recommendations.any((r) => r.contains('تذكير الطالب')),
        true,
      );
    });
  });

  /*
   * SERVER-SIDE TEST PLAN (Cloud Functions)
   * ======================================
   * These scenarios must be verified in the Firebase Emulator or Staging Env:
   * 
   * Scenario A: Multi-Teacher Context (The "Fairness" Test)
   * - Input: Student has 5 'late' events.
   * - Condition 1: All 5 events from Teacher A.
   *   -> Expected: isContextualIssue = true. Score penalty reduced by 30%. 
   *   -> Recommendation: "Contextual Issue with specific teacher".
   * - Condition 2: 5 events from 5 DIFFERENT teachers.
   *   -> Expected: isContextualIssue = false. Full penalty.
   *   -> Recommendation: "General behavioral issue".
   * 
   * Scenario B: Trend Calculation
   * - Input: 10 negative events.
   * - Condition: 8 events in last 7 days, 2 events in previous 7 days.
   *   -> Expected: Trend = 'Declining'. Risk Level increases.
   * 
   * Scenario C: Medical Exemption (Server Side Score)
   * - Input: Student has 'healthStatus: bathroom' and 20 bathroom events.
   *   -> Expected: Score should NOT decrease by 20 points (Bathroom penalty skipped).
   *   -> Verify: Compare score with non-medical student having same events.
   * 
   * Scenario D: Zero-Bug / Edge Cases
   * - Input: New student, 0 events.
   *   -> Expected: Score 100, Risk Low, Trend Stable. No crash.
   * - Input: Student with mixed events (Positive participation + Negative late).
   *   -> Expected: Score reflects net value (100 - Late + Participation).
   */
}
