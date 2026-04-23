import '../models/snapshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../scheduling/teacher_constraints_profile.dart' as intel;

class SchoolAnalyzer {
  const SchoolAnalyzer();

  Future<SchoolSnapshot> analyze(String schoolId) async {
    if (schoolId.trim().isEmpty) {
      throw Exception('schoolId فارغ');
    }

    final schoolDoc = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .get();
    final schoolData = schoolDoc.data() ?? const <String, dynamic>{};

    final schoolStageText = (schoolData['stage'] ?? '').toString();
    final stageHint = _stageHintFromSchoolStage(schoolStageText);
    final classInterpretationMode = stageHint == 'middle_only'
        ? 'middle_name_parser'
        : 'mixed';

    final classesSourcePath = 'Schools/$schoolId/Classes';
    final classesSnap = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .get();

    final parsedGradesSet = <int>{};
    final programTypes = <String>{};
    final classList = <SnapshotClass>[];
    final classGradeById = <String, int>{};
    final rawClassDocIds = <String>[];
    final rawClassGradeLevels = <dynamic>[];
    final parsedClassGradeLevels = <int>[];
    final classDebugSample = <Map<String, dynamic>>[];
    for (final d in classesSnap.docs) {
      final data = d.data();
      rawClassDocIds.add(d.id);
      final id = (data['id'] ?? d.id).toString();
      final name = (data['name'] ?? '').toString().trim();
      final nameCodeRaw = (data['nameCode'] ?? '').toString().trim();
      final displayNameRaw = (data['displayName'] ?? '').toString().trim();
      final rawGrade = data['gradeLevel'];
      rawClassGradeLevels.add(rawGrade);
      final parsedGrade = _resolveGradeLevel(
        stageHint: stageHint,
        className: name,
        nameCode: nameCodeRaw,
        data: data,
      );
      final parsedSectionNumber = _resolveSectionNumber(
        stageHint: stageHint,
        name: name,
        nameCode: nameCodeRaw,
        data: data,
      );
      if (parsedGrade != null && parsedGrade > 0) {
        parsedGradesSet.add(parsedGrade);
        parsedClassGradeLevels.add(parsedGrade);
        classGradeById[id] = parsedGrade;
      }
      final spt = (data['secondaryProgramType'] as String?)?.trim();
      if (spt != null && spt.isNotEmpty) programTypes.add(spt);

      if (classDebugSample.length < 25) {
        classDebugSample.add(<String, dynamic>{
          'docId': d.id,
          'id': data['id'],
          'name': data['name'],
          'nameCode': data['nameCode'],
          'displayName': data['displayName'],
          'gradeLevel': data['gradeLevel'],
          'level': data['level'],
          'grade': data['grade'],
          'index': data['index'],
          'order': data['order'],
          'number': data['number'],
          'section': data['section'],
          'sectionNumber': data['sectionNumber'],
          'stage': data['stage'],
          'track': data['track'],
          'secondaryTrack': data['secondaryTrack'],
          'secondaryPhase': data['secondaryPhase'],
          'parsedGradeLevel': parsedGrade,
          'parsedSectionNumber': parsedSectionNumber,
        });
      }
      classList.add(
        SnapshotClass(
          id: id,
          name: name.isEmpty ? id : name,
          nameCode: nameCodeRaw.isEmpty ? null : nameCodeRaw,
          displayName: displayNameRaw.isEmpty ? null : displayNameRaw,
          gradeLevel: parsedGrade ?? 0,
          secondaryProgramType: _normalizeSecondaryProgramType(spt),
          secondaryPhase:
              ((data['secondaryPhase'] as String?)?.trim().isNotEmpty == true)
              ? (data['secondaryPhase'] as String).trim()
              : _secondaryPhase(
                  stageHint: stageHint,
                  gradeLevel: parsedGrade ?? 0,
                ),
          secondaryTrack: _secondaryTrack(
            stageHint: stageHint,
            gradeLevel: parsedGrade ?? 0,
            raw: ((data['track'] ?? data['secondaryTrack']) as String?)?.trim(),
          ),
          sectionNumber: parsedSectionNumber,
        ),
      );
    }
    final parsedGrades = parsedGradesSet.toList()..sort();

    final teachersSnap = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .get();

    final subjectsDoc = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Config')
        .doc('Subjects')
        .get();
    final subjectsData = subjectsDoc.data() ?? const <String, dynamic>{};
    final rawSubjects = subjectsData['subjects'];
    final subjectsMap = rawSubjects is Map<String, dynamic>
        ? rawSubjects
        : <String, dynamic>{};
    final subjectsCount = subjectsMap.length;
    final subjectList = <SnapshotSubject>[];
    final subjectIdByAlias = <String, String>{};
    for (final entry in subjectsMap.entries) {
      final id = entry.key.trim();
      if (id.isEmpty) continue;
      final value = entry.value;
      String name = id;
      if (value is Map<String, dynamic>) {
        final rawName = (value['name'] ?? '').toString().trim();
        if (rawName.isNotEmpty) name = rawName;
      }
      subjectList.add(SnapshotSubject(id: id, name: name));
      subjectIdByAlias[_normalizeKey(id)] = id;
      subjectIdByAlias[_normalizeKey(name)] = id;

      if (value is Map<String, dynamic>) {
        final rawAliases = value['aliases'];
        if (rawAliases is List) {
          for (final a in rawAliases) {
            if (a == null) continue;
            final s = a.toString().trim();
            if (s.isEmpty) continue;
            subjectIdByAlias[_normalizeKey(s)] = id;
          }
        }
      }
    }

    final daysPerWeekRaw = schoolData['daysPerWeek'];
    final periodsPerDayRaw = schoolData['periodsPerDay'];
    final daysPerWeek = daysPerWeekRaw is int
        ? daysPerWeekRaw
        : int.tryParse('$daysPerWeekRaw');
    final periodsPerDay = periodsPerDayRaw is int
        ? periodsPerDayRaw
        : int.tryParse('$periodsPerDayRaw');

    final stage = stageHint ?? _detectStageFromGrades(parsedGrades);
    final grades = _filterGradesForStage(stage, parsedGrades);
    final lowerPrimaryClassesCount = classList
        .where((c) => c.gradeLevel >= 1 && c.gradeLevel <= 3)
        .length;
    final upperPrimaryClassesCount = classList
        .where((c) => c.gradeLevel >= 4 && c.gradeLevel <= 6)
        .length;

    var secondaryProgramType =
        (schoolData['secondaryProgramType'] as String?)?.trim() ??
        (programTypes.length == 1 ? programTypes.first : null);
    secondaryProgramType = _normalizeSecondaryProgramType(secondaryProgramType);
    if (stage == 'secondary_only') {
      secondaryProgramType = 'masarat';
    }
    final secondaryStructure =
        (schoolData['secondaryStructure'] as String?)?.trim().isNotEmpty == true
        ? (schoolData['secondaryStructure'] as String).trim()
        : (stage == 'secondary_only' ? 'shared_year_then_tracks' : null);
    final enabledTracksRaw = schoolData['enabledTracks'];
    final enabledTracks = enabledTracksRaw is List
        ? enabledTracksRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : (stage == 'secondary_only'
              ? const <String>[
                  'general',
                  'computer_engineering',
                  'health_life',
                  'business',
                  'sharia',
                ]
              : const <String>[]);
    final schoolEducationProfile =
        (schoolData['schoolEducationProfile'] as String?)?.trim();

    final teacherList = <SnapshotTeacher>[];
    final profilesByTeacherId = await _loadTeacherConstraintsProfiles(
      teacherIds: teachersSnap.docs.map((d) => d.id).toList(),
    );
    for (final d in teachersSnap.docs) {
      final data = d.data();
      final id = d.id;
      final name = (data['name'] ?? '').toString().trim();
      final assignedClassIds =
          (data['assignedClassIds'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
      final specialization = (data['specialization'] ?? '').toString().trim();
      final primarySubjectId = (data['primarySubjectId'] ?? '')
          .toString()
          .trim();
      final stageStr = (data['stage'] ?? '').toString().trim();
      final maxWeeklyClassesRaw = data['maxWeeklyClasses'];
      final maxWeeklyClasses = maxWeeklyClassesRaw is int
          ? maxWeeklyClassesRaw
          : int.tryParse('$maxWeeklyClassesRaw');
      final teacherRank = (data['teacherRank'] ?? '').toString().trim();
      final sharedBetweenSchools =
          data['sharedBetweenSchools'] == true ||
          data['isSharedBetweenSchools'] == true ||
          data['multiSchool'] == true ||
          data['isMultiSchool'] == true;
      final rankDefaultQuota = _rankQuota(
        teacherRank: teacherRank,
        sharedBetweenSchools: sharedBetweenSchools,
      );
      final effectiveMaxWeeklyClasses =
          (maxWeeklyClasses != null && maxWeeklyClasses > 0)
          ? maxWeeklyClasses
          : rankDefaultQuota;

      final subjectAssignmentsRaw = data['subjectAssignments'];
      final subjectAssignments = <SnapshotSubjectAssignment>[];
      if (subjectAssignmentsRaw is List) {
        for (final a in subjectAssignmentsRaw) {
          if (a is! Map) continue;
          final map = Map<String, dynamic>.from(a.cast<String, dynamic>());
          final subj = (map['subjectId'] ?? '').toString().trim();
          if (subj.isEmpty) continue;
          final type = (map['type'] ?? '').toString().trim();
          subjectAssignments.add(
            SnapshotSubjectAssignment(subjectId: subj, type: type),
          );
        }
      }

      final additionalSubjectsRaw = data['additionalSubjects'];
      final additionalSubjects = additionalSubjectsRaw is List
          ? additionalSubjectsRaw.map((e) => e.toString()).toList()
          : const <String>[];

      final prof = profilesByTeacherId[id];
      final maxWeeklyLoad = prof?.weeklyQuota ?? effectiveMaxWeeklyClasses;
      final targetWeeklyLoad = effectiveMaxWeeklyClasses > maxWeeklyLoad
          ? maxWeeklyLoad
          : effectiveMaxWeeklyClasses;
      final masaratAssignmentType = (data['masaratAssignmentType'] ?? '')
          .toString()
          .trim();
      final masaratGradeLevelRaw = data['masaratGradeLevel'];
      final masaratGradeLevel = masaratGradeLevelRaw is int
          ? masaratGradeLevelRaw
          : int.tryParse('$masaratGradeLevelRaw');
      final masaratTracksRaw = data['masaratTracks'];
      final masaratTracks = masaratTracksRaw is List
          ? masaratTracksRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[];

      teacherList.add(
        SnapshotTeacher(
          id: id,
          name: name.isEmpty ? id : name,
          stage: stageStr.isEmpty ? null : stageStr,
          specialization: specialization.isEmpty ? null : specialization,
          primarySubjectId: primarySubjectId.isEmpty ? null : primarySubjectId,
          additionalSubjects: additionalSubjects,
          subjectAssignments: subjectAssignments,
          assignedClassIds: assignedClassIds,
          masaratAssignmentType: masaratAssignmentType.isEmpty
              ? null
              : masaratAssignmentType,
          masaratTracks: masaratTracks,
          masaratGradeLevel: masaratGradeLevel,
          targetWeeklyLoad: targetWeeklyLoad,
          maxWeeklyLoad: maxWeeklyLoad,
          isAdministrative: prof?.hasAdministrativeDuties ?? false,
          isMedicalExempt: prof?.medicalExemption ?? false,
          blockedTimeSlots: prof?.blockedTimeSlots ?? const <String>[],
          preferredTimeSlots: prof?.preferredTimeSlots ?? const <String>[],
          softConstraintSlots: prof?.softConstraintSlots ?? const <String>[],
        ),
      );
    }

    return SchoolSnapshot(
      schoolId: schoolId,
      stage: stage,
      grades: grades,
      teachersCount: teachersSnap.size,
      subjectsCount: subjectsCount,
      classesCount: classesSnap.size,
      lowerPrimaryClassesCount: lowerPrimaryClassesCount,
      upperPrimaryClassesCount: upperPrimaryClassesCount,
      daysPerWeek: daysPerWeek ?? 5,
      periodsPerDay: periodsPerDay ?? 7,
      secondaryProgramType: secondaryProgramType,
      secondaryStructure: secondaryStructure,
      enabledTracks: enabledTracks,
      schoolEducationProfile: schoolEducationProfile,
      classes: classList,
      subjects: subjectList,
      teachers: teacherList,
      subjectIdByAlias: subjectIdByAlias,
      classesSourcePath: classesSourcePath,
      rawClassDocIds: rawClassDocIds,
      rawClassGradeLevels: rawClassGradeLevels,
      parsedClassGradeLevels: parsedClassGradeLevels,
      effectiveGradeLevels: parsedClassGradeLevels,
      classInterpretationMode: classInterpretationMode,
      classDebugSample: classDebugSample,
    );
  }

  int _rankQuota({
    required String teacherRank,
    required bool sharedBetweenSchools,
  }) {
    final r = teacherRank.trim().toLowerCase();
    if (sharedBetweenSchools) {
      if (r == 'expert') return 14;
      if (r == 'advanced') return 18;
      return 20;
    }
    if (r == 'expert') return 18;
    if (r == 'advanced') return 22;
    return 24;
  }

  int? _resolveSectionNumber({
    required String? stageHint,
    required String name,
    required String nameCode,
    required Map<String, dynamic> data,
  }) {
    final raw = data['sectionNumber'];
    final direct = raw is int ? raw : int.tryParse('$raw');
    if (direct != null && direct > 0) return direct;
    if (stageHint != 'secondary_only') return null;
    final parsed = _parseMasaratCode(nameCode.isNotEmpty ? nameCode : name);
    final s = parsed?['sectionNumber'];
    if (s != null && s > 0) return s;
    return null;
  }

  Map<String, int>? _parseMasaratCode(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    final m = RegExp(r'^([123])(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final gradeDigit = int.tryParse(m.group(1) ?? '');
    final sectionNumber = int.tryParse(m.group(2) ?? '');
    if (gradeDigit == null || sectionNumber == null) return null;
    return <String, int>{
      'gradeDigit': gradeDigit,
      'sectionNumber': sectionNumber,
    };
  }

  String? _normalizeSecondaryProgramType(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('مسارات') || v.contains('masarat')) return 'masarat';
    if (v.contains('مقررات') || v.contains('muqarrarat')) return 'masarat';
    return v;
  }

  String? _secondaryPhase({
    required String? stageHint,
    required int gradeLevel,
  }) {
    if (stageHint != 'secondary_only') return null;
    if (gradeLevel == 10) return 'shared';
    if (gradeLevel == 11 || gradeLevel == 12) return 'specialized';
    return null;
  }

  String? _secondaryTrack({
    required String? stageHint,
    required int gradeLevel,
    required String? raw,
  }) {
    if (stageHint != 'secondary_only') return raw;
    if (gradeLevel == 10) return null;
    final v = (raw ?? '').trim();
    return v.isEmpty ? null : v;
  }

  String? _stageHintFromSchoolStage(String schoolStage) {
    final s = schoolStage.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('ابتد') || s.contains('primary')) return 'primary_only';
    if (s.contains('متوسط') || s.contains('middle')) return 'middle_only';
    if (s.contains('ثانوي') || s.contains('secondary') || s.contains('high')) {
      return 'secondary_only';
    }
    return null;
  }

  String _detectStageFromGrades(List<int> grades) {
    if (grades.isEmpty) return 'combined';
    final hasPrimary = grades.any((g) => g >= 1 && g <= 6);
    final hasMiddle = grades.any((g) => g >= 7 && g <= 9);
    final hasSecondary = grades.any((g) => g >= 10 && g <= 12);

    if (hasPrimary && !hasMiddle && !hasSecondary) return 'primary_only';
    if (!hasPrimary && hasMiddle && !hasSecondary) return 'middle_only';
    if (!hasPrimary && !hasMiddle && hasSecondary) return 'secondary_only';
    return 'combined';
  }

  List<int> _filterGradesForStage(String stage, List<int> rawGrades) {
    if (rawGrades.isEmpty) return const <int>[];
    final filtered = switch (stage) {
      'primary_only' => rawGrades.where((g) => g >= 1 && g <= 6).toList(),
      'middle_only' => rawGrades.where((g) => g >= 7 && g <= 9).toList(),
      'secondary_only' => rawGrades.where((g) => g >= 10 && g <= 12).toList(),
      _ => rawGrades,
    };
    filtered.sort();
    return filtered.isNotEmpty ? filtered : rawGrades;
  }

  int? _resolveGradeLevel({
    required String? stageHint,
    required String className,
    required String nameCode,
    required Map<String, dynamic> data,
  }) {
    if (stageHint == 'middle_only') {
      final parsedFromName = _parseGradeFromClassName(stageHint, className);
      if (parsedFromName != null) return parsedFromName;
    }

    final fields = <String>[
      'gradeLevel',
      'grade',
      'level',
      'grade_number',
      'gradeNumber',
    ];

    int? candidate;
    for (final f in fields) {
      final raw = data[f];
      final v = raw is int ? raw : int.tryParse('$raw');
      if (v == null) continue;
      candidate = v;
      break;
    }

    final mappedCandidate = _mapGradeByStageHint(stageHint, candidate);
    if (mappedCandidate != null) return mappedCandidate;

    if (stageHint == 'secondary_only') {
      final codeParsed = _parseMasaratCode(
        nameCode.isNotEmpty ? nameCode : className,
      );
      if (codeParsed != null) {
        final digit = codeParsed['gradeDigit'] ?? 0;
        if (digit >= 1 && digit <= 3) return digit + 9;
      }
    }

    final parsedFromName = _parseGradeFromClassName(stageHint, className);
    if (parsedFromName != null) return parsedFromName;

    if (candidate != null && candidate >= 1 && candidate <= 12) {
      return candidate;
    }
    return null;
  }

  int? _mapGradeByStageHint(String? stageHint, int? raw) {
    if (raw == null) return null;
    if (raw <= 0) return null;

    if (stageHint == 'middle_only') {
      if (raw >= 7 && raw <= 9) return raw;
      if (raw >= 1 && raw <= 3) return raw + 6;
      return null;
    }
    if (stageHint == 'secondary_only') {
      if (raw >= 10 && raw <= 12) return raw;
      if (raw >= 1 && raw <= 3) return raw + 9;
      return null;
    }
    if (stageHint == 'primary_only') {
      if (raw >= 1 && raw <= 6) return raw;
      return null;
    }
    return null;
  }

  int? _parseGradeFromClassName(String? stageHint, String className) {
    final s = className.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2})\s*[/\\\-]').firstMatch(s);
    if (m == null) return null;
    final n = int.tryParse(m.group(1) ?? '');
    if (n == null) return null;

    if (stageHint == 'middle_only') {
      if (n >= 1 && n <= 3) return n + 6;
      if (n >= 7 && n <= 9) return n;
      return null;
    }
    if (stageHint == 'secondary_only') {
      if (n >= 1 && n <= 3) return n + 9;
      if (n >= 10 && n <= 12) return n;
      return null;
    }
    if (stageHint == 'primary_only') {
      if (n >= 1 && n <= 6) return n;
      return null;
    }
    if (n >= 1 && n <= 12) return n;
    return null;
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

  Future<Map<String, intel.TeacherConstraintsProfile>>
  _loadTeacherConstraintsProfiles({required List<String> teacherIds}) async {
    final out = <String, intel.TeacherConstraintsProfile>{};
    final futures = <Future<void>>[];
    for (final id in teacherIds) {
      if (id.trim().isEmpty) continue;
      futures.add(() async {
        final doc = await FirebaseFirestore.instance
            .collection('teacher_constraints_profiles')
            .doc(id)
            .get();
        final data = doc.data();
        if (data == null) return;
        final prof = intel.TeacherConstraintsProfile.fromMap(data);
        out[id] = prof;
      }());
    }
    await Future.wait(futures);
    return out;
  }
}
