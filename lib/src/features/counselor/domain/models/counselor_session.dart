import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { scheduled, completed, cancelled, no_show }

enum SessionType { individual, group, family, teacher_meeting }

class CounselorSession {
  final String id;
  final String schoolId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final SessionStatus status;
  final SessionType type;
  final List<String> attendeeIds;
  final String? caseId; // Optional link to a StudentCase
  final int evidenceCount;
  final String counselorId;
  final bool isConfidential;
  final List<String> attachments; // URLs to files

  CounselorSession({
    required this.id,
    required this.schoolId,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.durationMinutes = 30,
    this.status = SessionStatus.scheduled,
    this.type = SessionType.individual,
    required this.attendeeIds,
    this.caseId,
    this.evidenceCount = 0,
    required this.counselorId,
    this.isConfidential = true,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'title': title,
      'description': description,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'status': status.name,
      'type': type.name,
      'attendeeIds': attendeeIds,
      'caseId': caseId,
      'evidenceCount': evidenceCount,
      'counselorId': counselorId,
      'isConfidential': isConfidential,
      'attachments': attachments,
    };
  }

  factory CounselorSession.fromMap(Map<String, dynamic> map, String id) {
    return CounselorSession(
      id: id,
      schoolId: map['schoolId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      scheduledAt:
          (map['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: map['durationMinutes'] ?? 30,
      status: SessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SessionStatus.scheduled,
      ),
      type: SessionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SessionType.individual,
      ),
      attendeeIds: List<String>.from(map['attendeeIds'] ?? []),
      caseId: map['caseId'],
      evidenceCount: map['evidenceCount'] ?? 0,
      counselorId: map['counselorId'] ?? '',
      isConfidential: map['isConfidential'] ?? true,
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
}
