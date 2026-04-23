enum UserRole {
  superAdmin, // The App Owner
  admin,
  teacher,
  student,
  parent,
  counselor,
  administrative,
  deputy,
  technicalSupport,
  supportAdmin,
}

enum SubjectAssignmentType { primary, additional, emergency }

enum TeacherRank { practitioner, advanced, expert }

class SubjectAssignment {
  final String subjectId;
  final SubjectAssignmentType type;

  const SubjectAssignment({required this.subjectId, required this.type});

  Map<String, dynamic> toMap() {
    return {'subjectId': subjectId, 'type': type.name};
  }

  factory SubjectAssignment.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] ?? 'additional').toString();
    final type = SubjectAssignmentType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SubjectAssignmentType.additional,
    );
    return SubjectAssignment(
      subjectId: (map['subjectId'] ?? '').toString(),
      type: type,
    );
  }
}

bool isStaffRole(UserRole role) {
  return role == UserRole.admin ||
      role == UserRole.teacher ||
      role == UserRole.counselor ||
      role == UserRole.administrative ||
      role == UserRole.deputy ||
      role == UserRole.superAdmin ||
      role == UserRole.technicalSupport ||
      role == UserRole.supportAdmin;
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? profileImageUrl;
  final String? stage; // e.g., Primary, Middle
  final List<String>? assignedClassIds;
  final String? scheduleNotes;
  final String? identityNumber; // System Username/Employee ID (Used for login)
  final String? mnCode; // New field for short entry code
  final bool isActive;
  final String?
  nationalId; // Actual National ID/Iqama (Internal only, optional)
  final String? studentCode; // Unique secure login code (STU-XXXXXX)
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? specialization;
  final List<String>? additionalSubjects;
  final String? primarySubjectId;
  final List<SubjectAssignment>? subjectAssignments;
  final int? maxWeeklyClasses;
  final String? teacherRank; // practitioner, advanced, expert
  final bool sharedBetweenSchools;
  final String? masaratAssignmentType; // all | shared | specialized
  final List<String>? masaratTracks;
  final int? masaratGradeLevel;
  final String? schoolId;
  final String? deputyType; // 'academic', 'school', 'student'
  final bool isPasswordChangeRequired; // Forces password change on first login
  final bool isTwoFactorEnabled; // For Admin/Staff security
  final String?
  healthStatus; // 'care' (needs care), 'bathroom' (needs bathroom)
  final String? healthNeeds; // 'frequent_restroom', 'chronic_condition'
  final String? parentId;
  final String? parentIdentityNumber; // Added for strict parent linking
  final int excellenceScore; // Student Excellence Index (Starts at 100)
  final DateTime? lastViolationDate; // For SEI Auto-Recovery logic
  final Map<String, dynamic>?
  delegatedPermissions; // For Academic Deputy Delegation
  final DateTime? lastLoginAt;
  final DateTime? previousLoginAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImageUrl,
    this.stage,
    this.assignedClassIds,
    this.scheduleNotes,
    this.identityNumber,
    this.mnCode,
    this.isActive = true,
    this.nationalId,
    this.studentCode,
    this.phoneNumber,
    this.dateOfBirth,
    this.specialization,
    this.additionalSubjects,
    this.primarySubjectId,
    this.subjectAssignments,
    this.maxWeeklyClasses,
    this.teacherRank,
    this.sharedBetweenSchools = false,
    this.masaratAssignmentType,
    this.masaratTracks,
    this.masaratGradeLevel,
    this.schoolId,
    this.deputyType,
    this.isPasswordChangeRequired = false,
    this.isTwoFactorEnabled = false,
    this.healthStatus,
    this.healthNeeds,
    this.parentId,
    this.parentIdentityNumber,
    this.excellenceScore = 100,
    this.lastViolationDate,
    this.delegatedPermissions,
    this.lastLoginAt,
    this.previousLoginAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? profileImageUrl,
    String? stage,
    List<String>? assignedClassIds,
    String? scheduleNotes,
    String? identityNumber,
    String? mnCode,
    bool? isActive,
    String? nationalId,
    String? studentCode,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? specialization,
    List<String>? additionalSubjects,
    String? primarySubjectId,
    List<SubjectAssignment>? subjectAssignments,
    int? maxWeeklyClasses,
    String? teacherRank,
    bool? sharedBetweenSchools,
    String? masaratAssignmentType,
    List<String>? masaratTracks,
    int? masaratGradeLevel,
    String? schoolId,
    String? deputyType,
    bool? isPasswordChangeRequired,
    bool? isTwoFactorEnabled,
    String? healthStatus,
    String? parentId,
    String? parentIdentityNumber,
    int? excellenceScore,
    DateTime? lastViolationDate,
    Map<String, dynamic>? delegatedPermissions,
    DateTime? lastLoginAt,
    DateTime? previousLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      stage: stage ?? this.stage,
      assignedClassIds: assignedClassIds ?? this.assignedClassIds,
      scheduleNotes: scheduleNotes ?? this.scheduleNotes,
      identityNumber: identityNumber ?? this.identityNumber,
      mnCode: mnCode ?? this.mnCode,
      isActive: isActive ?? this.isActive,
      nationalId: nationalId ?? this.nationalId,
      studentCode: studentCode ?? this.studentCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      specialization: specialization ?? this.specialization,
      additionalSubjects: additionalSubjects ?? this.additionalSubjects,
      primarySubjectId: primarySubjectId ?? this.primarySubjectId,
      subjectAssignments: subjectAssignments ?? this.subjectAssignments,
      maxWeeklyClasses: maxWeeklyClasses ?? this.maxWeeklyClasses,
      teacherRank: teacherRank ?? this.teacherRank,
      sharedBetweenSchools: sharedBetweenSchools ?? this.sharedBetweenSchools,
      masaratAssignmentType: masaratAssignmentType ?? this.masaratAssignmentType,
      masaratTracks: masaratTracks ?? this.masaratTracks,
      masaratGradeLevel: masaratGradeLevel ?? this.masaratGradeLevel,
      schoolId: schoolId ?? this.schoolId,
      deputyType: deputyType ?? this.deputyType,
      isPasswordChangeRequired:
          isPasswordChangeRequired ?? this.isPasswordChangeRequired,
      isTwoFactorEnabled: isTwoFactorEnabled ?? this.isTwoFactorEnabled,
      healthStatus: healthStatus ?? this.healthStatus,
      healthNeeds: healthNeeds ?? this.healthNeeds,
      parentId: parentId ?? this.parentId,
      parentIdentityNumber: parentIdentityNumber ?? this.parentIdentityNumber,
      excellenceScore: excellenceScore ?? this.excellenceScore,
      lastViolationDate: lastViolationDate ?? this.lastViolationDate,
      delegatedPermissions: delegatedPermissions ?? this.delegatedPermissions,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      previousLoginAt: previousLoginAt ?? this.previousLoginAt,
    );
  }

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'profileImageUrl': profileImageUrl,
      'stage': stage,
      'assignedClassIds': assignedClassIds,
      'scheduleNotes': scheduleNotes,
      'identityNumber': identityNumber,
      'mnCode': mnCode,
      'isActive': isActive,
      'nationalId': nationalId,
      'studentCode': studentCode,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'specialization': specialization,
      'additionalSubjects': additionalSubjects,
      'primarySubjectId': primarySubjectId,
      'subjectAssignments': subjectAssignments?.map((e) => e.toMap()).toList(),
      'maxWeeklyClasses': maxWeeklyClasses,
      'teacherRank': teacherRank,
      'sharedBetweenSchools': sharedBetweenSchools,
      'masaratAssignmentType': masaratAssignmentType,
      'masaratTracks': masaratTracks,
      'masaratGradeLevel': masaratGradeLevel,
      'schoolId': schoolId,
      'deputyType': deputyType,
      'isPasswordChangeRequired': isPasswordChangeRequired,
      'isTwoFactorEnabled': isTwoFactorEnabled,
      'healthStatus': healthStatus,
      'healthNeeds': healthNeeds,
      'parentId': parentId,
      'parentIdentityNumber': parentIdentityNumber,
      'excellenceScore': excellenceScore,
      'lastViolationDate': lastViolationDate?.toIso8601String(),
      'delegatedPermissions': delegatedPermissions,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'previousLoginAt': previousLoginAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final legacyAdditional =
        (map['additionalSubjects'] as List<dynamic>?)?.cast<String>() ??
        const [];
    final primarySubjectId = map['primarySubjectId']?.toString();
    final rawAssignments = map['subjectAssignments'];
    List<SubjectAssignment>? assignments;
    if (rawAssignments is List) {
      assignments = rawAssignments
          .whereType<Map>()
          .map((e) => SubjectAssignment.fromMap(Map<String, dynamic>.from(e)))
          .where((a) => a.subjectId.trim().isNotEmpty)
          .toList();
    } else if (legacyAdditional.isNotEmpty) {
      assignments = legacyAdditional
          .map(
            (s) => SubjectAssignment(
              subjectId: s,
              type: SubjectAssignmentType.additional,
            ),
          )
          .toList();
    }

    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? 'مستخدم',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () {
          final roleStr = map['role'];
          // Handle legacy or mapped roles
          if (roleStr == 'Owner' || roleStr == 'owner') {
            return UserRole.superAdmin;
          }
          if (roleStr == 'manager' || roleStr == 'principal') {
            return UserRole.admin;
          }
          if (roleStr == 'support_admin') {
            return UserRole.supportAdmin;
          }
          if (roleStr == 'tech_support') {
            return UserRole.technicalSupport;
          }
          // STRICT MODE: No default to student. Throw if role is invalid.
          throw Exception('Unknown or invalid role: $roleStr');
        },
      ),
      profileImageUrl: map['profileImageUrl'],
      stage: map['stage'],
      assignedClassIds: (map['assignedClassIds'] as List<dynamic>?)
          ?.cast<String>(),
      scheduleNotes: map['scheduleNotes'],
      identityNumber: map['identityNumber'],
      mnCode: map['mnCode'],
      isActive: map['isActive'] ?? true,
      nationalId: map['nationalId'],
      studentCode: map['studentCode'],
      phoneNumber: map['phoneNumber'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'])
          : null,
      specialization: map['specialization'],
      additionalSubjects: legacyAdditional,
      primarySubjectId: primarySubjectId,
      subjectAssignments: assignments,
      maxWeeklyClasses: map['maxWeeklyClasses'],
      teacherRank: map['teacherRank'],
      sharedBetweenSchools: map['sharedBetweenSchools'] == true ||
          map['isSharedBetweenSchools'] == true ||
          map['multiSchool'] == true ||
          map['isMultiSchool'] == true,
      masaratAssignmentType:
          (map['masaratAssignmentType'] ?? '').toString().trim().isEmpty
              ? null
              : (map['masaratAssignmentType'] ?? '').toString().trim(),
      masaratTracks: (map['masaratTracks'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      masaratGradeLevel: map['masaratGradeLevel'] is int
          ? map['masaratGradeLevel']
          : int.tryParse('${map['masaratGradeLevel']}'),
      schoolId: map['schoolId'],
      deputyType: map['deputyType'],
      isPasswordChangeRequired: map['isPasswordChangeRequired'] ?? false,
      isTwoFactorEnabled: map['isTwoFactorEnabled'] ?? false,
      healthStatus: map['healthStatus'],
      parentId: map['parentId'],
      parentIdentityNumber: map['parentIdentityNumber'],
      excellenceScore: map['excellenceScore'] ?? 100,
      lastViolationDate: map['lastViolationDate'] != null
          ? DateTime.parse(map['lastViolationDate'])
          : null,
      delegatedPermissions: map['delegatedPermissions'] != null
          ? Map<String, dynamic>.from(map['delegatedPermissions'])
          : null,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.tryParse(map['lastLoginAt'])
          : null,
      previousLoginAt: map['previousLoginAt'] != null
          ? DateTime.tryParse(map['previousLoginAt'])
          : null,
    );
  }
}
