import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/email_generator.dart';
import '../domain/global_user.dart';

class SuperAdminRepository {
  final FirebaseFirestore _firestore;

  SuperAdminRepository(this._firestore);

  String _normalizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
      input = input.replaceAll(persian[i], english[i]);
    }
    return input;
  }

  Future<void> addSchool({
    required String name,
    required String type,
    required String stage,
    required String city,
    String adminRegion = '',
    required String managerName,
    required String managerEmail,
    required String managerPassword,
    String? managerIdentityNumber,
    String? managerPhoneNumber,
    required bool showSubscriptionSection,
    DateTime? trialEndsAt,
    bool isLifetimeAccess = false,
    String subscriptionPlan = 'free',
    bool hasSpecialEducation = false,
  }) async {
    try {
      // Normalize identity number to ensure English digits for Auth/Login
      final String? normalizedIdentity = managerIdentityNumber != null
          ? _normalizeDigits(managerIdentityNumber)
          : null;

      // 1. Call Atomic Registration Cloud Function
      await FirebaseFunctions.instance.httpsCallable('registerNewSchool').call({
        'schoolName': name,
        'schoolType': type,
        'schoolStage': stage,
        'adminRegion': adminRegion,
        'city': city,
        'studentCount': '0', // Default
        'hasSpecialEducation': hasSpecialEducation,
        'principalName': managerName,
        'identityNumber': normalizedIdentity,
        'mobile': managerPhoneNumber,
        'email': managerEmail, // Contact Email
        'password': managerPassword.isNotEmpty ? managerPassword : '123456',

        // Subscription Fields
        'showSubscriptionSection': showSubscriptionSection,
        'isLifetimeAccess': isLifetimeAccess,
        'subscriptionPlan': subscriptionPlan,
        'trialEndsAt': trialEndsAt?.toIso8601String(),
      });

      // No client-side update needed - Cloud Function handles everything atomically
    } catch (e) {
      debugPrint('Error adding school: $e');
      if (e is FirebaseFunctionsException) {
        // Provide more specific error messages
        if (e.code == 'permission-denied') {
          throw Exception('هذه العملية مقتصرة على مدير التطبيق فقط');
        } else if (e.code == 'unauthenticated') {
          throw Exception('يجب تسجيل الدخول أولاً');
        } else if (e.code == 'already-exists') {
          throw Exception('رقم الهوية أو البريد الإلكتروني مستخدم بالفعل');
        }
        throw Exception(e.message ?? 'حدث خطأ غير متوقع');
      }
      throw Exception('فشل إضافة المدرسة: $e');
    }
  }

  Stream<List<School>> getSchools() {
    return _firestore.collection('Schools').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return School.fromMap(data);
      }).toList();
    });
  }

  Future<User?> getUser(String userId, {String? schoolId}) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('GlobalUsers').doc(userId).get();
      if (doc.exists) {
        return User.fromMap(doc.data()!);
      }
      if (schoolId != null) {
        // Fallback: Try Staff collection
        final staffDoc = await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Staff')
            .doc(userId)
            .get();
        if (staffDoc.exists) return User.fromMap(staffDoc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  Future<void> addManager({
    required String schoolId,
    required String name,
    required String email,
    required String password,
  }) async {
    String effectiveEmail = email;
    String? identityNumber;
    if (!effectiveEmail.contains('@')) {
      identityNumber = _normalizeDigits(email);
      effectiveEmail = EmailGenerator.generateEmail(
        UserRole.admin,
        identityNumber: identityNumber,
      );
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createSchoolAdminProvision')
          .call({
            'email': effectiveEmail,
            'password': password,
            'name': name,
            'schoolId': schoolId,
            'role': 'admin',
            'identityNumber': identityNumber,
          });

      final newUserId = result.data['uid'] as String;
      await _firestore.collection('Schools').doc(schoolId).update({
        'ownerId': newUserId,
      });
    } catch (e) {
      if (e is FirebaseFunctionsException) throw Exception(e.message);
      throw Exception('فشل إضافة المدير: $e');
    }
  }

  Future<void> removeManager({
    required String schoolId,
    required String managerId,
  }) async {
    await deleteGlobalAccount(
      GlobalUser(
        id: managerId,
        role: 'admin',
        schoolId: schoolId,
        name: '',
        email: '',
      ),
    );
    await _firestore.collection('Schools').doc(schoolId).update({
      'ownerId': FieldValue.delete(),
    });
  }

  Future<User?> getSchoolUser(String schoolId, String userId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .doc(userId)
        .get();

    if (doc.exists) {
      return User.fromMap(doc.data()!);
    }

    // Fallback: Check Teachers
    final teacherDoc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .doc(userId)
        .get();

    if (teacherDoc.exists) {
      return User.fromMap(teacherDoc.data()!);
    }

    // Fallback: Check GlobalUsers (if not found in school collections yet)
    final globalDoc = await _firestore
        .collection('GlobalUsers')
        .doc(userId)
        .get();
    if (globalDoc.exists) {
      return User.fromMap(globalDoc.data()!);
    }

    return null;
  }

  Future<void> updateManagerName(
    String managerId,
    String schoolId,
    String newName,
  ) async {
    final updates = {'name': newName};
    await _firestore.collection('GlobalUsers').doc(managerId).update(updates);
    try {
      await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Staff')
          .doc(managerId)
          .update(updates);
    } catch (_) {}
  }

  Future<void> replaceManager({
    required String schoolId,
    required String oldManagerId,
    required String newName,
    required String newEmail,
    required String newPassword,
  }) async {
    await addManager(
      schoolId: schoolId,
      name: newName,
      email: newEmail,
      password: newPassword,
    );

    // Get the new ownerId from school doc to confirm (addManager sets it)
    final schoolDoc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .get();
    final newUserId = schoolDoc.data()?['ownerId'] as String?;

    if (oldManagerId.isNotEmpty &&
        newUserId != null &&
        oldManagerId != newUserId) {
      await deleteGlobalAccount(
        GlobalUser(
          id: oldManagerId,
          role: 'admin',
          schoolId: schoolId,
          name: '',
          email: '',
        ),
      );
    }
  }

  Future<void> deleteSchool(String schoolId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteSchoolDeep');
      await callable.call({'schoolId': schoolId});
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message);
      }
      throw Exception('فشل حذف المدرسة: $e');
    }
  }

  Future<void> addTechnicalSupport({
    required String schoolId,
    required String name,
    required String email,
    required String password,
  }) async {
    String effectiveEmail = email;
    String? identityNumber;
    if (!effectiveEmail.contains('@')) {
      identityNumber = _normalizeDigits(email);
      effectiveEmail = EmailGenerator.generateEmail(
        UserRole.technicalSupport,
        identityNumber: identityNumber,
      );
    }

    await FirebaseFunctions.instance
        .httpsCallable('createSchoolAdminProvision')
        .call({
          'email': effectiveEmail,
          'password': password,
          'name': name,
          'schoolId': schoolId,
          'role': UserRole.technicalSupport.name,
          'identityNumber': identityNumber,
        });
  }

  Stream<List<User>> getTechnicalSupportUsersStream(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Users')
        .where('role', isEqualTo: UserRole.technicalSupport.name)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => User.fromMap(d.data())).toList(),
        );
  }

  Future<List<User>> getTechnicalSupportUsers(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Users')
        .where('role', isEqualTo: UserRole.technicalSupport.name)
        .get();
    return snapshot.docs.map((d) => User.fromMap(d.data())).toList();
  }

  Future<void> deleteTechnicalSupportUser(
    String schoolId,
    String userId,
  ) async {
    await _firestore.collection('GlobalUsers').doc(userId).delete();
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Users')
        .doc(userId)
        .delete();
  }

  Future<void> updateTechnicalSupportUser({
    required String schoolId,
    required String userId,
    required String name,
  }) async {
    final updates = {'name': name};
    await _firestore.collection('GlobalUsers').doc(userId).update(updates);
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Users')
        .doc(userId)
        .update(updates);
  }

  Future<void> updateTechnicalSupportPassword({
    required String userId,
    required String newPassword,
  }) async {
    // Note: We cannot easily update the password in Firebase Auth from the client SDK
    // for *another* user without being logged in as them or using Admin SDK.
    // However, we can use the secondary app trick if we know the email.
    // But we don't have the old password to sign in.
    // Actually, Admin SDK is required to force password resets or changes without old password.
    // But we are using the "Secondary App" trick to CREATE users.
    // We cannot update password for another user easily this way unless we are Admin.
    // Wait, the `replaceManager` creates a NEW user.
    // For Technical Support, maybe we should just allow deleting and re-creating?
    // OR, we can try to update it if we are Super Admin? No, client SDK restriction.

    // Alternative: We can store the password in Firestore (Insecure but requested in previous memories for "Simple Password" approach?)
    // Memory 01KFE6DVX4825D572F3RJWEF2S says: "Teacher: Password = 123456".
    // It doesn't say we store it.

    // If I cannot implement "Change Password" easily without Admin SDK, maybe I should skip it or use the "Delete and Add" approach.
    // BUT the Manager section has `_showReplaceManagerDialog`.
    // Let's see how `replaceManager` works.
    // It creates a NEW auth user and deletes the old docs.
    // It does NOT update the password of the existing Auth User.
    // So for Technical Support, "Change Password" would effectively mean "Create New Auth User with same details but new password".
    // AND update the ID in Firestore?
    // If I change the Auth ID, I must update the Firestore Document ID to match (for consistency).
    // So `replaceTechnicalSupportUser` is better.
  }

  Future<void> replaceTechnicalSupportUser({
    required String schoolId,
    required String oldUserId,
    required String name,
    required String email, // We need the email/username to recreate
    required String newPassword,
  }) async {
    try {
      // 1. Create New Auth User (Atomic)
      final result = await FirebaseFunctions.instance
          .httpsCallable('createSchoolAdminProvision')
          .call({
            'email': email,
            'password': newPassword,
            'name': name,
            'schoolId': schoolId,
            'role': UserRole.technicalSupport.name,
          });

      final newUserId = result.data['uid'] as String;

      // 2. Delete Old User Docs
      if (oldUserId.isNotEmpty && oldUserId != newUserId) {
        await deleteTechnicalSupportUser(schoolId, oldUserId);
      }
    } catch (e) {
      debugPrint('Error replacing technical support: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message);
      }
      throw Exception('فشل استبدال الدعم الفني: $e');
    }
  }

  Stream<List<GlobalUser>> getAllGlobalUsers() {
    return _firestore.collection('GlobalUsers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return GlobalUser.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> deleteGlobalAccount(GlobalUser user) async {
    // 1. Delete from GlobalUsers
    await _firestore.collection('GlobalUsers').doc(user.id).delete();

    // 2. Delete from School Collection if schoolId and role exist
    if (user.schoolId != null &&
        user.schoolId!.isNotEmpty &&
        user.role != null) {
      String collectionName = 'Users';
      final roleStr = user.role!;
      if (roleStr == 'teacher') collectionName = 'Teachers';
      if (roleStr == 'student') collectionName = 'Students';
      if (roleStr == 'parent') collectionName = 'Parents';
      if (roleStr == 'deputy' ||
          roleStr == 'administrative' ||
          roleStr == 'counselor' ||
          roleStr == 'principal' ||
          roleStr == 'admin') {
        collectionName = 'Staff';
      }

      try {
        await _firestore
            .collection('Schools')
            .doc(user.schoolId)
            .collection(collectionName)
            .doc(user.id)
            .delete();
      } catch (e) {
        debugPrint('Error deleting sub-collection doc: $e');
      }
    }
  }
}

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository(FirebaseFirestore.instance);
});

final globalAccountsProvider = StreamProvider<List<GlobalUser>>((ref) {
  return ref.watch(superAdminRepositoryProvider).getAllGlobalUsers();
});

// Added this provider
final pendingSchoolRequestsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('SchoolRequests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});
