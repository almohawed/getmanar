import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus {
  waitingDirection,    // بانتظار توجيه المدير
  inProgress,          // قيد التنفيذ
  needsFollowUp,       // تحتاج متابعة
  delayed,             // متأخرة
  closed,              // مغلقة
}

enum TransactionType {
  circular,      // تعميم
  administrative, // إداري
  student,       // طلاب
  financial,     // مالي
  complaint,     // شكوى
}

enum TransactionPriority {
  normal,   // عادي
  important, // مهم
  urgent,    // عاجل
}

class IncomingTransaction {
  final String id;
  final String transactionNumber;
  final String senderEntity;
  final String subject;
  final DateTime receivedDate;
  final TransactionStatus status;
  final TransactionType type;
  final TransactionPriority priority;
  final int daysInCurrentStatus;
  final bool isSensitive;
  final List<String> attachments;
  final List<TransactionLog> logs;
  final String? assignedTo;
  final String? notes;

  IncomingTransaction({
    required this.id,
    required this.transactionNumber,
    required this.senderEntity,
    required this.subject,
    required this.receivedDate,
    required this.status,
    required this.type,
    required this.priority,
    required this.daysInCurrentStatus,
    this.isSensitive = false,
    this.attachments = const [],
    this.logs = const [],
    this.assignedTo,
    this.notes,
  });

  factory IncomingTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncomingTransaction(
      id: doc.id,
      transactionNumber: data['transactionNumber'] ?? '',
      senderEntity: data['senderEntity'] ?? '',
      subject: data['subject'] ?? '',
      receivedDate: (data['receivedDate'] as Timestamp).toDate(),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TransactionStatus.waitingDirection,
      ),
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.administrative,
      ),
      priority: TransactionPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TransactionPriority.normal,
      ),
      daysInCurrentStatus: data['daysInCurrentStatus'] ?? 0,
      isSensitive: data['isSensitive'] ?? false,
      attachments: List<String>.from(data['attachments'] ?? []),
      logs: (data['logs'] as List<dynamic>?)
              ?.map((e) => TransactionLog.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      assignedTo: data['assignedTo'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'transactionNumber': transactionNumber,
      'senderEntity': senderEntity,
      'subject': subject,
      'receivedDate': Timestamp.fromDate(receivedDate),
      'status': status.name,
      'type': type.name,
      'priority': priority.name,
      'daysInCurrentStatus': daysInCurrentStatus,
      'isSensitive': isSensitive,
      'attachments': attachments,
      'logs': logs.map((e) => e.toMap()).toList(),
      'assignedTo': assignedTo,
      'notes': notes,
    };
  }
}

class TransactionLog {
  final String action;
  final DateTime timestamp;
  final String performedBy;
  final String? notes;

  TransactionLog({
    required this.action,
    required this.timestamp,
    required this.performedBy,
    this.notes,
  });

  factory TransactionLog.fromMap(Map<String, dynamic> map) {
    return TransactionLog(
      action: map['action'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      performedBy: map['performedBy'] ?? '',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
      'performedBy': performedBy,
      'notes': notes,
    };
  }
}
