import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/teacher_note.dart';

final teacherNoteRepositoryProvider = Provider<TeacherNoteRepository>((ref) {
  return FirestoreTeacherNoteRepository();
});

abstract class TeacherNoteRepository {
  Future<void> addNote(TeacherNote note);
  Future<void> updateNote(TeacherNote note);
  Future<void> deleteNote(String noteId, {String? schoolId});
  Future<List<TeacherNote>> getTeacherNotes(
    String teacherId, {
    String? schoolId,
  });
}

class FirestoreTeacherNoteRepository implements TeacherNoteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getCollection() {
    return _firestore.collection('teacher_notes');
  }

  @override
  Future<void> addNote(TeacherNote note) async {
    await _getCollection().doc(note.id).set(note.toMap());
  }

  @override
  Future<void> updateNote(TeacherNote note) async {
    await _getCollection().doc(note.id).update(note.toMap());
  }

  @override
  Future<void> deleteNote(String noteId, {String? schoolId}) async {
    await _getCollection().doc(noteId).delete();
  }

  @override
  Future<List<TeacherNote>> getTeacherNotes(
    String teacherId, {
    String? schoolId,
  }) async {
    Query query = _getCollection().where('teacherId', isEqualTo: teacherId);

    if (schoolId != null && schoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }

    final snapshot = await query.get();

    final notes = snapshot.docs
        .map((doc) => TeacherNote.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notes;
  }
}
