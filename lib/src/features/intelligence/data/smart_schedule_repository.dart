import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/scheduling/teacher_constraints_profile.dart';
import '../domain/scheduling/override_learning_log.dart';

final smartScheduleRepositoryProvider = Provider<SmartScheduleRepository>((ref) {
  return FirestoreSmartScheduleRepository();
});

abstract class SmartScheduleRepository {
  Future<TeacherConstraintsProfile?> getTeacherProfile(String teacherId);
  Future<void> saveTeacherProfile(TeacherConstraintsProfile profile);
  Future<void> logOverride(OverrideLearningLog log);
  Future<List<OverrideLearningLog>> getOverrides(String teacherId);
}

class FirestoreSmartScheduleRepository implements SmartScheduleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _profilesCollection = 'teacher_constraints_profiles';
  static const String _overridesCollection = 'schedule_override_logs';

  @override
  Future<TeacherConstraintsProfile?> getTeacherProfile(String teacherId) async {
    final doc = await _firestore.collection(_profilesCollection).doc(teacherId).get();
    if (!doc.exists) return null;
    return TeacherConstraintsProfile.fromMap(doc.data()!);
  }

  @override
  Future<void> saveTeacherProfile(TeacherConstraintsProfile profile) async {
    await _firestore
        .collection(_profilesCollection)
        .doc(profile.teacherId)
        .set(profile.toMap());
  }

  @override
  Future<void> logOverride(OverrideLearningLog log) async {
    await _firestore.collection(_overridesCollection).doc(log.id).set(log.toMap());
  }

  @override
  Future<List<OverrideLearningLog>> getOverrides(String teacherId) async {
    final snapshot = await _firestore
        .collection(_overridesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('timestamp', descending: true)
        .get();
    
    return snapshot.docs.map((d) => OverrideLearningLog.fromMap(d.data())).toList();
  }
}
