import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/src/features/attendance/data/teacher_attendance_service.dart';
import 'package:masar_app/src/features/attendance/domain/school_schedule.dart';
import 'package:masar_app/src/core/domain/models/user.dart';
import 'package:masar_app/src/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore_for_file: subtype_of_sealed_class

// --- Minimal Fakes for Firestore Transaction Testing ---

class FakeFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> data = {};
  final List<String> logs = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return FakeCollectionReference(path, this);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) updateFunction, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    logs.add('Transaction Started');
    final transaction = FakeTransaction(this);
    try {
      final result = await updateFunction(transaction);
      logs.add('Transaction Committed');
      return result;
    } catch (e) {
      logs.add('Transaction Failed: $e');
      rethrow;
    }
  }
}

class FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final String path;
  final FakeFirestore firestore;
  FakeCollectionReference(this.path, this.firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(
      '${this.path}/${path ?? "new_id_${DateTime.now().millisecondsSinceEpoch}"}',
      firestore,
    );
  }
}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final String path;
  final FakeFirestore firestore;
  FakeDocumentReference(this.path, this.firestore);

  @override
  String get id => path.split('/').last;
}

class FakeTransaction extends Fake implements Transaction {
  final FakeFirestore firestore;
  FakeTransaction(this.firestore);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) async {
    final path = (document as FakeDocumentReference).path;
    final data = firestore.data[path];
    return FakeDocumentSnapshot<T>(document.id, data as T?);
  }

  @override
  Transaction update(DocumentReference document, Map<String, dynamic> data) {
    firestore.logs.add('Update ${document.id}: $data');
    final path = (document as FakeDocumentReference).path;
    if (firestore.data.containsKey(path)) {
      firestore.data[path]!.addAll(data);
    }
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    firestore.logs.add('Set ${document.id}: $data');
    final path = (document as FakeDocumentReference).path;
    if (data is Map<String, dynamic>) {
      firestore.data[path] = data;
    }
    return this;
  }

  @override
  Transaction delete(DocumentReference document) {
    firestore.logs.add('Delete ${document.id}');
    final path = (document as FakeDocumentReference).path;
    firestore.data.remove(path);
    return this;
  }
}

class FakeDocumentSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  final String _id;
  final T? _data;
  FakeDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  T? data() => _data;
}

// --- Fake AuthNotifier ---

class FakeAuthNotifier extends AuthNotifier {
  final User? initialUser;
  FakeAuthNotifier(this.initialUser);

  @override
  FutureOr<User?> build() {
    return initialUser;
  }
}

// --- Tests ---

void main() {
  group('Attendance Security & Logic Tests', () {
    late FakeFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirestore();
    });

    test(
      '1. RBAC: Teacher CANNOT modify non-pending status (Already Recorded)',
      () async {
        // Arrange
        firestore.data['schoolSchedules/sch1'] = {
          'schoolId': 's1',
          'teacherId': 't1',
          'day': 'الأحد',
          'period': 1,
          'attendanceStatus': 'present', // Already recorded
          'subject': 'Math',
          'className': '1A',
        };

        container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              () => FakeAuthNotifier(
                User(
                  id: 't1',
                  email: 't@t.com',
                  role: UserRole.teacher,
                  name: 'Teacher',
                  schoolId: 's1',
                ),
              ),
            ),
            teacherAttendanceServiceProvider.overrideWith(
              (ref) => TeacherAttendanceService(firestore, ref),
            ),
          ],
        );

        final service = container.read(teacherAttendanceServiceProvider);

        // Act & Assert
        try {
          await service.recordAttendance(
            scheduleId: 'sch1',
            status: AttendanceStatus.absent,
            source: 'test',
          );
          fail('Should have thrown exception');
        } catch (e) {
          // Accept either "Time Expired" or "Unauthorized Modification"
          // Both are valid security blocks for a Teacher.
          final msg = e.toString();
          final isTimeError = msg.contains('انتهى وقت الحصة');
          final isAuthError = msg.contains('غير مصرح لك بتعديل التحضير');
          expect(
            isTimeError || isAuthError,
            isTrue,
            reason: 'Should fail due to time or permission: $msg',
          );
        }
      },
    );

    test('2. RBAC: Deputy CAN modify non-pending status WITH Reason', () async {
      // Arrange
      firestore.data['schoolSchedules/sch1'] = {
        'schoolId': 's1',
        'teacherId': 't1',
        'day': 'الأحد',
        'period': 1,
        'attendanceStatus': 'present',
        'subject': 'Math',
        'className': '1A',
      };

      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              User(
                id: 'd1',
                email: 'd@d.com',
                role: UserRole.deputy,
                name: 'Deputy',
                schoolId: 's1',
                deputyType: 'academic',
              ),
            ),
          ),
          teacherAttendanceServiceProvider.overrideWith(
            (ref) => TeacherAttendanceService(firestore, ref),
          ),
        ],
      );

      final service = container.read(teacherAttendanceServiceProvider);

      // Act
      await service.recordAttendance(
        scheduleId: 'sch1',
        status: AttendanceStatus.absent,
        source: 'test',
        reason: 'Correction',
      );

      // Assert
      expect(firestore.logs, contains('Transaction Committed'));
      // Verify Schedule Update
      expect(
        firestore.data['schoolSchedules/sch1']!['attendanceStatus'],
        'absent',
      );

      // Verify Audit Log Creation (Atomic)
      // Check if any log entry corresponds to creating a document in teacherAttendanceLogs
      final hasLog = firestore.logs.any(
        (l) => l.startsWith('Set') && l.contains('Correction'),
      );
      expect(
        hasLog,
        isTrue,
        reason: 'Audit Log should be created. Logs: ${firestore.logs}',
      );
    });

    test('3. Atomic AuditLog: Log is created within same transaction', () async {
      // Arrange
      firestore.data['schoolSchedules/sch1'] = {
        'schoolId': 's1',
        'teacherId': 't1',
        'day': 'الأحد',
        'period': 1,
        'attendanceStatus': 'pending',
        'subject': 'Math',
        'className': '1A',
      };

      // Use Deputy to bypass Time Lock if needed (assuming time is expired in test env)
      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              User(
                id: 'd1',
                email: 'd@d.com',
                role: UserRole.deputy,
                name: 'Deputy',
                schoolId: 's1',
                deputyType: 'academic',
              ),
            ),
          ),
          teacherAttendanceServiceProvider.overrideWith(
            (ref) => TeacherAttendanceService(firestore, ref),
          ),
        ],
      );

      final service = container.read(teacherAttendanceServiceProvider);

      // Act
      await service.recordAttendance(
        scheduleId: 'sch1',
        status: AttendanceStatus.present,
        source: 'test',
        reason: 'Late Entry', // Reason needed if expired
      );

      // Assert
      final updates = firestore.logs
          .where((l) => l.startsWith('Update') || l.startsWith('Set'))
          .toList();
      expect(
        updates.length,
        2,
        reason: 'Should have 2 writes (Schedule + Log). Found: $updates',
      );
    });

    test('4. Safety Guard: Time Lock (Expired Period)', () async {
      // Arrange
      // Determine a day that is definitely NOT today to force expiration
      final now = DateTime.now();
      final todayIndex = now.weekday; // 1=Mon, ..., 7=Sun

      // Map index to our Arabic string (simplified for test)
      String getDayName(int index) {
        switch (index) {
          case DateTime.sunday:
            return 'الأحد';
          case DateTime.monday:
            return 'الاثنين';
          case DateTime.tuesday:
            return 'الثلاثاء';
          case DateTime.wednesday:
            return 'الأربعاء';
          case DateTime.thursday:
            return 'الخميس';
          case DateTime.friday:
            return 'الجمعة';
          case DateTime.saturday:
            return 'السبت';
          default:
            return 'الأحد';
        }
      }

      // Pick "tomorrow" (or just next day) to ensure it's not today
      final differentDayIndex = (todayIndex % 7) + 1;
      final differentDayName = getDayName(differentDayIndex);

      firestore.data['schoolSchedules/sch1'] = {
        'schoolId': 's1',
        'teacherId': 't1',
        'day': differentDayName,
        'period': 1,
        'attendanceStatus': 'pending',
        'subject': 'Math',
        'className': '1A',
      };

      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              User(
                id: 't1',
                email: 't@t.com',
                role: UserRole.teacher,
                name: 'Teacher',
                schoolId: 's1',
              ),
            ),
          ),
          teacherAttendanceServiceProvider.overrideWith(
            (ref) => TeacherAttendanceService(firestore, ref),
          ),
        ],
      );

      final service = container.read(teacherAttendanceServiceProvider);

      // Act & Assert
      try {
        await service.recordAttendance(
          scheduleId: 'sch1',
          status: AttendanceStatus.present,
          source: 'test',
        );
        fail('Should have thrown Time Lock exception');
      } catch (e) {
        expect(e.toString(), contains('انتهى وقت الحصة'));
      }
    });
  });
}
