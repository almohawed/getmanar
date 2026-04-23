import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/data/offline_storage_service.dart';
import '../../../core/utils/text_utils.dart';
import '../domain/auth_repository.dart';
import '../data/firestore_auth_repository.dart';
import '../data/mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // return MockAuthRepository();
  return FirestoreAuthRepository();
});

final authStateProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<User?> {
  Future<User?> _loginAndClearCache(Future<User?> Function() action) async {
    final result = await action();
    // Fire and forget storage cleanup to prevent blocking login
    if (result != null) {
      _clearCacheSafe(result.id);
    }
    return result;
  }

  Future<void> _clearCacheSafe(String userId) async {
    try {
      final storage = ref.read(offlineStorageProvider);
      // Add timeout to prevent hanging if IndexedDB/Hive is stuck
      await storage.init().timeout(const Duration(seconds: 2));
      await storage.clearAllCaches().timeout(const Duration(seconds: 2));
      await storage.saveLastLogin(userId).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Storage cleanup warning: $e');
    }
  }

  @override
  FutureOr<User?> build() async {
    // Attempt to recover session on reload
    final repo = ref.read(authRepositoryProvider);
    await repo.authStateReady();
    return await repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      try {
        // Normalize password digits before logging in
        final normalizedPassword = TextUtils.normalizeDigits(password);
        return await _loginAndClearCache(
          () => repo.login(email, normalizedPassword),
        );
      } on firebase_auth.FirebaseAuthException catch (e) {
        final message = _mapFirebaseAuthError(e);
        throw Exception(message);
      }
    });
  }

  // _normalizeDigits is now in TextUtils
  // String _normalizeDigits(String input) { ... }

  int _failedLoginAttempts = 0;
  DateTime? _lastFailedAttemptTime;

  Future<void> loginWithSmartFallback(String input, String password) async {
    // Basic client-side rate limiting
    if (_failedLoginAttempts >= 3) {
      if (_lastFailedAttemptTime != null &&
          DateTime.now().difference(_lastFailedAttemptTime!).inMinutes < 5) {
        throw Exception(
          'لقد تجاوزت الحد الأقصى لمحاولات الدخول. يرجى المحاولة بعد 5 دقائق.',
        );
      } else {
        _failedLoginAttempts = 0; // Reset after cooldown
      }
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final trimmedInput = TextUtils.normalizeDigits(input.trim());
      final normalizedPassword = TextUtils.normalizeDigits(password);
      final normalizedCodeCandidate = trimmedInput
          .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '')
          .trim()
          .toUpperCase();
      final looksLikePhoneEarly =
          RegExp(
            r'^\+?\d{8,15}$',
          ).hasMatch(trimmedInput.replaceAll(RegExp(r'\s+'), '')) ||
          RegExp(r'^05\d{8}$').hasMatch(trimmedInput);

      // 0. Direct Login Attempt (for Identity Number or Email)
      try {
        final user = await _loginAndVerify2FA(
          () => repo.login(trimmedInput, normalizedPassword),
        );
        if (user != null) {
          _failedLoginAttempts = 0;
          return user;
        }
      } catch (e) {
        // Continue if direct login fails, unless it's a critical error
        if (e.toString().contains('network-request-failed')) rethrow;
      }

      // 0.1 Resolve Alias via Cloud Function (Phone-only)
      if (looksLikePhoneEarly) {
        var aliasResolved = false;
        try {
          final functions = FirebaseFunctions.instance;
          final aliasResult = await functions
              .httpsCallable('resolveLoginAlias')
              .call({'alias': trimmedInput});
          final data = aliasResult.data;
          final m = data is Map ? data : null;
          final mappedEmail = (m?['authEmail'] ?? '').toString().trim();

          if (mappedEmail.isNotEmpty) {
            aliasResolved = true;
            try {
              final user = await _loginAndVerify2FA(
                () => repo.login(mappedEmail, normalizedPassword),
              );
              _failedLoginAttempts = 0;
              return user;
            } catch (e) {
              final msg = e.toString().replaceAll('Exception:', '').trim();
              if (msg.contains('اسم المستخدم أو كلمة المرور غير صحيحة') ||
                  msg.contains('wrong-password') ||
                  msg.contains('invalid-credential')) {
                throw Exception(
                  'رقم الجوال مرتبط بحساب آخر أو كلمة المرور غير صحيحة للحساب الأساسي',
                );
              }
              throw Exception(msg.isEmpty ? 'تعذر إتمام تسجيل الدخول' : msg);
            }
          }
        } catch (e) {
          if (e.toString().contains('network-request-failed')) rethrow;
          if (aliasResolved) rethrow;
        }
      }

      final looksLikePhone =
          RegExp(
            r'^\+?\d{8,15}$',
          ).hasMatch(trimmedInput.replaceAll(RegExp(r'\s+'), '')) ||
          RegExp(r'^05\d{8}$').hasMatch(trimmedInput);

      final aliasKey = (() {
        if (looksLikePhone) {
          final normalizedPhone = TextUtils.normalizeDigits(
            trimmedInput,
          ).replaceAll(RegExp(r'\s+'), '');
          var p = normalizedPhone;
          if (p.startsWith('+')) p = p.substring(1);
          if (p.startsWith('0') && p.length == 10) {
            p = '966${p.substring(1)}';
          } else if (p.startsWith('5') && p.length == 9) {
            p = '966$p';
          }
          return p;
        }
        return normalizedCodeCandidate.toLowerCase();
      })();

      if (aliasKey.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('GlobalUsers')
              .where('loginAliases', arrayContains: aliasKey)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            final mappedEmail = (data['authEmail'] ?? data['email'] ?? '')
                .toString()
                .trim();
            if (mappedEmail.isNotEmpty) {
              final user = await _loginAndVerify2FA(
                () => repo.login(mappedEmail, normalizedPassword),
              );
              _failedLoginAttempts = 0;
              return user;
            }
          }
        } catch (e) {
          if (e.toString().contains('network-request-failed')) rethrow;
        }
      }

      if (looksLikePhone) {
        final normalizedPhone = TextUtils.normalizeDigits(
          trimmedInput,
        ).replaceAll(RegExp(r'\s+'), '');
        String phoneLookup = normalizedPhone;
        if (phoneLookup.startsWith('+')) phoneLookup = phoneLookup.substring(1);
        if (phoneLookup.startsWith('0') && phoneLookup.length == 10) {
          phoneLookup = '966${phoneLookup.substring(1)}';
        } else if (phoneLookup.startsWith('5') && phoneLookup.length == 9) {
          phoneLookup = '966$phoneLookup';
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('GlobalUsers')
              .where('phoneLookup', isEqualTo: phoneLookup)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            final mappedEmail = (data['authEmail'] ?? data['email'] ?? '')
                .toString()
                .trim();
            if (mappedEmail.isNotEmpty) {
              final user = await _loginAndVerify2FA(
                () => repo.login(mappedEmail, normalizedPassword),
              );
              _failedLoginAttempts = 0;
              return user;
            }
          }
        } catch (e) {
          if (e.toString().contains('network-request-failed')) rethrow;
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('GlobalUsers')
              .where('phoneNumber', isEqualTo: normalizedPhone)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            final mappedEmail = (data['authEmail'] ?? data['email'] ?? '')
                .toString()
                .trim();
            if (mappedEmail.isNotEmpty) {
              final user = await _loginAndVerify2FA(
                () => repo.login(mappedEmail, normalizedPassword),
              );
              _failedLoginAttempts = 0;
              return user;
            }
          }
        } catch (e) {
          if (e.toString().contains('network-request-failed')) rethrow;
        }
      }

      final looksLikeNewMnCode = RegExp(
        r'^[A-Z]{2}\d{6}$',
      ).hasMatch(normalizedCodeCandidate);
      final looksLikeLegacyMnCode =
          normalizedCodeCandidate.length == 6 &&
          RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalizedCodeCandidate) &&
          RegExp(r'[A-Z]').hasMatch(normalizedCodeCandidate) &&
          RegExp(r'\d').hasMatch(normalizedCodeCandidate);

      if (looksLikeNewMnCode) {
        final prefix = normalizedCodeCandidate.substring(0, 2).toLowerCase();
        final digitsOnly = normalizedCodeCandidate.substring(2);
        final candidates = <String>{
          '$prefix$normalizedCodeCandidate@getmanar.com',
          '$prefix${normalizedCodeCandidate.toLowerCase()}@getmanar.com',
          '$prefix$digitsOnly@getmanar.com',
        }.toList();
        for (final deterministicEmail in candidates) {
          try {
            final user = await _loginAndVerify2FA(
              () => repo.login(deterministicEmail, normalizedPassword),
            );
            _failedLoginAttempts = 0;
            return user;
          } catch (e) {
            if (e.toString().contains('network-request-failed')) rethrow;
          }
        }
      }

      // 1. MN-Code Registry Lookup (Prefer for real login codes)
      if (!trimmedInput.contains('@') &&
          (looksLikeNewMnCode || looksLikeLegacyMnCode)) {
        try {
          final functions = FirebaseFunctions.instance;
          final lookupResult = await functions
              .httpsCallable('lookupUserCode')
              .call({'code': normalizedCodeCandidate});

          final data = lookupResult.data;
          final lookupData = data is Map ? data : null;
          final email = lookupData?['email'] as String?;
          final isActive = lookupData?['isActive'] as bool? ?? false;

          if (email != null && isActive) {
            try {
              for (final e in <String>{email, email.toLowerCase()}) {
                try {
                  final user = await _loginAndVerify2FA(
                    () => repo.login(e, normalizedPassword),
                  );
                  _failedLoginAttempts = 0;
                  return user;
                } catch (_) {}
              }
              throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('تم إيقاف حسابك') ||
                  msg.contains('غير مرتبط') ||
                  msg.contains('غير مكتمل') ||
                  msg.contains('GlobalUsers') ||
                  msg.contains('حساب المدير')) {
                rethrow;
              }
              throw Exception(
                'كود الدخول صحيح لكن كلمة المرور غير صحيحة. '
                'جرّب ترك كلمة المرور فارغة لتسجيل الدخول عبر التحقق برقم الجوال.',
              );
            }
          }
          throw Exception('كود الدخول غير صحيح أو غير نشط');
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('not-found') || msg.contains('كود الدخول')) {
            throw Exception('كود الدخول غير صحيح أو غير نشط');
          }
          debugPrint('MN-Code lookup failed: $e');
        }
      }

      // 2. Prefix Fallback Login (MOVED UP)
      // This handles standard usernames like 'mg1234567890' or 'st1234567890'
      if (!RegExp(r'^\d+$').hasMatch(trimmedInput)) {
        // RADICAL FIX: If input is already a valid email, skip prefix logic
        if (trimmedInput.contains('@') && trimmedInput.contains('.')) {
          try {
            final user = await _loginAndVerify2FA(
              () => repo.login(trimmedInput, normalizedPassword),
            );
            _failedLoginAttempts = 0;
            return user;
          } catch (e) {
            if (e.toString().contains('network-request-failed')) rethrow;
            throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
          }
        }

        final prefixes = ['', 'ts', 'st', 'p', 'tc', 'wk', 'cn', 'mg', 'ad'];
        for (final prefix in prefixes) {
          try {
            // Only add prefix if not already present
            final cleanInput = trimmedInput.toLowerCase();
            final effectivePrefix =
                (prefix.isNotEmpty && !cleanInput.startsWith(prefix))
                ? prefix
                : '';

            final email = '$effectivePrefix$trimmedInput@getmanar.com';
            debugPrint('Trying login with: $email');

            final user = await _loginAndVerify2FA(
              () => repo.login(email, normalizedPassword),
            );
            _failedLoginAttempts = 0; // Reset on success
            return user;
          } catch (e) {
            // Continue to next prefix
          }
        }
      }

      // 3. If Prefix Login failed, THEN try MN-Code Lookup (Last Resort)
      if (trimmedInput.length >= 3 && !trimmedInput.contains('@')) {
        try {
          final functions = FirebaseFunctions.instance;
          final lookupResult = await functions
              .httpsCallable('lookupUserCode')
              .call({'code': normalizedCodeCandidate});

          final data = lookupResult.data;
          // Handle both Map<String, dynamic> and Map<Object?, Object?>
          final lookupData = data is Map ? data : null;

          final email = lookupData?['email'] as String?;
          final isActive = lookupData?['isActive'] as bool? ?? false;

          if (email != null && isActive) {
            final user = await _loginAndVerify2FA(
              () => repo.login(email, normalizedPassword),
            );
            _failedLoginAttempts = 0;
            return user;
          }
        } catch (e) {
          debugPrint('Final MN-Code lookup failed: $e');
        }
      }

      // If all attempts fail
      _failedLoginAttempts++;
      _lastFailedAttemptTime = DateTime.now();
      throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
    });
  }

  Future<void> loginWithUserCodeAndPassword(
    String code,
    String password,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final normalizedCode = TextUtils.normalizeDigits(code)
          .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '')
          .trim()
          .toUpperCase();
      final normalizedPassword = TextUtils.normalizeDigits(password);

      try {
        if (RegExp(r'^[A-Z]{2}\d{6}$').hasMatch(normalizedCode)) {
          final prefix = normalizedCode.substring(0, 2).toLowerCase();
          final digitsOnly = normalizedCode.substring(2);
          final candidates = <String>{
            '$prefix$normalizedCode@getmanar.com',
            '$prefix${normalizedCode.toLowerCase()}@getmanar.com',
            '$prefix$digitsOnly@getmanar.com',
          }.toList();
          for (final deterministicEmail in candidates) {
            try {
              return await _loginAndVerify2FA(
                () => repo.login(deterministicEmail, normalizedPassword),
              );
            } catch (_) {}
          }
        }

        final functions = FirebaseFunctions.instance;
        final lookupResult = await functions
            .httpsCallable('lookupUserCode')
            .call({'code': normalizedCode});
        final data = lookupResult.data;
        final lookupData = data is Map ? data : null;
        final email = lookupData?['email'] as String?;
        final isActive = lookupData?['isActive'] as bool? ?? false;

        if (email == null || !isActive) {
          final prefix = normalizedCode.substring(0, 2).toLowerCase();
          final digitsOnly = normalizedCode.substring(2);
          final candidates = <String>{
            '$prefix$normalizedCode@getmanar.com',
            '$prefix${normalizedCode.toLowerCase()}@getmanar.com',
            '$prefix$digitsOnly@getmanar.com',
          }.toList();
          for (final fallbackEmail in candidates) {
            try {
              return await _loginAndVerify2FA(
                () => repo.login(fallbackEmail, normalizedPassword),
              );
            } catch (_) {}
          }
          throw Exception('كود الدخول غير صحيح أو غير نشط');
        }

        try {
          return await _loginAndVerify2FA(
            () => repo.login(email, normalizedPassword),
          );
        } catch (_) {
          if (email.toLowerCase() != email) {
            try {
              return await _loginAndVerify2FA(
                () => repo.login(email.toLowerCase(), normalizedPassword),
              );
            } catch (_) {}
          }
          throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'not-found' || e.code == 'failed-precondition') {
          final prefix = normalizedCode.substring(0, 2).toLowerCase();
          final digitsOnly = normalizedCode.substring(2);
          final candidates = <String>{
            '$prefix$normalizedCode@getmanar.com',
            '$prefix${normalizedCode.toLowerCase()}@getmanar.com',
            '$prefix$digitsOnly@getmanar.com',
          }.toList();
          for (final fallbackEmail in candidates) {
            try {
              return await _loginAndVerify2FA(
                () => repo.login(fallbackEmail, normalizedPassword),
              );
            } catch (_) {}
          }
          throw Exception('كود الدخول غير صحيح أو غير نشط');
        }
        throw Exception(e.message ?? 'تعذر التحقق من كود الدخول');
      } on firebase_auth.FirebaseAuthException catch (e) {
        final message = _mapFirebaseAuthError(e);
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          throw Exception('كلمة المرور غير صحيحة لهذا الكود');
        }
        throw Exception(message);
      }
    });
  }

  Future<void> bindAccountDevice(String deviceId) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo is MockAuthRepository) {
      debugPrint('Mock Mode: Skipping bindAccountDevice call');
      return;
    }

    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('bindAccountDevice').call({
        'deviceId': deviceId,
      });
    } catch (e) {
      debugPrint('Device binding failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> lookupCode(String code) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo is MockAuthRepository) {
      // In mock mode, any 6-7 char code is valid
      return {
        'email': 'mock@getmanar.com',
        'isActive': true,
        'role': 'student',
        'maskedPhone': '*******789',
      };
    }

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('lookupUserCode').call({
        'code': code,
      });
      return result.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Code lookup failed: $e');
      rethrow;
    }
  }

  Future<bool> verifyPhoneMatch(String code, String phone) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo is MockAuthRepository) {
      return true; // Always match in mock
    }

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('verifyUserPhoneMatch').call(
        {'code': code, 'inputPhone': phone},
      );
      return result.data['success'] == true;
    } catch (e) {
      debugPrint('Phone match failed: $e');
      rethrow;
    }
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      verificationFailed: (message) => onError(message),
    );
  }

  Future<void> confirmOTP(String verificationId, String smsCode) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo is MockAuthRepository) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final user = await repo.signInWithPhoneCredential(
          verificationId,
          smsCode,
        );
        if (user != null) _failedLoginAttempts = 0;
        return user;
      });
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await repo.signInWithPhoneCredential(
        verificationId,
        smsCode,
      );
      if (user != null) {
        _failedLoginAttempts = 0;
      }
      return user;
    });
  }

  Future<User?> _loginAndVerify2FA(Future<User?> Function() loginAction) async {
    final user = await _loginAndClearCache(loginAction);
    if (user == null) return null;

    // Check if 2FA is required (Admin, Deputy, Counselor)
    final sensitiveRoles = [
      UserRole.admin,
      UserRole.deputy,
      UserRole.counselor,
      UserRole.superAdmin,
    ];

    if (sensitiveRoles.contains(user.role) || user.isTwoFactorEnabled) {
      // In a real app, this would trigger an OTP.
      // For this demo, we'll mark it as "Verification Required"
      // which the UI will handle if needed.
      debugPrint('2FA REQUIRED for ${user.name} (${user.role})');
      // For now, we allow login but log the audit requirement.
    }

    return user;
  }

  void debugPrint(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  String _mapFirebaseAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'تم إيقاف حسابك. يرجى مراجعة إدارة المدرسة.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      default:
        return 'تعذر إتمام عملية تسجيل الدخول. يرجى المحاولة لاحقاً.';
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
      return null;
    });
  }

  Future<void> refreshUser() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.getCurrentUser();
    });
  }
}
