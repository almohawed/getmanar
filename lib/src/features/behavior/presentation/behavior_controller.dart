import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../domain/behavior_repository.dart';
import '../data/firestore_behavior_repository.dart';
import '../domain/bathroom_pass.dart';
import '../data/firestore_bathroom_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart'; // Import provider
import '../../auth/presentation/auth_controller.dart';
import '../data/offline_behavior_service.dart';
import '../../academic/services/student_excellence_service.dart';

class ViolationResult {
  final bool escalated;
  final bool parentNotified;
  final String message;

  ViolationResult({
    required this.escalated,
    required this.parentNotified,
    required this.message,
  });
}

final behaviorRepositoryProvider = Provider<BehaviorRepository>((ref) {
  final offlineService = ref.watch(offlineBehaviorServiceProvider);
  return FirestoreBehaviorRepository(offlineService: offlineService);
});

// Removed duplicate notificationRepositoryProvider definition

final studentBehaviorProvider =
    StreamProvider.family.autoDispose<List<BehaviorRecord>, String>((
      ref,
      studentId,
    ) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty || studentId.trim().isEmpty) {
        return const Stream.empty();
      }

      final query = FirebaseFirestore.instance
          .collection('behavior_records')
          .where('studentId', isEqualTo: studentId);

      return query.snapshots().map((snap) {
        final records = snap.docs
            .map((d) => BehaviorRecord.fromMap(d.data()))
            .where((r) => r.schoolId == null || r.schoolId == schoolId)
            .toList();
        records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return records;
      });
    });

final pendingTeacherNotesProvider =
    StreamProvider.autoDispose<List<BehaviorRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        return const Stream.empty();
      }

      final query = FirebaseFirestore.instance
          .collection('behavior_records')
          .where('status', isEqualTo: BehaviorStatus.pending.name);

      return query.snapshots().map((snap) {
        final records = snap.docs
            .map((d) => BehaviorRecord.fromMap(d.data()))
            .where(
              (r) =>
                  (r.schoolId == null || r.schoolId == schoolId) &&
                  r.points == 0 &&
                  r.type == BehaviorType.negative,
            )
            .toList();
        records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return records;
      });
    });

// Provides active bathroom trips for a list of students (simplified for UI refresh)
final activeBathroomTripsProvider = FutureProvider.autoDispose
    .family<Map<String, BathroomPass>, List<String>>((ref, studentIds) async {
      final repo = ref.watch(bathroomRepositoryProvider);

      // Execute in parallel to speed up loading
      final results = await Future.wait(
        studentIds.map((id) => repo.getActivePass(id)),
      );

      final Map<String, BathroomPass> activeTrips = {};
      for (int i = 0; i < studentIds.length; i++) {
        final trip = results[i];
        if (trip != null) {
          activeTrips[studentIds[i]] = trip;
        }
      }
      return activeTrips;
    });

// Provider to fetch pending violations
final pendingViolationsProvider =
    FutureProvider.autoDispose<List<BehaviorRecord>>((ref) async {
      final repo = ref.watch(behaviorRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      return repo.getPendingViolations(schoolId: user?.schoolId);
    });

class BehaviorController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  Future<void> addRecord(BehaviorRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(behaviorRepositoryProvider);
      await repo.addBehaviorRecord(record);
      ref.invalidate(activeBathroomTripsProvider);
      ref.invalidate(studentBehaviorProvider(record.studentId));

      // SEI Integration
      if (record.status == BehaviorStatus.approved && record.schoolId != null) {
        final excellenceService = ref.read(studentExcellenceServiceProvider);

        ExcellenceEventType? eventType;
        if (record.type == BehaviorType.positive) {
          eventType = ExcellenceEventType.behaviorPositive;
        } else if (record.type == BehaviorType.negative) {
          eventType = ExcellenceEventType.behaviorNegative;
        } else if (record.type == BehaviorType.escape) {
          eventType =
              ExcellenceEventType.behaviorNegative; // Treat escape as negative
        }

        if (eventType != null) {
          await excellenceService.processEvent(
            schoolId: record.schoolId!,
            studentId: record.studentId,
            eventType: eventType,
            customPoints: record.points,
            reason: record.description,
          );
        }
      }
    });
  }

  Future<String> addClassroomNote({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String description,
    required bool notifyDeputy,
    String? classId,
    String? className,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(behaviorRepositoryProvider);
      final currentUser = ref.read(authStateProvider).value;
      final schoolId = (currentUser?.schoolId ?? '').trim();

      final record = BehaviorRecord(
        id: const Uuid().v4(),
        studentId: studentId,
        teacherId: teacherId,
        teacherName: currentUser?.name,
        classId: classId,
        schoolId: schoolId.isEmpty ? null : schoolId,
        studentName: studentName,
        className: className,
        type: BehaviorType.negative,
        description: description,
        points: 0,
        timestamp: DateTime.now(),
        status: notifyDeputy ? BehaviorStatus.pending : BehaviorStatus.approved,
      );

      await repo.addBehaviorRecord(record);
      ref.invalidate(activeBathroomTripsProvider);
      ref.invalidate(studentBehaviorProvider(studentId));

      if (notifyDeputy && schoolId.isNotEmpty) {
        try {
          final notificationRepo = ref.read(notificationRepositoryProvider);
          await notificationRepo.sendNotification(
            NotificationRecord(
              id: const Uuid().v4(),
              schoolId: schoolId,
              targetRole: 'deputy',
              title: 'ملاحظة صفية واردة',
              body: 'تمت إحالة ملاحظة تربوية للطالب $studentName للمتابعة.',
              timestamp: DateTime.now(),
              data: {
                'recordId': record.id,
                'studentId': studentId,
                'studentName': studentName,
                'classId': classId ?? '',
                'className': className ?? '',
                'source': 'classroom_behavior_indicators',
              },
            ),
          );
        } catch (_) {}
      }

      state = const AsyncValue.data(null);
      return notifyDeputy
          ? 'تم إرسال الملاحظة للوكيل التعليمي بنجاح\nسيتم متابعة الحالة من قبل فريق المدرسة'
          : 'تم حفظ الملاحظة ضمن سجل الطالب';
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<ViolationResult> addViolationWithAutoEscalation({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String description,
    required int points,
    bool isWarning = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(behaviorRepositoryProvider);

      // 1. Get history
      final history = await repo.getStudentBehavior(studentId);

      BehaviorStatus status = BehaviorStatus.approved;
      String message = 'تم تسجيل المخالفة بنجاح في سجل المعلم.';
      bool escalated = false;
      bool parentNotified = false;

      if (isWarning) {
        // Warning Logic: Check for previous warnings
        final warningCount = history
            .where(
              (r) =>
                  r.type == BehaviorType.negative &&
                  r.description == description &&
                  r.status == BehaviorStatus.warning,
            )
            .length;

        if (warningCount >= 1) {
          // Second warning (or more) -> Escalate
          status = BehaviorStatus.pending;
          escalated = true;
          message = 'تم تكرار الإنذار للطالب $studentName، وتمت إحالته للوكيل.';
        } else {
          // First warning
          status = BehaviorStatus.warning;
          message = 'تم تسجيل إنذار للطالب.';
        }
      } else {
        // Normal Violation Logic (New Rule: Always escalate to Deputy)
        // User Request: "Violations recorded by teacher go to Deputy (Pending). If approved, go to Parent."

        status = BehaviorStatus.pending;
        escalated = true;

        // Optional: Check count just for the message context
        final existingCount = history
            .where(
              (r) =>
                  r.type == BehaviorType.negative &&
                  r.description == description,
            )
            .length;
        final newCount = existingCount + 1;

        message = 'تم إرسال المخالفة للوكيل للاعتماد (التكرار رقم $newCount).';
      }

      final currentUser = ref.read(authStateProvider).value;

      // 4. Create Record
      final record = BehaviorRecord(
        id: const Uuid().v4(),
        studentId: studentId,
        teacherId: teacherId,
        teacherName: currentUser?.name,
        schoolId: currentUser?.schoolId,
        type: BehaviorType.negative,
        description: description,
        points: points,
        timestamp: DateTime.now(),
        status: status,
      );

      await repo.addBehaviorRecord(record);
      ref.invalidate(activeBathroomTripsProvider);
      ref.invalidate(studentBehaviorProvider(studentId));

      // SEI Integration (Only if approved/warning)
      if (status == BehaviorStatus.approved ||
          status == BehaviorStatus.warning) {
        if (currentUser?.schoolId != null) {
          final excellenceService = ref.read(studentExcellenceServiceProvider);
          await excellenceService.processEvent(
            schoolId: currentUser!.schoolId!,
            studentId: studentId,
            eventType: ExcellenceEventType.behaviorNegative,
            customPoints: points,
            reason: description,
          );
        }
      }

      if (escalated) {
        // Notify Deputy
        // currentUser is already fetched above
        if (currentUser?.schoolId != null) {
          final notificationRepo = ref.read(notificationRepositoryProvider);
          await notificationRepo.sendNotification(
            NotificationRecord(
              id: const Uuid().v4(),
              schoolId: currentUser!.schoolId,
              targetRole: 'deputy',
              title: isWarning ? 'تكرار إنذار' : 'مخالفة سلوكية جديدة',
              body: isWarning
                  ? 'تكرر الإنذار للطالب $studentName.'
                  : 'قام المعلم بإحالة مخالفة للطالب $studentName للاعتماد.',
              timestamp: DateTime.now(),
              data: {'recordId': record.id},
            ),
          );
        }
      }

      state = const AsyncValue.data(null);
      return ViolationResult(
        escalated: escalated,
        parentNotified: parentNotified,
        message: message,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveViolation(
    BehaviorRecord record,
    String studentName,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(behaviorRepositoryProvider);

      // 1. Update status to approved
      final updated = record.copyWith(status: BehaviorStatus.approved);
      await repo.updateBehaviorRecord(updated);
      ref.invalidate(studentBehaviorProvider(record.studentId));

      // SEI Integration (Deduct points now that it is approved)
      if (record.schoolId != null) {
        final excellenceService = ref.read(studentExcellenceServiceProvider);
        await excellenceService.processEvent(
          schoolId: record.schoolId!,
          studentId: record.studentId,
          eventType: ExcellenceEventType.behaviorNegative,
          customPoints: record.points, // Use original points
          reason: record.description,
        );
      }

      // 2. Notify Parent
      final parentId = await repo.getParentIdForStudent(record.studentId);
      if (parentId != null) {
        final notificationRepo = ref.read(notificationRepositoryProvider);
        await notificationRepo.sendNotification(
          NotificationRecord(
            id: const Uuid().v4(),
            userId: parentId,
            title: 'تنبيه سلوكي',
            body:
                'تم تسجيل مخالفة على الطالب $studentName: ${record.description}',
            timestamp: DateTime.now(),
            data: {'recordId': record.id},
            schoolId: record.schoolId,
          ),
        );
      }
      ref.invalidate(pendingViolationsProvider);
    });
  }

  Future<void> rejectViolation(BehaviorRecord record, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(behaviorRepositoryProvider);
      final notificationRepo = ref.read(notificationRepositoryProvider);

      final updated = record.copyWith(
        status: BehaviorStatus.rejected,
        rejectionReason: reason,
      );
      await repo.updateBehaviorRecord(updated);
      ref.invalidate(studentBehaviorProvider(record.studentId));

      // Notify Teacher
      await notificationRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          userId: record.teacherId,
          schoolId: record.schoolId, // Use record's schoolId
          title: 'تم رفض المخالفة',
          body: 'سبب الرفض: $reason',
          timestamp: DateTime.now(),
          data: {'recordId': record.id},
        ),
      );

      ref.invalidate(pendingViolationsProvider);
    });
  }

  Future<void> startBathroomTrip(User student, User teacher) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(
        bathroomRepositoryProvider,
      ); // Use BathroomRepository
      final notificationRepo = ref.read(notificationRepositoryProvider);

      // 1. Create Bathroom Pass
      final now = DateTime.now();
      final pass = BathroomPass(
        id: const Uuid().v4(),
        studentId: student.id,
        teacherId: teacher.id,
        schoolId: student.schoolId,
        classId: null, // Add if available from context
        startTime: now,
        status: BathroomPassStatus.approved,
        dueYellowAt: now.add(const Duration(minutes: 5)),
        redAt: now.add(const Duration(minutes: 15)),
      );

      await repo.addPass(pass);
      ref.invalidate(activeBathroomTripsProvider);

      // 2. Notify Deputy (Immediate)
      if (student.schoolId != null) {
        await notificationRepo.sendNotification(
          NotificationRecord(
            id: const Uuid().v4(),
            schoolId: student.schoolId!,
            targetRole: 'deputy',
            title: 'خروج طالب (دورة مياه)',
            body: 'خرج الطالب ${student.name} لدورة المياه.',
            timestamp: DateTime.now(),
            data: {'passId': pass.id, 'type': 'bathroom_start'},
          ),
        );
      }

      // 3. Notify Parent (via Student ID)
      await notificationRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          userId: student.id, // Parent watches child's notifications
          schoolId: student.schoolId, // Ensure schoolId is set
          targetRole: 'parent',
          title: 'تنبيه خروج',
          body: 'خرج ابنكم ${student.name} لدورة المياه.',
          timestamp: DateTime.now(),
          data: {'passId': pass.id, 'type': 'bathroom_start'},
        ),
      );
    });
  }

  Future<void> returnStudentFromBathroom(
    BathroomPass activePass,
    User teacher,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(bathroomRepositoryProvider);
      final now = DateTime.now();

      // Check for RED Status (Locked)
      // If status is locked_red OR if time has passed redAt (even if status not updated yet)
      // But user said: "status='locked_red'" is done by Cloud Function.
      // However, client should also check time to prevent race condition or if CF is slow.
      // The user requirement said: "Teacher cannot close the pass... RED status means..."
      // So if status is locked_red, block.
      // Also check time just in case.

      bool isLocked = activePass.status == BathroomPassStatus.locked_red;
      if (!isLocked) {
        final duration = now.difference(activePass.startTime);
        if (duration.inMinutes >= 15) {
          isLocked = true;
        }
      }

      if (isLocked) {
        // Check role
        if (teacher.role != UserRole.admin &&
            teacher.deputyType != 'academic' &&
            teacher.deputyType != 'students') {
          throw Exception(
            'لا يمكن إغلاق الإذن لأنه تجاوز المدة المسموحة (الحالة الحمراء). يرجى مراجعة الوكيل.',
          );
        }
      }

      // 1. Update return time and status
      final updated = activePass.copyWith(
        endTime: now,
        status: BathroomPassStatus.completed,
        closedAt: now,
        closedByRole: teacher.role.name,
        closedByUid: teacher.id,
      );

      await repo.updatePass(updated);

      ref.invalidate(activeBathroomTripsProvider);
    });
  }
}

final behaviorControllerProvider =
    AsyncNotifierProvider<BehaviorController, void>(BehaviorController.new);
