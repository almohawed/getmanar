import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_task_entity.dart';
import '../domain/admin_task_repository.dart';
import 'admin_task_model.dart';

class FirestoreAdminTaskRepository implements AdminTaskRepository {
  final FirebaseFirestore _firestore;

  FirestoreAdminTaskRepository(this._firestore);

  CollectionReference _getCollection(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('AdminTasks');
  }

  @override
  Future<void> createTask(AdminTaskEntity task) async {
    final model = AdminTaskModel(
      id: task.id,
      schoolId: task.schoolId,
      title: task.title,
      description: task.description,
      assignedToId: task.assignedToId,
      assignedToName: task.assignedToName,
      assignedToRole: task.assignedToRole,
      status: task.status,
      priority: task.priority,
      type: task.type,
      dueDate: task.dueDate,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      notes: task.notes,
      evidenceCount: task.evidenceCount,
      createdByUserId: task.createdByUserId,
      createdByRole: task.createdByRole,
      escalationLevel: task.escalationLevel,
    );
    // If id is empty, generate one? Usually id is passed or generated here.
    // Assuming task.id is already set or we use doc().set().
    // If task.id is empty string, we might want to generate a new doc ID.
    // But Entity usually has ID. Let's assume it's provided.
    await _getCollection(task.schoolId).doc(task.id).set(model.toMap());
  }

  @override
  Future<void> updateTaskStatus(
    String schoolId,
    String taskId,
    AdminTaskStatus status,
  ) async {
    await _getCollection(schoolId).doc(taskId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<AdminTaskEntity>> watchTasks(String schoolId) {
    return _getCollection(schoolId)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs.map((doc) {
            return AdminTaskModel.fromFirestore(doc);
          }).toList();
          // ترتيب محلي بدلاً من Firestore orderBy لتجنب مشكلة الـ index
          tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return tasks;
        });
  }

  @override
  Future<List<AdminTaskEntity>> getTasksByRole(
    String schoolId,
    String role,
  ) async {
    final snapshot = await _getCollection(schoolId)
        .where('assignedToRole', isEqualTo: role)
        .orderBy('dueDate', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AdminTaskModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<List<AdminTaskEntity>> getOverdueTasks(String schoolId) async {
    final now = DateTime.now();
    // Complex query: status IN [pending, inProgress] AND dueDate < now
    // This requires a composite index.
    final snapshot = await _getCollection(schoolId)
        .where(
          'status',
          whereIn: [
            AdminTaskStatus.open.name,
            AdminTaskStatus.in_progress.name,
          ],
        )
        .where('dueDate', isLessThan: Timestamp.fromDate(now))
        .get();

    return snapshot.docs
        .map((doc) => AdminTaskModel.fromFirestore(doc))
        .toList();
  }

  @override
  Stream<AdminTaskEntity?> watchTaskById(String schoolId, String taskId) {
    return _getCollection(schoolId)
        .doc(taskId)
        .snapshots()
        .map((doc) => doc.exists ? AdminTaskModel.fromFirestore(doc) : null);
  }
}
