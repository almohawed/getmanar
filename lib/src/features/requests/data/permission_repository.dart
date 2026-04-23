import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../academic/data/student_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/schedule_slot.dart';
import '../domain/arrival_alert.dart';
import '../domain/permission_request.dart';
import '../../auth/presentation/auth_controller.dart';

class PermissionRepository {
  // In-memory storage
  final List<PermissionRequest> _requests = [];
  final List<ArrivalAlert> _arrivals = [];

  PermissionRepository() {
    // Seed with some mock data if needed
    _requests.addAll([
      PermissionRequest(
        id: 'req1',
        studentId: 's1',
        studentName: 'محمد أحمد',
        parentId: 'parent1',
        reason: 'موعد طبي',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: PermissionRequestStatus.pending,
      ),
      PermissionRequest(
        id: 'req2',
        studentId: 's2',
        studentName: 'خالد علي',
        parentId: 'parent1',
        reason: 'ظروف عائلية',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: PermissionRequestStatus.approved,
        decidedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ]);
  }

  Future<List<PermissionRequest>> fetchRequests() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _requests;
  }

  Future<List<PermissionRequest>> fetchRequestsByParent(String parentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _requests.where((r) => r.parentId == parentId).toList();
  }

  Future<List<PermissionRequest>> fetchPendingRequests() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _requests
        .where((r) => r.status == PermissionRequestStatus.pending)
        .toList();
  }

  Future<List<PermissionRequest>> fetchApprovedRequests() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _requests
        .where((r) => r.status == PermissionRequestStatus.approved)
        .toList();
  }

  Future<void> addRequest(PermissionRequest request) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _requests.insert(0, request); // Add to top
  }

  Future<void> updateRequestStatus(
    String requestId,
    PermissionRequestStatus status, {
    String? rejectionReason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: status,
        rejectionReason: rejectionReason,
        decidedAt: DateTime.now(),
      );
    }
  }

  Future<void> markParentAsNear(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        isParentNear: true,
        parentArrivedAt: DateTime.now(),
      );
    }
  }

  // Arrival Logic
  Future<void> addArrivalAlert(ArrivalAlert alert) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _arrivals.insert(0, alert);
  }

  Future<List<ArrivalAlert>> fetchArrivalAlerts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _arrivals;
  }
}

// Provider
final permissionRepositoryProvider = Provider<PermissionRepository>((ref) {
  return PermissionRepository();
});

// Notifier to manage requests list (for reactivity)
class RequestsNotifier extends Notifier<List<PermissionRequest>> {
  @override
  List<PermissionRequest> build() {
    _loadRequests();
    return [];
  }

  Future<void> _loadRequests() async {
    final repo = ref.read(permissionRepositoryProvider);
    final requests = await repo.fetchRequests();
    state = requests;
  }

  Future<void> refresh() async {
    await _loadRequests();
  }

  Future<void> addRequest(PermissionRequest request, String schoolId) async {
    final repo = ref.read(permissionRepositoryProvider);
    await repo.addRequest(request);

    // Notify Deputy
    try {
      final notifRepo = ref.read(notificationRepositoryProvider);
      await notifRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          title: 'طلب استئذان جديد',
          body: 'قام ولي أمر الطالب ${request.studentName} بطلب استئذان.',
          timestamp: DateTime.now(),
          targetRole: 'deputy', // Notify all deputies
          schoolId: schoolId,
        ),
      );
    } catch (e) {
      debugPrint('Failed to send notification for permission request: $e');
      // Continue anyway as the request is saved locally
    }

    state = [request, ...state];
  }

  Future<void> approveRequest(String requestId) async {
    final repo = ref.read(permissionRepositoryProvider);
    final currentUser = ref.read(authStateProvider).value;
    final schoolId = currentUser?.schoolId;

    if (schoolId == null) {
      // Should handle error, but for now just return or log
      debugPrint('Error: No schoolId found for approver');
      return;
    }

    await repo.updateRequestStatus(requestId, PermissionRequestStatus.approved);

    // Find request details
    final request = state.firstWhere((r) => r.id == requestId);

    // Notify Administrative (Idari) and Parent
    final notifRepo = ref.read(notificationRepositoryProvider);

    // Notify Parent
    await notifRepo.sendNotification(
      NotificationRecord(
        id: const Uuid().v4(),
        userId: request.parentId,
        title: 'تمت الموافقة على الاستئذان',
        body: 'تمت الموافقة على طلب استئذان الطالب ${request.studentName}.',
        timestamp: DateTime.now(),
        schoolId: schoolId,
      ),
    );

    // Notify Admin/Idari
    await notifRepo.sendNotification(
      NotificationRecord(
        id: const Uuid().v4(),
        title: 'خروج طالب',
        body:
            'تمت الموافقة على خروج الطالب ${request.studentName}. ولي الأمر بالطريق.',
        timestamp: DateTime.now(),
        targetRole: 'administrative',
        schoolId: schoolId,
      ),
    );

    // Notify Teacher of the current class
    try {
      final studentRepo = ref.read(studentRepositoryProvider);

      final student = await studentRepo.getStudentById(
        schoolId,
        request.studentId,
      );

      if (student != null && (student.assignedClassIds?.isNotEmpty ?? false)) {
        final classId = student.assignedClassIds!.first;
        final scheduleRepo = ref.read(scheduleRepositoryProvider);
        final currentSlot = await _getCurrentClassSlot(
          scheduleRepo,
          schoolId,
          classId,
        );

        if (currentSlot != null && currentSlot.teacherId.isNotEmpty) {
          await notifRepo.sendNotification(
            NotificationRecord(
              id: const Uuid().v4(),
              userId: currentSlot.teacherId,
              title: 'خروج طالب',
              body:
                  'نحيطك علماً بأن الطالب ${request.studentName} قد استأذن وتمت الموافقة على خروجه.',
              timestamp: DateTime.now(),
              data: {'requestId': request.id},
              schoolId: schoolId,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying teacher: $e');
    }

    await _loadRequests();
  }

  Future<ScheduleSlot?> _getCurrentClassSlot(
    ScheduleRepository repo,
    String schoolId,
    String classId,
  ) async {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final period = _getPeriod(now);

    if (period == 0) return null;

    final schedule = await repo.getClassSchedule(schoolId, classId);
    try {
      return schedule.firstWhere((s) => s.day == dayName && s.period == period);
    } catch (_) {
      return null;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
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
      default:
        return '';
    }
  }

  int _getPeriod(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final totalMinutes = hour * 60 + minute;

    if (totalMinutes >= 7 * 60 && totalMinutes < 7 * 60 + 45) return 1;
    if (totalMinutes >= 7 * 60 + 45 && totalMinutes < 8 * 60 + 30) return 2;
    if (totalMinutes >= 8 * 60 + 30 && totalMinutes < 9 * 60 + 15) return 3;
    if (totalMinutes >= 9 * 60 + 15 && totalMinutes < 10 * 60 + 30) {
      return 4; // Break included?
    }
    if (totalMinutes >= 10 * 60 + 30 && totalMinutes < 11 * 60 + 15) return 5;
    if (totalMinutes >= 11 * 60 + 15 && totalMinutes < 12 * 60) return 6;
    if (totalMinutes >= 12 * 60 && totalMinutes < 12 * 60 + 45) return 7;

    return 1; // Default for testing
  }

  Future<void> rejectRequest(String requestId, String reason) async {
    final repo = ref.read(permissionRepositoryProvider);
    await repo.updateRequestStatus(
      requestId,
      PermissionRequestStatus.rejected,
      rejectionReason: reason,
    );
    // Notify Parent
    final request = state.firstWhere((r) => r.id == requestId);
    final notifRepo = ref.read(notificationRepositoryProvider);
    final currentUser = ref.read(authStateProvider).value;

    if (currentUser?.schoolId != null) {
      await notifRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          userId: request.parentId,
          title: 'تم رفض الاستئذان',
          body:
              'تم رفض طلب استئذان الطالب ${request.studentName}. السبب: $reason',
          timestamp: DateTime.now(),
          schoolId: currentUser!.schoolId,
        ),
      );
    }

    await _loadRequests();
  }

  Future<void> notifyParentArrival(String requestId) async {
    final repo = ref.read(permissionRepositoryProvider);
    await repo.markParentAsNear(requestId);

    final request = state.firstWhere((r) => r.id == requestId);

    // Notify Deputy and Admin (Idari)
    final notifRepo = ref.read(notificationRepositoryProvider);
    final currentUser = ref.read(authStateProvider).value;
    final schoolId = currentUser?.schoolId ?? '';

    final notification = NotificationRecord(
      id: const Uuid().v4(),
      title: 'وصول ولي أمر',
      body: 'وصل ولي أمر الطالب ${request.studentName} إلى المدرسة.',
      timestamp: DateTime.now(),
      targetRole: 'deputy', // Also 'administrative' ideally
      schoolId: schoolId,
    );

    await notifRepo.sendNotification(notification);

    // Also send to admin
    await notifRepo.sendNotification(
      notification.copyWith(
        id: const Uuid().v4(),
        targetRole: 'administrative',
      ),
    );

    await _loadRequests();
  }
}

final requestsProvider =
    NotifierProvider<RequestsNotifier, List<PermissionRequest>>(
      RequestsNotifier.new,
    );
