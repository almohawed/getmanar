enum SessionStatus { open, collecting, closed, generated, published }

class SchedulingSession {
  final String id;
  final String schoolId;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? deadline; // For teacher input
  final String? generatedScheduleId;

  SchedulingSession({
    required this.id,
    required this.schoolId,
    required this.status,
    required this.createdAt,
    this.deadline,
    this.generatedScheduleId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'generatedScheduleId': generatedScheduleId,
    };
  }

  factory SchedulingSession.fromMap(Map<String, dynamic> map) {
    return SchedulingSession(
      id: map['id'],
      schoolId: map['schoolId'],
      status: SessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SessionStatus.open,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      deadline:
          map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      generatedScheduleId: map['generatedScheduleId'],
    );
  }

  SchedulingSession copyWith({
    String? id,
    String? schoolId,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? deadline,
    String? generatedScheduleId,
  }) {
    return SchedulingSession(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      generatedScheduleId: generatedScheduleId ?? this.generatedScheduleId,
    );
  }
}
