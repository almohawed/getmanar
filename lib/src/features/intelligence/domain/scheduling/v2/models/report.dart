class ScheduleReport {
  final String schoolId;
  final String stage;
  final String policyId;
  final String policyFile;
  final List<int> grades;
  final int teachers;
  final int subjects;
  final int classes;
  final int daysPerWeek;
  final int periodsPerDay;
  final int runtimeMs;
  final Map<String, dynamic> data;

  const ScheduleReport({
    required this.schoolId,
    required this.stage,
    required this.policyId,
    required this.policyFile,
    required this.grades,
    required this.teachers,
    required this.subjects,
    required this.classes,
    required this.daysPerWeek,
    required this.periodsPerDay,
    this.runtimeMs = 0,
    this.data = const <String, dynamic>{},
  });
}
