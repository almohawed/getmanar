class CounselingSession {
  final String id;
  final String studentId;
  final String counselorId;
  final DateTime date;
  final String notes; // Should be encrypted in real implementation
  final String recommendations;
  final bool isConfidential;

  CounselingSession({
    required this.id,
    required this.studentId,
    required this.counselorId,
    required this.date,
    required this.notes,
    required this.recommendations,
    this.isConfidential = true,
  });
}
