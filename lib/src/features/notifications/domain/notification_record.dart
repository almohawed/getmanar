import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRecord {
  final String id;
  final String? userId; // The recipient
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? route;
  final Map<String, dynamic>? data;
  final String? schoolId;
  final String? targetRole; // e.g. 'deputy', 'parent'
  final String? targetClassId; // For class-specific notifications

  NotificationRecord({
    required this.id,
    this.userId, // Nullable if targeting a role
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.route,
    this.data,
    this.schoolId,
    this.targetRole,
    this.targetClassId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'route': route,
      'data': data,
      'schoolId': schoolId,
      'targetRole': targetRole,
      'targetClassId': targetClassId,
    };
  }

  factory NotificationRecord.fromMap(Map<String, dynamic> map) {
    DateTime parsedTimestamp = DateTime.now();
    final rawTs = map['timestamp'];
    if (rawTs is String) {
      parsedTimestamp = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is Timestamp) {
      parsedTimestamp = rawTs.toDate();
    }

    return NotificationRecord(
      id: map['id'] ?? '',
      userId: map['userId'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: parsedTimestamp,
      isRead: map['isRead'] ?? false,
      route: map['route'],
      data: map['data'],
      schoolId: map['schoolId'],
      targetRole: map['targetRole'],
      targetClassId: map['targetClassId'],
    );
  }

  NotificationRecord copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? route,
    Map<String, dynamic>? data,
    String? schoolId,
    String? targetRole,
    String? targetClassId,
  }) {
    return NotificationRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      route: route ?? this.route,
      data: data ?? this.data,
      schoolId: schoolId ?? this.schoolId,
      targetRole: targetRole ?? this.targetRole,
      targetClassId: targetClassId ?? this.targetClassId,
    );
  }
}
