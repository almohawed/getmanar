import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../academic/domain/classroom.dart';

final firestoreClassRepositoryProvider = Provider<FirestoreClassRepository>((ref) {
  return FirestoreClassRepository(FirebaseFirestore.instance);
});

class FirestoreClassRepository {
  final FirebaseFirestore _firestore;

  FirestoreClassRepository(this._firestore);

  Future<List<Classroom>> getClasses(String schoolId) async {
    if (schoolId.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .get();

      return snapshot.docs.map((doc) => Classroom.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      return [];
    }
  }

  Stream<List<Classroom>> getClassesStream(String schoolId) {
    if (schoolId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Classroom.fromMap(doc.data())).toList();
    });
  }

  Future<Classroom?> getClassById(String schoolId, String classId) async {
    try {
      final doc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .doc(classId)
          .get();

      if (doc.exists) {
        return Classroom.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching class: $e');
      return null;
    }
  }

  Future<void> addClass(String schoolId, Classroom classroom) async {
    if (schoolId.isEmpty) {
      throw Exception('School ID مفقود أثناء إنشاء الفصل، لن يتم الحفظ.');
    }
    if (kDebugMode) {
      debugPrint(
        'Saving class to path: Schools/$schoolId/Classes/${classroom.id}',
      );
    }
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .doc(classroom.id)
        .set(classroom.toMap());
  }

  Future<void> addClassesBatch(String schoolId, List<Classroom> classes) async {
    if (schoolId.isEmpty) {
      throw Exception('School ID مفقود أثناء إنشاء الفصول، لن يتم الحفظ.');
    }
    if (classes.isEmpty) return;

    const maxWritesPerBatch = 450;
    for (var i = 0; i < classes.length; i += maxWritesPerBatch) {
      final chunk = classes.sublist(
        i,
        (i + maxWritesPerBatch) > classes.length
            ? classes.length
            : (i + maxWritesPerBatch),
      );
      final batch = _firestore.batch();
      for (final c in chunk) {
        final docRef = _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Classes')
            .doc(c.id);
        batch.set(docRef, c.toMap());
      }
      await batch.commit();
    }
  }

  Future<void> updateClass(String schoolId, Classroom classroom) async {
    if (schoolId.isEmpty) {
      throw Exception('School ID مفقود أثناء تحديث الفصل، لن يتم الحفظ.');
    }
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .doc(classroom.id)
        .update(classroom.toMap());
  }

  Future<void> deleteClasses(String schoolId, List<String> ids) async {
    final batch = _firestore.batch();
    for (var id in ids) {
      final docRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .doc(id);
      batch.delete(docRef);
    }
    await batch.commit();
  }
}

final classRepositoryProvider = Provider<FirestoreClassRepository>((ref) {
  return FirestoreClassRepository(FirebaseFirestore.instance);
});
