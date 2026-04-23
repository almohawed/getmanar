import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherPreference {
  final String teacherId;
  final String schoolId;
  final String sessionId;
  final List<String> unwantedSlots; // Format: "DayName-PeriodIndex" e.g. "Sunday-1"
  final DateTime submittedAt;

  TeacherPreference({
    required this.teacherId,
    required this.schoolId,
    required this.sessionId,
    required this.unwantedSlots,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'schoolId': schoolId,
      'sessionId': sessionId,
      'unwantedSlots': unwantedSlots,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }

  factory TeacherPreference.fromMap(Map<String, dynamic> map) {
    return TeacherPreference(
      teacherId: map['teacherId'],
      schoolId: map['schoolId'],
      sessionId: map['sessionId'],
      unwantedSlots: List<String>.from(map['unwantedSlots'] ?? []),
      submittedAt: (map['submittedAt'] as Timestamp).toDate(),
    );
  }
}
