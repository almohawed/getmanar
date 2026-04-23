import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

class FirstActionPlan {
  final String id;
  final String schoolId;
  final String sourceType;
  final String sourceName;
  final String priorityReason;
  final int timeWindowHours;
  final String actionId;
  final String actionTitle;
  final String todayStep;
  final String tomorrowStep;
  final String endOfWeekStep;
  final String successMetric;

  FirstActionPlan({
    required this.id,
    required this.schoolId,
    required this.sourceType,
    required this.sourceName,
    required this.priorityReason,
    required this.timeWindowHours,
    required this.actionId,
    required this.actionTitle,
    required this.todayStep,
    required this.tomorrowStep,
    required this.endOfWeekStep,
    required this.successMetric,
  });

  factory FirstActionPlan.fromMap(String id, Map<String, dynamic> data) {
    return FirstActionPlan(
      id: id,
      schoolId: data['schoolId'] ?? '',
      sourceType: data['sourceType'] ?? '',
      sourceName: data['sourceName'] ?? '',
      priorityReason: data['priorityReason'] ?? '',
      timeWindowHours: data['timeWindowHours'] is int
          ? data['timeWindowHours'] as int
          : int.tryParse('${data['timeWindowHours']}') ?? 48,
      actionId: data['actionId'] ?? '',
      actionTitle: data['actionTitle'] ?? '',
      todayStep: data['todayStep'] ?? '',
      tomorrowStep: data['tomorrowStep'] ?? '',
      endOfWeekStep: data['endOfWeekStep'] ?? '',
      successMetric: data['successMetric'] ?? '',
    );
  }
}

final firstActionServiceProvider = Provider<FirstActionService>((ref) {
  return FirstActionService(FirebaseFirestore.instance, ref);
});

final firstActionPlanProvider =
    StreamProvider.autoDispose<FirstActionPlan?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (schoolId == null || schoolId.isEmpty) {
    return const Stream.empty();
  }
  final service = ref.watch(firstActionServiceProvider);
  return service.watchFirstActionForSchool(schoolId);
});

class FirstActionService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  FirstActionService(this._firestore, this._ref);

  Stream<FirstActionPlan?> watchFirstActionForSchool(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('BehaviorFirstActions')
        .orderBy('weekKey', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return FirstActionPlan.fromMap(doc.id, doc.data());
    }).handleError((e, s) {
      debugPrint('Error loading FirstActionPlan: $e');
    });
  }

  Future<void> logExecution(FirstActionPlan plan) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) return;
    final schoolId = user.schoolId!;
    final db = _firestore;

    final batch = db.batch();

    final actionRef = db
        .collection('Schools')
        .doc(schoolId)
        .collection('DeputyActions')
        .doc();

    batch.set(actionRef, {
      'schoolId': schoolId,
      'createdBy': user.id,
      'createdByName': user.name,
      'role': user.role.name,
      'firstActionId': plan.id,
      'actionId': plan.actionId,
      'actionTitle': plan.actionTitle,
      'sourceType': plan.sourceType,
      'sourceName': plan.sourceName,
      'weekKey': DateTime.now().toIso8601String().substring(0, 10),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'done',
      'channel': 'behavior_index',
    });

    batch.commit();
  }
}

