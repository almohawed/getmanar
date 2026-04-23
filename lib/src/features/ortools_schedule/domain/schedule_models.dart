class ScheduleRequest {
  final String schoolId;
  final String schoolType;
  final List<TeacherModel> teachers;
  final List<ClassModel> classes;
  final Map<String, List<SubjectRequirement>> subjectRequirements;
  final int daysPerWeek;
  final int periodsPerDay;

  ScheduleRequest({
    required this.schoolId,
    required this.schoolType,
    required this.teachers,
    required this.classes,
    required this.subjectRequirements,
    this.daysPerWeek = 5,
    this.periodsPerDay = 7,
  });

  Map<String, dynamic> toJson() => {
        'schoolId': schoolId,
        'schoolType': schoolType,
        'teachers': teachers.map((t) => t.toJson()).toList(),
        'classes': classes.map((c) => c.toJson()).toList(),
        'subjectRequirements': subjectRequirements.map(
          (key, value) => MapEntry(
            key,
            value.map((s) => s.toJson()).toList(),
          ),
        ),
        'daysPerWeek': daysPerWeek,
        'periodsPerDay': periodsPerDay,
      };
}

class TeacherModel {
  final String id;
  final String name;
  final List<String> subjects;
  final List<String> assignedClassIds;
  final int maxWeeklyLoad;

  TeacherModel({
    required this.id,
    required this.name,
    required this.subjects,
    required this.assignedClassIds,
    this.maxWeeklyLoad = 24,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subjects': subjects,
        'assignedClassIds': assignedClassIds,
        'maxWeeklyLoad': maxWeeklyLoad,
      };
}

class ClassModel {
  final String id;
  final String name;
  final int gradeLevel;
  final String? track;

  ClassModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    this.track,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gradeLevel': gradeLevel,
        if (track != null) 'track': track,
      };
}

class SubjectRequirement {
  final String subject;
  final int weeklyHours;

  SubjectRequirement({
    required this.subject,
    required this.weeklyHours,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'weeklyHours': weeklyHours,
      };
}

class LessonModel {
  final String classId;
  final String className;
  final String day;
  final int period;
  final String teacherId;
  final String teacherName;
  final String subject;

  LessonModel({
    required this.classId,
    required this.className,
    required this.day,
    required this.period,
    required this.teacherId,
    required this.teacherName,
    required this.subject,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        classId: json['classId'],
        className: json['className'],
        day: json['day'],
        period: json['period'],
        teacherId: json['teacherId'],
        teacherName: json['teacherName'],
        subject: json['subject'],
      );
}

class ScheduleResponse {
  final bool success;
  final String message;
  final List<LessonModel> lessons;
  final Map<String, dynamic> stats;
  final double executionTime;

  ScheduleResponse({
    required this.success,
    required this.message,
    required this.lessons,
    required this.stats,
    required this.executionTime,
  });

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) =>
      ScheduleResponse(
        success: json['success'],
        message: json['message'],
        lessons: (json['lessons'] as List)
            .map((l) => LessonModel.fromJson(l))
            .toList(),
        stats: json['stats'],
        executionTime: json['executionTime'],
      );
}
