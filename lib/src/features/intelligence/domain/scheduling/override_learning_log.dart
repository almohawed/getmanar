class OverrideLearningLog {
  final String id;
  final String teacherId;
  final String overriddenBy; // User ID of Admin/Deputy
  final String originalSlot; // e.g., "Monday:1"
  final String newSlot;
  final String reason;
  final DateTime timestamp;

  OverrideLearningLog({
    required this.id,
    required this.teacherId,
    required this.overriddenBy,
    required this.originalSlot,
    required this.newSlot,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'overriddenBy': overriddenBy,
      'originalSlot': originalSlot,
      'newSlot': newSlot,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OverrideLearningLog.fromMap(Map<String, dynamic> map) {
    return OverrideLearningLog(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      overriddenBy: map['overriddenBy'] ?? '',
      originalSlot: map['originalSlot'] ?? '',
      newSlot: map['newSlot'] ?? '',
      reason: map['reason'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
