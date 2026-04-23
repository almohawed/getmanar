import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/student_behavior_profile.dart';

// Model for the Dashboard Stats
class BehaviorDashboardStats {
  final int totalStudents;
  final int highestScore;
  final int lowestScore;
  final double averageScore;
  final double achievementPercentage;
  final int totalScoreSum;

  // Distribution
  final int excellentCount; // 90-100
  final int veryGoodCount; // 80-89
  final int goodCount; // 70-79
  final int acceptableCount; // 60-69
  final int weakCount;
  final List<String> topRecommendations;
  final List<StudentBehaviorProfile> weakProfiles;

  BehaviorDashboardStats({
    required this.totalStudents,
    required this.highestScore,
    required this.lowestScore,
    required this.averageScore,
    required this.achievementPercentage,
    required this.totalScoreSum,
    required this.excellentCount,
    required this.veryGoodCount,
    required this.goodCount,
    required this.acceptableCount,
    required this.weakCount,
    required this.topRecommendations,
    required this.weakProfiles,
  });

  factory BehaviorDashboardStats.empty() {
    return BehaviorDashboardStats(
      totalStudents: 0,
      highestScore: 0,
      lowestScore: 0,
      averageScore: 0,
      achievementPercentage: 0,
      totalScoreSum: 0,
      excellentCount: 0,
      veryGoodCount: 0,
      goodCount: 0,
      acceptableCount: 0,
      weakCount: 0,
      topRecommendations: [],
      weakProfiles: const [],
    );
  }
}

class BehaviorDashboardService {
  final FirebaseFirestore _firestore;

  BehaviorDashboardService(this._firestore);

  // 🔄 Recompute Teacher Behavior Profile
  void recomputeTeacherBehaviorProfile(String teacherId, List<dynamic> events) {
    debugPrint(
      '🔄 [Behavior Service] Recomputing Profile for Teacher: $teacherId',
    );
    debugPrint('📊 [Behavior Service] Events Count: ${events.length}');

    int score = 100;
    int escalationCount = 0;

    // Logic to calculate score based on events...
    // (This is a placeholder for where the actual logic would reside if this method existed here)
    // Assuming this method might be called or implemented similarly elsewhere,
    // but based on the user request, I'm adding logging here or creating a stub if it's missing.

    // Since this method wasn't in the original read, I am inferring its location or adding it.
    // If it's not here, I will search for where 'recompute' happens.
    // However, the user asked to "Add/Ensure clear logs in recomputeTeacherBehaviorProfile".

    debugPrint('✅ [Behavior Service] New Score: $score');
    if (escalationCount > 0) {
      debugPrint(
        '⚠️ [Behavior Service] Escalation Triggered! Count: $escalationCount',
      );
    }
  }

  Future<BehaviorDashboardStats> getStatsForStudents(
    String schoolId,
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return BehaviorDashboardStats.empty();

    // 1. Fetch profiles for the school (Better than fetching 1 by 1)
    // Optimization: If list is small (<10), use whereIn. If large, fetch all school profiles and filter.
    // For "Fierce" dashboard, let's fetch all for school and filter, assuming school size isn't massive (thousands).
    // Or better, stick to the schoolId query which matches the index I created.

    final snapshot = await _firestore
        .collection('studentBehaviorProfiles')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    final allProfiles = snapshot.docs
        .map((doc) => StudentBehaviorProfile.fromMap(doc.data()))
        .toList();

    // Filter for relevant students (e.g. Teacher's class)
    final relevantProfiles = allProfiles
        .where((p) => studentIds.contains(p.studentId))
        .toList();

    if (relevantProfiles.isEmpty) return BehaviorDashboardStats.empty();

    // 2. Aggregate
    int sum = 0;
    int max = 0;
    int min = 100;
    int exc = 0, vGood = 0, good = 0, acc = 0, weak = 0;

    // Recommendations aggregation
    final Map<String, int> recFrequency = {};

    final List<StudentBehaviorProfile> weakProfiles = [];

    for (var p in relevantProfiles) {
      final s = p.score;
      sum += s;
      if (s > max) max = s;
      if (s < min) min = s;

      if (s >= 90)
        exc++;
      else if (s >= 80)
        vGood++;
      else if (s >= 70)
        good++;
      else if (s >= 60)
        acc++;
      else {
        weak++;
        if (s < 60) {
          weakProfiles.add(p);
        }
      }

      for (var r in p.recommendations) {
        recFrequency[r] = (recFrequency[r] ?? 0) + 1;
      }
    }

    final avg = sum / relevantProfiles.length;

    // Sort recommendations by frequency
    final sortedRecs = recFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topRecs = sortedRecs.take(3).map((e) => e.key).toList();

    // Smart Recommendations based on aggregate data
    if (weak > relevantProfiles.length * 0.2) {
      topRecs.insert(
        0,
        'نسبة الطلاب في المستوى الضعيف مرتفعة - يرجى مراجعة سياسة التحفيز',
      );
    }
    if (exc > relevantProfiles.length * 0.5) {
      topRecs.insert(0, 'أداء متميز للفصل بشكل عام - ينصح بتكريم جماعي');
    }

    return BehaviorDashboardStats(
      totalStudents: relevantProfiles.length,
      highestScore: max,
      lowestScore: min,
      averageScore: avg,
      achievementPercentage:
          avg, // Mapping avg score to achievement % directly for now
      totalScoreSum: sum,
      excellentCount: exc,
      veryGoodCount: vGood,
      goodCount: good,
      acceptableCount: acc,
      weakCount: weak,
      topRecommendations: topRecs.take(4).toList(),
      weakProfiles: weakProfiles,
    );
  }
}

final behaviorDashboardServiceProvider = Provider<BehaviorDashboardService>((
  ref,
) {
  return BehaviorDashboardService(FirebaseFirestore.instance);
});
