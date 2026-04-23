import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleMode { smart_quick, collaborative }

enum ScheduleStatus { collecting, locked, generating, completed, published }

enum WaitingCoverageMode { balanced, strict, tiers }

class ScheduleRun {
  final String id;
  final String schoolId;
  final ScheduleMode mode;
  final ScheduleStatus status;
  final DateTime? collectUntil;
  final WaitingCoverageMode waitingCoverageMode;
  final int waitingSlotsPerPeriod; // 2, 3, 4
  final String waitingPolicy; // 'standard', 'tiers', or Custom Rules ID
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? fairnessReport;
  final String? timetableId;
  final int? generationDurationMs;

  // Collaborative Stats
  final int? teacherCountExpected;
  final int? submittedCount;
  final List<String>? missingTeacherIds;

  ScheduleRun({
    required this.id,
    required this.schoolId,
    required this.mode,
    required this.status,
    this.collectUntil,
    this.waitingCoverageMode = WaitingCoverageMode.balanced,
    this.waitingSlotsPerPeriod = 2,
    this.waitingPolicy = 'standard',
    required this.createdBy,
    required this.createdAt,
    this.fairnessReport,
    this.timetableId,
    this.generationDurationMs,
    this.teacherCountExpected,
    this.submittedCount,
    this.missingTeacherIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'mode': mode.name,
      'status': status.name,
      'collectUntil': collectUntil != null
          ? Timestamp.fromDate(collectUntil!)
          : null,
      'waitingCoverageMode': waitingCoverageMode.name,
      'waitingSlotsPerPeriod': waitingSlotsPerPeriod,
      'waitingPolicy': waitingPolicy,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'fairnessReport': fairnessReport,
      'timetableId': timetableId,
      'generationDurationMs': generationDurationMs,
      'teacherCountExpected': teacherCountExpected,
      'submittedCount': submittedCount,
      'missingTeacherIds': missingTeacherIds,
    };
  }

  factory ScheduleRun.fromMap(Map<String, dynamic> map) {
    return ScheduleRun(
      id: map['id'] ?? '',
      schoolId: map['schoolId'] ?? '',
      mode: ScheduleMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => ScheduleMode.smart_quick,
      ),
      status: ScheduleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ScheduleStatus.collecting,
      ),
      collectUntil: map['collectUntil'] != null
          ? (map['collectUntil'] as Timestamp).toDate()
          : null,
      waitingCoverageMode: WaitingCoverageMode.values.firstWhere(
        (e) => e.name == map['waitingCoverageMode'],
        orElse: () => WaitingCoverageMode.balanced,
      ),
      waitingSlotsPerPeriod: map['waitingSlotsPerPeriod'] ?? 2,
      waitingPolicy: map['waitingPolicy'] ?? 'standard',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      fairnessReport: map['fairnessReport'],
      timetableId: map['timetableId'],
      generationDurationMs: map['generationDurationMs'],
      teacherCountExpected: map['teacherCountExpected'],
      submittedCount: map['submittedCount'],
      missingTeacherIds: (map['missingTeacherIds'] as List<dynamic>?)
          ?.cast<String>(),
    );
  }

  ScheduleRun copyWith({
    String? id,
    String? schoolId,
    ScheduleMode? mode,
    ScheduleStatus? status,
    DateTime? collectUntil,
    WaitingCoverageMode? waitingCoverageMode,
    int? waitingSlotsPerPeriod,
    String? waitingPolicy,
    String? createdBy,
    DateTime? createdAt,
    Map<String, dynamic>? fairnessReport,
    String? timetableId,
    int? generationDurationMs,
    int? teacherCountExpected,
    int? submittedCount,
    List<String>? missingTeacherIds,
  }) {
    return ScheduleRun(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      collectUntil: collectUntil ?? this.collectUntil,
      waitingCoverageMode: waitingCoverageMode ?? this.waitingCoverageMode,
      waitingSlotsPerPeriod:
          waitingSlotsPerPeriod ?? this.waitingSlotsPerPeriod,
      waitingPolicy: waitingPolicy ?? this.waitingPolicy,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      fairnessReport: fairnessReport ?? this.fairnessReport,
      timetableId: timetableId ?? this.timetableId,
      generationDurationMs:
          generationDurationMs ?? this.generationDurationMs,
      teacherCountExpected: teacherCountExpected ?? this.teacherCountExpected,
      submittedCount: submittedCount ?? this.submittedCount,
      missingTeacherIds: missingTeacherIds ?? this.missingTeacherIds,
    );
  }
}
