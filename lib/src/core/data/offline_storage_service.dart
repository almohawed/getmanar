import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kOfflineQueueBox = 'offline_queue';
const String kBehaviorCacheBox = 'behavior_cache';
const String kAttendanceCacheBox = 'attendance_cache';
const String kStudentCacheBox = 'student_cache';
const String kSettingsBox = 'settings_box';

final offlineStorageProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService();
});

class OfflineStorageService {
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    await Hive.openBox(kOfflineQueueBox);
    await Hive.openBox(kBehaviorCacheBox);
    await Hive.openBox(kAttendanceCacheBox);
    await Hive.openBox(kStudentCacheBox);
    await Hive.openBox(kSettingsBox);
    _isInitialized = true;
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<void> queueOperation(String type, Map<String, dynamic> data) async {
    final box = Hive.box(kOfflineQueueBox);
    final operation = {
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await box.add(operation);
  }

  Future<void> cacheData(
    String boxName,
    String key,
    Map<String, dynamic> data,
  ) async {
    final box = Hive.box(boxName);
    await box.put(key, data);
  }

  List<Map<String, dynamic>> getAllCachedData(String boxName) {
    final box = Hive.box(boxName);
    // Handle potential type issues if data wasn't Map<String, dynamic>
    // Hive stores Map<dynamic, dynamic> by default
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> clearQueue() async {
    final box = Hive.box(kOfflineQueueBox);
    await box.clear();
  }

  List<Map<String, dynamic>> getQueue() {
    final box = Hive.box(kOfflineQueueBox);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Map<dynamic, Map<String, dynamic>> getQueueMap() {
    final box = Hive.box(kOfflineQueueBox);
    final map = <dynamic, Map<String, dynamic>>{};
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        map[key] = Map<String, dynamic>.from(value as Map);
      }
    }
    return map;
  }

  Future<void> removeQueueItem(dynamic key) async {
    final box = Hive.box(kOfflineQueueBox);
    await box.delete(key);
  }

  Future<void> clearAllCaches() async {
    await Hive.box(kOfflineQueueBox).clear();
    await Hive.box(kBehaviorCacheBox).clear();
    await Hive.box(kAttendanceCacheBox).clear();
    await Hive.box(kStudentCacheBox).clear();
  }

  Future<void> saveLastLogin(String userId) async {
    final box = Hive.box(kSettingsBox);
    final key = 'last_login_$userId';
    final existing = box.get(key);

    String? previous;
    if (existing is Map) {
      final map = Map<String, dynamic>.from(existing);
      final value = map['lastLoginAt'];
      if (value is String) {
        previous = value;
      }
    }

    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'lastLoginAt': now,
      if (previous != null) 'previousLoginAt': previous,
    };

    await box.put(key, data);
  }

  Map<String, dynamic>? getLastLogin(String userId) {
    final box = Hive.box(kSettingsBox);
    final raw = box.get('last_login_$userId');
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveString(String key, String value) async {
    final box = Hive.box(kSettingsBox);
    await box.put(key, value);
  }

  String? getString(String key) {
    final box = Hive.box(kSettingsBox);
    final value = box.get(key);
    return value is String ? value : null;
  }
}
