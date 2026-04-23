enum ViolationType { minor, moderate, major }
enum ViolationStatus { active, closed, archived }

class Violation {
  final String id;
  final String studentId;
  final String teacherId;
  final ViolationType type;
  final String description;
  final DateTime timestamp;
  final ViolationStatus status;
  final int pointsDeducted;

  Violation({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.type,
    required this.description,
    required this.timestamp,
    this.status = ViolationStatus.active,
    required this.pointsDeducted,
  });
}
