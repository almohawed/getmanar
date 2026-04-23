import '../models/assignment.dart';
import '../models/policy.dart';
import '../models/snapshot.dart';

class AssignmentEngine {
  const AssignmentEngine();

  AssignmentModel assign(SchoolSnapshot snapshot, PolicyProfile policy) {
    final classGradeById = <String, int>{
      for (final c in snapshot.classes) c.id: c.gradeLevel,
    };

    final isPrimaryOnly = snapshot.stage == 'primary_only';
    final subjectIds = snapshot.subjects.map((s) => s.id).toSet();
    final allowUnknownSubjectIds = isPrimaryOnly || subjectIds.isEmpty;
    final coveredTeachersBySubject = <String, int>{
      for (final id in subjectIds) id: 0,
    };

    int assignedTeachersCount = 0;
    int unassignedTeachersCount = 0;
    int overloadedTeachersCount = 0;
    int subjectTeachersCount = 0;
    int lowerPrimaryTeachersCount = 0;
    int upperPrimaryTeachersCount = 0;
    int bundleTeachersCount = 0;
    int sharedTeachersCount = 0;
    int specializedTeachersCount = 0;
    int administrativeTeachersCount = 0;

    final entries = <TeacherAssignment>[];

    final lowerDailyAliases = _stringList(
      isPrimaryOnly ? policy.raw['primary_lower_policy_daily_subjects'] : null,
    );
    final lowerBundleAliases = _stringList(
      isPrimaryOnly ? policy.raw['primary_lower_policy_bundle_subjects'] : null,
    );
    final lowerDailySubjectIds = isPrimaryOnly
        ? _resolveSubjectIdsByAliases(
            aliases: lowerDailyAliases.isNotEmpty
                ? lowerDailyAliases
                : const ['لغتي', 'رياضيات'],
            subjectIdByAlias: snapshot.subjectIdByAlias,
            subjectIds: subjectIds,
          )
        : const <String>[];
    final lowerBundleSubjectIds = isPrimaryOnly
        ? _resolveSubjectIdsByAliases(
            aliases: lowerBundleAliases.isNotEmpty
                ? lowerBundleAliases
                : const ['لغتي', 'رياضيات', 'اسلامية', 'علوم', 'مهارات'],
            subjectIdByAlias: snapshot.subjectIdByAlias,
            subjectIds: subjectIds,
          )
        : const <String>[];
    final masaratEligibilityEngine = SecondaryMasaratEligibilityEngine(
      subjectIdByAlias: snapshot.subjectIdByAlias,
      knownSubjectIds: subjectIds,
    );
    final enableMasaratEligibility =
        snapshot.stage == 'secondary_only' && snapshot.secondaryProgramType == 'masarat';

    for (final t in snapshot.teachers) {
      final assignedSubjects = <String>{};

      String? primary;
      if (t.primarySubjectId != null && t.primarySubjectId!.trim().isNotEmpty) {
        final id = t.primarySubjectId!.trim();
        if (allowUnknownSubjectIds || subjectIds.contains(id)) {
          primary = id;
          assignedSubjects.add(id);
        }
      }

      for (final a in t.subjectAssignments) {
        final id = a.subjectId.trim();
        if (id.isEmpty) continue;
        if (!allowUnknownSubjectIds && !subjectIds.contains(id)) continue;
        assignedSubjects.add(id);
      }

      for (final s in t.additionalSubjects) {
        final id = s.trim();
        if (id.isEmpty) continue;
        if (!allowUnknownSubjectIds && !subjectIds.contains(id)) continue;
        assignedSubjects.add(id);
      }

      final spec = t.specialization?.trim() ?? '';
      if (spec.isNotEmpty) {
        final alias = _normalizeKey(spec);
        final mapped = snapshot.subjectIdByAlias[alias];
        if (mapped != null &&
            (allowUnknownSubjectIds || subjectIds.contains(mapped))) {
          assignedSubjects.add(mapped);
          primary ??= mapped;
        }
      }

      if (enableMasaratEligibility && !t.isAdministrative) {
        assignedSubjects.addAll(
          masaratEligibilityEngine.resolveEligibleSubjectIds(
            specialization: t.specialization,
            primarySubjectId: t.primarySubjectId,
            additionalSubjectIds: t.additionalSubjects,
            subjectAssignments: t.subjectAssignments,
          ),
        );
        if (primary == null && assignedSubjects.isNotEmpty) {
          primary = assignedSubjects.first;
        }
      }

      final stageClassification = _classifyTeacher(
        teacher: t,
        classGradeById: classGradeById,
      );
      if (stageClassification == 'lower_primary') lowerPrimaryTeachersCount++;
      if (stageClassification == 'upper_primary') upperPrimaryTeachersCount++;

      final primaryBand = isPrimaryOnly
          ? _primaryBandForTeacher(
              teacher: t,
              classGradeById: classGradeById,
              stageClassification: stageClassification,
            )
          : '';
      final isLowerPrimaryTeacher =
          isPrimaryOnly && primaryBand == 'lower' && !t.isAdministrative;
      final isUpperPrimaryTeacher =
          isPrimaryOnly && primaryBand == 'upper' && !t.isAdministrative;

      if (isLowerPrimaryTeacher) {
        assignedSubjects.clear();
        final bundle = lowerBundleSubjectIds.isNotEmpty
            ? lowerBundleSubjectIds
            : const <String>['لغتي', 'رياضيات', 'اسلامية', 'علوم', 'مهارات'];
        for (final s in bundle) {
          final id = s.trim();
          if (id.isNotEmpty) assignedSubjects.add(id);
        }
        if (primary == null) {
          final daily = lowerDailySubjectIds.isNotEmpty
              ? lowerDailySubjectIds
              : const <String>['لغتي', 'رياضيات'];
          primary = daily.first;
        }
      } else if (isUpperPrimaryTeacher) {
        if (primary == null && assignedSubjects.isNotEmpty) {
          primary = assignedSubjects.first;
        }
      }

      String? effectivePrimary = primary;
      if (effectivePrimary == null && assignedSubjects.length == 1) {
        effectivePrimary = assignedSubjects.first;
      }

      final teacherType = isLowerPrimaryTeacher
          ? 'bundle'
          : _classifyTeacherType(
              isAdministrative: t.isAdministrative,
              assignedSubjectsCount: assignedSubjects.length,
              primarySubject: effectivePrimary,
            );
      if (teacherType == 'administrative') administrativeTeachersCount++;
      if (teacherType == 'specialized') specializedTeachersCount++;
      if (teacherType == 'shared') sharedTeachersCount++;
      if (teacherType == 'bundle') bundleTeachersCount++;

      final isAssigned = isPrimaryOnly
          ? (!t.isAdministrative &&
                (isLowerPrimaryTeacher || isUpperPrimaryTeacher) &&
                _hasAnyPrimaryClassAssignment(
                  teacher: t,
                  classGradeById: classGradeById,
                ))
          : assignedSubjects.isNotEmpty;
      if (isAssigned) {
        assignedTeachersCount++;
        if (isPrimaryOnly) {
          if (isUpperPrimaryTeacher) subjectTeachersCount++;
        } else {
          if (!t.isAdministrative) subjectTeachersCount++;
        }
        if (assignedSubjects.isNotEmpty) {
          for (final s in assignedSubjects) {
            coveredTeachersBySubject[s] =
                (coveredTeachersBySubject[s] ?? 0) + 1;
          }
        }
      } else {
        unassignedTeachersCount++;
      }

      final overloaded = t.targetWeeklyLoad > t.maxWeeklyLoad;
      if (overloaded) overloadedTeachersCount++;

      entries.add(
        TeacherAssignment(
          teacherId: t.id,
          teacherName: t.name,
          classification: teacherType,
          primarySubject: effectivePrimary,
          additionalSubjects: t.additionalSubjects,
          assignedSubjects: assignedSubjects.toList()..sort(),
          targetWeeklyLoad: t.targetWeeklyLoad,
          maxWeeklyLoad: t.maxWeeklyLoad,
          isAdministrative: t.isAdministrative,
          isMedicalExempt: t.isMedicalExempt,
        ),
      );
    }

    final uncoveredSubjectIds = <String>[];
    for (final s in subjectIds) {
      if ((coveredTeachersBySubject[s] ?? 0) <= 0) uncoveredSubjectIds.add(s);
    }
    uncoveredSubjectIds.sort();

    final summary = AssignmentSummary(
      teachersCount: snapshot.teachersCount,
      assignedTeachersCount: assignedTeachersCount,
      unassignedTeachersCount: unassignedTeachersCount,
      uncoveredSubjectsCount: uncoveredSubjectIds.length,
      overloadedTeachersCount: overloadedTeachersCount,
      subjectTeachersCount: subjectTeachersCount,
      lowerPrimaryTeachersCount: lowerPrimaryTeachersCount,
      upperPrimaryTeachersCount: upperPrimaryTeachersCount,
      bundleTeachersCount: bundleTeachersCount,
      sharedTeachersCount: sharedTeachersCount,
      specializedTeachersCount: specializedTeachersCount,
      administrativeTeachersCount: administrativeTeachersCount,
    );

    return AssignmentModel(
      teachers: entries,
      summary: summary,
      uncoveredSubjectIds: uncoveredSubjectIds,
    );
  }

  String _classifyTeacher({
    required SnapshotTeacher teacher,
    required Map<String, int> classGradeById,
  }) {
    final grades = <int>{};
    for (final cid in teacher.assignedClassIds) {
      final g = classGradeById[cid];
      if (g != null && g > 0) grades.add(g);
    }
    if (grades.isNotEmpty) {
      final hasLower = grades.any((g) => g >= 1 && g <= 3);
      final hasUpper = grades.any((g) => g >= 4 && g <= 6);
      final hasPrimary = grades.any((g) => g >= 1 && g <= 6);
      final hasMiddle = grades.any((g) => g >= 7 && g <= 9);
      final hasSecondary = grades.any((g) => g >= 10 && g <= 12);

      if (hasLower && !hasUpper && !hasMiddle && !hasSecondary) {
        return 'lower_primary';
      }
      if (!hasLower && hasUpper && !hasMiddle && !hasSecondary) {
        return 'upper_primary';
      }
      if (hasPrimary && !hasMiddle && !hasSecondary) return 'primary';
      if (!hasPrimary && hasMiddle && !hasSecondary) return 'middle';
      if (!hasPrimary && !hasMiddle && hasSecondary) return 'secondary';
      return 'shared';
    }

    final s = (teacher.stage ?? '').trim().toLowerCase();
    if (s.contains('ابتد') || s.contains('primary')) return 'primary';
    if (s.contains('متوسط') || s.contains('middle')) return 'middle';
    if (s.contains('ثانوي') || s.contains('secondary') || s.contains('high')) {
      return 'secondary';
    }
    return 'shared';
  }

  String _normalizeKey(String s) {
    var v = s.trim().toLowerCase();
    v = v
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
    return v;
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  List<String> _resolveSubjectIdsByAliases({
    required List<String> aliases,
    required Map<String, String> subjectIdByAlias,
    required Set<String> subjectIds,
  }) {
    final out = <String>{};
    for (final a in aliases) {
      final key = _normalizeKey(a);
      final mapped = subjectIdByAlias[key];
      if (mapped != null &&
          (subjectIds.isEmpty || subjectIds.contains(mapped))) {
        out.add(mapped);
        continue;
      }
      if (subjectIds.isEmpty && key.isNotEmpty) out.add(key);
    }
    final list = out.toList()..sort();
    return list;
  }

  String _primaryBandForTeacher({
    required SnapshotTeacher teacher,
    required Map<String, int> classGradeById,
    required String stageClassification,
  }) {
    final grades = <int>{};
    for (final cid in teacher.assignedClassIds) {
      final g = classGradeById[cid];
      if (g != null && g > 0) grades.add(g);
    }

    if (grades.isNotEmpty) {
      final hasLower = grades.any((g) => g >= 1 && g <= 3);
      final hasUpper = grades.any((g) => g >= 4 && g <= 6);
      if (hasLower && !hasUpper) return 'lower';
      if (hasUpper && !hasLower) return 'upper';
    }

    if (stageClassification == 'lower_primary') return 'lower';
    if (stageClassification == 'upper_primary') return 'upper';

    final hasSubjects =
        (teacher.primarySubjectId ?? '').trim().isNotEmpty ||
        teacher.subjectAssignments.isNotEmpty ||
        teacher.additionalSubjects.isNotEmpty ||
        (teacher.specialization ?? '').trim().isNotEmpty;
    if (hasSubjects) return 'upper';
    return 'lower';
  }

  bool _hasAnyPrimaryClassAssignment({
    required SnapshotTeacher teacher,
    required Map<String, int> classGradeById,
  }) {
    for (final cid in teacher.assignedClassIds) {
      final g = classGradeById[cid];
      if (g != null && g >= 1 && g <= 6) return true;
    }
    return teacher.assignedClassIds.isNotEmpty &&
        ((teacher.stage ?? '').trim().contains('ابتد') ||
            (teacher.stage ?? '').trim().toLowerCase().contains('primary'));
  }

  String _classifyTeacherType({
    required bool isAdministrative,
    required int assignedSubjectsCount,
    required String? primarySubject,
  }) {
    if (isAdministrative) return 'administrative';
    if (assignedSubjectsCount <= 0) return 'unassigned';
    if (assignedSubjectsCount > 1) return 'shared';
    if (primarySubject == null || primarySubject.trim().isEmpty)
      return 'shared';
    return 'specialized';
  }
}

class SecondaryMasaratEligibilityEngine {
  final Map<String, String> subjectIdByAlias;
  final Set<String> knownSubjectIds;

  const SecondaryMasaratEligibilityEngine({
    required this.subjectIdByAlias,
    required this.knownSubjectIds,
  });

  Set<String> resolveEligibleSubjectIds({
    required String? specialization,
    required String? primarySubjectId,
    required List<String> additionalSubjectIds,
    required List<SnapshotSubjectAssignment> subjectAssignments,
  }) {
    final seed = <String>{};
    final spec = (specialization ?? '').trim();
    if (spec.isNotEmpty) seed.add(spec);
    final prim = (primarySubjectId ?? '').trim();
    if (prim.isNotEmpty) seed.add(prim);
    for (final s in additionalSubjectIds) {
      final v = s.trim();
      if (v.isNotEmpty) seed.add(v);
    }
    for (final a in subjectAssignments) {
      final v = a.subjectId.trim();
      if (v.isNotEmpty) seed.add(v);
    }

    final aliases = <String>[];
    for (final s in seed) {
      final n = _normalizeKey(s);
      if (n.contains('حاسب') || n.contains('الحاسب') || n.contains('computer')) {
        aliases.addAll(const [
          'AI',
          'Cyber',
          'Software',
          'Computer Architecture',
          'الذكاء الاصطناعي',
          'الامن السيبراني',
          'هندسة البرمجيات',
        ]);
        continue;
      }
      if (n.contains('رياض') || n.contains('math') || n.contains('فيز') || n.contains('physics')) {
        aliases.addAll(const ['هندسة', 'روبوت', 'robot', 'engineering']);
        continue;
      }
      if (n.contains('احياء') || n.contains('biology')) {
        aliases.addAll(const ['علوم صحية', 'جسم الانسان', 'health', 'anatomy']);
        continue;
      }
      if (n.contains('كيمي') || n.contains('chem')) {
        aliases.addAll(const ['كيمياء حيوية', 'biochemistry']);
        continue;
      }
      if (n.contains('ادار') || n.contains('business') || n.contains('اقتصاد')) {
        aliases.addAll(const ['ادارة مالية', 'تسويق', 'صناعة قرار', 'finance', 'marketing']);
        continue;
      }
      if (n.contains('اسلام') || n.contains('شرع') || n.contains('عرب') || n.contains('arabic')) {
        aliases.addAll(const ['قانون', 'انظمة', 'مواد شرعية', 'law', 'regulations']);
        continue;
      }
    }

    final out = <String>{};
    for (final a in aliases) {
      final key = _normalizeKey(a);
      final mapped = subjectIdByAlias[key];
      if (mapped != null && (knownSubjectIds.isEmpty || knownSubjectIds.contains(mapped))) {
        out.add(mapped);
        continue;
      }
      if (knownSubjectIds.contains(a)) {
        out.add(a);
      }
    }
    return out;
  }

  String _normalizeKey(String s) {
    var v = s.trim().toLowerCase();
    v = v
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
    return v;
  }
}
