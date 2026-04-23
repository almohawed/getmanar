class TeacherBehaviorProfile {
  final String teacherId;
  final String schoolId;
  final int score;
  final String badge; // e.g., 'التزام متميز'
  final String badgeColor; // 'Green', 'Yellow', 'Orange', 'Red'
  final String trend; // 'Improving', 'Stable', 'Declining'
  final List<String> patterns;
  final List<String> recommendations;
  final ScheduleHints scheduleHints;
  final TeacherMetrics metrics;
  final DateTime lastUpdatedAt;
  final int escalationLevel; // 0, 1, 2, 3
  final String
  escalationStage; // 'Observation', 'Constraint', 'AdministrativeFlag', 'CriticalReview'
  final DateTime? firstObservationDate;
  final List<DecisionLog> decisionLogs;

  TeacherBehaviorProfile({
    required this.teacherId,
    required this.schoolId,
    required this.score,
    required this.badge,
    required this.badgeColor,
    required this.trend,
    required this.patterns,
    required this.recommendations,
    required this.scheduleHints,
    required this.metrics,
    required this.lastUpdatedAt,
    this.escalationLevel = 0,
    this.escalationStage = 'Observation',
    this.firstObservationDate,
    this.decisionLogs = const [],
  });

  factory TeacherBehaviorProfile.fromMap(Map<String, dynamic> map) {
    return TeacherBehaviorProfile(
      teacherId: map['teacherId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      score: map['score']?.toInt() ?? 100,
      badge: map['badge'] ?? 'التزام متميز',
      badgeColor: map['badgeColor'] ?? 'Green',
      trend: map['trend'] ?? 'Stable',
      patterns: List<String>.from(map['patterns'] ?? []),
      recommendations: List<String>.from(map['recommendations'] ?? []),
      scheduleHints: ScheduleHints.fromMap(map['scheduleHints'] ?? {}),
      metrics: TeacherMetrics.fromMap(map['metrics'] ?? {}),
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? (map['lastUpdatedAt'] as dynamic).toDate()
          : DateTime.now(),
      escalationLevel: map['escalationLevel'] ?? 0,
      escalationStage: map['escalationStage'] ?? 'Observation',
      firstObservationDate: map['firstObservationDate'] != null
          ? (map['firstObservationDate'] as dynamic).toDate()
          : null,
      decisionLogs:
          (map['decisionLogs'] as List<dynamic>?)
              ?.map((e) => DecisionLog.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'schoolId': schoolId,
      'score': score,
      'badge': badge,
      'badgeColor': badgeColor,
      'trend': trend,
      'patterns': patterns,
      'recommendations': recommendations,
      'scheduleHints': scheduleHints.toMap(),
      'metrics': metrics.toMap(),
      'lastUpdatedAt': lastUpdatedAt,
      'escalationLevel': escalationLevel,
      'escalationStage': escalationStage,
      'firstObservationDate': firstObservationDate,
      'decisionLogs': decisionLogs.map((e) => e.toMap()).toList(),
    };
  }
}

class DecisionLog {
  final String date;
  final String action;
  final String reason;
  final String type; // 'Automatic', 'Manual'

  DecisionLog({
    required this.date,
    required this.action,
    required this.reason,
    required this.type,
  });

  factory DecisionLog.fromMap(Map<String, dynamic> map) {
    return DecisionLog(
      date: map['date'] ?? '',
      action: map['action'] ?? '',
      reason: map['reason'] ?? '',
      type: map['type'] ?? 'Automatic',
    );
  }

  Map<String, dynamic> toMap() {
    return {'date': date, 'action': action, 'reason': reason, 'type': type};
  }
}

class ScheduleHints {
  final List<int> avoidPeriods;
  final int? preferStartPeriod;
  final int? maxGapsPerDay;
  final List<String> avoidDays;
  final bool escalationForced;

  ScheduleHints({
    this.avoidPeriods = const [],
    this.preferStartPeriod,
    this.maxGapsPerDay,
    this.avoidDays = const [],
    this.escalationForced = false,
  });

  factory ScheduleHints.fromMap(Map<String, dynamic> map) {
    return ScheduleHints(
      avoidPeriods: List<int>.from(map['avoidPeriods'] ?? []),
      preferStartPeriod: map['preferStartPeriod'],
      maxGapsPerDay: map['maxGapsPerDay'],
      avoidDays: List<String>.from(map['avoidDays'] ?? []),
      escalationForced: map['escalationForced'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'avoidPeriods': avoidPeriods,
      'preferStartPeriod': preferStartPeriod,
      'maxGapsPerDay': maxGapsPerDay,
      'avoidDays': avoidDays,
      'escalationForced': escalationForced,
    };
  }
}

class TeacherMetrics {
  final int lateCount;
  final int absenceUnexcused;
  final int absenceExcused;
  final int skipP7Count;
  final int skipP1Count;
  final int waitingRefusalCount;
  final int taskDelayCount;

  TeacherMetrics({
    this.lateCount = 0,
    this.absenceUnexcused = 0,
    this.absenceExcused = 0,
    this.skipP7Count = 0,
    this.skipP1Count = 0,
    this.waitingRefusalCount = 0,
    this.taskDelayCount = 0,
  });

  factory TeacherMetrics.fromMap(Map<String, dynamic> map) {
    return TeacherMetrics(
      lateCount: map['lateCount'] ?? 0,
      absenceUnexcused: map['absenceUnexcused'] ?? 0,
      absenceExcused: map['absenceExcused'] ?? 0,
      skipP7Count: map['skipP7Count'] ?? 0,
      skipP1Count: map['skipP1Count'] ?? 0,
      waitingRefusalCount: map['waitingRefusalCount'] ?? 0,
      taskDelayCount: map['taskDelayCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lateCount': lateCount,
      'absenceUnexcused': absenceUnexcused,
      'absenceExcused': absenceExcused,
      'skipP7Count': skipP7Count,
      'skipP1Count': skipP1Count,
      'waitingRefusalCount': waitingRefusalCount,
      'taskDelayCount': taskDelayCount,
    };
  }
}
