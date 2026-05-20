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
        .get();

    final list = snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<BehavioralViolation>> getViolationsByStudent(String studentId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .get();

    final list = snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
  
  Future<List<BehavioralViolation>> getPendingViolations(String schoolId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: ViolationStatus.pending.name)
        .get();

    final list = snapshot.docs
        .map((doc) => BehavioralViolation.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<List<BehavioralViolation>> streamPendingViolations(String schoolId) {
    return _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: ViolationStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => BehavioralViolation.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }
}

final violationsRepositoryProvider = Provider<FirestoreViolationsRepository>((ref) {
  return FirestoreViolationsRepository();
});
