enum TeacherFormType {
  primaryLowerForm,
  primaryUpperForm,
  middleForm,
  secondaryMasaratForm,
  secondaryMuqarraratForm,
  combinedForm,
}

class TeacherFormResolution {
  final String detectedStageKey;
  final String secondaryProgramType;
  final List<int> effectiveGradeLevels;
  final TeacherFormType formType;

  const TeacherFormResolution({
    required this.detectedStageKey,
    required this.secondaryProgramType,
    required this.effectiveGradeLevels,
    required this.formType,
  });

  String get formKey => switch (formType) {
    TeacherFormType.primaryLowerForm => 'primary_lower_form',
    TeacherFormType.primaryUpperForm => 'primary_upper_form',
    TeacherFormType.middleForm => 'middle_form',
    TeacherFormType.secondaryMasaratForm => 'secondary_masarat_form',
    TeacherFormType.secondaryMuqarraratForm => 'secondary_muqarrarat_form',
    TeacherFormType.combinedForm => 'combined_form',
  };

  String get formLabel => switch (formType) {
    TeacherFormType.primaryLowerForm => 'ابتدائي (صفوف أولية)',
    TeacherFormType.primaryUpperForm => 'ابتدائي (صفوف عليا/معلم مادة)',
    TeacherFormType.middleForm => 'متوسط',
    TeacherFormType.secondaryMasaratForm => 'ثانوي (مسارات)',
    TeacherFormType.secondaryMuqarraratForm => 'ثانوي (مقررات)',
    TeacherFormType.combinedForm => 'مجمع',
  };
}

class TeacherFormResolver {
  const TeacherFormResolver();

  TeacherFormResolution resolve({
    required String? schoolStageRaw,
    required String? secondaryProgramTypeRaw,
    required List<int> effectiveGradeLevels,
  }) {
    final stageKey = _detectStageKey(schoolStageRaw, effectiveGradeLevels);
    final hasSecondaryGrades = effectiveGradeLevels.any(
      (g) => g >= 10 && g <= 12,
    );
    final isSecondaryContext =
        stageKey == 'secondary_only' ||
        (stageKey == 'combined' && hasSecondaryGrades);
    final programType = _detectSecondaryProgramType(
      secondaryProgramTypeRaw,
      assumeSecondary: isSecondaryContext,
    );

    final form = switch (stageKey) {
      'primary_only' => TeacherFormType.primaryLowerForm,
      'middle_only' => TeacherFormType.middleForm,
      'secondary_only' => TeacherFormType.secondaryMasaratForm,
      _ => TeacherFormType.combinedForm,
    };

    return TeacherFormResolution(
      detectedStageKey: stageKey,
      secondaryProgramType: programType,
      effectiveGradeLevels: List<int>.from(effectiveGradeLevels)..sort(),
      formType: form,
    );
  }

  String _detectStageKey(String? schoolStageRaw, List<int> grades) {
    final s = (schoolStageRaw ?? '').trim().toLowerCase();
    if (s.isNotEmpty) {
      if (s.contains('ابتد') || s.contains('primary')) return 'primary_only';
      if (s.contains('متوسط') || s.contains('middle')) return 'middle_only';
      if (s.contains('ثانوي') ||
          s.contains('secondary') ||
          s.contains('high')) {
        return 'secondary_only';
      }
      if (s.contains('مجمع') || s.contains('combined')) return 'combined';
    }

    final hasPrimary = grades.any((g) => g >= 1 && g <= 6);
    final hasMiddle = grades.any((g) => g >= 7 && g <= 9);
    final hasSecondary = grades.any((g) => g >= 10 && g <= 12);

    if (hasPrimary && !hasMiddle && !hasSecondary) return 'primary_only';
    if (!hasPrimary && hasMiddle && !hasSecondary) return 'middle_only';
    if (!hasPrimary && !hasMiddle && hasSecondary) return 'secondary_only';
    return 'combined';
  }

  String _detectSecondaryProgramType(
    String? raw, {
    required bool assumeSecondary,
  }) {
    if (!assumeSecondary) return '';
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return 'masarat';
    if (s.contains('مسارات') || s.contains('masarat')) return 'masarat';
    if (s.contains('مقررات') || s.contains('muqarrarat')) return 'muqarrarat';
    return 'masarat';
  }
}
