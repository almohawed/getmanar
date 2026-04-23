import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _pinKey = 'user_pin_hash';
  static const String _sessionKey = 'user_session_token';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _lastAuthKey = 'last_full_auth_time';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutUntilKey = 'pin_lockout_until';

  // Save PIN and session info
  Future<void> setupPin(String userId, String role, String pin, String sessionToken) async {
    final pinHash = _hashPin(pin);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userRoleKey, value: role);
    await _storage.write(key: _pinKey, value: pinHash);
    await _storage.write(key: _sessionKey, value: sessionToken);
    await _storage.write(key: _lastAuthKey, value: DateTime.now().toIso8601String());
    await _storage.write(key: _failedAttemptsKey, value: '0');
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    // Check lockout
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr != null) {
      final lockoutUntil = DateTime.parse(lockoutUntilStr);
      if (DateTime.now().isBefore(lockoutUntil)) {
        return false; // Still locked out
      }
    }

    final inputHash = _hashPin(pin);
    if (inputHash == storedHash) {
      await _storage.write(key: _failedAttemptsKey, value: '0');
      return true;
    } else {
      await _incrementFailedAttempts();
      return false;
    }
  }

  Future<void> _incrementFailedAttempts() async {
    final attemptsStr = await _storage.read(key: _failedAttemptsKey) ?? '0';
    int attempts = int.parse(attemptsStr) + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());

    if (attempts >= 5) {
      final lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      await _storage.write(key: _lockoutUntilKey, value: lockoutUntil.toIso8601String());
    }
  }

  Future<bool> isLockedOut() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) return false;
    final lockoutUntil = DateTime.parse(lockoutUntilStr);
    return DateTime.now().isBefore(lockoutUntil);
  }

  Future<DateTime?> getLockoutTime() async {
    final lockoutUntilStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutUntilStr == null) return null;
    return DateTime.parse(lockoutUntilStr);
  }

  Future<bool> hasPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  Future<String?> getStoredUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<String?> getStoredRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  Future<String?> getSessionToken() async {
    return await _storage.read(key: _sessionKey);
  }

  Future<DateTime?> getLastFullAuth() async {
    final time = await _storage.read(key: _lastAuthKey);
    if (time == null) return null;
    return DateTime.parse(time);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
