class SchoolSnapshot {
  final String schoolId;
  final String stage;
  final List<int> grades;
  final int teachersCount;
  final int subjectsCount;
  final int classesCount;
  final int lowerPrimaryClassesCount;
  final int upperPrimaryClassesCount;
  final int daysPerWeek;
  final int periodsPerDay;
  final String? secondaryProgramType;
  final String? secondaryStructure;
  final List<String> enabledTracks;
  final String? schoolEducationProfile;
  final List<SnapshotClass> classes;
  final List<SnapshotSubject> subjects;
  final List<SnapshotTeacher> teachers;
  final Map<String, String> subjectIdByAlias;
  final String classesSourcePath;
  final List<String> rawClassDocIds;
  final List<dynamic> rawClassGradeLevels;
  final List<int> parsedClassGradeLevels;
  final List<int> effectiveGradeLevels;
  final String classInterpretationMode;
  final List<Map<String, dynamic>> classDebugSample;

  const SchoolSnapshot({
    required this.schoolId,
    required this.stage,
    required this.grades,
    required this.teachersCount,
    required this.subjectsCount,
    required this.classesCount,
    this.lowerPrimaryClassesCount = 0,
    this.upperPrimaryClassesCount = 0,
    required this.daysPerWeek,
    required this.periodsPerDay,
    this.secondaryProgramType,
    this.secondaryStructure,
    this.enabledTracks = const <String>[],
    this.schoolEducationProfile,
    this.classes = const <SnapshotClass>[],
    this.subjects = const <SnapshotSubject>[],
    this.teachers = const <SnapshotTeacher>[],
    this.subjectIdByAlias = const <String, String>{},
    required this.classesSourcePath,
    this.rawClassDocIds = const <String>[],
    this.rawClassGradeLevels = const <dynamic>[],
    this.parsedClassGradeLevels = const <int>[],
    this.effectiveGradeLevels = const <int>[],
    this.classInterpretationMode = '',
    this.classDebugSample = const <Map<String, dynamic>>[],
  });
}

class SnapshotClass {
  final String id;
  final String name;
  final String? nameCode;
  final String? displayName;
  final int gradeLevel;
  final String? secondaryProgramType;
  final String? secondaryPhase;
  final String? secondaryTrack;
  final int? sectionNumber;

  const SnapshotClass({
    required this.id,
    required this.name,
    this.nameCode,
    this.displayName,
    required this.gradeLevel,
    this.secondaryProgramType,
    this.secondaryPhase,
    this.secondaryTrack,
    this.sectionNumber,
  });
}

class SnapshotSubject {
  final String id;
  final String name;

  const SnapshotSubject({required this.id, required this.name});
}

class SnapshotTeacher {
  final String id;
  final String name;
  final String? stage;
  final String? specialization;
  final String? primarySubjectId;
  final List<String> additionalSubjects;
  final List<SnapshotSubjectAssignment> subjectAssignments;
  final List<String> assignedClassIds;
  final String? masaratAssignmentType;
  final List<String> masaratTracks;
  final int? masaratGradeLevel;
  final int targetWeeklyLoad;
  final int maxWeeklyLoad;
  final bool isAdministrative;
  final bool isMedicalExempt;
  final List<String> blockedTimeSlots;
  final List<String> preferredTimeSlots;
  final List<String> softConstraintSlots;

  const SnapshotTeacher({
    required this.id,
    required this.name,
    this.stage,
    this.specialization,
    this.primarySubjectId,
    this.additionalSubjects = const <String>[],
    this.subjectAssignments = const <SnapshotSubjectAssignment>[],
    this.assignedClassIds = const <String>[],
    this.masaratAssignmentType,
    this.masaratTracks = const <String>[],
    this.masaratGradeLevel,
    this.targetWeeklyLoad = 0,
    this.maxWeeklyLoad = 0,
    this.isAdministrative = false,
    this.isMedicalExempt = false,
    this.blockedTimeSlots = const <String>[],
    this.preferredTimeSlots = const <String>[],
    this.softConstraintSlots = const <String>[],
  });
}

class SnapshotSubjectAssignment {
  final String subjectId;
  final String type;

  const SnapshotSubjectAssignment({
    required this.subjectId,
    required this.type,
  });
}
