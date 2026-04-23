import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'mock_student_repository.dart';
import 'firestore_student_repository.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

abstract class StudentRepository {
  Stream<List<User>> watchStudents(String schoolId);
  Future<User?> findStudentByIdentity(String schoolId, String identityNumber);
  Future<User?> findStudentByCode(String schoolId, String studentCode);
  Future<User?> getStudentById(String schoolId, String studentId); // Added
  Future<List<User>> getStudentsByParentPhone(
    String schoolId,
    String parentPhone,
  ); // Added
  Future<void> addStudent(String schoolId, User student, String password);
  Future<void> updateStudent(String schoolId, User student);
  Future<void> deleteStudent(String schoolId, String studentId);
  Future<int> deleteAllStudents(String schoolId);
  Future<int> deleteStudentsByClass(String schoolId, String classId);
}

final mockStudentRepositoryProvider = Provider<MockStudentRepository>((ref) {
  return MockStudentRepository();
});

final firestoreStudentRepositoryProvider = Provider<FirestoreStudentRepository>(
  (ref) {
    return FirestoreStudentRepository(FirebaseFirestore.instance);
  },
);

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final userState = ref.watch(authStateProvider);
  final user = userState.value;

  if (user != null && (user.schoolId?.isNotEmpty ?? false)) {
    return ref.watch(firestoreStudentRepositoryProvider);
  }
  if (kReleaseMode) {
    return ref.watch(firestoreStudentRepositoryProvider);
  }
  return ref.watch(mockStudentRepositoryProvider);
});
