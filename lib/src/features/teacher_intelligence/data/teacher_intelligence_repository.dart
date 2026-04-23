import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/teacher_behavior_profile.dart';

final teacherIntelligenceRepositoryProvider =
    Provider<TeacherIntelligenceRepository>((ref) {
      return TeacherIntelligenceRepository(FirebaseFirestore.instance);
    });

class TeacherIntelligenceRepository {
  final FirebaseFirestore _firestore;

  TeacherIntelligenceRepository(this._firestore);

  Stream<List<TeacherBehaviorProfile>> watchSchoolProfiles(String schoolId) {
    return _firestore
        .collection('teacherBehaviorProfiles')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TeacherBehaviorProfile.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<TeacherBehaviorProfile?> getTeacherProfile(String teacherId) async {
    final doc = await _firestore
        .collection('teacherBehaviorProfiles')
        .doc(teacherId)
        .get();

    if (!doc.exists) return null;
    return TeacherBehaviorProfile.fromMap(doc.data()!);
  }
}
