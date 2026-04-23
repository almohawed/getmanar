import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import 'firestore_parent_repository.dart';
import 'student_repository.dart';

class FirestoreStudentRepository implements StudentRepository {
  final FirebaseFirestore _firestore;
  late final FirestoreParentRepository _parentRepository;

  FirestoreStudentRepository(this._firestore) {
    _parentRepository = FirestoreParentRepository(_firestore);
  }

  Future<String?> _repairSchoolId() async {
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('repairCurrentUserLink')
          .call({});
      final d = res.data;
      if (d is Map && d['schoolId'] != null) {
        final sid = d['schoolId'].toString().trim();
        return sid.isEmpty ? null : sid;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _createSchoolAdminProvision({
    required String email,
    required String password,
    required String role,
    required String name,
    required String schoolId,
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
            'identityNumber': identityNumber,
            'mobile': mobile,
          });
      return result.data['uid'] as String?;
    } catch (e) {
      debugPrint('Error creating student via Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'حدث خطأ غير معروف في السيرفر');
      }
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  @override
  Future<User?> findStudentByIdentity(
    String schoolId,
    String identityNumber,
  ) async {
    try {
      final query = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .where('identityNumber', isEqualTo: identityNumber)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        data['id'] = query.docs.first.id;
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error finding student by identity: $e');
      return null;
    }
  }

  @override
  Stream<List<User>> watchStudents(String schoolId) async* {
    var sid = schoolId.trim();
    if (sid.isEmpty) {
      final repaired = await _repairSchoolId();
      if (repaired != null) sid = repaired;
    }
    if (sid.isEmpty) {
      yield const <User>[];
      return;
    }

    while (true) {
      try {
        await for (final snapshot
            in _firestore
                .collection('Schools')
                .doc(sid)
                .collection('Students')
                .snapshots()) {
          final students = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return User.fromMap(data);
          }).toList();
          students.sort((a, b) => a.name.compareTo(b.name));
          yield students;
        }
        return;
      } catch (e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          final repaired = await _repairSchoolId();
          if (repaired != null && repaired != sid) {
            sid = repaired;
            continue;
          }
        }
        rethrow;
      }
    }
  }

  @override
  Future<User?> getStudentById(String schoolId, String studentId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .doc(studentId)
        .get();
    if (doc.exists) {
      return User.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<List<User>> getStudentsByParentPhone(
    String schoolId,
    String parentPhone,
  ) async {
    try {
      final query = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .where('phoneNumber', isEqualTo: parentPhone)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return User.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching students by parent phone: $e');
      return [];
    }
  }

  @override
  Future<void> addStudent(
    String schoolId,
    User student,
    String password,
  ) async {
    var sid = schoolId.trim();
    final repaired = await _repairSchoolId();
    if (repaired != null) sid = repaired;
    if (sid.isEmpty) {
      throw Exception('School ID مفقود أثناء إنشاء الطالب، لن يتم الحفظ.');
    }

    // 1. Create Auth User
    // Use the provided password which is now random

    // Ensure email is unique or handle error.
    String email = student.email;
    if (email.isEmpty) {
      // Generate a dummy email if missing
      if (student.identityNumber != null &&
          student.identityNumber!.isNotEmpty) {
        email = 'st${student.identityNumber}@getmanar.com';
      } else {
        email = 'st${const Uuid().v4().substring(0, 8)}@getmanar.com';
      }
    }

    try {
      String? authId = await _createSchoolAdminProvision(
        email: email,
        password: password,
        role: 'student',
        name: student.name,
        schoolId: sid,
        // Use National ID for the Global User (Auth) identity if available.
        // Do NOT use the System ID (username) here as it may fail validation (must be 10 digits).
        identityNumber:
            (student.nationalId != null && student.nationalId!.isNotEmpty)
            ? student.nationalId
            : null,
        mobile: student.phoneNumber,
      );

      if (authId == null) {
        throw Exception(
          'فشل إنشاء حساب الطالب. قد يكون اسم المستخدم مستخدم بالفعل.',
        );
      }

      final String userId = authId;

      // Generate a unique student code
      final studentCode = _generateStudentCode();

      // Update student with Auth ID and ensured email and force password change
      final userToSave = student.copyWith(
        id: userId,
        email: email,
        isPasswordChangeRequired: true,
        studentCode: studentCode,
      );

      // 2. Save to School's Students (Update with full details)
      // Cloud Function creates the basic doc, we merge the rest (grade, class, etc.)
      if (kDebugMode) {
        debugPrint('Saving student to path: Schools/$sid/Students/$userId');
      }
      await FirebaseFunctions.instance.httpsCallable('saveStudentDetails').call(
        {'schoolId': sid, 'studentId': userId, 'data': userToSave.toMap()},
      );

      // 3. Auto-Create Parent Account (Strictly by National ID)
      if (student.parentIdentityNumber != null &&
          student.parentIdentityNumber!.isNotEmpty) {
        await _ensureParentAccount(
          sid,
          student.parentIdentityNumber!,
          student.phoneNumber,
        );
      } else {
        debugPrint(
          'Skipping parent account creation: No parent identity number provided for student ${student.name}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _ensureParentAccount(
    String schoolId,
    String parentIdentityNumber,
    String? phoneNumber,
  ) async {
    try {
      // Strict Identity Check: Check if parent exists by National ID
      final existingParent = await _parentRepository.getParentByIdentity(
        schoolId,
        parentIdentityNumber,
      );

      if (existingParent != null) {
        debugPrint(
          'Parent account already exists for ID: $parentIdentityNumber',
        );
        return;
      }

      // Create new Parent (Single Identity Only)
      final parentEmail = 'p$parentIdentityNumber@getmanar.com';
      final parentUser = User(
        id: const Uuid().v4(),
        name: 'ولي أمر - $parentIdentityNumber',
        email: parentEmail,
        role: UserRole.parent,
        identityNumber: parentIdentityNumber, // Crucial: Set Identity
        phoneNumber: phoneNumber, // Contact info only, not identity
        schoolId: schoolId,
        isPasswordChangeRequired: true,
      );

      await _parentRepository.addParent(schoolId, parentUser);
      debugPrint(
        'Auto-created parent account for Identity: $parentIdentityNumber',
      );
    } catch (e) {
      debugPrint('Error auto-creating parent: $e');
    }
  }

  @override
  Future<void> updateStudent(String schoolId, User student) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .doc(student.id)
        .update(student.toMap());
  }

  @override
  Future<void> deleteStudent(String schoolId, String studentId) async {
    if (schoolId.isEmpty) {
      throw Exception('School ID مفقود أثناء حذف الطالب');
    }

    final studentRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .doc(studentId);

    final studentSnap = await studentRef.get();
    final studentData = studentSnap.data();
    final assigned =
        (studentData?['assignedClassIds'] as List?)
            ?.map((e) => '$e')
            .toList() ??
        const <String>[];

    final batch = _firestore.batch();

    for (final classId in assigned) {
      if (classId.trim().isEmpty) continue;
      batch.update(
        _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Classes')
            .doc(classId),
        {
          'studentIds': FieldValue.arrayRemove([studentId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    batch.delete(studentRef);

    try {
      batch.delete(_firestore.collection('GlobalUsers').doc(studentId));
    } catch (_) {}

    await batch.commit();
  }

  @override
  Future<int> deleteAllStudents(String schoolId) async {
    if (schoolId.isEmpty) {
      throw Exception('School ID مفقود');
    }
    final classesSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .get();
    for (var i = 0; i < classesSnap.docs.length; i += 450) {
      final chunk = classesSnap.docs.skip(i).take(450).toList();
      final batch = _firestore.batch();
      for (final d in chunk) {
        batch.update(d.reference, {
          'studentIds': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    final studentsSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .get();
    final total = studentsSnap.docs.length;
    for (var i = 0; i < studentsSnap.docs.length; i += 450) {
      final chunk = studentsSnap.docs.skip(i).take(450).toList();
      final batch = _firestore.batch();
      for (final d in chunk) {
        batch.delete(d.reference);
        try {
          batch.delete(_firestore.collection('GlobalUsers').doc(d.id));
        } catch (_) {}
      }
      await batch.commit();
    }
    return total;
  }

  @override
  Future<int> deleteStudentsByClass(String schoolId, String classId) async {
    if (schoolId.isEmpty || classId.isEmpty) {
      throw Exception('بيانات غير كاملة للحذف حسب الفصل');
    }

    final studentIdsToDelete = <String>{};

    final q = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .where('assignedClassIds', arrayContains: classId)
        .get();

    for (final doc in q.docs) {
      studentIdsToDelete.add(doc.id);
    }

    final classDoc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .doc(classId)
        .get();

    if (classDoc.exists) {
      final data = classDoc.data();
      final ids =
          (data?['studentIds'] as List?)?.map((e) => e.toString()).toList() ??
          [];
      studentIdsToDelete.addAll(ids);
    }

    final idsList = studentIdsToDelete.toList();
    final total = idsList.length;

    for (var i = 0; i < idsList.length; i += 200) {
      final chunk = idsList.skip(i).take(200).toList();
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.delete(
          _firestore
              .collection('Schools')
              .doc(schoolId)
              .collection('Students')
              .doc(id),
        );
        try {
          batch.delete(_firestore.collection('GlobalUsers').doc(id));
        } catch (_) {}
      }
      await batch.commit();
    }

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .doc(classId)
        .update({
          'studentIds': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
    return total;
  }

  String _generateStudentCode() {
    // Generate a secure random code: STU-XXXXXX
    // Exclude ambiguous characters: I, O, 0, 1
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return 'STU-$code';
  }

  @override
  Future<User?> findStudentByCode(String schoolId, String studentCode) async {
    try {
      // Use Collection Group Query to find student across all schools if schoolId is not provided/reliable
      // However, the interface asks for schoolId.
      // If we want global uniqueness, we should use collectionGroup.

      QuerySnapshot<Map<String, dynamic>> query;

      if (schoolId.isNotEmpty) {
        query = await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .where('studentCode', isEqualTo: studentCode)
            .limit(1)
            .get();
      } else {
        // Fallback to collection group if schoolId is empty (though unlikely in this repo usage)
        query = await _firestore
            .collectionGroup('Students')
            .where('studentCode', isEqualTo: studentCode)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        data['id'] = query.docs.first.id;
        // If using collectionGroup, we might want to ensure we get the schoolId from the path
        // path: Schools/{schoolId}/Students/{studentId}
        final ref = query.docs.first.reference;
        final parentPath = ref.parent.parent?.path; // Schools/{schoolId}
        if (parentPath != null) {
          final pathParts = parentPath.split('/');
          if (pathParts.length >= 2) {
            data['schoolId'] = pathParts[1];
          }
        }
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error finding student by code: $e');
      return null;
    }
  }
}
