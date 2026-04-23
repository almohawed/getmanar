enum ViolationLevel {
  firstDegree, // الدرجة الأولى
  secondDegree, // الدرجة الثانية
  thirdDegree, // الدرجة الثالثة
  fourthDegree, // الدرجة الرابعة
  fifthDegree, // الدرجة الخامسة
}

enum ViolationStatus {
  pending, // بانتظار الاعتماد
  approved, // معتمد
  rejected, // مرفوض
  archived, // مؤرشف
}

class BehavioralViolation {
  final String id;
  final String studentId;
  final String studentName; // Cached for ease
  final String recorderId; // Deputy/Teacher ID
  final String recorderName;
  final String schoolId;
  final String violationTitle; // e.g. "إتلاف ممتلكات"
  final String description;
  final ViolationLevel level;
  final DateTime date;
  final String? period; // e.g. "الحصة الثالثة"
  final String? notes;
  final ViolationStatus status;
  final String? rejectionReason;
  final List<String> attachments; // URLs to photos/evidence
  final String? actionTaken; // الإجراء المتخذ

  BehavioralViolation({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.recorderId,
    required this.recorderName,
    required this.schoolId,
    required this.violationTitle,
    required this.description,
    required this.level,
    required this.date,
    this.period,
    this.notes,
    this.status = ViolationStatus.pending,
    this.rejectionReason,
    this.attachments = const [],
    this.actionTaken,
  });

  BehavioralViolation copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? recorderId,
    String? recorderName,
    String? schoolId,
    String? violationTitle,
    String? description,
    ViolationLevel? level,
    DateTime? date,
    String? period,
    String? notes,
    ViolationStatus? status,
    String? rejectionReason,
    List<String>? attachments,
    String? actionTaken,
  }) {
    return BehavioralViolation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      recorderId: recorderId ?? this.recorderId,
      recorderName: recorderName ?? this.recorderName,
      schoolId: schoolId ?? this.schoolId,
      violationTitle: violationTitle ?? this.violationTitle,
      description: description ?? this.description,
      level: level ?? this.level,
      date: date ?? this.date,
      period: period ?? this.period,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      attachments: attachments ?? this.attachments,
      actionTaken: actionTaken ?? this.actionTaken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'recorderId': recorderId,
      'recorderName': recorderName,
      'schoolId': schoolId,
      'violationTitle': violationTitle,
      'description': description,
      'level': level.name,
      'date': date.toIso8601String(),
      'period': period,
      'notes': notes,
      'status': status.name,
      'rejectionReason': rejectionReason,
      'attachments': attachments,
      'actionTaken': actionTaken,
    };
  }

  factory BehavioralViolation.fromMap(Map<String, dynamic> map) {
    return BehavioralViolation(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      recorderId: map['recorderId'] ?? '',
      recorderName: map['recorderName'] ?? '',
      schoolId: map['schoolId'] ?? '',
      violationTitle: map['violationTitle'] ?? '',
      description: map['description'] ?? '',
      level: ViolationLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => ViolationLevel.firstDegree,
      ),
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      period: map['period'],
      notes: map['notes'],
      status: ViolationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ViolationStatus.pending,
      ),
      rejectionReason: map['rejectionReason'],
      attachments: List<String>.from(map['attachments'] ?? []),
      actionTaken: map['actionTaken'],
    );
  }
}
