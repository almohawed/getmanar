import 'package:cloud_firestore/cloud_firestore.dart';

class CoreRule {
  final String id;
  final String title;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  CoreRule({
    required this.id,
    required this.title,
    required this.description,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory CoreRule.fromMap(Map<String, dynamic> map, String id) {
    return CoreRule(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  CoreRule copyWith({
    String? id,
    String? title,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return CoreRule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
