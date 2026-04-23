import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_task_entity.dart';

class AdminTaskModel extends AdminTaskEntity {
  const AdminTaskModel({
    required super.id,
    required super.schoolId,
    required super.title,
    super.description,
    super.relatedStudentId,
    super.relatedCaseId,
    super.assignedToId,
    super.assignedToName,
    super.assignedToRole,
    super.status,
    super.priority,
    super.type,
    required super.dueDate,
    required super.createdAt,
    super.updatedAt,
    super.notes,
    super.evidenceCount,
    super.createdByUserId,
    super.createdByRole,
    super.escalationLevel = 0,
  });

  factory AdminTaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminTaskModel(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      relatedStudentId: data['relatedStudentId'],
      relatedCaseId: data['relatedCaseId'],
      assignedToId: data['assignedToId'],
      assignedToName: data['assignedToName'],
      assignedToRole: data['assignedToRole'],
      status: AdminTaskStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AdminTaskStatus.open,
      ),
      priority: AdminTaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => AdminTaskPriority.medium,
      ),
      type: AdminTaskType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AdminTaskType.general,
      ),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      evidenceCount: data['evidenceCount'] ?? 0,
      createdByUserId: data['createdByUserId'],
      createdByRole: data['createdByRole'],
      escalationLevel: data['escalationLevel'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'title': title,
      'description': description,
      'relatedStudentId': relatedStudentId,
      'relatedCaseId': relatedCaseId,
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'assignedToRole': assignedToRole,
      'status': status.name,
      'priority': priority.name,
      'type': type.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'notes': notes,
      'evidenceCount': evidenceCount,
      'createdByUserId': createdByUserId,
      'createdByRole': createdByRole,
      'escalationLevel': escalationLevel,
    };
  }
}
