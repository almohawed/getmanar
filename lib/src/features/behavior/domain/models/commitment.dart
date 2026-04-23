enum CommitmentType { behavioral, disciplinary, academic }
enum CommitmentStatus { active, expired, violated, completed }

class Commitment {
  final String id;
  final String studentId;
  final CommitmentType type;
  final String description;
  final DateTime createdDate;
  final DateTime expiryDate;
  final CommitmentStatus status;
  final bool isStudentSigned;
  final DateTime? studentSignedAt;
  final bool isParentApproved;
  final DateTime? parentApprovedAt;

  Commitment({
    required this.id,
    required this.studentId,
    required this.type,
    required this.description,
    required this.createdDate,
    required this.expiryDate,
    this.status = CommitmentStatus.active,
    this.isStudentSigned = false,
    this.studentSignedAt,
    this.isParentApproved = false,
    this.parentApprovedAt,
  });
}
