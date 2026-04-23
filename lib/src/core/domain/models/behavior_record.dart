import 'package:cloud_firestore/cloud_firestore.dart';

enum BehaviorType {
  positive,
  negative,
  bathroom,
  escape,
  distinguished,
  permission,
  escalation, // New type for system actions (Alert, Summons, Referral)
}

enum BehaviorStatus { pending, approved, rejected, draft, warning, lockedRed }

class BehaviorRecord {
  final String id;
  final String studentId;
  final String teacherId;
  final String? teacherName;
  final String? classId; // Optional: Link behavior to a specific class context
  final BehaviorType type;
  final String description;
  final String? notes; // New field for extra notes (e.g. assignment name)
  final int points;
  final DateTime timestamp;
  final DateTime? bathroomExitTime;
  final DateTime? bathroomReturnTime;
  final String? returnTeacherId; // Teacher who recorded the return
  final BehaviorStatus status;
  final String? rejectionReason;
  final String? schoolId;
  final String? studentName;
  final String? className;

  // Bathroom Pass specific fields
  final DateTime? dueYellowAt;
  final DateTime? redAt;
  final bool redNotified;

  BehaviorRecord({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.teacherName,
    this.classId,
    this.schoolId,
    this.studentName,
    this.className,
    required this.type,
    required this.description,
    this.notes,
    required this.points,
    required this.timestamp,
    this.bathroomExitTime,
    this.bathroomReturnTime,
    this.returnTeacherId,
    this.status = BehaviorStatus
        .approved, // Default to approved for backward compatibility/auto-approve
    this.rejectionReason,
    this.dueYellowAt,
    this.redAt,
    this.redNotified = false,
  });

  BehaviorRecord copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? teacherName,
    String? classId,
    String? schoolId,
    String? studentName,
    String? className,
    BehaviorType? type,
    String? description,
    String? notes,
    int? points,
    DateTime? timestamp,
    DateTime? bathroomExitTime,
    DateTime? bathroomReturnTime,
    String? returnTeacherId,
    BehaviorStatus? status,
    String? rejectionReason,
    DateTime? dueYellowAt,
    DateTime? redAt,
    bool? redNotified,
  }) {
    return BehaviorRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      classId: classId ?? this.classId,
      schoolId: schoolId ?? this.schoolId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      type: type ?? this.type,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      points: points ?? this.points,
      timestamp: timestamp ?? this.timestamp,
      bathroomExitTime: bathroomExitTime ?? this.bathroomExitTime,
      bathroomReturnTime: bathroomReturnTime ?? this.bathroomReturnTime,
      returnTeacherId: returnTeacherId ?? this.returnTeacherId,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      dueYellowAt: dueYellowAt ?? this.dueYellowAt,
      redAt: redAt ?? this.redAt,
      redNotified: redNotified ?? this.redNotified,
    );
  }

  // Logic to calculate bathroom duration
  int? get bathroomDurationMinutes {
    if (bathroomExitTime != null && bathroomReturnTime != null) {
      return bathroomReturnTime!.difference(bathroomExitTime!).inMinutes;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'classId': classId,
      'schoolId': schoolId,
      'studentName': studentName,
      'className': className,
      'type': type.name,
      'description': description,
      'notes': notes,
      'points': points,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'bathroomExitTime': bathroomExitTime?.millisecondsSinceEpoch,
      'bathroomReturnTime': bathroomReturnTime?.millisecondsSinceEpoch,
      'returnTeacherId': returnTeacherId,
      'status': status.name,
      'rejectionReason': rejectionReason,
      'dueYellowAt': dueYellowAt?.millisecondsSinceEpoch,
      'redAt': redAt?.millisecondsSinceEpoch,
      'redNotified': redNotified,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  factory BehaviorRecord.fromMap(Map<String, dynamic> map) {
    return BehaviorRecord(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'],
      classId: map['classId'],
      schoolId: map['schoolId'],
      studentName: map['studentName'],
      className: map['className'],
      type: BehaviorType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BehaviorType.positive,
      ),
      description: map['description'] ?? '',
      notes: map['notes'],
      points: map['points']?.toInt() ?? 0,
      timestamp: _parseDate(map['timestamp']),
      bathroomExitTime: map['bathroomExitTime'] != null
          ? _parseDate(map['bathroomExitTime'])
          : null,
      bathroomReturnTime: map['bathroomReturnTime'] != null
          ? _parseDate(map['bathroomReturnTime'])
          : null,
      returnTeacherId: map['returnTeacherId'],
      status: BehaviorStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BehaviorStatus.approved,
      ),
      rejectionReason: map['rejectionReason'],
      dueYellowAt: map['dueYellowAt'] != null
          ? _parseDate(map['dueYellowAt'])
          : null,
      redAt: map['redAt'] != null ? _parseDate(map['redAt']) : null,
      redNotified: map['redNotified'] ?? false,
    );
  }
}
