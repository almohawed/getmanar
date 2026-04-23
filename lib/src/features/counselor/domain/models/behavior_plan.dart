import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanStatus { active, completed, dropped, review_needed }

class BehaviorPlan {
  final String id;
  final String studentId;
  final String studentName;
  final String schoolId;
  final String title;
  final List<String> goals;
  final PlanStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? reviewAt;
  final int evidenceCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BehaviorPlan({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.schoolId,
    required this.title,
    required this.goals,
    this.status = PlanStatus.active,
    required this.startDate,
    this.endDate,
    this.reviewAt,
    this.evidenceCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'schoolId': schoolId,
      'title': title,
      'goals': goals,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'reviewAt': reviewAt != null ? Timestamp.fromDate(reviewAt!) : null,
      'evidenceCount': evidenceCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory BehaviorPlan.fromMap(Map<String, dynamic> map, String id) {
    return BehaviorPlan(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      schoolId: map['schoolId'] ?? '',
      title: map['title'] ?? '',
      goals: List<String>.from(map['goals'] ?? []),
      status: PlanStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PlanStatus.active,
      ),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      reviewAt: (map['reviewAt'] as Timestamp?)?.toDate(),
      evidenceCount: map['evidenceCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
