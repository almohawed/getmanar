import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../../core/domain/models/user.dart';
import '../domain/auth_repository.dart';

class FirestoreAuthRepository implements AuthRepository {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isOwnerEmail(String email) {
    final lower = email.trim().toLowerCase();
    return lower == 'mohwed32@getmanar.com' ||
        lower == 'mohawed32@manar.com' ||
        lower == 'mohwed32@manar.com' ||
        lower == 'mohawed32@getmanar.com' ||
        lower == 'almohawed@gmail.com';
  }

  @override
  Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw Exception('User UID is null');
      }

      // 2. Lookup School ID from GlobalUsers
      DocumentSnapshot<Map<String, dynamic>> globalDoc;
      final emailLower = (userCredential.user?.email ?? email).toLowerCase();
      final isOwner = _isOwnerEmail(emailLower);

      // حل جذري: إذا كان Super Admin، السماح بالدخول مباشرة بدون التحقق من GlobalUsers
      if (isOwner) {
        return User(
          id: uid,
          name: 'مالك المنصة',
          email: emailLower,
          role: UserRole.superAdmin,
          schoolId: '',
          phoneNumber: '',
        );
      }

      try {
        globalDoc = await _firestore.collection('GlobalUsers').doc(uid).get();
      } catch (e) {
        // ignore: avoid_print
        print('Firestore Read Failed: $e');
        rethrow;
      }

      if (!globalDoc.exists) {
        throw Exception(
          'تعذر تسجيل الدخول: حسابك غير مرتبط بسجلات النظام المركزية (GlobalUsers). يرجى التأكد من تفعيل الحساب لدى إدارة المدرسة أو التواصل مع الدعم.',
        );
      }

      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'repairCurrentUserLink',
        );
        await callable.call({});
        globalDoc = await _firestore.collection('GlobalUsers').doc(uid).get();
      } catch (_) {}

      final data = globalDoc.data();
      var roleStr = data?['role'];

      if (roleStr == 'superAdmin' || roleStr == 'Owner' || roleStr == 'owner') {
        return User(
          id: uid,
          name: data?['name'] ?? 'مالك المنصة',
          email: emailLower,
          role: UserRole.superAdmin,
          schoolId: data?['schoolId'] as String? ?? '',
          phoneNumber: data?['phoneNumber'] as String? ?? '',
        );
      }

      var schoolId = (data?['schoolId'] ?? '').toString().trim();

      if (schoolId.isEmpty) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'repairCurrentUserLink',
          );
          await callable.call({});
          globalDoc = await _firestore.collection('GlobalUsers').doc(uid).get();
          final repaired = globalDoc.data();
          schoolId = (repaired?['schoolId'] ?? '').toString().trim();
          roleStr = repaired?['role'] ?? roleStr;
        } catch (_) {}
      }

      if (schoolId.isEmpty) {
        throw Exception('School ID not found for this user.');
      }

      // 3. Fetch User Profile from School's Users collection
      String collectionName = 'Users';
      if (roleStr == 'teacher') collectionName = 'Teachers';
      if (roleStr == 'student') collectionName = 'Students';
      if (roleStr == 'parent') collectionName = 'Parents';
      if (roleStr == 'deputy' ||
          roleStr == 'administrative' ||
          roleStr == 'counselor' ||
          roleStr == 'principal' ||
          roleStr == 'admin' ||
          roleStr == 'manager' ||
          roleStr == 'technicalSupport' ||
          roleStr == 'support_admin' ||
          roleStr == 'tech_support') {
        collectionName = 'Staff';
      }

      DocumentSnapshot<Map<String, dynamic>> userDoc;
      try {
        userDoc = await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection(collectionName)
            .doc(uid)
            .get();
      } catch (e) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'repairCurrentUserLink',
          );
          await callable.call({});
          globalDoc = await _firestore.collection('GlobalUsers').doc(uid).get();
          final repaired = globalDoc.data();
          schoolId = (repaired?['schoolId'] ?? schoolId).toString().trim();
          roleStr = repaired?['role'] ?? roleStr;

          String cn = 'Users';
          if (roleStr == 'teacher') cn = 'Teachers';
          if (roleStr == 'student') cn = 'Students';
          if (roleStr == 'parent') cn = 'Parents';
          if (roleStr == 'deputy' ||
              roleStr == 'administrative' ||
              roleStr == 'counselor' ||
              roleStr == 'principal' ||
              roleStr == 'admin' ||
              roleStr == 'manager' ||
              roleStr == 'technicalSupport' ||
              roleStr == 'support_admin' ||
              roleStr == 'tech_support') {
            cn = 'Staff';
          }
          collectionName = cn;

          userDoc = await _firestore
              .collection('Schools')
              .doc(schoolId)
              .collection(collectionName)
              .doc(uid)
              .get();
        } catch (_) {
          rethrow;
        }
      }

      Map<String, dynamic> userData;
      if (userDoc.exists) {
        userData = userDoc.data()!;
        // Ensure schoolId is present (crucial for dashboard sections)
        userData['schoolId'] = schoolId;
      } else {
        // Fallback: Try searching in 'Teachers' collection if not found in Staff
        // This handles cases where a Teacher is promoted to Manager but profile remains in Teachers
        if (collectionName == 'Staff') {
          try {
            final teacherDoc = await _firestore
                .collection('Schools')
                .doc(schoolId)
                .collection('Teachers')
                .doc(uid)
                .get();
            if (teacherDoc.exists) {
              userData = teacherDoc.data()!;
              // Ensure we keep the correct role from GlobalUsers
              userData['role'] = roleStr;
            } else {
              // Not found in Teachers either
              userData = {}; // Trigger fallback below
            }
          } catch (e) {
            userData = {}; // Trigger fallback below
          }
        } else {
          userData = {};
        }
      }

      if (userData.isEmpty) {
        // STRICT SECURITY: If profile is missing in School Staff/Teachers, DO NOT CREATE FALLBACK for Admins.
        // The user explicitly requested to prevent "orphan" accounts from accessing the dashboard with incomplete data.

        if (roleStr == 'admin' ||
            roleStr == 'manager' ||
            roleStr == 'principal') {
          debugPrint(
            'AUTH_BLOCKED: Admin/Manager profile missing in School Staff/Teachers.',
          );
          throw Exception(
            'حساب المدير غير مربوط بسجلات المدرسة (Staff/Teachers). تواصل مع مالك النظام.',
          );
        }

        // For other roles (or if we decide to allow fallback strictly for non-admins), we *could* keep fallback,
        // but for now, let's respect the "Strict" directive for the Manager Dashboard.
        // If we want to allow Students/Parents to login even if their detailed profile is missing (rare),
        // we can keep a minimal fallback, but let's be safe and block if data is inconsistent.

        // However, to be "Backward Compatible" for non-admins who might have issues,
        // we can leave the fallback for them, but definitely NOT for admins.

        debugPrint(
          'User profile missing in School collection: $collectionName',
        );
        String? name = data?['name'];
        if (name == null || name == 'مستخدم' || name.trim().isEmpty) {
          name = 'مستخدم';
        }

        userData = {
          'id': uid,
          'email': email,
          'name': name,
          'schoolId': schoolId,
        };
      }

      if (data != null && data.containsKey('isPasswordChangeRequired')) {
        userData['isPasswordChangeRequired'] = data['isPasswordChangeRequired'];
      }

      final nowIso = DateTime.now().toIso8601String();
      final previousLast = data?['lastLoginAt'] as String?;

      await _firestore.collection('GlobalUsers').doc(uid).set({
        'lastLoginAt': nowIso,
        if (previousLast != null) 'previousLoginAt': previousLast,
      }, SetOptions(merge: true));

      userData['lastLoginAt'] = nowIso;
      if (previousLast != null) {
        userData['previousLoginAt'] = previousLast;
      }

      // CRITICAL FIX: Enforce role from GlobalUsers as Single Source of Truth
      if (roleStr != null && roleStr.isNotEmpty) {
        userData['role'] = roleStr;
        debugPrint('AUTH_RESOLVED_FROM_GLOBALUSERS → role=$roleStr');
      } else {
        // STRICT SECURITY GATE
        debugPrint(
          'AUTH_BLOCKED_MISSING_ROLE: User $uid has no role in GlobalUsers',
        );
        throw Exception(
          'الحساب غير مكتمل (role مفقود). تواصل مع إدارة النظام.',
        );
      }

      return User.fromMap(userData);
    } catch (e) {
      // Catch-all for any other errors (including rethrown ones if not handled above)
      if (e is auth.FirebaseAuthException) {
        throw Exception(_mapAuthError(e));
      }
      // ignore: avoid_print
      print('Login Error: $e');
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) verificationFailed,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (auth.PhoneAuthCredential credential) async {
        // Auto-resolution (on some Android devices)
        // For simplicity, we'll let the user manually enter the code for consistent UI
      },
      verificationFailed: (auth.FirebaseAuthException e) {
        String message = 'فشل إرسال رمز التحقق.';
        if (e.code == 'invalid-phone-number') {
          message = 'رقم الجوال غير صحيح.';
        } else if (e.code == 'too-many-requests') {
          message = 'تم إيقاف المحاولات مؤقتاً بسبب تكرار المحاولة.';
        }
        verificationFailed(message);
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Future<User?> signInWithPhoneCredential(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final credential = auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final uid = userCredential.user?.uid;
      if (uid == null) return null;

      return await getCurrentUser();
    } catch (e) {
      if (e is auth.FirebaseAuthException) {
        throw Exception(_mapAuthError(e));
      }
      rethrow;
    }
  }

  @override
  Future<User?> signInWithCustomToken(String customToken) async {
    try {
      final userCredential = await _firebaseAuth.signInWithCustomToken(customToken);
      final uid = userCredential.user?.uid;
      if (uid == null) return null;
      return await getCurrentUser();
    } catch (e) {
      if (e is auth.FirebaseAuthException) {
        throw Exception(_mapAuthError(e));
      }
      rethrow;
    }
  }

  String _mapAuthError(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'تم إيقاف حسابك. يرجى مراجعة إدارة المدرسة.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'too-many-requests':
        return 'تم إيقاف المحاولات مؤقتاً بسبب تكرار المحاولة. يرجى الانتظار قليلاً ثم إعادة المحاولة.';
      default:
        return 'تعذر إتمام عملية تسجيل الدخول. يرجى المحاولة لاحقاً.';
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<User?> getCurrentUser() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return null;

    try {
      final globalDoc = await _firestore
          .collection('GlobalUsers')
          .doc(currentUser.uid)
          .get();
      if (!globalDoc.exists) {
        final emailLower = (currentUser.email ?? '').toLowerCase();
        if (_isOwnerEmail(emailLower)) {
          return User(
            id: currentUser.uid,
            name: 'مالك المنصة',
            email: emailLower,
            role: UserRole.superAdmin,
            schoolId: '',
            phoneNumber: '',
          );
        }
        throw Exception(
          'تعذر إكمال تسجيل الدخول برقم الجوال.\nسجّل دخولك بالكود/البريد ثم فعّل رقم الجوال من الإعدادات.',
        );
      }

      DocumentSnapshot<Map<String, dynamic>> currentGlobalDoc = globalDoc;
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'repairCurrentUserLink',
        );
        await callable.call({});
        currentGlobalDoc = await _firestore
            .collection('GlobalUsers')
            .doc(currentUser.uid)
            .get();
      } catch (_) {}

      final data = currentGlobalDoc.data();
      final roleStr = data?['role'];
      final emailLower = (currentUser.email ?? '').toLowerCase();
      final isOwner = _isOwnerEmail(emailLower);

      if (isOwner ||
          roleStr == 'superAdmin' ||
          roleStr == 'Owner' ||
          roleStr == 'owner') {
        return User(
          id: currentUser.uid,
          name: data?['name'] ?? 'مالك المنصة',
          email: emailLower,
          role: UserRole.superAdmin,
          schoolId: data?['schoolId'] as String? ?? '',
          phoneNumber: data?['phoneNumber'] as String? ?? '',
        );
      }

      var schoolId = (data?['schoolId'] ?? '').toString().trim();
      if (schoolId.isEmpty) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'repairCurrentUserLink',
          );
          await callable.call({});
          final repairedDoc = await _firestore
              .collection('GlobalUsers')
              .doc(currentUser.uid)
              .get();
          final repaired = repairedDoc.data();
          schoolId = (repaired?['schoolId'] ?? '').toString().trim();
        } catch (_) {}
      }
      if (schoolId.isEmpty) throw Exception('SchoolID missing');

      String collectionName = 'Users';
      if (roleStr == 'teacher') collectionName = 'Teachers';
      if (roleStr == 'student') collectionName = 'Students';
      if (roleStr == 'parent') collectionName = 'Parents';
      if (roleStr == 'deputy' ||
          roleStr == 'administrative' ||
          roleStr == 'counselor' ||
          roleStr == 'principal' ||
          roleStr == 'admin' ||
          roleStr == 'manager' ||
          roleStr == 'technicalSupport' ||
          roleStr == 'support_admin' ||
          roleStr == 'tech_support') {
        collectionName = 'Staff';
      }

      DocumentSnapshot<Map<String, dynamic>> userDoc;
      try {
        userDoc = await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection(collectionName)
            .doc(currentUser.uid)
            .get();
      } catch (e) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'repairCurrentUserLink',
          );
          await callable.call({});
          final repairedDoc = await _firestore
              .collection('GlobalUsers')
              .doc(currentUser.uid)
              .get();
          final repaired = repairedDoc.data();
          final repairedSchoolId = (repaired?['schoolId'] ?? '')
              .toString()
              .trim();
          if (repairedSchoolId.isNotEmpty) {
            schoolId = repairedSchoolId;
          }
          userDoc = await _firestore
              .collection('Schools')
              .doc(schoolId)
              .collection(collectionName)
              .doc(currentUser.uid)
              .get();
        } catch (_) {
          rethrow;
        }
      }

      Map<String, dynamic> userData;
      if (userDoc.exists) {
        userData = userDoc.data()!;
        // Ensure schoolId is present (crucial for dashboard sections)
        userData['schoolId'] = schoolId;
      } else {
        // STRICT SECURITY: If profile is missing in School Staff/Teachers, DO NOT CREATE FALLBACK for Admins.
        // The user explicitly requested to prevent "orphan" accounts from accessing the dashboard with incomplete data.

        if (roleStr == 'admin' ||
            roleStr == 'manager' ||
            roleStr == 'principal') {
          debugPrint(
            'AUTH_BLOCKED: Admin/Manager profile missing in School Staff/Teachers.',
          );
          throw Exception(
            'حساب المدير غير مربوط بسجلات المدرسة (Staff/Teachers). تواصل مع مالك النظام.',
          );
        }

        // If profile is missing in School, create a minimal profile based on GlobalUsers
        debugPrint(
          'User profile missing in School collection: $collectionName',
        );

        // BETTER DEFAULT NAME LOGIC
        String? name = data?['name'];
        if (name == null || name == 'مستخدم' || name.trim().isEmpty) {
          if (roleStr == 'admin' ||
              roleStr == 'manager' ||
              roleStr == 'principal') {
            name = 'المدير';
          } else {
            name = 'مستخدم';
          }
        }

        userData = {
          'id': currentUser.uid,
          'email': currentUser.email,
          'name': name,
          'schoolId': schoolId,
        };
      }

      if (data != null && data.containsKey('isPasswordChangeRequired')) {
        userData['isPasswordChangeRequired'] = data['isPasswordChangeRequired'];
      }

      if (data != null) {
        if (data.containsKey('lastLoginAt')) {
          userData['lastLoginAt'] = data['lastLoginAt'];
        }
        if (data.containsKey('previousLoginAt')) {
          userData['previousLoginAt'] = data['previousLoginAt'];
        }
      }

      // CRITICAL FIX: Ensure schoolId is present in userData for proper Dashboard loading
      userData['schoolId'] = schoolId;

      // Enforce role from GlobalUsers
      if (roleStr != null && roleStr.isNotEmpty) {
        userData['role'] = roleStr;
        debugPrint('AUTH_RESOLVED_FROM_GLOBALUSERS → role=$roleStr');
      } else {
        // STRICT SECURITY GATE
        debugPrint(
          'AUTH_BLOCKED_MISSING_ROLE: User ${currentUser.uid} has no role in GlobalUsers',
        );
        throw Exception(
          'الحساب غير مكتمل (role مفقود). تواصل مع إدارة النظام.',
        );
      }

      return User.fromMap(userData);
    } catch (e) {
      debugPrint('GetCurrentUser Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Create credential with current email and provided password
    final credential = auth.EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    try {
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      if (e is auth.FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception('كلمة المرور الحالية غير صحيحة');
        }
      }
      throw Exception('فشل إعادة التحقق من الهوية: $e');
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user logged in');

    debugPrint('Changing password for user: ${user.uid}');

    // 1. Update Password in Firebase Auth
    try {
      await user.updatePassword(newPassword);
      debugPrint('Firebase Auth password updated successfully');

      // CRITICAL FIX FOR ANDROID PERMISSION DENIED (P0)
      // Force token refresh to ensure Firestore rules recognize the active session immediately.
      await user.reload();
      // Wait a moment for the token to propagate
      await Future.delayed(const Duration(milliseconds: 500));

      // Update reference after reload
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser == null) {
        throw Exception('User session lost after password change');
      }
    } catch (e) {
      throw Exception('فشل تحديث كلمة المرور: $e');
    }

    // 2. Update isPasswordChangeRequired via Cloud Function (Option A - Preferred)
    // This eliminates "Permission Denied" errors on Android/Client-side by moving the logic to the trusted server environment.
    try {
      debugPrint('Calling completePasswordChange Cloud Function...');

      // Prepare optional data for best-effort sync
      String? schoolId;
      String? collectionName;

      try {
        final uid = _firebaseAuth.currentUser?.uid ?? user.uid;
        // Try to read locally cached doc if possible
        final globalDoc = await _firestore
            .collection('GlobalUsers')
            .doc(uid)
            .get();
        if (globalDoc.exists) {
          final data = globalDoc.data();
          schoolId = data?['schoolId'];
          final roleStr = data?['role'];
          if (roleStr != null) {
            if (roleStr == 'teacher')
              collectionName = 'Teachers';
            else if (roleStr == 'student')
              collectionName = 'Students';
            else if (roleStr == 'parent')
              collectionName = 'Parents';
            else if ([
              'deputy',
              'administrative',
              'counselor',
              'principal',
              'admin',
              'manager',
              'technicalSupport',
              'support_admin',
              'tech_support',
            ].contains(roleStr)) {
              collectionName = 'Staff';
            } else {
              collectionName = 'Users';
            }
          }
        }
      } catch (lookupError) {
        // Non-critical: If we can't look up details, just call function without them
        debugPrint('Pre-function lookup failed: $lookupError');
      }

      final httpsCallable = FirebaseFunctions.instance.httpsCallable(
        'completePasswordChange',
      );
      final result = await httpsCallable.call({
        'schoolId': schoolId,
        'collection': collectionName,
      });

      debugPrint('Cloud Function result: ${result.data}');
    } catch (e) {
      debugPrint('Cloud Function failed: $e');
      throw Exception('تم تغيير كلمة المرور ولكن فشل تحديث حالة الحساب: $e');
    }
  }

  @override
  Future<void> authStateReady() async {
    await _firebaseAuth.authStateChanges().first;
  }
}
