enum AssignmentType {
  healthGuide, // مرشد صحي
  safetyOfficer, // مسؤول أمن وسلامة
  activityLeader, // مسؤول نشاط مدرسي
  classLeader, // رائد فصل
  deputy, // وكيل مدرسة (عام)
  stageDeputy, // وكيل مرحلة (جديد)
  committee, // لجنة (تكليف خاص)
}

extension AssignmentTypeExtension on AssignmentType {
  String get label {
    switch (this) {
      case AssignmentType.healthGuide:
        return 'المرشد الصحي';
      case AssignmentType.safetyOfficer:
        return 'مسؤول الأمن والسلامة';
      case AssignmentType.activityLeader:
        return 'مسؤول النشاط المدرسي';
      case AssignmentType.classLeader:
        return 'رائد الفصل';
      case AssignmentType.deputy:
        return 'وكيل المدرسة';
      case AssignmentType.stageDeputy:
        return 'وكيل مرحلة';
      case AssignmentType.committee:
        return 'لجنة خاصة';
    }
  }
}

class AdministrativeAssignment {
  final String id;
  final String teacherId;
  final String teacherName;
  final AssignmentType type;
  final String title; // Custom title if needed
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? notes;
  final String? classId; // For Class Leader
  final String? committeeName; // For Committee
  final String? stage; // For Deputy (Wakil) - Primary, Middle, High
  final String?
  gradeLevel; // For Deputy (Wakil) - Specific Grade (e.g., 3rd Intermediate)

  AdministrativeAssignment({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.type,
    required this.title,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.notes,
    this.classId,
    this.committeeName,
    this.stage,
    this.gradeLevel,
  });

  AdministrativeAssignment copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    AssignmentType? type,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? notes,
    String? classId,
    String? committeeName,
    String? stage,
    String? gradeLevel,
  }) {
    return AdministrativeAssignment(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      type: type ?? this.type,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      classId: classId ?? this.classId,
      committeeName: committeeName ?? this.committeeName,
      stage: stage ?? this.stage,
      gradeLevel: gradeLevel ?? this.gradeLevel,
    );
  }
}
