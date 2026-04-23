import 'package:cloud_firestore/cloud_firestore.dart';

enum CaseStatus { open, in_progress, resolved, closed }

enum CasePriority { low, medium, high, urgent }

class StudentCase {
  final String id;
  final String studentId;
  final String studentName;
  final String schoolId;
  final String title;
  final String description;
  final CaseStatus status;
  final CasePriority priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? assignedTo;
  final int evidenceCount;

  StudentCase({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.schoolId,
    required this.title,
    required this.description,
    this.status = CaseStatus.open,
    this.priority = CasePriority.medium,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.assignedTo,
    this.evidenceCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'schoolId': schoolId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'assignedTo': assignedTo,
      'evidenceCount': evidenceCount,
    };
  }

  factory StudentCase.fromMap(Map<String, dynamic> map, String id) {
    return StudentCase(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      schoolId: map['schoolId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: CaseStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CaseStatus.open,
      ),
      priority: CasePriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => CasePriority.medium,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
      assignedTo: map['assignedTo'],
      evidenceCount: map['evidenceCount'] ?? 0,
    );
  }
}
