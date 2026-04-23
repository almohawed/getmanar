import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/student_behavior_profile.dart';

final behaviorProfileRepositoryProvider = Provider<FirestoreBehaviorProfileRepository>((ref) {
  return FirestoreBehaviorProfileRepository(FirebaseFirestore.instance);
});

final studentBehaviorProfileProvider = StreamProvider.family<StudentBehaviorProfile?, String>((ref, studentId) {
  final repository = ref.watch(behaviorProfileRepositoryProvider);
  return repository.watchStudentProfile(studentId);
});

class FirestoreBehaviorProfileRepository {
  final FirebaseFirestore _firestore;

  FirestoreBehaviorProfileRepository(this._firestore);

  Stream<StudentBehaviorProfile?> watchStudentProfile(String studentId) {
    return _firestore
        .collection('studentBehaviorProfiles')
        .doc(studentId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return StudentBehaviorProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }
}
