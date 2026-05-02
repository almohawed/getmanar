import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../../core/domain/models/user.dart';
import 'staff_repository.dart';

class FirestoreStaffRepository implements StaffRepository {
  final FirebaseFirestore _firestore;

  FirestoreStaffRepository(this._firestore);

  Future<StaffProvisioningResult> _createSchoolAdminProvision({
    required String email,
    required String password,
    required String role,
    required String name,
    required String schoolId,
    String? mnCode,
    String? deputyType,
    String? identityNumber,
    String? mobile,
    Map<String, dynamic>? delegatedPermissions,
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
            'mnCode': mnCode,
            'deputyType': deputyType,
            'identityNumber': identityNumber,
            'mobile': mobile,
            'delegatedPermissions': delegatedPermissions,
          });
      final data = result.data as Map;
      return StaffProvisioningResult(
        uid: (data['uid'] ?? '').toString(),
        mnCode: (data['mnCode'] ?? '').toString(),
        password: (data['password'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('Error creating staff via Cloud Function: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'حدث خطأ غير معروف في السيرفر');
      }
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  @override
  Future<StaffProvisioningResult> addStaff(User user, String password) async {
    // حل جذري: استخدام Cloud Function لضمان إنشاء حساب Auth + Firestore + GlobalUsers + UserCode
    try {
      final provision = await _createSchoolAdminProvision(
        email: user.email,
        password: password,
        role: user.role.name,
        name: user.name,
        schoolId: user.schoolId ?? '',
        mnCode: user.mnCode,
        deputyType: user.deputyType,
        identityNumber: user
            .nationalId, // Use National ID (10 digits) instead of System ID (MN-ADM-...)
        mobile: user.phoneNumber,
        delegatedPermissions: user.delegatedPermissions,
      );

      debugPrint('Staff added successfully via Cloud Function: ${user.name}');
      return provision;
    } catch (e) {
      debugPrint('Error adding staff: $e');
      rethrow;
    }
  }

  @override
  Future<List<User>> getStaffByRole(UserRole role) async {
    // Requires schoolId context, so this interface is limited.
    // We will implement getStaffForSchool separately.
    return [];
  }

  @override
  Future<List<User>> getAllStaff() async {
    return [];
  }

  Future<List<User>> getStaffForSchool(String schoolId, UserRole role) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .where('role', isEqualTo: role.name)
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID matches document key
            return User.fromMap(data);
          } catch (e) {
            debugPrint('Error parsing staff ${doc.id}: $e');
            return null;
          }
        })
        .where((u) => u != null)
        .cast<User>()
        .toList();
  }

  Future<List<User>> getAllStaffForSchool(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID matches document key
            return User.fromMap(data);
          } catch (e) {
            debugPrint('Error parsing staff ${doc.id}: $e');
            return null;
          }
        })
        .where((u) => u != null)
        .cast<User>()
        .toList();
  }

  @override
  Future<void> deleteStaff(List<String> ids) async {}

  Future<void> deleteStaffForSchool(
    String schoolId,
    List<String> staffIds,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'deleteSchoolAdminProvision',
    );

    for (final id in staffIds) {
      await callable.call({'uid': id, 'schoolId': schoolId, 'role': 'staff'});
    }
  }

  @override
  Stream<List<User>> watchAllStaff(String schoolId) {
    // الكادر الإداري فقط من Staff collection (بدون Teachers)
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            return User.fromMap(data);
          } catch (e) { return null; }
        }).where((u) => u != null).cast<User>().toList());
  }

  @override
  Stream<List<User>> watchSupportStaff(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .where(
          'role',
          whereIn: [
            'support_admin',
            'tech_support',
            'technicalSupport',
            'supportAdmin',
          ],
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => User.fromMap(doc.data())).toList(),
        );
  }

  @override
  Future<void> createSupportUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String schoolId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createSchoolSupportUser',
    );
    await callable.call({
      'email': email,
      'password': password,
      'name': name,
      'role': role,
      'schoolId': schoolId,
    });
  }

  @override
  Future<void> deleteSupportUser({
    required String uid,
    required String schoolId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'deleteSchoolSupportUser',
    );
    await callable.call({'uid': uid, 'schoolId': schoolId});
  }

  @override
  Future<void> updateStaff(User user) async {
    final schoolId = user.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('لا يوجد مدرسة محددة لهذا الموظف');
    }

    final batch = _firestore.batch();

    final staffRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .doc(user.id);

    batch.set(staffRef, {
      'name': user.name,
      'phoneNumber': user.phoneNumber,
      'identityNumber': user.identityNumber,
      'deputyType': user.deputyType,
      'delegatedPermissions': user.delegatedPermissions,
    }, SetOptions(merge: true));

    final globalRef = _firestore.collection('GlobalUsers').doc(user.id);

    batch.set(globalRef, {
      'name': user.name,
      'phoneNumber': user.phoneNumber,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
