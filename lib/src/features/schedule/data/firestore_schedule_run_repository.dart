import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/schedule_run.dart';
import '../domain/teacher_preference_entity.dart';
import 'schedule_run_repository.dart';

final scheduleRunRepositoryProvider = Provider<ScheduleRunRepository>((ref) {
  return FirestoreScheduleRunRepository(FirebaseFirestore.instance);
});

class FirestoreScheduleRunRepository implements ScheduleRunRepository {
  final FirebaseFirestore _firestore;

  FirestoreScheduleRunRepository(this._firestore);

  @override
  Future<String> createScheduleRun(ScheduleRun run) async {
    final docRef = _firestore
        .collection('Schools')
        .doc(run.schoolId)
        .collection('ScheduleRuns')
        .doc(); // Auto ID
    
    final newRun = run.copyWith(id: docRef.id);
    await docRef.set(newRun.toMap());
    return docRef.id;
  }

  @override
  Future<void> updateScheduleRun(ScheduleRun run) async {
    await _firestore
        .collection('Schools')
        .doc(run.schoolId)
        .collection('ScheduleRuns')
        .doc(run.id)
        .update(run.toMap());
  }

  @override
  Future<ScheduleRun?> getScheduleRun(String schoolId, String runId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .doc(runId)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return ScheduleRun.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Stream<ScheduleRun?> watchScheduleRun(String schoolId, String runId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .doc(runId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ScheduleRun.fromMap(doc.data()!);
      }
      return null;
    });
  }

  @override
  Future<List<ScheduleRun>> listScheduleRuns(
    String schoolId, {
    ScheduleMode? mode,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (mode != null) {
      query = query.where('mode', isEqualTo: mode.name);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ScheduleRun.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> saveTeacherPreference(String schoolId, TeacherPreferenceEntity preference) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .doc(preference.scheduleRunId)
        .collection('TeacherPreferences')
        .doc(preference.teacherId)
        .set(preference.toMap());
  }

  @override
  Future<TeacherPreferenceEntity?> getTeacherPreference(String schoolId, String runId, String teacherId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .doc(runId)
        .collection('TeacherPreferences')
        .doc(teacherId)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return TeacherPreferenceEntity.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<List<TeacherPreferenceEntity>> getAllPreferences(String schoolId, String runId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleRuns')
        .doc(runId)
        .collection('TeacherPreferences')
        .get();
    
    return snapshot.docs.map((doc) => TeacherPreferenceEntity.fromMap(doc.data())).toList();
  }
}
