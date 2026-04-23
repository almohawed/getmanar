import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_admin_task_repository.dart';
import '../data/firestore_admin_task_evidence_repository.dart';
import '../domain/admin_task_entity.dart';
import '../domain/admin_task_evidence_entity.dart';
import '../domain/admin_task_repository.dart';
import '../domain/admin_task_evidence_repository.dart';

final adminTaskRepositoryProvider = Provider<AdminTaskRepository>((ref) {
  return FirestoreAdminTaskRepository(FirebaseFirestore.instance);
});

final adminTaskEvidenceRepositoryProvider =
    Provider<AdminTaskEvidenceRepository>((ref) {
      return FirestoreAdminTaskEvidenceRepository(FirebaseFirestore.instance);
    });

final adminTasksStreamProvider =
    StreamProvider.autoDispose<List<AdminTaskEntity>>((ref) {
      final userAsync = ref.watch(authStateProvider);
      final user = userAsync.value;
      if (user == null || user.schoolId == null) {
        return Stream.value([]);
      }
      final repo = ref.watch(adminTaskRepositoryProvider);
      return repo.watchTasks(user.schoolId!);
    });

final taskStatsProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final tasksAsync = ref.watch(adminTasksStreamProvider);
  return tasksAsync.when(
    data: (tasks) {
      final overdue = tasks
          .where((t) => t.isOverdue || t.status == AdminTaskStatus.overdue)
          .length;
      final open = tasks
          .where((t) => t.status == AdminTaskStatus.open && !t.isOverdue)
          .length;
      final inProgress = tasks
          .where((t) => t.status == AdminTaskStatus.in_progress && !t.isOverdue)
          .length;
      final done = tasks.where((t) => t.status == AdminTaskStatus.done).length;
      return {
        'overdue': overdue,
        'open': open,
        'inProgress': inProgress,
        'done': done,
        'total': tasks.length,
      };
    },
    loading: () => {
      'overdue': 0,
      'open': 0,
      'inProgress': 0,
      'done': 0,
      'total': 0,
    },
    error: (_, __) => {
      'overdue': 0,
      'open': 0,
      'inProgress': 0,
      'done': 0,
      'total': 0,
    },
  );
});

final overdueTasksProvider = Provider.autoDispose<List<AdminTaskEntity>>((ref) {
  final tasksAsync = ref.watch(adminTasksStreamProvider);
  return tasksAsync.when(
    data: (tasks) => tasks
        .where((t) => t.isOverdue || t.status == AdminTaskStatus.overdue)
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final criticalTasksProvider = Provider.autoDispose<List<AdminTaskEntity>>((
  ref,
) {
  final tasksAsync = ref.watch(adminTasksStreamProvider);
  return tasksAsync.when(
    data: (tasks) {
      final critical = tasks.where((t) => t.isCritical).toList();
      // Sort: Urgent first, then High. Within priority: Overdue first, then Due Today.
      critical.sort((a, b) {
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(
            a.priority.index,
          ); // Higher index = Higher priority (assuming Urgent > High)
        }
        return a.dueDate.compareTo(b.dueDate);
      });
      return critical.take(5).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final tasksMissingEvidenceProvider =
    Provider.autoDispose<List<AdminTaskEntity>>((ref) {
      final tasksAsync = ref.watch(adminTasksStreamProvider);
      return tasksAsync.when(
        data: (tasks) => tasks
            .where(
              (t) =>
                  (t.status == AdminTaskStatus.done ||
                      t.status == AdminTaskStatus.in_progress) &&
                  t.evidenceCount == 0,
            )
            .toList(),
        loading: () => [],
        error: (_, __) => [],
      );
    });

final taskEvidenceStreamProvider = StreamProvider.autoDispose
    .family<List<AdminTaskEvidenceEntity>, String>((ref, taskId) {
      final userAsync = ref.watch(authStateProvider);
      final user = userAsync.value;
      if (user == null || user.schoolId == null) {
        return Stream.value([]);
      }
      final repo = ref.watch(adminTaskEvidenceRepositoryProvider);
      return repo.watchEvidence(user.schoolId!, taskId);
    });

final taskByIdProvider =
    StreamProvider.autoDispose.family<AdminTaskEntity?, String>((ref, taskId) {
      final userAsync = ref.watch(authStateProvider);
      final user = userAsync.value;
      if (user == null || user.schoolId == null) {
        return Stream.value(null);
      }
      final repo = ref.watch(adminTaskRepositoryProvider);
      return repo.watchTaskById(user.schoolId!, taskId);
    });
