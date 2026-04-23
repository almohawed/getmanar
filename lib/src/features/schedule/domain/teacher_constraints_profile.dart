class TeacherConstraintsProfile {
  final String id;
  final String teacherId;
  final String schoolId;
  final int weeklyQuota;
  final Set<String> unavailableSlots; // Format: "Day_Period" e.g. "Monday_1"
  final Set<String> preferredSlots;   // Format: "Day_Period"
  final int maxPerDay;

  const TeacherConstraintsProfile({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    this.weeklyQuota = 24,
    this.unavailableSlots = const {},
    this.preferredSlots = const {},
    this.maxPerDay = 7,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'schoolId': schoolId,
      'weeklyQuota': weeklyQuota,
      'unavailableSlots': unavailableSlots.toList(),
      'preferredSlots': preferredSlots.toList(),
      'maxPerDay': maxPerDay,
    };
  }

  factory TeacherConstraintsProfile.fromMap(Map<String, dynamic> map, String id) {
    return TeacherConstraintsProfile(
      id: id,
      teacherId: map['teacherId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      weeklyQuota: map['weeklyQuota']?.toInt() ?? 24,
      unavailableSlots: (map['unavailableSlots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {},
      preferredSlots: (map['preferredSlots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {},
      maxPerDay: map['maxPerDay']?.toInt() ?? 7,
    );
  }

  TeacherConstraintsProfile copyWith({
    String? id,
    String? teacherId,
    String? schoolId,
    int? weeklyQuota,
    Set<String>? unavailableSlots,
    Set<String>? preferredSlots,
    int? maxPerDay,
  }) {
    return TeacherConstraintsProfile(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      schoolId: schoolId ?? this.schoolId,
      weeklyQuota: weeklyQuota ?? this.weeklyQuota,
      unavailableSlots: unavailableSlots ?? this.unavailableSlots,
      preferredSlots: preferredSlots ?? this.preferredSlots,
      maxPerDay: maxPerDay ?? this.maxPerDay,
    );
  }
}
