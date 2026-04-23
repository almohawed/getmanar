import 'dart:math';
import '../../../../features/attendance/domain/student_attendance.dart';
import '../../../../features/assignments/domain/assignment.dart';
import '../../../../core/domain/models/behavior_record.dart';
import 'silent_guidance_constants.dart';
import 'student_guidance_policy.dart';

// Export constants for consumers
export 'silent_guidance_constants.dart';
export 'student_guidance_policy.dart';

/// Minimal Integration Contract: Result Object
class GuidanceResult {
  final String messageId;
  final GuidanceCategory category;
  final GuidanceSeverity severityLevel;
  final String text;

  const GuidanceResult({
    required this.messageId,
    required this.category,
    required this.severityLevel,
    required this.text,
  });
}

/// Minimal Integration Contract: Input Metrics
class GuidanceMetrics {
  final double lateRisk; // 0-100
  final double hwRisk; // 0-100
  final double discRisk; // 0-100
  final double excellenceScore; // 0-100

  const GuidanceMetrics({
    required this.lateRisk,
    required this.hwRisk,
    required this.discRisk,
    required this.excellenceScore,
  });
}

/// Minimal Integration Contract: History Entry
class GuidanceHistoryEntry {
  final String messageId;
  final GuidanceCategory category;
  final GuidanceSeverity severity;
  final DateTime timestamp;

  const GuidanceHistoryEntry({
    required this.messageId,
    required this.category,
    required this.severity,
    required this.timestamp,
  });
}

class SilentGuidanceEngine {
  // Weights for Risk Calculation
  static const double _wLate = 1.00;
  static const double _wHw = 1.05;
  static const double _wDisc = 0.95;

  /// Main Integration Point
  /// Returns null if no message should be shown (Silent).
  static GuidanceResult? getSilentGuidance({
    required String studentId,
    required SchoolStage stage,
    required GuidanceMetrics metrics,
    required List<GuidanceHistoryEntry> history,
    StudentGuidancePolicy? policy,
  }) {
    // Resolve Policy
    final effectivePolicy = policy ?? StudentGuidancePolicy.createDefault();

    // 0. Global Enable Check
    if (!effectivePolicy.enabled) return null;

    final now = DateTime.now();

    // 1. Excellence / Positive Check (Perfect Student Immunity)
    // If excellent and low risks, prioritize positive reinforcement.
    if (metrics.excellenceScore >= 98 &&
        metrics.lateRisk < 10 &&
        metrics.hwRisk < 10 &&
        metrics.discRisk < 10) {
      // Check frequency for positive messages (don't spam excellence too much? or maybe do?)
      // User didn't specify strict limit for positive, but we should rotate.
      return _selectMessage(
        GuidanceCategory.positive,
        GuidanceSeverity.soft,
        history,
        stage,
        effectivePolicy,
      );
    }

    // 2. Cooldown Check (Anti-Spam)
    // Rule: minDaysBetweenMessages = policy.minDaysBetweenMessages
    if (history.isNotEmpty) {
      // Assuming history is sorted desc (newest first)
      final lastMsg = history.first;
      final daysSince = now.difference(lastMsg.timestamp).inDays;

      int minDays = effectivePolicy.minDaysBetweenMessages;
      // Exception: excellenceScore >= 85 -> reduce cooldown to 1 day if allowed
      if (metrics.excellenceScore >= 85 && minDays > 1) minDays = 1;

      if (daysSince < minDays) {
        return null; // Cooldown active, stay silent
      }
    }

    // 3. Determine Category & Severity based on Risks
    final selection = _determineCategoryAndSeverity(metrics, effectivePolicy);
    var category = selection.key;
    var severity = selection.value;

    // If no significant risk found, try Positive if score is decent
    if (category == null) {
      if (metrics.excellenceScore >= 80) {
        return _selectMessage(
          GuidanceCategory.positive,
          GuidanceSeverity.soft,
          history,
          stage,
          effectivePolicy,
        );
      }
      return null; // No risk, no excellence -> Silent
    }

    // 4. Category Rotation Rules (Anti-Boredom)
    // Policy Check: maxPer7Days for this category
    final catRule = effectivePolicy.categoryRules[category];
    final maxPer7Days = catRule?.maxPer7Days ?? 2; // Default 2

    if (_isCategoryOverused(category, history, days: 7, limit: maxPer7Days)) {
      // Try to switch to Merged or another category?
      // Or fallback to positive if applicable.
      // For now, let's suppress to force diversity or silence.
      // Alternatively, check secondary risk? (Complexity for later)
      return null;
    }

    // 5. Severity Caps (Anti-Harshness)
    // Policy Check: maxStrongPer7Days
    if (severity == GuidanceSeverity.strong) {
      if (_isSeverityOverused(
        GuidanceSeverity.strong,
        history,
        days: 7,
        limit: effectivePolicy.maxStrongPer7Days,
      )) {
        severity = GuidanceSeverity.medium; // Downgrade
      }
    }

    // 6. Select Message from Library
    return _selectMessage(category, severity, history, stage, effectivePolicy);
  }

  // ---------------------------------------------------------------------------
  // Internal Logic Helpers
  // ---------------------------------------------------------------------------

  static MapEntry<GuidanceCategory?, GuidanceSeverity>
  _determineCategoryAndSeverity(
    GuidanceMetrics metrics,
    StudentGuidancePolicy policy,
  ) {
    // 1. Calculate Weighted Scores
    double lateScore = metrics.lateRisk * _wLate;
    double hwScore = metrics.hwRisk * _wHw;
    double discScore = metrics.discRisk * _wDisc;

    Map<GuidanceCategory, double> scores = {
      GuidanceCategory.lateness: lateScore,
      GuidanceCategory.homework: hwScore,
      GuidanceCategory.discipline: discScore,
    };

    // 2. Sort
    var sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final primary = sortedEntries[0];
    final secondary = sortedEntries[1];

    // 3. Threshold check
    // If primary risk is very low (< 20), no negative guidance needed.
    if (primary.value < 20) {
      return const MapEntry(null, GuidanceSeverity.soft);
    }

    // 3.1 Policy Category Gate
    if (policy.categoryRules[primary.key]?.enabled == false) {
      return const MapEntry(null, GuidanceSeverity.soft);
    }

    // 4. Check Merge Condition
    // Rule: secondary >= primary * 0.85
    bool isMerged =
        policy.allowMergedMessages &&
        (secondary.value >= primary.value * 0.85) &&
        (secondary.value > 20);

    GuidanceCategory finalCategory = primary.key;
    if (isMerged) {
      finalCategory = _getMergedCategory(primary.key, secondary.key);
    }

    // 5. Determine Severity
    GuidanceSeverity severity = _getSeverityLevel(primary.value);

    // 5.1 Severity Clamp from Policy
    final catRule = policy.categoryRules[finalCategory];
    if (catRule != null && severity.index > catRule.maxSeverity.index) {
      severity = catRule.maxSeverity;
    }

    return MapEntry(finalCategory, severity);
  }

  static GuidanceCategory _getMergedCategory(
    GuidanceCategory c1,
    GuidanceCategory c2,
  ) {
    final set = {c1, c2};
    if (set.contains(GuidanceCategory.lateness) &&
        set.contains(GuidanceCategory.homework)) {
      return GuidanceCategory.mergedLateHomework;
    }
    if (set.contains(GuidanceCategory.homework) &&
        set.contains(GuidanceCategory.discipline)) {
      return GuidanceCategory.mergedHomeworkDiscipline;
    }
    if (set.contains(GuidanceCategory.lateness) &&
        set.contains(GuidanceCategory.discipline)) {
      return GuidanceCategory.mergedLateDiscipline;
    }
    return c1; // Fallback to primary if merge not defined
  }

  static GuidanceSeverity _getSeverityLevel(double score) {
    if (score < 35) return GuidanceSeverity.soft;
    if (score < 70) return GuidanceSeverity.medium;
    return GuidanceSeverity.strong;
  }

  static bool _isCategoryOverused(
    GuidanceCategory category,
    List<GuidanceHistoryEntry> history, {
    required int days,
    required int limit,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    int count = history
        .where((h) => h.timestamp.isAfter(cutoff) && h.category == category)
        .length;
    return count >= limit;
  }

  static bool _isSeverityOverused(
    GuidanceSeverity severity,
    List<GuidanceHistoryEntry> history, {
    required int days,
    required int limit,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    int count = history
        .where((h) => h.timestamp.isAfter(cutoff) && h.severity == severity)
        .length;
    return count >= limit;
  }

  static GuidanceResult? _selectMessage(
    GuidanceCategory category,
    GuidanceSeverity severity,
    List<GuidanceHistoryEntry> history,
    SchoolStage stage,
    StudentGuidancePolicy policy,
  ) {
    // 1. Get pool of messages
    List<GuidanceMessage> pool = _getMessagesFor(category, severity);
    if (pool.isEmpty) return null;

    // 2. Filter recently shown messages (Anti-Repetition)
    // Rule: Don't show same message ID if shown in last 14 days
    final recentMsgIds = history
        .where((h) => DateTime.now().difference(h.timestamp).inDays < 14)
        .map((h) => h.messageId)
        .toSet();

    final candidates = pool.where((m) => !recentMsgIds.contains(m.id)).toList();

    // Fallback: If all candidates shown recently, reset pool (allow repetition if necessary)
    // But prefer least recently shown? For now, just reset.
    final finalPool = candidates.isNotEmpty ? candidates : pool;

    // 3. Shuffle & Pick One
    // (In real app, maybe use deterministic hash of day+studentId to keep it stable for the day?)
    // Here we use random as it's called once per session/day check.
    finalPool.shuffle();
    final selected = finalPool.first;

    // 5. Apply Stage Tone & Safety Guards
    final finalText = _applyStageToneAndGuards(
      selected.text,
      stage,
      category,
      severity,
      policy,
    );

    return GuidanceResult(
      messageId: selected.id,
      category: category,
      severityLevel: severity,
      text: finalText,
    );
  }

  static List<GuidanceMessage> _getMessagesFor(
    GuidanceCategory category,
    GuidanceSeverity severity,
  ) {
    switch (category) {
      case GuidanceCategory.lateness:
        return SilentGuidanceConstants.lateMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.homework:
        return SilentGuidanceConstants.homeworkMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.discipline:
        return SilentGuidanceConstants.disciplineMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.mergedLateHomework:
        return SilentGuidanceConstants.mergedLateHomeworkMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.mergedHomeworkDiscipline:
        return SilentGuidanceConstants.mergedHomeworkDisciplineMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.mergedLateDiscipline:
        return SilentGuidanceConstants.mergedLateDisciplineMessages
            .where((m) => m.severity == severity)
            .toList();
      case GuidanceCategory.positive:
        return SilentGuidanceConstants
            .positiveMessages; // Positive usually Soft
    }
  }

  static String _applyStageToneAndGuards(
    String text,
    SchoolStage stage,
    GuidanceCategory category,
    GuidanceSeverity severity,
    StudentGuidancePolicy policy,
  ) {
    var safeText = text;

    // 1. Policy Wording Permissions
    if (!policy.allowHomeworkWording) {
      safeText = safeText
          .replaceAll("واجب", "مذاكرة")
          .replaceAll("مهام", "تنظيم");
    }
    if (!policy.allowAttendanceWording) {
      safeText = safeText
          .replaceAll("حضور", "تواجد")
          .replaceAll("تأخر", "وصول متأخر");
    }
    if (!policy.allowDisciplineWording) {
      safeText = safeText
          .replaceAll("انضباط", "سلوك")
          .replaceAll("التزام", "تركيز");
    }

    // 2. Policy Replacements (Custom Dictionary)
    if (policy.replacements.isNotEmpty) {
      policy.replacements.forEach((key, value) {
        safeText = safeText.replaceAll(key, value);
      });
    }

    // 3. Banned Words Check
    // Refined Safety Net: Use softer words based on profile
    String safetyReplacement =
        (policy.toneProfile == ToneProfile.governmentBalanced)
        ? "تنبيه تربوي"
        : "ملاحظة";

    for (var word in policy.bannedWords) {
      if (safeText.contains(word)) {
        safeText = safeText.replaceAll(word, safetyReplacement);
      }
    }

    // 4. Stage Tone Pack Logic
    if (stage == SchoolStage.primary) {
      // Primary: Simplify language
      safeText = safeText
          .replaceAll("المسؤولية", "الاهتمام")
          .replaceAll("الانضباط", "الالتزام")
          .replaceAll("تؤثر سلباً", "تقلل")
          .replaceAll("التحصيل الدراسي", "درجاتك")
          .replaceAll("مستقبلك", "نجاحك");

      // Add friendly prefix for Soft/Positive if not present
      if (severity == GuidanceSeverity.soft ||
          category == GuidanceCategory.positive) {
        if (!safeText.startsWith("يا بطل")) {
          safeText = "يا بطل، " + safeText;
        }
      }
    } else if (stage == SchoolStage.middle) {
      // Middle: Balanced
      // Keep as is mostly, maybe slight adjustments
    } else if (stage == SchoolStage.secondary) {
      // Secondary: Mature
      safeText = safeText
          .replaceAll("يا بطل", "عزيزي الطالب")
          .replaceAll("ممتاز", "أداء متميز");
    }

    return safeText;
  }

  /// Micro A/B Evaluation Logic (C6)
  /// Calculates the impact score of a message based on risk changes after 7 days.
  /// Usage: Call this in a background job or periodic check.
  static int calculateImpactScore({
    required GuidanceMetrics before,
    required GuidanceMetrics after,
  }) {
    // delta = after - before
    // We want risk to DECREASE. So negative delta is GOOD.
    final deltaLate = after.lateRisk - before.lateRisk;
    final deltaHw = after.hwRisk - before.hwRisk;
    final deltaDisc = after.discRisk - before.discRisk;

    int score = 0;

    // Rewards for significant improvement (drop in risk)
    if (deltaLate < -10) score += 1;
    if (deltaLate < -25) score += 1; // Bonus for big drop

    if (deltaHw < -10) score += 1;
    if (deltaHw < -25) score += 1;

    if (deltaDisc < -10) score += 1;
    if (deltaDisc < -25) score += 1;

    // Penalties for deterioration (increase in risk)
    if (deltaLate > 10) score -= 1;
    if (deltaHw > 10) score -= 1;
    if (deltaDisc > 10) score -= 1;

    return score;
  }

  // ---------------------------------------------------------------------------
  // Backward Compatibility Wrapper
  // ---------------------------------------------------------------------------
  static String? analyzeAndGenerateMessage({
    required List<StudentAttendance> attendanceHistory,
    required List<Assignment> assignments,
    required List<BehaviorRecord> behaviorRecords,
    required double excellenceScore,
    SchoolStage stage = SchoolStage.middle, // Default
    List<GuidanceHistoryEntry> history = const [],
    String studentId = "unknown", // Should be passed
  }) {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final fourWeeksAgo = now.subtract(const Duration(days: 28));

    // --- Metric Calculation (Reused Logic) ---

    // Lateness
    final recentLates = attendanceHistory.where((a) {
      return a.date.isAfter(twoWeeksAgo) &&
          a.status == StudentAttendanceStatus.late;
    }).length;

    final previousLates = attendanceHistory.where((a) {
      return a.date.isAfter(fourWeeksAgo) &&
          a.date.isBefore(twoWeeksAgo) &&
          a.status == StudentAttendanceStatus.late;
    }).length;

    double lateTrend = 0.0;
    if (previousLates > 0) {
      lateTrend = (recentLates - previousLates) / previousLates;
    } else if (recentLates > 0) {
      lateTrend = 1.0;
    }

    // Homework
    final recentDueAssignments = assignments.where((a) {
      return a.dueDate.isAfter(twoWeeksAgo) && a.dueDate.isBefore(now);
    }).toList();
    final previousDueAssignments = assignments.where((a) {
      return a.dueDate.isAfter(fourWeeksAgo) && a.dueDate.isBefore(twoWeeksAgo);
    }).toList();

    double calculateCompletionRate(List<Assignment> list) {
      if (list.isEmpty) return 1.0;
      final completed = list
          .where(
            (a) =>
                a.status == AssignmentStatus.submitted ||
                a.status == AssignmentStatus.approved,
          )
          .length;
      return completed / list.length;
    }

    final recentHwRate = calculateCompletionRate(recentDueAssignments);
    final previousHwRate = calculateCompletionRate(previousDueAssignments);
    double hwTrend = recentHwRate - previousHwRate;

    // Discipline
    final recentNegativeBehaviors = behaviorRecords.where((r) {
      return r.timestamp.isAfter(twoWeeksAgo) && r.points < 0;
    }).length;
    final previousNegativeBehaviors = behaviorRecords.where((r) {
      return r.timestamp.isAfter(fourWeeksAgo) &&
          r.timestamp.isBefore(twoWeeksAgo) &&
          r.points < 0;
    }).length;

    double disciplineTrend = 0.0;
    if (previousNegativeBehaviors > 0) {
      disciplineTrend =
          (recentNegativeBehaviors - previousNegativeBehaviors) /
          previousNegativeBehaviors;
    } else if (recentNegativeBehaviors > 0) {
      disciplineTrend = 1.0;
    }

    // --- Risk Calculation ---
    double lateSeverity = 0;
    if (recentLates <= 0)
      lateSeverity = 0;
    else if (recentLates <= 2)
      lateSeverity = 25;
    else if (recentLates <= 4)
      lateSeverity = 55;
    else
      lateSeverity = 85;

    double hwSeverity = 0;
    if (recentHwRate >= 0.90)
      hwSeverity = 0;
    else if (recentHwRate >= 0.70)
      hwSeverity = 35;
    else if (recentHwRate >= 0.50)
      hwSeverity = 65;
    else
      hwSeverity = 90;

    double disciplineSeverity = 0;
    if (recentNegativeBehaviors == 0)
      disciplineSeverity = 0;
    else if (recentNegativeBehaviors <= 1)
      disciplineSeverity = 25;
    else if (recentNegativeBehaviors <= 2)
      disciplineSeverity = 55;
    else
      disciplineSeverity = 85;

    // Trend Multipliers
    double getBadBehaviorTrendMultiplier(double t) {
      if (t >= 0.35) return 1.20;
      if (t >= 0.10) return 1.10;
      if (t <= -0.35) return 0.80;
      if (t <= -0.10) return 0.90;
      return 1.00;
    }

    double getGoodBehaviorTrendMultiplier(double t) {
      if (t <= -0.35) return 1.20;
      if (t <= -0.10) return 1.10;
      if (t >= 0.35) return 0.80;
      if (t >= 0.10) return 0.90;
      return 1.00;
    }

    double lateRisk = (lateSeverity * getBadBehaviorTrendMultiplier(lateTrend))
        .clamp(0, 100);
    double hwRisk = (hwSeverity * getGoodBehaviorTrendMultiplier(hwTrend))
        .clamp(0, 100);
    double discRisk =
        (disciplineSeverity * getBadBehaviorTrendMultiplier(disciplineTrend))
            .clamp(0, 100);

    // --- Call Engine ---
    final metrics = GuidanceMetrics(
      lateRisk: lateRisk,
      hwRisk: hwRisk,
      discRisk: discRisk,
      excellenceScore: excellenceScore,
    );

    final result = getSilentGuidance(
      studentId: studentId,
      stage: stage,
      metrics: metrics,
      history: history,
    );

    return result?.text;
  }
}
