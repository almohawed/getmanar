import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../behavior/domain/models/student_behavior_profile.dart';
import '../domain/school_health_index.dart';

class SchoolIntelligenceSnapshot {
  final String id;
  final String termId;
  final double schoolHealthScore;
  final List<String> riskClasses;
  final List<String> riskSubjects;
  final List<String> riskTeachers;
  final double? avgAttendanceRate;
  final double? avgScore;
  final int? riskCountRed;
  final int? riskCountYellow;
  final DateTime generatedAt;
  SchoolIntelligenceSnapshot({
    required this.id,
    required this.termId,
    required this.schoolHealthScore,
    required this.riskClasses,
    required this.riskSubjects,
    required this.riskTeachers,
    this.avgAttendanceRate,
    this.avgScore,
    this.riskCountRed,
    this.riskCountYellow,
    required this.generatedAt,
  });
  factory SchoolIntelligenceSnapshot.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data()!;
    return SchoolIntelligenceSnapshot(
      id: d.id,
      termId: m['termId'] ?? '',
      schoolHealthScore: (m['schoolHealthScore'] ?? 0.0).toDouble(),
      riskClasses:
          (m['riskClasses'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      riskSubjects:
          (m['riskSubjects'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      riskTeachers:
          (m['riskTeachers'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      avgAttendanceRate: (m['avgAttendanceRate'] is num)
          ? (m['avgAttendanceRate'] as num).toDouble()
          : null,
      avgScore: (m['avgScore'] is num)
          ? (m['avgScore'] as num).toDouble()
          : null,
      riskCountRed: (m['riskCountRed'] is num)
          ? (m['riskCountRed'] as num).toInt()
          : null,
      riskCountYellow: (m['riskCountYellow'] is num)
          ? (m['riskCountYellow'] as num).toInt()
          : null,
      generatedAt: (m['generatedAt'] as Timestamp).toDate(),
    );
  }

  factory SchoolIntelligenceSnapshot.fromMap(
    String id,
    Map<String, dynamic> m,
  ) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is Map) {
        final sec = v['_seconds'] ?? v['seconds'];
        final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
        final s = sec is num ? sec.toInt() : int.tryParse(sec.toString());
        final n = nanos is num ? nanos.toInt() : int.tryParse(nanos.toString());
        if (s != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (s * 1000) + (((n ?? 0) / 1000000).round()),
          );
        }
      }
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    List<String> toStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const <String>[];
    }

    return SchoolIntelligenceSnapshot(
      id: id,
      termId: (m['termId'] ?? '').toString(),
      schoolHealthScore: (m['schoolHealthScore'] ?? 0.0) is num
          ? (m['schoolHealthScore'] as num).toDouble()
          : double.tryParse(m['schoolHealthScore']?.toString() ?? '0') ?? 0.0,
      riskClasses: toStringList(m['riskClasses']),
      riskSubjects: toStringList(m['riskSubjects']),
      riskTeachers: toStringList(m['riskTeachers']),
      avgAttendanceRate: (m['avgAttendanceRate'] is num)
          ? (m['avgAttendanceRate'] as num).toDouble()
          : double.tryParse(m['avgAttendanceRate']?.toString() ?? ''),
      avgScore: (m['avgScore'] is num)
          ? (m['avgScore'] as num).toDouble()
          : double.tryParse(m['avgScore']?.toString() ?? ''),
      riskCountRed: (m['riskCountRed'] is num)
          ? (m['riskCountRed'] as num).toInt()
          : int.tryParse(m['riskCountRed']?.toString() ?? ''),
      riskCountYellow: (m['riskCountYellow'] is num)
          ? (m['riskCountYellow'] as num).toInt()
          : int.tryParse(m['riskCountYellow']?.toString() ?? ''),
      generatedAt: parseDate(m['generatedAt']),
    );
  }
}

class RiskPrediction {
  final String id;
  final String studentId;
  final String subjectId;
  final String riskLevel;
  final List<String> riskFactors;
  final List<String> generatedActions;
  final DateTime generatedAt;
  RiskPrediction({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.riskLevel,
    required this.riskFactors,
    required this.generatedActions,
    required this.generatedAt,
  });
  factory RiskPrediction.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return RiskPrediction(
      id: d.id,
      studentId: m['studentId'] ?? '',
      subjectId: m['subjectId'] ?? '',
      riskLevel: m['riskLevel'] ?? 'GREEN',
      riskFactors:
          (m['riskFactors'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      generatedActions:
          (m['generatedActions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      generatedAt: (m['generatedAt'] as Timestamp).toDate(),
    );
  }

  factory RiskPrediction.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is Map) {
        final sec = v['_seconds'] ?? v['seconds'];
        final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
        final s = sec is num ? sec.toInt() : int.tryParse(sec.toString());
        final n = nanos is num ? nanos.toInt() : int.tryParse(nanos.toString());
        if (s != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (s * 1000) + (((n ?? 0) / 1000000).round()),
          );
        }
      }
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String)
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    List<String> toStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const <String>[];
    }

    return RiskPrediction(
      id: id,
      studentId: (m['studentId'] ?? '').toString(),
      subjectId: (m['subjectId'] ?? '').toString(),
      riskLevel: (m['riskLevel'] ?? 'GREEN').toString(),
      riskFactors: toStringList(m['riskFactors']),
      generatedActions: toStringList(m['generatedActions']),
      generatedAt: parseDate(m['generatedAt']),
    );
  }
}

class RemedialPlan {
  final String id;
  final List<String> studentIds;
  final String causeType;
  final String strategy;
  final String teacherId;
  final Map<String, dynamic> baselineMetrics;
  final Map<String, dynamic> targetMetrics;
  final String status;
  final double improvementScore;

  // Audit & Confidence Fields
  final DateTime? createdAt;
  final DateTime? baselineStart;
  final DateTime? baselineEnd;
  final DateTime? lastCalculatedAt;
  final String confidenceLevel; // 'high', 'medium', 'low'
  final String
  effectivenessStatus; // 'measuring', 'improved', 'stable', 'needs_support'

  RemedialPlan({
    required this.id,
    required this.studentIds,
    required this.causeType,
    required this.strategy,
    required this.teacherId,
    required this.baselineMetrics,
    required this.targetMetrics,
    required this.status,
    required this.improvementScore,
    this.createdAt,
    this.baselineStart,
    this.baselineEnd,
    this.lastCalculatedAt,
    this.confidenceLevel = 'low',
    this.effectivenessStatus = 'measuring',
  });
  factory RemedialPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return RemedialPlan(
      id: d.id,
      studentIds:
          (m['studentIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      causeType: m['causeType'] ?? '',
      strategy: m['strategy'] ?? '',
      teacherId: m['teacherId'] ?? '',
      baselineMetrics:
          (m['baselineMetrics'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          const {},
      targetMetrics:
          (m['targetMetrics'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          const {},
      status: m['status'] ?? 'active',
      improvementScore: (m['improvementScore'] ?? 0.0).toDouble(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      baselineStart: (m['baselineStart'] as Timestamp?)?.toDate(),
      baselineEnd: (m['baselineEnd'] as Timestamp?)?.toDate(),
      lastCalculatedAt: (m['lastCalculatedAt'] as Timestamp?)?.toDate(),
      confidenceLevel: m['confidenceLevel'] ?? 'low',
      effectivenessStatus: m['effectivenessStatus'] ?? 'measuring',
    );
  }

  factory RemedialPlan.fromMap(String id, Map<String, dynamic> m) {
    DateTime? parseOptDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is Map) {
        final sec = v['_seconds'] ?? v['seconds'];
        final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
        final s = sec is num ? sec.toInt() : int.tryParse(sec.toString());
        final n = nanos is num ? nanos.toInt() : int.tryParse(nanos.toString());
        if (s != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (s * 1000) + (((n ?? 0) / 1000000).round()),
          );
        }
      }
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> toStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const <String>[];
    }

    Map<String, dynamic> toStringKeyMap(dynamic v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val));
      }
      return const <String, dynamic>{};
    }

    return RemedialPlan(
      id: id,
      studentIds: toStringList(m['studentIds']),
      causeType: (m['causeType'] ?? '').toString(),
      strategy: (m['strategy'] ?? '').toString(),
      teacherId: (m['teacherId'] ?? '').toString(),
      baselineMetrics: toStringKeyMap(m['baselineMetrics']),
      targetMetrics: toStringKeyMap(m['targetMetrics']),
      status: (m['status'] ?? 'active').toString(),
      improvementScore: (m['improvementScore'] ?? 0.0) is num
          ? (m['improvementScore'] as num).toDouble()
          : double.tryParse(m['improvementScore']?.toString() ?? '0') ?? 0.0,
      createdAt: parseOptDate(m['createdAt']),
      baselineStart: parseOptDate(m['baselineStart']),
      baselineEnd: parseOptDate(m['baselineEnd']),
      lastCalculatedAt: parseOptDate(m['lastCalculatedAt']),
      confidenceLevel: (m['confidenceLevel'] ?? 'low').toString(),
      effectivenessStatus: (m['effectivenessStatus'] ?? 'measuring').toString(),
    );
  }
}

class FirestoreSchoolIntelligenceRepository {
  final FirebaseFirestore _firestore;
  FirestoreSchoolIntelligenceRepository(this._firestore);

  Future<SchoolIntelligenceSnapshot?> getLatestSnapshotOnce(
    String schoolId,
  ) async {
    final q = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return SchoolIntelligenceSnapshot.fromDoc(q.docs.first);
  }

  Future<List<RiskPrediction>> getRiskPredictionsOnce(String schoolId) async {
    final q = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RiskPredictions')
        .orderBy('generatedAt', descending: true)
        .limit(200)
        .get();
    return q.docs.map(RiskPrediction.fromDoc).toList();
  }

  Future<List<RemedialPlan>> getRemedialPlansOnce(
    String schoolId, {
    String? status,
  }) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans');
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    final snap = await q.orderBy('teacherId').limit(300).get();
    return snap.docs.map(RemedialPlan.fromDoc).toList();
  }

  Stream<SchoolIntelligenceSnapshot?> watchLatestSnapshot(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (s) => s.docs.isEmpty
              ? null
              : SchoolIntelligenceSnapshot.fromDoc(s.docs.first),
        );
  }

  Stream<List<RiskPrediction>> watchRiskPredictions(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RiskPredictions')
        .orderBy('generatedAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map(RiskPrediction.fromDoc).toList());
  }

  Stream<List<RemedialPlan>> watchRemedialPlans(
    String schoolId, {
    String? status,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans');
    if (status != null && status.isNotEmpty)
      q = q.where('status', isEqualTo: status);
    return q
        .orderBy('teacherId')
        .snapshots()
        .map((s) => s.docs.map(RemedialPlan.fromDoc).toList());
  }

  Future<SchoolHealthIndex?> getSchoolHealthIndex(String schoolId) async {
    final query = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final snapshot = SchoolIntelligenceSnapshot.fromDoc(query.docs.first);
    return SchoolHealthIndex(
      overallScore: snapshot.schoolHealthScore,
      behaviorScore: 85.0, // Default/Placeholder
      attendanceScore: 85.0, // Default/Placeholder
      stabilityScore: 85.0, // Default/Placeholder
      familyEngagementScore: 85.0, // Default/Placeholder
      criticalAlerts: [...snapshot.riskClasses, ...snapshot.riskSubjects],
      weekStart: snapshot.generatedAt,
    );
  }

  Future<void> updateRemedialProgress(
    String schoolId,
    String planId,
    Map<String, dynamic> delta,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .doc(planId)
        .update(delta);
  }

  /// Calculates and updates the effectiveness of a remedial plan based on current student behavior.
  /// This implements the "Intervention Effectiveness" (فعالية التعزيز) logic.
  Future<void> updatePlanEffectiveness(String schoolId, String planId) async {
    final planDoc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .doc(planId)
        .get();

    if (!planDoc.exists) return;
    final plan = RemedialPlan.fromDoc(planDoc);

    if (plan.studentIds.isEmpty) return;

    // 1. Check Operating Period (Measuring Window)
    // Rule: Plan must be active for at least 7 days before measuring effectiveness.
    final now = DateTime.now();
    final createdAt = plan.createdAt ?? now;
    final daysActive = now.difference(createdAt).inDays;

    if (daysActive < 7) {
      // Too early to measure
      await updateRemedialProgress(schoolId, planId, {
        'effectivenessStatus': 'measuring',
        'confidenceLevel': 'low',
        'lastCalculatedAt': Timestamp.fromDate(now),
      });
      return;
    }

    // 2. Calculate current average behavior score for students in the plan
    double currentTotalScore = 0;
    int studentCount = 0;

    for (final studentId in plan.studentIds) {
      final profileDoc = await _firestore
          .collection('studentBehaviorProfiles')
          .doc(studentId)
          .get();
      if (profileDoc.exists) {
        final profile = StudentBehaviorProfile.fromMap(profileDoc.data()!);
        currentTotalScore += profile.score;
        studentCount++;
      }
    }

    if (studentCount == 0) return;

    final double currentAvg = currentTotalScore / studentCount;
    // Fallback: If baseline is missing, use a default or previous metrics.
    // Ideally, baseline should be calculated from historical data (7 days before creation).
    // For now, we rely on what's stored in baselineMetrics.
    final double baselineAvg =
        (plan.baselineMetrics['averageBehaviorScore'] ?? 0).toDouble();

    // 3. Calculate Improvement (Effectiveness) with Safety Checks
    double improvement = 0.0;

    // Safety: Handle zero baseline using max(baseline, 1) to avoid division by zero
    final double safeBaseline = baselineAvg > 0 ? baselineAvg : 1.0;

    // Formula: ((Current - Baseline) / Baseline) * 100
    improvement = ((currentAvg - safeBaseline) / safeBaseline) * 100;

    // Safety: Clamp extreme values (-100% to +100%) to remove noise
    if (improvement > 100) improvement = 100;
    if (improvement < -100) improvement = -100;

    // 4. Determine Status & Confidence
    String status = 'stable';
    if (improvement >= 5.0) status = 'improved'; // +5% threshold
    if (improvement <= -5.0) status = 'needs_support'; // -5% threshold

    // Confidence Calculation
    // High: > 10 students AND > 14 days active
    // Medium: > 5 students AND > 7 days active
    // Low: Small group or short period
    String confidence = 'low';
    if (studentCount >= 10 && daysActive >= 14) {
      confidence = 'high';
    } else if (studentCount >= 5 && daysActive >= 7) {
      confidence = 'medium';
    }

    // 5. Update the plan with Audit Trail
    await updateRemedialProgress(schoolId, planId, {
      'improvementScore': improvement,
      'effectivenessStatus': status,
      'confidenceLevel': confidence,
      'lastCalculatedAt': Timestamp.fromDate(now),
      'currentMetrics': {'averageBehaviorScore': currentAvg},
      // Optional: Store window details if we had historical data queries
      'measureEnd': Timestamp.fromDate(now),
    });
  }

  Future<void> writeSnapshot(
    String schoolId,
    Map<String, dynamic> snapshot,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SchoolIntelligence')
        .add({...snapshot, 'generatedAt': Timestamp.fromDate(DateTime.now())});
  }

  Future<void> upsertPrediction(
    String schoolId,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RiskPredictions')
        .doc(docId)
        .set({...data, 'generatedAt': Timestamp.fromDate(DateTime.now())});
  }

  Future<void> createRemedialPlan(
    String schoolId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .add({
          ...data,
          'status': data['status'] ?? 'active',
          'improvementScore': data['improvementScore'] ?? 0.0,
        });
  }
}

final schoolIntelligenceRepositoryProvider =
    Provider<FirestoreSchoolIntelligenceRepository>(
      (ref) =>
          FirestoreSchoolIntelligenceRepository(FirebaseFirestore.instance),
    );
