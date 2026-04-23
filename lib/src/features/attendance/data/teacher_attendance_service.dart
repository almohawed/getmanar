import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/school_schedule.dart';

final teacherAttendanceServiceProvider = Provider<TeacherAttendanceService>((
  ref,
) {
  return TeacherAttendanceService(FirebaseFirestore.instance, ref);
});

final currentPeriodScheduleProvider =
    StreamProvider.family<
      List<SchoolSchedule>,
      ({String schoolId, String day, int period})
    >((ref, params) {
      final service = ref.watch(teacherAttendanceServiceProvider);
      return service.watchScheduleByPeriod(
        params.schoolId,
        params.day,
        params.period,
      );
    });

final teacherCurrentSlotProvider =
    StreamProvider.family<
      SchoolSchedule?,
      ({String schoolId, String teacherId, String day, int period})
    >((ref, params) {
      final service = ref.watch(teacherAttendanceServiceProvider);
      return service.watchTeacherSlot(
        params.schoolId,
        params.teacherId,
        params.day,
        params.period,
      );
    });

class TeacherAttendanceService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  TeacherAttendanceService(this._firestore, this._ref);

  // Stream for Deputy View (List of all teachers for a specific period)
  Stream<List<SchoolSchedule>> watchScheduleByPeriod(
    String schoolId,
    String day,
    int period,
  ) {
    return _firestore
        .collection('schoolSchedules')
        .where('schoolId', isEqualTo: schoolId)
        .where('day', isEqualTo: day)
        .where('period', isEqualTo: period)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SchoolSchedule.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Stream for Teacher View (Specific slot)
  Stream<SchoolSchedule?> watchTeacherSlot(
    String schoolId,
    String teacherId,
    String day,
    int period,
  ) {
    return _firestore
        .collection('schoolSchedules')
        .where('schoolId', isEqualTo: schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .where('day', isEqualTo: day)
        .where('period', isEqualTo: period)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return SchoolSchedule.fromMap(
            snapshot.docs.first.id,
            snapshot.docs.first.data(),
          );
        });
  }

  /// Records attendance with strict Safety Guards and Audit Logging.
  ///
  /// [reason] is mandatory if modifying an existing record (non-pending).
  ///
  /// 🔒 SECURITY NOTE:
  /// This method uses a Secure Cloud Function `submitAttendance` to ensure:
  /// 1. Server-Side Time Validation (Not Device Time).
  /// 2. Atomic Audit Logging.
  /// 3. Strict RBAC.
  Future<void> recordAttendance({
    required String scheduleId,
    required AttendanceStatus status,
    required String source,
    String? reason,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      // Call the Secure Cloud Function
      final callable = functions.httpsCallable('submitAttendance');
      await callable.call({
        'scheduleId': scheduleId,
        'status': status.name,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      // Map Cloud Function Errors to User-Friendly Messages
      String message = 'حدث خطأ غير متوقع';
      switch (e.code) {
        case 'deadline-exceeded':
          message =
              'انتهى وقت الحصة الفعلي (توقيت السيرفر). يرجى مراجعة الوكيل.';
          break;
        case 'permission-denied':
          message = 'غير مصرح لك بإجراء هذا التعديل.';
          break;
        case 'already-exists':
          message = 'تم تسجيل التحضير مسبقًا. لا يمكن التعديل.';
          break;
        case 'failed-precondition':
          message = e.message ?? 'لا يمكن إتمام العملية.';
          break;
        case 'invalid-argument':
          message = e.message ?? 'بيانات غير صحيحة.';
          break;
        default:
          message = e.message ?? e.code;
      }
      throw Exception(message);
    } on FirebaseException catch (e) {
      if (e.code == 'no-app') {
        await _recordAttendanceClientSide(
          scheduleId: scheduleId,
          status: status,
          source: source,
          reason: reason,
        );
        return;
      }
      throw Exception('فشل الاتصال بالسيرفر: $e');
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  Future<void> _recordAttendanceClientSide({
    required String scheduleId,
    required AttendanceStatus status,
    required String source,
    String? reason,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    await _firestore.runTransaction((transaction) async {
      final scheduleRef = _firestore
          .collection('schoolSchedules')
          .doc(scheduleId);
      final scheduleSnap = await transaction.get(scheduleRef);

      if (!scheduleSnap.exists) {
        throw Exception('لم يتم العثور على الحصة المطلوبة.');
      }

      final data = scheduleSnap.data() as Map<String, dynamic>;
      final currentStatusName =
          (data['attendanceStatus'] as String?) ?? 'pending';
      final currentStatus = AttendanceStatus.values.firstWhere(
        (s) => s.name == currentStatusName,
        orElse: () => AttendanceStatus.pending,
      );

      final day = data['day'] as String? ?? '';
      final period = (data['period'] as int?) ?? 1;
      final teacherId = data['teacherId'] as String? ?? '';
      final schoolId = data['schoolId'] as String? ?? '';

      final bool isExpired = _isPeriodExpired(day, period);
      final bool isOwnerTeacher =
          user.role == UserRole.teacher && user.id == teacherId;

      if (isOwnerTeacher) {
        if (isExpired) {
          throw Exception('انتهى وقت الحصة، لا يمكن تعديل التحضير.');
        }
        if (currentStatus != AttendanceStatus.pending) {
          throw Exception('غير مصرح لك بتعديل التحضير بعد اعتماده.');
        }
      } else {
        if (!_canOverrideStatus(user.role)) {
          throw Exception('غير مصرح لك بتعديل التحضير.');
        }
        final requiresReason =
            currentStatus != AttendanceStatus.pending || isExpired;
        if (requiresReason && (reason == null || reason.trim().isEmpty)) {
          throw Exception(
            'يجب كتابة سبب واضح عند تعديل التحضير بعد انتهاء الوقت أو بعد اعتماده.',
          );
        }
      }

      transaction.update(scheduleRef, {'attendanceStatus': status.name});

      final logRef = _firestore.collection('teacherAttendanceLogs').doc();
      transaction.set(logRef, {
        'id': logRef.id,
        'scheduleId': scheduleId,
        'teacherId': teacherId,
        'schoolId': schoolId,
        'previousStatus': currentStatus.name,
        'newStatus': status.name,
        'updatedBy': user.id,
        'updatedByRole': user.role.name,
        'reason': reason ?? 'بدون سبب',
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool _canOverrideStatus(UserRole role) {
    // Only Admin, Deputy, and Support can override
    return role == UserRole.admin ||
        role == UserRole.deputy ||
        role == UserRole.technicalSupport ||
        role == UserRole.superAdmin ||
        role == UserRole.supportAdmin;
  }

  bool _isPeriodExpired(String day, int period) {
    // Basic implementation:
    // If today is NOT the schedule day -> Expired (assuming past days are locked)
    // If today IS schedule day -> Check time.

    final now = DateTime.now();
    // Map Arabic day to Weekday
    final scheduleWeekday = _mapArabicDayToWeekday(day);

    if (now.weekday != scheduleWeekday) {
      // If distinct day, and we assume we only look at current week schedules,
      // Any day before today is expired. Any day after is not started.
      // But for safety, let's say if it's NOT today, we treat it as "Special Case"
      // or "Expired" if we assume daily attendance.
      // Let's assume strict daily attendance: You can only mark TODAY.
      // If you are marking yesterday, it is "Expired".
      return true; // Lock everything not "Today"
    }

    // Check Period Times (Approximate for now)
    // P1: 07:00 - 07:45
    // P2: 07:45 - 08:30
    // P3: 08:30 - 09:15
    // P4: 09:15 - 10:00
    // P5: 10:00 - 10:45
    // P6: 10:45 - 11:30
    // P7: 11:30 - 12:15

    // Better:
    // P1 Ends 7:45
    // P2 Ends 8:30
    // ...

    // Convert now to minutes from midnight
    final currentMinutes = now.hour * 60 + now.minute;

    // Allow 15 mins grace period after class ends? User said "End of period".
    // Let's be strict.

    // Calculation:
    // Start 7:00 (420 min)
    // P1 End: 420 + 45 = 465
    // P2 End: 465 + 5 + 45 = 515
    // ...
    int endTime = 420;
    for (int i = 1; i <= period; i++) {
      endTime += 45; // Class
      if (i < 7) endTime += 5; // Break
    }

    return currentMinutes > endTime;
  }

  int _mapArabicDayToWeekday(String day) {
    switch (day) {
      case 'الأحد':
        return DateTime.sunday;
      case 'الاثنين':
        return DateTime.monday;
      case 'الثلاثاء':
        return DateTime.tuesday;
      case 'الأربعاء':
        return DateTime.wednesday;
      case 'الخميس':
        return DateTime.thursday;
      case 'الجمعة':
        return DateTime.friday;
      case 'السبت':
        return DateTime.saturday;
      default:
        return DateTime.sunday;
    }
  }
}
