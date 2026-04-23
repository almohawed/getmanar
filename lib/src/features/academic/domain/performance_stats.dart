class PerformanceStats {
  final double overallSuccessRate;
  final double excellenceRate;
  final double improvementRate;
  final Map<String, double> performanceLevels;
  final Map<String, double> successRatesByClass;
  final int totalStudents;
  final int successfulStudents;

  PerformanceStats({
    required this.overallSuccessRate,
    required this.excellenceRate,
    required this.improvementRate,
    required this.performanceLevels,
    required this.successRatesByClass,
    required this.totalStudents,
    required this.successfulStudents,
  });

  factory PerformanceStats.empty() {
    return PerformanceStats(
      overallSuccessRate: 0.0,
      excellenceRate: 0.0,
      improvementRate: 0.0,
      performanceLevels: {
        'excellent': 0.0,
        'veryGood': 0.0,
        'good': 0.0,
        'acceptable': 0.0,
        'weak': 0.0,
      },
      successRatesByClass: {},
      totalStudents: 0,
      successfulStudents: 0,
    );
  }
}

class GapStats {
  final int totalGaps;
  final int criticalGaps;
  final int resolvedGaps;
  final List<LearningGapInfo> gaps;

  GapStats({
    required this.totalGaps,
    required this.criticalGaps,
    required this.resolvedGaps,
    required this.gaps,
  });

  factory GapStats.empty() {
    return GapStats(
      totalGaps: 0,
      criticalGaps: 0,
      resolvedGaps: 0,
      gaps: [],
    );
  }
}

class LearningGapInfo {
  final String subject;
  final String className;
  final String description;
  final int affectedStudents;
  final String priority;

  LearningGapInfo({
    required this.subject,
    required this.className,
    required this.description,
    required this.affectedStudents,
    required this.priority,
  });
}

class TeacherStats {
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final double avgExcellence;
  final int currentLoad;
  final int maxLoad;

  TeacherStats({
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.avgExcellence,
    required this.currentLoad,
    required this.maxLoad,
  });

  double get loadPercentage {
    if (maxLoad == 0) return 0.0;
    return (currentLoad / maxLoad) * 100;
  }
}
