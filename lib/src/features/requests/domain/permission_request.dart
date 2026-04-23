
enum PermissionRequestStatus {
  pending,
  approved,
  rejected,
}

class PermissionRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String parentId;
  final String reason;
  final DateTime createdAt;
  final PermissionRequestStatus status;
  final String? rejectionReason;
  final DateTime? decidedAt;
  final bool isParentNear; // New field
  final DateTime? parentArrivedAt; // New field

  PermissionRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.parentId,
    required this.reason,
    required this.createdAt,
    this.status = PermissionRequestStatus.pending,
    this.rejectionReason,
    this.decidedAt,
    this.isParentNear = false,
    this.parentArrivedAt,
  });

  PermissionRequest copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? parentId,
    String? reason,
    DateTime? createdAt,
    PermissionRequestStatus? status,
    String? rejectionReason,
    DateTime? decidedAt,
    bool? isParentNear,
    DateTime? parentArrivedAt,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      parentId: parentId ?? this.parentId,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      decidedAt: decidedAt ?? this.decidedAt,
      isParentNear: isParentNear ?? this.isParentNear,
      parentArrivedAt: parentArrivedAt ?? this.parentArrivedAt,
    );
  }
}
