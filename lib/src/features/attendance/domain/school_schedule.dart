import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { pending, present, late, absent }

class SchoolSchedule {
  final String id;
  final String schoolId;
  final String day;
  final int period;
  final String teacherId;
  final String subject;
  final String className;
  final AttendanceStatus attendanceStatus;
  final DateTime? attendanceTimestamp;
  final String? recordedBy;

  SchoolSchedule({
    required this.id,
    required this.schoolId,
    required this.day,
    required this.period,
    required this.teacherId,
    required this.subject,
    required this.className,
    this.attendanceStatus = AttendanceStatus.pending,
    this.attendanceTimestamp,
    this.recordedBy,
  });

  factory SchoolSchedule.fromMap(String id, Map<String, dynamic> map) {
    return SchoolSchedule(
      id: id,
      schoolId: map['schoolId'] ?? '',
      day: map['day'] ?? '',
      period: map['period'] ?? 0,
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      className: map['className'] ?? '',
      attendanceStatus: _parseStatus(map['attendanceStatus']),
      attendanceTimestamp: (map['attendanceTimestamp'] as Timestamp?)?.toDate(),
      recordedBy: map['recordedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'day': day,
      'period': period,
      'teacherId': teacherId,
      'subject': subject,
      'className': className,
      'attendanceStatus': attendanceStatus.name,
      'attendanceTimestamp': attendanceTimestamp != null
          ? Timestamp.fromDate(attendanceTimestamp!)
          : null,
      'recordedBy': recordedBy,
    };
  }

  static AttendanceStatus _parseStatus(String? status) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => AttendanceStatus.pending,
    );
  }
}
