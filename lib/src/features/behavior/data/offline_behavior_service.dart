import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/offline_storage_service.dart';
import '../../../core/domain/models/behavior_record.dart';

final offlineBehaviorServiceProvider = Provider<OfflineBehaviorService>((ref) {
  final storage = ref.watch(offlineStorageProvider);
  return OfflineBehaviorService(storage);
});

class OfflineBehaviorService {
  final OfflineStorageService _storage;

  OfflineBehaviorService(this._storage);

  Future<bool> isOnline() => _storage.isOnline();

  Future<void> cacheBehaviorRecords(List<BehaviorRecord> records) async {
    for (var record in records) {
      await _storage.cacheData(kBehaviorCacheBox, record.id, record.toMap());
    }
  }

  List<BehaviorRecord> getCachedBehaviorRecords() {
    final data = _storage.getAllCachedData(kBehaviorCacheBox);
    return data.map((e) => BehaviorRecord.fromMap(e)).toList();
  }

  Future<void> queueAddBehavior(BehaviorRecord record) async {
    // 1. Cache locally immediately for optimistic UI
    await _storage.cacheData(kBehaviorCacheBox, record.id, record.toMap());
    
    // 2. Queue operation
    await _storage.queueOperation('ADD_BEHAVIOR', record.toMap());
  }

  // Helper to filter cached records
  List<BehaviorRecord> getCachedRecordsForStudent(String studentId) {
    return getCachedBehaviorRecords()
        .where((r) => r.studentId == studentId)
        .toList();
  }

  List<BehaviorRecord> getCachedRecordsForClass(String classId) {
    return getCachedBehaviorRecords()
        .where((r) => r.classId == classId)
        .toList();
  }

  List<BehaviorRecord> getCachedRecordsForTeacher(String teacherId) {
    return getCachedBehaviorRecords()
        .where((r) => r.teacherId == teacherId)
        .toList();
  }
}
