import 'package:cloud_firestore/cloud_firestore.dart';
import 'school_schedule.dart';

class TeacherAttendanceLog {
  final String id;
  final String teacherId;
  final String schoolId;
  final String day;
  final int period;
  final AttendanceStatus status;
  final AttendanceStatus? previousStatus; // Before state
  final String source; // 'schedule_screen' | 'attendance_screen'
  final DateTime createdAt;
  final String recordedBy;
  final String userRole; // Role of the person recording
  final String? reason; // Optional reason for modification

  TeacherAttendanceLog({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.day,
    required this.period,
    required this.status,
    this.previousStatus,
    required this.source,
    required this.createdAt,
    required this.recordedBy,
    required this.userRole,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'schoolId': schoolId,
      'day': day,
      'period': period,
      'status': status.name,
      'previousStatus': previousStatus?.name,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'recordedBy': recordedBy,
      'userRole': userRole,
      'reason': reason,
    };
  }
}
