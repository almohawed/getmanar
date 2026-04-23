import 'admin_task_entity.dart';

abstract class AdminTaskRepository {
  Future<void> createTask(AdminTaskEntity task);
  Future<void> updateTaskStatus(
    String schoolId,
    String taskId,
    AdminTaskStatus status,
  );
  Stream<List<AdminTaskEntity>> watchTasks(String schoolId);
  Future<List<AdminTaskEntity>> getTasksByRole(String schoolId, String role);
  Future<List<AdminTaskEntity>> getOverdueTasks(String schoolId);
  Stream<AdminTaskEntity?> watchTaskById(String schoolId, String taskId);
}
