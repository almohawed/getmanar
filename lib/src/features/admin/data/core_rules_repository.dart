import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/core_rule.dart';

class CoreRulesRepository {
  final FirebaseFirestore _firestore;

  CoreRulesRepository(this._firestore);

  CollectionReference _getCollection(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CoreRules');
  }

  Stream<List<CoreRule>> getRules(String schoolId) {
    return _getCollection(
      schoolId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CoreRule.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addRule(String schoolId, CoreRule rule) async {
    await _getCollection(schoolId).doc(rule.id).set(rule.toMap());
  }

  Future<void> updateRule(String schoolId, CoreRule rule) async {
    await _getCollection(schoolId).doc(rule.id).update(rule.toMap());
  }

  Future<void> deleteRule(String schoolId, String ruleId) async {
    await _getCollection(schoolId).doc(ruleId).delete();
  }

  Future<void> toggleRuleStatus(
    String schoolId,
    String ruleId,
    bool isActive,
  ) async {
    await _getCollection(schoolId).doc(ruleId).update({'isActive': isActive});
  }
}

final coreRulesRepositoryProvider = Provider<CoreRulesRepository>((ref) {
  return CoreRulesRepository(FirebaseFirestore.instance);
});

final coreRulesStreamProvider = StreamProvider<List<CoreRule>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.value;
  if (user == null || user.schoolId == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(coreRulesRepositoryProvider);
  return repository.getRules(user.schoolId!);
});
