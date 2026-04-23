class DistinguishedNomination {
  final String id;
  final String cycleId;
  final String studentId;
  final String studentName;
  final String gradeLevel; // e.g. "Primary 1" or just "1" if context is clear
  final String stage; // e.g. "Primary", "Middle", "High"
  final double score; // Calculated score
  final bool isApprovedByDeputy;
  final List<String> rejectedByTeacherIds; // List of teachers who voted 'No'
  final List<String> approvedByTeacherIds; // List of teachers who voted 'Yes'
  final bool isFinal; // If true, this student is in the final list

  // Breakdown of score for transparency
  final double behaviorScore;
  final double attendanceScore;
  final double academicScore;

  DistinguishedNomination({
    required this.id,
    required this.cycleId,
    required this.studentId,
    required this.studentName,
    required this.gradeLevel,
    required this.stage,
    required this.score,
    this.isApprovedByDeputy = false,
    this.rejectedByTeacherIds = const [],
    this.approvedByTeacherIds = const [],
    this.isFinal = false,
    this.behaviorScore = 0,
    this.attendanceScore = 0,
    this.academicScore = 0,
  });

  DistinguishedNomination copyWith({
    String? id,
    String? cycleId,
    String? studentId,
    String? studentName,
    String? gradeLevel,
    String? stage,
    double? score,
    bool? isApprovedByDeputy,
    List<String>? rejectedByTeacherIds,
    List<String>? approvedByTeacherIds,
    bool? isFinal,
    double? behaviorScore,
    double? attendanceScore,
    double? academicScore,
  }) {
    return DistinguishedNomination(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      stage: stage ?? this.stage,
      score: score ?? this.score,
      isApprovedByDeputy: isApprovedByDeputy ?? this.isApprovedByDeputy,
      rejectedByTeacherIds: rejectedByTeacherIds ?? this.rejectedByTeacherIds,
      approvedByTeacherIds: approvedByTeacherIds ?? this.approvedByTeacherIds,
      isFinal: isFinal ?? this.isFinal,
      behaviorScore: behaviorScore ?? this.behaviorScore,
      attendanceScore: attendanceScore ?? this.attendanceScore,
      academicScore: academicScore ?? this.academicScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'studentId': studentId,
      'studentName': studentName,
      'gradeLevel': gradeLevel,
      'stage': stage,
      'score': score,
      'isApprovedByDeputy': isApprovedByDeputy,
      'rejectedByTeacherIds': rejectedByTeacherIds,
      'approvedByTeacherIds': approvedByTeacherIds,
      'isFinal': isFinal,
      'behaviorScore': behaviorScore,
      'attendanceScore': attendanceScore,
      'academicScore': academicScore,
    };
  }

  factory DistinguishedNomination.fromMap(Map<String, dynamic> map) {
    return DistinguishedNomination(
      id: map['id'] ?? '',
      cycleId: map['cycleId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      gradeLevel: map['gradeLevel'] ?? '',
      stage: map['stage'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      isApprovedByDeputy: map['isApprovedByDeputy'] ?? false,
      rejectedByTeacherIds: List<String>.from(
        map['rejectedByTeacherIds'] ?? [],
      ),
      approvedByTeacherIds: List<String>.from(
        map['approvedByTeacherIds'] ?? [],
      ),
      isFinal: map['isFinal'] ?? false,
      behaviorScore: (map['behaviorScore'] ?? 0).toDouble(),
      attendanceScore: (map['attendanceScore'] ?? 0).toDouble(),
      academicScore: (map['academicScore'] ?? 0).toDouble(),
    );
  }
}
