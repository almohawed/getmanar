enum AttendanceStatus { present, absent, late, excused }
enum AttendanceMethod { qr, manual, adminOverride }

class AttendanceRecord {
  final String id;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkInTime;
  final AttendanceMethod method;
  final String? excuseNote;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.checkInTime,
    required this.method,
    this.excuseNote,
  });
}
