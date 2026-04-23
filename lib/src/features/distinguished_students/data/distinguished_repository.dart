import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/distinguished_cycle.dart';
import '../domain/distinguished_nomination.dart';

class DistinguishedRepository {
  final FirebaseFirestore _firestore;

  DistinguishedRepository(this._firestore);

  // Cycle Management
  Future<DistinguishedCycle?> getCurrentCycle(String schoolId) async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedCycles')
        .where('endDate', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('endDate', descending: false)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return DistinguishedCycle.fromMap(snapshot.docs.first.data());
    }
    
    // If no active cycle, check for pending/published ones that are recent
    final recentSnapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedCycles')
        .orderBy('endDate', descending: true)
        .limit(1)
        .get();

     if (recentSnapshot.docs.isNotEmpty) {
       return DistinguishedCycle.fromMap(recentSnapshot.docs.first.data());
     }
     
    return null;
  }
  
  // Create a new cycle
  Future<void> createCycle(String schoolId, DistinguishedCycle cycle) async {
      await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedCycles')
        .doc(cycle.id)
        .set(cycle.toMap());
  }
  
  // Update cycle status
  Future<void> updateCycle(String schoolId, DistinguishedCycle cycle) async {
      await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedCycles')
        .doc(cycle.id)
        .update(cycle.toMap());
  }

  // Nomination Management
  Future<void> saveNominations(String schoolId, List<DistinguishedNomination> nominations) async {
    final batch = _firestore.batch();
    for (var nom in nominations) {
      final ref = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedNominations')
        .doc(nom.id);
      batch.set(ref, nom.toMap());
    }
    await batch.commit();
  }

  Future<List<DistinguishedNomination>> getNominations(String schoolId, String cycleId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedNominations')
        .where('cycleId', isEqualTo: cycleId)
        .orderBy('score', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => DistinguishedNomination.fromMap(doc.data())).toList();
  }
  
  Future<void> updateNomination(String schoolId, DistinguishedNomination nomination) async {
     await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedNominations')
        .doc(nomination.id)
        .update(nomination.toMap());
  }
  
  // Get Final Published List (for public view)
  Stream<List<DistinguishedNomination>> watchPublishedStudents(String schoolId) {
    // We need to find the latest published cycle first? 
    // Or just query nominations that are isFinal=true and belong to a recent published cycle.
    // To keep it simple, we watch nominations where isFinal == true
    // And optionally filter by cycleId if we have it in context, but for "Last Week" logic,
    // we might need to filter by cycle end date.
    // For now, let's just return all final ones and filter in UI or Service.
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DistinguishedNominations')
        .where('isFinal', isEqualTo: true)
        // .orderBy('score', descending: true) // Requires index with isFinal
        .snapshots()
        .map((s) => s.docs.map((d) => DistinguishedNomination.fromMap(d.data())).toList());
  }
}

final distinguishedRepositoryProvider = Provider<DistinguishedRepository>((ref) {
  return DistinguishedRepository(FirebaseFirestore.instance);
});
