import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_task_evidence_entity.dart';

class AdminTaskEvidenceModel extends AdminTaskEvidenceEntity {
  const AdminTaskEvidenceModel({
    required super.id,
    required super.taskId,
    required super.addedByUserId,
    required super.addedByUserName,
    required super.type,
    required super.url,
    super.description,
    required super.createdAt,
  });

  factory AdminTaskEvidenceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminTaskEvidenceModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      addedByUserId: data['addedByUserId'] ?? '',
      addedByUserName: data['addedByUserName'] ?? '',
      type: AdminTaskEvidenceType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AdminTaskEvidenceType.note,
      ),
      url: data['url'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'type': type.name,
      'url': url,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
