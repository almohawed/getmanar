import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherPreferenceEntity {
  final String teacherId;
  final String scheduleRunId;
  final List<Map<String, int>> unavailableSlots; // [{dayIndex: 0, period: 1}]
  final bool noSeventhPeriod;
  final bool preferConsecutive;
  final bool submitted;
  final DateTime? submittedAt;

  TeacherPreferenceEntity({
    required this.teacherId,
    required this.scheduleRunId,
    required this.unavailableSlots,
    this.noSeventhPeriod = false,
    this.preferConsecutive = false,
    this.submitted = false,
    this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'scheduleRunId': scheduleRunId,
      'unavailableSlots': unavailableSlots,
      'noSeventhPeriod': noSeventhPeriod,
      'preferConsecutive': preferConsecutive,
      'submitted': submitted,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
    };
  }

  factory TeacherPreferenceEntity.fromMap(Map<String, dynamic> map) {
    return TeacherPreferenceEntity(
      teacherId: map['teacherId'] ?? '',
      scheduleRunId: map['scheduleRunId'] ?? '',
      unavailableSlots: (map['unavailableSlots'] as List<dynamic>?)
              ?.map((e) => Map<String, int>.from(e))
              .toList() ??
          [],
      noSeventhPeriod: map['noSeventhPeriod'] ?? false,
      preferConsecutive: map['preferConsecutive'] ?? false,
      submitted: map['submitted'] ?? false,
      submittedAt: map['submittedAt'] != null
          ? (map['submittedAt'] as Timestamp).toDate()
          : null,
    );
  }

  TeacherPreferenceEntity copyWith({
    String? teacherId,
    String? scheduleRunId,
    List<Map<String, int>>? unavailableSlots,
    bool? noSeventhPeriod,
    bool? preferConsecutive,
    bool? submitted,
    DateTime? submittedAt,
  }) {
    return TeacherPreferenceEntity(
      teacherId: teacherId ?? this.teacherId,
      scheduleRunId: scheduleRunId ?? this.scheduleRunId,
      unavailableSlots: unavailableSlots ?? this.unavailableSlots,
      noSeventhPeriod: noSeventhPeriod ?? this.noSeventhPeriod,
      preferConsecutive: preferConsecutive ?? this.preferConsecutive,
      submitted: submitted ?? this.submitted,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
