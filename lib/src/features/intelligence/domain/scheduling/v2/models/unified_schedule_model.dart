/// نموذج موحد لجميع بيانات الجدول
/// يتم تجميع كل البيانات مرة واحدة قبل التوليد
class UnifiedScheduleModel {
  final List<TeacherData> teachers;
  final List<ClassData> classes;
  final List<SubjectData> subjects;
  final ScheduleConstraints constraints;

  const UnifiedScheduleModel({
    required this.teachers,
    required this.classes,
    required this.subjects,
    required this.constraints,
  });
}

/// بيانات المعلم الموحدة
class TeacherData {
  final String id;
  final String name;
  final List<String> subjects; // مواد موحدة ومنظفة
  final List<String> assignedClassIds; // الفصول المسندة
  final int maxWeeklyLoad;
  final bool isAdministrative;

  const TeacherData({
    required this.id,
    required this.name,
    required this.subjects,
    required this.assignedClassIds,
    required this.maxWeeklyLoad,
    this.isAdministrative = false,
  });
}

/// بيانات الفصل الموحدة
class ClassData {
  final String id;
  final String name;
  final int gradeLevel;
  final Map<String, int> requiredSubjects; // subject -> weekly count

  const ClassData({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.requiredSubjects,
  });
}

/// بيانات المادة الموحدة
class SubjectData {
  final String id;
  final String name;
  final String normalizedName;
  final int maxPerDay; // 1 for most, 2 for Arabic/Islamic

  const SubjectData({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.maxPerDay,
  });
}

/// قيود الجدول
class ScheduleConstraints {
  final int daysPerWeek;
  final int periodsPerDay;
  final List<String> days;

  const ScheduleConstraints({
    required this.daysPerWeek,
    required this.periodsPerDay,
    required this.days,
  });
}
