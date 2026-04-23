class SaudiSubjectPlans {
  final Map<String, dynamic> raw;

  SaudiSubjectPlans(this.raw);

  Map<String, dynamic> get plans =>
      (raw['plans'] as Map?)?.cast<String, dynamic>() ?? const {};

  Map<String, dynamic> get trackCatalog =>
      (raw['trackCatalog'] as Map?)?.cast<String, dynamic>() ?? const {};

  Map<String, int> weeklyDemandForGrade({
    required int gradeLevel,
    required String? secondaryProgramType,
    required String? secondaryTrack,
  }) {
    final planKey = _planKeyForGrade(
      gradeLevel: gradeLevel,
      secondaryProgramType: secondaryProgramType,
    );
    final plan = (plans[planKey] as Map?)?.cast<String, dynamic>();
    if (plan == null) return const {};
    final grades = (plan['grades'] as Map?)?.cast<String, dynamic>();
    if (grades == null) return const {};
    final g = grades['$gradeLevel'];
    if (g is! Map) return const {};
    final gradeMap = g.cast<String, dynamic>();

    final commonRaw = gradeMap['common'];
    final tracksRaw = gradeMap['tracks'];
    if (commonRaw is Map && tracksRaw is Map) {
      final common = _toIntMap(commonRaw);
      final tracks = tracksRaw.cast<String, dynamic>();
      final key = _normalizeTrackKey(secondaryTrack);
      final deltaRaw = key.isEmpty ? null : tracks[key];
      if (deltaRaw is Map) {
        final delta = _toIntMap(deltaRaw);
        final merged = Map<String, int>.from(common);
        delta.forEach((subject, diff) {
          merged[subject] = (merged[subject] ?? 0) + diff;
        });
        merged.removeWhere((_, v) => v <= 0);
        return merged;
      }
      common.removeWhere((_, v) => v <= 0);
      return common;
    }

    final flat = _toIntMap(gradeMap);
    flat.removeWhere((_, v) => v <= 0);
    return flat;
  }

  Map<String, int> _toIntMap(Map rawMap) {
    return rawMap.cast<String, dynamic>().map((k, v) {
      if (v is int) return MapEntry(k, v);
      if (v is num) return MapEntry(k, v.toInt());
      return MapEntry(k, int.tryParse(v.toString()) ?? 0);
    });
  }

  String _normalizeTrackKey(String? rawTrack) {
    final raw = (rawTrack ?? '').trim();
    if (raw.isEmpty) return '';
    final direct = raw.toLowerCase();
    if (trackCatalog.containsKey(direct)) return direct;

    final normalized = _normalizeSimple(direct);
    for (final entry in trackCatalog.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      final aliasesRaw = data['aliases'];
      if (aliasesRaw is! List) continue;
      for (final a in aliasesRaw) {
        final s = (a ?? '').toString().trim();
        if (s.isEmpty) continue;
        if (_normalizeSimple(s.toLowerCase()) == normalized) {
          return entry.key.toLowerCase();
        }
      }
    }
    return direct;
  }

  String _normalizeSimple(String s) {
    var out = s.trim();
    out = out.replaceAll('أ', 'ا');
    out = out.replaceAll('إ', 'ا');
    out = out.replaceAll('آ', 'ا');
    out = out.replaceAll('ى', 'ي');
    out = out.replaceAll('ة', 'ه');
    out = out.replaceAll('ـ', '');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  String _planKeyForGrade({
    required int gradeLevel,
    required String? secondaryProgramType,
  }) {
    if (gradeLevel >= 1 && gradeLevel <= 3) return 'primary_lower';
    if (gradeLevel >= 4 && gradeLevel <= 6) return 'primary_upper';
    if (gradeLevel >= 7 && gradeLevel <= 9) return 'middle';
    final type = (secondaryProgramType ?? '').toLowerCase().trim();
    if (type == 'masarat') return 'secondary_masarat';
    return 'secondary_general';
  }
}
