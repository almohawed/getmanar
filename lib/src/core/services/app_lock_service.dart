import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockService {
  final FlutterSecureStorage _storage;

  const AppLockService(this._storage);

  static const _kEnabled = 'app_lock_enabled';
  static const _kPinHash = 'app_lock_pin_hash';
  static const _kBiometricEnabled = 'app_lock_biometric_enabled';

  Future<bool> isEnabled(String uid) async {
    final v = await _storage.read(key: '$_kEnabled:$uid');
    return v == '1';
  }

  Future<void> setEnabled(String uid, bool enabled) async {
    await _storage.write(key: '$_kEnabled:$uid', value: enabled ? '1' : '0');
  }

  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    await _storage.write(
      key: '$_kBiometricEnabled:$uid',
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> isBiometricEnabled(String uid) async {
    final v = await _storage.read(key: '$_kBiometricEnabled:$uid');
    return v == '1';
  }

  Future<void> setPin(String uid, String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _storage.write(key: '$_kPinHash:$uid', value: hash);
  }

  Future<bool> hasPin(String uid) async {
    final v = await _storage.read(key: '$_kPinHash:$uid');
    return (v ?? '').trim().isNotEmpty;
  }

  Future<bool> verifyPin(String uid, String pin) async {
    final stored = await _storage.read(key: '$_kPinHash:$uid');
    if (stored == null || stored.trim().isEmpty) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return stored == hash;
  }

  Future<void> clear(String uid) async {
    await _storage.delete(key: '$_kEnabled:$uid');
    await _storage.delete(key: '$_kPinHash:$uid');
    await _storage.delete(key: '$_kBiometricEnabled:$uid');
  }
}

