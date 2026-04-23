class TimetablePolicies {
  final Map<String, dynamic> raw;

  TimetablePolicies(this.raw);

  Map<String, dynamic> get globalDefaults =>
      (raw['globalDefaults'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  Map<String, dynamic> get stageProfiles =>
      (raw['stageProfiles'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  Map<String, dynamic> get workloadPolicies =>
      (raw['workloadPolicies'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  Map<String, dynamic> get schoolProfileResolver =>
      (raw['schoolProfileResolver'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  String get defaultPolicy =>
      (raw['defaultPolicy'] as String?)?.trim().isNotEmpty == true
      ? (raw['defaultPolicy'] as String).trim()
      : 'middle_only';

  String resolveStageProfileKey({
    required String? schoolEducationProfile,
    required String? fallbackStageArabic,
  }) {
    final profile = (schoolEducationProfile ?? '').trim().isNotEmpty == true
        ? schoolEducationProfile!.trim()
        : _fallbackEducationProfileFromStage(fallbackStageArabic);

    final rules =
        (schoolProfileResolver['rules'] as List?)?.cast<dynamic>() ?? const [];
    for (final r in rules) {
      final m = r is Map ? r.cast<String, dynamic>() : null;
      if (m == null) continue;
      if ((m['ifSchoolEducationProfile'] ?? '').toString() == profile) {
        return (m['useStageProfile'] ?? defaultPolicy).toString();
      }
    }
    return defaultPolicy;
  }

  Map<String, dynamic> loadStageProfile(String stageProfileKey) {
    final p = stageProfiles[stageProfileKey];
    return (p is Map ? p.cast<String, dynamic>() : null) ??
        const <String, dynamic>{};
  }

  Map<String, dynamic> mergedConstraintsForStage(String stageProfileKey) {
    final stage = loadStageProfile(stageProfileKey);
    final stageConstraints =
        (stage['constraints'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final stageTeacherPref = (stage['teacherPreferencePolicy'] as Map?)
        ?.cast<String, dynamic>();
    final subjectRules =
        (raw['subjectRules'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final teacherPrefGlobal = (raw['teacherPreferencePolicy'] as Map?)
        ?.cast<String, dynamic>();

    final merged = <String, dynamic>{};
    merged.addAll(globalDefaults);
    merged.addAll(subjectRules);
    merged.addAll(stageConstraints);
    if (teacherPrefGlobal != null) {
      merged['teacherPreferencePolicy'] = Map<String, dynamic>.from(
        teacherPrefGlobal,
      );
    }
    if (stageTeacherPref != null) {
      final base =
          (merged['teacherPreferencePolicy'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      base.addAll(stageTeacherPref);
      merged['teacherPreferencePolicy'] = base;
    }
    return merged;
  }

  int intValue(Map<String, dynamic> m, String key, int fallback) {
    final v = m[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    final parsed = int.tryParse(v?.toString() ?? '');
    return parsed ?? fallback;
  }

  bool boolValue(Map<String, dynamic> m, String key, bool fallback) {
    final v = m[key];
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  String _fallbackEducationProfileFromStage(String? stageArabic) {
    final s = (stageArabic ?? '').trim();
    if (s.contains('ابتد')) return 'primary_only';
    if (s.contains('متوسط')) return 'middle_only';
    if (s.contains('ثانو')) return 'secondary_only';
    return defaultPolicy;
  }
}
