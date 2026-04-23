import 'package:cloud_firestore/cloud_firestore.dart';

enum SmsStatus { queued, sent, failed }

class SmsMessage {
  final String id;
  final String body;
  final String recipientId; // Parent ID
  final String phoneNumber; // Actual number to send to
  final SmsStatus status;
  final String? error;
  final DateTime createdAt;
  final String createdBy; // User ID
  final Map<String, dynamic>?
  metadata; // For tracking context (e.g. absence date)

  SmsMessage({
    required this.id,
    required this.body,
    required this.recipientId,
    required this.phoneNumber,
    required this.status,
    this.error,
    required this.createdAt,
    required this.createdBy,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'body': body,
      'recipientId': recipientId,
      'phoneNumber': phoneNumber,
      'status': status.name,
      'error': error,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  factory SmsMessage.fromMap(Map<String, dynamic> map, String docId) {
    return SmsMessage(
      id: docId,
      body: map['body'] ?? '',
      recipientId: map['recipientId'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      status: SmsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SmsStatus.queued,
      ),
      error: map['error'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      metadata: map['metadata'],
    );
  }
}
