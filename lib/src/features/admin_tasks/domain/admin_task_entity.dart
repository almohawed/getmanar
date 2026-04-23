import 'package:equatable/equatable.dart';

enum AdminTaskStatus { open, in_progress, done, overdue }

enum AdminTaskPriority { low, medium, high, urgent }

enum AdminTaskType {
  healthGuide,
  safetyOfficer,
  activityLeader,
  classLeader,
  deputy,
  stageDeputy,
  floorSupervisor,
  committee,
  general,
}

class AdminTaskEntity extends Equatable {
  final String id;
  final String schoolId;
  final String title;
  final String? description;
  final String? assignedToId;
  final String? assignedToName;
  final String? assignedToRole; // e.g., 'teacher', 'admin', 'deputy'
  final AdminTaskStatus status;
  final AdminTaskPriority priority;
  final AdminTaskType type;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final int evidenceCount; // Optimization for querying tasks without evidence
  final String? createdByUserId; // New: Owner UID
  final String? createdByRole; // New: Owner Role
  final int escalationLevel; // New: 0, 1, 2, 3
  final String? relatedStudentId; // Link to student profile when relevant
  final String? relatedCaseId; // Link to counselor student case when relevant

  const AdminTaskEntity({
    required this.id,
    required this.schoolId,
    required this.title,
    this.description,
    this.assignedToId,
    this.assignedToName,
    this.assignedToRole,
    this.status = AdminTaskStatus.open,
    this.priority = AdminTaskPriority.medium,
    this.type = AdminTaskType.general,
    required this.dueDate,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.evidenceCount = 0,
    this.createdByUserId,
    this.createdByRole,
    this.escalationLevel = 0,
    this.relatedStudentId,
    this.relatedCaseId,
  });

  bool get isOverdue =>
      status != AdminTaskStatus.done && DateTime.now().isAfter(dueDate);

  bool get isCritical =>
      (priority == AdminTaskPriority.high ||
          priority == AdminTaskPriority.urgent) &&
      (isOverdue || isDueToday);

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  AdminTaskEntity copyWith({
    String? id,
    String? schoolId,
    String? title,
    String? description,
    String? assignedToId,
    String? assignedToName,
    String? assignedToRole,
    AdminTaskStatus? status,
    AdminTaskPriority? priority,
    AdminTaskType? type,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    int? evidenceCount,
    String? createdByUserId,
    String? createdByRole,
    int? escalationLevel,
    String? relatedStudentId,
    String? relatedCaseId,
  }) {
    return AdminTaskEntity(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedToRole: assignedToRole ?? this.assignedToRole,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByRole: createdByRole ?? this.createdByRole,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      relatedStudentId: relatedStudentId ?? this.relatedStudentId,
      relatedCaseId: relatedCaseId ?? this.relatedCaseId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    schoolId,
    title,
    description,
    assignedToId,
    assignedToName,
    assignedToRole,
    status,
    priority,
    type,
    dueDate,
    createdAt,
    updatedAt,
    notes,
    evidenceCount,
    createdByUserId,
    createdByRole,
    escalationLevel,
    relatedStudentId,
    relatedCaseId,
  ];
}
