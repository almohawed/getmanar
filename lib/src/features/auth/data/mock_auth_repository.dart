import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/mock_data.dart';
import '../domain/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  User? _currentUser;

  @override
  Future<User?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _currentUser;
  }

  @override
  Future<void> changePassword(String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // In mock, we don't actually change password logic effectively
    // unless we track it in memory map. For now just success.
  }

  @override
  Future<User?> login(String identifier, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    try {
      // 1. Check static mock users
      final allStaticUsers = [
        ...mockStudents,
        ...mockTeachers,
        ...mockDeputies,
        ...mockCounselors,
        ...mockAdmins,
        ...mockParents,
        mockPrincipal, // Single object, no spread
        mockSuperAdmin, // Single object, no spread
      ];

      try {
        final lowerIdentifier = identifier.toLowerCase().trim();
        final user = allStaticUsers.firstWhere((u) {
          final emailMatch = u.email.toLowerCase() == lowerIdentifier;
          final phoneMatch = u.phoneNumber == identifier;
          final idMatch = u.identityNumber == identifier;
          final stuMatch = u.studentCode == identifier;
          final idDirectMatch = u.id == identifier;
          return emailMatch ||
              phoneMatch ||
              idMatch ||
              stuMatch ||
              idDirectMatch;
        });
        return _validatePassword(user, password);
      } catch (_) {
        // User not found in static lists, continue to dynamic files
      }

      // 2. Check dynamic users from JSON files (Local Storage)
      // Note: This only works on Mobile/Desktop where getApplicationDocumentsDirectory is supported
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();

        // Helper to search in a file
        Future<User?> searchInFile(String filename) async {
          final file = File('${directory.path}/$filename');
          if (await file.exists()) {
            try {
              final content = await file.readAsString();
              final List<dynamic> jsonList = json.decode(content);
              final users = jsonList.map((e) => User.fromMap(e)).toList();
              try {
                return users.firstWhere(
                  (u) =>
                      u.email.toLowerCase() == identifier.toLowerCase() ||
                      u.phoneNumber == identifier ||
                      u.identityNumber == identifier,
                );
              } catch (_) {
                return null;
              }
            } catch (e) {
              debugPrint('Error reading $filename: $e');
            }
          }
          return null;
        }

        // Check teachers.json
        User? foundUser = await searchInFile('teachers.json');
        if (foundUser != null) return _validatePassword(foundUser, password);

        // Check staff.json
        foundUser = await searchInFile('staff.json');
        if (foundUser != null) return _validatePassword(foundUser, password);

        // Check students.json
        foundUser = await searchInFile('students.json');
        if (foundUser != null) return _validatePassword(foundUser, password);
      }

      // 3. Check Firestore (Global Fallback for Real Users)
      // This allows users created by Admin (Web) to be found by App (Mobile)
      try {
        if (Firebase.apps.isNotEmpty) {
          final query = await FirebaseFirestore.instance
              .collectionGroup('Users')
              .where('email', isEqualTo: identifier)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final user = User.fromMap(query.docs.first.data());
            return _validatePassword(user, password);
          }

          // Also try phone
          final queryPhone = await FirebaseFirestore.instance
              .collectionGroup('Users')
              .where('phoneNumber', isEqualTo: identifier)
              .limit(1)
              .get();

          if (queryPhone.docs.isNotEmpty) {
            final user = User.fromMap(queryPhone.docs.first.data());
            return _validatePassword(user, password);
          }
        }
      } catch (e) {
        debugPrint('Firestore Lookup Error: $e');
      }

      return null; // Not found anywhere
    } catch (e) {
      debugPrint('Login Error: $e');
      return null;
    }
  }

  User? _validatePassword(User user, String password) {
    bool isValid = false;

    // Super Owner Specific Check
    if (user.email == 'Mohawed32' && password == 'Aa123!!') {
      isValid = true;
    }
    // Default password check for others (Mock Mode)
    // We accept 123, 123456 for simplicity in mock mode since we don't store passwords
    else if (password == '123456' ||
        password == '123' ||
        password == '1234' ||
        password == '111') {
      isValid = true;
    }
    // Master password for ALL mock users
    else if (password == 'admin' || password == 'pass') {
      isValid = true;
    }
    // Legacy test pass
    else if (user.email.startsWith('mn') && password == '123') {
      isValid = true;
    }
    // Admin Ahmed check (from user request)
    else if (user.email == 'ahmed' && password == '123') {
      isValid = true;
    }

    if (!isValid) return null;

    _currentUser = user;
    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  @override
  Future<void> authStateReady() async {
    return;
  }

  @override
  Future<void> reauthenticate(String password) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return;
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) verificationFailed,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate code sent for any phone number
    codeSent('mock-verification-id', 12345);
  }

  @override
  Future<User?> signInWithPhoneCredential(
    String verificationId,
    String smsCode,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    if (smsCode == '123456') {
      // In mock, we return the principal user if code matches
      _currentUser = mockPrincipal;
      return mockPrincipal;
    }
    return null;
  }
}
