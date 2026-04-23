import 'package:cloud_firestore/cloud_firestore.dart';

enum OutgoingTransactionStatus {
  draft, // مسودة
  reviewing, // قيد المراجعة
  awaitingApproval, // بانتظار الاعتماد
  sent, // تم الإرسال
  archived, // مؤرشف
}

enum OutgoingTransactionType {
  report, // تقرير
  letter, // خطاب
  circular, // تعميم
  financial, // مالي
  other, // أخرى
}

enum OutgoingTransactionPriority { normal, high, urgent }

class OutgoingTransaction {
  final String id;
  final String schoolId;
  final String number;
  final String recipientEntity;
  final String subject;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentAt;
  final OutgoingTransactionStatus status;
  final OutgoingTransactionType type;
  final OutgoingTransactionPriority priority;
  final String content;
  final List<String> attachments;
  final String creatorId;
  final String creatorName;
  final List<OutgoingLog> logs;

  OutgoingTransaction({
    required this.id,
    required this.schoolId,
    required this.number,
    required this.recipientEntity,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
    required this.status,
    required this.type,
    required this.priority,
    required this.content,
    required this.attachments,
    required this.creatorId,
    required this.creatorName,
    required this.logs,
  });

  factory OutgoingTransaction.fromMap(Map<String, dynamic> map, String id) {
    return OutgoingTransaction(
      id: id,
      schoolId: map['schoolId'] ?? '',
      number: map['number'] ?? '',
      recipientEntity: map['recipientEntity'] ?? '',
      subject: map['subject'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : null,
      status: OutgoingTransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OutgoingTransactionStatus.draft,
      ),
      type: OutgoingTransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OutgoingTransactionType.other,
      ),
      priority: OutgoingTransactionPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => OutgoingTransactionPriority.normal,
      ),
      content: map['content'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      logs: (map['logs'] as List? ?? [])
          .map((l) => OutgoingLog.fromMap(l))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'number': number,
      'recipientEntity': recipientEntity,
      'subject': subject,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'status': status.name,
      'type': type.name,
      'priority': priority.name,
      'content': content,
      'attachments': attachments,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'logs': logs.map((l) => l.toMap()).toList(),
    };
  }

  OutgoingTransaction copyWith({
    String? id,
    String? schoolId,
    String? number,
    String? recipientEntity,
    String? subject,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
    OutgoingTransactionStatus? status,
    OutgoingTransactionType? type,
    OutgoingTransactionPriority? priority,
    String? content,
    List<String>? attachments,
    String? creatorId,
    String? creatorName,
    List<OutgoingLog>? logs,
  }) {
    return OutgoingTransaction(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      number: number ?? this.number,
      recipientEntity: recipientEntity ?? this.recipientEntity,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      logs: logs ?? this.logs,
    );
  }
}

class OutgoingLog {
  final String action;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String? notes;

  OutgoingLog({
    required this.action,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.notes,
  });

  factory OutgoingLog.fromMap(Map<String, dynamic> map) {
    return OutgoingLog(
      action: map['action'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'userId': userId,
      'userName': userName,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
    };
  }
}

class OutboxStatistics {
  final int totalToday;
  final int inPreparation;
  final int awaitingApproval;
  final int sent;
  final double averageProcessingTime; // باليوم

  OutboxStatistics({
    required this.totalToday,
    required this.inPreparation,
    required this.awaitingApproval,
    required this.sent,
    required this.averageProcessingTime,
  });
}
