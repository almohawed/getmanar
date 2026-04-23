import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/bathroom_pass.dart';

abstract class BathroomRepository {
  Future<void> addPass(BathroomPass pass);
  Future<void> updatePass(BathroomPass pass);
  Future<BathroomPass?> getActivePass(String studentId);
  Stream<List<BathroomPass>> watchActivePasses(String schoolId);
}

class FirestoreBathroomRepository implements BathroomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> addPass(BathroomPass pass) async {
    if (pass.schoolId == null) throw Exception('School ID is required');
    await _firestore
        .collection('Schools')
        .doc(pass.schoolId)
        .collection('BathroomPasses')
        .doc(pass.id)
        .set(pass.toMap());
  }

  @override
  Future<void> updatePass(BathroomPass pass) async {
    if (pass.schoolId == null) throw Exception('School ID is required');
    await _firestore
        .collection('Schools')
        .doc(pass.schoolId)
        .collection('BathroomPasses')
        .doc(pass.id)
        .update(pass.toMap());
  }

  @override
  Future<BathroomPass?> getActivePass(String studentId) async {
    // We need to query across all schools or we need schoolId.
    // Assuming we query by collection group or if we know schoolId.
    // Ideally we should know schoolId. But usually getActivePass is by studentId.
    // Student should belong to one school.
    // For efficiency, let's use CollectionGroup query if schoolId is not provided,
    // OR require schoolId. But here we only have studentId.
    // The user's requirement says "active pass guard" on Create, which implies uniqueness per student.
    
    // Let's use collectionGroup for finding active pass by studentId
    final snapshot = await _firestore
        .collectionGroup('BathroomPasses')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: ['approved', 'locked_red']) // Active statuses
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return BathroomPass.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  @override
  Stream<List<BathroomPass>> watchActivePasses(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('BathroomPasses')
        .where('status', whereIn: ['approved', 'locked_red'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BathroomPass.fromMap(doc.data(), doc.id))
            .toList());
  }
}

final bathroomRepositoryProvider = Provider<BathroomRepository>((ref) {
  return FirestoreBathroomRepository();
});
