import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  financial, // مالية
  administrative, // إدارية
  student, // طلابية
  circular, // تعميم
  complaint, // شكوى
  other, // أخرى
}

enum TransactionStatus {
  awaitingDirectorRouting, // بانتظار توجيه المدير
  routed, // تم التوجيه - قيد التنفيذ
  needsFollowup, // تحتاج متابعة
  delayed, // متأخرة
  closed, // مغلقة
}

enum TransactionPriority {
  critical, // حرجة
  high, // عالية
  medium, // متوسطة
  low, // منخفضة
}

class Transaction {
  final String id;
  final String schoolId;
  final String number; // رقم المعاملة
  final String senderEntity; // الجهة المرسلة
  final String subject; // الموضوع
  final String? description; // الوصف الكامل
  final TransactionType type;
  final TransactionStatus status;
  final TransactionPriority priority;
  final DateTime receivedAt; // تاريخ الاستلام
  final DateTime? routedAt; // تاريخ التوجيه
  final DateTime? closedAt; // تاريخ الإغلاق
  final String? routedToUserId; // الموجه إليه
  final String? routedToUserName;
  final String? routedByUserId; // من وجهها
  final String? routedByUserName;
  final List<String> attachments; // المرفقات
  final List<TransactionLog> logs; // سجل الحركة
  final List<String> viewedBy; // من اطلع عليها
  final bool isSensitive; // حساسة (عاجلة، زيارة إشرافية، مالية، شكوى)
  final String? notes; // ملاحظات
  final DateTime? dueDate; // تاريخ الاستحقاق
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.schoolId,
    required this.number,
    required this.senderEntity,
    required this.subject,
    this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.receivedAt,
    this.routedAt,
    this.closedAt,
    this.routedToUserId,
    this.routedToUserName,
    this.routedByUserId,
    this.routedByUserName,
    this.attachments = const [],
    this.logs = const [],
    this.viewedBy = const [],
    this.isSensitive = false,
    this.notes,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  // حساب مدة البقاء في الحالة الحالية
  Duration get durationInCurrentStatus {
    final now = DateTime.now();
    switch (status) {
      case TransactionStatus.awaitingDirectorRouting:
        return now.difference(receivedAt);
      case TransactionStatus.routed:
        return now.difference(routedAt ?? receivedAt);
      case TransactionStatus.needsFollowup:
        return now.difference(logs.lastWhere((l) => l.action == 'needs_followup', orElse: () => logs.last).timestamp);
      case TransactionStatus.delayed:
        return now.difference(logs.lastWhere((l) => l.action == 'marked_delayed', orElse: () => logs.last).timestamp);
      case TransactionStatus.closed:
        return closedAt != null ? closedAt!.difference(receivedAt) : Duration.zero;
    }
  }

  // هل متأخرة؟
  bool get isDelayed {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && status != TransactionStatus.closed;
  }

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    return Transaction(
      id: id,
      schoolId: map['schoolId'] ?? '',
      number: map['number'] ?? '',
      senderEntity: map['senderEntity'] ?? '',
      subject: map['subject'] ?? '',
      description: map['description'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.other,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.awaitingDirectorRouting,
      ),
      priority: TransactionPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TransactionPriority.medium,
      ),
      receivedAt: (map['receivedAt'] as Timestamp).toDate(),
      routedAt: map['routedAt'] != null ? (map['routedAt'] as Timestamp).toDate() : null,
      closedAt: map['closedAt'] != null ? (map['closedAt'] as Timestamp).toDate() : null,
      routedToUserId: map['routedToUserId'],
      routedToUserName: map['routedToUserName'],
      routedByUserId: map['routedByUserId'],
      routedByUserName: map['routedByUserName'],
      attachments: List<String>.from(map['attachments'] ?? []),
      logs: (map['logs'] as List<dynamic>?)?.map((e) => TransactionLog.fromMap(e)).toList() ?? [],
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
      isSensitive: map['isSensitive'] ?? false,
      notes: map['notes'],
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'number': number,
      'senderEntity': senderEntity,
      'subject': subject,
      'description': description,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'routedAt': routedAt != null ? Timestamp.fromDate(routedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'routedToUserId': routedToUserId,
      'routedToUserName': routedToUserName,
      'routedByUserId': routedByUserId,
      'routedByUserName': routedByUserName,
      'attachments': attachments,
      'logs': logs.map((e) => e.toMap()).toList(),
      'viewedBy': viewedBy,
      'isSensitive': isSensitive,
      'notes': notes,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class TransactionLog {
  final String action; // route, close, escalate, request_clarification, etc.
  final String userId;
  final String userName;
  final String? notes;
  final DateTime timestamp;

  TransactionLog({
    required this.action,
    required this.userId,
    required this.userName,
    this.notes,
    required this.timestamp,
  });

  factory TransactionLog.fromMap(Map<String, dynamic> map) {
    return TransactionLog(
      action: map['action'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      notes: map['notes'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'userId': userId,
      'userName': userName,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

// إحصائيات الوارد
class InboxStatistics {
  final int totalToday;
  final int unrouted;
  final int delayed;
  final double averageProcessingTime; // بالساعات
  final int critical;
  final String flowStatus; // مستقر / ضغط متوسط / ضغط مرتفع

  InboxStatistics({
    required this.totalToday,
    required this.unrouted,
    required this.delayed,
    required this.averageProcessingTime,
    required this.critical,
    required this.flowStatus,
  });
}

// تحليل إداري
class AdministrativeAnalysis {
  final String topSenderEntity;
  final int topSenderCount;
  final TransactionType mostDelayedType;
  final List<String> peakDays;
  final Map<String, int> delayReasons; // سبب التأخير
  final String summary; // ملخص مكتوب

  AdministrativeAnalysis({
    required this.topSenderEntity,
    required this.topSenderCount,
    required this.mostDelayedType,
    required this.peakDays,
    required this.delayReasons,
    required this.summary,
  });
}

// خريطة الضغط الإداري
class WorkloadMap {
  final Map<String, int> departmentLoad; // الإدارات الأكثر ضغطاً
  final String mostReceivedStaff;
  final int mostReceivedCount;
  final String mostDelayedStaff;
  final int mostDelayedCount;

  WorkloadMap({
    required this.departmentLoad,
    required this.mostReceivedStaff,
    required this.mostReceivedCount,
    required this.mostDelayedStaff,
    required this.mostDelayedCount,
  });
}

// مؤشر سلامة الدورة الإدارية
class CycleHealthIndicator {
  final double routingSpeed; // 0-100
  final double closingSpeed; // 0-100
  final double delayRate; // 0-100
  final double accumulationRate; // 0-100
  final double overallScore; // 0-100
  final String rating; // ممتاز / جيد / يحتاج تدخل

  CycleHealthIndicator({
    required this.routingSpeed,
    required this.closingSpeed,
    required this.delayRate,
    required this.accumulationRate,
    required this.overallScore,
    required this.rating,
  });

  String get ratingArabic {
    if (overallScore >= 85) return 'ممتاز';
    if (overallScore >= 70) return 'جيد';
    return 'يحتاج تدخل';
  }
}
