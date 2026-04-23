import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'offline_storage_service.dart';
import '../../features/behavior/presentation/behavior_controller.dart';
import '../../core/domain/models/behavior_record.dart';
import '../../features/assignments/data/firestore_assignments_repository.dart';
import '../../features/assignments/domain/assignment.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  final Ref _ref;
  StreamSubscription? _subscription;
  bool _isSyncing = false;

  SyncService(this._ref) {
    _init();
  }

  void _init() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncPendingData();
      }
    });
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final offlineService = _ref.read(offlineStorageProvider);
      final queueMap = offlineService.getQueueMap();

      if (queueMap.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('Starting sync of ${queueMap.length} items...');

      final behaviorRepo = _ref.read(behaviorRepositoryProvider);
      final assignmentsRepo = _ref.read(firestoreAssignmentRepositoryProvider);

      for (final entry in queueMap.entries) {
        final key = entry.key;
        final item = entry.value;
        final type = item['type'] as String;
        final data = item['data'] as Map<String, dynamic>;

        try {
          bool success = false;
          switch (type) {
            case 'ADD_BEHAVIOR':
              final record = BehaviorRecord.fromMap(data);
              await behaviorRepo.addBehaviorRecord(record);
              success = true;
              break;
            case 'ADD_ASSIGNMENT':
              final assignment = Assignment.fromMap(data);
              await assignmentsRepo.addAssignment(assignment);
              success = true;
              break;
            case 'UPDATE_ASSIGNMENT':
              final assignment = Assignment.fromMap(data);
              await assignmentsRepo.updateAssignment(assignment);
              success = true;
              break;
            case 'DELETE_ASSIGNMENT':
              final id = data['id'] as String;
              await assignmentsRepo.deleteAssignment(id);
              success = true;
              break;
            case 'SUBMIT_ASSIGNMENT':
              final id = data['id'] as String;
              await assignmentsRepo.submitAssignment(id);
              success = true;
              break;
            default:
              debugPrint('Unknown operation type: $type');
              success = true;
          }

          if (success) {
            await offlineService.removeQueueItem(key);
          }
        } catch (e) {
          debugPrint('Error syncing item $type (key: $key): $e');
          // Leave in queue to retry later
        }
      }

      debugPrint('Sync attempt complete.');
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
