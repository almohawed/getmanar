import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/audit_log.dart';
import '../domain/school_health_index.dart';
import '../../../core/domain/models/behavior_record.dart';

final firestoreIntelligenceRepositoryProvider = Provider(
  (ref) => FirestoreIntelligenceRepository(),
);

class FirestoreIntelligenceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logAction(AuditLog log) async {
    await _firestore.collection('audit_logs').doc(log.id).set(log.toMap());
  }

  Future<List<AuditLog>> getLogs(String schoolId, {int limit = 50}) async {
    final snapshot = await _firestore
        .collection('audit_logs')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => AuditLog.fromMap(doc.data())).toList();
  }

  Future<SchoolHealthIndex> getSchoolHealthIndex(String schoolId) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('PROOF_LOG: Loading SchoolHealthReports for School: $schoolId');

    try {
      final reportsSnap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('SchoolHealthReports')
          .orderBy('weekKey', descending: true)
          .limit(1)
          .get();

      if (reportsSnap.docs.isNotEmpty) {
        final data = reportsSnap.docs.first.data();
        final overallScore =
            (data['overallScore'] as num?)?.toDouble() ?? 100.0;
        final behaviorScore =
            (data['behaviorScore'] as num?)?.toDouble() ?? overallScore;
        final attendanceScore =
            (data['attendanceScore'] as num?)?.toDouble() ?? 100.0;
        final stabilityScore =
            (data['stabilityScore'] as num?)?.toDouble() ??
                (behaviorScore + attendanceScore) / 2;
        final alerts =
            (data['criticalAlerts'] as List<dynamic>?)?.cast<String>() ?? [];

        stopwatch.stop();
        return SchoolHealthIndex(
          overallScore: overallScore,
          behaviorScore: behaviorScore,
          attendanceScore: attendanceScore,
          stabilityScore: stabilityScore,
          familyEngagementScore: 100.0,
          criticalAlerts: alerts,
          weekStart: DateTime.now().subtract(const Duration(days: 7)),
        );
      }
    } catch (e) {
      debugPrint('PROOF_LOG: Failed to read SchoolHealthReports: $e');
    }

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    List<BehaviorRecord> behaviors = [];

    try {
      final classesSnapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .get();

      final classIds = classesSnapshot.docs.map((doc) => doc.id).toList();

      if (classIds.isNotEmpty) {
        debugPrint(
          'PROOF_LOG: Fallback Health Index by class, ${classIds.length} classes',
        );
        final futures = classIds.map((classId) {
          return _firestore
              .collection('behavior_records')
              .where('schoolId', isEqualTo: schoolId)
              .where('classId', isEqualTo: classId)
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();
        });

        final results = await Future.wait(futures);

        for (var snapshot in results) {
          behaviors.addAll(
            snapshot.docs
                .map((doc) => BehaviorRecord.fromMap(doc.data()))
                .where(
                  (b) => b.timestamp.isAfter(sevenDaysAgo),
                ),
          );
        }

        behaviors.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        debugPrint(
          'PROOF_LOG: No classes found. Attempting direct school query...',
        );
        final behaviorSnapshot = await _firestore
            .collection('behavior_records')
            .where('schoolId', isEqualTo: schoolId)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();

        behaviors = behaviorSnapshot.docs
            .map((doc) => BehaviorRecord.fromMap(doc.data()))
            .where((b) => b.timestamp.isAfter(sevenDaysAgo))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching behaviors in Intelligence Repo: $e');
      try {
        debugPrint('PROOF_LOG: Primary fetch failed. Attempting Fallback Query...');
        final behaviorSnapshot = await _firestore
            .collection('behavior_records')
            .where('schoolId', isEqualTo: schoolId)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();

        behaviors = behaviorSnapshot.docs
            .map((doc) => BehaviorRecord.fromMap(doc.data()))
            .where((b) => b.timestamp.isAfter(sevenDaysAgo))
            .toList();
      } catch (e2) {
        // ignore: avoid_print
        print('Fallback failed: $e2');
        rethrow;
      }
    }

    stopwatch.stop();
    debugPrint(
      'PROOF_LOG: Health Index Fallback Query Completed in ${stopwatch.elapsedMilliseconds}ms',
    );

    final totalBehaviors = behaviors.length;
    final negativeBehaviors = behaviors
        .where((b) => b.type == BehaviorType.negative)
        .length;
    final positiveBehaviors = behaviors
        .where((b) => b.type == BehaviorType.positive)
        .length;

    double behaviorScore = 100.0;
    if (totalBehaviors > 0 && positiveBehaviors + negativeBehaviors > 0) {
      behaviorScore =
          (positiveBehaviors / (positiveBehaviors + negativeBehaviors)) * 100;
    }

    double attendanceScore = 100.0;
    double stabilityScore = (behaviorScore + attendanceScore) / 2;

    List<String> alerts = [];
    if (behaviorScore < 70) {
      alerts.add('مؤشر السلوك منخفض هذا الأسبوع.');
    }
    if (negativeBehaviors > 50) {
      alerts.add(
        'ارتفاع ملحوظ في المخالفات السلوكية ($negativeBehaviors مخالفة).',
      );
    }

    return SchoolHealthIndex(
      overallScore: stabilityScore,
      behaviorScore: behaviorScore,
      attendanceScore: attendanceScore,
      stabilityScore: stabilityScore,
      familyEngagementScore: 100.0,
      criticalAlerts: alerts,
      weekStart: DateTime.now().subtract(const Duration(days: 7)),
    );
  }
}
