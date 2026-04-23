import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../domain/teacher_repository.dart';

final firestoreTeacherRepositoryProvider = Provider<FirestoreTeacherRepository>(
  (ref) {
    return FirestoreTeacherRepository(FirebaseFirestore.instance);
  },
);

class FirestoreTeacherRepository implements TeacherRepository {
  final FirebaseFirestore _firestore;

  FirestoreTeacherRepository(this._firestore);

  Future<TeacherProvisioningResult> _createSchoolAdminProvision({
    required String email,
    required String password,
    required String role,
    required String name,
    required String schoolId,
    String? mnCode,
    String? identityNumber,
    String? mobile,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createSchoolAdminProvision')
          .call({
            'email': email,
            'password': password,
            'role': role,
            'name': name,
            'schoolId': schoolId,
            if (mnCode != null && mnCode.trim().isNotEmpty) 'mnCode': mnCode,
            'identityNumber': identityNumber,
            'mobile': mobile,
          });
      final data = result.data as Map;
      return TeacherProvisioningResult(
        uid: (data['uid'] ?? '').toString(),
        mnCode: (data['mnCode'] ?? '').toString(),
        password: (data['password'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('Error creating teacher via Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'حدث خطأ غير معروف في السيرفر');
      }
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  @override
  Future<TeacherProvisioningResult> addTeacher(User teacher, String password) async {
    // 1. Create Auth User
    // Use provided random password

    try {
      final provision = await _createSchoolAdminProvision(
        email: teacher.email,
        password: password,
        role: 'teacher',
        name: teacher.name,
        schoolId: teacher.schoolId ?? '',
        mnCode:
            RegExp(r'^[A-Z]{2}\d{6}$').hasMatch((teacher.identityNumber ?? '').trim())
            ? (teacher.identityNumber ?? '').trim()
            : null,
        // Use National ID for Auth Identity if available (must be 10 digits)
        // Do NOT use System ID (username) here to avoid validation errors
        identityNumber: (teacher.nationalId != null && teacher.nationalId!.isNotEmpty)
            ? teacher.nationalId
            : null,
        mobile: teacher.phoneNumber,
      );
      final authId = provision.uid;

      // CRITICAL FIX: If Auth creation fails, do NOT create a duplicate user with a random ID.
      // This prevents "Double Teacher" issue where one has Auth ID and another has UUID.
      if (authId.isEmpty) {
        throw Exception(
          'فشل إنشاء الحساب. قد يكون المعرّف النظامي مستخدم بالفعل أو يوجد خلل في الاتصال.',
        );
      }

      final mergedTeacher = teacher.copyWith(id: authId);
      final schoolId = mergedTeacher.schoolId ?? '';
      if (schoolId.isNotEmpty) {
        await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Teachers')
            .doc(authId)
            .set(mergedTeacher.toMap(), SetOptions(merge: true));
      }
      try {
        await _firestore
            .collection('GlobalUsers')
            .doc(authId)
            .set(mergedTeacher.toMap(), SetOptions(merge: true));
      } catch (_) {}
      return provision;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateTeacher(User teacher) async {
    if (teacher.schoolId != null && teacher.schoolId!.isNotEmpty) {
      await _firestore
          .collection('Schools')
          .doc(teacher.schoolId)
          .collection('Teachers')
          .doc(teacher.id)
          .set(teacher.toMap(), SetOptions(merge: true));
    }
    try {
      await _firestore
          .collection('GlobalUsers')
          .doc(teacher.id)
          .set(teacher.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<List<User>> getTeachers({String? schoolId}) async {
    if (schoolId != null && schoolId.isNotEmpty) {
      return getTeachersForSchool(schoolId);
    }
    return [];
  }

  Stream<List<User>> getTeachersStream(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;
                  data['schoolId'] = (data['schoolId'] ?? '').toString().trim().isEmpty
                      ? schoolId
                      : data['schoolId'];
                  return User.fromMap(data);
                } catch (e) {
                  debugPrint('Error parsing teacher ${doc.id}: $e');
                  return null;
                }
              })
              .where((u) => u != null)
              .cast<User>()
              .toList();
        });
  }

  // Helper for specific school
  Future<List<User>> getTeachersForSchool(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .get();
    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID matches document key
            data['schoolId'] = (data['schoolId'] ?? '').toString().trim().isEmpty
                ? schoolId
                : data['schoolId'];
            return User.fromMap(data);
          } catch (e) {
            debugPrint('Error parsing teacher ${doc.id}: $e');
            return null;
          }
        })
        .where((u) => u != null)
        .cast<User>()
        .toList();
  }

  @override
  Future<void> deleteTeacher(String teacherId) async {
    try {
      // 1. Find schoolId from GlobalUsers
      final globalDoc = await _firestore
          .collection('GlobalUsers')
          .doc(teacherId)
          .get();
      if (!globalDoc.exists) return;

      final data = globalDoc.data();
      final schoolId = data?['schoolId'];

      // 2. Delete from School
      if (schoolId != null) {
        await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Teachers')
            .doc(teacherId)
            .delete();
      }

      // 3. Delete from GlobalUsers
      await _firestore.collection('GlobalUsers').doc(teacherId).delete();

      // Note: Auth user deletion requires Admin SDK or Cloud Functions
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTeachers(List<String> teacherIds) async {
    for (var id in teacherIds) {
      await deleteTeacher(id);
    }
  }

  Future<void> deleteTeachersForSchool(
    String schoolId,
    List<String> teacherIds,
  ) async {
    final batch = _firestore.batch();
    for (var id in teacherIds) {
      final docRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .doc(id);
      batch.delete(docRef);

      // Also delete from GlobalUsers
      final globalRef = _firestore.collection('GlobalUsers').doc(id);
      batch.delete(globalRef);
    }
    await batch.commit();
  }
}
