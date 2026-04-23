import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';

class FirestoreParentRepository {
  final FirebaseFirestore _firestore;

  FirestoreParentRepository(this._firestore);

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
      debugPrint('Error creating parent via Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'حدث خطأ غير معروف في السيرفر');
      }
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  Future<void> addParent(String schoolId, User parent) async {
    var sid = schoolId.trim();
    final repaired = await _repairSchoolId();
    if (repaired != null) sid = repaired;
    if (sid.isEmpty) {
      throw Exception('School ID مفقود أثناء إنشاء ولي الأمر');
    }

    // 1. Create Auth User
    // Password should be 123456 by default as requested
    const password = '123456';

    // Ensure email
    String email = parent.email;
    if (email.isEmpty) {
      // Fallback
      if (parent.identityNumber != null && parent.identityNumber!.isNotEmpty) {
        email = 'p${parent.identityNumber}@getmanar.com';
      } else {
        email = 'p${parent.phoneNumber}@getmanar.com';
      }
    }

    try {
      String? authId = await _createSchoolAdminProvision(
        email: email,
        password: password,
        role: 'parent',
        name: parent.name,
        schoolId: sid,
        identityNumber: parent.identityNumber,
        mobile: parent.phoneNumber,
      );

      if (authId == null) {
        throw Exception(
          'فشل إنشاء حساب ولي الأمر. قد يكون رقم الهوية أو الهاتف مستخدم بالفعل.',
        );
      }

      final String userId = authId;

      final userToSave = parent.copyWith(
        id: userId,
        email: email,
        isPasswordChangeRequired: true,
      );

      await FirebaseFunctions.instance.httpsCallable('saveParentDetails').call({
        'schoolId': sid,
        'parentId': userId,
        'data': userToSave.toMap(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteParent(String schoolId, String parentId) async {
    if (schoolId.trim().isEmpty) {
      throw Exception('School ID مفقود أثناء حذف ولي الأمر');
    }
    if (parentId.trim().isEmpty) return;

    final batch = _firestore.batch();
    batch.delete(
      _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Parents')
          .doc(parentId),
    );
    try {
      batch.delete(_firestore.collection('GlobalUsers').doc(parentId));
    } catch (_) {}
    try {
      batch.delete(
        _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Users')
            .doc(parentId),
      );
    } catch (_) {}

    await batch.commit();
  }

  Future<int> deleteParents(String schoolId, List<String> parentIds) async {
    if (schoolId.trim().isEmpty) {
      throw Exception('School ID مفقود أثناء حذف أولياء الأمور');
    }

    final ids = parentIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return 0;

    for (var i = 0; i < ids.length; i += 450) {
      final chunk = ids.skip(i).take(450).toList();
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.delete(
          _firestore
              .collection('Schools')
              .doc(schoolId)
              .collection('Parents')
              .doc(id),
        );
        try {
          batch.delete(_firestore.collection('GlobalUsers').doc(id));
        } catch (_) {}
        try {
          batch.delete(
            _firestore
                .collection('Schools')
                .doc(schoolId)
                .collection('Users')
                .doc(id),
          );
        } catch (_) {}
      }
      await batch.commit();
    }
    return ids.length;
  }

  Future<int> deleteAllParents(String schoolId) async {
    if (schoolId.trim().isEmpty) {
      throw Exception('School ID مفقود أثناء حذف أولياء الأمور');
    }

    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Parents')
        .get();
    final total = snap.docs.length;
    for (var i = 0; i < snap.docs.length; i += 450) {
      final chunk = snap.docs.skip(i).take(450).toList();
      final batch = _firestore.batch();
      for (final d in chunk) {
        batch.delete(d.reference);
        try {
          batch.delete(_firestore.collection('GlobalUsers').doc(d.id));
        } catch (_) {}
        try {
          batch.delete(
            _firestore
                .collection('Schools')
                .doc(schoolId)
                .collection('Users')
                .doc(d.id),
          );
        } catch (_) {}
      }
      await batch.commit();
    }
    return total;
  }

  Stream<List<User>> watchParents(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Parents')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return User.fromMap(data);
          }).toList();
        });
  }

  Future<User?> getParentByPhone(String schoolId, String phoneNumber) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Parents')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return User.fromMap(data);
    }
    return null;
  }

  Future<User?> getParentByIdentity(
    String schoolId,
    String identityNumber,
  ) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Parents')
        .where('identityNumber', isEqualTo: identityNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return User.fromMap(data);
    }
    return null;
  }

  Future<User?> getParentById(String schoolId, String parentId) async {
    try {
      final doc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Parents')
          .doc(parentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return User.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error getting parent by id: $e');
    }
    return null;
  }
}

final firestoreParentRepositoryProvider = Provider<FirestoreParentRepository>((
  ref,
) {
  return FirestoreParentRepository(FirebaseFirestore.instance);
});
