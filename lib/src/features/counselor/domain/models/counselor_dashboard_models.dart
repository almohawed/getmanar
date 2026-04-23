
class RiskCase {
  final String studentId;
  final String studentName;
  final String reason;
  final String severity; // 'high', 'critical'
  final DateTime detectedAt;

  RiskCase({
    required this.studentId,
    required this.studentName,
    required this.reason,
    required this.severity,
    required this.detectedAt,
  });
}

class CounselingLoad {
  final int activeCases;
  final int openPlans;
  final int sessionsThisWeek;
  final double avgClosureDays;
  final String status; // 'normal', 'medium', 'high'

  CounselingLoad({
    required this.activeCases,
    required this.openPlans,
    required this.sessionsThisWeek,
    required this.avgClosureDays,
    required this.status,
  });
}

class CounselingRecommendation {
  final String title;
  final String description;
  final String targetGroup; // e.g., 'Class 2/A'
  final String type; // 'behavior', 'academic', 'social'

  CounselingRecommendation({
    required this.title,
    required this.description,
    required this.targetGroup,
    required this.type,
  });
}
