import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentAttendanceStatus { present, absent, late, excused }

class StudentAttendance {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String classId;
  final DateTime date;
  final StudentAttendanceStatus status;
  final DateTime? arrivalTime;
  final String recordedBy;
  final int? period; // Added for per-period attendance

  StudentAttendance({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.date,
    required this.status,
    this.arrivalTime,
    required this.recordedBy,
    this.period,
  });

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toMap() {
    final dateKey = _dateKey(date);
    final schoolDateKey = '${schoolId}_$dateKey';
    return {
      'id': id,
      'schoolId': schoolId,
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'date': Timestamp.fromDate(date),
      'dateKey': dateKey,
      'schoolDateKey': schoolDateKey,
      'status': status.name,
      'arrivalTime': arrivalTime == null ? null : Timestamp.fromDate(arrivalTime!),
      'recordedBy': recordedBy,
      'period': period,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  factory StudentAttendance.fromMap(Map<String, dynamic> map) {
    return StudentAttendance(
      id: map['id'] ?? '',
      schoolId: map['schoolId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      classId: map['classId'] ?? '',
      date: _parseDate(map['date']),
      status: StudentAttendanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => StudentAttendanceStatus.present,
      ),
      arrivalTime: map['arrivalTime'] != null
          ? _parseDate(map['arrivalTime'])
          : null,
      recordedBy: map['recordedBy'] ?? '',
      period: map['period'],
    );
  }
}
