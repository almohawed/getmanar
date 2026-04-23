import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/notification_record.dart';
import '../domain/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference _getCollection(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications');
  }

  @override
  Stream<List<NotificationRecord>> getUserNotifications(
    String userId, {
    String? schoolId,
  }) {
    if (schoolId == null || schoolId.isEmpty) {
      // Cannot query without schoolId due to permission/scoping structure
      return Stream.value([]);
    }

    return _getCollection(schoolId)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
        });
  }

  @override
  Stream<List<NotificationRecord>> getRoleNotifications(
    String schoolId,
    String role,
  ) {
    return _getCollection(schoolId)
        .where('targetRole', isEqualTo: role)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
        });
  }

  @override
  Stream<List<NotificationRecord>> getClassNotifications(
    String schoolId,
    String classId,
  ) {
    return _getCollection(schoolId)
        .where('targetClassId', isEqualTo: classId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
        });
  }

  @override
  Stream<List<NotificationRecord>> getClassesNotifications(
    String schoolId,
    List<String> classIds,
  ) {
    if (classIds.isEmpty) return Stream.value([]);
    // Firestore limit is 10 for 'whereIn'. If more, we might need multiple queries.
    // For now, take top 10 or assume it's enough.
    final chunks = classIds.take(10).toList();

    return _getCollection(
      schoolId,
    ).where('targetClassId', whereIn: chunks).snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                NotificationRecord.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    });
  }

  @override
  Future<List<NotificationRecord>> fetchNotifications(
    String userId, {
    String? schoolId,
  }) async {
    if (schoolId == null || schoolId.isEmpty) {
      return [];
    }

    final snapshot = await _getCollection(schoolId)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              NotificationRecord.fromMap(doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> sendNotification(NotificationRecord notification) async {
    if (notification.schoolId == null) {
      throw Exception('Cannot send notification without schoolId');
    }
    final callable = _functions.httpsCallable('sendSchoolNotification');
    await callable.call({
      'schoolId': notification.schoolId!,
      'title': notification.title,
      'body': notification.body,
      'targetUserId': notification.userId,
      'targetRole': notification.targetRole,
      'targetClassId': notification.targetClassId,
      'route': notification.route,
      'data': notification.data,
    });
  }

  @override
  Future<void> markAsRead(String notificationId, {String? schoolId}) async {
    if (schoolId == null) {
      throw Exception('Cannot mark as read without schoolId');
    }
    await _getCollection(schoolId).doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> deleteNotification(
    String notificationId, {
    String? schoolId,
  }) async {
    if (schoolId == null) {
      throw Exception('Cannot delete notification without schoolId');
    }
    await _getCollection(schoolId).doc(notificationId).delete();
  }
}
