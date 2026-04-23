
class StudentBehaviorProfile {
  final String studentId;
  final String schoolId;
  final int score;
  final String riskLevel;
  final String trend;
  final List<String> topDrivers;
  final List<String> recommendations;
  final DateTime lastUpdatedAt;
  final String modelVersion;

  StudentBehaviorProfile({
    required this.studentId,
    required this.schoolId,
    required this.score,
    required this.riskLevel,
    required this.trend,
    required this.topDrivers,
    required this.recommendations,
    required this.lastUpdatedAt,
    required this.modelVersion,
  });

  factory StudentBehaviorProfile.fromMap(Map<String, dynamic> map) {
    return StudentBehaviorProfile(
      studentId: map['studentId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      score: map['score']?.toInt() ?? 100,
      riskLevel: map['riskLevel'] ?? 'Low',
      trend: map['trend'] ?? 'Stable',
      topDrivers: List<String>.from(map['topDrivers'] ?? []),
      recommendations: List<String>.from(map['recommendations'] ?? []),
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? (map['lastUpdatedAt'] as dynamic).toDate()
          : DateTime.now(),
      modelVersion: map['modelVersion'] ?? '1.0.0',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'schoolId': schoolId,
      'score': score,
      'riskLevel': riskLevel,
      'trend': trend,
      'topDrivers': topDrivers,
      'recommendations': recommendations,
      'lastUpdatedAt': lastUpdatedAt,
      'modelVersion': modelVersion,
    };
  }
}
