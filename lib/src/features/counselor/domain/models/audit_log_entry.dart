import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String action; // create, update, delete, view, print, export
  final String performedBy; // userId
  final String performedByRole; // role
  final String schoolId;
  final String targetType; // session, plan, student
  final String targetId;
  final DateTime timestamp;
  final String? deviceInfo; // ip/deviceId
  final String? clientVersion;
  final Map<String, dynamic>? diff; // before/after without sensitive data
  final Map<String, dynamic>? details; // extra context

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performedByRole,
    required this.schoolId,
    required this.targetType,
    required this.targetId,
    required this.timestamp,
    this.deviceInfo,
    this.clientVersion,
    this.diff,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'performedBy': performedBy,
      'performedByRole': performedByRole,
      'schoolId': schoolId,
      'targetType': targetType,
      'targetId': targetId,
      'timestamp': Timestamp.fromDate(timestamp),
      'deviceInfo': deviceInfo,
      'clientVersion': clientVersion,
      'diff': diff,
      'details': details,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map, String id) {
    return AuditLogEntry(
      id: id,
      action: map['action'] ?? '',
      performedBy: map['performedBy'] ?? '',
      performedByRole: map['performedByRole'] ?? '',
      schoolId: map['schoolId'] ?? '',
      targetType: map['targetType'] ?? '',
      targetId: map['targetId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      deviceInfo: map['deviceInfo'],
      clientVersion: map['clientVersion'],
      diff: map['diff'],
      details: map['details'],
    );
  }
}
