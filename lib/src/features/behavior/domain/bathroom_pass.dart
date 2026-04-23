import 'package:cloud_firestore/cloud_firestore.dart';

enum BathroomPassStatus {
  approved, // Active (Green/Yellow)
  locked_red, // Locked (Red)
  completed, // Closed normally
  completed_late, // Closed but was late (if needed, or just completed)
}

class BathroomPass {
  final String id;
  final String studentId;
  final String teacherId;
  final String? schoolId;
  final String? classId;
  final DateTime startTime;
  final DateTime? endTime;
  final BathroomPassStatus status;
  final DateTime dueYellowAt;
  final DateTime redAt;
  final bool redNotified;
  final DateTime? lockedAt;
  final DateTime? closedAt;
  final String? closedByRole;
  final String? closedByUid;

  BathroomPass({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.schoolId,
    this.classId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.dueYellowAt,
    required this.redAt,
    this.redNotified = false,
    this.lockedAt,
    this.closedAt,
    this.closedByRole,
    this.closedByUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'teacherId': teacherId,
      'schoolId': schoolId,
      'classId': classId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.name,
      'dueYellowAt': Timestamp.fromDate(dueYellowAt),
      'redAt': Timestamp.fromDate(redAt),
      'redNotified': redNotified,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'closedByRole': closedByRole,
      'closedByUid': closedByUid,
    };
  }

  factory BathroomPass.fromMap(Map<String, dynamic> map, String id) {
    return BathroomPass(
      id: id,
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      schoolId: map['schoolId'],
      classId: map['classId'],
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      status: _parseStatus(map['status']),
      dueYellowAt: (map['dueYellowAt'] as Timestamp).toDate(),
      redAt: (map['redAt'] as Timestamp).toDate(),
      redNotified: map['redNotified'] ?? false,
      lockedAt: (map['lockedAt'] as Timestamp?)?.toDate(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
      closedByRole: map['closedByRole'],
      closedByUid: map['closedByUid'],
    );
  }

  static BathroomPassStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return BathroomPassStatus.approved;
      case 'locked_red':
        return BathroomPassStatus.locked_red;
      case 'completed':
        return BathroomPassStatus.completed;
      case 'completed_late':
        return BathroomPassStatus.completed_late;
      default:
        return BathroomPassStatus.approved;
    }
  }

  BathroomPass copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? schoolId,
    String? classId,
    DateTime? startTime,
    DateTime? endTime,
    BathroomPassStatus? status,
    DateTime? dueYellowAt,
    DateTime? redAt,
    bool? redNotified,
    DateTime? lockedAt,
    DateTime? closedAt,
    String? closedByRole,
    String? closedByUid,
  }) {
    return BathroomPass(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      dueYellowAt: dueYellowAt ?? this.dueYellowAt,
      redAt: redAt ?? this.redAt,
      redNotified: redNotified ?? this.redNotified,
      lockedAt: lockedAt ?? this.lockedAt,
      closedAt: closedAt ?? this.closedAt,
      closedByRole: closedByRole ?? this.closedByRole,
      closedByUid: closedByUid ?? this.closedByUid,
    );
  }
}
