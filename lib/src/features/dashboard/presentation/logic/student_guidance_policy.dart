import 'silent_guidance_constants.dart';

enum ToneProfile {
  governmentBalanced,
  privateMotivational,
  internationalNeutral,
}

enum StrictnessLevel { relaxed, standard, strict }

class GuidanceCategoryRule {
  final bool enabled;
  final int maxPer7Days;
  final GuidanceSeverity maxSeverity;

  const GuidanceCategoryRule({
    this.enabled = true,
    this.maxPer7Days = 2,
    this.maxSeverity = GuidanceSeverity.strong,
  });
}

class StudentGuidancePolicy {
  final bool enabled;
  final ToneProfile toneProfile;
  final StrictnessLevel strictness;
  final int maxStrongPer7Days;
  final int minDaysBetweenMessages;
  final bool allowMergedMessages;

  // Wording Permissions
  final bool allowHomeworkWording;
  final bool allowAttendanceWording;
  final bool allowDisciplineWording;

  // Content Safety
  final List<String> bannedWords;
  final Map<String, String> replacements;

  // Per-Category Rules
  final Map<GuidanceCategory, GuidanceCategoryRule> categoryRules;

  const StudentGuidancePolicy({
    this.enabled = true,
    this.toneProfile = ToneProfile.governmentBalanced,
    this.strictness = StrictnessLevel.standard,
    this.maxStrongPer7Days = 1,
    this.minDaysBetweenMessages = 2,
    this.allowMergedMessages = true,
    this.allowHomeworkWording = true,
    this.allowAttendanceWording = true,
    this.allowDisciplineWording = true,
    this.bannedWords = const [],
    this.replacements = const {},
    this.categoryRules = const {},
  });

  /// --------------------------------------------------------------------------
  /// Factory: Default Policy (Safe Defaults)
  /// --------------------------------------------------------------------------
  factory StudentGuidancePolicy.createDefault() {
    return const StudentGuidancePolicy(
      enabled: true,
      toneProfile: ToneProfile.governmentBalanced,
      strictness: StrictnessLevel.standard,
      maxStrongPer7Days: 1,
      minDaysBetweenMessages: 2,
      allowMergedMessages: true,
      allowHomeworkWording: true,
      allowAttendanceWording: true,
      allowDisciplineWording: true,
      bannedWords: ["عقوبة", "تعهد", "مخالفة", "تهديد", "هروب", "خصم"],
      replacements: {
        "عقوبة": "إجراء تربوي",
        "مخالفة": "ملاحظة تربوية",
        "تهديد": "تنبيه",
        "هروب": "خروج دون إذن",
        "خصم": "تعديل",
      },
      categoryRules: {
        GuidanceCategory.lateness: GuidanceCategoryRule(
          maxPer7Days: 2,
          maxSeverity: GuidanceSeverity.medium,
        ),
        GuidanceCategory.homework: GuidanceCategoryRule(
          maxPer7Days: 2,
          maxSeverity: GuidanceSeverity.strong,
        ),
        GuidanceCategory.discipline: GuidanceCategoryRule(
          maxPer7Days: 2,
          maxSeverity: GuidanceSeverity.medium,
        ),
        GuidanceCategory.positive: GuidanceCategoryRule(
          maxPer7Days: 3,
          maxSeverity: GuidanceSeverity.soft,
        ),
      },
    );
  }

  /// --------------------------------------------------------------------------
  /// Factory: From Tone Profile (Predefined Templates)
  /// --------------------------------------------------------------------------
  factory StudentGuidancePolicy.fromProfile(ToneProfile profile) {
    switch (profile) {
      case ToneProfile.governmentBalanced:
        // A) Government Balanced (Official, Educational, Minimal Strong)
        return StudentGuidancePolicy.createDefault().copyWith(
          toneProfile: ToneProfile.governmentBalanced,
          maxStrongPer7Days: 1, // Minimal Strong
          replacements: {
            "عقوبة": "إجراء تربوي",
            "مخالفة": "ملاحظة تربوية",
            "تهديد": "تنبيه",
            "هروب": "خروج دون إذن",
            "خصم": "تعديل",
            "مسؤولية": "واجب مدرسي",
          },
        );

      case ToneProfile.privateMotivational:
        // B) Private Motivational (Motivational, allows more praise)
        return StudentGuidancePolicy.createDefault().copyWith(
          toneProfile: ToneProfile.privateMotivational,
          maxStrongPer7Days: 2, // Allow a bit more strong messages if needed
          replacements: {
            "عقوبة": "إجراء إداري",
            "مخالفة": "سلوك يحتاج تحسين",
            "تهديد": "تذكير هام",
            "هروب": "غياب جزئي",
            "خصم": "مراجعة",
          },
        );

      case ToneProfile.internationalNeutral:
        // C) International Neutral (Neutral, no moral judgment)
        return StudentGuidancePolicy.createDefault().copyWith(
          toneProfile: ToneProfile.internationalNeutral,
          maxStrongPer7Days: 0, // Avoid strong messages entirely, prefer medium
          allowDisciplineWording:
              false, // Often sensitive in international schools
          replacements: {
            "عقوبة": "Action",
            "مخالفة": "Note",
            "تهديد": "Reminder",
            "هروب": "Absence",
            "خصم": "Review",
            "التزام": "Focus", // Neutral term
            "انضباط": "Self-Regulation",
          },
        );
    }
  }

  /// Helper to merge with manual overrides
  StudentGuidancePolicy copyWith({
    bool? enabled,
    ToneProfile? toneProfile,
    StrictnessLevel? strictness,
    int? maxStrongPer7Days,
    int? minDaysBetweenMessages,
    bool? allowMergedMessages,
    bool? allowHomeworkWording,
    bool? allowAttendanceWording,
    bool? allowDisciplineWording,
    List<String>? bannedWords,
    Map<String, String>? replacements,
    Map<GuidanceCategory, GuidanceCategoryRule>? categoryRules,
  }) {
    return StudentGuidancePolicy(
      enabled: enabled ?? this.enabled,
      toneProfile: toneProfile ?? this.toneProfile,
      strictness: strictness ?? this.strictness,
      maxStrongPer7Days: maxStrongPer7Days ?? this.maxStrongPer7Days,
      minDaysBetweenMessages:
          minDaysBetweenMessages ?? this.minDaysBetweenMessages,
      allowMergedMessages: allowMergedMessages ?? this.allowMergedMessages,
      allowHomeworkWording: allowHomeworkWording ?? this.allowHomeworkWording,
      allowAttendanceWording:
          allowAttendanceWording ?? this.allowAttendanceWording,
      allowDisciplineWording:
          allowDisciplineWording ?? this.allowDisciplineWording,
      bannedWords: bannedWords ?? this.bannedWords,
      replacements: replacements ?? this.replacements,
      categoryRules: categoryRules ?? this.categoryRules,
    );
  }

  /// --------------------------------------------------------------------------
  /// Serialization (Firestore Compatible)
  /// --------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'toneProfile': toneProfile.name, // e.g., 'governmentBalanced'
      'strictness': strictness.name,
      'maxStrongPer7Days': maxStrongPer7Days,
      'minDaysBetweenMessages': minDaysBetweenMessages,
      'allowMergedMessages': allowMergedMessages,
      'allowHomeworkWording': allowHomeworkWording,
      'allowAttendanceWording': allowAttendanceWording,
      'allowDisciplineWording': allowDisciplineWording,
      'bannedWords': bannedWords,
      'replacements': replacements,
      'categoryRules': categoryRules.map(
        (k, v) => MapEntry(k.name, {
          'enabled': v.enabled,
          'maxPer7Days': v.maxPer7Days,
          'maxSeverity': v.maxSeverity.name,
        }),
      ),
    };
  }

  factory StudentGuidancePolicy.fromJson(Map<String, dynamic> json) {
    return StudentGuidancePolicy(
      enabled: json['enabled'] ?? true,
      toneProfile: ToneProfile.values.firstWhere(
        (e) => e.name == json['toneProfile'],
        orElse: () => ToneProfile.governmentBalanced,
      ),
      strictness: StrictnessLevel.values.firstWhere(
        (e) => e.name == json['strictness'],
        orElse: () => StrictnessLevel.standard,
      ),
      maxStrongPer7Days: json['maxStrongPer7Days'] ?? 1,
      minDaysBetweenMessages: json['minDaysBetweenMessages'] ?? 2,
      allowMergedMessages: json['allowMergedMessages'] ?? true,
      allowHomeworkWording: json['allowHomeworkWording'] ?? true,
      allowAttendanceWording: json['allowAttendanceWording'] ?? true,
      allowDisciplineWording: json['allowDisciplineWording'] ?? true,
      bannedWords: List<String>.from(json['bannedWords'] ?? []),
      replacements: Map<String, String>.from(json['replacements'] ?? {}),
      categoryRules:
          (json['categoryRules'] as Map<String, dynamic>?)?.map((k, v) {
            final cat = GuidanceCategory.values.firstWhere(
              (e) => e.name == k,
              orElse: () => GuidanceCategory.positive,
            ); // Fallback safe
            return MapEntry(
              cat,
              GuidanceCategoryRule(
                enabled: v['enabled'] ?? true,
                maxPer7Days: v['maxPer7Days'] ?? 2,
                maxSeverity: GuidanceSeverity.values.firstWhere(
                  (e) => e.name == v['maxSeverity'],
                  orElse: () => GuidanceSeverity.strong,
                ),
              ),
            );
          }) ??
          {},
    );
  }
}
