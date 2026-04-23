enum SpecialEducationRole {
  none,
  braille,
  hearing,
  visual,
  learningDisabilities,
}

enum SchedulingPriorityLevel { normal, high, critical }

class TeacherConstraintsProfile {
  final String teacherId;
  final int weeklyQuota;
  final int currentLoad;
  final bool eligibilityForWaiting;
  final int maxWaitingPerWeek;
  final bool medicalExemption;
  final bool mobilityConstraint;
  final SpecialEducationRole specialEducationRole;
  final SchedulingPriorityLevel schedulingPriorityLevel;
  final List<String> preferredTimeSlots; // e.g., "Monday:1", "Tuesday:2"
  final List<String> blockedTimeSlots; // Hard Constraints: Slots the teacher CANNOT teach
  final List<String> softConstraintSlots; // Soft Constraints: Unwanted slots (Elite Preference)
  final int floorMobilityLimit; // 0 = ground floor only
  final double overrideHistoryScore; // Learned from overrides
  final bool hasAdministrativeDuties; // New: Assigned administrative work

  TeacherConstraintsProfile({
    required this.teacherId,
    this.weeklyQuota = 24,
    this.currentLoad = 0,
    this.eligibilityForWaiting = true,
    this.maxWaitingPerWeek = 2,
    this.medicalExemption = false,
    this.mobilityConstraint = false,
    this.specialEducationRole = SpecialEducationRole.none,
    this.schedulingPriorityLevel = SchedulingPriorityLevel.normal,
    this.preferredTimeSlots = const [],
    this.blockedTimeSlots = const [],
    this.softConstraintSlots = const [],
    this.floorMobilityLimit = 3,
    this.overrideHistoryScore = 1.0,
    this.hasAdministrativeDuties = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'weeklyQuota': weeklyQuota,
      'currentLoad': currentLoad,
      'eligibilityForWaiting': eligibilityForWaiting,
      'maxWaitingPerWeek': maxWaitingPerWeek,
      'medicalExemption': medicalExemption,
      'mobilityConstraint': mobilityConstraint,
      'specialEducationRole': specialEducationRole.name,
      'schedulingPriorityLevel': schedulingPriorityLevel.name,
      'preferredTimeSlots': preferredTimeSlots,
      'blockedTimeSlots': blockedTimeSlots,
      'softConstraintSlots': softConstraintSlots,
      'floorMobilityLimit': floorMobilityLimit,
      'overrideHistoryScore': overrideHistoryScore,
      'hasAdministrativeDuties': hasAdministrativeDuties,
    };
  }

  factory TeacherConstraintsProfile.fromMap(Map<String, dynamic> map) {
    return TeacherConstraintsProfile(
      teacherId: map['teacherId'] ?? '',
      weeklyQuota: map['weeklyQuota'] ?? 24,
      currentLoad: map['currentLoad'] ?? 0,
      eligibilityForWaiting: map['eligibilityForWaiting'] ?? true,
      maxWaitingPerWeek: map['maxWaitingPerWeek'] ?? 2,
      medicalExemption: map['medicalExemption'] ?? false,
      mobilityConstraint: map['mobilityConstraint'] ?? false,
      specialEducationRole: SpecialEducationRole.values.firstWhere(
        (e) => e.name == map['specialEducationRole'],
        orElse: () => SpecialEducationRole.none,
      ),
      schedulingPriorityLevel: SchedulingPriorityLevel.values.firstWhere(
        (e) => e.name == map['schedulingPriorityLevel'],
        orElse: () => SchedulingPriorityLevel.normal,
      ),
      preferredTimeSlots: List<String>.from(map['preferredTimeSlots'] ?? []),
      blockedTimeSlots: List<String>.from(map['blockedTimeSlots'] ?? []),
      softConstraintSlots: List<String>.from(map['softConstraintSlots'] ?? []),
      floorMobilityLimit: map['floorMobilityLimit'] ?? 3,
      overrideHistoryScore: (map['overrideHistoryScore'] ?? 1.0).toDouble(),
      hasAdministrativeDuties: map['hasAdministrativeDuties'] ?? false,
    );
  }

  TeacherConstraintsProfile copyWith({
    String? teacherId,
    int? weeklyQuota,
    int? currentLoad,
    bool? eligibilityForWaiting,
    int? maxWaitingPerWeek,
    bool? medicalExemption,
    bool? mobilityConstraint,
    SpecialEducationRole? specialEducationRole,
    SchedulingPriorityLevel? schedulingPriorityLevel,
    List<String>? preferredTimeSlots,
    List<String>? blockedTimeSlots,
    List<String>? softConstraintSlots,
    int? floorMobilityLimit,
    double? overrideHistoryScore,
    bool? hasAdministrativeDuties,
  }) {
    return TeacherConstraintsProfile(
      teacherId: teacherId ?? this.teacherId,
      weeklyQuota: weeklyQuota ?? this.weeklyQuota,
      currentLoad: currentLoad ?? this.currentLoad,
      eligibilityForWaiting:
          eligibilityForWaiting ?? this.eligibilityForWaiting,
      maxWaitingPerWeek: maxWaitingPerWeek ?? this.maxWaitingPerWeek,
      medicalExemption: medicalExemption ?? this.medicalExemption,
      mobilityConstraint: mobilityConstraint ?? this.mobilityConstraint,
      specialEducationRole: specialEducationRole ?? this.specialEducationRole,
      schedulingPriorityLevel:
          schedulingPriorityLevel ?? this.schedulingPriorityLevel,
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      blockedTimeSlots: blockedTimeSlots ?? this.blockedTimeSlots,
      softConstraintSlots: softConstraintSlots ?? this.softConstraintSlots,
      floorMobilityLimit: floorMobilityLimit ?? this.floorMobilityLimit,
      overrideHistoryScore: overrideHistoryScore ?? this.overrideHistoryScore,
      hasAdministrativeDuties:
          hasAdministrativeDuties ?? this.hasAdministrativeDuties,
    );
  }
}
