import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/src/features/schedule/application/smart_schedule_service.dart';
import 'package:masar_app/src/features/intelligence/data/smart_schedule_repository.dart';
import 'package:masar_app/src/features/intelligence/domain/scheduling/teacher_constraints_profile.dart';
import 'package:masar_app/src/features/intelligence/domain/scheduling/override_learning_log.dart';
import 'package:masar_app/src/features/schedule/domain/schedule_slot.dart';
import 'package:masar_app/src/core/domain/models/user.dart';
import 'package:masar_app/src/core/domain/models/school.dart';

// Simple Mock Implementation
class MockSmartScheduleRepository implements SmartScheduleRepository {
  @override
  Future<TeacherConstraintsProfile?> getTeacherProfile(
    String? teacherId,
  ) async {
    return null; // Force create new default logic in service
  }

  @override
  Future<void> saveTeacherProfile(TeacherConstraintsProfile? profile) async {}

  @override
  Future<void> logOverride(OverrideLearningLog log) async {}

  @override
  Future<List<OverrideLearningLog>> getOverrides(String teacherId) async {
    return [];
  }
}

void main() {
  late SmartScheduleService service;
  late MockSmartScheduleRepository mockRepo;

  setUp(() {
    mockRepo = MockSmartScheduleRepository();
    service = SmartScheduleService(mockRepo);
  });

  group('Elite Schedule - Critical Logic Tests', () {
    test(
      'HARD FAIL: Should throw exception when Fixed Slot conflicts with Teacher Blocked Time',
      () async {
        // 1. Arrange
        final teacher = User(
          id: 't1',
          name: 'Teacher 1',
          role: UserRole.teacher,
          email: 't1@test.com',
          schoolId: 's1',
        );

        final school = School(
          id: 's1',
          name: 'Test School',
          type: 'government',
          stage: 'High',
          city: 'Riyadh',
          ownerId: 'owner1',
          hasSpecialEducation: false,
        );

        // Constraint: Teacher CANNOT teach on Sunday Period 1
        final constraints = [
          TeacherConstraintsProfile(
            teacherId: 't1',
            weeklyQuota: 24,
            blockedTimeSlots: ['الأحد:1'],
          ),
        ];

        // Input: Admin tries to FORCE Teacher 1 to teach on Sunday Period 1
        final fixedSlots = {
          't1': [
            ScheduleSlot(
              day: 'الأحد',
              period: 1,
              className: 'Class 1A',
              subject: 'Math',
            ),
          ],
        };

        // 2. Act & Assert
        // Must fail with specific error message
        expect(
          () async => await service.generateSchedule(
            teachers: [teacher],
            classIds: ['1A'],
            school: school,
            constraints: constraints, // Pass constraints directly
            fixedSlots: fixedSlots, // Pass conflicting fixed slots
          ),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('تعارض في الجدول المثبت') &&
                  e.toString().contains('وقت محظور'),
            ),
          ),
        );
      },
    );

    test('SUCCESS: Should accept Fixed Slot if no conflict', () async {
      // 1. Arrange
      final teacher = User(
        id: 't1',
        name: 'Teacher 1',
        role: UserRole.teacher,
        email: 't1@test.com',
        schoolId: 's1',
      );

      final school = School(
        id: 's1',
        name: 'Test School',
        type: 'government',
        stage: 'High',
        city: 'Riyadh',
        ownerId: 'owner1',
      );

      final constraints = [
        TeacherConstraintsProfile(
          teacherId: 't1',
          weeklyQuota: 40,
          blockedTimeSlots: ['الأحد:1'],
        ),
      ];

      // Input: Admin fixes slot on Sunday Period 2 (Allowed)
      final fixedSlots = {
        't1': [
          ScheduleSlot(
            day: 'الأحد',
            period: 2,
            className: 'Class 1A',
            subject: 'Math',
          ),
        ],
      };

      // 2. Act
      final result = await service.generateSchedule(
        teachers: [teacher],
        classIds: ['1A'],
        school: school,
        constraints: constraints,
        fixedSlots: fixedSlots,
      );

      // 3. Assert
      // The fixed slot must be present
      final hasFixedSlot = result.schedule['t1']!.any(
        (s) => s.day == 'الأحد' && s.period == 2,
      );
      expect(hasFixedSlot, isTrue);
    });
  });
}
