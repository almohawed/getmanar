import 'package:cloud_firestore/cloud_firestore.dart';

enum CycleStatus {
  active, // Currently gathering data (the "2 weeks" period)
  pendingDeputy, // Waiting for Deputy Approval
  pendingTeachers, // Optional: Waiting for Teacher Voting
  published, // Finalized and visible
  archived, // Old cycles
}

class DistinguishedCycle {
  final String id;
  final String schoolId;
  final DateTime startDate;
  final DateTime endDate;
  final CycleStatus status;
  final DateTime? publishedAt;

  DistinguishedCycle({
    required this.id,
    required this.schoolId,
    required this.startDate,
    required this.endDate,
    this.status = CycleStatus.active,
    this.publishedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.name,
      'publishedAt': publishedAt != null
          ? Timestamp.fromDate(publishedAt!)
          : null,
    };
  }

  factory DistinguishedCycle.fromMap(Map<String, dynamic> map) {
    return DistinguishedCycle(
      id: map['id'],
      schoolId: map['schoolId'],
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      status: CycleStatus.values.firstWhere(
        (e) =>
            e.name == map['status'] ||
            (e == CycleStatus.pendingDeputy &&
                map['status'] == 'pending_deputy') ||
            (e == CycleStatus.pendingTeachers &&
                map['status'] == 'pending_teachers'),
        orElse: () => CycleStatus.active,
      ),
      publishedAt: map['publishedAt'] != null
          ? (map['publishedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
