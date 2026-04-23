enum AttendanceStatus { present, absent, late }

class TeacherAttendance {
  final String id;
  final String teacherId;
  final String teacherName;
  final String day;
  final int period;
  final AttendanceStatus status;
  final DateTime date;

  TeacherAttendance({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.day,
    required this.period,
    required this.status,
    required this.date,
  });

  TeacherAttendance copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? day,
    int? period,
    AttendanceStatus? status,
    DateTime? date,
  }) {
    return TeacherAttendance(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      day: day ?? this.day,
      period: period ?? this.period,
      status: status ?? this.status,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'day': day,
      'period': period,
      'status': status.index,
      'date': date.toIso8601String(),
    };
  }

  factory TeacherAttendance.fromMap(Map<String, dynamic> map) {
    return TeacherAttendance(
      id: map['id'],
      teacherId: map['teacherId'],
      teacherName: map['teacherName'],
      day: map['day'],
      period: map['period'],
      status: AttendanceStatus.values[map['status']],
      date: DateTime.parse(map['date']),
    );
  }
}
