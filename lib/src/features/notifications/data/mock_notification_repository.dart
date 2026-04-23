import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_record.dart';
import '../domain/notification_repository.dart';
import 'firestore_notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  final List<NotificationRecord> _notifications = [];
  final _controller = StreamController<List<NotificationRecord>>.broadcast();

  MockNotificationRepository() {
    // Initial mock data
    _notifications.add(
      NotificationRecord(
        id: '1',
        userId: 'student1',
        title: 'مرحباً بك في مسار',
        body: 'نتمنى لك عاماً دراسياً موفقاً',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    _emit();
  }

  void _emit() {
    _controller.add(List.from(_notifications));
  }

  @override
  Stream<List<NotificationRecord>> getUserNotifications(
    String userId, {
    String? schoolId,
  }) {
    // Filter by userId and emit initial value
    return _controller.stream.map((list) {
      return list.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  @override
  Future<List<NotificationRecord>> fetchNotifications(
    String userId, {
    String? schoolId,
  }) async {
    // Return current state
    return _notifications.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Stream<List<NotificationRecord>> getRoleNotifications(
    String schoolId,
    String role,
  ) {
    return _controller.stream.map((list) {
      return list
          .where((n) => n.schoolId == schoolId && n.targetRole == role)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  @override
  Stream<List<NotificationRecord>> getClassNotifications(
    String schoolId,
    String classId,
  ) {
    return _controller.stream.map((list) {
      return list
          .where((n) => n.schoolId == schoolId && n.targetClassId == classId)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  @override
  Stream<List<NotificationRecord>> getClassesNotifications(
    String schoolId,
    List<String> classIds,
  ) {
    return _controller.stream.map((list) {
      return list
          .where((n) =>
              n.schoolId == schoolId &&
              n.targetClassId != null &&
              classIds.contains(n.targetClassId))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // Helper to get initial value without waiting for stream
  List<NotificationRecord> getNotificationsSync(String userId) {
    return _notifications.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> sendNotification(NotificationRecord notification) async {
    _notifications.add(notification);
    _emit();
  }

  @override
  Future<void> markAsRead(String notificationId, {String? schoolId}) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _emit();
    }
  }

  @override
  Future<void> deleteNotification(String notificationId, {String? schoolId}) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _emit();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  // Use Firestore implementation for production behavior
  return FirestoreNotificationRepository();
});

final userNotificationsProvider =
    StreamProvider.family<List<NotificationRecord>, String>((ref, userId) {
      final repo = ref.watch(notificationRepositoryProvider);
      return repo.getUserNotifications(userId);
    });
