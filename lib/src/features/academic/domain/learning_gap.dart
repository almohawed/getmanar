import 'package:cloud_firestore/cloud_firestore.dart';

enum GapPriority {
  critical,  // حرجة
  medium,    // متوسطة
  low,       // منخفضة
}

class LearningGap {
  final String id;
  final String schoolId;
  final String subject;
  final String className;
  final String description;
  final int affectedStudents;
  final GapPriority priority;
  final bool isResolved;
  final DateTime discoveredAt;

  LearningGap({
    required this.id,
    required this.schoolId,
    required this.subject,
    required this.className,
    required this.description,
    required this.affectedStudents,
    required this.priority,
    this.isResolved = false,
    required this.discoveredAt,
  });

  factory LearningGap.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LearningGap(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      subject: data['subject'] ?? '',
      className: data['className'] ?? '',
      description: data['description'] ?? '',
      affectedStudents: data['affectedStudents'] ?? 0,
      priority: _parsePriority(data['priority']),
      isResolved: data['isResolved'] ?? false,
      discoveredAt: (data['discoveredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'subject': subject,
      'className': className,
      'description': description,
      'affectedStudents': affectedStudents,
      'priority': priority.name,
      'isResolved': isResolved,
      'discoveredAt': Timestamp.fromDate(discoveredAt),
    };
  }

  static GapPriority _parsePriority(dynamic value) {
    if (value == null) return GapPriority.low;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'critical':
          return GapPriority.critical;
        case 'medium':
          return GapPriority.medium;
        default:
          return GapPriority.low;
      }
    }
    return GapPriority.low;
  }

  String get priorityText {
    switch (priority) {
      case GapPriority.critical:
        return 'حرجة';
      case GapPriority.medium:
        return 'متوسطة';
      case GapPriority.low:
        return 'منخفضة';
    }
  }
}
