import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../../intelligence/domain/scheduling/teacher_constraints_profile.dart';
import '../../intelligence/domain/scheduling/override_learning_log.dart';
import '../domain/schedule_slot.dart';
import '../domain/teacher_preference_entity.dart';
import '../domain/timetable_policies.dart';
import '../domain/saudi_subject_plans.dart';
import '../../intelligence/data/smart_schedule_repository.dart';
import 'advanced_schedule_solver.dart'; // إضافة الـ Solver الجديد

// Service Provider
final smartScheduleServiceProvider = Provider<SmartScheduleService>((ref) {
  final repo = ref.read(smartScheduleRepositoryProvider);
  return SmartScheduleService(repo);
});

class ScheduleGenerationResult {
  final Map<String, List<ScheduleSlot>> schedule;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic>? fairnessReport;
  final List<Map<String, dynamic>>? gapDiagnosis; // Added field

  ScheduleGenerationResult(
    this.schedule,
    this.metrics, {
    this.fairnessReport,
    this.gapDiagnosis,
  });
}

class ScheduleGenerationImpossibleException implements Exception {
  final List<Map<String, dynamic>> blockingTeachers;
  final String message;

  ScheduleGenerationImpossibleException(this.blockingTeachers, this.message);

  @override
  String toString() {
    return message;
  }
}

class _CoreScheduleBuildResult {
  final Map<String, List<ScheduleSlot>> schedule;
  final Map<String, dynamic> report;

  const _CoreScheduleBuildResult({
    required this.schedule,
    required this.report,
  });
}

class _V2Task {
  final String classId;
  final String day;
  final String subject;

  const _V2Task({
    required this.classId,
    required this.day,
    required this.subject,
  });
}

class _V2Assignment {
  final _V2Task task;
  final int period;
  final String teacherId;

  const _V2Assignment({
    required this.task,
    required this.period,
    required this.teacherId,
  });
}

class _V2FlexAssignment {
  final _V2SlotVar v;
  final String subject;
  final String teacherId;

  const _V2FlexAssignment({
    required this.v,
    required this.subject,
    required this.teacherId,
  });
}

class _V2Choice {
  final int period;
  final String teacherId;
  final double score;

  const _V2Choice({
    required this.period,
    required this.teacherId,
    required this.score,
  });
}

class _V2SlotVar {
  final String classId;
  final String day;
  final int period;

  const _V2SlotVar({
    required this.classId,
    required this.day,
    required this.period,
  });
}

class _SlotRef {
  final String teacherId;
  final int index;
  final ScheduleSlot slot;

  const _SlotRef({
    required this.teacherId,
    required this.index,
    required this.slot,
  });
}

class _BalancingPolicy {
  final bool preferNoEmptyTeacherDay;
  final bool hardDisallowEmptyTeacherDay;
  final int emptyTeacherDayPenalty;
  final int dailyLoadVariancePenalty;
  final bool enableRebalancing;
  final int rebalanceIterations;
  final String targetDailyLoadMode;
  final List<String> autoFillPriority;

  const _BalancingPolicy({
    required this.preferNoEmptyTeacherDay,
    required this.hardDisallowEmptyTeacherDay,
    required this.emptyTeacherDayPenalty,
    required this.dailyLoadVariancePenalty,
    required this.enableRebalancing,
    required this.rebalanceIterations,
    required this.targetDailyLoadMode,
    required this.autoFillPriority,
  });

  factory _BalancingPolicy.fromRaw(Map<String, dynamic> raw) {
    final ap =
        (raw['autoFillPriority'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[
          'rebalance_real_lessons',
          'activity',
          'supervision',
          'waiting',
        ];
    return _BalancingPolicy(
      preferNoEmptyTeacherDay: raw['preferNoEmptyTeacherDay'] == true,
      hardDisallowEmptyTeacherDay: raw['hardDisallowEmptyTeacherDay'] == true,
      emptyTeacherDayPenalty: (raw['emptyTeacherDayPenalty'] is num)
          ? (raw['emptyTeacherDayPenalty'] as num).toInt()
          : 120,
      dailyLoadVariancePenalty: (raw['dailyLoadVariancePenalty'] is num)
          ? (raw['dailyLoadVariancePenalty'] as num).toInt()
          : 35,
      enableRebalancing: raw['enableRebalancing'] != false,
      rebalanceIterations: (raw['rebalanceIterations'] is num)
          ? (raw['rebalanceIterations'] as num).toInt()
          : 300,
      targetDailyLoadMode:
          (raw['targetDailyLoadMode'] ?? 'weekly_load_divided_by_school_days')
              .toString(),
      autoFillPriority: ap,
    );
  }
}

enum _V2Mode { strict, flex }

/// Smart Schedule Engine for Manar System
/// 🎯 البرومبت الشامل لمحرك إنشاء الجدول الذكي
class SmartScheduleService {
  final SmartScheduleRepository _repository;
  TimetablePolicies? _cachedPolicies;
  SaudiSubjectPlans? _cachedSaudiPlans;
  bool _treatQuranAsIslamic = false;
  String? _canonicalArabicId;

  SmartScheduleService(this._repository);

  Future<TimetablePolicies?> _loadTimetablePolicies() async {
    if (_cachedPolicies != null) return _cachedPolicies;
    try {
      final text = await rootBundle.loadString(
        'assets/config/timetable_policies.json',
      );
      final decoded = jsonDecode(text);
      final map = decoded is Map ? decoded.cast<String, dynamic>() : null;
      if (map == null) return null;
      _cachedPolicies = TimetablePolicies(map);
      return _cachedPolicies;
    } catch (_) {
      return null;
    }
  }

  Future<SaudiSubjectPlans?> _loadSaudiSubjectPlans() async {
    if (_cachedSaudiPlans != null) return _cachedSaudiPlans;
    try {
      final text = await rootBundle.loadString(
        'assets/config/saudi_subject_plans.json',
      );
      final decoded = jsonDecode(text);
      final map = decoded is Map ? decoded.cast<String, dynamic>() : null;
      if (map == null) return null;
      _cachedSaudiPlans = SaudiSubjectPlans(map);
      return _cachedSaudiPlans;
    } catch (_) {
      return null;
    }
  }

  Map<String, Map<String, int>> _buildClassWeeklyDemandFromSaudiPlans({
    required List<String> classIds,
    required Map<String, int> gradeLevelByClassId,
    required SaudiSubjectPlans plans,
    required Map<String, String> secondaryProgramTypeByClassId,
    required Map<String, String> secondaryTrackByClassId,
    required String? defaultSecondaryProgramType,
    int? activityPeriod,
  }) {
    final demand = <String, Map<String, int>>{
      for (final id in classIds) id: <String, int>{},
    };

    final effectivePeriodsPerDay =
        _periodsPerDay - (activityPeriod != null ? 1 : 0);
    final totalSlotsNeededPerClass = _days.length * effectivePeriodsPerDay;

    for (final classId in classIds) {
      final grade = gradeLevelByClassId[classId] ?? 0;
      if (grade <= 0) continue;
      final classProgram =
          secondaryProgramTypeByClassId[classId] ?? defaultSecondaryProgramType;
      final classTrack = secondaryTrackByClassId[classId];
      final base = plans.weeklyDemandForGrade(
        gradeLevel: grade,
        secondaryProgramType: classProgram,
        secondaryTrack: classTrack,
      );
      if (base.isEmpty) continue;

      final entries = base.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final sum = entries.fold<int>(0, (a, e) => a + e.value);
      if (sum <= 0) continue;

      if (sum == totalSlotsNeededPerClass) {
        demand[classId] = Map<String, int>.from(base);
        continue;
      }

      final floors = <String, int>{};
      final fracs = <String, double>{};
      var used = 0;
      for (final e in entries) {
        final scaled = totalSlotsNeededPerClass * (e.value / sum);
        final floorVal = scaled.floor();
        floors[e.key] = floorVal;
        fracs[e.key] = scaled - floorVal;
        used += floorVal;
      }

      var remainder = totalSlotsNeededPerClass - used;
      final ordered = entries.map((e) => e.key).toList()
        ..sort((a, b) {
          final fa = fracs[a] ?? 0.0;
          final fb = fracs[b] ?? 0.0;
          if (fa != fb) return fb.compareTo(fa);
          return a.compareTo(b);
        });

      var idx = 0;
      while (remainder > 0 && ordered.isNotEmpty) {
        final key = ordered[idx % ordered.length];
        floors[key] = (floors[key] ?? 0) + 1;
        remainder--;
        idx++;
      }

      floors.removeWhere((_, v) => v <= 0);
      demand[classId] = floors;
    }

    return demand;
  }

  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  final int _periodsPerDay = 7;

  Map<String, String> _subjectAliasLookup = <String, String>{};
  Map<String, int> _subjectWeights = <String, int>{};
  Map<String, String> _subjectNameById = <String, String>{};
  Map<String, double> _assignmentWeights = <String, double>{
    'primary': 1.0,
    'additional': 0.6,
    'emergency': 0.3,
  };

  // 📊 Official Quotas based on Rank and Stage
  int _quotaForRankAndStage(String? rank, String? stage) {
    final r = (rank ?? '').toLowerCase();
    final s = (stage ?? '').toLowerCase();

    // Secondary Stage (ثانوية)
    if (s.contains('ثانوي') || s.contains('secondary') || s.contains('high')) {
      if (r == 'assistant' || r == 'teacher' || r == 'معلم') return 18;
      if (r == 'senior1' || r == 'senior_1' || r == 'معلم أول') return 17;
      if (r == 'senior1a' || r == 'senior_1_a' || r == 'معلم أول أ') return 16;
      if (r == 'expert' || r == 'معلم خبير' || r == 'advanced') return 16;
      if (r == 'master' || r == 'كبير معلمين') return 14;
      return 18; // Default
    }

    // Middle Stage (متوسطة)
    if (s.contains('متوسط') || s.contains('middle') || s.contains('prep')) {
      if (r == 'assistant' || r == 'teacher' || r == 'معلم') return 21;
      if (r == 'senior1' || r == 'senior_1' || r == 'معلم أول') return 19;
      if (r == 'senior1a' || r == 'senior_1_a' || r == 'معلم أول أ') return 18;
      if (r == 'expert' || r == 'معلم خبير' || r == 'advanced') return 17;
      if (r == 'master' || r == 'كبير معلمين') return 15;
      return 21; // Default
    }

    // Primary Stage (ابتدائية)
    // Default to Primary if stage is unknown
    if (r == 'assistant' || r == 'teacher' || r == 'معلم') return 24;
    if (r == 'senior1' || r == 'senior_1' || r == 'معلم أول') return 22;
    if (r == 'senior1a' || r == 'senior_1_a' || r == 'معلم أول أ') return 20;
    if (r == 'expert' || r == 'معلم خبير' || r == 'advanced') return 18;
    if (r == 'master' || r == 'كبير معلمين') return 16;
    return 24; // Default
  }

  // Legacy method for backward compatibility if needed, but we should use the one above
  int _quotaForRank(String? rank) {
    return _quotaForRankAndStage(rank, 'primary'); // Fallback
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

  Future<void> _loadSubjectCatalog(String schoolId) async {
    _subjectAliasLookup = <String, String>{};
    _subjectWeights = <String, int>{};
    _subjectNameById = <String, String>{};
    _assignmentWeights = <String, double>{
      'primary': 1.0,
      'additional': 0.6,
      'emergency': 0.3,
    };

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .get();

      final data = doc.data();
      final assignW = data?['assignmentWeights'];
      if (assignW is Map<String, dynamic>) {
        final p = double.tryParse('${assignW['primary'] ?? 1.0}') ?? 1.0;
        final a = double.tryParse('${assignW['additional'] ?? 0.6}') ?? 0.6;
        final e = double.tryParse('${assignW['emergency'] ?? 0.3}') ?? 0.3;
        _assignmentWeights = {'primary': p, 'additional': a, 'emergency': e};
      }
      final subjects = data?['subjects'];
      if (subjects is Map<String, dynamic>) {
        subjects.forEach((id, value) {
          if (id.trim().isEmpty) return;
          _subjectAliasLookup[_normalizeKey(id)] = id;

          if (value is Map<String, dynamic>) {
            final name = (value['name'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              _subjectAliasLookup[_normalizeKey(name)] = id;
              _subjectNameById[id] = name;
            } else {
              _subjectNameById[id] = id;
            }

            final rawWeight = value['weight'];
            final weight = rawWeight is int
                ? rawWeight
                : int.tryParse(rawWeight?.toString() ?? '');
            if (weight != null) {
              _subjectWeights[id] = weight;
            }

            final rawAliases = value['aliases'];
            if (rawAliases is List) {
              for (final a in rawAliases) {
                if (a == null) continue;
                final s = a.toString().trim();
                if (s.isEmpty) continue;
                _subjectAliasLookup[_normalizeKey(s)] = id;
              }
            }
          }
        });
      }
    } catch (_) {}

    String? detectCanonicalId(bool Function(String) matches) {
      String? best;
      for (final e in _subjectAliasLookup.entries) {
        if (!matches(e.key)) continue;
        best = e.value;
        break;
      }
      return best;
    }

    bool isArabicKey(String normalizedKey) =>
        normalizedKey.contains('عربي') ||
        normalizedKey.contains('اللغةالعربية') ||
        normalizedKey.contains('لغتي') ||
        normalizedKey.contains('arabic');

    _canonicalArabicId = detectCanonicalId(isArabicKey);
    if (_canonicalArabicId != null) {
      _subjectAliasLookup[_normalizeKey('Arabic')] = _canonicalArabicId!;
      _subjectAliasLookup[_normalizeKey('اللغة العربية')] = _canonicalArabicId!;
      _subjectAliasLookup[_normalizeKey('لغة عربية')] = _canonicalArabicId!;
      _subjectAliasLookup[_normalizeKey('عربي')] = _canonicalArabicId!;
      _subjectAliasLookup[_normalizeKey('لغتي')] = _canonicalArabicId!;
    }

    if (_subjectWeights.isEmpty) {
      _subjectWeights = <String, int>{
        'Arabic': 6,
        'Math': 5,
        'Science': 4,
        'English': 4,
        'Islamic': 4,
        'Social': 3,
        'PE': 2,
        'Art': 2,
        'Computer': 2,
      };
      for (final id in _subjectWeights.keys) {
        _subjectAliasLookup[_normalizeKey(id)] = id;
        _subjectNameById[id] = id;
      }
    }
  }

  String _normalizeSubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    final resolved = _subjectAliasLookup[_normalizeKey(s)];
    if (resolved != null) return resolved;

    final lower = s.toLowerCase();
    if (lower == 'general' || lower == 'عام') {
      return '';
    }

    if (lower.contains('عربي') || lower.contains('لغتي') || lower == 'arabic') {
      return _canonicalArabicId ?? 'Arabic';
    }
    if (lower.contains('رياضيات')) {
      return 'Math';
    }
    if (lower.contains('علوم')) {
      return 'Science';
    }
    if (lower.contains('اسلام') ||
        lower.contains('إسلام') ||
        lower.contains('تربية اسلامية')) {
      return 'Islamic';
    }
    if (lower.contains('قرآن') ||
        lower.contains('قران') ||
        lower.contains('تحفيظ') ||
        lower.contains('quran')) {
      return _treatQuranAsIslamic ? 'Islamic' : 'Quran';
    }
    if (lower.contains('انجليز') ||
        lower.contains('إنجليز') ||
        lower.contains('english')) {
      return 'English';
    }
    if (lower.contains('اجتماعي') ||
        lower.contains('دراسات اجتماعية') ||
        lower.contains('الاجتماعيات')) {
      return 'Social';
    }
    if (lower.contains('حاسب') ||
        lower.contains('حوسبة') ||
        lower.contains('حاسوب') ||
        lower.contains('كمبيوتر') ||
        lower.contains('تقنية رقمية') ||
        lower == 'cs' ||
        lower.contains('computer')) {
      return 'Computer';
    }
    if (lower.contains('بدنية') ||
        lower.contains('رياضية') ||
        lower.contains('رياضة')) {
      return 'PE';
    }
    if (lower.contains('فنية') || lower.contains('رسم')) {
      return 'Art';
    }

    return s;
  }

  String _teacherPrimarySubject(User t) {
    final raw = (t.primarySubjectId ?? '').toString().trim();
    final fallback = (t.specialization ?? '').toString().trim();
    return _normalizeSubject(raw.isNotEmpty ? raw : fallback);
  }

  bool _isNonTeachingSubject(String subject) {
    final s = subject.trim().toLowerCase();
    if (s.isEmpty) return true;
    if (s.startsWith('منتظر')) return true;
    if (s == 'activity' || s.contains('نشاط')) return true;
    if (s.contains('إشراف') || s.contains('اشراف') || s.contains('supervision'))
      return true;
    return false;
  }

  bool _isTeachingSlot(ScheduleSlot slot) {
    if (slot.className.trim().isEmpty) return false;
    if (slot.className.trim() == 'Standby') return false;
    if (_isNonTeachingSubject(slot.subject)) return false;
    if (slot.subject.trim().startsWith('منتظر')) return false;
    return true;
  }

  static const int _maxSameSubjectPerDayForTeacher = 5;

  bool _canAssignSameSubjectForTeacherDay({
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required String teacherId,
    required String day,
    required String subject,
  }) {
    if (_isNonTeachingSubject(subject)) return true;
    final key = _normalizeSubject(subject);
    final count =
        teacherSchedule[teacherId]
            ?.where(
              (s) =>
                  s.day == day &&
                  !_isNonTeachingSubject(s.subject) &&
                  _normalizeSubject(s.subject) == key,
            )
            .length ??
        0;
    return count < _maxSameSubjectPerDayForTeacher;
  }

  Map<String, dynamic> _rebalanceTeacherQuotas({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teachersBySubject = <String, List<User>>{};

    for (final t in teachers) {
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) {
        teachersBySubject.putIfAbsent(primary, () => []);
        teachersBySubject[primary]!.add(t);
      }

      final assignments = t.subjectAssignments ?? const [];
      for (final a in assignments) {
        final subj = _normalizeSubject(a.subjectId);
        if (subj.isEmpty) continue;
        teachersBySubject.putIfAbsent(subj, () => []);
        if (!teachersBySubject[subj]!.any((x) => x.id == t.id)) {
          teachersBySubject[subj]!.add(t);
        }
      }
    }

    final teachingLoad = <String, int>{};
    final occupancy = <String, Map<String, Map<int, bool>>>{};
    for (final entry in schedule.entries) {
      final tid = entry.key;
      occupancy[tid] = {
        for (final d in _days)
          d: {for (var p = 1; p <= _periodsPerDay; p++) p: false},
      };
      var load = 0;
      for (final s in entry.value) {
        if (s.day.isEmpty) continue;
        if (s.period < 1 || s.period > _periodsPerDay) continue;
        occupancy[tid]?[s.day]?[s.period] = true;
        if (!_isNonTeachingSubject(s.subject)) load++;
      }
      teachingLoad[tid] = load;
    }

    int moved = 0;
    int dropped = 0;
    final overloadedBefore = <String, int>{};

    int loops = 0;
    const maxLoops = 50000;

    while (true) {
      loops++;
      if (loops > maxLoops) break;

      String? worstTeacherId;
      var worstOver = 0;
      for (final entry in teachingLoad.entries) {
        final prof = profilesById[entry.key];
        if (prof == null) continue;
        final over = entry.value - prof.weeklyQuota;
        if (over > worstOver) {
          worstOver = over;
          worstTeacherId = entry.key;
        }
      }
      if (worstTeacherId == null || worstOver <= 0) break;

      overloadedBefore[worstTeacherId] = max(
        overloadedBefore[worstTeacherId] ?? 0,
        worstOver,
      );

      final slots = schedule[worstTeacherId] ?? const <ScheduleSlot>[];
      ScheduleSlot? chosenSlot;
      User? chosenReplacement;
      int? chosenReplacementLoad;

      for (final s in slots) {
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.day.isEmpty) continue;
        if (s.period < 1 || s.period > _periodsPerDay) continue;

        final subjectKey = _normalizeSubject(s.subject);
        final candidates = teachersBySubject[subjectKey] ?? const <User>[];
        if (candidates.isEmpty) continue;

        for (final c in candidates) {
          if (c.id == worstTeacherId) continue;
          final prof = profilesById[c.id];
          if (prof == null) continue;
          if (occupancy[c.id] == null) {
            occupancy[c.id] = {
              for (final d in _days)
                d: {for (var p = 1; p <= _periodsPerDay; p++) p: false},
            };
          }
          if (occupancy[c.id]?[s.day]?[s.period] == true) continue;
          if (prof.blockedTimeSlots.contains('${s.day}:${s.period}')) continue;
          final load = teachingLoad[c.id] ?? 0;
          if (load + 1 > prof.weeklyQuota) continue;
          if (!_canAssignSameSubjectForTeacherDay(
            teacherSchedule: schedule,
            teacherId: c.id,
            day: s.day,
            subject: subjectKey,
          )) {
            continue;
          }

          if (chosenReplacement == null ||
              load < (chosenReplacementLoad ?? 1 << 30)) {
            chosenSlot = s;
            chosenReplacement = c;
            chosenReplacementLoad = load;
          }
        }
      }

      if (chosenSlot != null && chosenReplacement != null) {
        final srcList = schedule[worstTeacherId]!;
        srcList.remove(chosenSlot);

        schedule.putIfAbsent(chosenReplacement.id, () => []);
        schedule[chosenReplacement.id]!.add(
          ScheduleSlot(
            day: chosenSlot.day,
            period: chosenSlot.period,
            className: chosenSlot.className,
            subject: chosenSlot.subject,
            teacherId: chosenReplacement.id,
          ),
        );

        occupancy[worstTeacherId]?[chosenSlot.day]?[chosenSlot.period] = false;
        occupancy[chosenReplacement.id]?[chosenSlot.day]?[chosenSlot.period] =
            true;
        teachingLoad[worstTeacherId] = (teachingLoad[worstTeacherId] ?? 0) - 1;
        teachingLoad[chosenReplacement.id] =
            (teachingLoad[chosenReplacement.id] ?? 0) + 1;
        moved++;
        continue;
      }

      final srcList = schedule[worstTeacherId]!;
      final dropIndex = srcList.indexWhere(
        (s) => !_isNonTeachingSubject(s.subject),
      );
      if (dropIndex == -1) break;
      final droppedSlot = srcList.removeAt(dropIndex);
      if (droppedSlot.day.isNotEmpty &&
          droppedSlot.period >= 1 &&
          droppedSlot.period <= _periodsPerDay) {
        occupancy[worstTeacherId]?[droppedSlot.day]?[droppedSlot.period] =
            false;
      }
      teachingLoad[worstTeacherId] = (teachingLoad[worstTeacherId] ?? 0) - 1;
      dropped++;
    }

    return {
      'movedSlots': moved,
      'droppedSlots': dropped,
      'maxOverloadBeforeByTeacher': overloadedBefore,
      'loops': loops,
    };
  }

  Map<String, dynamic> _buildQuotaComplianceReport({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required School school,
  }) {
    final profileById = {for (final p in profiles) p.teacherId: p};
    final teacherById = {for (final t in teachers) t.id: t};

    final teacherReports = <Map<String, dynamic>>[];
    final violations = <Map<String, dynamic>>[];

    for (final t in teachers) {
      final prof = profileById[t.id];
      final stage = t.stage ?? school.stage;
      final systemQuota = _quotaForRankAndStage(t.teacherRank, stage);
      final quota = prof?.weeklyQuota ?? systemQuota;

      final slots = schedule[t.id] ?? const <ScheduleSlot>[];
      final waitingCount = slots
          .where((s) => s.subject.startsWith('منتظر'))
          .length;
      final teachingCount = slots
          .where((s) => !_isNonTeachingSubject(s.subject))
          .length;
      final total = teachingCount + waitingCount;

      final overQuota = total > quota;
      final waitingWhileTeachingAtQuota =
          teachingCount >= quota && waitingCount > 0;

      final report = <String, dynamic>{
        'teacherId': t.id,
        'teacherName': t.name,
        'stage': stage ?? '',
        'rank': t.teacherRank ?? '',
        'systemQuota': systemQuota,
        'quota': quota,
        'teaching': teachingCount,
        'waiting': waitingCount,
        'total': total,
        'overQuota': overQuota,
        'waitingWhileTeachingAtQuota': waitingWhileTeachingAtQuota,
      };
      teacherReports.add(report);

      if (overQuota || waitingWhileTeachingAtQuota) {
        violations.add(report);
      }
    }

    teacherReports.sort((a, b) {
      final an = (a['teacherName'] ?? '').toString();
      final bn = (b['teacherName'] ?? '').toString();
      return an.compareTo(bn);
    });

    final missingTeachers = schedule.keys
        .where((id) => !teacherById.containsKey(id))
        .where((id) => !id.startsWith('unassigned_'))
        .toList();

    return {
      'isValid': violations.isEmpty && missingTeachers.isEmpty,
      'violationsCount': violations.length,
      'missingTeachersCount': missingTeachers.length,
      'missingTeacherIds': missingTeachers,
      'teachers': teacherReports,
      'violations': violations,
    };
  }

  Map<String, dynamic> _validateStrictSchedule({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required List<String> classIds,
    required int? activityPeriod,
    required _BalancingPolicy balancingPolicy,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teacherById = {for (final t in teachers) t.id: t};

    final violations = <Map<String, dynamic>>[];

    final classSchedule = <String, List<ScheduleSlot>>{
      for (final c in classIds) c: <ScheduleSlot>[],
    };
    for (final entry in schedule.entries) {
      for (final s in entry.value) {
        if (!s.className.startsWith('Class ')) continue;
        if (s.subject.startsWith('منتظر')) continue;
        if (_isNonTeachingSubject(s.subject) && !s.subject.contains('نشاط')) {
          continue;
        }
        final cid = s.className.replaceFirst('Class ', '');
        if (!classSchedule.containsKey(cid)) continue;
        classSchedule[cid]!.add(s);
      }
    }

    for (final classId in classIds) {
      final slots = classSchedule[classId] ?? const <ScheduleSlot>[];
      final byDay = <String, Map<String, int>>{
        for (final d in _days) d: <String, int>{},
      };
      for (final s in slots) {
        if (activityPeriod != null && s.period == activityPeriod) continue;
        final subj = _normalizeSubject(s.subject);
        if (subj.isEmpty) continue;
        final map = byDay[s.day]!;
        map[subj] = (map[subj] ?? 0) + 1;
      }
      for (final d in _days) {
        final map = byDay[d]!;
        for (final e in map.entries) {
          if (e.value > 2) {
            violations.add({
              'type': 'class_subject_overflow',
              'classId': classId,
              'day': d,
              'subject': e.key,
              'count': e.value,
            });
          }
        }
      }
      final expectedPerDay = _periodsPerDay;
      for (final d in _days) {
        final actual = slots
            .where((s) => s.day == d && !s.subject.startsWith('منتظر'))
            .length;
        if (actual != expectedPerDay) {
          violations.add({
            'type': 'class_day_incomplete',
            'classId': classId,
            'day': d,
            'expected': expectedPerDay,
            'actual': actual,
          });
        }
      }
    }

    for (final t in teachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      final slots = schedule[t.id] ?? const <ScheduleSlot>[];
      final teaching = slots
          .where(
            (s) =>
                !_isNonTeachingSubject(s.subject) &&
                !s.subject.startsWith('منتظر'),
          )
          .length;
      final waiting = slots.where((s) => s.subject.startsWith('منتظر')).length;
      final total = teaching + waiting;
      if (total > prof.weeklyQuota) {
        violations.add({
          'type': 'teacher_over_quota',
          'teacherId': t.id,
          'teacherName': t.name,
          'quota': prof.weeklyQuota,
          'teaching': teaching,
          'waiting': waiting,
          'total': total,
        });
      }
      if (teaching >= prof.weeklyQuota && waiting > 0) {
        violations.add({
          'type': 'teacher_waiting_with_closed_teaching',
          'teacherId': t.id,
          'teacherName': t.name,
          'quota': prof.weeklyQuota,
          'teaching': teaching,
          'waiting': waiting,
        });
      }
      final byDay = <String, int>{for (final d in _days) d: 0};
      for (final s in slots) {
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.subject.startsWith('منتظر')) continue;
        byDay[s.day] = (byDay[s.day] ?? 0) + 1;
      }
      final presenceByDay = <String, int>{for (final d in _days) d: 0};
      for (final s in slots) {
        if (s.day.isEmpty) continue;
        if (!presenceByDay.containsKey(s.day)) continue;
        presenceByDay[s.day] = (presenceByDay[s.day] ?? 0) + 1;
      }
      final workingDays = byDay.values.where((v) => v > 0).length;
      final desired = _desiredWorkingDaysForTeacher(prof.weeklyQuota);
      if (prof.weeklyQuota >= 11 &&
          teaching > 0 &&
          workingDays < min(desired, 5)) {
        violations.add({
          'type': 'teacher_working_days_low',
          'teacherId': t.id,
          'teacherName': t.name,
          'quota': prof.weeklyQuota,
          'workingDays': workingDays,
          'desiredDays': desired,
          'byDay': byDay,
        });
      }

      final thuCount = byDay['الخميس'] ?? 0;
      final blockedThu = List<int>.generate(
        _periodsPerDay,
        (i) => i + 1,
      ).every((p) => prof.blockedTimeSlots.contains('الخميس:$p'));
      final allowedThuEmpty =
          prof.weeklyQuota <= 10 ||
          blockedThu ||
          prof.hasAdministrativeDuties ||
          prof.medicalExemption;
      if (prof.weeklyQuota >= 11 &&
          teaching > 0 &&
          thuCount == 0 &&
          !allowedThuEmpty) {
        violations.add({
          'type': 'teacher_thursday_empty',
          'teacherId': t.id,
          'teacherName': t.name,
          'quota': prof.weeklyQuota,
          'byDay': byDay,
          'reason': 'لا يوجد قيد يبرر فراغ الخميس',
        });
      }

      if (!prof.hasAdministrativeDuties && !prof.medicalExemption) {
        for (final d in _days) {
          final blockedDay = List<int>.generate(_periodsPerDay, (i) => i + 1)
              .where((p) => activityPeriod == null || p != activityPeriod)
              .every((p) => prof.blockedTimeSlots.contains('$d:$p'));
          if (blockedDay) continue;
          if ((presenceByDay[d] ?? 0) == 0) {
            violations.add({
              'type': 'teacher_day_empty',
              'teacherId': t.id,
              'teacherName': t.name,
              'day': d,
              'quota': prof.weeklyQuota,
            });
          }
        }
      }
    }

    final waitingCounts = <int>[];
    final dailyTeachingLoads = <int>[];
    for (final t in teachers) {
      final slots = schedule[t.id] ?? const <ScheduleSlot>[];
      waitingCounts.add(
        slots.where((s) => s.subject.startsWith('منتظر')).length,
      );
      final byDay = <String, int>{for (final d in _days) d: 0};
      for (final s in slots) {
        if (!s.className.startsWith('Class ')) continue;
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.subject.startsWith('منتظر')) continue;
        byDay[s.day] = (byDay[s.day] ?? 0) + 1;
      }
      dailyTeachingLoads.addAll(byDay.values);
    }
    final waitingVariance = waitingCounts.isEmpty
        ? 0.0
        : _calculateVariance(waitingCounts);
    final dailyLoadVariance = dailyTeachingLoads.isEmpty
        ? 0.0
        : _calculateVariance(dailyTeachingLoads);

    var score = 100000.0;
    for (final v in violations) {
      final type = (v['type'] ?? '').toString();
      if (type == 'teacher_over_quota' ||
          type == 'teacher_waiting_with_closed_teaching') {
        score -= 100000;
      } else if (type == 'teacher_thursday_empty') {
        score -= 20000;
      } else if (type == 'teacher_day_empty') {
        score -= balancingPolicy.emptyTeacherDayPenalty.toDouble();
      } else if (type == 'class_subject_overflow') {
        score -= 15000;
      } else if (type == 'class_day_incomplete') {
        score -= 50000;
      } else if (type == 'teacher_working_days_low') {
        score -= 10000;
      } else {
        score -= 2000;
      }
    }
    score -= waitingVariance * 200;
    score -= dailyLoadVariance * balancingPolicy.dailyLoadVariancePenalty;

    final hardTypes = <String>{
      'teacher_over_quota',
      'teacher_waiting_with_closed_teaching',
      'class_subject_overflow',
      'class_day_incomplete',
      'teacher_thursday_empty',
    };
    if (balancingPolicy.hardDisallowEmptyTeacherDay) {
      hardTypes.add('teacher_day_empty');
    }
    final hardViolations = violations
        .where((v) => hardTypes.contains((v['type'] ?? '').toString()))
        .toList();

    return {
      'isValid': hardViolations.isEmpty,
      'violations': violations,
      'violationsCount': violations.length,
      'hardViolationsCount': hardViolations.length,
      'strictScore': score,
      'waitingVariance': waitingVariance,
      'dailyLoadVariance': dailyLoadVariance,
      'teacherCount': teachers.length,
      'classCount': classIds.length,
    };
  }

  _BalancingPolicy _balancingPolicyFromConstraints(
    Map<String, dynamic> policyConstraints,
  ) {
    final raw = (policyConstraints['balancingPolicy'] as Map?)
        ?.cast<String, dynamic>();
    final merged = <String, dynamic>{
      'preferNoEmptyTeacherDay': true,
      'hardDisallowEmptyTeacherDay': true,
      'emptyTeacherDayPenalty': 2500,
      'dailyLoadVariancePenalty': 35,
      'enableRebalancing': true,
      'rebalanceIterations': 300,
      'targetDailyLoadMode': 'weekly_load_divided_by_school_days',
      'autoFillPriority': const ['rebalance_real_lessons', 'waiting'],
    };
    if (raw != null) merged.addAll(raw);
    return _BalancingPolicy.fromRaw(merged);
  }

  void _applyBalancingPolicy({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required List<String> classIds,
    required int? activityPeriod,
    required _BalancingPolicy policy,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
    required int maxPerDayPerSubjectForClass,
  }) {
    if (policy.enableRebalancing) {
      _rebalanceTeacherDailyLoads(
        schedule: schedule,
        teachers: teachers,
        profiles: profiles,
        activityPeriod: activityPeriod,
        teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
        treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
        teacherNoSeventh: teacherNoSeventh,
        noSeventhPeriodMode: noSeventhPeriodMode,
        maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
        iterations: policy.rebalanceIterations,
      );
    }

    if (policy.preferNoEmptyTeacherDay) {
      _autoFillTeacherEmptyDays(
        schedule: schedule,
        teachers: teachers,
        profiles: profiles,
        activityPeriod: activityPeriod,
        teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
        treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
        teacherNoSeventh: teacherNoSeventh,
        noSeventhPeriodMode: noSeventhPeriodMode,
        autoFillPriority: policy.autoFillPriority,
      );
    }
  }

  void _injectDailyActivityForClasses({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<String> classIds,
    required int? activityPeriod,
  }) {
    if (activityPeriod == null) return;

    final existing = <String, Map<String, Set<int>>>{};
    for (final entry in schedule.entries) {
      for (final s in entry.value) {
        if (!s.className.startsWith('Class ')) continue;
        final cid = s.className.replaceFirst('Class ', '');
        existing.putIfAbsent(cid, () => <String, Set<int>>{});
        existing[cid]!.putIfAbsent(s.day, () => <int>{}).add(s.period);
      }
    }

    for (final classId in classIds) {
      for (final day in _days) {
        final used = existing[classId]?[day] ?? const <int>{};
        if (used.contains(activityPeriod)) continue;
        final tid = 'activity_${classId}_${day}_$activityPeriod';
        schedule.putIfAbsent(tid, () => <ScheduleSlot>[]);
        schedule[tid]!.add(
          ScheduleSlot(
            day: day,
            period: activityPeriod,
            className: 'Class $classId',
            subject: 'نشاط',
            teacherId: tid,
          ),
        );
      }
    }
  }

  Map<String, Map<String, Map<int, _SlotRef>>> _indexClassSlots(
    Map<String, List<ScheduleSlot>> schedule,
  ) {
    final out = <String, Map<String, Map<int, _SlotRef>>>{};
    for (final entry in schedule.entries) {
      final tid = entry.key;
      final list = entry.value;
      for (int i = 0; i < list.length; i++) {
        final s = list[i];
        if (!s.className.startsWith('Class ')) continue;
        final classId = s.className.replaceFirst('Class ', '');
        out.putIfAbsent(classId, () => <String, Map<int, _SlotRef>>{});
        out[classId]!.putIfAbsent(s.day, () => <int, _SlotRef>{});
        out[classId]![s.day]![s.period] = _SlotRef(
          teacherId: tid,
          index: i,
          slot: s,
        );
      }
    }
    return out;
  }

  Map<String, Map<String, Set<int>>> _indexTeacherBusy(
    Map<String, List<ScheduleSlot>> schedule,
  ) {
    final out = <String, Map<String, Set<int>>>{};
    for (final entry in schedule.entries) {
      final tid = entry.key;
      final byDay = <String, Set<int>>{};
      for (final s in entry.value) {
        byDay.putIfAbsent(s.day, () => <int>{}).add(s.period);
      }
      out[tid] = byDay;
    }
    return out;
  }

  Map<String, Map<String, int>> _teacherDailyTeachingLoad(
    Map<String, List<ScheduleSlot>> schedule,
    List<User> teachers,
  ) {
    final out = <String, Map<String, int>>{};
    for (final t in teachers) {
      final m = <String, int>{for (final d in _days) d: 0};
      final slots = schedule[t.id] ?? const <ScheduleSlot>[];
      for (final s in slots) {
        if (!s.className.startsWith('Class ')) continue;
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.subject.startsWith('منتظر')) continue;
        m[s.day] = (m[s.day] ?? 0) + 1;
      }
      out[t.id] = m;
    }
    return out;
  }

  bool _canPlaceTeacherAt({
    required TeacherConstraintsProfile prof,
    required String teacherId,
    required String day,
    required int period,
    required Map<String, Map<String, Set<int>>> teacherBusy,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
    required int? activityPeriod,
  }) {
    if (activityPeriod != null && period == activityPeriod) return false;
    if (prof.blockedTimeSlots.contains('$day:$period')) return false;
    if ((teacherBusy[teacherId]?[day]?.contains(period) ?? false)) return false;
    if ((teacherNoSeventh[teacherId] ?? false) &&
        noSeventhPeriodMode == 'hard' &&
        period == 7) {
      return false;
    }
    final softBlocked = teacherUnavailablePrefSlots[teacherId];
    if (treatUnavailableSlotsAsHard &&
        softBlocked != null &&
        softBlocked.contains('$day:$period')) {
      return false;
    }
    return true;
  }

  bool _canTeacherWorkAt({
    required TeacherConstraintsProfile prof,
    required String teacherId,
    required String day,
    required int period,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
    required int? activityPeriod,
  }) {
    if (activityPeriod != null && period == activityPeriod) return false;
    if (prof.blockedTimeSlots.contains('$day:$period')) return false;
    if ((teacherNoSeventh[teacherId] ?? false) &&
        noSeventhPeriodMode == 'hard' &&
        period == 7) {
      return false;
    }
    final softBlocked = teacherUnavailablePrefSlots[teacherId];
    if (treatUnavailableSlotsAsHard &&
        softBlocked != null &&
        softBlocked.contains('$day:$period')) {
      return false;
    }
    return true;
  }

  bool _classSubjectCountOkAfterSwap({
    required Map<String, Map<String, Map<int, _SlotRef>>> classIndex,
    required String classId,
    required String dayA,
    required int periodA,
    required String subjectA,
    required String dayB,
    required int periodB,
    required String subjectB,
    required int maxPerDayPerSubjectForClass,
  }) {
    final mapA = classIndex[classId]?[dayA] ?? const <int, _SlotRef>{};
    final mapB = classIndex[classId]?[dayB] ?? const <int, _SlotRef>{};

    int countSubj(Map<int, _SlotRef> m, String subj, int skipPeriod) {
      final key = _normalizeSubject(subj);
      var c = 0;
      for (final e in m.entries) {
        final p = e.key;
        final s = e.value.slot;
        if (p == skipPeriod) continue;
        if (_isNonTeachingSubject(s.subject) || s.subject.startsWith('منتظر')) {
          continue;
        }
        if (_normalizeSubject(s.subject) == key) c++;
      }
      return c;
    }

    final bAfterA = countSubj(mapA, subjectB, periodA) + 1;
    final aAfterB = countSubj(mapB, subjectA, periodB) + 1;

    return bAfterA <= maxPerDayPerSubjectForClass &&
        aAfterB <= maxPerDayPerSubjectForClass;
  }

  bool _teacherSubjectCountOkAfterSwap({
    required Map<String, List<ScheduleSlot>> schedule,
    required String teacherId,
    required String fromDay,
    required String fromSubject,
    required String toDay,
    required String toSubject,
  }) {
    if (_isNonTeachingSubject(toSubject) || toSubject.startsWith('منتظر')) {
      return true;
    }
    final slots = schedule[teacherId] ?? const <ScheduleSlot>[];
    final key = _normalizeSubject(toSubject);
    var count = 0;
    for (final s in slots) {
      if (s.day != toDay) continue;
      if (_isNonTeachingSubject(s.subject) || s.subject.startsWith('منتظر')) {
        continue;
      }
      if (_normalizeSubject(s.subject) == key) count++;
    }
    if (fromDay == toDay && _normalizeSubject(fromSubject) == key) {
      count = max(0, count - 1);
    }
    return count < _maxSameSubjectPerDayForTeacher;
  }

  bool _rebalanceTeacherDailyLoads({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required int? activityPeriod,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
    required int maxPerDayPerSubjectForClass,
    required int iterations,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    var changed = false;

    for (int iter = 0; iter < iterations; iter++) {
      final classIndex = _indexClassSlots(schedule);
      final teacherBusy = _indexTeacherBusy(schedule);
      final teacherLoads = _teacherDailyTeachingLoad(schedule, teachers);

      User? targetTeacher;
      String? targetDay;
      int bestUrgency = -1;

      for (final t in teachers) {
        final prof = profilesById[t.id];
        if (prof == null) continue;
        if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;
        final loads = teacherLoads[t.id] ?? const <String, int>{};
        final empties = loads.entries
            .where((e) => e.value == 0)
            .map((e) => e.key)
            .toList();
        if (empties.isEmpty) continue;
        final urgency = empties.length;
        if (urgency > bestUrgency) {
          bestUrgency = urgency;
          targetTeacher = t;
          targetDay = empties.first;
        }
      }

      if (targetTeacher == null || targetDay == null) break;

      final profT = profilesById[targetTeacher.id]!;
      final loadsT = teacherLoads[targetTeacher.id]!;
      final sourceDay = loadsT.entries.fold<String>(
        _days.first,
        (best, e) => (e.value > (loadsT[best] ?? 0)) ? e.key : best,
      );
      if ((loadsT[sourceDay] ?? 0) <= 1) break;

      final teacherSlots =
          (schedule[targetTeacher.id] ?? const <ScheduleSlot>[])
              .where(
                (s) =>
                    s.className.startsWith('Class ') &&
                    !_isNonTeachingSubject(s.subject) &&
                    !s.subject.startsWith('منتظر') &&
                    s.day == sourceDay,
              )
              .toList();
      if (teacherSlots.isEmpty) break;

      var swapped = false;

      for (final slotA in teacherSlots) {
        final classId = slotA.className.replaceFirst('Class ', '');
        final mapB = classIndex[classId]?[targetDay] ?? const <int, _SlotRef>{};
        final periodsB = mapB.keys.toList()..sort();
        for (final pB in periodsB) {
          final refB = mapB[pB];
          if (refB == null) continue;
          final slotB = refB.slot;
          if (_isNonTeachingSubject(slotB.subject)) continue;
          if (slotB.subject.startsWith('منتظر')) continue;
          if (refB.teacherId.startsWith('unassigned_')) continue;
          if (refB.teacherId == targetTeacher.id) continue;

          final profB = profilesById[refB.teacherId];
          if (profB == null) continue;

          if (!_canPlaceTeacherAt(
            prof: profT,
            teacherId: targetTeacher.id,
            day: targetDay,
            period: pB,
            teacherBusy: teacherBusy,
            teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
            treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
            teacherNoSeventh: teacherNoSeventh,
            noSeventhPeriodMode: noSeventhPeriodMode,
            activityPeriod: activityPeriod,
          ))
            continue;

          if (!_canPlaceTeacherAt(
            prof: profB,
            teacherId: refB.teacherId,
            day: sourceDay,
            period: slotA.period,
            teacherBusy: teacherBusy,
            teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
            treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
            teacherNoSeventh: teacherNoSeventh,
            noSeventhPeriodMode: noSeventhPeriodMode,
            activityPeriod: activityPeriod,
          ))
            continue;

          if (!_teacherSubjectCountOkAfterSwap(
            schedule: schedule,
            teacherId: targetTeacher.id,
            fromDay: sourceDay,
            fromSubject: slotA.subject,
            toDay: targetDay,
            toSubject: slotA.subject,
          ))
            continue;

          if (!_teacherSubjectCountOkAfterSwap(
            schedule: schedule,
            teacherId: refB.teacherId,
            fromDay: targetDay,
            fromSubject: slotB.subject,
            toDay: sourceDay,
            toSubject: slotB.subject,
          ))
            continue;

          if (!_classSubjectCountOkAfterSwap(
            classIndex: classIndex,
            classId: classId,
            dayA: sourceDay,
            periodA: slotA.period,
            subjectA: slotA.subject,
            dayB: targetDay,
            periodB: pB,
            subjectB: slotB.subject,
            maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
          ))
            continue;

          final loadsB = teacherLoads[refB.teacherId] ?? const <String, int>{};
          final profBR = profilesById[refB.teacherId]!;
          if (!(profBR.hasAdministrativeDuties || profBR.medicalExemption)) {
            final bTarget = loadsB[targetDay] ?? 0;
            if (bTarget <= 1) continue;
          }

          final refA = classIndex[classId]?[sourceDay]?[slotA.period];
          if (refA == null) continue;

          schedule[refA.teacherId]![refA.index] = refA.slot.copyWith(
            day: targetDay,
            period: pB,
          );
          schedule[refB.teacherId]![refB.index] = refB.slot.copyWith(
            day: sourceDay,
            period: slotA.period,
          );
          swapped = true;
          changed = true;
          break;
        }
        if (swapped) break;
      }

      if (!swapped) break;
    }

    return changed;
  }

  void _autoFillTeacherEmptyDays({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required int? activityPeriod,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
    required List<String> autoFillPriority,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teacherBusy = _indexTeacherBusy(schedule);

    for (final t in teachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;

      for (final day in _days) {
        final hasAny = (teacherBusy[t.id]?[day]?.isNotEmpty ?? false);
        if (hasAny) continue;

        for (final step in autoFillPriority) {
          if (step == 'rebalance_real_lessons') continue;
          if (step != 'waiting') continue;

          final periods = <int>[
            for (var i = 1; i <= _periodsPerDay; i++)
              if (activityPeriod == null || i != activityPeriod) i,
          ];

          int? picked;
          for (final p in periods) {
            if (!_canPlaceTeacherAt(
              prof: prof,
              teacherId: t.id,
              day: day,
              period: p,
              teacherBusy: teacherBusy,
              teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
              treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
              teacherNoSeventh: teacherNoSeventh,
              noSeventhPeriodMode: noSeventhPeriodMode,
              activityPeriod: activityPeriod,
            ))
              continue;
            picked = p;
            break;
          }
          if (picked == null) continue;

          const subject = 'منتظر';
          const className = 'Standby';

          schedule.putIfAbsent(t.id, () => <ScheduleSlot>[]);
          schedule[t.id]!.add(
            ScheduleSlot(
              day: day,
              period: picked,
              className: className,
              subject: subject,
              teacherId: t.id,
            ),
          );
          teacherBusy.putIfAbsent(t.id, () => <String, Set<int>>{});
          teacherBusy[t.id]!.putIfAbsent(day, () => <int>{}).add(picked);
          break;
        }
      }
    }
  }

  Map<String, dynamic> _enforceTeacherDailyPresence({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required int? activityPeriod,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teacherBusy = _indexTeacherBusy(schedule);

    final allowedSubjectsByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      final set = <String>{};
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) set.add(primary);
      for (final a in t.subjectAssignments ?? const <SubjectAssignment>[]) {
        final id = _normalizeSubject(a.subjectId);
        if (id.isEmpty) continue;
        set.add(id);
      }
      allowedSubjectsByTeacher[t.id] = set;
    }

    final slotsByDay = <String, List<_SlotRef>>{};
    for (final entry in schedule.entries) {
      final teacherId = entry.key;
      for (var i = 0; i < entry.value.length; i++) {
        final slot = entry.value[i];
        if (slot.day.isEmpty) continue;
        if (slot.period < 1 || slot.period > _periodsPerDay) continue;
        slotsByDay.putIfAbsent(slot.day, () => <_SlotRef>[]);
        slotsByDay[slot.day]!.add(
          _SlotRef(teacherId: teacherId, index: i, slot: slot),
        );
      }
    }

    bool hasAnySlotOnDay(String teacherId, String day) {
      final s = schedule[teacherId];
      if (s == null) return false;
      return s.any((x) => x.day == day);
    }

    int teachingCount(String teacherId) {
      final s = schedule[teacherId] ?? const <ScheduleSlot>[];
      var c = 0;
      for (final x in s) {
        if (!_isTeachingSlot(x)) continue;
        c++;
      }
      return c;
    }

    int steals = 0;
    int forcedWaiting = 0;
    final stillEmpty = <Map<String, dynamic>>[];

    for (final t in teachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;

      for (final day in _days) {
        if (hasAnySlotOnDay(t.id, day)) continue;

        final allowed = allowedSubjectsByTeacher[t.id] ?? const <String>{};
        bool moved = false;

        if (allowed.isNotEmpty) {
          final dayRefs = slotsByDay[day] ?? const <_SlotRef>[];
          for (final ref in dayRefs) {
            if (ref.teacherId == t.id) continue;
            final slot = ref.slot;
            if (slot.day != day) continue;
            if (!slot.className.startsWith('Class ')) continue;
            if (_isNonTeachingSubject(slot.subject)) continue;
            if (slot.subject.startsWith('منتظر')) continue;
            final assigned = t.assignedClassIds ?? const <String>[];
            if (assigned.isNotEmpty) {
              final cid = slot.className.substring(6);
              if (!assigned.contains(cid)) continue;
            }
            final subjectKey = _normalizeSubject(slot.subject);
            if (!allowed.contains(subjectKey)) continue;

            final donorProf = profilesById[ref.teacherId];
            if (donorProf == null) continue;
            if (!donorProf.hasAdministrativeDuties &&
                !donorProf.medicalExemption) {
              final donorHasOtherThatDay =
                  (schedule[ref.teacherId] ?? const <ScheduleSlot>[]).any(
                    (x) => x.day == day && x != slot,
                  );
              if (!donorHasOtherThatDay) continue;
            }

            if (!_canPlaceTeacherAt(
              prof: prof,
              teacherId: t.id,
              day: day,
              period: slot.period,
              teacherBusy: teacherBusy,
              teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
              treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
              teacherNoSeventh: teacherNoSeventh,
              noSeventhPeriodMode: noSeventhPeriodMode,
              activityPeriod: activityPeriod,
            )) {
              continue;
            }

            schedule[ref.teacherId]?.remove(slot);
            schedule.putIfAbsent(t.id, () => <ScheduleSlot>[]);
            schedule[t.id]!.add(slot.copyWith(teacherId: t.id));

            teacherBusy.putIfAbsent(t.id, () => <String, Set<int>>{});
            teacherBusy[t.id]!.putIfAbsent(day, () => <int>{}).add(slot.period);
            teacherBusy.putIfAbsent(ref.teacherId, () => <String, Set<int>>{});
            teacherBusy[ref.teacherId]!
                .putIfAbsent(day, () => <int>{})
                .remove(slot.period);

            steals++;
            moved = true;
            break;
          }
        }

        if (moved) continue;

        int? picked;
        for (var p = 1; p <= _periodsPerDay; p++) {
          if (!_canPlaceTeacherAt(
            prof: prof,
            teacherId: t.id,
            day: day,
            period: p,
            teacherBusy: teacherBusy,
            teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
            treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
            teacherNoSeventh: teacherNoSeventh,
            noSeventhPeriodMode: noSeventhPeriodMode,
            activityPeriod: activityPeriod,
          ))
            continue;
          picked = p;
          break;
        }

        if (picked == null) {
          stillEmpty.add({
            'teacherId': t.id,
            'teacherName': t.name,
            'day': day,
          });
          continue;
        }

        schedule.putIfAbsent(t.id, () => <ScheduleSlot>[]);
        schedule[t.id]!.add(
          ScheduleSlot(
            day: day,
            period: picked,
            className: 'Standby',
            subject: 'منتظر',
            teacherId: t.id,
          ),
        );
        teacherBusy.putIfAbsent(t.id, () => <String, Set<int>>{});
        teacherBusy[t.id]!.putIfAbsent(day, () => <int>{}).add(picked);
        forcedWaiting++;
      }
    }

    final zeroTeaching = <Map<String, dynamic>>[];
    for (final t in teachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;
      final primary = _teacherPrimarySubject(t);
      if (primary.isEmpty) continue;
      if (teachingCount(t.id) > 0) continue;
      zeroTeaching.add({
        'teacherId': t.id,
        'teacherName': t.name,
        'primarySubject': primary,
      });
    }

    return {
      'steals': steals,
      'forcedWaiting': forcedWaiting,
      'stillEmpty': stillEmpty,
      'zeroTeaching': zeroTeaching,
    };
  }

  Map<String, dynamic> _ensureEachTeacherHasAtLeastOneTeaching({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required int? activityPeriod,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teacherBusy = _indexTeacherBusy(schedule);

    final allowedSubjectsByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      final set = <String>{};
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) set.add(primary);
      for (final a in t.subjectAssignments ?? const <SubjectAssignment>[]) {
        final id = _normalizeSubject(a.subjectId);
        if (id.isEmpty) continue;
        set.add(id);
      }
      allowedSubjectsByTeacher[t.id] = set;
    }

    int teachingCount(String teacherId) {
      final s = schedule[teacherId] ?? const <ScheduleSlot>[];
      var c = 0;
      for (final x in s) {
        if (!_isTeachingSlot(x)) continue;
        c++;
      }
      return c;
    }

    final teachingSlotsBySubject = <String, List<_SlotRef>>{};
    for (final entry in schedule.entries) {
      final tid = entry.key;
      for (var i = 0; i < entry.value.length; i++) {
        final slot = entry.value[i];
        if (!_isTeachingSlot(slot)) continue;
        final key = _normalizeSubject(slot.subject);
        if (key.isEmpty) continue;
        teachingSlotsBySubject.putIfAbsent(key, () => <_SlotRef>[]);
        teachingSlotsBySubject[key]!.add(
          _SlotRef(teacherId: tid, index: i, slot: slot),
        );
      }
    }

    int moves = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final t in teachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;
      final primary = _teacherPrimarySubject(t);
      if (primary.isEmpty) continue;
      if (teachingCount(t.id) > 0) continue;

      final allowed = allowedSubjectsByTeacher[t.id] ?? const <String>{};
      final orderedSubjects = <String>[
        if (allowed.contains(primary)) primary,
        ...allowed.where((s) => s != primary),
      ];

      bool fixed = false;
      for (final subj in orderedSubjects) {
        final candidates = teachingSlotsBySubject[subj];
        if (candidates == null || candidates.isEmpty) continue;

        for (var idx = 0; idx < candidates.length; idx++) {
          final ref = candidates[idx];
          if (ref.teacherId == t.id) continue;
          final slot = ref.slot;
          if (slot.day.isEmpty) continue;
          if (slot.period < 1 || slot.period > _periodsPerDay) continue;

          final donorList = schedule[ref.teacherId];
          if (donorList == null || donorList.isEmpty) continue;
          final donorIndex = donorList.indexWhere(
            (s) =>
                s.day == slot.day &&
                s.period == slot.period &&
                s.className == slot.className &&
                s.subject == slot.subject &&
                _isTeachingSlot(s),
          );
          if (donorIndex < 0) continue;
          final donorSlot = donorList[donorIndex];
          if (donorSlot.className.startsWith('Class ')) {
            final cid = donorSlot.className.substring(6);
            final assigned = t.assignedClassIds ?? const <String>[];
            if (assigned.isNotEmpty && !assigned.contains(cid)) continue;
          }

          final donorProf = profilesById[ref.teacherId];
          if (donorProf == null) continue;
          if (!donorProf.hasAdministrativeDuties &&
              !donorProf.medicalExemption) {
            final donorHasOtherThatDay = donorList.any(
              (x) => x.day == slot.day && x != slot,
            );
            if (!donorHasOtherThatDay) continue;
          }
          if (teachingCount(ref.teacherId) <= 1) continue;

          schedule.putIfAbsent(t.id, () => <ScheduleSlot>[]);
          final targetList = schedule[t.id]!;
          final targetIndex = targetList.indexWhere(
            (s) => s.day == donorSlot.day && s.period == donorSlot.period,
          );
          if (targetIndex >= 0 && _isTeachingSlot(targetList[targetIndex])) {
            continue;
          }
          final canWork = targetIndex >= 0
              ? _canTeacherWorkAt(
                  prof: prof,
                  teacherId: t.id,
                  day: donorSlot.day,
                  period: donorSlot.period,
                  teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
                  treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
                  teacherNoSeventh: teacherNoSeventh,
                  noSeventhPeriodMode: noSeventhPeriodMode,
                  activityPeriod: activityPeriod,
                )
              : _canPlaceTeacherAt(
                  prof: prof,
                  teacherId: t.id,
                  day: donorSlot.day,
                  period: donorSlot.period,
                  teacherBusy: teacherBusy,
                  teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
                  treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
                  teacherNoSeventh: teacherNoSeventh,
                  noSeventhPeriodMode: noSeventhPeriodMode,
                  activityPeriod: activityPeriod,
                );
          if (!canWork) continue;

          donorList.removeAt(donorIndex);
          if (targetIndex >= 0) {
            targetList[targetIndex] = donorSlot.copyWith(teacherId: t.id);
          } else {
            targetList.add(donorSlot.copyWith(teacherId: t.id));
            teacherBusy.putIfAbsent(t.id, () => <String, Set<int>>{});
            teacherBusy[t.id]!
                .putIfAbsent(donorSlot.day, () => <int>{})
                .add(donorSlot.period);
          }

          teacherBusy.putIfAbsent(ref.teacherId, () => <String, Set<int>>{});
          teacherBusy[ref.teacherId]!
              .putIfAbsent(donorSlot.day, () => <int>{})
              .remove(donorSlot.period);

          candidates.removeAt(idx);
          moves++;
          fixed = true;
          break;
        }
        if (fixed) break;
      }

      if (!fixed) {
        remaining.add({
          'teacherId': t.id,
          'teacherName': t.name,
          'primarySubject': primary,
        });
      }
    }

    return {'moves': moves, 'remaining': remaining};
  }

  Map<String, dynamic> _enforceTeacherAssignedClassesAndQuotas({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<User> teachers,
    required List<TeacherConstraintsProfile> profiles,
    required int? activityPeriod,
    required Map<String, Set<String>> teacherUnavailablePrefSlots,
    required bool treatUnavailableSlotsAsHard,
    required Map<String, bool> teacherNoSeventh,
    required String noSeventhPeriodMode,
  }) {
    final profilesById = {for (final p in profiles) p.teacherId: p};
    final teacherById = {for (final t in teachers) t.id: t};
    final teacherBusy = _indexTeacherBusy(schedule);

    final allowedSubjectsByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      final set = <String>{};
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) set.add(primary);
      for (final a in t.subjectAssignments ?? const <SubjectAssignment>[]) {
        final id = _normalizeSubject(a.subjectId);
        if (id.isEmpty) continue;
        set.add(id);
      }
      allowedSubjectsByTeacher[t.id] = set;
    }

    final teachingLoadByTeacher = <String, int>{};
    schedule.forEach((tid, slots) {
      teachingLoadByTeacher[tid] = slots.where(_isTeachingSlot).length;
    });

    final slotsByClassAndSubject = <String, List<_SlotRef>>{};
    schedule.forEach((tid, slots) {
      for (var i = 0; i < slots.length; i++) {
        final slot = slots[i];
        if (!_isTeachingSlot(slot)) continue;
        if (!slot.className.startsWith('Class ')) continue;
        final classId = slot.className.substring(6);
        final subjectKey = _normalizeSubject(slot.subject);
        if (subjectKey.isEmpty) continue;
        final key = '$classId|$subjectKey';
        slotsByClassAndSubject.putIfAbsent(key, () => <_SlotRef>[]);
        slotsByClassAndSubject[key]!.add(
          _SlotRef(teacherId: tid, index: i, slot: slot),
        );
      }
    });

    int moves = 0;
    final results = <Map<String, dynamic>>[];

    final orderedTeachers = List<User>.from(teachers)
      ..sort((a, b) {
        final qa = profilesById[a.id]?.weeklyQuota ?? 0;
        final qb = profilesById[b.id]?.weeklyQuota ?? 0;
        final la = teachingLoadByTeacher[a.id] ?? 0;
        final lb = teachingLoadByTeacher[b.id] ?? 0;
        final na = max(0, qa - la);
        final nb = max(0, qb - lb);
        if (na != nb) return nb.compareTo(na);
        return a.id.compareTo(b.id);
      });

    for (final t in orderedTeachers) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (prof.hasAdministrativeDuties || prof.medicalExemption) continue;

      final assigned = (t.assignedClassIds ?? const <String>[]).toSet();
      if (assigned.isEmpty) continue;

      final quota = prof.weeklyQuota;
      if (quota <= 0) continue;

      final allowed = allowedSubjectsByTeacher[t.id] ?? const <String>{};
      if (allowed.isEmpty) continue;

      var load = teachingLoadByTeacher[t.id] ?? 0;
      if (load >= quota) continue;

      int localMoves = 0;
      while (load < quota) {
        _SlotRef? bestRef;
        String? bestKey;
        int bestScore = 1 << 30;

        for (final classId in assigned) {
          for (final subj in allowed) {
            final key = '$classId|$subj';
            final list = slotsByClassAndSubject[key];
            if (list == null || list.isEmpty) continue;

            for (final ref in list) {
              if (ref.teacherId == t.id) continue;
              final slot = ref.slot;
              if (!slot.className.startsWith('Class ')) continue;

              final donorId = ref.teacherId;
              final donorProf = profilesById[donorId];
              final donorLoad = teachingLoadByTeacher[donorId] ?? 0;
              if (donorProf != null &&
                  !donorProf.hasAdministrativeDuties &&
                  !donorProf.medicalExemption) {
                if (donorLoad <= 1) continue;
              }

              final donorUser = teacherById[donorId];
              if (donorUser != null) {
                final donorAssigned =
                    (donorUser.assignedClassIds ?? const <String>[]);
                if (donorAssigned.isNotEmpty) {
                  if (donorProf == null) continue;
                  if (!donorProf.hasAdministrativeDuties &&
                      !donorProf.medicalExemption) {
                    final donorQuota = donorProf.weeklyQuota;
                    if (donorLoad <= donorQuota) continue;
                  }
                }
              }

              final targetList = schedule[t.id] ?? const <ScheduleSlot>[];
              final existingIndex = targetList.indexWhere(
                (s) => s.day == slot.day && s.period == slot.period,
              );
              if (existingIndex >= 0 &&
                  _isTeachingSlot(targetList[existingIndex])) {
                continue;
              }

              final canWork = existingIndex >= 0
                  ? _canTeacherWorkAt(
                      prof: prof,
                      teacherId: t.id,
                      day: slot.day,
                      period: slot.period,
                      teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
                      treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
                      teacherNoSeventh: teacherNoSeventh,
                      noSeventhPeriodMode: noSeventhPeriodMode,
                      activityPeriod: activityPeriod,
                    )
                  : _canPlaceTeacherAt(
                      prof: prof,
                      teacherId: t.id,
                      day: slot.day,
                      period: slot.period,
                      teacherBusy: teacherBusy,
                      teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
                      treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
                      teacherNoSeventh: teacherNoSeventh,
                      noSeventhPeriodMode: noSeventhPeriodMode,
                      activityPeriod: activityPeriod,
                    );
              if (!canWork) continue;

              var score = 0;
              if (donorId.startsWith('unassigned_')) score -= 1000;
              if (donorUser == null ||
                  (donorUser.assignedClassIds ?? const <String>[]).isEmpty) {
                score -= 5;
              }
              if (donorProf != null) {
                score -= max(0, donorLoad - donorProf.weeklyQuota);
              }

              if (score < bestScore) {
                bestScore = score;
                bestRef = ref;
                bestKey = key;
                if (bestScore <= -1000) break;
              }
            }
          }
        }

        if (bestRef == null || bestKey == null) break;

        final ref = bestRef;
        final keyUsed = bestKey;

        final donorId = ref.teacherId;
        final donorList = schedule[donorId];
        if (donorList == null) break;

        final donorIndex = donorList.indexWhere(
          (s) =>
              s.day == ref.slot.day &&
              s.period == ref.slot.period &&
              s.className == ref.slot.className &&
              s.subject == ref.slot.subject &&
              _isTeachingSlot(s),
        );
        if (donorIndex < 0) break;
        final donorSlot = donorList[donorIndex];

        schedule.putIfAbsent(t.id, () => <ScheduleSlot>[]);
        final targetList = schedule[t.id]!;
        final existingIndex = targetList.indexWhere(
          (s) => s.day == donorSlot.day && s.period == donorSlot.period,
        );
        if (existingIndex >= 0 && _isTeachingSlot(targetList[existingIndex])) {
          break;
        }

        donorList.removeAt(donorIndex);
        if (existingIndex >= 0) {
          targetList[existingIndex] = donorSlot.copyWith(teacherId: t.id);
        } else {
          targetList.add(donorSlot.copyWith(teacherId: t.id));
          teacherBusy.putIfAbsent(t.id, () => <String, Set<int>>{});
          teacherBusy[t.id]!
              .putIfAbsent(donorSlot.day, () => <int>{})
              .add(donorSlot.period);
        }

        teacherBusy.putIfAbsent(donorId, () => <String, Set<int>>{});
        teacherBusy[donorId]!
            .putIfAbsent(donorSlot.day, () => <int>{})
            .remove(donorSlot.period);

        teachingLoadByTeacher[t.id] = (teachingLoadByTeacher[t.id] ?? 0) + 1;
        load = teachingLoadByTeacher[t.id] ?? load + 1;
        teachingLoadByTeacher[donorId] = max(
          0,
          (teachingLoadByTeacher[donorId] ?? 0) - 1,
        );

        moves++;
        localMoves++;

        final list = slotsByClassAndSubject[keyUsed];
        if (list != null) {
          list.removeWhere(
            (r) =>
                r.slot.day == donorSlot.day &&
                r.slot.period == donorSlot.period &&
                r.slot.className == donorSlot.className &&
                r.slot.subject == donorSlot.subject,
          );
          list.add(
            _SlotRef(
              teacherId: t.id,
              index: max(0, targetList.length - 1),
              slot: donorSlot.copyWith(teacherId: t.id),
            ),
          );
        }
      }

      results.add({
        'teacherId': t.id,
        'teacherName': t.name,
        'quota': quota,
        'before': (teachingLoadByTeacher[t.id] ?? 0) - localMoves,
        'after': teachingLoadByTeacher[t.id] ?? 0,
        'moves': localMoves,
        'assignedClassesCount': assigned.length,
      });
    }

    return {'moves': moves, 'teachers': results};
  }

  bool _isPreferredPeriodForSubject(String subject, int period) {
    final s = _normalizeSubject(subject).toLowerCase();

    if (s == 'math' || s == 'science' || s == 'english' || s == 'arabic') {
      return period >= 1 && period <= 4;
    }

    if (s == 'social' || s == 'islamic' || s == 'quran' || s == 'computer') {
      return period >= 2 && period <= 6;
    }

    return period >= 4 && period <= 7;
  }

  int _computeMaxPerDayForSubject({
    required String subject,
    required int weeklyDemandForClass,
    Map<String, int>? maxPerDayBySubject,
  }) {
    if (maxPerDayBySubject != null && maxPerDayBySubject.containsKey(subject)) {
      return maxPerDayBySubject[subject]!;
    }

    // Dynamic Calculation:
    // If demand is high, we MUST allow more than 1 per day.
    // e.g. 5 days.
    // Demand 5 -> 1/day
    // Demand 6 -> 2/day
    // Demand 10 -> 2/day
    // Demand 24 -> 5/day
    if (weeklyDemandForClass <= 5) return 1;
    return (weeklyDemandForClass / 5).ceil();
  }

  String _subjectLayer(String subject) {
    final key = _normalizeSubject(subject).toLowerCase();
    if (key == 'math' ||
        key == 'science' ||
        key == 'english' ||
        key == 'arabic') {
      return 'A';
    }
    if (key == 'social' || key == 'islamic' || key == 'quran') {
      return 'B';
    }
    return 'C';
  }

  double _periodLayerWeight(String subject, int period) {
    final layer = _subjectLayer(subject);
    if (period == 1) {
      if (layer == 'A') return 1.0;
      if (layer == 'B') return 0.25;
      return 0.01;
    }
    if (period == 2 || period == 3) {
      if (layer == 'A') return 1.0;
      if (layer == 'B') return 0.25;
      return 0.15;
    }
    if (period == 4) {
      if (layer == 'A') return 1.0;
      if (layer == 'B') return 0.35;
      return 0.20;
    }
    if (period == 5 || period == 6) {
      if (layer == 'A') return 0.60;
      return 1.0;
    }
    if (period == 7) {
      if (layer == 'C') return 1.0;
      if (layer == 'B') return 0.35;
      return 0.05;
    }
    return 0.0;
  }

  double _preferredBonus(String subject, int period) {
    final layer = _subjectLayer(subject);
    if (period >= 1 && period <= 3) {
      if (layer == 'A') return 0.2;
      if (layer == 'B') return 0.1;
      return 0.05;
    }
    if (period == 4) {
      if (layer == 'A') return 0.15;
      if (layer == 'B') return 0.1;
      return 0.05;
    }
    if (period == 5 || period == 6) {
      return 0.1;
    }
    if (period == 7) {
      return 0.05;
    }
    return 0.0;
  }

  // 🛠️ Initialize Profiles (Helper)
  Future<List<TeacherConstraintsProfile>> initializeProfiles(
    List<User> teachers, {
    required School school,
    Map<String, TeacherPreferenceEntity>? preferences,
    List<dynamic>? staffAssignments,
    bool treatUnavailableSlotsAsHard = true,
    String noSeventhPeriodMode = 'hard',
  }) async {
    final List<TeacherConstraintsProfile> profiles = [];

    for (var teacher in teachers) {
      final existing = await _repository.getTeacherProfile(teacher.id);
      final pref = preferences?[teacher.id];

      // Check for administrative assignments (Activity Leader, Coordinator, etc.)
      bool hasAdminDuty = false;
      if (staffAssignments != null) {
        hasAdminDuty = staffAssignments.any((a) {
          final title = (a['assignmentTitle'] ?? '').toString();
          final type = (a['assignmentType'] ?? '').toString();
          final userId = (a['assignedUserId'] ?? '').toString();

          if (userId != teacher.id) return false;

          // Key titles as requested: رائد نشاط، منسق برامج، أعمال إدارية
          return title.contains('نشاط') ||
              title.contains('منسق') ||
              title.contains('إداري') ||
              type.contains('deputy') ||
              type.contains('counselor');
        });
      }

      // Convert preference unavailable slots to "Day:Period" format
      final List<String> prefBlocked = [];
      if (pref != null) {
        if (treatUnavailableSlotsAsHard) {
          for (var slot in pref.unavailableSlots) {
            if (slot['dayIndex'] != null && slot['period'] != null) {
              int dayIdx = slot['dayIndex']!;
              if (dayIdx >= 0 && dayIdx < _days.length) {
                prefBlocked.add("${_days[dayIdx]}:${slot['period']}");
              }
            }
          }
        }

        if (pref.noSeventhPeriod && noSeventhPeriodMode == 'hard') {
          for (var d in _days) {
            prefBlocked.add("$d:7");
          }
        }
      }

      if (existing != null) {
        // Updated to use rank AND stage from the school
        final rankMax = _quotaForRankAndStage(
          teacher.teacherRank,
          teacher.stage ?? school.stage,
        );
        final desiredQuotaRaw =
            teacher.maxWeeklyClasses ?? existing.weeklyQuota;
        final desiredQuota = desiredQuotaRaw > rankMax
            ? rankMax
            : desiredQuotaRaw;
        final merged = existing.copyWith(
          weeklyQuota: desiredQuota,
          hasAdministrativeDuties: hasAdminDuty,
          blockedTimeSlots: {
            ...existing.blockedTimeSlots,
            ...prefBlocked,
          }.toList(),
        );
        if (merged.weeklyQuota != existing.weeklyQuota ||
            merged.hasAdministrativeDuties !=
                existing.hasAdministrativeDuties ||
            merged.blockedTimeSlots.length !=
                existing.blockedTimeSlots.length) {
          await _repository.saveTeacherProfile(merged);
        }
        profiles.add(merged);
      } else {
        // Create Default Profile
        final rankMax = _quotaForRankAndStage(
          teacher.teacherRank,
          teacher.stage ?? school.stage,
        );
        final newProfile = TeacherConstraintsProfile(
          teacherId: teacher.id,
          weeklyQuota: (teacher.maxWeeklyClasses ?? rankMax) > rankMax
              ? rankMax
              : (teacher.maxWeeklyClasses ?? rankMax),
          hasAdministrativeDuties: hasAdminDuty,
          blockedTimeSlots: prefBlocked,
        );
        await _repository.saveTeacherProfile(newProfile);
        profiles.add(newProfile);
      }
    }
    return profiles;
  }

  int _waitingSlotsForTeacherCount(int count, String? stage) {
    final s = (stage ?? '').toLowerCase();
    if (s.contains('ابتدائي') || s.contains('primary')) return 1;
    if (count >= 18 && count <= 26) return 2;
    if (count >= 27 && count <= 35) return 3;
    if (count > 35) return 4;
    return 1;
  }

  // 🏁 Main Generation Method
  Future<ScheduleGenerationResult> generateSchedule({
    required List<User> teachers,
    required List<String> classIds,
    required School school,
    List<TeacherConstraintsProfile>? constraints,
    Map<String, List<ScheduleSlot>>? fixedSlots,
    Map<String, TeacherPreferenceEntity>? teacherPreferences,
    List<dynamic>? staffAssignments, // Added assignments list
    int? waitingSlotsPerPeriod,
    String waitingPolicy = 'tiers',
    Map<int, Map<int, int>>? customWaitingRules,
    int? activityPeriod,
    int? seed,
    int maxAttempts = 25,
    bool handleFractionalNeed = true,
    int fractionalBaseQuota = 24,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('🚀 [Elite Schedule] Starting Generation for ${school.name}');

    try {
      await _loadSubjectCatalog(school.id);
      final policies = await _loadTimetablePolicies();
      final stageProfileKey =
          policies?.resolveStageProfileKey(
            schoolEducationProfile: school.schoolEducationProfile,
            fallbackStageArabic: school.stage,
          ) ??
          ((school.stage.contains('ابتد'))
              ? 'primary_only'
              : (school.stage.contains('ثانو')
                    ? 'secondary_only'
                    : 'middle_only'));
      final policyConstraints =
          policies?.mergedConstraintsForStage(stageProfileKey) ??
          const <String, dynamic>{};
      final policySolverSeconds =
          policies?.intValue(policyConstraints, 'maxSolverTimeSeconds', 30) ??
          30;
      final timeBudgetSeconds = min(29, max(8, policySolverSeconds));
      final deadline = DateTime.now().add(Duration(seconds: timeBudgetSeconds));
      final maxBacktrackingSteps =
          policies?.intValue(
            policyConstraints,
            'maxBacktrackingSteps',
            250000,
          ) ??
          250000;
      final maxDailyLessonsPerTeacher =
          policies?.intValue(
            policyConstraints,
            'maxDailyLessonsPerTeacher',
            0,
          ) ??
          0;
      final maxConsecutiveLessonsPerTeacher =
          policies?.intValue(
            policyConstraints,
            'maxConsecutiveLessonsPerTeacher',
            0,
          ) ??
          0;
      final defaultPreventSameSubjectTwicePerDay =
          policies?.boolValue(
            policyConstraints,
            'preventSameSubjectTwicePerDayByDefault',
            true,
          ) ??
          true;
      final preventSameSubjectTwicePerDay =
          policies?.boolValue(
            policyConstraints,
            'preventSameSubjectTwicePerDay',
            defaultPreventSameSubjectTwicePerDay,
          ) ??
          defaultPreventSameSubjectTwicePerDay;
      var preventSameSubjectTwicePerDayEffective =
          preventSameSubjectTwicePerDay;
      var maxPerDayPerSubjectForClass = preventSameSubjectTwicePerDay ? 1 : 2;
      final allowSeventhPeriod =
          policies?.boolValue(policyConstraints, 'allowSeventhPeriod', true) ??
          true;
      final seventhPeriodPenalty = allowSeventhPeriod ? 0.8 : 6.0;
      final allowWaitingAssignments =
          policies?.boolValue(
            policyConstraints,
            'allowWaitingAssignments',
            true,
          ) ??
          true;

      final teacherPrefPolicy =
          (policyConstraints['teacherPreferencePolicy'] as Map?)
              ?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final treatUnavailableSlotsAsHard =
          policies?.boolValue(
            teacherPrefPolicy,
            'treatUnavailableSlotsAsHard',
            true,
          ) ??
          true;
      final unavailableSlotPenalty =
          (teacherPrefPolicy['unavailableSlotPenalty'] as num?)?.toDouble() ??
          12.0;
      final noSeventhPeriodMode =
          (teacherPrefPolicy['noSeventhPeriodMode'] ?? 'hard').toString();
      final noSeventhPeriodPenalty =
          (teacherPrefPolicy['noSeventhPeriodPenalty'] as num?)?.toDouble() ??
          18.0;
      final preferConsecutiveWeight =
          (teacherPrefPolicy['preferConsecutiveWeight'] as num?)?.toDouble() ??
          -0.9;
      final balancingPolicy = _balancingPolicyFromConstraints(
        policyConstraints,
      );

      final effectiveWaitingSlotsPerPeriod = !allowWaitingAssignments
          ? 0
          : (waitingSlotsPerPeriod ??
                _waitingSlotsForTeacherCount(teachers.length, school.stage));

      final teacherUnavailablePrefSlots = <String, Set<String>>{};
      final teacherNoSeventh = <String, bool>{};
      final teacherPreferConsecutive = <String, bool>{};
      if (teacherPreferences != null) {
        for (final e in teacherPreferences.entries) {
          final tid = e.key;
          final pref = e.value;
          final set = <String>{};
          for (final slot in pref.unavailableSlots) {
            final dayIdx = slot['dayIndex'];
            final period = slot['period'];
            if (dayIdx == null || period == null) continue;
            if (dayIdx < 0 || dayIdx >= _days.length) continue;
            set.add('${_days[dayIdx]}:$period');
          }
          if (set.isNotEmpty) teacherUnavailablePrefSlots[tid] = set;
          teacherNoSeventh[tid] = pref.noSeventhPeriod;
          teacherPreferConsecutive[tid] = pref.preferConsecutive;
        }
      }

      // 0. Load Profiles
      final profiles =
          constraints ??
          await initializeProfiles(
            teachers,
            school: school, // Pass school to determine stage
            preferences: teacherPreferences,
            staffAssignments: staffAssignments, // Pass assignments
            treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
            noSeventhPeriodMode: noSeventhPeriodMode,
          );

      final saudiPlans = school.countryCode == 'SA'
          ? await _loadSaudiSubjectPlans()
          : null;

      bool isQuranLike(String raw) {
        final s = raw.toLowerCase();
        return s.contains('quran') ||
            s.contains('قرآن') ||
            s.contains('قران') ||
            s.contains('تحفيظ');
      }

      final hasQuranTeacher = teachers.any((t) {
        if (isQuranLike(t.primarySubjectId ?? '')) return true;
        if (isQuranLike(t.specialization ?? '')) return true;
        for (final a in t.subjectAssignments ?? const <SubjectAssignment>[]) {
          if (isQuranLike(a.subjectId)) return true;
        }
        return false;
      });

      final catalogHasQuran =
          _subjectNameById.containsKey('Quran') ||
          _subjectAliasLookup.values.any((v) => v == 'Quran');

      _treatQuranAsIslamic =
          saudiPlans == null && !hasQuranTeacher && !catalogHasQuran;
      final gradeLevelByClassId = <String, int>{};
      final secondaryProgramTypeByClassId = <String, String>{};
      final secondaryTrackByClassId = <String, String>{};
      if (saudiPlans != null) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('Schools')
              .doc(school.id)
              .collection('Classes')
              .get();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final id = (data['id'] ?? doc.id).toString();
            final grade = data['gradeLevel'];
            final program = (data['secondaryProgramType'] ?? '')
                .toString()
                .trim();
            if (program.isNotEmpty) {
              secondaryProgramTypeByClassId[id] = program;
              secondaryProgramTypeByClassId[doc.id] = program;
            }
            final track = (data['secondaryTrack'] ?? '').toString().trim();
            if (track.isNotEmpty) {
              secondaryTrackByClassId[id] = track;
              secondaryTrackByClassId[doc.id] = track;
            }
            if (grade is int) {
              gradeLevelByClassId[id] = grade;
              gradeLevelByClassId[doc.id] = grade;
            } else if (grade is num) {
              gradeLevelByClassId[id] = grade.toInt();
              gradeLevelByClassId[doc.id] = grade.toInt();
            }
          }
        } catch (_) {}
      }

      final normalizedDemand =
          (saudiPlans != null && gradeLevelByClassId.values.any((g) => g > 0))
          ? _buildClassWeeklyDemandFromSaudiPlans(
              classIds: classIds,
              gradeLevelByClassId: gradeLevelByClassId,
              plans: saudiPlans,
              secondaryProgramTypeByClassId: secondaryProgramTypeByClassId,
              secondaryTrackByClassId: secondaryTrackByClassId,
              defaultSecondaryProgramType: school.secondaryProgramType,
              activityPeriod: activityPeriod,
            )
          : _buildClassWeeklyDemandFromSupply(
              classIds: classIds,
              activityPeriod: activityPeriod,
            );
      final demandSource =
          (saudiPlans != null &&
              normalizedDemand.values.any((m) => m.isNotEmpty))
          ? 'saudi_subject_plans'
          : 'weights';

      final schoolDays = _days.length;
      var requiredMaxPerDay = 1;
      for (final classId in classIds) {
        final map = normalizedDemand[classId] ?? const <String, int>{};
        for (final e in map.entries) {
          final need = e.value;
          if (need <= 0) continue;
          final perDay = (need / schoolDays).ceil();
          if (perDay > requiredMaxPerDay) requiredMaxPerDay = perDay;
        }
      }
      if (requiredMaxPerDay > maxPerDayPerSubjectForClass) {
        maxPerDayPerSubjectForClass = requiredMaxPerDay;
        preventSameSubjectTwicePerDayEffective = false;
      }

      final remainderBySubject = <String, int>{};
      if (handleFractionalNeed) {
        final totalBySubject = <String, int>{};
        for (final classId in classIds) {
          final map = normalizedDemand[classId] ?? const <String, int>{};
          for (final e in map.entries) {
            totalBySubject[e.key] = (totalBySubject[e.key] ?? 0) + e.value;
          }
        }
        if (fractionalBaseQuota > 0) {
          for (final e in totalBySubject.entries) {
            final rem = e.value % fractionalBaseQuota;
            if (rem > 0) remainderBySubject[e.key] = rem;
          }
        }
      }

      final baseSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
      final attempts = maxAttempts < 1 ? 1 : maxAttempts;
      final autoAttempts = min(10, (timeBudgetSeconds / 3).floor() + 2);
      final attemptBudget = min(max(attempts, 2), max(2, autoAttempts));
      Map<String, List<ScheduleSlot>>? bestSchedule;
      Map<String, dynamic>? bestReport;
      int? bestSeed;
      Map<String, dynamic>? lastInvalidQuotaCompliance;
      Map<String, dynamic>? lastInvalidStrictValidation;
      String? lastAttemptError;

      double bestCompletion = -1;
      int bestVacancies = 1 << 30;
      double bestQuality = -1;
      double bestStrictScore = -1e18;

      for (var attempt = 0; attempt < attemptBudget; attempt++) {
        if (DateTime.now().isAfter(deadline)) break;
        final attemptSeed = baseSeed + (attempt * 9973);
        final rng = Random(attemptSeed);
        debugPrint('🎲 Using Seed: $attemptSeed');

        final fractionReport =
            handleFractionalNeed && remainderBySubject.isNotEmpty
            ? <String, dynamic>{
                'coveredByAdditional': <String, int>{},
                'coveredByEmergency': <String, int>{},
                'placementsTotal': 0,
              }
            : null;

        Map<String, List<ScheduleSlot>> schedule;
        Map<String, dynamic> engineReport;
        try {
          // استخدام المحلل القديم المجرب
          debugPrint('🎯 [Elite Schedule] استخدام المحلل V2 - المحاولة ${attempt + 1}');
          
          final strictCap = min(65000, max(12000, maxBacktrackingSteps ~/ 6));
          final strictNodes = min(strictCap, 9000 + (attempt * 2200));
          final coreStrict = await _assignCoreSlotsV2(
            profiles,
            teachers,
            classIds,
            school,
            fixedSlots,
            rng,
            activityPeriod,
            normalizedDemand,
            remainderBySubject: remainderBySubject,
            fractionReport: fractionReport,
            mode: _V2Mode.strict,
            maxNodes: strictNodes,
            deadline: deadline,
            teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
            teacherNoSeventh: teacherNoSeventh,
            teacherPreferConsecutive: teacherPreferConsecutive,
            unavailableSlotPenalty: unavailableSlotPenalty,
            noSeventhPeriodMode: noSeventhPeriodMode,
            noSeventhPeriodPenalty: noSeventhPeriodPenalty,
            preferConsecutiveWeight: preferConsecutiveWeight,
            maxDailyLessonsPerTeacher: maxDailyLessonsPerTeacher > 0
                ? maxDailyLessonsPerTeacher
                : null,
            maxConsecutiveLessonsPerTeacher: maxConsecutiveLessonsPerTeacher > 0
                ? maxConsecutiveLessonsPerTeacher
                : null,
            seventhPeriodPenalty: seventhPeriodPenalty,
            maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
          );
          schedule = coreStrict.schedule;
          engineReport = coreStrict.report;
        } catch (e) {
          lastAttemptError = e.toString();
          try {
            final flexCap = min(110000, max(20000, maxBacktrackingSteps ~/ 3));
            final flexNodes = min(flexCap, 14000 + (attempt * 3200));
            final coreFlex = await _assignCoreSlotsV2(
              profiles,
              teachers,
              classIds,
              school,
              fixedSlots,
              rng,
              activityPeriod,
              normalizedDemand,
              remainderBySubject: remainderBySubject,
              fractionReport: fractionReport,
              mode: _V2Mode.flex,
              maxNodes: flexNodes,
              deadline: deadline,
              teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
              teacherNoSeventh: teacherNoSeventh,
              teacherPreferConsecutive: teacherPreferConsecutive,
              unavailableSlotPenalty: unavailableSlotPenalty,
              noSeventhPeriodMode: noSeventhPeriodMode,
              noSeventhPeriodPenalty: noSeventhPeriodPenalty,
              preferConsecutiveWeight: preferConsecutiveWeight,
              maxDailyLessonsPerTeacher: maxDailyLessonsPerTeacher > 0
                  ? maxDailyLessonsPerTeacher
                  : null,
              maxConsecutiveLessonsPerTeacher:
                  maxConsecutiveLessonsPerTeacher > 0
                  ? maxConsecutiveLessonsPerTeacher
                  : null,
              seventhPeriodPenalty: seventhPeriodPenalty,
              maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
            );
            schedule = coreFlex.schedule;
            engineReport = coreFlex.report;
          } catch (e2) {
            lastAttemptError = e2.toString();
            continue;
          }
        }

        _applyBalancingPolicy(
          schedule: schedule,
          teachers: teachers,
          profiles: profiles,
          classIds: classIds,
          activityPeriod: activityPeriod,
          policy: balancingPolicy,
          teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
          treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
          teacherNoSeventh: teacherNoSeventh,
          noSeventhPeriodMode: noSeventhPeriodMode,
          maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
        );

        engineReport['stageProfile'] = stageProfileKey;
        engineReport['demandSource'] = demandSource;
        engineReport['maxSolverTimeSeconds'] = timeBudgetSeconds;
        engineReport['maxBacktrackingSteps'] = maxBacktrackingSteps;
        engineReport['maxDailyLessonsPerTeacher'] = maxDailyLessonsPerTeacher;
        engineReport['maxConsecutiveLessonsPerTeacher'] =
            maxConsecutiveLessonsPerTeacher;
        engineReport['preventSameSubjectTwicePerDay'] =
            preventSameSubjectTwicePerDayEffective;
        engineReport['allowSeventhPeriod'] = allowSeventhPeriod;
        engineReport['treatUnavailableSlotsAsHard'] =
            treatUnavailableSlotsAsHard;
        engineReport['unavailableSlotPenalty'] = unavailableSlotPenalty;
        engineReport['noSeventhPeriodMode'] = noSeventhPeriodMode;
        engineReport['noSeventhPeriodPenalty'] = noSeventhPeriodPenalty;
        engineReport['preferConsecutiveWeight'] = preferConsecutiveWeight;
        engineReport['balancingPolicy'] = {
          'preferNoEmptyTeacherDay': balancingPolicy.preferNoEmptyTeacherDay,
          'hardDisallowEmptyTeacherDay':
              balancingPolicy.hardDisallowEmptyTeacherDay,
          'emptyTeacherDayPenalty': balancingPolicy.emptyTeacherDayPenalty,
          'dailyLoadVariancePenalty': balancingPolicy.dailyLoadVariancePenalty,
          'enableRebalancing': balancingPolicy.enableRebalancing,
          'rebalanceIterations': balancingPolicy.rebalanceIterations,
          'targetDailyLoadMode': balancingPolicy.targetDailyLoadMode,
          'autoFillPriority': balancingPolicy.autoFillPriority,
        };

        final updatedProfiles = profiles.map((p) {
          final slots = schedule[p.teacherId] ?? const [];
          final load = slots
              .where((s) => !_isNonTeachingSubject(s.subject))
              .length;
          return p.copyWith(currentLoad: load);
        }).toList();

        final updatedCategories = _categorizeTeachers(updatedProfiles);

        Map<String, dynamic> waitingOptimization;
        if (effectiveWaitingSlotsPerPeriod <= 0) {
          waitingOptimization = {
            'attemptsTried': 0,
            'moves': 0,
            'swaps': 0,
            'relaxedConstraints': <String>[],
            'uncoveredSlots': <Map<String, dynamic>>[],
          };
        } else {
          try {
            waitingOptimization = _assignWaitingSlots(
              schedule,
              updatedProfiles,
              updatedCategories,
              waitingSlotsPerPeriod: effectiveWaitingSlotsPerPeriod,
              policy: waitingPolicy,
              customRules: customWaitingRules,
              teacherPreferences: teacherPreferences,
            );
          } catch (e) {
            lastAttemptError = e.toString();
            continue;
          }
        }

        final presenceFix = _enforceTeacherDailyPresence(
          schedule: schedule,
          teachers: teachers,
          profiles: updatedProfiles,
          activityPeriod: activityPeriod,
          teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
          treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
          teacherNoSeventh: teacherNoSeventh,
          noSeventhPeriodMode: noSeventhPeriodMode,
        );
        final stillEmpty =
            (presenceFix['stillEmpty'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        if (stillEmpty.isNotEmpty) {
          final sample = stillEmpty
              .take(3)
              .map((e) {
                final name = (e['teacherName'] ?? e['teacherId']).toString();
                final day = (e['day'] ?? '').toString();
                return '$name/$day';
              })
              .join(', ');
          lastAttemptError =
              'presence_fix_failed: stillEmpty=${stillEmpty.length} sample=$sample';
          continue;
        }
        final zeroTeaching =
            (presenceFix['zeroTeaching'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        if (zeroTeaching.isNotEmpty) {
          final fix = _ensureEachTeacherHasAtLeastOneTeaching(
            schedule: schedule,
            teachers: teachers,
            profiles: updatedProfiles,
            activityPeriod: activityPeriod,
            teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
            treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
            teacherNoSeventh: teacherNoSeventh,
            noSeventhPeriodMode: noSeventhPeriodMode,
          );
          final remaining =
              (fix['remaining'] as List?)?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];
          if (remaining.isNotEmpty) {
            engineReport['warnings'] = {
              ...(engineReport['warnings'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{},
              'zeroTeachingTeachers': remaining,
            };
          }
        }

        final assignmentQuotaFix = _enforceTeacherAssignedClassesAndQuotas(
          schedule: schedule,
          teachers: teachers,
          profiles: updatedProfiles,
          activityPeriod: activityPeriod,
          teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
          treatUnavailableSlotsAsHard: treatUnavailableSlotsAsHard,
          teacherNoSeventh: teacherNoSeventh,
          noSeventhPeriodMode: noSeventhPeriodMode,
        );
        engineReport['assignmentQuotaFix'] = assignmentQuotaFix;

        final enforcedProfiles = updatedProfiles.map((p) {
          final slots = schedule[p.teacherId] ?? const [];
          final load = slots
              .where((s) => !_isNonTeachingSubject(s.subject))
              .length;
          return p.copyWith(currentLoad: load);
        }).toList();

        final quotaCompliance = _buildQuotaComplianceReport(
          schedule: schedule,
          teachers: teachers,
          profiles: enforcedProfiles,
          school: school,
        );
        if (quotaCompliance['isValid'] != true) {
          lastInvalidQuotaCompliance = quotaCompliance;
          continue;
        }

        final strictValidation = _validateStrictSchedule(
          schedule: schedule,
          teachers: teachers,
          profiles: enforcedProfiles,
          classIds: classIds,
          activityPeriod: activityPeriod,
          balancingPolicy: balancingPolicy,
        );
        final mode = (engineReport['mode'] ?? 'strict').toString();
        if (mode == 'strict' && strictValidation['isValid'] != true) {
          lastInvalidStrictValidation = strictValidation;
          continue;
        }

        final fairnessReport = evaluateFairness(
          schedule,
          enforcedProfiles,
          teacherPreferences: teacherPreferences,
          totalTeachers: teachers.length,
          waitingSlotsPerPeriod: effectiveWaitingSlotsPerPeriod,
        );
        fairnessReport['waitingOptimization'] = waitingOptimization;
        fairnessReport['quotaCompliance'] = quotaCompliance;
        fairnessReport['strictValidation'] = strictValidation;
        fairnessReport['engineV2'] = engineReport;

        final qualityReport = _calculateQualityMetrics(
          schedule,
          normalizedDemand,
          classIds,
          _periodsPerDay - (activityPeriod != null ? 1 : 0),
        );

        fairnessReport.addAll(qualityReport);
        if (fractionReport != null) {
          final coveredAdditional =
              (fractionReport['coveredByAdditional'] as Map?)
                  ?.cast<String, int>() ??
              <String, int>{};
          final coveredEmergency =
              (fractionReport['coveredByEmergency'] as Map?)
                  ?.cast<String, int>() ??
              <String, int>{};

          final subjects = <Map<String, dynamic>>[];
          for (final entry in remainderBySubject.entries) {
            final subjectId = entry.key;
            final remainder = entry.value;
            final a = coveredAdditional[subjectId] ?? 0;
            final e = coveredEmergency[subjectId] ?? 0;
            final used = a + e;
            final method = used == 0
                ? 'إعادة توزيع'
                : (e > 0 ? 'إضافي ثم طارئ' : 'إسناد إضافي');
            subjects.add({
              'subjectId': subjectId,
              'subjectName': _subjectNameById[subjectId] ?? subjectId,
              'remainder': remainder,
              'coveredAdditional': a,
              'coveredEmergency': e,
              'method': method,
            });
          }

          final placementsTotal =
              (fractionReport['placementsTotal'] as int?) ??
              (coveredAdditional.values.fold<int>(0, (a, b) => a + b) +
                  coveredEmergency.values.fold<int>(0, (a, b) => a + b));

          fairnessReport['fractionHandling'] = {
            'baseQuota': fractionalBaseQuota,
            'assignmentWeights': _assignmentWeights,
            'subjects': subjects,
            'placementsTotal': placementsTotal,
            'expectedVacancyReduction': placementsTotal,
            'vacanciesAfter': fairnessReport['totalVacancies'],
            'qualityAfter': fairnessReport['qualityScore'],
            'qualityLabelAfter': fairnessReport['qualityLabel'],
          };
        }
        fairnessReport['seedUsed'] = attemptSeed;
        fairnessReport['attemptIndex'] = attempt;
        fairnessReport['attemptsTotal'] = attemptBudget;

        final completion =
            (fairnessReport['completionRate'] as num?)?.toDouble() ?? 0;
        final vacancies =
            (fairnessReport['totalVacancies'] as num?)?.toInt() ?? (1 << 29);
        final quality =
            (fairnessReport['qualityScore'] as num?)?.toDouble() ?? completion;
        final strictScore =
            (strictValidation['strictScore'] as num?)?.toDouble() ?? -1e18;

        final isBetter =
            strictScore > bestStrictScore ||
            (strictScore == bestStrictScore && completion > bestCompletion) ||
            (strictScore == bestStrictScore &&
                completion == bestCompletion &&
                vacancies < bestVacancies) ||
            (strictScore == bestStrictScore &&
                completion == bestCompletion &&
                vacancies == bestVacancies &&
                quality > bestQuality);

        if (isBetter) {
          bestSchedule = schedule;
          bestReport = Map<String, dynamic>.from(fairnessReport);
          bestSeed = attemptSeed;
          bestCompletion = completion;
          bestVacancies = vacancies;
          bestQuality = quality;
          bestStrictScore = strictScore;
        }

        if (bestVacancies == 0 &&
            bestCompletion >= 100 &&
            attempt >= attempts) {
          break;
        }
      }

      debugPrint('⚖️ [Elite Schedule] Fairness & Quality Report Generated');
      stopwatch.stop();

      if (bestSchedule == null) {
        final v = (lastInvalidQuotaCompliance?['violationsCount'] ?? 0)
            .toString();
        final s = (lastInvalidStrictValidation?['violationsCount'] ?? 0)
            .toString();
        final last = (lastAttemptError ?? '').trim();
        throw ScheduleGenerationImpossibleException(
          const [],
          'فشل إنشاء جدول صالح: مخالفات النصاب: $v | مخالفات الجودة الصارمة: $s${last.isEmpty ? '' : ' | آخر خطأ: $last'}',
        );
      }

      return ScheduleGenerationResult(bestSchedule ?? {}, {
        'duration': stopwatch.elapsedMilliseconds,
        'seedUsed': bestSeed ?? baseSeed,
        'attemptsTotal': attemptBudget,
      }, fairnessReport: bestReport);
    } catch (e, stack) {
      debugPrint('❌ [Elite Schedule] Generation Failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Map<String, dynamic> calculateQualityMetricsForSchedule({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<String> classIds,
    int? activityPeriod,
  }) {
    final periodsPerDay = _periodsPerDay - (activityPeriod != null ? 1 : 0);
    final dummyDemand = <String, Map<String, int>>{
      for (final id in classIds) id: <String, int>{},
    };
    return _calculateQualityMetrics(
      schedule,
      dummyDemand,
      classIds,
      periodsPerDay,
    );
  }

  Map<String, dynamic> _calculateQualityMetrics(
    Map<String, List<ScheduleSlot>> schedule,
    Map<String, Map<String, int>> normalizedDemand,
    List<String> classIds,
    int periodsPerDay,
  ) {
    int totalSlotsNeeded = classIds.length * _days.length * periodsPerDay;
    int totalSlotsFilled = 0;

    // Count filled slots (excluding 'Activity' if handled separately, but usually slots are in schedule)
    // We iterate through classIds to be precise
    final Map<String, int> vacanciesPerClass = {};
    int repeatedSameSubjectSameDay = 0;
    double periodVarietyScoreSum = 0;
    int periodVarietyCount = 0;

    // Reconstruct class schedule for analysis
    final Map<String, List<ScheduleSlot>> classSchedules = {};
    schedule.values.expand((l) => l).forEach((slot) {
      if (slot.className.startsWith('Class ')) {
        final cid = slot.className.replaceFirst('Class ', '');
        classSchedules.putIfAbsent(cid, () => []).add(slot);
      }
    });

    for (final classId in classIds) {
      final slots = classSchedules[classId] ?? [];
      // Filter out waiting or non-academic if necessary, but usually we want to count valid academic slots
      final validSlots = slots
          .where((s) => !s.subject.startsWith('منتظر'))
          .length;
      totalSlotsFilled += validSlots;

      int expected = _days.length * periodsPerDay;
      if (validSlots < expected) {
        vacanciesPerClass[classId] = expected - validSlots;
      }

      final byDay = <String, List<ScheduleSlot>>{};
      for (final s in slots) {
        if (s.subject.startsWith('منتظر')) continue;
        byDay.putIfAbsent(s.day, () => []).add(s);
      }
      for (final day in byDay.keys) {
        final list = byDay[day]!;
        final counts = <String, int>{};
        for (final s in list) {
          final key = _normalizeSubject(s.subject);
          if (key.isEmpty) continue;
          counts[key] = (counts[key] ?? 0) + 1;
        }
        repeatedSameSubjectSameDay += counts.values
            .where((c) => c > 1)
            .fold(0, (a, b) => a + (b - 1));
      }

      final subjectPeriods = <String, Set<int>>{};
      final subjectCounts = <String, int>{};
      for (final s in slots) {
        if (s.subject.startsWith('منتظر')) continue;
        final key = _normalizeSubject(s.subject);
        if (key.isEmpty) continue;
        subjectPeriods.putIfAbsent(key, () => <int>{}).add(s.period);
        subjectCounts[key] = (subjectCounts[key] ?? 0) + 1;
      }
      for (final entry in subjectCounts.entries) {
        final periods = subjectPeriods[entry.key] ?? <int>{};
        final unique = periods.length;
        final total = entry.value;
        if (total <= 0) continue;
        periodVarietyScoreSum += unique / total;
        periodVarietyCount++;
      }
    }

    double completionRate = totalSlotsNeeded > 0
        ? (totalSlotsFilled / totalSlotsNeeded) * 100
        : 100;

    final totalVacancies = totalSlotsNeeded - totalSlotsFilled;
    final vacancyPenalty = totalVacancies > 0
        ? min(30.0, totalVacancies / 2)
        : 0.0;
    final repetitionPenalty = min(15.0, repeatedSameSubjectSameDay * 1.5);
    final varietyScore = periodVarietyCount > 0
        ? (periodVarietyScoreSum / periodVarietyCount) * 100
        : 100.0;
    final varietyPenalty = max(0.0, 100.0 - varietyScore) * 0.1;

    final teacherIds = schedule.keys
        .where((id) => !id.startsWith('unassigned_'))
        .where((id) => !id.startsWith('activity_'))
        .toList();
    final dailyLoads = <int>[];
    var emptyTeacherDays = 0;
    for (final tid in teacherIds) {
      final byDay = <String, int>{for (final d in _days) d: 0};
      var hasTeaching = false;
      for (final s in schedule[tid] ?? const <ScheduleSlot>[]) {
        if (!s.className.startsWith('Class ')) continue;
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.subject.startsWith('منتظر')) continue;
        hasTeaching = true;
        byDay[s.day] = (byDay[s.day] ?? 0) + 1;
      }
      if (!hasTeaching) continue;
      for (final v in byDay.values) {
        dailyLoads.add(v);
        if (v == 0) emptyTeacherDays++;
      }
    }
    final dailyLoadVariance = dailyLoads.isEmpty
        ? 0.0
        : _calculateVariance(dailyLoads);
    final emptyDayPenalty = min(20.0, emptyTeacherDays * 0.6);
    final dailyVariancePenalty = min(15.0, dailyLoadVariance * 0.9);

    double qualityScore =
        completionRate -
        vacancyPenalty -
        repetitionPenalty -
        varietyPenalty -
        emptyDayPenalty -
        dailyVariancePenalty;
    qualityScore = qualityScore.clamp(0, 100);

    String qualityLabel;
    if (qualityScore >= 92) {
      qualityLabel = 'ممتاز';
    } else if (qualityScore >= 80) {
      qualityLabel = 'جيد';
    } else {
      qualityLabel = 'يحتاج تحسين';
    }

    return {
      'completionRate': completionRate,
      'totalVacancies': totalVacancies,
      'vacanciesPerClass': vacanciesPerClass,
      'repeatedSameSubjectSameDay': repeatedSameSubjectSameDay,
      'periodVarietyScore': varietyScore,
      'emptyTeacherDays': emptyTeacherDays,
      'dailyLoadVariance': dailyLoadVariance,
      'qualityScore': qualityScore,
      'qualityLabel': qualityLabel,
    };
  }

  // ... [analyzeScheduleHealth unchanged] ...
  // 🏥 Health Analysis & Burnout Detection
  List<Map<String, dynamic>> analyzeScheduleHealth(
    Map<String, List<ScheduleSlot>> schedule,
  ) {
    final List<Map<String, dynamic>> alerts = [];

    schedule.forEach((teacherId, slots) {
      // Group by Day
      final Map<String, List<int>> dayPeriods = {};
      for (var s in slots) {
        if (!dayPeriods.containsKey(s.day)) dayPeriods[s.day] = [];
        dayPeriods[s.day]!.add(s.period);
      }

      // Check Consecutive Classes
      dayPeriods.forEach((day, periods) {
        periods.sort();
        int consecutive = 0;
        int maxConsecutive = 0;
        int lastPeriod = -1;

        for (var p in periods) {
          if (p == lastPeriod + 1) {
            consecutive++;
          } else {
            consecutive = 1;
          }
          if (consecutive > maxConsecutive) maxConsecutive = consecutive;
          lastPeriod = p;
        }

        // Rule: > 4 consecutive is a risk. > 5 is critical.
        if (maxConsecutive >= 5) {
          alerts.add({
            'teacherId': teacherId,
            'issue': 'High Consecutive Load ($maxConsecutive classes)',
            'day': day,
            'severity': maxConsecutive >= 6 ? 'Critical' : 'High',
            'suggestion':
                'Consider moving a class from Period $lastPeriod to another day.',
          });
        }
      });
    });

    return alerts;
  }

  // 📝 Record manual overrides for learning and audit
  Future<void> recordOverride(OverrideLearningLog log) async {
    await _repository.logOverride(log);
  }

  // 🎯 Phase 1: Teacher Categorization
  Map<String, List<TeacherConstraintsProfile>> _categorizeTeachers(
    List<TeacherConstraintsProfile> profiles,
  ) {
    final categories = {
      'A': <TeacherConstraintsProfile>[], // Fully Eligible for Waiting
      'B': <TeacherConstraintsProfile>[], // Partially Eligible
      'C': <TeacherConstraintsProfile>[], // Exempt
    };

    for (var p in profiles) {
      bool isExempt =
          p.medicalExemption ||
          p.mobilityConstraint ||
          (p.specialEducationRole != SpecialEducationRole.none &&
              p.schedulingPriorityLevel == SchedulingPriorityLevel.critical);

      if (isExempt) {
        categories['C']!.add(p);
      } else if (p.hasAdministrativeDuties) {
        categories['B']!.add(p);
      } else if (!p.eligibilityForWaiting || p.currentLoad >= 24) {
        // Note: Changed from 20 to 24 to match standard policy "fill to 24"
        categories['B']!.add(p);
      } else {
        categories['A']!.add(p);
      }
    }
    return categories;
  }

  // ⚙️ Phase 2: Core Slot Assignment
  Future<Map<String, List<ScheduleSlot>>> _assignCoreSlots(
    List<TeacherConstraintsProfile> profiles,
    List<User> teachers,
    List<String> classIds,
    School school,
    Map<String, List<ScheduleSlot>>? fixedSlots,
    Random rng,
    int? activityPeriod,
    Map<String, Map<String, int>> normalizedDemand, { // Added argument
    Map<String, int>? remainderBySubject,
    Map<String, dynamic>? fractionReport,
  }) async {
    final teacherSchedule = <String, List<ScheduleSlot>>{};
    for (final p in profiles) {
      teacherSchedule[p.teacherId] = [];
    }

    final shuffledClassIds = List<String>.from(classIds)..shuffle(rng);

    final classSchedule = <String, List<ScheduleSlot>>{};
    for (final classId in shuffledClassIds) {
      classSchedule[classId] = [];
    }

    final teacherOccupancy = <String, Map<String, Map<int, bool>>>{};
    for (final p in profiles) {
      teacherOccupancy[p.teacherId] = {};
      for (final day in _days) {
        teacherOccupancy[p.teacherId]![day] = {};
        for (int period = 1; period <= _periodsPerDay; period++) {
          teacherOccupancy[p.teacherId]![day]![period] = false;
        }
      }
    }

    final classOccupancy = <String, Map<String, Map<int, bool>>>{};
    for (final classId in shuffledClassIds) {
      classOccupancy[classId] = {};
      for (final day in _days) {
        classOccupancy[classId]![day] = {};
        for (int period = 1; period <= _periodsPerDay; period++) {
          classOccupancy[classId]![day]![period] = false;
        }
      }
    }

    final classSubjectPerWeek = <String, Map<String, int>>{};
    final classSubjectPerDay = <String, Map<String, Map<String, int>>>{};
    final classDayLoad = <String, Map<String, int>>{};
    for (final classId in shuffledClassIds) {
      classSubjectPerWeek[classId] = {};
      classSubjectPerDay[classId] = {};
      classDayLoad[classId] = {};
      for (final day in _days) {
        classSubjectPerDay[classId]![day] = {};
        classDayLoad[classId]![day] = 0;
      }
    }

    // Use pre-calculated demand from generateSchedule if passed, but here we recalculate or use passed.
    // However, _assignCoreSlots is called inside generateSchedule where we already calculated normalizedDemand.
    // To avoid changing signature too much, let's just use the passed normalizedDemand if we update signature,
    // OR we just remove this redundant calculation if we pass it.
    // For now, let's keep it but ideally we should pass it.
    // Actually, to fix the compilation error in generateSchedule, we moved calculation up.
    // But _assignCoreSlots also calculates it locally. Let's make _assignCoreSlots ACCEPT it as argument.

    // We need to update _assignCoreSlots signature first.
    // Since I cannot update signature easily in one go without breaking call,
    // I will let _assignCoreSlots calculate it AGAIN internally (it's cheap) or update signature.
    // Let's update signature.

    // Wait, the previous tool call failed to find the string because I might have targeted the wrong lines.
    // Let's just fix the call in generateSchedule to pass it, and update definition.

    // Step 1: Update generateSchedule call

    if (activityPeriod != null) {
      for (final classId in shuffledClassIds) {
        for (final day in _days) {
          classOccupancy[classId]![day]![activityPeriod] = true;
          classSchedule[classId]!.add(
            ScheduleSlot(
              day: day,
              period: activityPeriod,
              className: 'Class $classId',
              subject: 'Activity',
              teacherId: '',
            ),
          );
          classDayLoad[classId]![day] = (classDayLoad[classId]![day] ?? 0) + 1;
        }
      }
    }

    if (fixedSlots != null) {
      for (final entry in fixedSlots.entries) {
        final teacherId = entry.key;
        final slots = entry.value;
        final profile = profiles.firstWhere((p) => p.teacherId == teacherId);

        for (final slot in slots) {
          if (profile.blockedTimeSlots.contains('${slot.day}:${slot.period}')) {
            throw Exception(
              'تعارض في الجدول المثبت: المعلم ${profile.teacherId} لديه وقت محظور في ${slot.day} الحصة ${slot.period}.',
            );
          }
          if (!slot.className.startsWith('Class ')) {
            if (!_canAssignSameSubjectForTeacherDay(
              teacherSchedule: teacherSchedule,
              teacherId: teacherId,
              day: slot.day,
              subject: slot.subject,
            )) {
              throw Exception(
                'تعارض نصاب المادة: لا يمكن إسناد أكثر من $_maxSameSubjectPerDayForTeacher حصص لنفس المادة في يوم واحد للمعلم $teacherId.',
              );
            }
            teacherSchedule[teacherId]!.add(slot);
            teacherOccupancy[teacherId]![slot.day]![slot.period] = true;
            continue;
          }

          final clsId = slot.className.replaceFirst('Class ', '');
          if (!classIds.contains(clsId)) {
            if (!_canAssignSameSubjectForTeacherDay(
              teacherSchedule: teacherSchedule,
              teacherId: teacherId,
              day: slot.day,
              subject: slot.subject,
            )) {
              throw Exception(
                'تعارض نصاب المادة: لا يمكن إسناد أكثر من $_maxSameSubjectPerDayForTeacher حصص لنفس المادة في يوم واحد للمعلم $teacherId.',
              );
            }
            teacherSchedule[teacherId]!.add(slot);
            teacherOccupancy[teacherId]![slot.day]![slot.period] = true;
            continue;
          }

          if (classOccupancy[clsId]![slot.day]![slot.period] == true) {
            throw Exception(
              'تعارض في الجدول المثبت: الفصل $clsId لديه حصة مزدوجة في ${slot.day} الحصة ${slot.period}.',
            );
          }

          final subjectKey = _normalizeSubject(
            slot.subject.isEmpty
                ? (teachers
                          .firstWhere(
                            (t) => t.id == teacherId,
                            orElse: () => User(
                              id: 'unknown',
                              name: 'Unknown',
                              role: UserRole.teacher,
                              email: '',
                              schoolId: '',
                            ),
                          )
                          .primarySubjectId ??
                      teachers
                          .firstWhere(
                            (t) => t.id == teacherId,
                            orElse: () => User(
                              id: 'unknown',
                              name: 'Unknown',
                              role: UserRole.teacher,
                              email: '',
                              schoolId: '',
                            ),
                          )
                          .specialization ??
                      '')
                : slot.subject,
          );

          if (!_canAssignSameSubjectForTeacherDay(
            teacherSchedule: teacherSchedule,
            teacherId: teacherId,
            day: slot.day,
            subject: subjectKey,
          )) {
            throw Exception(
              'تعارض نصاب المادة: لا يمكن إسناد أكثر من $_maxSameSubjectPerDayForTeacher حصص لنفس المادة في يوم واحد للمعلم $teacherId.',
            );
          }

          teacherSchedule[teacherId]!.add(
            ScheduleSlot(
              day: slot.day,
              period: slot.period,
              className: 'Class $clsId',
              subject: subjectKey,
              teacherId: teacherId,
            ),
          );
          classSchedule[clsId]!.add(
            ScheduleSlot(
              day: slot.day,
              period: slot.period,
              className: 'Class $clsId',
              subject: subjectKey,
              teacherId: teacherId,
            ),
          );
          teacherOccupancy[teacherId]![slot.day]![slot.period] = true;
          classOccupancy[clsId]![slot.day]![slot.period] = true;

          classSubjectPerWeek[clsId]![subjectKey] =
              (classSubjectPerWeek[clsId]![subjectKey] ?? 0) + 1;
          final dayMap = classSubjectPerDay[clsId]![slot.day]!;
          dayMap[subjectKey] = (dayMap[subjectKey] ?? 0) + 1;
          classDayLoad[clsId]![slot.day] =
              (classDayLoad[clsId]![slot.day] ?? 0) + 1;
        }
      }
    }

    final classRemainingDemand = <String, Map<String, int>>{};
    normalizedDemand.forEach((classId, subjectMap) {
      final rem = <String, int>{};
      subjectMap.forEach((subject, demand) {
        final already = classSubjectPerWeek[classId]?[subject] ?? 0;
        final remaining = demand - already;
        rem[subject] = remaining > 0 ? remaining : 0;
      });
      classRemainingDemand[classId] = rem;
    });

    final teachersBySubject = <String, List<User>>{};
    final teacherTierBySubject = <String, Map<String, int>>{};
    for (final t in teachers) {
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) {
        teachersBySubject.putIfAbsent(primary, () => []);
        teacherTierBySubject.putIfAbsent(primary, () => {});
        teachersBySubject[primary]!.add(t);
        teacherTierBySubject[primary]![t.id] = 0;
      }

      for (final a in t.subjectAssignments ?? const []) {
        final sid = _normalizeSubject(a.subjectId);
        if (sid.isEmpty) continue;
        teachersBySubject.putIfAbsent(sid, () => []);
        teacherTierBySubject.putIfAbsent(sid, () => {});
        final tier = a.type == SubjectAssignmentType.primary
            ? 0
            : (a.type == SubjectAssignmentType.additional ? 1 : 2);
        final existingTier = teacherTierBySubject[sid]![t.id];
        if (existingTier == null || tier < existingTier) {
          teacherTierBySubject[sid]![t.id] = tier;
        }
        if (!teachersBySubject[sid]!.any((x) => x.id == t.id)) {
          teachersBySubject[sid]!.add(t);
        }
      }
    }
    for (final entry in teachersBySubject.entries) {
      entry.value.shuffle(rng);
    }

    final profileByTeacherId = {for (final p in profiles) p.teacherId: p};
    final coveredByAdditional =
        (fractionReport?['coveredByAdditional'] as Map?)?.cast<String, int>() ??
        <String, int>{};
    final coveredByEmergency =
        (fractionReport?['coveredByEmergency'] as Map?)?.cast<String, int>() ??
        <String, int>{};
    if (fractionReport != null) {
      fractionReport['coveredByAdditional'] = coveredByAdditional;
      fractionReport['coveredByEmergency'] = coveredByEmergency;
      fractionReport['placementsTotal'] =
          fractionReport['placementsTotal'] ?? 0;
    }

    int teachingLoadOf(String teacherId) {
      final slots = teacherSchedule[teacherId] ?? const <ScheduleSlot>[];
      return slots.where((s) => !_isNonTeachingSubject(s.subject)).length;
    }

    int remainingFractionBudget(String subject) {
      if (remainderBySubject == null) return 0;
      final rem = remainderBySubject[subject] ?? 0;
      final used =
          (coveredByAdditional[subject] ?? 0) +
          (coveredByEmergency[subject] ?? 0);
      final left = rem - used;
      return left > 0 ? left : 0;
    }

    User? pickFractionTeacher({
      required String subject,
      required String day,
      required int period,
      required int tier,
    }) {
      if (fractionReport == null) return null;
      if (remainingFractionBudget(subject) <= 0) return null;

      final layer = _subjectLayer(subject);
      final candidates = <User>[];
      for (final t in teachers) {
        final prof = profileByTeacherId[t.id];
        if (prof == null) continue;
        if (teacherOccupancy[t.id]?[day]?[period] == true) continue;
        if (prof.blockedTimeSlots.contains('$day:$period')) continue;
        final load = teachingLoadOf(t.id);
        if (load >= prof.weeklyQuota) continue;
        if (!_canAssignSameSubjectForTeacherDay(
          teacherSchedule: teacherSchedule,
          teacherId: t.id,
          day: day,
          subject: subject,
        )) {
          continue;
        }
        candidates.add(t);
      }
      if (candidates.isEmpty) return null;

      candidates.shuffle(rng);
      candidates.sort((a, b) {
        final pa = _normalizeSubject(
          a.primarySubjectId ?? a.specialization ?? '',
        );
        final pb = _normalizeSubject(
          b.primarySubjectId ?? b.specialization ?? '',
        );
        final la = _subjectLayer(pa);
        final lb = _subjectLayer(pb);
        final wa = la == layer ? 0 : 1;
        final wb = lb == layer ? 0 : 1;
        if (wa != wb) return wa.compareTo(wb);
        final ca = teachingLoadOf(a.id);
        final cb = teachingLoadOf(b.id);
        if (ca != cb) return ca.compareTo(cb);
        return a.id.compareTo(b.id);
      });

      final chosen = candidates.first;
      teachersBySubject.putIfAbsent(subject, () => []);
      teacherTierBySubject.putIfAbsent(subject, () => {});
      final existingTier = teacherTierBySubject[subject]![chosen.id];
      if (existingTier == null || tier < existingTier) {
        teacherTierBySubject[subject]![chosen.id] = tier;
      }
      if (!teachersBySubject[subject]!.any((x) => x.id == chosen.id)) {
        teachersBySubject[subject]!.add(chosen);
      }

      if (tier == 2) {
        coveredByEmergency[subject] = (coveredByEmergency[subject] ?? 0) + 1;
      } else {
        coveredByAdditional[subject] = (coveredByAdditional[subject] ?? 0) + 1;
      }
      final v = (fractionReport['placementsTotal'] as int?) ?? 0;
      fractionReport['placementsTotal'] = v + 1;

      return chosen;
    }

    // Safety Counter to prevent infinite loops
    int loopSafetyCounter = 0;
    const int maxLoops = 10000;

    while (true) {
      loopSafetyCounter++;
      if (loopSafetyCounter > maxLoops) {
        debugPrint(
          '⚠️ [Elite Schedule] Infinite loop detected in main distribution. Breaking.',
        );
        break;
      }

      // Yield to event loop periodically to prevent UI freeze
      if (loopSafetyCounter % 50 == 0) {
        await Future.delayed(Duration.zero);
      }

      final target = _pickMostDemandingClassSubjectBalanced(
        classRemainingDemand: classRemainingDemand,
        classSchedule: classSchedule,
        rng: rng,
      );
      if (target == null) break;

      final classId = target['classId'] as String;
      final subject = target['subject'] as String;
      var remaining = target['remaining'] as int;

      final weeklyDemandForClass = normalizedDemand[classId]?[subject] ?? 0;
      final maxPerDayForSubject = _computeMaxPerDayForSubject(
        subject: subject,
        weeklyDemandForClass: weeklyDemandForClass,
      );

      var placedSomething = false;

      final dayOrder = List<String>.from(_days);
      dayOrder.sort((a, b) {
        final la = classDayLoad[classId]?[a] ?? 0;
        final lb = classDayLoad[classId]?[b] ?? 0;
        if (la != lb) return la.compareTo(lb);
        return a.compareTo(b);
      });

      for (final day in dayOrder) {
        final basePeriods = List<int>.generate(
          _periodsPerDay,
          (index) => index + 1,
        );
        final periodOffset =
            (classId.hashCode * 31 + subject.hashCode * 7 + day.hashCode) %
            _periodsPerDay;

        final rotatedPeriods = <int>[];
        for (var i = 0; i < _periodsPerDay; i++) {
          rotatedPeriods.add(basePeriods[(i + periodOffset) % _periodsPerDay]);
        }

        rotatedPeriods.sort((a, b) {
          final weightA = _periodLayerWeight(subject, a);
          final weightB = _periodLayerWeight(subject, b);
          double bonusA = 0.0;
          double bonusB = 0.0;
          if (_isPreferredPeriodForSubject(subject, a)) {
            bonusA = _preferredBonus(subject, a);
          }
          if (_isPreferredPeriodForSubject(subject, b)) {
            bonusB = _preferredBonus(subject, b);
          }

          // Positional Variety Penalty
          // Check if this subject was assigned to this period in previous days for this class
          double penaltyA = 0.0;
          double penaltyB = 0.0;

          for (final prevDay in _days) {
            if (prevDay == day) continue;
            if (classOccupancy[classId]?[prevDay]?[a] == true) {
              // Check if it was THIS subject
              final slot = classSchedule[classId]?.firstWhere(
                (s) => s.day == prevDay && s.period == a,
                orElse: () => ScheduleSlot(
                  day: '',
                  period: -1,
                  className: '',
                  subject: '',
                  teacherId: '',
                ),
              );
              if (slot != null &&
                  slot.period != -1 &&
                  slot.subject == subject) {
                penaltyA += 0.5; // Significant penalty for same period
              }
            }
            if (classOccupancy[classId]?[prevDay]?[b] == true) {
              final slot = classSchedule[classId]?.firstWhere(
                (s) => s.day == prevDay && s.period == b,
                orElse: () => ScheduleSlot(
                  day: '',
                  period: -1,
                  className: '',
                  subject: '',
                  teacherId: '',
                ),
              );
              if (slot != null &&
                  slot.period != -1 &&
                  slot.subject == subject) {
                penaltyB += 0.5;
              }
            }
          }

          final scoreA = weightA + bonusA - penaltyA;
          final scoreB = weightB + bonusB - penaltyB;

          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          final ia = rotatedPeriods.indexOf(a);
          final ib = rotatedPeriods.indexOf(b);
          return ia.compareTo(ib);
        });

        for (final period in rotatedPeriods) {
          if (remaining <= 0) break;

          final assignedWeek = classSubjectPerWeek[classId]?[subject] ?? 0;
          if (assignedWeek >= weeklyDemandForClass) {
            remaining = 0;
            break;
          }

          if (classOccupancy[classId]![day]![period] == true) {
            continue;
          }

          final dayMap = classSubjectPerDay[classId]![day]!;
          final currentDayCount = dayMap[subject] ?? 0;
          if (currentDayCount >= maxPerDayForSubject) {
            continue;
          }
          if (currentDayCount > 0) {
            final assignedWeek = classSubjectPerWeek[classId]?[subject] ?? 0;
            final remainingWeekly = max(0, weeklyDemandForClass - assignedWeek);
            var remainingAvailableDays = 0;
            for (final d in _days) {
              var hasFree = false;
              for (var p = 1; p <= _periodsPerDay; p++) {
                if (classOccupancy[classId]?[d]?[p] == false) {
                  hasFree = true;
                  break;
                }
              }
              if (hasFree) remainingAvailableDays++;
            }
            final canSpread =
                remainingWeekly <= remainingAvailableDays * maxPerDayForSubject;
            if (canSpread) {
              continue;
            }
          }

          // Try to find a teacher normally
          var teacher = _pickBestTeacherForSlot(
            subject: subject,
            day: day,
            period: period,
            teachers: teachersBySubject[subject] ?? const [],
            teacherSchedule: teacherSchedule,
            teacherOccupancy: teacherOccupancy,
            profiles: {for (final p in profiles) p.teacherId: p},
            tierByTeacherId: teacherTierBySubject[subject],
          );

          // Smart Swapping Logic: If no teacher available, try to swap
          if (teacher == null) {
            final potentialTeachers = List<User>.from(
              teachersBySubject[subject] ?? const [],
            );
            potentialTeachers.sort((a, b) {
              final ta = teacherTierBySubject[subject]?[a.id] ?? 0;
              final tb = teacherTierBySubject[subject]?[b.id] ?? 0;
              return ta.compareTo(tb);
            });
            for (final t in potentialTeachers) {
              // Check if teacher is busy at this slot
              if (teacherOccupancy[t.id]?[day]?[period] == true) {
                // Find what they are teaching
                final conflictSlot = teacherSchedule[t.id]!.firstWhere(
                  (s) => s.day == day && s.period == period,
                  orElse: () => ScheduleSlot(
                    day: '',
                    period: -1,
                    className: '',
                    subject: '',
                    teacherId: '',
                  ),
                );

                if (conflictSlot.period == -1)
                  continue; // Should not happen if occupancy is true

                // Try to move conflictSlot to another period
                final conflictClassId = conflictSlot.className.replaceFirst(
                  'Class ',
                  '',
                );

                // Find a free slot for (conflictClassId, t)
                for (final altPeriod in rotatedPeriods) {
                  if (altPeriod == period) continue;
                  if (classOccupancy[conflictClassId]?[day]?[altPeriod] ==
                          false &&
                      teacherOccupancy[t.id]?[day]?[altPeriod] == false) {
                    if (!_canAssignSameSubjectForTeacherDay(
                      teacherSchedule: teacherSchedule,
                      teacherId: t.id,
                      day: day,
                      subject: subject,
                    )) {
                      continue;
                    }
                    // Perform Swap!
                    // 1. Remove old slot from teacher and class schedules
                    teacherSchedule[t.id]!.removeWhere(
                      (s) => s == conflictSlot,
                    );
                    classSchedule[conflictClassId]!.removeWhere(
                      (s) => s == conflictSlot,
                    );

                    // 2. Add new moved slot
                    final newSlot = ScheduleSlot(
                      day: day,
                      period: altPeriod,
                      className: conflictSlot.className,
                      subject: conflictSlot.subject,
                      teacherId: t.id,
                    );
                    teacherSchedule[t.id]!.add(newSlot);
                    classSchedule[conflictClassId]!.add(newSlot);

                    // Update Occupancy
                    teacherOccupancy[t.id]![day]![period] = false;
                    teacherOccupancy[t.id]![day]![altPeriod] = true;

                    classOccupancy[conflictClassId]![day]![period] = false;
                    classOccupancy[conflictClassId]![day]![altPeriod] = true;

                    // Now the teacher is free at 'period'!
                    teacher = t;
                    break;
                  }
                }
                if (teacher != null) break;
              }
            }
          }

          if (teacher == null) {
            teacher = pickFractionTeacher(
              subject: subject,
              day: day,
              period: period,
              tier: 1,
            );
            teacher ??= pickFractionTeacher(
              subject: subject,
              day: day,
              period: period,
              tier: 2,
            );
          }

          // Ultimate Fallback: Assign a placeholder teacher if absolutely no one is available
          // This ensures the Subject appears in the schedule even if unassigned.
          if (teacher == null) {
            // Create a fake teacher for this slot
            teacher = User(
              id: 'unassigned_${subject}_${day}_$period', // Unique ID to avoid conflicts
              name: 'لم يحدد', // "Not Assigned"
              role: UserRole.teacher,
              email: '',
              schoolId: '',
              specialization: subject,
            );
            // We don't add this fake user to 'teacherSchedule' map because it's not a real teacher
            // But we add the slot to 'classSchedule' so it shows up.

            final slot = ScheduleSlot(
              day: day,
              period: period,
              className: 'Class $classId',
              subject: subject,
              teacherId: teacher.id,
            );

            // Only add to class schedule
            classSchedule[classId]!.add(slot);
            classOccupancy[classId]![day]![period] = true;

            classSubjectPerWeek[classId]![subject] = assignedWeek + 1;
            dayMap[subject] = currentDayCount + 1;
            classDayLoad[classId]![day] =
                (classDayLoad[classId]![day] ?? 0) + 1;

            classRemainingDemand[classId]![subject] = remaining - 1;
            remaining--;
            placedSomething = true;
            continue; // Skip the standard assignment logic below
          }

          if (teacher == null) {
            continue;
          }

          final teacherId = teacher.id;
          final currentTeachingLoad =
              teacherSchedule[teacherId]
                  ?.where((s) => !_isNonTeachingSubject(s.subject))
                  .length ??
              0;
          final profile = profiles.firstWhere(
            (p) => p.teacherId == teacherId,
            orElse: () => TeacherConstraintsProfile(
              teacherId: teacherId,
              weeklyQuota: 0,
              blockedTimeSlots: const [],
            ),
          );
          if (profile.weeklyQuota > 0 &&
              currentTeachingLoad >= profile.weeklyQuota) {
            continue;
          }
          if (!_canAssignSameSubjectForTeacherDay(
            teacherSchedule: teacherSchedule,
            teacherId: teacherId,
            day: day,
            subject: subject,
          )) {
            continue;
          }

          final slot = ScheduleSlot(
            day: day,
            period: period,
            className: 'Class $classId',
            subject: subject,
            teacherId: teacherId,
          );

          teacherSchedule[teacherId]!.add(slot);
          classSchedule[classId]!.add(slot);
          teacherOccupancy[teacherId]![day]![period] = true;
          classOccupancy[classId]![day]![period] = true;

          classSubjectPerWeek[classId]![subject] = assignedWeek + 1;
          dayMap[subject] = currentDayCount + 1;
          classDayLoad[classId]![day] = (classDayLoad[classId]![day] ?? 0) + 1;

          classRemainingDemand[classId]![subject] = remaining - 1;
          remaining--;
          placedSomething = true;
        }
        if (remaining <= 0) break;
      }

      if (!placedSomething) {
        classRemainingDemand[classId]?[subject] = 0;
        bool hasAnyRemaining = false;
        classRemainingDemand.forEach((cid, subjectMap) {
          subjectMap.forEach((subj, rem) {
            if (rem > 0) {
              hasAnyRemaining = true;
            }
          });
        });
        if (!hasAnyRemaining) {
          break;
        }
        continue;
      }
    }

    final profilesById = {for (final p in profiles) p.teacherId: p};

    _fillRemainingClassSlotsWithCoreSubjects(
      classIds: shuffledClassIds,
      classSchedule: classSchedule,
      teacherSchedule: teacherSchedule,
      classOccupancy: classOccupancy,
      teacherOccupancy: teacherOccupancy,
      classSubjectPerWeek: classSubjectPerWeek,
      classSubjectPerDay: classSubjectPerDay,
      classDayLoad: classDayLoad,
      normalizedDemand: normalizedDemand,
      teachersBySubject: teachersBySubject,
      teacherTierBySubject: teacherTierBySubject,
      profilesById: profilesById,
    );

    // Phase 2.5: Auto-Optimization (Gap Filling)
    // Try to fill any remaining gaps by moving conflicting slots
    _optimizeScheduleGaps(
      classIds: shuffledClassIds,
      classSchedule: classSchedule,
      teacherSchedule: teacherSchedule,
      classOccupancy: classOccupancy,
      teacherOccupancy: teacherOccupancy,
      classSubjectPerWeek: classSubjectPerWeek,
      classSubjectPerDay: classSubjectPerDay,
      classDayLoad: classDayLoad,
      normalizedDemand: normalizedDemand,
      teachersBySubject: teachersBySubject,
      teacherTierBySubject: teacherTierBySubject,
      profilesById: profilesById,
    );

    return teacherSchedule;
  }

  int _desiredWorkingDaysForTeacher(int weeklyQuota) {
    if (weeklyQuota >= 20) return 5;
    if (weeklyQuota >= 16) return 4;
    if (weeklyQuota >= 11) return 4;
    if (weeklyQuota >= 7) return 3;
    if (weeklyQuota >= 4) return 2;
    return 1;
  }

  Map<String, Map<String, int>> _buildClassDayPlanStrict({
    required Map<String, int> weeklyDemand,
    required Map<String, int> dayTargets,
    required Random rng,
  }) {
    final byDay = <String, Map<String, int>>{
      for (final d in _days) d: <String, int>{},
    };
    final dayLoad = <String, int>{for (final d in _days) d: 0};

    final subjects = weeklyDemand.entries
        .where((e) => e.value > 0)
        .map((e) => MapEntry(_normalizeSubject(e.key), e.value))
        .where((e) => e.key.trim().isNotEmpty)
        .toList();
    subjects.sort((a, b) => a.key.compareTo(b.key));

    final totalDemand = subjects.fold<int>(0, (a, b) => a + b.value);
    final totalTarget = _days.fold<int>(0, (a, d) => a + (dayTargets[d] ?? 0));
    if (totalDemand != totalTarget) {
      throw Exception(
        'خطة التوزيع غير ممكنة: إجمالي الاحتياج $totalDemand لا يطابق السعة $totalTarget.',
      );
    }

    for (final entry in subjects) {
      final subject = entry.key;
      var remaining = entry.value;
      if (remaining > _days.length * 2) {
        throw Exception(
          'خطة التوزيع غير ممكنة: المادة $subject عددها $remaining أكبر من الحد (مرتين يوميًا).',
        );
      }
      final perDay = <String, int>{for (final d in _days) d: 0};

      final base = min(remaining, _days.length);
      final days = List<String>.from(_days);
      days.shuffle(rng);
      days.sort((a, b) {
        final ca = ((dayTargets[a] ?? 0) - (dayLoad[a] ?? 0));
        final cb = ((dayTargets[b] ?? 0) - (dayLoad[b] ?? 0));
        if (ca != cb) return cb.compareTo(ca);
        final la = dayLoad[a] ?? 0;
        final lb = dayLoad[b] ?? 0;
        if (la != lb) return la.compareTo(lb);
        return a.compareTo(b);
      });
      var basePlaced = 0;
      for (final d in days) {
        if (basePlaced >= base) break;
        if ((dayTargets[d] ?? 0) <= (dayLoad[d] ?? 0)) continue;
        perDay[d] = 1;
        dayLoad[d] = (dayLoad[d] ?? 0) + 1;
        basePlaced++;
      }
      remaining -= basePlaced;

      while (remaining > 0) {
        final candidates = List<String>.from(_days);
        candidates.shuffle(rng);
        candidates.sort((a, b) {
          final ca = perDay[a] ?? 0;
          final cb = perDay[b] ?? 0;
          if (ca != cb) return ca.compareTo(cb);
          final ra = ((dayTargets[a] ?? 0) - (dayLoad[a] ?? 0));
          final rb = ((dayTargets[b] ?? 0) - (dayLoad[b] ?? 0));
          if (ra != rb) return rb.compareTo(ra);
          final la = dayLoad[a] ?? 0;
          final lb = dayLoad[b] ?? 0;
          if (la != lb) return la.compareTo(lb);
          return a.compareTo(b);
        });

        String? chosen;
        for (final d in candidates) {
          if ((perDay[d] ?? 0) >= 2) continue;
          if ((dayTargets[d] ?? 0) <= (dayLoad[d] ?? 0)) continue;
          chosen = d;
          break;
        }
        if (chosen == null) {
          throw Exception(
            'خطة التوزيع غير ممكنة: لا توجد سعة متبقية لتوزيع المادة $subject.',
          );
        }
        perDay[chosen] = (perDay[chosen] ?? 0) + 1;
        dayLoad[chosen] = (dayLoad[chosen] ?? 0) + 1;
        remaining--;
      }

      for (final d in _days) {
        final c = perDay[d] ?? 0;
        if (c <= 0) continue;
        byDay[d]![subject] = (byDay[d]![subject] ?? 0) + c;
      }
    }

    for (final d in _days) {
      final target = dayTargets[d] ?? 0;
      final total = byDay[d]!.values.fold<int>(0, (a, b) => a + b);
      if (total != target) {
        throw Exception(
          'خطة التوزيع غير ممكنة: يوم $d للفصل لديه $total من أصل $target.',
        );
      }
    }

    return byDay;
  }

  User? _pickTeacherForSlotStrict({
    required String subject,
    required String day,
    required int period,
    required List<User> candidates,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required Map<String, Map<String, Map<int, bool>>> teacherOccupancy,
    required Map<String, int> teachingLoadByTeacher,
    required Map<String, Map<String, int>> teachingByTeacherByDay,
  }) {
    User? best;
    int? bestScore;
    final subjectKey = _normalizeSubject(subject);

    for (final t in candidates) {
      final prof = profilesById[t.id];
      if (prof == null) continue;
      if (teacherOccupancy[t.id]?[day]?[period] == true) continue;
      if (prof.blockedTimeSlots.contains('$day:$period')) continue;
      final load = teachingLoadByTeacher[t.id] ?? 0;
      if (load >= prof.weeklyQuota) continue;
      if (!_canAssignSameSubjectForTeacherDay(
        teacherSchedule: teacherSchedule,
        teacherId: t.id,
        day: day,
        subject: subjectKey,
      )) {
        continue;
      }

      final desiredDays = _desiredWorkingDaysForTeacher(prof.weeklyQuota);
      final currentDays = teachingByTeacherByDay[t.id]!.values
          .where((v) => v > 0)
          .length;
      final dayCount = teachingByTeacherByDay[t.id]?[day] ?? 0;
      final isNewDay = dayCount == 0;
      final maxPerDay = max(3, (prof.weeklyQuota / max(1, desiredDays)).ceil());

      var score = 0;
      score += load * 4;
      score += dayCount * 8;
      if (dayCount >= maxPerDay) score += 200;
      if (isNewDay && currentDays < desiredDays) score -= 60;
      if (day == 'الخميس' &&
          prof.weeklyQuota >= 11 &&
          (teachingByTeacherByDay[t.id]?['الخميس'] ?? 0) == 0) {
        score -= 80;
      }

      if (best == null || score < bestScore!) {
        best = t;
        bestScore = score;
      }
    }

    return best;
  }

  Future<Map<String, List<ScheduleSlot>>> _assignCoreSlotsStrict(
    List<TeacherConstraintsProfile> profiles,
    List<User> teachers,
    List<String> classIds,
    School school,
    Map<String, List<ScheduleSlot>>? fixedSlots,
    Random rng,
    int? activityPeriod,
    Map<String, Map<String, int>> normalizedDemand, {
    Map<String, int>? remainderBySubject,
    Map<String, dynamic>? fractionReport,
  }) async {
    final profilesById = {for (final p in profiles) p.teacherId: p};

    final teacherSchedule = <String, List<ScheduleSlot>>{
      for (final p in profiles) p.teacherId: <ScheduleSlot>[],
    };

    final teacherOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final p in profiles)
        p.teacherId: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final c in classIds)
        c: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classSchedule = <String, List<ScheduleSlot>>{
      for (final c in classIds) c: <ScheduleSlot>[],
    };

    final teachingLoadByTeacher = <String, int>{
      for (final p in profiles) p.teacherId: 0,
    };
    final teachingByTeacherByDay = <String, Map<String, int>>{
      for (final p in profiles) p.teacherId: {for (final d in _days) d: 0},
    };

    final effectivePeriodsPerDay =
        _periodsPerDay - (activityPeriod != null ? 1 : 0);

    final mutableDemand = <String, Map<String, int>>{};
    for (final classId in classIds) {
      mutableDemand[classId] = Map<String, int>.from(
        normalizedDemand[classId] ?? const <String, int>{},
      );
    }

    if (activityPeriod != null) {
      for (final classId in classIds) {
        for (final day in _days) {
          classOccupancy[classId]![day]![activityPeriod] = true;
          classSchedule[classId]!.add(
            ScheduleSlot(
              day: day,
              period: activityPeriod,
              className: 'Class $classId',
              subject: 'Activity',
              teacherId: '',
            ),
          );
        }
      }
    }

    if (fixedSlots != null) {
      for (final entry in fixedSlots.entries) {
        final teacherId = entry.key;
        final prof = profilesById[teacherId];
        if (prof == null) continue;
        for (final slot in entry.value) {
          if (prof.blockedTimeSlots.contains('${slot.day}:${slot.period}')) {
            throw Exception(
              'تعارض في الجدول المثبت: المعلم $teacherId لديه وقت محظور في ${slot.day} الحصة ${slot.period}.',
            );
          }
          if (teacherOccupancy[teacherId]?[slot.day]?[slot.period] == true) {
            throw Exception(
              'تعارض في الجدول المثبت: المعلم $teacherId لديه حصة مزدوجة في ${slot.day} الحصة ${slot.period}.',
            );
          }

          teacherSchedule[teacherId]!.add(slot);
          teacherOccupancy[teacherId]![slot.day]![slot.period] = true;

          final isClass = slot.className.startsWith('Class ');
          if (isClass) {
            final cid = slot.className.replaceFirst('Class ', '');
            if (classOccupancy.containsKey(cid)) {
              if (classOccupancy[cid]?[slot.day]?[slot.period] == true) {
                throw Exception(
                  'تعارض في الجدول المثبت: الفصل $cid لديه حصة مزدوجة في ${slot.day} الحصة ${slot.period}.',
                );
              }
              classOccupancy[cid]![slot.day]![slot.period] = true;
              classSchedule[cid]!.add(slot);
              final subj = _normalizeSubject(slot.subject);
              if (!_isNonTeachingSubject(subj)) {
                teachingLoadByTeacher[teacherId] =
                    (teachingLoadByTeacher[teacherId] ?? 0) + 1;
                teachingByTeacherByDay[teacherId]![slot.day] =
                    (teachingByTeacherByDay[teacherId]![slot.day] ?? 0) + 1;
              }
              final current = mutableDemand[cid]?[subj] ?? 0;
              if (current > 0) {
                mutableDemand[cid]![subj] = current - 1;
              }
            }
          } else {
            if (!_isNonTeachingSubject(slot.subject)) {
              teachingLoadByTeacher[teacherId] =
                  (teachingLoadByTeacher[teacherId] ?? 0) + 1;
              teachingByTeacherByDay[teacherId]![slot.day] =
                  (teachingByTeacherByDay[teacherId]![slot.day] ?? 0) + 1;
            }
          }
        }
      }
    }

    final teachersBySubject = <String, List<User>>{};
    final teacherTier = <String, Map<String, int>>{};
    final assignedClassesByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      assignedClassesByTeacher[t.id] = (t.assignedClassIds ?? const <String>[])
          .toSet();
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) {
        teachersBySubject.putIfAbsent(primary, () => <User>[]);
        if (!teachersBySubject[primary]!.any((x) => x.id == t.id)) {
          teachersBySubject[primary]!.add(t);
        }
        teacherTier.putIfAbsent(primary, () => <String, int>{});
        teacherTier[primary]![t.id] = 0;
      }
      final assigns = t.subjectAssignments ?? const <SubjectAssignment>[];
      for (final a in assigns) {
        final subj = _normalizeSubject(a.subjectId);
        if (subj.isEmpty) continue;
        teachersBySubject.putIfAbsent(subj, () => <User>[]);
        if (!teachersBySubject[subj]!.any((x) => x.id == t.id)) {
          teachersBySubject[subj]!.add(t);
        }
        teacherTier.putIfAbsent(subj, () => <String, int>{});
        final tier = switch (a.type) {
          SubjectAssignmentType.primary => 0,
          SubjectAssignmentType.additional => 1,
          SubjectAssignmentType.emergency => 2,
        };
        final existing = teacherTier[subj]![t.id];
        if (existing == null || tier < existing) {
          teacherTier[subj]![t.id] = tier;
        }
      }
    }

    final classMappingFallbacks = <Map<String, String>>[];
    final _classMappingFallbackKey = <String>{};
    final candidatesBySubjectAndClass = <String, Map<String, List<User>>>{};

    List<User> candidatesForSubjectAndClass(String subject, String classId) {
      final raw = teachersBySubject[subject] ?? const <User>[];
      if (raw.isEmpty) return const <User>[];

      final cache = candidatesBySubjectAndClass.putIfAbsent(
        subject,
        () => <String, List<User>>{},
      );
      if (cache.containsKey(classId)) return cache[classId]!;

      final specific = <User>[];
      final general = <User>[];
      for (final t in raw) {
        final set = assignedClassesByTeacher[t.id] ?? const <String>{};
        if (set.isEmpty) {
          general.add(t);
        } else if (set.contains(classId)) {
          specific.add(t);
        }
      }

      List<User> resolved;
      if (specific.isNotEmpty) {
        resolved = specific;
      } else if (general.isNotEmpty) {
        resolved = general;
      } else {
        resolved = raw;
        final key = '$subject|$classId';
        if (_classMappingFallbackKey.add(key)) {
          classMappingFallbacks.add({'subject': subject, 'classId': classId});
        }
      }

      cache[classId] = resolved;
      return resolved;
    }

    final classDayPlan = <String, Map<String, Map<String, int>>>{};
    for (final classId in classIds) {
      final dayTargets = <String, int>{};
      for (final day in _days) {
        var free = 0;
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] == false) {
            free++;
          }
        }
        dayTargets[day] = free;
      }
      classDayPlan[classId] = _buildClassDayPlanStrict(
        weeklyDemand: mutableDemand[classId] ?? const <String, int>{},
        dayTargets: dayTargets,
        rng: rng,
      );
    }

    final teacherNameById = {for (final t in teachers) t.id: t.name};

    for (final day in _days) {
      final classesForDay = List<String>.from(classIds)..shuffle(rng);
      classesForDay.sort((a, b) {
        double scoreFor(String classId) {
          final plan = classDayPlan[classId]?[day] ?? const <String, int>{};
          var s = 0.0;
          for (final e in plan.entries) {
            final c = (teachersBySubject[e.key] ?? const <User>[]).length;
            final inv = 1.0 / max(1, c);
            s += inv * e.value;
          }
          return s;
        }

        final sa = scoreFor(a);
        final sb = scoreFor(b);
        if (sa != sb) return sb.compareTo(sa);
        return a.compareTo(b);
      });

      for (final classId in classesForDay) {
        final plan = classDayPlan[classId]?[day] ?? const <String, int>{};
        final subjectInstances = <String>[];
        for (final e in plan.entries) {
          for (int i = 0; i < e.value; i++) {
            subjectInstances.add(e.key);
          }
        }

        final freePeriods = <int>[];
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] == false) {
            freePeriods.add(p);
          }
        }

        String diagnoseNoTeacher({
          required String subject,
          required List<int> remainingPeriods,
        }) {
          final candidates = teachersBySubject[subject] ?? const <User>[];
          final total = candidates.length;
          final byPeriod = <String>[];
          for (final p in remainingPeriods) {
            var avail = 0;
            for (final t in candidates) {
              final tid = t.id;
              final prof = profilesById[tid];
              if (prof == null) continue;
              if (teacherOccupancy[tid]?[day]?[p] == true) continue;
              if (prof.blockedTimeSlots.contains('$day:$p')) continue;
              if ((teachingLoadByTeacher[tid] ?? 0) >= prof.weeklyQuota)
                continue;
              if (!_canAssignSameSubjectForTeacherDay(
                teacherSchedule: teacherSchedule,
                teacherId: tid,
                day: day,
                subject: subject,
              )) {
                continue;
              }
              avail++;
            }
            byPeriod.add('$p=$avail');
          }
          final sample = candidates
              .take(5)
              .map((t) => teacherNameById[t.id] ?? t.id)
              .toList();
          final sampleText = sample.isEmpty
              ? ''
              : ' | عينة معلمين: ${sample.join('، ')}';
          return 'لا يوجد معلم متاح لمادة $subject في $day. إجمالي المعلمين للمادة: $total | المتاح لكل حصة: ${byPeriod.join('، ')}$sampleText';
        }

        final attemptsForDay = 90;
        bool okDay = false;
        String? lastFailReason;

        for (int dayAttempt = 0; dayAttempt < attemptsForDay; dayAttempt++) {
          final placedSlots = <ScheduleSlot>[];
          final periods = List<int>.from(freePeriods);
          periods.shuffle(rng);

          final order = List<String>.from(subjectInstances);
          order.shuffle(rng);
          order.sort((a, b) {
            final ca = (teachersBySubject[a] ?? const <User>[]).length;
            final cb = (teachersBySubject[b] ?? const <User>[]).length;
            if (ca != cb) return ca.compareTo(cb);
            return a.compareTo(b);
          });

          bool success = true;
          for (final subject in order) {
            if (periods.isEmpty) {
              success = false;
              lastFailReason = 'نفدت الحصص المتاحة لهذا اليوم.';
              break;
            }

            double bestPeriodScore = 1e18;
            int? bestPeriod;
            User? bestTeacher;

            for (final p in periods) {
              final list = List<User>.from(
                teachersBySubject[subject] ?? const <User>[],
              );
              if (list.isEmpty) continue;
              list.shuffle(rng);
              list.sort((a, b) {
                final ta = teacherTier[subject]?[a.id] ?? 9;
                final tb = teacherTier[subject]?[b.id] ?? 9;
                if (ta != tb) return ta.compareTo(tb);
                final la = teachingLoadByTeacher[a.id] ?? 0;
                final lb = teachingLoadByTeacher[b.id] ?? 0;
                if (la != lb) return la.compareTo(lb);
                return a.id.compareTo(b.id);
              });

              final teacher = _pickTeacherForSlotStrict(
                subject: subject,
                day: day,
                period: p,
                candidates: list,
                profilesById: profilesById,
                teacherSchedule: teacherSchedule,
                teacherOccupancy: teacherOccupancy,
                teachingLoadByTeacher: teachingLoadByTeacher,
                teachingByTeacherByDay: teachingByTeacherByDay,
              );
              if (teacher == null) continue;

              final teacherId = teacher.id;
              final prof = profilesById[teacherId];
              if (prof == null) continue;
              if ((teachingLoadByTeacher[teacherId] ?? 0) >= prof.weeklyQuota) {
                continue;
              }

              var score = 0.0;
              score += _isPreferredPeriodForSubject(subject, p) ? -2.0 : 0.0;
              score += (p == 7) ? 0.6 : 0.0;
              score += (teachingByTeacherByDay[teacherId]?[day] ?? 0) * 0.25;
              score += rng.nextDouble() * 0.05;

              if (score < bestPeriodScore) {
                bestPeriodScore = score;
                bestPeriod = p;
                bestTeacher = teacher;
              }
            }

            if (bestPeriod == null || bestTeacher == null) {
              success = false;
              lastFailReason = diagnoseNoTeacher(
                subject: subject,
                remainingPeriods: List<int>.from(periods),
              );
              break;
            }

            final teacherId = bestTeacher.id;
            final slot = ScheduleSlot(
              day: day,
              period: bestPeriod,
              className: 'Class $classId',
              subject: subject,
              teacherId: teacherId,
            );

            teacherSchedule[teacherId]!.add(slot);
            classSchedule[classId]!.add(slot);
            teacherOccupancy[teacherId]![day]![bestPeriod] = true;
            classOccupancy[classId]![day]![bestPeriod] = true;
            teachingLoadByTeacher[teacherId] =
                (teachingLoadByTeacher[teacherId] ?? 0) + 1;
            teachingByTeacherByDay[teacherId]![day] =
                (teachingByTeacherByDay[teacherId]![day] ?? 0) + 1;

            periods.remove(bestPeriod);
            placedSlots.add(slot);
          }

          if (success) {
            okDay = true;
            break;
          }

          for (final s in placedSlots) {
            final tid = s.teacherId;
            teacherSchedule[tid]?.removeWhere((x) {
              return x.day == s.day &&
                  x.period == s.period &&
                  x.className == s.className &&
                  x.subject == s.subject &&
                  x.teacherId == s.teacherId;
            });
            classSchedule[classId]?.removeWhere((x) {
              return x.day == s.day &&
                  x.period == s.period &&
                  x.className == s.className &&
                  x.subject == s.subject &&
                  x.teacherId == s.teacherId;
            });
            teacherOccupancy[tid]?[s.day]?[s.period] = false;
            classOccupancy[classId]?[s.day]?[s.period] = false;
            teachingLoadByTeacher[tid] = (teachingLoadByTeacher[tid] ?? 1) - 1;
            teachingByTeacherByDay[tid]?[s.day] =
                (teachingByTeacherByDay[tid]?[s.day] ?? 1) - 1;
          }
        }

        if (!okDay) {
          throw Exception(
            'فشل بناء جدول صارم: تعذر إكمال يوم $day للفصل $classId. ${lastFailReason ?? ''}',
          );
        }
      }
    }

    for (final classId in classIds) {
      for (final day in _days) {
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] != true) {
            throw Exception(
              'فشل بناء جدول صارم: يوجد فراغ في الفصل $classId في $day الحصة $p.',
            );
          }
        }
      }
    }

    return teacherSchedule;
  }

  Map<String, Map<String, int>> _buildClassWeeklyDemandAdjusted({
    required Map<String, int> baseDemand,
    required List<ScheduleSlot> fixedClassSlots,
    required int? activityPeriod,
  }) {
    final out = <String, Map<String, int>>{
      'demand': Map<String, int>.from(baseDemand),
    };
    for (final s in fixedClassSlots) {
      if (activityPeriod != null && s.period == activityPeriod) continue;
      if (s.subject.startsWith('منتظر')) continue;
      if (_isNonTeachingSubject(s.subject)) continue;
      final subj = _normalizeSubject(s.subject);
      if (subj.isEmpty) continue;
      final current = out['demand']![subj] ?? 0;
      if (current > 0) out['demand']![subj] = current - 1;
    }
    out['demand']!.removeWhere((k, v) => v <= 0);
    return out;
  }

  Map<String, Map<String, int>> _buildClassDayPlanV2({
    required Map<String, int> weeklyDemand,
    required Map<String, int> dayTargets,
    required Random rng,
    int maxPerDayPerSubject = 2,
  }) {
    final byDay = <String, Map<String, int>>{
      for (final d in _days) d: <String, int>{},
    };
    final byDayCount = <String, Map<String, int>>{
      for (final d in _days) d: <String, int>{},
    };
    final remainingCapacity = <String, int>{
      for (final d in _days) d: dayTargets[d] ?? 0,
    };

    final totalDemand = weeklyDemand.values.fold<int>(0, (a, b) => a + b);
    final totalCap = remainingCapacity.values.fold<int>(0, (a, b) => a + b);
    if (totalDemand != totalCap) {
      throw Exception(
        'خطة الفصل غير متسقة: إجمالي الاحتياج $totalDemand لا يساوي السعة $totalCap',
      );
    }

    final subjects = weeklyDemand.entries.toList()
      ..sort((a, b) {
        if (a.value != b.value) return b.value.compareTo(a.value);
        return a.key.compareTo(b.key);
      });

    final dayOrder = List<String>.from(_days);
    final start = rng.nextInt(_days.length);
    final rotated = <String>[
      ...dayOrder.sublist(start),
      ...dayOrder.sublist(0, start),
    ];

    for (final e in subjects) {
      final subject = _normalizeSubject(e.key);
      var remaining = e.value;
      final maxTotal = _days.length * maxPerDayPerSubject;
      if (remaining > maxTotal) {
        throw Exception(
          'خطة الفصل غير ممكنة: المادة $subject $remaining تتجاوز حد $maxPerDayPerSubject مرات يوميًا',
        );
      }

      for (final d in rotated) {
        if (remaining <= 0) break;
        if ((remainingCapacity[d] ?? 0) <= 0) continue;
        if ((byDayCount[d]?[subject] ?? 0) >= 1) continue;
        byDay[d]![subject] = (byDay[d]![subject] ?? 0) + 1;
        byDayCount[d]![subject] = 1;
        remainingCapacity[d] = (remainingCapacity[d] ?? 0) - 1;
        remaining--;
      }

      while (remaining > 0) {
        final candidates = List<String>.from(_days);
        candidates.shuffle(rng);
        candidates.sort((a, b) {
          final ca = byDayCount[a]?[subject] ?? 0;
          final cb = byDayCount[b]?[subject] ?? 0;
          if (ca != cb) return ca.compareTo(cb);
          final ra = remainingCapacity[a] ?? 0;
          final rb = remainingCapacity[b] ?? 0;
          if (ra != rb) return rb.compareTo(ra);
          final ta = dayTargets[a] ?? 0;
          final tb = dayTargets[b] ?? 0;
          if (ta != tb) return tb.compareTo(ta);
          return a.compareTo(b);
        });

        String? chosen;
        for (final d in candidates) {
          if ((remainingCapacity[d] ?? 0) <= 0) continue;
          final count = byDayCount[d]?[subject] ?? 0;
          if (count >= maxPerDayPerSubject) continue;
          chosen = d;
          break;
        }
        if (chosen == null) {
          throw Exception(
            'خطة الفصل غير ممكنة: لا يمكن إكمال توزيع $subject ضمن حد $maxPerDayPerSubject مرات يوميًا',
          );
        }
        byDay[chosen]![subject] = (byDay[chosen]![subject] ?? 0) + 1;
        byDayCount[chosen]![subject] = (byDayCount[chosen]?[subject] ?? 0) + 1;
        remainingCapacity[chosen] = (remainingCapacity[chosen] ?? 0) - 1;
        remaining--;
      }
    }

    for (final d in _days) {
      if ((remainingCapacity[d] ?? 0) != 0) {
        throw Exception('خطة الفصل غير ممكنة: سعة اليوم $d لم تُملأ بالكامل');
      }
    }

    return byDay;
  }

  Map<String, Map<String, int>> _buildTeacherDayTargetsV2({
    required List<TeacherConstraintsProfile> profiles,
    required Random rng,
  }) {
    final out = <String, Map<String, int>>{};
    for (final p in profiles) {
      final desiredDays = _desiredWorkingDaysForTeacher(p.weeklyQuota);
      final days = List<String>.from(_days);
      days.shuffle(rng);
      final blockedThu = List<int>.generate(
        _periodsPerDay,
        (i) => i + 1,
      ).every((x) => p.blockedTimeSlots.contains('الخميس:$x'));
      if (p.weeklyQuota >= 11 && !blockedThu && days.contains('الخميس')) {
        days.remove('الخميس');
        days.insert(0, 'الخميس');
      }

      final usedDays = days.take(min(desiredDays, _days.length)).toList();
      final base = (p.weeklyQuota / max(1, usedDays.length)).floor();
      var rem = p.weeklyQuota - (base * usedDays.length);
      final map = <String, int>{for (final d in _days) d: 0};
      for (final d in usedDays) {
        map[d] = base;
      }
      usedDays.shuffle(rng);
      var i = 0;
      while (rem > 0 && usedDays.isNotEmpty) {
        final d = usedDays[i % usedDays.length];
        map[d] = (map[d] ?? 0) + 1;
        rem--;
        i++;
      }
      out[p.teacherId] = map;
    }
    return out;
  }

  List<User> _teachersForSubjectSorted({
    required String subject,
    required List<User> teachers,
    required Map<String, int> teachingLoadByTeacher,
    required Map<String, Map<String, int>> teacherTier,
    required Random rng,
  }) {
    final list = List<User>.from(teachers);
    list.shuffle(rng);
    list.sort((a, b) {
      final ta = teacherTier[subject]?[a.id] ?? 9;
      final tb = teacherTier[subject]?[b.id] ?? 9;
      if (ta != tb) return ta.compareTo(tb);
      final la = teachingLoadByTeacher[a.id] ?? 0;
      final lb = teachingLoadByTeacher[b.id] ?? 0;
      if (la != lb) return la.compareTo(lb);
      return a.id.compareTo(b.id);
    });
    return list;
  }

  Future<_CoreScheduleBuildResult> _buildCoreScheduleBacktrackingV2({
    required List<TeacherConstraintsProfile> profiles,
    required List<User> teachers,
    required List<String> classIds,
    required School school,
    required Map<String, List<ScheduleSlot>>? fixedSlots,
    required Random rng,
    required int? activityPeriod,
    required Map<String, Map<String, int>> normalizedDemand,
    required int maxNodes,
    required DateTime deadline,
    required int yieldEveryNodes,
    Map<String, Set<String>>? teacherUnavailablePrefSlots,
    Map<String, bool>? teacherNoSeventh,
    Map<String, bool>? teacherPreferConsecutive,
    double unavailableSlotPenalty = 12.0,
    String noSeventhPeriodMode = 'hard',
    double noSeventhPeriodPenalty = 18.0,
    double preferConsecutiveWeight = -0.9,
    int? maxDailyLessonsPerTeacher,
    int? maxConsecutiveLessonsPerTeacher,
    double seventhPeriodPenalty = 0.8,
    int maxPerDayPerSubjectForClass = 2,
  }) async {
    final profilesById = {for (final p in profiles) p.teacherId: p};

    final teacherSchedule = <String, List<ScheduleSlot>>{
      for (final p in profiles) p.teacherId: <ScheduleSlot>[],
    };

    final teacherOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final p in profiles)
        p.teacherId: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final c in classIds)
        c: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classSchedule = <String, List<ScheduleSlot>>{
      for (final c in classIds) c: <ScheduleSlot>[],
    };

    final teachingLoadByTeacher = <String, int>{
      for (final p in profiles) p.teacherId: 0,
    };
    final teachingByTeacherByDay = <String, Map<String, int>>{
      for (final p in profiles) p.teacherId: {for (final d in _days) d: 0},
    };

    if (activityPeriod != null) {
      for (final classId in classIds) {
        for (final day in _days) {
          classOccupancy[classId]![day]![activityPeriod] = true;
          classSchedule[classId]!.add(
            ScheduleSlot(
              day: day,
              period: activityPeriod,
              className: 'Class $classId',
              subject: 'Activity',
              teacherId: '',
            ),
          );
        }
      }
    }

    final fixedByTeacher = fixedSlots ?? const <String, List<ScheduleSlot>>{};
    for (final entry in fixedByTeacher.entries) {
      final teacherId = entry.key;
      if (!teacherSchedule.containsKey(teacherId)) continue;
      final prof = profilesById[teacherId];
      if (prof == null) continue;
      for (final slot in entry.value) {
        if (prof.blockedTimeSlots.contains('${slot.day}:${slot.period}')) {
          throw Exception(
            'تعارض في الجدول المثبت: المعلم $teacherId لديه وقت محظور في ${slot.day} الحصة ${slot.period}.',
          );
        }
        if (teacherOccupancy[teacherId]?[slot.day]?[slot.period] == true) {
          throw Exception(
            'تعارض في الجدول المثبت: المعلم $teacherId لديه حصة مزدوجة في ${slot.day} الحصة ${slot.period}.',
          );
        }
        teacherSchedule[teacherId]!.add(slot);
        teacherOccupancy[teacherId]![slot.day]![slot.period] = true;
        if (!_isNonTeachingSubject(slot.subject) &&
            !slot.subject.startsWith('منتظر')) {
          teachingLoadByTeacher[teacherId] =
              (teachingLoadByTeacher[teacherId] ?? 0) + 1;
          teachingByTeacherByDay[teacherId]![slot.day] =
              (teachingByTeacherByDay[teacherId]![slot.day] ?? 0) + 1;
        }

        if (slot.className.startsWith('Class ')) {
          final cid = slot.className.substring(6);
          if (classOccupancy.containsKey(cid)) {
            classOccupancy[cid]![slot.day]![slot.period] = true;
            classSchedule[cid]!.add(slot);
          }
        }
      }
    }

    final teachersBySubject = <String, List<User>>{};
    final teacherTier = <String, Map<String, int>>{};
    final assignedClassesByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      assignedClassesByTeacher[t.id] = (t.assignedClassIds ?? const <String>[])
          .toSet();
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) {
        teachersBySubject.putIfAbsent(primary, () => <User>[]);
        if (!teachersBySubject[primary]!.any((x) => x.id == t.id)) {
          teachersBySubject[primary]!.add(t);
        }
        teacherTier.putIfAbsent(primary, () => <String, int>{});
        teacherTier[primary]![t.id] = 0;
      }
      final assigns = t.subjectAssignments ?? const <SubjectAssignment>[];
      for (final a in assigns) {
        final subj = _normalizeSubject(a.subjectId);
        if (subj.isEmpty) continue;
        teachersBySubject.putIfAbsent(subj, () => <User>[]);
        if (!teachersBySubject[subj]!.any((x) => x.id == t.id)) {
          teachersBySubject[subj]!.add(t);
        }
        teacherTier.putIfAbsent(subj, () => <String, int>{});
        final tier = switch (a.type) {
          SubjectAssignmentType.primary => 0,
          SubjectAssignmentType.additional => 1,
          SubjectAssignmentType.emergency => 2,
        };
        final existing = teacherTier[subj]![t.id];
        if (existing == null || tier < existing) {
          teacherTier[subj]![t.id] = tier;
        }
      }
    }

    final classMappingFallbacks = <Map<String, String>>[];
    final _classMappingFallbackKey = <String>{};
    final candidatesBySubjectAndClass = <String, Map<String, List<User>>>{};

    List<User> candidatesForSubjectAndClass(String subject, String classId) {
      final raw = teachersBySubject[subject] ?? const <User>[];
      if (raw.isEmpty) return const <User>[];

      final cache = candidatesBySubjectAndClass.putIfAbsent(
        subject,
        () => <String, List<User>>{},
      );
      if (cache.containsKey(classId)) return cache[classId]!;

      final specific = <User>[];
      final general = <User>[];
      for (final t in raw) {
        final set = assignedClassesByTeacher[t.id] ?? const <String>{};
        if (set.isEmpty) {
          general.add(t);
        } else if (set.contains(classId)) {
          specific.add(t);
        }
      }

      List<User> resolved;
      if (specific.isNotEmpty) {
        resolved = specific;
      } else if (general.isNotEmpty) {
        resolved = general;
      } else {
        resolved = raw;
        final key = '$subject|$classId';
        if (_classMappingFallbackKey.add(key)) {
          classMappingFallbacks.add({'subject': subject, 'classId': classId});
        }
      }

      cache[classId] = resolved;
      return resolved;
    }

    final classDayPlan = <String, Map<String, Map<String, int>>>{};
    final classFreePeriods = <String, Map<String, List<int>>>{};
    for (final classId in classIds) {
      final dayTargets = <String, int>{};
      final freePerDay = <String, List<int>>{};
      for (final day in _days) {
        final periods = <int>[];
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] == false) {
            periods.add(p);
          }
        }
        freePerDay[day] = periods;
        dayTargets[day] = periods.length;
      }
      classFreePeriods[classId] = freePerDay;
      classDayPlan[classId] = _buildClassDayPlanV2(
        weeklyDemand: normalizedDemand[classId] ?? const <String, int>{},
        dayTargets: dayTargets,
        rng: rng,
        maxPerDayPerSubject: maxPerDayPerSubjectForClass,
      );
    }

    final teacherDayTargets = _buildTeacherDayTargetsV2(
      profiles: profiles,
      rng: rng,
    );

    final allTasks = <_V2Task>[];
    for (final classId in classIds) {
      for (final day in _days) {
        final plan = classDayPlan[classId]![day] ?? const <String, int>{};
        for (final e in plan.entries) {
          for (int i = 0; i < e.value; i++) {
            allTasks.add(_V2Task(classId: classId, day: day, subject: e.key));
          }
        }
      }
    }

    allTasks.shuffle(rng);
    allTasks.sort((a, b) {
      final ca = candidatesForSubjectAndClass(a.subject, a.classId).length;
      final cb = candidatesForSubjectAndClass(b.subject, b.classId).length;
      if (ca != cb) return ca.compareTo(cb);
      final da = _days.indexOf(a.day);
      final db = _days.indexOf(b.day);
      if (da != db) return da.compareTo(db);
      return a.classId.compareTo(b.classId);
    });

    final classDayUsedSubjects =
        <String, Map<String, Map<String, List<int>>>>{};
    for (final classId in classIds) {
      classDayUsedSubjects[classId] = {
        for (final d in _days) d: <String, List<int>>{},
      };
    }

    final classDayUsedPeriods = <String, Map<String, Set<int>>>{};
    for (final classId in classIds) {
      classDayUsedPeriods[classId] = {for (final d in _days) d: <int>{}};
    }

    var nodes = 0;
    var backtracks = 0;
    var maxDepth = 0;
    Map<String, dynamic>? bestDeadEnd;
    var bestDeadEndDepth = -1;
    var bestPartialDepth = -1;
    var bestPartialStack = <_V2Assignment>[];

    Map<String, dynamic> buildDeadEnd({
      required _V2Task task,
      required List<int> availablePeriods,
      required String reason,
    }) {
      final candidates = candidatesForSubjectAndClass(
        task.subject,
        task.classId,
      );
      final availByPeriod = <String, int>{};
      for (final p in availablePeriods) {
        var avail = 0;
        for (final t in candidates) {
          final tid = t.id;
          if (teacherOccupancy[tid]?[task.day]?[p] == true) continue;
          final prof = profilesById[tid];
          if (prof == null) continue;
          if (prof.blockedTimeSlots.contains('${task.day}:$p')) continue;
          if ((teachingLoadByTeacher[tid] ?? 0) >= prof.weeklyQuota) continue;
          final desiredDays = _desiredWorkingDaysForTeacher(prof.weeklyQuota);
          final maxPerDay = max(
            3,
            (prof.weeklyQuota / max(1, desiredDays)).ceil(),
          );
          if ((teachingByTeacherByDay[tid]?[task.day] ?? 0) >= maxPerDay) {
            continue;
          }
          if (!_canAssignSameSubjectForTeacherDay(
            teacherSchedule: teacherSchedule,
            teacherId: tid,
            day: task.day,
            subject: task.subject,
          )) {
            continue;
          }
          avail++;
        }
        availByPeriod[p.toString()] = avail;
      }
      return {
        'classId': task.classId,
        'day': task.day,
        'subject': task.subject,
        'subjectName': _subjectNameById[task.subject] ?? task.subject,
        'candidatesTotal': candidates.length,
        'availableByPeriod': availByPeriod,
        'reason': reason,
      };
    }

    int maxConsecutiveIfAssigned(
      List<ScheduleSlot> slots,
      String day,
      int period,
    ) {
      final periods = slots
          .where((s) => s.day == day)
          .map((s) => s.period)
          .toList();
      periods.add(period);
      periods.sort();
      var best = 1;
      var cur = 1;
      for (int i = 1; i < periods.length; i++) {
        if (periods[i] == periods[i - 1] + 1) {
          cur++;
          if (cur > best) best = cur;
        } else {
          cur = 1;
        }
      }
      return best;
    }

    bool canPlaceTaskAt({
      required _V2Task task,
      required int period,
      required String teacherId,
    }) {
      if (classOccupancy[task.classId]?[task.day]?[period] == true)
        return false;
      if (teacherOccupancy[teacherId]?[task.day]?[period] == true) return false;
      final prof = profilesById[teacherId];
      if (prof == null) return false;
      if (prof.blockedTimeSlots.contains('${task.day}:$period')) return false;
      if ((teachingLoadByTeacher[teacherId] ?? 0) >= prof.weeklyQuota)
        return false;
      if ((teacherNoSeventh?[teacherId] ?? false) &&
          noSeventhPeriodMode == 'hard' &&
          period == 7) {
        return false;
      }
      if (!_canAssignSameSubjectForTeacherDay(
        teacherSchedule: teacherSchedule,
        teacherId: teacherId,
        day: task.day,
        subject: task.subject,
      )) {
        return false;
      }
      final usedToday = teachingByTeacherByDay[teacherId]?[task.day] ?? 0;
      final desiredDays = _desiredWorkingDaysForTeacher(prof.weeklyQuota);
      var maxPerDay = max(3, (prof.weeklyQuota / max(1, desiredDays)).ceil());
      final policyMaxDaily = maxDailyLessonsPerTeacher ?? 0;
      if (policyMaxDaily > 0) maxPerDay = min(maxPerDay, policyMaxDaily);
      if (usedToday >= maxPerDay) return false;
      final policyMaxConsecutive = maxConsecutiveLessonsPerTeacher ?? 0;
      if (policyMaxConsecutive > 0) {
        final slots = teacherSchedule[teacherId] ?? const <ScheduleSlot>[];
        final mx = maxConsecutiveIfAssigned(slots, task.day, period);
        if (mx > policyMaxConsecutive) return false;
      }
      return true;
    }

    double scoreChoice({
      required _V2Task task,
      required int period,
      required String teacherId,
    }) {
      final prof = profilesById[teacherId]!;
      var score = 0.0;
      score += _isPreferredPeriodForSubject(task.subject, period) ? -3.0 : 0.0;
      score += (period == 7) ? seventhPeriodPenalty : 0.0;
      if ((teacherNoSeventh?[teacherId] ?? false) && period == 7) {
        score += noSeventhPeriodPenalty;
      }
      final softBlocked = teacherUnavailablePrefSlots?[teacherId];
      if (softBlocked != null && softBlocked.contains('${task.day}:$period')) {
        score += unavailableSlotPenalty;
      }
      score += (teachingLoadByTeacher[teacherId] ?? 0) * 0.2;
      score += (teachingByTeacherByDay[teacherId]?[task.day] ?? 0) * 0.35;
      final target = teacherDayTargets[teacherId]?[task.day] ?? 0;
      final current = teachingByTeacherByDay[teacherId]?[task.day] ?? 0;
      if (current < target) score -= 0.8;
      if (task.day == 'الخميس' && prof.weeklyQuota >= 11) {
        if ((teachingByTeacherByDay[teacherId]?['الخميس'] ?? 0) == 0) {
          score -= 1.2;
        }
      }
      final occurrences =
          classDayUsedSubjects[task.classId]?[task.day]?[task.subject] ??
          const <int>[];
      if (occurrences.isNotEmpty) {
        final other = occurrences.first;
        if ((other - period).abs() <= 1) score += 2.0;
      }
      if ((teacherPreferConsecutive?[teacherId] ?? false) &&
          preferConsecutiveWeight != 0.0) {
        final dayPeriods =
            teacherSchedule[teacherId]
                ?.where((s) => s.day == task.day)
                .map((s) => s.period)
                .toSet() ??
            <int>{};
        if (dayPeriods.contains(period - 1) ||
            dayPeriods.contains(period + 1)) {
          score += preferConsecutiveWeight;
        }
      }
      score += rng.nextDouble() * 0.05;
      return score;
    }

    Future<bool> dfs(int index, List<_V2Assignment> stack) async {
      if (DateTime.now().isAfter(deadline)) return false;
      if (nodes++ > maxNodes) return false;
      if (yieldEveryNodes > 0 && nodes % yieldEveryNodes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (index >= allTasks.length) return true;
      maxDepth = max(maxDepth, index);
      if (index > bestPartialDepth) {
        bestPartialDepth = index;
        bestPartialStack = List<_V2Assignment>.from(stack);
      }

      final task = allTasks[index];
      final free = classFreePeriods[task.classId]?[task.day] ?? const <int>[];
      final used =
          classDayUsedPeriods[task.classId]?[task.day] ?? const <int>{};
      final availablePeriods = free.where((p) => !used.contains(p)).toList();
      if (availablePeriods.isEmpty) {
        if (index > bestDeadEndDepth) {
          bestDeadEndDepth = index;
          bestDeadEnd = buildDeadEnd(
            task: task,
            availablePeriods: const <int>[],
            reason: 'لا توجد حصص متاحة للفصل في هذا اليوم',
          );
        }
        return false;
      }

      final subjectTeachersRaw = candidatesForSubjectAndClass(
        task.subject,
        task.classId,
      );
      if (subjectTeachersRaw.isEmpty) {
        if (index > bestDeadEndDepth) {
          bestDeadEndDepth = index;
          bestDeadEnd = buildDeadEnd(
            task: task,
            availablePeriods: availablePeriods,
            reason: 'لا يوجد معلمون لهذه المادة',
          );
        }
        return false;
      }
      final sortedTeachers = _teachersForSubjectSorted(
        subject: task.subject,
        teachers: subjectTeachersRaw,
        teachingLoadByTeacher: teachingLoadByTeacher,
        teacherTier: teacherTier,
        rng: rng,
      );

      final choices = <_V2Choice>[];
      for (final period in availablePeriods) {
        for (final t in sortedTeachers.take(12)) {
          if (!canPlaceTaskAt(task: task, period: period, teacherId: t.id))
            continue;
          final sc = scoreChoice(task: task, period: period, teacherId: t.id);
          choices.add(_V2Choice(period: period, teacherId: t.id, score: sc));
        }
      }
      if (choices.isEmpty) {
        if (index > bestDeadEndDepth) {
          bestDeadEndDepth = index;
          bestDeadEnd = buildDeadEnd(
            task: task,
            availablePeriods: availablePeriods,
            reason: 'لا يوجد معلم متاح ضمن القيود',
          );
        }
        return false;
      }
      choices.sort((a, b) => a.score.compareTo(b.score));

      final limit = min(choices.length, 18);
      for (int i = 0; i < limit; i++) {
        final c = choices[i];
        final teacherId = c.teacherId;
        final period = c.period;

        final slot = ScheduleSlot(
          day: task.day,
          period: period,
          className: 'Class ${task.classId}',
          subject: task.subject,
          teacherId: teacherId,
        );

        teacherSchedule[teacherId]!.add(slot);
        classSchedule[task.classId]!.add(slot);
        teacherOccupancy[teacherId]![task.day]![period] = true;
        classOccupancy[task.classId]![task.day]![period] = true;
        teachingLoadByTeacher[teacherId] =
            (teachingLoadByTeacher[teacherId] ?? 0) + 1;
        teachingByTeacherByDay[teacherId]![task.day] =
            (teachingByTeacherByDay[teacherId]![task.day] ?? 0) + 1;
        classDayUsedPeriods[task.classId]![task.day]!.add(period);
        classDayUsedSubjects[task.classId]![task.day]!
            .putIfAbsent(task.subject, () => <int>[])
            .add(period);

        stack.add(
          _V2Assignment(task: task, period: period, teacherId: teacherId),
        );

        if (await dfs(index + 1, stack)) return true;

        stack.removeLast();
        backtracks++;

        teacherSchedule[teacherId]!.removeLast();
        classSchedule[task.classId]!.removeLast();
        teacherOccupancy[teacherId]![task.day]![period] = false;
        classOccupancy[task.classId]![task.day]![period] = false;
        teachingLoadByTeacher[teacherId] =
            (teachingLoadByTeacher[teacherId] ?? 1) - 1;
        teachingByTeacherByDay[teacherId]![task.day] =
            (teachingByTeacherByDay[teacherId]![task.day] ?? 1) - 1;
        classDayUsedPeriods[task.classId]![task.day]!.remove(period);
        final occ =
            classDayUsedSubjects[task.classId]![task.day]![task.subject];
        occ?.remove(period);
      }
      return false;
    }

    final stack = <_V2Assignment>[];
    final ok = await dfs(0, stack);
    if (!ok) {
      for (final a in bestPartialStack) {
        final task = a.task;
        final period = a.period;
        if (classOccupancy[task.classId]?[task.day]?[period] == true) continue;
        final slot = ScheduleSlot(
          day: task.day,
          period: period,
          className: 'Class ${task.classId}',
          subject: task.subject,
          teacherId: a.teacherId,
        );
        teacherSchedule.putIfAbsent(a.teacherId, () => <ScheduleSlot>[]);
        teacherSchedule[a.teacherId]!.add(slot);
        classOccupancy[task.classId]![task.day]![period] = true;
      }

      var unassignedCount = 0;
      var unresolved = 0;
      for (int i = bestPartialStack.length; i < allTasks.length; i++) {
        final task = allTasks[i];
        int? picked;
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[task.classId]?[task.day]?[p] == true) continue;
          picked = p;
          break;
        }
        if (picked == null) {
          unresolved++;
          continue;
        }
        final tid =
            'unassigned_${task.subject}_${task.classId}_${task.day}_$picked';
        final slot = ScheduleSlot(
          day: task.day,
          period: picked,
          className: 'Class ${task.classId}',
          subject: task.subject,
          teacherId: tid,
        );
        teacherSchedule.putIfAbsent(tid, () => <ScheduleSlot>[]);
        teacherSchedule[tid]!.add(slot);
        classOccupancy[task.classId]![task.day]![picked] = true;
        unassignedCount++;
      }

      final report = <String, dynamic>{
        'mode': 'strict',
        'nodes': nodes,
        'backtracks': backtracks,
        'maxDepth': maxDepth,
        'tasksTotal': allTasks.length,
        'deadEnd': bestDeadEnd,
        'fallbackUsed': true,
        'fallbackAppliedDepth': bestPartialDepth,
        'fallbackUnassignedSlots': unassignedCount,
        'fallbackUnresolvedTasks': unresolved,
        if (classMappingFallbacks.isNotEmpty)
          'classMappingFallbacks': classMappingFallbacks,
      };
      return _CoreScheduleBuildResult(
        schedule: teacherSchedule,
        report: report,
      );
    }

    final resultSchedule = teacherSchedule;
    final teacherNameById = {for (final t in teachers) t.id: t.name};
    final teacherDayReport = <Map<String, dynamic>>[];
    for (final p in profiles) {
      final byDay =
          teachingByTeacherByDay[p.teacherId] ?? const <String, int>{};
      teacherDayReport.add({
        'teacherId': p.teacherId,
        'teacherName': teacherNameById[p.teacherId] ?? p.teacherId,
        'quota': p.weeklyQuota,
        'days': byDay,
        'total': byDay.values.fold<int>(0, (a, b) => a + b),
      });
    }

    final classRepeatReport = <Map<String, dynamic>>[];
    for (final classId in classIds) {
      for (final day in _days) {
        final counts = <String, int>{};
        for (final s in classSchedule[classId] ?? const <ScheduleSlot>[]) {
          if (s.day != day) continue;
          if (_isNonTeachingSubject(s.subject)) continue;
          if (s.subject.startsWith('منتظر')) continue;
          final subj = _normalizeSubject(s.subject);
          counts[subj] = (counts[subj] ?? 0) + 1;
        }
        final over = counts.entries.where((e) => e.value > 2).toList();
        if (over.isNotEmpty) {
          classRepeatReport.add({
            'classId': classId,
            'day': day,
            'overflow': {for (final e in over) e.key: e.value},
          });
        }
      }
    }

    final report = <String, dynamic>{
      'nodes': nodes,
      'backtracks': backtracks,
      'maxDepth': maxDepth,
      'tasksTotal': allTasks.length,
      'teacherDays': teacherDayReport,
      'classSubjectOverflow': classRepeatReport,
      'deadEnd': bestDeadEnd,
      if (classMappingFallbacks.isNotEmpty)
        'classMappingFallbacks': classMappingFallbacks,
    };

    return _CoreScheduleBuildResult(schedule: resultSchedule, report: report);
  }

  Future<_CoreScheduleBuildResult> _buildCoreScheduleBacktrackingV2Flex({
    required List<TeacherConstraintsProfile> profiles,
    required List<User> teachers,
    required List<String> classIds,
    required School school,
    required Map<String, List<ScheduleSlot>>? fixedSlots,
    required Random rng,
    required int? activityPeriod,
    required Map<String, Map<String, int>> normalizedDemand,
    required int maxNodes,
    required DateTime deadline,
    required int yieldEveryNodes,
    Map<String, Set<String>>? teacherUnavailablePrefSlots,
    Map<String, bool>? teacherNoSeventh,
    Map<String, bool>? teacherPreferConsecutive,
    double unavailableSlotPenalty = 12.0,
    String noSeventhPeriodMode = 'hard',
    double noSeventhPeriodPenalty = 18.0,
    double preferConsecutiveWeight = -0.9,
    int? maxDailyLessonsPerTeacher,
    int? maxConsecutiveLessonsPerTeacher,
    double seventhPeriodPenalty = 0.8,
    int maxPerDayPerSubjectForClass = 2,
  }) async {
    final profilesById = {for (final p in profiles) p.teacherId: p};

    final teacherSchedule = <String, List<ScheduleSlot>>{
      for (final p in profiles) p.teacherId: <ScheduleSlot>[],
    };

    final teacherOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final p in profiles)
        p.teacherId: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classOccupancy = <String, Map<String, Map<int, bool>>>{
      for (final c in classIds)
        c: {
          for (final d in _days)
            d: {
              for (int period = 1; period <= _periodsPerDay; period++)
                period: false,
            },
        },
    };

    final classSchedule = <String, List<ScheduleSlot>>{
      for (final c in classIds) c: <ScheduleSlot>[],
    };

    final teachingLoadByTeacher = <String, int>{
      for (final p in profiles) p.teacherId: 0,
    };
    final teachingByTeacherByDay = <String, Map<String, int>>{
      for (final p in profiles) p.teacherId: {for (final d in _days) d: 0},
    };

    if (activityPeriod != null) {
      for (final classId in classIds) {
        for (final day in _days) {
          classOccupancy[classId]![day]![activityPeriod] = true;
          classSchedule[classId]!.add(
            ScheduleSlot(
              day: day,
              period: activityPeriod,
              className: 'Class $classId',
              subject: 'Activity',
              teacherId: '',
            ),
          );
        }
      }
    }

    final fixedByTeacher = fixedSlots ?? const <String, List<ScheduleSlot>>{};
    for (final entry in fixedByTeacher.entries) {
      final teacherId = entry.key;
      if (!teacherSchedule.containsKey(teacherId)) continue;
      final prof = profilesById[teacherId];
      if (prof == null) continue;
      for (final slot in entry.value) {
        if (prof.blockedTimeSlots.contains('${slot.day}:${slot.period}')) {
          throw Exception(
            'تعارض في الجدول المثبت: المعلم $teacherId لديه وقت محظور في ${slot.day} الحصة ${slot.period}.',
          );
        }
        if (teacherOccupancy[teacherId]?[slot.day]?[slot.period] == true) {
          throw Exception(
            'تعارض في الجدول المثبت: المعلم $teacherId لديه حصة مزدوجة في ${slot.day} الحصة ${slot.period}.',
          );
        }
        teacherSchedule[teacherId]!.add(slot);
        teacherOccupancy[teacherId]![slot.day]![slot.period] = true;
        if (!_isNonTeachingSubject(slot.subject) &&
            !slot.subject.startsWith('منتظر')) {
          teachingLoadByTeacher[teacherId] =
              (teachingLoadByTeacher[teacherId] ?? 0) + 1;
          teachingByTeacherByDay[teacherId]![slot.day] =
              (teachingByTeacherByDay[teacherId]![slot.day] ?? 0) + 1;
        }

        if (slot.className.startsWith('Class ')) {
          final cid = slot.className.substring(6);
          if (classOccupancy.containsKey(cid)) {
            classOccupancy[cid]![slot.day]![slot.period] = true;
            classSchedule[cid]!.add(slot);
          }
        }
      }
    }

    final teachersBySubject = <String, List<User>>{};
    final teacherTier = <String, Map<String, int>>{};
    final assignedClassesByTeacher = <String, Set<String>>{};
    for (final t in teachers) {
      assignedClassesByTeacher[t.id] = (t.assignedClassIds ?? const <String>[])
          .toSet();
      final primary = _teacherPrimarySubject(t);
      if (primary.isNotEmpty) {
        teachersBySubject.putIfAbsent(primary, () => <User>[]);
        if (!teachersBySubject[primary]!.any((x) => x.id == t.id)) {
          teachersBySubject[primary]!.add(t);
        }
        teacherTier.putIfAbsent(primary, () => <String, int>{});
        teacherTier[primary]![t.id] = 0;
      }
      final assigns = t.subjectAssignments ?? const <SubjectAssignment>[];
      for (final a in assigns) {
        final subj = _normalizeSubject(a.subjectId);
        if (subj.isEmpty) continue;
        teachersBySubject.putIfAbsent(subj, () => <User>[]);
        if (!teachersBySubject[subj]!.any((x) => x.id == t.id)) {
          teachersBySubject[subj]!.add(t);
        }
        teacherTier.putIfAbsent(subj, () => <String, int>{});
        final tier = switch (a.type) {
          SubjectAssignmentType.primary => 0,
          SubjectAssignmentType.additional => 1,
          SubjectAssignmentType.emergency => 2,
        };
        final existing = teacherTier[subj]![t.id];
        if (existing == null || tier < existing) {
          teacherTier[subj]![t.id] = tier;
        }
      }
    }

    final classMappingFallbacks = <Map<String, String>>[];
    final _classMappingFallbackKey = <String>{};
    final candidatesBySubjectAndClass = <String, Map<String, List<User>>>{};

    List<User> candidatesForSubjectAndClass(String subject, String classId) {
      final raw = teachersBySubject[subject] ?? const <User>[];
      if (raw.isEmpty) return const <User>[];

      final cache = candidatesBySubjectAndClass.putIfAbsent(
        subject,
        () => <String, List<User>>{},
      );
      if (cache.containsKey(classId)) return cache[classId]!;

      final specific = <User>[];
      final general = <User>[];
      for (final t in raw) {
        final set = assignedClassesByTeacher[t.id] ?? const <String>{};
        if (set.isEmpty) {
          general.add(t);
        } else if (set.contains(classId)) {
          specific.add(t);
        }
      }

      List<User> resolved;
      if (specific.isNotEmpty) {
        resolved = specific;
      } else if (general.isNotEmpty) {
        resolved = general;
      } else {
        resolved = raw;
        final key = '$subject|$classId';
        if (_classMappingFallbackKey.add(key)) {
          classMappingFallbacks.add({'subject': subject, 'classId': classId});
        }
      }

      cache[classId] = resolved;
      return resolved;
    }

    final remainingDemandByClass = <String, Map<String, int>>{};
    for (final classId in classIds) {
      final base = Map<String, int>.from(
        normalizedDemand[classId] ?? const <String, int>{},
      );
      for (final s in classSchedule[classId] ?? const <ScheduleSlot>[]) {
        if (activityPeriod != null && s.period == activityPeriod) continue;
        if (_isNonTeachingSubject(s.subject)) continue;
        if (s.subject.startsWith('منتظر')) continue;
        final subj = _normalizeSubject(s.subject);
        if (subj.isEmpty) continue;
        final current = base[subj] ?? 0;
        if (current > 0) base[subj] = current - 1;
      }
      base.removeWhere((k, v) => v <= 0);
      remainingDemandByClass[classId] = base;
    }

    final totalRequired = remainingDemandByClass.values
        .expand((m) => m.values)
        .fold<int>(0, (a, b) => a + b);
    final totalCapacity = classIds.fold<int>(0, (a, classId) {
      var c = 0;
      for (final day in _days) {
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] == false) c++;
        }
      }
      return a + c;
    });
    if (totalRequired != totalCapacity) {
      throw Exception(
        'استحالة جدولة: احتياج التدريس $totalRequired لا يساوي سعة الفصول $totalCapacity.',
      );
    }

    final totalQuotaRemaining = profiles.fold<int>(0, (a, p) {
      final used = teachingLoadByTeacher[p.teacherId] ?? 0;
      final rem = max(0, p.weeklyQuota - used);
      return a + rem;
    });
    if (totalQuotaRemaining < totalRequired) {
      throw Exception(
        'استحالة جدولة: مجموع الأنصبة المتبقية $totalQuotaRemaining أقل من الاحتياج $totalRequired.',
      );
    }

    final subjectDeficits = <String, int>{};
    for (final classId in classIds) {
      final demand = remainingDemandByClass[classId] ?? const <String, int>{};
      for (final e in demand.entries) {
        final subj = _normalizeSubject(e.key);
        if (subj.isEmpty) continue;
        if ((teachersBySubject[subj] ?? const <User>[]).isEmpty) {
          subjectDeficits[subj] = (subjectDeficits[subj] ?? 0) + e.value;
        }
      }
    }

    final slotVars = <_V2SlotVar>[];
    for (final classId in classIds) {
      for (final day in _days) {
        for (int p = 1; p <= _periodsPerDay; p++) {
          if (activityPeriod != null && p == activityPeriod) continue;
          if (classOccupancy[classId]?[day]?[p] == false) {
            slotVars.add(_V2SlotVar(classId: classId, day: day, period: p));
          }
        }
      }
    }

    slotVars.shuffle(rng);
    slotVars.sort((a, b) {
      final da = _days.indexOf(a.day);
      final db = _days.indexOf(b.day);
      if (da != db) return da.compareTo(db);
      if (a.period != b.period) return a.period.compareTo(b.period);
      return a.classId.compareTo(b.classId);
    });

    final classDaySubjectCount = <String, Map<String, Map<String, int>>>{};
    for (final classId in classIds) {
      classDaySubjectCount[classId] = {
        for (final d in _days) d: <String, int>{},
      };
    }

    final teacherDayTargets = _buildTeacherDayTargetsV2(
      profiles: profiles,
      rng: rng,
    );

    var nodes = 0;
    var backtracks = 0;
    var maxDepth = 0;
    Map<String, dynamic>? bestDeadEnd;
    var bestDeadEndDepth = -1;
    var bestPartialDepth = -1;
    var bestPartialStack = <_V2FlexAssignment>[];

    int maxConsecutiveIfAssigned(
      List<ScheduleSlot> slots,
      String day,
      int period,
    ) {
      final periods = slots
          .where((s) => s.day == day)
          .map((s) => s.period)
          .toList();
      periods.add(period);
      periods.sort();
      var best = 1;
      var cur = 1;
      for (int i = 1; i < periods.length; i++) {
        if (periods[i] == periods[i - 1] + 1) {
          cur++;
          if (cur > best) best = cur;
        } else {
          cur = 1;
        }
      }
      return best;
    }

    Map<String, dynamic> buildDeadEnd({
      required _V2SlotVar v,
      required String reason,
    }) {
      final remaining =
          remainingDemandByClass[v.classId] ?? const <String, int>{};
      final subjects =
          remaining.entries
              .where((e) => e.value > 0)
              .map((e) => _normalizeSubject(e.key))
              .toSet()
              .toList()
            ..sort((a, b) {
              final ca = candidatesForSubjectAndClass(a, v.classId).length;
              final cb = candidatesForSubjectAndClass(b, v.classId).length;
              if (ca != cb) return ca.compareTo(cb);
              return a.compareTo(b);
            });

      final top = subjects.take(3).toList();
      final perSubjectAvail = <String, int>{};
      for (final subj in top) {
        var avail = 0;
        for (final t in candidatesForSubjectAndClass(subj, v.classId)) {
          final tid = t.id;
          if (teacherOccupancy[tid]?[v.day]?[v.period] == true) continue;
          final prof = profilesById[tid];
          if (prof == null) continue;
          if (prof.blockedTimeSlots.contains('${v.day}:${v.period}')) continue;
          if ((teachingLoadByTeacher[tid] ?? 0) >= prof.weeklyQuota) continue;
          avail++;
        }
        perSubjectAvail[subj] = avail;
      }

      return {
        'classId': v.classId,
        'day': v.day,
        'period': v.period,
        'reason': reason,
        'remainingSubjectsTop': top
            .map((s) => _subjectNameById[s] ?? s)
            .toList(),
        'availableTeachersTop': perSubjectAvail,
      };
    }

    bool canAssign({
      required String teacherId,
      required String day,
      required int period,
    }) {
      if (teacherOccupancy[teacherId]?[day]?[period] == true) return false;
      final prof = profilesById[teacherId];
      if (prof == null) return false;
      if (prof.blockedTimeSlots.contains('$day:$period')) return false;
      if ((teachingLoadByTeacher[teacherId] ?? 0) >= prof.weeklyQuota) {
        return false;
      }
      if ((teacherNoSeventh?[teacherId] ?? false) &&
          noSeventhPeriodMode == 'hard' &&
          period == 7) {
        return false;
      }
      final policyMaxDaily = maxDailyLessonsPerTeacher ?? 0;
      if (policyMaxDaily > 0) {
        if ((teachingByTeacherByDay[teacherId]?[day] ?? 0) >= policyMaxDaily) {
          return false;
        }
      }
      final policyMaxConsecutive = maxConsecutiveLessonsPerTeacher ?? 0;
      if (policyMaxConsecutive > 0) {
        final slots = teacherSchedule[teacherId] ?? const <ScheduleSlot>[];
        final mx = maxConsecutiveIfAssigned(slots, day, period);
        if (mx > policyMaxConsecutive) return false;
      }
      return true;
    }

    double scoreChoice({
      required _V2SlotVar v,
      required String subject,
      required String teacherId,
    }) {
      final tier = teacherTier[subject]?[teacherId] ?? 9;
      final load = teachingLoadByTeacher[teacherId] ?? 0;
      final dayCount = teachingByTeacherByDay[teacherId]?[v.day] ?? 0;
      final classCount = classDaySubjectCount[v.classId]?[v.day]?[subject] ?? 0;
      var score = 0.0;
      score += tier * 4.0;
      score += load * 0.25;
      score += dayCount * 0.6;
      if (classCount >= 1) score += 1.5;
      if (classCount >= 2) score += 6.0;
      if (_isPreferredPeriodForSubject(subject, v.period)) score -= 0.8;
      if (v.period == 7) score += seventhPeriodPenalty;
      if ((teacherNoSeventh?[teacherId] ?? false) && v.period == 7) {
        score += noSeventhPeriodPenalty;
      }
      final softBlocked = teacherUnavailablePrefSlots?[teacherId];
      if (softBlocked != null && softBlocked.contains('${v.day}:${v.period}')) {
        score += unavailableSlotPenalty;
      }
      if ((teacherPreferConsecutive?[teacherId] ?? false) &&
          preferConsecutiveWeight != 0.0) {
        final dayPeriods =
            teacherSchedule[teacherId]
                ?.where((s) => s.day == v.day)
                .map((s) => s.period)
                .toSet() ??
            <int>{};
        if (dayPeriods.contains(v.period - 1) ||
            dayPeriods.contains(v.period + 1)) {
          score += preferConsecutiveWeight;
        }
      }
      final target = teacherDayTargets[teacherId]?[v.day] ?? 0;
      if (dayCount < target) score -= 0.4;
      score += rng.nextDouble() * 0.03;
      return score;
    }

    Future<bool> dfs(int index, List<_V2FlexAssignment> stack) async {
      if (DateTime.now().isAfter(deadline)) return false;
      if (nodes++ > maxNodes) return false;
      if (yieldEveryNodes > 0 && nodes % yieldEveryNodes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (index >= slotVars.length) return true;
      maxDepth = max(maxDepth, index);
      if (index > bestPartialDepth) {
        bestPartialDepth = index;
        bestPartialStack = List<_V2FlexAssignment>.from(stack);
      }

      final v = slotVars[index];
      final rem = remainingDemandByClass[v.classId] ?? const <String, int>{};
      final subjects = rem.entries
          .where((e) => e.value > 0)
          .map((e) => _normalizeSubject(e.key))
          .toList();
      if (subjects.isEmpty) {
        if (index > bestDeadEndDepth) {
          bestDeadEndDepth = index;
          bestDeadEnd = buildDeadEnd(
            v: v,
            reason: 'لا توجد مواد متبقية لهذا الفصل',
          );
        }
        return false;
      }

      subjects.sort((a, b) {
        final ca = candidatesForSubjectAndClass(a, v.classId).length;
        final cb = candidatesForSubjectAndClass(b, v.classId).length;
        if (ca != cb) return ca.compareTo(cb);
        final ra = rem[a] ?? 0;
        final rb = rem[b] ?? 0;
        if (ra != rb) return rb.compareTo(ra);
        return a.compareTo(b);
      });

      final choices = <Map<String, dynamic>>[];
      for (final subject in subjects.take(10)) {
        final classCount =
            classDaySubjectCount[v.classId]?[v.day]?[subject] ?? 0;
        if (classCount >= maxPerDayPerSubjectForClass) continue;
        final candidates = candidatesForSubjectAndClass(subject, v.classId);
        for (final t in candidates.take(18)) {
          if (!canAssign(teacherId: t.id, day: v.day, period: v.period))
            continue;
          final sc = scoreChoice(v: v, subject: subject, teacherId: t.id);
          choices.add({'subject': subject, 'teacherId': t.id, 'score': sc});
        }
      }
      if (choices.isEmpty) {
        if (index > bestDeadEndDepth) {
          bestDeadEndDepth = index;
          bestDeadEnd = buildDeadEnd(
            v: v,
            reason: 'لا يوجد معلم متاح ضمن القيود الصلبة',
          );
        }
        return false;
      }

      choices.shuffle(rng);
      choices.sort(
        (a, b) => (a['score'] as double).compareTo(b['score'] as double),
      );

      final limit = min(choices.length, 24);
      for (int i = 0; i < limit; i++) {
        final c = choices[i];
        final subject = c['subject'] as String;
        final teacherId = c['teacherId'] as String;

        final slot = ScheduleSlot(
          day: v.day,
          period: v.period,
          className: 'Class ${v.classId}',
          subject: subject,
          teacherId: teacherId,
        );

        teacherSchedule[teacherId]!.add(slot);
        classSchedule[v.classId]!.add(slot);
        teacherOccupancy[teacherId]![v.day]![v.period] = true;
        classOccupancy[v.classId]![v.day]![v.period] = true;
        teachingLoadByTeacher[teacherId] =
            (teachingLoadByTeacher[teacherId] ?? 0) + 1;
        teachingByTeacherByDay[teacherId]![v.day] =
            (teachingByTeacherByDay[teacherId]![v.day] ?? 0) + 1;
        classDaySubjectCount[v.classId]![v.day]![subject] =
            (classDaySubjectCount[v.classId]![v.day]![subject] ?? 0) + 1;

        remainingDemandByClass[v.classId]![subject] =
            (remainingDemandByClass[v.classId]![subject] ?? 1) - 1;

        stack.add(
          _V2FlexAssignment(v: v, subject: subject, teacherId: teacherId),
        );
        if (await dfs(index + 1, stack)) return true;
        stack.removeLast();

        remainingDemandByClass[v.classId]![subject] =
            (remainingDemandByClass[v.classId]![subject] ?? 0) + 1;
        if (remainingDemandByClass[v.classId]![subject] == 0) {
          remainingDemandByClass[v.classId]!.remove(subject);
        }

        classDaySubjectCount[v.classId]![v.day]![subject] =
            (classDaySubjectCount[v.classId]![v.day]![subject] ?? 1) - 1;
        if ((classDaySubjectCount[v.classId]![v.day]![subject] ?? 0) <= 0) {
          classDaySubjectCount[v.classId]![v.day]!.remove(subject);
        }

        teacherSchedule[teacherId]!.removeLast();
        classSchedule[v.classId]!.removeLast();
        teacherOccupancy[teacherId]![v.day]![v.period] = false;
        classOccupancy[v.classId]![v.day]![v.period] = false;
        teachingLoadByTeacher[teacherId] =
            (teachingLoadByTeacher[teacherId] ?? 1) - 1;
        teachingByTeacherByDay[teacherId]![v.day] =
            (teachingByTeacherByDay[teacherId]![v.day] ?? 1) - 1;

        backtracks++;
      }

      return false;
    }

    final stack = <_V2FlexAssignment>[];
    final ok = await dfs(0, stack);
    if (!ok) {
      String pickSubjectForClass(String classId) {
        final rem = remainingDemandByClass[classId];
        if (rem != null && rem.isNotEmpty) {
          MapEntry<String, int>? best;
          for (final e in rem.entries) {
            if (e.value <= 0) continue;
            if (best == null || e.value > best.value) best = e;
          }
          if (best != null) return _normalizeSubject(best.key);
        }
        final fallback = normalizedDemand[classId]?.keys.toList() ?? <String>[];
        fallback.sort();
        return fallback.isNotEmpty
            ? _normalizeSubject(fallback.first)
            : 'Arabic';
      }

      void decrementRemaining(String classId, String subject) {
        final rem = remainingDemandByClass[classId];
        if (rem == null) return;
        final k = rem.keys.firstWhere(
          (x) => _normalizeSubject(x) == subject,
          orElse: () => subject,
        );
        if (!rem.containsKey(k)) return;
        rem[k] = (rem[k] ?? 1) - 1;
        if ((rem[k] ?? 0) <= 0) rem.remove(k);
      }

      for (final a in bestPartialStack) {
        final v = a.v;
        if (classOccupancy[v.classId]?[v.day]?[v.period] == true) continue;
        final slot = ScheduleSlot(
          day: v.day,
          period: v.period,
          className: 'Class ${v.classId}',
          subject: a.subject,
          teacherId: a.teacherId,
        );
        teacherSchedule.putIfAbsent(a.teacherId, () => <ScheduleSlot>[]);
        teacherSchedule[a.teacherId]!.add(slot);
        classOccupancy[v.classId]![v.day]![v.period] = true;
        decrementRemaining(v.classId, _normalizeSubject(a.subject));
      }

      var unassignedCount = 0;
      for (int i = bestPartialStack.length; i < slotVars.length; i++) {
        final v = slotVars[i];
        if (classOccupancy[v.classId]?[v.day]?[v.period] == true) continue;
        final subject = pickSubjectForClass(v.classId);
        final tid = 'unassigned_${subject}_${v.classId}_${v.day}_${v.period}';
        final slot = ScheduleSlot(
          day: v.day,
          period: v.period,
          className: 'Class ${v.classId}',
          subject: subject,
          teacherId: tid,
        );
        teacherSchedule.putIfAbsent(tid, () => <ScheduleSlot>[]);
        teacherSchedule[tid]!.add(slot);
        classOccupancy[v.classId]![v.day]![v.period] = true;
        decrementRemaining(v.classId, subject);
        unassignedCount++;
      }

      final report = <String, dynamic>{
        'mode': 'flex',
        'nodes': nodes,
        'backtracks': backtracks,
        'maxDepth': maxDepth,
        'tasksTotal': slotVars.length,
        'deadEnd': bestDeadEnd,
        'fallbackUsed': true,
        'fallbackAppliedDepth': bestPartialDepth,
        'fallbackUnassignedSlots': unassignedCount,
        if (classMappingFallbacks.isNotEmpty)
          'classMappingFallbacks': classMappingFallbacks,
        'subjectDeficits': {
          for (final e in subjectDeficits.entries)
            (_subjectNameById[e.key] ?? e.key): e.value,
        },
        'relaxedConstraints': [
          'teacher_day_distribution',
          'subject_day_distribution',
        ],
      };

      return _CoreScheduleBuildResult(
        schedule: teacherSchedule,
        report: report,
      );
    }

    final teacherNameById = {for (final t in teachers) t.id: t.name};
    final teacherDayReport = <Map<String, dynamic>>[];
    for (final p in profiles) {
      final byDay =
          teachingByTeacherByDay[p.teacherId] ?? const <String, int>{};
      teacherDayReport.add({
        'teacherId': p.teacherId,
        'teacherName': teacherNameById[p.teacherId] ?? p.teacherId,
        'quota': p.weeklyQuota,
        'days': byDay,
        'total': byDay.values.fold<int>(0, (a, b) => a + b),
      });
    }

    final report = <String, dynamic>{
      'mode': 'flex',
      'nodes': nodes,
      'backtracks': backtracks,
      'maxDepth': maxDepth,
      'tasksTotal': slotVars.length,
      'teacherDays': teacherDayReport,
      'deadEnd': bestDeadEnd,
      if (classMappingFallbacks.isNotEmpty)
        'classMappingFallbacks': classMappingFallbacks,
      'subjectDeficits': {
        for (final e in subjectDeficits.entries)
          (_subjectNameById[e.key] ?? e.key): e.value,
      },
      'relaxedConstraints': [
        'teacher_day_distribution',
        'subject_day_distribution',
      ],
    };

    return _CoreScheduleBuildResult(schedule: teacherSchedule, report: report);
  }

  Future<_CoreScheduleBuildResult> _assignCoreSlotsV2(
    List<TeacherConstraintsProfile> profiles,
    List<User> teachers,
    List<String> classIds,
    School school,
    Map<String, List<ScheduleSlot>>? fixedSlots,
    Random rng,
    int? activityPeriod,
    Map<String, Map<String, int>> normalizedDemand, {
    Map<String, int>? remainderBySubject,
    Map<String, dynamic>? fractionReport,
    _V2Mode mode = _V2Mode.strict,
    int maxNodes = 60000,
    required DateTime deadline,
    int yieldEveryNodes = 1500,
    Map<String, Set<String>>? teacherUnavailablePrefSlots,
    Map<String, bool>? teacherNoSeventh,
    Map<String, bool>? teacherPreferConsecutive,
    double unavailableSlotPenalty = 12.0,
    String noSeventhPeriodMode = 'hard',
    double noSeventhPeriodPenalty = 18.0,
    double preferConsecutiveWeight = -0.9,
    int? maxDailyLessonsPerTeacher,
    int? maxConsecutiveLessonsPerTeacher,
    double seventhPeriodPenalty = 0.8,
    int maxPerDayPerSubjectForClass = 2,
  }) async {
    if (mode == _V2Mode.flex) {
      return await _buildCoreScheduleBacktrackingV2Flex(
        profiles: profiles,
        teachers: teachers,
        classIds: classIds,
        school: school,
        fixedSlots: fixedSlots,
        rng: rng,
        activityPeriod: activityPeriod,
        normalizedDemand: normalizedDemand,
        maxNodes: maxNodes,
        deadline: deadline,
        yieldEveryNodes: yieldEveryNodes,
        teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
        teacherNoSeventh: teacherNoSeventh,
        teacherPreferConsecutive: teacherPreferConsecutive,
        unavailableSlotPenalty: unavailableSlotPenalty,
        noSeventhPeriodMode: noSeventhPeriodMode,
        noSeventhPeriodPenalty: noSeventhPeriodPenalty,
        preferConsecutiveWeight: preferConsecutiveWeight,
        maxDailyLessonsPerTeacher: maxDailyLessonsPerTeacher,
        maxConsecutiveLessonsPerTeacher: maxConsecutiveLessonsPerTeacher,
        seventhPeriodPenalty: seventhPeriodPenalty,
        maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
      );
    }
    final core = await _buildCoreScheduleBacktrackingV2(
      profiles: profiles,
      teachers: teachers,
      classIds: classIds,
      school: school,
      fixedSlots: fixedSlots,
      rng: rng,
      activityPeriod: activityPeriod,
      normalizedDemand: normalizedDemand,
      maxNodes: maxNodes,
      deadline: deadline,
      yieldEveryNodes: yieldEveryNodes,
      teacherUnavailablePrefSlots: teacherUnavailablePrefSlots,
      teacherNoSeventh: teacherNoSeventh,
      teacherPreferConsecutive: teacherPreferConsecutive,
      unavailableSlotPenalty: unavailableSlotPenalty,
      noSeventhPeriodMode: noSeventhPeriodMode,
      noSeventhPeriodPenalty: noSeventhPeriodPenalty,
      preferConsecutiveWeight: preferConsecutiveWeight,
      maxDailyLessonsPerTeacher: maxDailyLessonsPerTeacher,
      maxConsecutiveLessonsPerTeacher: maxConsecutiveLessonsPerTeacher,
      seventhPeriodPenalty: seventhPeriodPenalty,
      maxPerDayPerSubjectForClass: maxPerDayPerSubjectForClass,
    );
    core.report['mode'] = 'strict';
    core.report['relaxedConstraints'] = const <String>[];
    return core;
  }

  void _optimizeScheduleGaps({
    required List<String> classIds,
    required Map<String, List<ScheduleSlot>> classSchedule,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required Map<String, Map<String, Map<int, bool>>> classOccupancy,
    required Map<String, Map<String, Map<int, bool>>> teacherOccupancy,
    required Map<String, Map<String, Map<String, int>>> classSubjectPerDay,
    required Map<String, Map<String, int>> classSubjectPerWeek,
    required Map<String, Map<String, int>> classDayLoad,
    required Map<String, Map<String, int>> normalizedDemand,
    required Map<String, List<User>> teachersBySubject,
    required Map<String, Map<String, int>> teacherTierBySubject,
    required Map<String, TeacherConstraintsProfile> profilesById,
  }) {
    // Identify gaps
    for (final classId in classIds) {
      for (final day in _days) {
        for (var period = 1; period <= _periodsPerDay; period++) {
          if (classOccupancy[classId]?[day]?[period] == true) continue;

          // Found a gap at (classId, day, period)
          // Find what subjects are needed
          final demand = normalizedDemand[classId] ?? {};
          String? bestSubject;
          int maxNeed = 0;

          demand.forEach((subject, needed) {
            final have = classSubjectPerWeek[classId]?[subject] ?? 0;
            if (have < needed) {
              if (needed - have > maxNeed) {
                maxNeed = needed - have;
                bestSubject = subject;
              }
            }
          });

          if (bestSubject == null) continue;

          // Try to find a teacher for bestSubject
          final teachers = List<User>.from(
            teachersBySubject[bestSubject] ?? const [],
          );
          teachers.sort((a, b) {
            final ta = teacherTierBySubject[bestSubject]?[a.id] ?? 0;
            final tb = teacherTierBySubject[bestSubject]?[b.id] ?? 0;
            return ta.compareTo(tb);
          });
          bool assigned = false;

          for (final t in teachers) {
            // Check if we can free this teacher at (day, period)
            // Similar to smart swapping but focused on gaps
            if (teacherOccupancy[t.id]?[day]?[period] == true) {
              final conflictSlot = teacherSchedule[t.id]!.firstWhere(
                (s) => s.day == day && s.period == period,
                orElse: () => ScheduleSlot(
                  day: '',
                  period: -1,
                  className: '',
                  subject: '',
                  teacherId: '',
                ),
              );
              if (conflictSlot.period == -1) continue;

              final conflictClassId = conflictSlot.className.replaceFirst(
                'Class ',
                '',
              );

              // Try to move conflictSlot to ANY other free slot
              for (final altDay in _days) {
                for (
                  var altPeriod = 1;
                  altPeriod <= _periodsPerDay;
                  altPeriod++
                ) {
                  if (altDay == day && altPeriod == period) continue;

                  if (classOccupancy[conflictClassId]?[altDay]?[altPeriod] ==
                          false &&
                      teacherOccupancy[t.id]?[altDay]?[altPeriod] == false) {
                    if (!_canAssignSameSubjectForTeacherDay(
                      teacherSchedule: teacherSchedule,
                      teacherId: t.id,
                      day: altDay,
                      subject: conflictSlot.subject,
                    )) {
                      continue;
                    }
                    // Perform Move
                    teacherSchedule[t.id]!.removeWhere(
                      (s) => s == conflictSlot,
                    );
                    classSchedule[conflictClassId]!.removeWhere(
                      (s) => s == conflictSlot,
                    );

                    final newSlot = ScheduleSlot(
                      day: altDay,
                      period: altPeriod,
                      className: conflictSlot.className,
                      subject: conflictSlot.subject,
                      teacherId: t.id,
                    );
                    teacherSchedule[t.id]!.add(newSlot);
                    classSchedule[conflictClassId]!.add(newSlot);

                    teacherOccupancy[t.id]![day]![period] = false;
                    teacherOccupancy[t.id]![altDay]![altPeriod] = true;

                    classOccupancy[conflictClassId]![day]![period] = false;
                    classOccupancy[conflictClassId]![altDay]![altPeriod] = true;

                    // Assign original gap
                    if (!_canAssignSameSubjectForTeacherDay(
                      teacherSchedule: teacherSchedule,
                      teacherId: t.id,
                      day: day,
                      subject: bestSubject!,
                    )) {
                      continue;
                    }
                    final fillSlot = ScheduleSlot(
                      day: day,
                      period: period,
                      className: 'Class $classId',
                      subject: bestSubject!,
                      teacherId: t.id,
                    );
                    teacherSchedule[t.id]!.add(fillSlot);
                    classSchedule[classId]!.add(fillSlot);

                    teacherOccupancy[t.id]![day]![period] = true;
                    classOccupancy[classId]![day]![period] = true;
                    classSubjectPerWeek[classId]![bestSubject!] =
                        (classSubjectPerWeek[classId]![bestSubject!] ?? 0) + 1;

                    assigned = true;
                    break;
                  }
                }
                if (assigned) break;
              }
            } else {
              // Teacher is free! Just assign.
              // Check constraints (quota, max per day)
              // For optimization, we might relax constraints slightly or just enforce strict
              // Here enforcing strict basic availability
              if (profilesById[t.id]!.blockedTimeSlots.contains('$day:$period'))
                continue;
              final currentTeachingLoad =
                  teacherSchedule[t.id]
                      ?.where((s) => !_isNonTeachingSubject(s.subject))
                      .length ??
                  0;
              if (currentTeachingLoad >= profilesById[t.id]!.weeklyQuota) {
                continue;
              }
              if (!_canAssignSameSubjectForTeacherDay(
                teacherSchedule: teacherSchedule,
                teacherId: t.id,
                day: day,
                subject: bestSubject!,
              )) {
                continue;
              }

              final fillSlot = ScheduleSlot(
                day: day,
                period: period,
                className: 'Class $classId',
                subject: bestSubject!,
                teacherId: t.id,
              );
              teacherSchedule[t.id]!.add(fillSlot);
              classSchedule[classId]!.add(fillSlot);
              teacherOccupancy[t.id]![day]![period] = true;
              classOccupancy[classId]![day]![period] = true;
              classSubjectPerWeek[classId]![bestSubject!] =
                  (classSubjectPerWeek[classId]![bestSubject!] ?? 0) + 1;
              assigned = true;
              break;
            }
            if (assigned) break;
          }

          // AGGRESSIVE FILLING: If strict matching failed, try any teacher with relaxed rules
          if (!assigned) {
            // First pass: Try teachers who teach 'General' or similar subjects (often flexible)
            final generalTeachers = teachersBySubject['General'] ?? [];
            for (final t in generalTeachers) {
              if (teacherOccupancy[t.id]?[day]?[period] == false &&
                  !profilesById[t.id]!.blockedTimeSlots.contains(
                    '$day:$period',
                  )) {
                final currentTeachingLoad =
                    teacherSchedule[t.id]
                        ?.where((s) => !_isNonTeachingSubject(s.subject))
                        .length ??
                    0;
                if (currentTeachingLoad >= profilesById[t.id]!.weeklyQuota) {
                  continue;
                }
                if (!_canAssignSameSubjectForTeacherDay(
                  teacherSchedule: teacherSchedule,
                  teacherId: t.id,
                  day: day,
                  subject: bestSubject!,
                )) {
                  continue;
                }
                final fillSlot = ScheduleSlot(
                  day: day,
                  period: period,
                  className: 'Class $classId',
                  subject: bestSubject!, // Keep original subject name
                  teacherId: t.id,
                );
                teacherSchedule[t.id]!.add(fillSlot);
                classSchedule[classId]!.add(fillSlot);
                teacherOccupancy[t.id]![day]![period] = true;
                classOccupancy[classId]![day]![period] = true;
                classSubjectPerWeek[classId]![bestSubject!] =
                    (classSubjectPerWeek[classId]![bestSubject!] ?? 0) + 1;
                assigned = true;
                break;
              }
            }

            // Second pass: NUCLEAR OPTION - Try ANY free teacher
            if (!assigned) {
              // Get all teacher IDs
              final allTeacherIds = profilesById.keys.toList();
              // Shuffle for fairness
              allTeacherIds.shuffle();

              for (final tid in allTeacherIds) {
                // Check if teacher is free OR has a waiting slot we can override
                final isFree = teacherOccupancy[tid]?[day]?[period] == false;
                final isBlocked = profilesById[tid]!.blockedTimeSlots.contains(
                  '$day:$period',
                );

                if (isBlocked) continue;

                bool canAssign = false;
                ScheduleSlot? slotToRemove;

                if (isFree) {
                  canAssign = true;
                } else {
                  // Check if they have a 'Waiting' slot here
                  final existingSlot = teacherSchedule[tid]?.firstWhere(
                    (s) => s.day == day && s.period == period,
                    orElse: () => ScheduleSlot(
                      day: '',
                      period: -1,
                      className: '',
                      subject: '',
                      teacherId: '',
                    ),
                  );

                  if (existingSlot != null &&
                      existingSlot.period != -1 &&
                      existingSlot.subject.startsWith('منتظر')) {
                    // We can override this waiting slot!
                    canAssign = true;
                    slotToRemove = existingSlot;
                  }
                }

                if (canAssign) {
                  final currentTeachingLoad =
                      teacherSchedule[tid]
                          ?.where((s) => !_isNonTeachingSubject(s.subject))
                          .length ??
                      0;
                  if (currentTeachingLoad + 1 >
                      profilesById[tid]!.weeklyQuota) {
                    continue;
                  }
                  if (!_canAssignSameSubjectForTeacherDay(
                    teacherSchedule: teacherSchedule,
                    teacherId: tid,
                    day: day,
                    subject: bestSubject!,
                  )) {
                    continue;
                  }
                  if (slotToRemove != null) {
                    teacherSchedule[tid]!.remove(slotToRemove);
                    // Occupancy remains true, but we swapped the activity
                  }

                  final fillSlot = ScheduleSlot(
                    day: day,
                    period: period,
                    className: 'Class $classId',
                    subject: bestSubject!,
                    teacherId: tid,
                  );
                  teacherSchedule[tid]!.add(fillSlot);
                  classSchedule[classId]!.add(fillSlot);
                  teacherOccupancy[tid]![day]![period] = true;
                  classOccupancy[classId]![day]![period] = true;
                  classSubjectPerWeek[classId]![bestSubject!] =
                      (classSubjectPerWeek[classId]![bestSubject!] ?? 0) + 1;
                  assigned = true;
                  break;
                }
              }
            }
          }
        }
      }
    }
  }

  User? _pickBestTeacherForSlot({
    required String subject,
    required String day,
    required int period,
    required List<User> teachers,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required Map<String, Map<String, Map<int, bool>>> teacherOccupancy,
    required Map<String, TeacherConstraintsProfile> profiles,
    Map<String, int>? tierByTeacherId,
    bool ignoreQuota = false,
  }) {
    User? best;
    int? bestScore;

    for (final t in teachers) {
      final profile = profiles[t.id];
      if (profile == null) continue;

      if (!ignoreQuota) {
        final currentTeachingLoad =
            teacherSchedule[t.id]
                ?.where((s) => !_isNonTeachingSubject(s.subject))
                .length ??
            0;
        if (currentTeachingLoad >= profile.weeklyQuota) {
          continue;
        }
      }

      if (!_canAssignSameSubjectForTeacherDay(
        teacherSchedule: teacherSchedule,
        teacherId: t.id,
        day: day,
        subject: subject,
      )) {
        continue;
      }

      if (teacherOccupancy[t.id]?[day]?[period] == true) continue;
      if (profile.blockedTimeSlots.contains('$day:$period')) continue;

      final totalSlots = teacherSchedule[t.id]?.length ?? 0;
      final daySlots =
          teacherSchedule[t.id]
              ?.where((s) => s.day == day && !_isNonTeachingSubject(s.subject))
              .length ??
          0;

      int subjectSlots = 0;
      int consecutivePenalty = 0;
      int lastPeriod = -100;
      for (final s in teacherSchedule[t.id] ?? const []) {
        if (s.day != day) continue;
        if (s.subject == subject) {
          subjectSlots++;
        }
        if (s.period == lastPeriod + 1) {
          consecutivePenalty++;
        }
        lastPeriod = s.period;
      }

      var score = 0;
      score -= totalSlots * 2;
      score -= daySlots * 3;
      score -= subjectSlots;
      score -= consecutivePenalty * 5;
      score += (tierByTeacherId?[t.id] ?? 0) * 100000;

      if (best == null || score < bestScore!) {
        best = t;
        bestScore = score;
      }
    }

    return best;
  }

  void _fillRemainingClassSlotsWithCoreSubjects({
    required List<String> classIds,
    required Map<String, List<ScheduleSlot>> classSchedule,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required Map<String, Map<String, Map<int, bool>>> classOccupancy,
    required Map<String, Map<String, Map<int, bool>>> teacherOccupancy,
    required Map<String, Map<String, Map<String, int>>> classSubjectPerDay,
    required Map<String, Map<String, int>> classSubjectPerWeek,
    required Map<String, Map<String, int>> classDayLoad,
    required Map<String, Map<String, int>> normalizedDemand,
    required Map<String, List<User>> teachersBySubject,
    required Map<String, Map<String, int>> teacherTierBySubject,
    required Map<String, TeacherConstraintsProfile> profilesById,
  }) {
    for (final classId in classIds) {
      final classDemand = normalizedDemand[classId] ?? const {};
      if (classDemand.isEmpty) continue;

      final subjects = classDemand.keys.toList();
      final coreSubjects = subjects
          .where((s) => _subjectLayer(s) == 'A')
          .toList();
      final secondarySubjects = subjects
          .where((s) => _subjectLayer(s) == 'B')
          .toList();
      if (coreSubjects.isEmpty && secondarySubjects.isEmpty) continue;

      for (final day in _days) {
        for (var period = 1; period <= _periodsPerDay; period++) {
          if (classOccupancy[classId]?[day]?[period] == true) continue;

          // Prevent Double Booking in Backfilling: Check if class already has this subject today
          // REMOVED: Incorrectly placed here, `subject` is not defined yet.
          // if (classSubjectPerDay[classId]![day]!.containsKey(subject) &&
          //     classSubjectPerDay[classId]![day]![subject]! > 0) {
          //   continue;
          // }

          final candidates = [...coreSubjects, ...secondarySubjects];

          bool placed = false;
          for (final subject in candidates) {
            final weeklyDemand = classDemand[subject] ?? 0;
            final currentWeek = classSubjectPerWeek[classId]?[subject] ?? 0;

            if (weeklyDemand > 0 && currentWeek >= weeklyDemand + 2) {
              continue;
            }

            // Prevent Double Booking inside candidate loop as well
            if (classSubjectPerDay[classId]![day]!.containsKey(subject) &&
                classSubjectPerDay[classId]![day]![subject]! > 0) {
              continue;
            }

            final dayMap = classSubjectPerDay[classId]![day]!;
            final currentDayCount = dayMap[subject] ?? 0;
            final baseWeekly = weeklyDemand > 0 ? weeklyDemand : 5;
            final maxPerDay = _computeMaxPerDayForSubject(
              subject: subject,
              weeklyDemandForClass: baseWeekly,
            );
            if (currentDayCount >= maxPerDay + 1) {
              continue;
            }

            final teacherList = teachersBySubject[subject] ?? const [];
            if (teacherList.isEmpty) continue;

            var teacher = _pickBestTeacherForSlot(
              subject: subject,
              day: day,
              period: period,
              teachers: teacherList,
              teacherSchedule: teacherSchedule,
              teacherOccupancy: teacherOccupancy,
              profiles: profilesById,
              tierByTeacherId: teacherTierBySubject[subject],
            );

            if (teacher == null) {
              continue;
            }

            final slot = ScheduleSlot(
              day: day,
              period: period,
              className: 'Class $classId',
              subject: subject,
              teacherId: teacher.id,
            );

            teacherSchedule[teacher.id]!.add(slot);
            classSchedule[classId]!.add(slot);
            teacherOccupancy[teacher.id]![day]![period] = true;
            classOccupancy[classId]![day]![period] = true;

            classSubjectPerWeek[classId]![subject] = currentWeek + 1;
            dayMap[subject] = currentDayCount + 1;
            classDayLoad[classId]![day] =
                (classDayLoad[classId]![day] ?? 0) + 1;

            placed = true;
            break;
          }

          if (!placed) {
            continue;
          }
        }
      }
    }
  }

  Map<String, dynamic>? _pickMostDemandingClassSubjectBalanced({
    required Map<String, Map<String, int>> classRemainingDemand,
    required Map<String, List<ScheduleSlot>> classSchedule,
    required Random rng,
  }) {
    String? bestClassId;
    String? bestSubject;
    int bestRemaining = 0;
    // We prioritize subjects with High Difficulty (Layer A > B > C)
    // Difficulty Score = Remaining * Weight
    // Weight: A=3, B=2, C=1

    double bestScore = -1.0;

    classRemainingDemand.forEach((classId, subjectMap) {
      subjectMap.forEach((subject, remaining) {
        if (remaining <= 0) return;

        final layer = _subjectLayer(subject);
        int weight = 1;
        if (layer == 'A') weight = 5; // Critical Subjects first
        if (layer == 'B') weight = 3;

        // Also consider total class load (balance across classes)
        // If a class is empty, prioritize it slightly to get it started
        final classLoad = classSchedule[classId]?.length ?? 0;
        final balanceFactor = (100 - classLoad) / 100.0; // Higher if empty

        // Add significant random noise to break ties and ensure variety
        final noise = rng.nextDouble() * 2.0; // Up to 2.0 points of randomness

        final score = (remaining * weight) + balanceFactor + noise;

        if (score > bestScore) {
          bestClassId = classId;
          bestSubject = subject;
          bestRemaining = remaining;
          bestScore = score;
        }
      });
    });

    if (bestClassId == null || bestSubject == null) {
      return null;
    }
    return {
      'classId': bestClassId,
      'subject': bestSubject,
      'remaining': bestRemaining,
    };
  }

  Map<String, Map<String, int>> _buildClassWeeklyDemandFromSupply({
    required List<String> classIds,
    int? activityPeriod,
  }) {
    final demand = <String, Map<String, int>>{};
    for (final classId in classIds) {
      demand[classId] = {};
    }

    final effectivePeriodsPerDay =
        _periodsPerDay - (activityPeriod != null ? 1 : 0);
    final totalSlotsNeededPerClass =
        _days.length * effectivePeriodsPerDay; // Usually 35 or 30
    final weights = Map<String, int>.from(_subjectWeights)
      ..removeWhere((k, v) => v <= 0);

    if (weights.isEmpty) {
      return demand;
    }

    final sum = weights.values.fold<int>(0, (a, b) => a + b);
    final entries = weights.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final perClass = <String, int>{};
    if (sum == totalSlotsNeededPerClass) {
      for (final e in entries) {
        perClass[e.key] = e.value;
      }
    } else if (sum > 0) {
      final floors = <String, int>{};
      final fracs = <String, double>{};
      var used = 0;
      for (final e in entries) {
        final scaled = totalSlotsNeededPerClass * (e.value / sum);
        final floorVal = scaled.floor();
        floors[e.key] = floorVal;
        fracs[e.key] = scaled - floorVal;
        used += floorVal;
      }
      var remainder = totalSlotsNeededPerClass - used;
      final ordered = entries.map((e) => e.key).toList()
        ..sort((a, b) {
          final fa = fracs[a] ?? 0.0;
          final fb = fracs[b] ?? 0.0;
          if (fa != fb) return fb.compareTo(fa);
          return a.compareTo(b);
        });

      perClass.addAll(floors);
      var i = 0;
      while (remainder > 0 && ordered.isNotEmpty) {
        final key = ordered[i % ordered.length];
        perClass[key] = (perClass[key] ?? 0) + 1;
        remainder--;
        i++;
      }
    }

    for (final classId in classIds) {
      demand[classId] = Map<String, int>.from(perClass);
    }

    return demand;
  }

  // 🧠 Phase 3: Smart Triple Waiting Assignment
  Map<String, dynamic> _assignWaitingSlots(
    Map<String, List<ScheduleSlot>> currentSchedule,
    List<TeacherConstraintsProfile> profiles,
    Map<String, List<TeacherConstraintsProfile>> categories, {
    int waitingSlotsPerPeriod = 3,
    String policy = 'tiers',
    Map<int, Map<int, int>>? customRules,
    Map<String, TeacherPreferenceEntity>? teacherPreferences,
  }) {
    final ordinalNames = ['أول', 'ثاني', 'ثالث', 'رابع', 'خامس'];

    final profilesById = {for (final p in profiles) p.teacherId: p};

    final baseSchedule = <String, List<ScheduleSlot>>{};
    for (final entry in currentSchedule.entries) {
      baseSchedule[entry.key] = entry.value
          .where((s) => !s.subject.startsWith('منتظر'))
          .toList();
    }
    for (final p in profiles) {
      baseSchedule.putIfAbsent(p.teacherId, () => <ScheduleSlot>[]);
    }

    final tierSpecs = <_WaitingTierSpec>[
      const _WaitingTierSpec(
        name: 'ideal',
        allowDuplicatePerDay: false,
        allowHighLoadExtra: false,
      ),
      const _WaitingTierSpec(
        name: 'flex_1',
        allowDuplicatePerDay: true,
        allowHighLoadExtra: false,
      ),
      const _WaitingTierSpec(
        name: 'flex_2',
        allowDuplicatePerDay: true,
        allowHighLoadExtra: true,
      ),
    ];

    final requiredTotal = _days.length * _periodsPerDay * waitingSlotsPerPeriod;
    final attemptCount = requiredTotal <= 50 ? 10 : 6;
    final baseRng = Random(DateTime.now().microsecondsSinceEpoch);

    Map<String, List<ScheduleSlot>>? bestSchedule;
    Map<String, dynamic>? bestReport;
    int bestUncovered = 1 << 30;
    int bestPenalty = 1 << 30;
    int attemptsRun = 0;

    for (int attempt = 0; attempt < attemptCount; attempt++) {
      attemptsRun++;
      final rng = Random(baseRng.nextInt(1 << 30) ^ (attempt * 9973));
      final schedule = <String, List<ScheduleSlot>>{
        for (final entry in baseSchedule.entries)
          entry.key: List<ScheduleSlot>.from(entry.value),
      };

      final report = _runWaitingOptimizationAttempt(
        schedule: schedule,
        profiles: profiles,
        profilesById: profilesById,
        categories: categories,
        ordinalNames: ordinalNames,
        waitingSlotsPerPeriod: waitingSlotsPerPeriod,
        tiers: tierSpecs,
        rng: rng,
      );

      final uncovered = (report['uncoveredSlots'] as List?)?.length ?? 0;
      final penalty = (report['penaltyScore'] as num?)?.toInt() ?? 0;

      if (uncovered < bestUncovered ||
          (uncovered == bestUncovered && penalty < bestPenalty)) {
        bestUncovered = uncovered;
        bestPenalty = penalty;
        bestSchedule = schedule;
        bestReport = report;
      }

      if (bestUncovered == 0) break;
    }

    if (bestSchedule != null) {
      currentSchedule
        ..clear()
        ..addAll(bestSchedule);
    }

    if (bestReport != null) {
      bestReport['attemptsTried'] = attemptsRun;
      bestReport['bestUncovered'] = bestUncovered;
    }

    return bestReport ??
        <String, dynamic>{
          'attempts': 0,
          'attemptsTried': attemptsRun,
          'bestUncovered': bestUncovered,
          'tiersUsed': <Map<String, dynamic>>[],
          'uncoveredSlots': <Map<String, dynamic>>[],
          'penaltyScore': 0,
        };
  }

  Map<String, dynamic> _runWaitingOptimizationAttempt({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required Map<String, List<TeacherConstraintsProfile>> categories,
    required List<String> ordinalNames,
    required int waitingSlotsPerPeriod,
    required List<_WaitingTierSpec> tiers,
    required Random rng,
  }) {
    final baseBusy = <String, Map<String, Set<int>>>{};
    for (final entry in schedule.entries) {
      final teacherId = entry.key;
      final perDay = <String, Set<int>>{};
      for (final s in entry.value) {
        perDay.putIfAbsent(s.day, () => <int>{}).add(s.period);
      }
      baseBusy[teacherId] = perDay;
    }

    int totalAssignments = 0;
    int totalMoves = 0;
    int totalSwaps = 0;
    final tiersUsed = <Map<String, dynamic>>[];
    final relaxed = <String>[];

    for (final tier in tiers) {
      final busy = <String, Map<String, Set<int>>>{
        for (final entry in baseBusy.entries)
          entry.key: {
            for (final d in entry.value.entries) d.key: Set<int>.from(d.value),
          },
      };

      final waitingByTeacherByDay = <String, Map<String, Set<int>>>{};
      final waitingCountByTeacher = <String, int>{};
      final assignedTodayByDay = <String, Set<String>>{
        for (final d in _days) d: <String>{},
      };
      final coverageByDay = <String, Map<int, int>>{
        for (final d in _days)
          d: {for (int p = 1; p <= _periodsPerDay; p++) p: 0},
      };

      for (final entry in schedule.entries) {
        final teacherId = entry.key;
        for (final s in entry.value) {
          if (!s.subject.startsWith('منتظر')) continue;
          busy.putIfAbsent(teacherId, () => <String, Set<int>>{});
          busy[teacherId]!.putIfAbsent(s.day, () => <int>{}).add(s.period);
          waitingByTeacherByDay
              .putIfAbsent(teacherId, () => <String, Set<int>>{})
              .putIfAbsent(s.day, () => <int>{})
              .add(s.period);
          waitingCountByTeacher[teacherId] =
              (waitingCountByTeacher[teacherId] ?? 0) + 1;
          assignedTodayByDay
              .putIfAbsent(s.day, () => <String>{})
              .add(teacherId);
          if (coverageByDay.containsKey(s.day)) {
            coverageByDay[s.day]![s.period] =
                (coverageByDay[s.day]![s.period] ?? 0) + 1;
          }
        }
      }

      final capRemaining = _buildWaitingCapacity(
        profiles: profiles,
        categories: categories,
        waitingSlotsPerPeriod: waitingSlotsPerPeriod,
        allowHighLoadExtra: tier.allowHighLoadExtra,
        waitingCountByTeacher: waitingCountByTeacher,
      );

      final tierResult = _fillWaitingTier(
        schedule: schedule,
        profiles: profiles,
        profilesById: profilesById,
        ordinalNames: ordinalNames,
        waitingSlotsPerPeriod: waitingSlotsPerPeriod,
        allowDuplicatePerDay: tier.allowDuplicatePerDay,
        capRemaining: capRemaining,
        busy: busy,
        waitingByTeacherByDay: waitingByTeacherByDay,
        waitingCountByTeacher: waitingCountByTeacher,
        assignedTodayByDay: assignedTodayByDay,
        coverageByDay: coverageByDay,
        rng: rng,
        onMove: () => totalMoves++,
        onSwap: () => totalSwaps++,
      );

      totalAssignments += (tierResult['assigned'] as int?) ?? 0;

      tiersUsed.add({
        'tier': tier.name,
        'allowDuplicatePerDay': tier.allowDuplicatePerDay,
        'allowHighLoadExtra': tier.allowHighLoadExtra,
        'iterations': (tierResult['iterations'] as int?) ?? 0,
        'assigned': (tierResult['assigned'] as int?) ?? 0,
        'remainingUncovered': ((tierResult['uncovered'] as List?)?.length ?? 0),
      });

      if (tier.allowDuplicatePerDay) {
        relaxed.add('allowDuplicatePerDay');
      }
      if (tier.allowHighLoadExtra) {
        relaxed.add('allowHighLoadExtra');
      }

      if (((tierResult['uncovered'] as List?)?.isEmpty ?? true)) {
        break;
      }
    }

    final uncovered = _diagnoseUncoveredWaiting(
      schedule: schedule,
      profiles: profiles,
      profilesById: profilesById,
      waitingSlotsPerPeriod: waitingSlotsPerPeriod,
    );

    final waitingCounts = profiles
        .map((p) => schedule[p.teacherId] ?? const <ScheduleSlot>[])
        .map(
          (slots) => slots.where((s) => s.subject.startsWith('منتظر')).length,
        )
        .toList();
    final variance = _calculateVariance(waitingCounts);
    final penaltyScore =
        ((variance * 100).round()) + (totalMoves * 3) + (totalSwaps * 5);

    final suggestions = _suggestWaitingFixes(uncovered);

    return {
      'attempts': 1,
      'tiersUsed': tiersUsed,
      'retries': totalAssignments,
      'moves': totalMoves,
      'swaps': totalSwaps,
      'relaxedConstraints': relaxed.toSet().toList(),
      'uncoveredSlots': uncovered,
      'penaltyScore': penaltyScore,
      'suggestions': suggestions,
    };
  }

  Map<String, int> _buildWaitingCapacity({
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, List<TeacherConstraintsProfile>> categories,
    required int waitingSlotsPerPeriod,
    required bool allowHighLoadExtra,
    required Map<String, int> waitingCountByTeacher,
  }) {
    final caps = <String, int>{};
    for (final p in profiles) {
      final existingWaiting = waitingCountByTeacher[p.teacherId] ?? 0;
      final remainingQuota = p.weeklyQuota - p.currentLoad - existingWaiting;
      if (remainingQuota <= 0) {
        caps[p.teacherId] = 0;
        continue;
      }
      if (p.currentLoad >= p.weeklyQuota) {
        caps[p.teacherId] = 0;
        continue;
      }
      if (categories['C']?.contains(p) == true) {
        caps[p.teacherId] = 0;
        continue;
      }
      if (p.hasAdministrativeDuties) {
        caps[p.teacherId] = min(1, remainingQuota);
        continue;
      }
      if (waitingSlotsPerPeriod == 1) {
        caps[p.teacherId] = min(5, remainingQuota);
        continue;
      }
      final load = p.currentLoad;
      final base = (p.weeklyQuota - load).clamp(0, 5);
      final relaxed = (base == 0 && allowHighLoadExtra) ? 1 : base;
      caps[p.teacherId] = min(relaxed, remainingQuota);
    }
    return caps;
  }

  Map<String, dynamic> _fillWaitingTier({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required List<String> ordinalNames,
    required int waitingSlotsPerPeriod,
    required bool allowDuplicatePerDay,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Map<String, Set<int>>> waitingByTeacherByDay,
    required Map<String, int> waitingCountByTeacher,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, Map<int, int>> coverageByDay,
    required Random rng,
    required void Function() onMove,
    required void Function() onSwap,
  }) {
    int iterations = 0;
    int assigned = 0;
    final tried = <String>{};

    while (iterations < 600) {
      final uncovered = _listUncoveredWaiting(
        coverageByDay: coverageByDay,
        waitingSlotsPerPeriod: waitingSlotsPerPeriod,
      );
      if (uncovered.isEmpty) {
        return {
          'iterations': iterations,
          'assigned': assigned,
          'uncovered': <Map<String, dynamic>>[],
        };
      }

      uncovered.shuffle(rng);
      uncovered.sort((a, b) {
        final ca = _countCandidatesForWaiting(
          day: a.day,
          period: a.period,
          level: a.level,
          profiles: profiles,
          profilesById: profilesById,
          allowDuplicatePerDay: allowDuplicatePerDay,
          capRemaining: capRemaining,
          busy: busy,
          assignedTodayByDay: assignedTodayByDay,
          waitingCountByTeacher: waitingCountByTeacher,
        );
        final cb = _countCandidatesForWaiting(
          day: b.day,
          period: b.period,
          level: b.level,
          profiles: profiles,
          profilesById: profilesById,
          allowDuplicatePerDay: allowDuplicatePerDay,
          capRemaining: capRemaining,
          busy: busy,
          assignedTodayByDay: assignedTodayByDay,
          waitingCountByTeacher: waitingCountByTeacher,
        );
        if (ca != cb) return ca.compareTo(cb);
        final da = _days.indexOf(a.day);
        final db = _days.indexOf(b.day);
        if (da != db) return da.compareTo(db);
        return a.period.compareTo(b.period);
      });

      final target = uncovered.first;
      final key = '${target.day}:${target.period}:${target.level}';
      if (tried.contains(key) && tried.length >= uncovered.length) {
        break;
      }

      final ok = _assignOrRepairWaiting(
        day: target.day,
        period: target.period,
        level: target.level,
        schedule: schedule,
        profiles: profiles,
        profilesById: profilesById,
        ordinalNames: ordinalNames,
        allowDuplicatePerDay: allowDuplicatePerDay,
        capRemaining: capRemaining,
        busy: busy,
        waitingByTeacherByDay: waitingByTeacherByDay,
        waitingCountByTeacher: waitingCountByTeacher,
        assignedTodayByDay: assignedTodayByDay,
        coverageByDay: coverageByDay,
        rng: rng,
        onMove: onMove,
        onSwap: onSwap,
      );

      if (ok) {
        assigned++;
        tried.clear();
      } else {
        tried.add(key);
      }
      iterations++;
    }

    final stillUncovered = _listUncoveredWaiting(
      coverageByDay: coverageByDay,
      waitingSlotsPerPeriod: waitingSlotsPerPeriod,
    );
    return {
      'iterations': iterations,
      'assigned': assigned,
      'uncovered': stillUncovered.map((k) => k.toJson()).toList(),
    };
  }

  List<_WaitingKey> _listUncoveredWaiting({
    required Map<String, Map<int, int>> coverageByDay,
    required int waitingSlotsPerPeriod,
  }) {
    final uncovered = <_WaitingKey>[];
    for (final day in _days) {
      for (int period = 1; period <= _periodsPerDay; period++) {
        final current = coverageByDay[day]?[period] ?? 0;
        for (int level = current + 1; level <= waitingSlotsPerPeriod; level++) {
          uncovered.add(_WaitingKey(day: day, period: period, level: level));
        }
      }
    }
    return uncovered;
  }

  int _countCandidatesForWaiting({
    required String day,
    required int period,
    required int level,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required bool allowDuplicatePerDay,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, int> waitingCountByTeacher,
  }) {
    int count = 0;
    for (final p in profiles) {
      final tid = p.teacherId;
      if ((capRemaining[tid] ?? 0) <= 0) continue;
      final profile = profilesById[tid];
      if (profile == null) continue;
      if (profile.currentLoad >= profile.weeklyQuota) continue;
      final totalLoad = profile.currentLoad + (waitingCountByTeacher[tid] ?? 0);
      if (totalLoad >= profile.weeklyQuota) continue;
      final remainingTeaching = (profile.weeklyQuota - profile.currentLoad)
          .clamp(0, 1000);
      final minLevel = remainingTeaching <= 0
          ? 999
          : (remainingTeaching == 1 ? 3 : (remainingTeaching == 2 ? 2 : 1));
      if (level < minLevel) continue;
      if (profile.blockedTimeSlots.contains('$day:$period')) continue;
      if (busy[tid]?[day]?.contains(period) == true) continue;
      if (!allowDuplicatePerDay &&
          (assignedTodayByDay[day]?.contains(tid) == true)) {
        continue;
      }
      count++;
    }
    return count;
  }

  bool _assignOrRepairWaiting({
    required String day,
    required int period,
    required int level,
    required Map<String, List<ScheduleSlot>> schedule,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required List<String> ordinalNames,
    required bool allowDuplicatePerDay,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Map<String, Set<int>>> waitingByTeacherByDay,
    required Map<String, int> waitingCountByTeacher,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, Map<int, int>> coverageByDay,
    required Random rng,
    required void Function() onMove,
    required void Function() onSwap,
  }) {
    final candidates = _listCandidatesForWaiting(
      day: day,
      period: period,
      level: level,
      profiles: profiles,
      profilesById: profilesById,
      allowDuplicatePerDay: allowDuplicatePerDay,
      capRemaining: capRemaining,
      busy: busy,
      assignedTodayByDay: assignedTodayByDay,
      waitingCountByTeacher: waitingCountByTeacher,
    );

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final sa = _scoreWaitingCandidate(
          teacherId: a.teacherId,
          day: day,
          period: period,
          schedule: schedule,
          waitingCountByTeacher: waitingCountByTeacher,
        );
        final sb = _scoreWaitingCandidate(
          teacherId: b.teacherId,
          day: day,
          period: period,
          schedule: schedule,
          waitingCountByTeacher: waitingCountByTeacher,
        );
        return sa.compareTo(sb);
      });
      final best = candidates.first;
      _addWaitingSlot(
        teacherId: best.teacherId,
        day: day,
        period: period,
        level: level,
        schedule: schedule,
        ordinalNames: ordinalNames,
        capRemaining: capRemaining,
        busy: busy,
        waitingByTeacherByDay: waitingByTeacherByDay,
        waitingCountByTeacher: waitingCountByTeacher,
        assignedTodayByDay: assignedTodayByDay,
        coverageByDay: coverageByDay,
      );
      return true;
    }

    if (allowDuplicatePerDay) return false;

    final bestRepair = _attemptDayRepair(
      day: day,
      targetPeriod: period,
      targetLevel: level,
      schedule: schedule,
      profiles: profiles,
      profilesById: profilesById,
      ordinalNames: ordinalNames,
      capRemaining: capRemaining,
      busy: busy,
      waitingByTeacherByDay: waitingByTeacherByDay,
      waitingCountByTeacher: waitingCountByTeacher,
      assignedTodayByDay: assignedTodayByDay,
      coverageByDay: coverageByDay,
      rng: rng,
      onMove: onMove,
      onSwap: onSwap,
    );

    return bestRepair;
  }

  List<TeacherConstraintsProfile> _listCandidatesForWaiting({
    required String day,
    required int period,
    required int level,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required bool allowDuplicatePerDay,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, int> waitingCountByTeacher,
  }) {
    final out = <TeacherConstraintsProfile>[];
    for (final p in profiles) {
      final tid = p.teacherId;
      if ((capRemaining[tid] ?? 0) <= 0) continue;
      final profile = profilesById[tid];
      if (profile == null) continue;
      if (profile.currentLoad >= profile.weeklyQuota) continue;
      final totalLoad = profile.currentLoad + (waitingCountByTeacher[tid] ?? 0);
      if (totalLoad >= profile.weeklyQuota) continue;
      final remainingTeaching = (profile.weeklyQuota - profile.currentLoad)
          .clamp(0, 1000);
      final minLevel = remainingTeaching <= 0
          ? 999
          : (remainingTeaching == 1 ? 3 : (remainingTeaching == 2 ? 2 : 1));
      if (level < minLevel) continue;
      if (profile.blockedTimeSlots.contains('$day:$period')) continue;
      if (busy[tid]?[day]?.contains(period) == true) continue;
      if (!allowDuplicatePerDay &&
          (assignedTodayByDay[day]?.contains(tid) == true)) {
        continue;
      }
      out.add(p);
    }
    return out;
  }

  int _scoreWaitingCandidate({
    required String teacherId,
    required String day,
    required int period,
    required Map<String, List<ScheduleSlot>> schedule,
    required Map<String, int> waitingCountByTeacher,
  }) {
    final slots = schedule[teacherId] ?? const <ScheduleSlot>[];
    final wait = waitingCountByTeacher[teacherId] ?? 0;
    final chain = _calculateConsecutiveChain(slots, day, period);
    final gaps = _calculateGapsIfAssigned(slots, day, period);
    final total = slots.length;
    return (wait * 1000) + (total * 10) + (gaps * 3) + chain;
  }

  bool _attemptDayRepair({
    required String day,
    required int targetPeriod,
    required int targetLevel,
    required Map<String, List<ScheduleSlot>> schedule,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required List<String> ordinalNames,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Map<String, Set<int>>> waitingByTeacherByDay,
    required Map<String, int> waitingCountByTeacher,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, Map<int, int>> coverageByDay,
    required Random rng,
    required void Function() onMove,
    required void Function() onSwap,
  }) {
    final teachersWithWaiting = waitingByTeacherByDay.entries
        .where((e) => (e.value[day]?.isNotEmpty ?? false))
        .map((e) => e.key)
        .toList();
    teachersWithWaiting.shuffle(rng);

    for (final tid in teachersWithWaiting) {
      if (busy[tid]?[day]?.contains(targetPeriod) == true) continue;
      final periods =
          waitingByTeacherByDay[tid]?[day]?.toList() ?? const <int>[];
      if (periods.isEmpty) continue;

      periods.shuffle(rng);
      for (final oldPeriod in periods) {
        if (oldPeriod == targetPeriod) continue;
        final oldCoverage = coverageByDay[day]?[oldPeriod] ?? 0;
        if (oldCoverage > 1) {
          _moveWaitingSlot(
            teacherId: tid,
            day: day,
            fromPeriod: oldPeriod,
            toPeriod: targetPeriod,
            toLevel: targetLevel,
            schedule: schedule,
            ordinalNames: ordinalNames,
            busy: busy,
            waitingByTeacherByDay: waitingByTeacherByDay,
            assignedTodayByDay: assignedTodayByDay,
            coverageByDay: coverageByDay,
          );
          onMove();
          return true;
        }

        final removedLevelHint = _peekWaitingAt(
          teacherId: tid,
          day: day,
          period: oldPeriod,
          schedule: schedule,
        );
        if (removedLevelHint == null) continue;

        final replacement = _listCandidatesForWaiting(
          day: day,
          period: oldPeriod,
          level: removedLevelHint,
          profiles: profiles,
          profilesById: profilesById,
          allowDuplicatePerDay: false,
          capRemaining: capRemaining,
          busy: busy,
          assignedTodayByDay: assignedTodayByDay,
          waitingCountByTeacher: waitingCountByTeacher,
        ).where((p) => p.teacherId != tid).toList();

        if (replacement.isEmpty) continue;

        replacement.sort((a, b) {
          final sa = _scoreWaitingCandidate(
            teacherId: a.teacherId,
            day: day,
            period: oldPeriod,
            schedule: schedule,
            waitingCountByTeacher: waitingCountByTeacher,
          );
          final sb = _scoreWaitingCandidate(
            teacherId: b.teacherId,
            day: day,
            period: oldPeriod,
            schedule: schedule,
            waitingCountByTeacher: waitingCountByTeacher,
          );
          return sa.compareTo(sb);
        });

        final replacementTeacher = replacement.first.teacherId;
        final removedLevel = _removeWaitingAt(
          teacherId: tid,
          day: day,
          period: oldPeriod,
          schedule: schedule,
        );
        if (removedLevel == null) continue;

        waitingCountByTeacher[tid] = (waitingCountByTeacher[tid] ?? 1) - 1;
        busy[tid]?[day]?.remove(oldPeriod);
        waitingByTeacherByDay[tid]?[day]?.remove(oldPeriod);
        coverageByDay[day]![oldPeriod] =
            (coverageByDay[day]![oldPeriod] ?? 1) - 1;

        _addWaitingSlot(
          teacherId: replacementTeacher,
          day: day,
          period: oldPeriod,
          level: removedLevel,
          schedule: schedule,
          ordinalNames: ordinalNames,
          capRemaining: capRemaining,
          busy: busy,
          waitingByTeacherByDay: waitingByTeacherByDay,
          waitingCountByTeacher: waitingCountByTeacher,
          assignedTodayByDay: assignedTodayByDay,
          coverageByDay: coverageByDay,
        );

        _addWaitingSlot(
          teacherId: tid,
          day: day,
          period: targetPeriod,
          level: targetLevel,
          schedule: schedule,
          ordinalNames: ordinalNames,
          capRemaining: capRemaining,
          busy: busy,
          waitingByTeacherByDay: waitingByTeacherByDay,
          waitingCountByTeacher: waitingCountByTeacher,
          assignedTodayByDay: assignedTodayByDay,
          coverageByDay: coverageByDay,
          countAgainstCap: false,
        );

        onSwap();
        return true;
      }
    }

    return false;
  }

  void _addWaitingSlot({
    required String teacherId,
    required String day,
    required int period,
    required int level,
    required Map<String, List<ScheduleSlot>> schedule,
    required List<String> ordinalNames,
    required Map<String, int> capRemaining,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Map<String, Set<int>>> waitingByTeacherByDay,
    required Map<String, int> waitingCountByTeacher,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, Map<int, int>> coverageByDay,
    bool countAgainstCap = true,
  }) {
    schedule.putIfAbsent(teacherId, () => <ScheduleSlot>[]);
    final subjectName = level <= ordinalNames.length
        ? 'منتظر ${ordinalNames[level - 1]}'
        : 'منتظر $level';
    schedule[teacherId]!.add(
      ScheduleSlot(
        day: day,
        period: period,
        className: 'Standby',
        subject: subjectName,
        teacherId: teacherId,
      ),
    );
    busy.putIfAbsent(teacherId, () => <String, Set<int>>{});
    busy[teacherId]!.putIfAbsent(day, () => <int>{}).add(period);
    waitingByTeacherByDay
        .putIfAbsent(teacherId, () => <String, Set<int>>{})
        .putIfAbsent(day, () => <int>{})
        .add(period);
    waitingCountByTeacher[teacherId] =
        (waitingCountByTeacher[teacherId] ?? 0) + 1;
    assignedTodayByDay.putIfAbsent(day, () => <String>{}).add(teacherId);
    coverageByDay[day]![period] = (coverageByDay[day]![period] ?? 0) + 1;
    if (countAgainstCap) {
      capRemaining[teacherId] = (capRemaining[teacherId] ?? 0) - 1;
    }
  }

  void _moveWaitingSlot({
    required String teacherId,
    required String day,
    required int fromPeriod,
    required int toPeriod,
    required int toLevel,
    required Map<String, List<ScheduleSlot>> schedule,
    required List<String> ordinalNames,
    required Map<String, Map<String, Set<int>>> busy,
    required Map<String, Map<String, Set<int>>> waitingByTeacherByDay,
    required Map<String, Set<String>> assignedTodayByDay,
    required Map<String, Map<int, int>> coverageByDay,
  }) {
    final removedLevel = _removeWaitingAt(
      teacherId: teacherId,
      day: day,
      period: fromPeriod,
      schedule: schedule,
    );
    if (removedLevel == null) return;
    busy[teacherId]?[day]?.remove(fromPeriod);
    waitingByTeacherByDay[teacherId]?[day]?.remove(fromPeriod);
    coverageByDay[day]![fromPeriod] =
        (coverageByDay[day]![fromPeriod] ?? 1) - 1;

    schedule[teacherId]!.add(
      ScheduleSlot(
        day: day,
        period: toPeriod,
        className: 'Standby',
        subject: toLevel <= ordinalNames.length
            ? 'منتظر ${ordinalNames[toLevel - 1]}'
            : 'منتظر $toLevel',
        teacherId: teacherId,
      ),
    );
    busy.putIfAbsent(teacherId, () => <String, Set<int>>{});
    busy[teacherId]!.putIfAbsent(day, () => <int>{}).add(toPeriod);
    waitingByTeacherByDay[teacherId]!
        .putIfAbsent(day, () => <int>{})
        .add(toPeriod);
    assignedTodayByDay.putIfAbsent(day, () => <String>{}).add(teacherId);
    coverageByDay[day]![toPeriod] = (coverageByDay[day]![toPeriod] ?? 0) + 1;
  }

  int? _peekWaitingAt({
    required String teacherId,
    required String day,
    required int period,
    required Map<String, List<ScheduleSlot>> schedule,
  }) {
    final list = schedule[teacherId];
    if (list == null) return null;
    for (final s in list) {
      if (s.day != day || s.period != period) continue;
      if (!s.subject.startsWith('منتظر')) continue;
      final digits = RegExp(r'\d+').firstMatch(s.subject)?.group(0);
      final parsed = int.tryParse(digits ?? '');
      if (s.subject.contains('أول')) return 1;
      if (s.subject.contains('ثاني')) return 2;
      if (s.subject.contains('ثالث')) return 3;
      if (s.subject.contains('رابع')) return 4;
      if (s.subject.contains('خامس')) return 5;
      return parsed ?? 1;
    }
    return null;
  }

  int? _removeWaitingAt({
    required String teacherId,
    required String day,
    required int period,
    required Map<String, List<ScheduleSlot>> schedule,
  }) {
    final list = schedule[teacherId];
    if (list == null) return null;
    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      if (s.day != day || s.period != period) continue;
      if (!s.subject.startsWith('منتظر')) continue;
      list.removeAt(i);
      final digits = RegExp(r'\d+').firstMatch(s.subject)?.group(0);
      final parsed = int.tryParse(digits ?? '');
      if (s.subject.contains('أول')) return 1;
      if (s.subject.contains('ثاني')) return 2;
      if (s.subject.contains('ثالث')) return 3;
      if (s.subject.contains('رابع')) return 4;
      if (s.subject.contains('خامس')) return 5;
      return parsed ?? 1;
    }
    return null;
  }

  List<Map<String, dynamic>> _diagnoseUncoveredWaiting({
    required Map<String, List<ScheduleSlot>> schedule,
    required List<TeacherConstraintsProfile> profiles,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required int waitingSlotsPerPeriod,
  }) {
    final coverageByDay = <String, Map<int, int>>{
      for (final d in _days)
        d: {for (int p = 1; p <= _periodsPerDay; p++) p: 0},
    };
    final busy = <String, Map<String, Set<int>>>{};
    for (final entry in schedule.entries) {
      final tid = entry.key;
      final perDay = <String, Set<int>>{};
      for (final s in entry.value) {
        perDay.putIfAbsent(s.day, () => <int>{}).add(s.period);
        if (s.subject.startsWith('منتظر') && coverageByDay.containsKey(s.day)) {
          coverageByDay[s.day]![s.period] =
              (coverageByDay[s.day]![s.period] ?? 0) + 1;
        }
      }
      busy[tid] = perDay;
    }

    final uncovered = <Map<String, dynamic>>[];
    for (final day in _days) {
      for (int period = 1; period <= _periodsPerDay; period++) {
        final current = coverageByDay[day]?[period] ?? 0;
        if (current >= waitingSlotsPerPeriod) continue;
        for (int level = current + 1; level <= waitingSlotsPerPeriod; level++) {
          int free = 0;
          int blocked = 0;
          for (final p in profiles) {
            final tid = p.teacherId;
            final profile = profilesById[tid];
            if (profile == null) continue;
            if (profile.blockedTimeSlots.contains('$day:$period')) {
              blocked++;
              continue;
            }
            if (busy[tid]?[day]?.contains(period) == true) continue;
            free++;
          }
          String reason;
          if (free == 0 && blocked > 0) {
            reason = 'حظر/تعارض كامل في هذا الوقت';
          } else if (free == 0) {
            reason = 'تعارض كامل مع حصص المعلمين في هذا الوقت';
          } else {
            reason = 'قيود السعة/توزيع الانتظار لم تسمح بالتغطية';
          }
          uncovered.add({
            'day': day,
            'period': period,
            'level': level,
            'freeTeachers': free,
            'blockedTeachers': blocked,
            'reason': reason,
          });
        }
      }
    }
    return uncovered;
  }

  List<String> _suggestWaitingFixes(List<Map<String, dynamic>> uncovered) {
    if (uncovered.isEmpty) return <String>[];
    int conflict = 0;
    int capacity = 0;
    for (final u in uncovered) {
      final reason = (u['reason'] ?? '').toString();
      if (reason.contains('تعارض') || reason.contains('حظر')) {
        conflict++;
      } else {
        capacity++;
      }
    }
    final suggestions = <String>[];
    if (conflict >= capacity) {
      suggestions.add('تقليل الأوقات المحظورة أو تعديل جداول بعض المعلمين');
      suggestions.add('زيادة عدد المعلمين المتاحين في الأوقات الحرجة');
    } else {
      suggestions.add(
        'زيادة حد الانتظار الأسبوعي المسموح أو تقليل عدد المنتظرين لكل حصة',
      );
      suggestions.add('السماح بتكرار محدود للمعلم في اليوم عند الضرورة');
    }
    return suggestions;
  }

  int _calculateGapsIfAssigned(
    List<ScheduleSlot> slots,
    String day,
    int newPeriod,
  ) {
    final daySlots = slots
        .where((s) => s.day == day)
        .map((s) => s.period)
        .toList();
    daySlots.add(newPeriod);
    daySlots.sort();

    int gaps = 0;
    for (int i = 0; i < daySlots.length - 1; i++) {
      if (daySlots[i + 1] > daySlots[i] + 1) {
        gaps += (daySlots[i + 1] - daySlots[i] - 1);
      }
    }
    return gaps;
  }

  int _calculateConsecutiveChain(
    List<ScheduleSlot> slots,
    String day,
    int period,
  ) {
    final daySlots =
        slots.where((s) => s.day == day).map((s) => s.period).toList()..sort();

    int chain = 0;
    // Look backward from period
    for (int p = period - 1; p >= 1; p--) {
      if (daySlots.contains(p)) {
        chain++;
      } else {
        break;
      }
    }
    return chain;
  }

  // 5. Gap Diagnosis
  List<Map<String, dynamic>> _diagnoseGaps({
    required List<String> classIds,
    required Map<String, List<ScheduleSlot>> classSchedule,
    required Map<String, Map<String, int>> normalizedDemand,
    required Map<String, List<User>> teachersBySubject,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
    required Map<String, TeacherConstraintsProfile> profilesById,
    required Map<String, Map<String, Map<int, bool>>> classOccupancy,
    required Map<String, Map<String, Map<int, bool>>> teacherOccupancy,
    required Map<String, Map<String, Map<String, int>>> classSubjectPerDay,
  }) {
    final List<Map<String, dynamic>> diagnosis = [];

    for (final classId in classIds) {
      final demand = normalizedDemand[classId] ?? {};

      // Calculate current supply
      final supply = <String, int>{};
      final slots = classSchedule[classId] ?? [];
      for (final s in slots) {
        if (!s.subject.startsWith('منتظر')) {
          supply[s.subject] = (supply[s.subject] ?? 0) + 1;
        }
      }

      demand.forEach((subject, needed) {
        final have = supply[subject] ?? 0;
        if (have < needed) {
          int missing = needed - have;

          // Analyze why we couldn't fill 'missing' slots
          // We don't have a specific 'slot' to check, but we can check general feasibility

          final teachers = teachersBySubject[subject] ?? [];

          String reason = 'Unknown';

          if (teachers.isEmpty) {
            reason = 'No teachers available for this subject';
          } else {
            // Check quotas
            bool anyQuotaLeft = false;
            bool anyTimeFree = false;

            for (final t in teachers) {
              final profile = profilesById[t.id];
              final load =
                  teacherSchedule[t.id]
                      ?.where((s) => !_isNonTeachingSubject(s.subject))
                      .length ??
                  0;
              if (profile != null && load < profile.weeklyQuota) {
                anyQuotaLeft = true;
              }
              // Check if there is ANY common free slot between class and teacher
              for (final day in _days) {
                for (int p = 1; p <= _periodsPerDay; p++) {
                  if (classOccupancy[classId]?[day]?[p] == false &&
                      teacherOccupancy[t.id]?[day]?[p] == false &&
                      !profile!.blockedTimeSlots.contains('$day:$p')) {
                    anyTimeFree = true;
                  }
                }
              }
            }

            if (!anyQuotaLeft) {
              reason =
                  'All teachers for $subject have reached their weekly quota';
            } else if (!anyTimeFree) {
              reason =
                  'Time conflict: Teachers available but no common free slots with class';
            } else {
              reason =
                  'Optimization failure: Slots available but algorithm missed them (Try generating again)';
            }
          }

          diagnosis.add({
            'classId': classId,
            'subject': subject,
            'missing': missing,
            'reason': reason,
            'severity': 'High',
          });
        }
      });
    }
    return diagnosis;
  }

  // 4. Evaluate Fairness (Detailed)
  Map<String, dynamic> evaluateFairness(
    Map<String, List<ScheduleSlot>> schedule,
    List<TeacherConstraintsProfile> profiles, {
    Map<String, TeacherPreferenceEntity>? teacherPreferences,
    required int totalTeachers,
    int waitingSlotsPerPeriod = 2,
  }) {
    int totalFirstPeriods = 0;
    int totalSeventhPeriods = 0;
    int totalGaps = 0;
    int totalPreferenceViolations = 0;

    final Map<String, int> waitingByLevel = {};
    final Map<String, dynamic> teacherStats = {};

    // Variance Trackers
    final List<int> seventhCounts = [];
    final List<int> firstCounts = [];
    final List<int> waitingCounts = [];

    final List<int> totalAssignedCounts = [];

    for (var p in profiles) {
      final slots = schedule[p.teacherId] ?? [];

      int firsts = slots.where((s) => s.period == 1).length;
      int sevenths = slots.where((s) => s.period == 7).length;
      int waitings = slots.where((s) => s.subject.startsWith('منتظر')).length;
      int teachingLoad = slots
          .where((s) => !s.subject.startsWith('منتظر'))
          .length;
      int totalAssigned = slots.length;

      // Gaps
      int gaps = 0;
      for (var day in _days) {
        gaps += _calculateGapsIfAssigned(
          slots.where((s) => !s.subject.startsWith('منتظر')).toList(),
          day,
          -999,
        ); // -999 dummy
      }

      // Violations
      int violations = 0;
      final pref = teacherPreferences?[p.teacherId];
      if (pref != null) {
        if (pref.noSeventhPeriod && sevenths > 0) violations++;
        if (pref.preferConsecutive && gaps > 0)
          violations++; // Strict interpretation
        // Unavailable slots check
        for (var slot in pref.unavailableSlots) {
          final int? d = slot['dayIndex'] is num
              ? (slot['dayIndex'] as num).toInt()
              : slot['dayIndex'] as int?;
          final int? pr = slot['period'] is num
              ? (slot['period'] as num).toInt()
              : slot['period'] as int?;
          if (d != null && pr != null && d >= 0 && d < _days.length) {
            if (slots.any((s) => s.day == _days[d] && s.period == pr)) {
              violations++;
            }
          }
        }
      }

      totalFirstPeriods += firsts;
      totalSeventhPeriods += sevenths;
      totalGaps += gaps;
      totalPreferenceViolations += violations;

      seventhCounts.add(sevenths);
      firstCounts.add(firsts);
      waitingCounts.add(waitings);
      totalAssignedCounts.add(totalAssigned);

      // Waiting Level Breakdown
      for (var s in slots.where((s) => s.subject.startsWith('منتظر'))) {
        waitingByLevel[s.subject] = (waitingByLevel[s.subject] ?? 0) + 1;
      }
    }

    int minWaiting = waitingCounts.isEmpty
        ? 0
        : waitingCounts.reduce((a, b) => a < b ? a : b);
    int maxWaiting = waitingCounts.isEmpty
        ? 0
        : waitingCounts.reduce((a, b) => a > b ? a : b);
    double avgWaiting = waitingCounts.isEmpty
        ? 0.0
        : waitingCounts.reduce((a, b) => a + b) / waitingCounts.length;

    int uncoveredWaitingSlots = 0;
    for (var day in _days) {
      for (int period = 1; period <= _periodsPerDay; period++) {
        int countAtSlot = 0;
        for (var p in profiles) {
          final slots = schedule[p.teacherId] ?? [];
          if (slots.any(
            (s) =>
                s.day == day &&
                s.period == period &&
                s.subject.startsWith('منتظر'),
          )) {
            countAtSlot++;
          }
        }
        if (countAtSlot < waitingSlotsPerPeriod) {
          uncoveredWaitingSlots += waitingSlotsPerPeriod - countAtSlot;
        }
      }
    }

    final List<String> maxWaitingBreaches = [];
    for (var p in profiles) {
      final slots = schedule[p.teacherId] ?? [];
      int waitings = slots.where((s) => s.subject.startsWith('منتظر')).length;
      if (waitings > p.maxWaitingPerWeek) {
        maxWaitingBreaches.add(p.teacherId);
      }
    }

    int submittedCount = teacherPreferences?.length ?? 0;
    int noResponse = totalTeachers - submittedCount;

    return {
      'firstPeriods': totalFirstPeriods,
      'seventhPeriods': totalSeventhPeriods,
      'gaps': totalGaps,
      'waitingByLevel': waitingByLevel,
      'preferenceViolations': totalPreferenceViolations,
      'teachersNoResponse': noResponse,
      'variance': {
        'seventh': _calculateVariance(seventhCounts),
        'first': _calculateVariance(firstCounts),
        'waiting': _calculateVariance(waitingCounts),
        'totalAssigned': _calculateVariance(totalAssignedCounts),
      },
      'waitingSummary': {
        'min': minWaiting,
        'max': maxWaiting,
        'average': avgWaiting,
      },
      'uncoveredWaitingSlots': uncoveredWaitingSlots,
      'maxWaitingBreaches': maxWaitingBreaches,
    };
  }

  double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = values
        .map((v) => pow(v - mean, 2).toDouble())
        .reduce((a, b) => a + b);
    return sumSquaredDiff / values.length;
  }
}

class _WaitingTierSpec {
  final String name;
  final bool allowDuplicatePerDay;
  final bool allowHighLoadExtra;

  const _WaitingTierSpec({
    required this.name,
    required this.allowDuplicatePerDay,
    required this.allowHighLoadExtra,
  });
}

class _WaitingKey {
  final String day;
  final int period;
  final int level;

  const _WaitingKey({
    required this.day,
    required this.period,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
    'day': day,
    'period': period,
    'level': level,
  };
}
