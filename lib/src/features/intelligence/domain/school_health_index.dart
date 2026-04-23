class SchoolHealthIndex {
  final double overallScore; // 0-100
  final double behaviorScore;
  final double attendanceScore;
  final double stabilityScore;
  final double familyEngagementScore;
  final List<String> criticalAlerts;
  final DateTime weekStart;

  SchoolHealthIndex({
    required this.overallScore,
    required this.behaviorScore,
    required this.attendanceScore,
    required this.stabilityScore,
    required this.familyEngagementScore,
    required this.criticalAlerts,
    required this.weekStart,
  });
}
