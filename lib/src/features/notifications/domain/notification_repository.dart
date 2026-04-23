import '../domain/notification_record.dart';

abstract class NotificationRepository {
  Stream<List<NotificationRecord>> getUserNotifications(
    String userId, {
    String? schoolId,
  });
  Stream<List<NotificationRecord>> getRoleNotifications(
    String schoolId,
    String role,
  );
  Stream<List<NotificationRecord>> getClassNotifications(
    String schoolId,
    String classId,
  );
  Stream<List<NotificationRecord>> getClassesNotifications(
    String schoolId,
    List<String> classIds,
  );
  Future<List<NotificationRecord>> fetchNotifications(
    String userId, {
    String? schoolId,
  });
  Future<void> sendNotification(NotificationRecord notification);
  Future<void> markAsRead(String notificationId, {String? schoolId});
  Future<void> deleteNotification(String notificationId, {String? schoolId});
}
