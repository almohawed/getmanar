class ScheduleRequestV2 {
  final String schoolId;
  final String schoolType;
  final List<TeacherV2> teachers;
  final List<ClassV2> classes;
  final List<SubjectV2> subjects;
  final List<AssignmentV2> assignments;
  final List<ManualConstraintV2> manualConstraints;
  final int daysPerWeek;
  final int periodsPerDay;
  final Map<String, double> softConstraintWeights;

  ScheduleRequestV2({
    required this.schoolId,
    required this.schoolType,
    required this.teachers,
    required this.classes,
    required this.subjects,
    required this.assignments,
    this.manualConstraints = const [],
    this.daysPerWeek = 5,
    this.periodsPerDay = 7,
    Map<String, double>? softConstraintWeights,
  }) : softConstraintWeights = softConstraintWeights ?? {
    'teacher_gaps': 10.0,
    'class_gaps': 5.0,
    'daily_balance': 8.0,
    'avoid_heavy_last': 7.0,
    'teacher_daily_balance': 6.0,
    'subject_distribution': 9.0,
  };

  Map<String, dynamic> toJson() => {
    'schoolId': schoolId,
    'schoolType': schoolType,
    'teachers': teachers.map((t) => t.toJson()).toList(),
    'classes': classes.map((c) => c.toJson()).toList(),
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'manualConstraints': manualConstraints.map((m) => m.toJson()).toList(),
    'daysPerWeek': daysPerWeek,
    'periodsPerDay': periodsPerDay,
    'softConstraintWeights': softConstraintWeights,
  };
}

class TeacherV2 {
  final String id;
  final String name;
  final List<String> subjects;
  final List<String> assignedClassIds;
  final int maxWeeklyLoad;
  final List<Map<String, dynamic>> unavailableSlots;
  final Map<String, dynamic> preferences;
  final bool isClassTeacher;

  TeacherV2({
    required this.id,
    required this.name,
    required this.subjects,
    required this.assignedClassIds,
    this.maxWeeklyLoad = 24,
    this.unavailableSlots = const [],
    this.preferences = const {},
    this.isClassTeacher = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subjects': subjects,
    'assignedClassIds': assignedClassIds,
    'maxWeeklyLoad': maxWeeklyLoad,
    'unavailableSlots': unavailableSlots,
    'preferences': preferences,
    'isClassTeacher': isClassTeacher,
  };
}

class ClassV2 {
  final String id;
  final String name;
  final int gradeLevel;
  final String schoolType;
  final String? track;
  final String? classTeacherId;

  ClassV2({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.schoolType,
    this.track,
    this.classTeacherId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gradeLevel': gradeLevel,
    'schoolType': schoolType,
    if (track != null) 'track': track,
    if (classTeacherId != null) 'classTeacherId': classTeacherId,
  };
}

class SubjectV2 {
  final String id;
  final String name;
  final String normalizedName;
  final int weeklyHours;
  final int maxPerDay;
  final bool canBeConsecutive;
  final bool avoidFirstPeriod;
  final bool avoidLastPeriod;
  final bool isHeavy;

  SubjectV2({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.weeklyHours,
    this.maxPerDay = 1,
    this.canBeConsecutive = false,
    this.avoidFirstPeriod = false,
    this.avoidLastPeriod = false,
    this.isHeavy = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'weeklyHours': weeklyHours,
    'maxPerDay': maxPerDay,
    'canBeConsecutive': canBeConsecutive,
    'avoidFirstPeriod': avoidFirstPeriod,
    'avoidLastPeriod': avoidLastPeriod,
    'isHeavy': isHeavy,
  };
}

class AssignmentV2 {
  final String teacherId;
  final String classId;
  final String subjectId;
  final int weeklyHours;

  AssignmentV2({
    required this.teacherId,
    required this.classId,
    required this.subjectId,
    required this.weeklyHours,
  });

  Map<String, dynamic> toJson() => {
    'teacherId': teacherId,
    'classId': classId,
    'subjectId': subjectId,
    'weeklyHours': weeklyHours,
  };
}

class ManualConstraintV2 {
  final String id;
  final String type;
  final String? teacherId;
  final String? subjectId;
  final String? classId;
  final String? day;
  final int? period;
  final String description;

  ManualConstraintV2({
    required this.id,
    required this.type,
    this.teacherId,
    this.subjectId,
    this.classId,
    this.day,
    this.period,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    if (teacherId != null) 'teacherId': teacherId,
    if (subjectId != null) 'subjectId': subjectId,
    if (classId != null) 'classId': classId,
    if (day != null) 'day': day,
    if (period != null) 'period': period,
    'description': description,
  };
}

class PrecheckReportV2 {
  final bool canGenerate;
  final int totalDemand;
  final int totalCapacity;
  final List<PrecheckIssueV2> issues;

  PrecheckReportV2({
    required this.canGenerate,
    required this.totalDemand,
    required this.totalCapacity,
    required this.issues,
  });

  factory PrecheckReportV2.fromJson(Map<String, dynamic> json) => PrecheckReportV2(
    canGenerate: json['canGenerate'],
    totalDemand: json['totalDemand'],
    totalCapacity: json['totalCapacity'],
    issues: (json['issues'] as List).map((i) => PrecheckIssueV2.fromJson(i)).toList(),
  );
}

class PrecheckIssueV2 {
  final String severity;
  final String category;
  final String message;
  final Map<String, dynamic> details;

  PrecheckIssueV2({
    required this.severity,
    required this.category,
    required this.message,
    required this.details,
  });

  factory PrecheckIssueV2.fromJson(Map<String, dynamic> json) => PrecheckIssueV2(
    severity: json['severity'],
    category: json['category'],
    message: json['message'],
    details: json['details'] ?? {},
  );
}

class ScheduleResponseV2 {
  final bool success;
  final String message;
  final String? scheduleId;
  final Map<String, dynamic> solverStats;
  final List<dynamic> unmetSoftConstraints;
  final PrecheckReportV2? precheckReport;

  ScheduleResponseV2({
    required this.success,
    required this.message,
    this.scheduleId,
    required this.solverStats,
    this.unmetSoftConstraints = const [],
    this.precheckReport,
  });

  factory ScheduleResponseV2.fromJson(Map<String, dynamic> json) => ScheduleResponseV2(
    success: json['success'],
    message: json['message'],
    scheduleId: json['scheduleId'],
    solverStats: json['solverStats'],
    unmetSoftConstraints: json['unmetSoftConstraints'] ?? [],
    precheckReport: json['precheckReport'] != null 
      ? PrecheckReportV2.fromJson(json['precheckReport']) 
      : null,
  );
}
