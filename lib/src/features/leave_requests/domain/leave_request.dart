import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType {
  earlyDeparture,   // انصراف مبكر
  lateArrival,      // تأخر في الحضور
  fullDay,          // غياب يوم كامل
  duringPeriod,     // استئذان أثناء الدوام
  emergency,        // طارئ
}

enum LeaveStatus {
  pending,   // قيد الانتظار
  approved,  // مقبول
  rejected,  // مرفوض
}

extension LeaveTypeLabel on LeaveType {
  String get label {
    switch (this) {
      case LeaveType.earlyDeparture:  return 'انصراف مبكر';
      case LeaveType.lateArrival:     return 'تأخر في الحضور';
      case LeaveType.fullDay:         return 'غياب يوم كامل';
      case LeaveType.duringPeriod:    return 'استئذان أثناء الدوام';
      case LeaveType.emergency:       return 'حالة طارئة';
    }
  }

  String get icon {
    switch (this) {
      case LeaveType.earlyDeparture:  return '🚪';
      case LeaveType.lateArrival:     return '⏰';
      case LeaveType.fullDay:         return '📅';
      case LeaveType.duringPeriod:    return '🕐';
      case LeaveType.emergency:       return '🚨';
    }
  }
}

extension LeaveStatusLabel on LeaveStatus {
  String get label {
    switch (this) {
      case LeaveStatus.pending:   return 'قيد المراجعة';
      case LeaveStatus.approved:  return 'مقبول';
      case LeaveStatus.rejected:  return 'مرفوض';
    }
  }
}

class LeaveRequest {
  final String id;
  final String schoolId;
  final String teacherId;
  final String teacherName;
  final LeaveType type;
  final LeaveStatus status;
  final DateTime requestDate;      // تاريخ الطلب
  final DateTime leaveDate;        // تاريخ الاستئذان
  final String? fromTime;          // من الساعة
  final String? toTime;            // إلى الساعة
  final String reason;             // السبب
  final String? deputyNote;        // ملاحظة الوكيل
  final DateTime? reviewedAt;      // وقت المراجعة
  final String? reviewedBy;        // من راجع الطلب

  const LeaveRequest({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.teacherName,
    required this.type,
    required this.status,
    required this.requestDate,
    required this.leaveDate,
    this.fromTime,
    this.toTime,
    required this.reason,
    this.deputyNote,
    this.reviewedAt,
    this.reviewedBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'schoolId': schoolId,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'type': type.name,
    'status': status.name,
    'requestDate': Timestamp.fromDate(requestDate),
    'leaveDate': Timestamp.fromDate(leaveDate),
    'fromTime': fromTime,
    'toTime': toTime,
    'reason': reason,
    'deputyNote': deputyNote,
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    'reviewedBy': reviewedBy,
  };

  factory LeaveRequest.fromMap(Map<String, dynamic> map) => LeaveRequest(
    id: map['id'] ?? '',
    schoolId: map['schoolId'] ?? '',
    teacherId: map['teacherId'] ?? '',
    teacherName: map['teacherName'] ?? '',
    type: LeaveType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => LeaveType.duringPeriod,
    ),
    status: LeaveStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => LeaveStatus.pending,
    ),
    requestDate: (map['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    leaveDate: (map['leaveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    fromTime: map['fromTime'],
    toTime: map['toTime'],
    reason: map['reason'] ?? '',
    deputyNote: map['deputyNote'],
    reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    reviewedBy: map['reviewedBy'],
  );
}
