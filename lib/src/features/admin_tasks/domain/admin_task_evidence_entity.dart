import 'package:equatable/equatable.dart';

enum AdminTaskEvidenceType {
  image,
  document,
  link,
  note,
}

class AdminTaskEvidenceEntity extends Equatable {
  final String id;
  final String taskId;
  final String addedByUserId;
  final String addedByUserName;
  final AdminTaskEvidenceType type;
  final String url; // URL to file or link
  final String? description;
  final DateTime createdAt;

  const AdminTaskEvidenceEntity({
    required this.id,
    required this.taskId,
    required this.addedByUserId,
    required this.addedByUserName,
    required this.type,
    required this.url,
    this.description,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        taskId,
        addedByUserId,
        addedByUserName,
        type,
        url,
        description,
        createdAt,
      ];
}
