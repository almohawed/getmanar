class ScheduleSlot {
  final String day; // 'Sunday', 'Monday', etc.
  final int period; // 1-7
  final String className; // '3/1', '2/2'
  final String subject; // 'Math', 'Science'
  final String teacherId; // Added for Class Schedule view

  ScheduleSlot({
    required this.day,
    required this.period,
    this.className = '',
    required this.subject,
    this.teacherId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'period': period,
      'className': className,
      'subject': subject,
      'teacherId': teacherId,
    };
  }

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) {
    return ScheduleSlot(
      day: map['day'] ?? '',
      period: map['period'] ?? 0,
      className: map['className'] ?? '',
      subject: map['subject'] ?? '',
      teacherId: map['teacherId'] ?? '',
    );
  }

  ScheduleSlot copyWith({
    String? day,
    int? period,
    String? className,
    String? subject,
    String? teacherId,
  }) {
    return ScheduleSlot(
      day: day ?? this.day,
      period: period ?? this.period,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      teacherId: teacherId ?? this.teacherId,
    );
  }
}
