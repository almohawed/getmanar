import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masar_app/src/features/schedule/application/elite_schedule_service.dart';
import 'package:masar_app/src/features/schedule/data/elite_schedule_repository.dart';
import 'package:masar_app/src/features/schedule/domain/scheduling_session.dart';
import 'package:masar_app/src/features/schedule/domain/teacher_preference.dart';
import 'package:masar_app/src/features/admin/data/firestore_teacher_repository.dart';
import 'package:masar_app/src/core/domain/models/user.dart';

// --- Manual Mocks ---

class FakeEliteRepo extends Fake implements EliteScheduleRepository {
  List<TeacherPreference> _prefs = [];
  final List<String> _remindedIds = [];
  SchedulingSession? _session;

  @override
  Future<List<TeacherPreference>> getPreferences(String schoolId, String sessionId) async {
    return _prefs;
  }

  @override
  Future<void> sendReminders(List<String> teacherIds, String title, String body) async {
    _remindedIds.addAll(teacherIds);
  }

  @override
  Future<SchedulingSession> getSession(String schoolId, String sessionId) async {
    if (_session != null) return _session!;
    throw Exception('Session not found');
  }

  @override
  Future<void> updateSessionStatus(String schoolId, String sessionId, SessionStatus status) async {
    if (_session != null) {
        _session = _session!.copyWith(status: status);
    }
  }
}

class FakeTeacherRepo extends Fake implements FirestoreTeacherRepository {
  List<User> _teachers = [];

  @override
  Future<List<User>> getTeachers({String? schoolId}) async {
    return _teachers;
  }
}

void main() {
  group('Elite Schedule Service Tests', () {
    test('1. Send Reminders: Only missing teachers get reminders', () async {
        final eliteRepo = FakeEliteRepo();
        final teacherRepo = FakeTeacherRepo();
        final container = ProviderContainer(overrides: [
            eliteScheduleRepositoryProvider.overrideWithValue(eliteRepo),
            firestoreTeacherRepositoryProvider.overrideWithValue(teacherRepo),
        ]);
        
        // Setup
        teacherRepo._teachers = [
            User(id: 't1', email: 't1@test.com', role: UserRole.teacher, name: 'T1', schoolId: 's1'),
            User(id: 't2', email: 't2@test.com', role: UserRole.teacher, name: 'T2', schoolId: 's1'),
            User(id: 't3', email: 't3@test.com', role: UserRole.teacher, name: 'T3', schoolId: 's1'),
        ];
        
        eliteRepo._prefs = [
            TeacherPreference(teacherId: 't1', schoolId: 's1', sessionId: 'ses1', unwantedSlots: [], submittedAt: DateTime.now()),
        ];
        
        final serviceProv = container.read(eliteScheduleServiceProvider);
        
        // Act
        final count = await serviceProv.sendRemindersToNonSubmitters('s1', 'ses1');
        
        // Assert
        expect(count, 2); // t2, t3
        expect(eliteRepo._remindedIds, contains('t2'));
        expect(eliteRepo._remindedIds, contains('t3'));
        expect(eliteRepo._remindedIds, isNot(contains('t1')));
    });

    test('2. Close Session: Throws if deadline not passed and not forced', () async {
         final eliteRepo = FakeEliteRepo();
         final container = ProviderContainer(overrides: [
            eliteScheduleRepositoryProvider.overrideWithValue(eliteRepo),
        ]);
        
        // Setup Session in future
        eliteRepo._session = SchedulingSession(
            id: 'ses1', 
            schoolId: 's1', 
            status: SessionStatus.collecting, 
            createdAt: DateTime.now(), 
            deadline: DateTime.now().add(Duration(hours: 1)) // Future
        );
        
        final serviceProv = container.read(eliteScheduleServiceProvider);
        
        // Act & Assert
        expect(
            () => serviceProv.closeAndGenerate('s1', 'ses1'),
            throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('لا يمكن إغلاق الجلسة قبل انتهاء الوقت')))
        );
    });

    test('3. Close Session: Proceeds if forced even if deadline not passed', () async {
         final eliteRepo = FakeEliteRepo();
         final container = ProviderContainer(overrides: [
            eliteScheduleRepositoryProvider.overrideWithValue(eliteRepo),
        ]);
        
        // Setup Session in future
        eliteRepo._session = SchedulingSession(
            id: 'ses1', 
            schoolId: 's1', 
            status: SessionStatus.collecting, 
            createdAt: DateTime.now(), 
            deadline: DateTime.now().add(Duration(hours: 1)) // Future
        );
        
        final serviceProv = container.read(eliteScheduleServiceProvider);
        
        // Act
        await serviceProv.closeAndGenerate('s1', 'ses1', force: true);

        // Assert
        expect(eliteRepo._session!.status, SessionStatus.closed);
    });
  });
}
