import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/offline_storage_service.dart';
import '../domain/assignment.dart';
import '../../auth/presentation/auth_controller.dart';

class FirestoreAssignmentsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineStorageService? _offlineStorage;
  static const String _collection = 'assignments';

  FirestoreAssignmentsRepository({OfflineStorageService? offlineStorage})
    : _offlineStorage = offlineStorage;

  Future<void> addAssignment(Assignment assignment) async {
    final storage = _offlineStorage;
    if (!kIsWeb && storage != null && !(await storage.isOnline())) {
      await storage.queueOperation('ADD_ASSIGNMENT', assignment.toMap());
      return;
    }

    await _firestore
        .collection(_collection)
        .doc(assignment.id)
        .set(assignment.toMap());
  }

  Future<void> updateAssignment(Assignment assignment) async {
    final storage = _offlineStorage;
    if (storage != null && !(await storage.isOnline())) {
      await storage.queueOperation('UPDATE_ASSIGNMENT', assignment.toMap());
      return;
    }

    await _firestore
        .collection(_collection)
        .doc(assignment.id)
        .update(assignment.toMap());
  }

  Future<void> deleteAssignment(String id) async {
    final storage = _offlineStorage;
    if (storage != null && !(await storage.isOnline())) {
      await storage.queueOperation('DELETE_ASSIGNMENT', {'id': id});
      return;
    }

    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<List<Assignment>> getAssignmentsForStudent(
    String studentId, {
    String? schoolId,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId);
    final normalizedSchoolId = schoolId?.trim();
    if (normalizedSchoolId != null && normalizedSchoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: normalizedSchoolId);
    }

    final snapshot = await query.get();

    final assignments = snapshot.docs
        .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
        .where((a) => a.published != false)
        .toList();

    // Sort client-side
    assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return assignments;
  }

  Stream<List<Assignment>> getAssignmentsForStudentStream(
    String studentId, {
    String? schoolId,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId);
    final normalizedSchoolId = schoolId?.trim();
    if (normalizedSchoolId != null && normalizedSchoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: normalizedSchoolId);
    }

    return query.snapshots().map((snapshot) {
      final assignments = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
          .where((a) => a.published != false)
          .toList();
      // Sort client-side
      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return assignments;
    });
  }

  Future<void> submitAssignment(String id) async {
    final storage = _offlineStorage;
    if (storage != null && !(await storage.isOnline())) {
      await storage.queueOperation('SUBMIT_ASSIGNMENT', {'id': id});
      return;
    }

    await _firestore.collection(_collection).doc(id).update({
      'status': AssignmentStatus.submitted.name,
    });
  }

  Future<List<Assignment>> getAssignmentsForTeacher(
    String teacherId, {
    String? schoolId,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('teacherId', isEqualTo: teacherId);

      final normalizedSchoolId = schoolId?.trim();
      if (normalizedSchoolId != null && normalizedSchoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: normalizedSchoolId);
      }

      // Remove orderBy to avoid index requirement errors
      final snapshot = await query.limit(100).get();

      final assignments = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort client-side
      assignments.sort((a, b) => b.dueDate.compareTo(a.dueDate));

      return assignments;
    } catch (e) {
      debugPrint('Error fetching teacher assignments: $e');
      return [];
    }
  }

  Stream<List<Assignment>> getAssignmentsForTeacherStream(
    String teacherId, {
    String? schoolId,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId);

    final normalizedSchoolId = schoolId?.trim();
    if (normalizedSchoolId != null && normalizedSchoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: normalizedSchoolId);
    }

    return query.snapshots().map((snapshot) {
      final assignments = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      assignments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return assignments;
    });
  }
}

final firestoreAssignmentRepositoryProvider =
    Provider<FirestoreAssignmentsRepository>((ref) {
      final storage = ref.watch(offlineStorageProvider);
      return FirestoreAssignmentsRepository(offlineStorage: storage);
    });

final teacherAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, teacherId) {
      final repo = ref.watch(firestoreAssignmentRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      // Pass schoolId if available to ensure permission compliance
      return repo.getAssignmentsForTeacherStream(
        teacherId,
        schoolId: user?.schoolId,
      );
    });

final studentAssignmentsProvider =
    FutureProvider.family<List<Assignment>, String>((ref, studentId) async {
      final repo = ref.watch(firestoreAssignmentRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      // Pass schoolId if available
      return repo.getAssignmentsForStudent(studentId, schoolId: user?.schoolId);
    });

final studentAssignmentsStreamProvider =
    StreamProvider.family<List<Assignment>, String>((ref, studentId) {
      final repo = ref.watch(firestoreAssignmentRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      return repo.getAssignmentsForStudentStream(
        studentId,
        schoolId: user?.schoolId,
      );
    });
