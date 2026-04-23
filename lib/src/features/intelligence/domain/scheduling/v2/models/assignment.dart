class AssignmentModel {
  final List<TeacherAssignment> teachers;
  final AssignmentSummary summary;
  final List<String> uncoveredSubjectIds;

  const AssignmentModel({
    this.teachers = const <TeacherAssignment>[],
    required this.summary,
    this.uncoveredSubjectIds = const <String>[],
  });
}

class TeacherAssignment {
  final String teacherId;
  final String teacherName;
  final String classification;
  final String? primarySubject;
  final List<String> additionalSubjects;
  final List<String> assignedSubjects;
  final int targetWeeklyLoad;
  final int maxWeeklyLoad;
  final bool isAdministrative;
  final bool isMedicalExempt;

  const TeacherAssignment({
    required this.teacherId,
    required this.teacherName,
    required this.classification,
    this.primarySubject,
    this.additionalSubjects = const <String>[],
    this.assignedSubjects = const <String>[],
    required this.targetWeeklyLoad,
    required this.maxWeeklyLoad,
    required this.isAdministrative,
    required this.isMedicalExempt,
  });
}

class AssignmentSummary {
  final int teachersCount;
  final int assignedTeachersCount;
  final int unassignedTeachersCount;
  final int uncoveredSubjectsCount;
  final int overloadedTeachersCount;
  final int subjectTeachersCount;
  final int lowerPrimaryTeachersCount;
  final int upperPrimaryTeachersCount;
  final int bundleTeachersCount;
  final int sharedTeachersCount;
  final int specializedTeachersCount;
  final int administrativeTeachersCount;

  const AssignmentSummary({
    required this.teachersCount,
    required this.assignedTeachersCount,
    required this.unassignedTeachersCount,
    required this.uncoveredSubjectsCount,
    required this.overloadedTeachersCount,
    required this.subjectTeachersCount,
    required this.lowerPrimaryTeachersCount,
    required this.upperPrimaryTeachersCount,
    required this.bundleTeachersCount,
    required this.sharedTeachersCount,
    required this.specializedTeachersCount,
    required this.administrativeTeachersCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'teachersCount': teachersCount,
      'assignedTeachersCount': assignedTeachersCount,
      'unassignedTeachersCount': unassignedTeachersCount,
      'uncoveredSubjectsCount': uncoveredSubjectsCount,
      'overloadedTeachersCount': overloadedTeachersCount,
      'subjectTeachersCount': subjectTeachersCount,
      'lowerPrimaryTeachersCount': lowerPrimaryTeachersCount,
      'upperPrimaryTeachersCount': upperPrimaryTeachersCount,
      'bundleTeachersCount': bundleTeachersCount,
      'sharedTeachersCount': sharedTeachersCount,
      'specializedTeachersCount': specializedTeachersCount,
      'administrativeTeachersCount': administrativeTeachersCount,
      'lowerPrimaryTeachers': lowerPrimaryTeachersCount,
      'upperPrimaryTeachers': upperPrimaryTeachersCount,
      'bundleTeachers': bundleTeachersCount,
      'subjectTeachers': subjectTeachersCount,
    };
  }
}
