import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/behavioral_violation.dart';

class FirestoreViolationsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'behavioral_violations';

  Future<void> addViolation(BehavioralViolation violation) async {
    await _firestore
        .collection(_collection)
        .doc(violation.id)
        .set(violation.toMap());
  }

  Future<void> updateViolation(BehavioralViolation violation) async {
    await _firestore
        .collection(_collection)
        .doc(violation.id)
        .update(violation.toMap());
  }

  Future<List<BehavioralViolation>> getViolationsBySchool(String schoolId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
  }

  Future<List<BehavioralViolation>> getViolationsByStudent(String studentId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
  }
  
  Future<List<BehavioralViolation>> getPendingViolations(String schoolId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: ViolationStatus.pending.name)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
  }

  Stream<List<BehavioralViolation>> streamPendingViolations(String schoolId) {
    return _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: ViolationStatus.pending.name)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BehavioralViolation.fromMap(doc.data()))
            .toList());
  }
}

final violationsRepositoryProvider = Provider<FirestoreViolationsRepository>((ref) {
  return FirestoreViolationsRepository();
});
