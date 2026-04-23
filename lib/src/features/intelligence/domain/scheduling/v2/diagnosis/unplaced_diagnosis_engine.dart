import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../../schedule/domain/saudi_subject_plans.dart';
import '../models/assignment.dart';
import '../models/demand.dart';
import '../models/policy.dart';
import '../models/snapshot.dart';
import '../utils/subject_normalizer.dart';

class UnplacedDiagnosisEngine {
  const UnplacedDiagnosisEngine();

  Future<Map<String, dynamic>> diagnose({
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required AssignmentModel assignment,
    required DemandModel balanced,
  }) async {
    final days = _daysFromPolicy(policy, fallback: balanced.data['days']);
    final periods =
        (balanced.data['periodsPerDay'] as num?)?.toInt() ??
        (policy.raw['periodsPerDay'] as num?)?.toInt() ??
        snapshot.periodsPerDay;

    final classNameById = <String, String>{
      for (final c in snapshot.classes) c.id.trim(): c.name,
    };
    final subjectNameById = <String, String>{
      for (final s in snapshot.subjects) s.id.trim(): s.name,
    };
    final teacherNameById = <String, String>{
      for (final t in snapshot.teachers) t.id.trim(): t.name,
    };

    final isPrimaryOnly = snapshot.stage == 'primary_only';
    final teacherSubjects = <String, List<String>>{};
    for (final t in assignment.teachers) {
      if (t.isAdministrative) continue;
      
      // ✅ توحيد أسماء المواد المسندة
      final subjects = t.assignedSubjects
          .map((e) => SubjectNormalizer.normalize(e.trim()))
          .where((e) => e.isNotEmpty)
          .toList();
      if (subjects.isNotEmpty) {
        teacherSubjects[t.teacherId] = subjects..sort();
        continue;
      }
      if (isPrimaryOnly) {
        final fallback = (t.primarySubject ?? '').trim().isNotEmpty
            ? <String>[SubjectNormalizer.normalize(t.primarySubject!.trim())]
            : const <String>['general'];
        teacherSubjects[t.teacherId] = List<String>.from(fallback);
      }
    }

    final classIdSet = <String>{
      for (final c in snapshot.classes)
        if (!isPrimaryOnly || (c.gradeLevel >= 1 && c.gradeLevel <= 6))
          c.id.trim(),
    }..removeWhere((e) => e.isEmpty);
    final gradeByClassId = <String, int>{
      for (final c in snapshot.classes)
        if (classIdSet.contains(c.id.trim())) c.id.trim(): c.gradeLevel,
    };
    final lowerClassIds = <String>{
      for (final entry in gradeByClassId.entries)
        if (entry.value >= 1 && entry.value <= 3) entry.key,
    };
    final upperClassIds = <String>{
      for (final entry in gradeByClassId.entries)
        if (entry.value >= 4 && entry.value <= 6) entry.key,
    };

    final assignmentByTeacherId = <String, TeacherAssignment>{
      for (final t in assignment.teachers) t.teacherId: t,
    };
    final snapshotTeacherById = <String, SnapshotTeacher>{
      for (final t in snapshot.teachers) t.id: t,
    };

    final teacherAllowedClasses = <String, Set<String>>{};
    for (final tid in teacherSubjects.keys) {
      final st = snapshotTeacherById[tid];
      if (st == null) {
        teacherAllowedClasses[tid] = classIdSet;
        continue;
      }

      final isBundleTeacher =
          isPrimaryOnly &&
          assignmentByTeacherId[tid]?.classification == 'bundle';

      if (isPrimaryOnly) {
        teacherAllowedClasses[tid] = isBundleTeacher
            ? lowerClassIds
            : upperClassIds;
        continue;
      }

      if (snapshot.stage == 'secondary_only' &&
          snapshot.secondaryProgramType == 'masarat') {
        final hasFilters =
            (st.masaratAssignmentType ?? '').trim().isNotEmpty ||
            st.masaratGradeLevel != null ||
            st.masaratTracks.isNotEmpty;
        if (!hasFilters) {
          teacherAllowedClasses[tid] = classIdSet;
          continue;
        }

        final gradeFilter = st.masaratGradeLevel;
        final type = (st.masaratAssignmentType ?? '').trim();
        final allowedGrades = gradeFilter != null
            ? <int>{gradeFilter}
            : (type == 'shared'
                  ? <int>{10}
                  : (type == 'specialized'
                        ? <int>{11, 12}
                        : <int>{10, 11, 12}));
        final tracks = st.masaratTracks.toSet();
        final allowed2 = <String>{};
        for (final c in snapshot.classes) {
          final cid = c.id.trim();
          if (cid.isEmpty) continue;
          if (!classIdSet.contains(cid)) continue;
          if (!allowedGrades.contains(c.gradeLevel)) continue;
          if (c.gradeLevel == 10) {
            allowed2.add(cid);
            continue;
          }
          if (tracks.isNotEmpty) {
            final ct = (c.secondaryTrack ?? '').trim();
            if (tracks.contains(ct)) allowed2.add(cid);
            continue;
          }
          allowed2.add(cid);
        }
        teacherAllowedClasses[tid] = allowed2.isNotEmpty ? allowed2 : classIdSet;
        continue;
      }

      // Default: allow all classes
      teacherAllowedClasses[tid] = classIdSet;
    }

    final lessons = _readLessons(balanced.data['lessons']);
    final classBusy = <String, Map<String, Set<int>>>{};
    final teacherBusy = <String, Map<String, Set<int>>>{};
    final teacherLoad = <String, int>{};
    final classSubjectCount = <String, Map<String, int>>{};

    for (final l in lessons) {
      classBusy.putIfAbsent(l.classId, () => <String, Set<int>>{});
      classBusy[l.classId]!.putIfAbsent(l.day, () => <int>{});
      classBusy[l.classId]![l.day]!.add(l.period);

      teacherBusy.putIfAbsent(l.teacherId, () => <String, Set<int>>{});
      teacherBusy[l.teacherId]!.putIfAbsent(l.day, () => <int>{});
      teacherBusy[l.teacherId]![l.day]!.add(l.period);

      teacherLoad[l.teacherId] = (teacherLoad[l.teacherId] ?? 0) + 1;
      classSubjectCount.putIfAbsent(l.classId, () => <String, int>{});
      if (l.subjectId.isNotEmpty) {
        classSubjectCount[l.classId]![l.subjectId] =
            (classSubjectCount[l.classId]![l.subjectId] ?? 0) + 1;
      }
    }

    final englishDayToArabic = <String, String>{
      'sunday': 'الأحد',
      'monday': 'الاثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
    };
    final teacherBlocked = <String, Map<String, Set<int>>>{};
    for (final t in snapshot.teachers) {
      final raw = t.blockedTimeSlots;
      if (raw.isEmpty) continue;
      teacherBlocked.putIfAbsent(t.id, () => <String, Set<int>>{});
      for (final x in raw) {
        final s = x.toString().trim();
        final idx = s.indexOf(':');
        if (idx <= 0) continue;
        final dayRaw = s.substring(0, idx).trim();
        final periodRaw = s.substring(idx + 1).trim();
        final period = int.tryParse(periodRaw);
        if (period == null || period <= 0) continue;
        final dayLower = dayRaw.toLowerCase().trim();
        final day = englishDayToArabic[dayLower] ?? dayRaw;
        if (!days.contains(day)) continue;
        teacherBlocked[t.id]!.putIfAbsent(day, () => <int>{});
        teacherBlocked[t.id]![day]!.add(period);
      }
    }

    final classIds = classIdSet.toList()..sort();
    final unfilledSlots = <Map<String, dynamic>>[];
    for (final cid in classIds) {
      for (final day in days) {
        for (var p = 1; p <= periods; p++) {
          final busy = classBusy[cid]?[day]?.contains(p) == true;
          if (busy) continue;
          unfilledSlots.add(<String, dynamic>{
            'classId': cid,
            'className': classNameById[cid] ?? cid,
            'day': day,
            'period': p,
          });
        }
      }
    }

    final maxWeeklyLoadByTeacherId = <String, int>{
      for (final t in assignment.teachers) t.teacherId: t.maxWeeklyLoad,
    };

    final unfilledSlotDiagnosis = <Map<String, dynamic>>[];
    final reasonCounts = <String, int>{};
    final fillableSlotsByClass = <String, int>{};

    for (final slot in unfilledSlots) {
      final cid = (slot['classId'] ?? '').toString();
      final day = (slot['day'] ?? '').toString();
      final period = int.tryParse('${slot['period']}') ?? 0;

      final eligibleTeachers = <String>[];
      for (final tid in teacherSubjects.keys) {
        final allowed = teacherAllowedClasses[tid];
        if (allowed != null && allowed.isNotEmpty && !allowed.contains(cid)) {
          continue;
        }
        eligibleTeachers.add(tid);
      }
      if (eligibleTeachers.isEmpty) {
        _bump(reasonCounts, 'no_eligible_teacher');
        unfilledSlotDiagnosis.add(<String, dynamic>{
          ...slot,
          'reason': 'no_eligible_teacher',
          'reasonLabel': 'لا يوجد معلم مؤهل',
          'eligibleTeachers': 0,
        });
        continue;
      }

      final underCap = <String>[];
      for (final tid in eligibleTeachers) {
        final maxQ = maxWeeklyLoadByTeacherId[tid] ?? 0;
        if (maxQ > 0 && (teacherLoad[tid] ?? 0) >= maxQ) continue;
        underCap.add(tid);
      }
      if (underCap.isEmpty) {
        _bump(reasonCounts, 'quota_reached');
        unfilledSlotDiagnosis.add(<String, dynamic>{
          ...slot,
          'reason': 'quota_reached',
          'reasonLabel': 'بلوغ النصاب',
          'eligibleTeachers': eligibleTeachers.length,
          'eligibleUnderCap': 0,
        });
        continue;
      }

      final notBlocked = <String>[];
      for (final tid in underCap) {
        final blocked = teacherBlocked[tid]?[day]?.contains(period) == true;
        if (blocked) continue;
        notBlocked.add(tid);
      }
      if (notBlocked.isEmpty) {
        _bump(reasonCounts, 'manual_constraint_conflict');
        unfilledSlotDiagnosis.add(<String, dynamic>{
          ...slot,
          'reason': 'manual_constraint_conflict',
          'reasonLabel': 'تعارض قيد يدوي',
          'eligibleTeachers': eligibleTeachers.length,
          'eligibleUnderCap': underCap.length,
          'eligibleNotBlocked': 0,
        });
        continue;
      }

      final freeAtTime = <String>[];
      for (final tid in notBlocked) {
        final busy = teacherBusy[tid]?[day]?.contains(period) == true;
        if (busy) continue;
        freeAtTime.add(tid);
      }
      if (freeAtTime.isEmpty) {
        _bump(reasonCounts, 'no_teacher_time');
        unfilledSlotDiagnosis.add(<String, dynamic>{
          ...slot,
          'reason': 'no_teacher_time',
          'reasonLabel': 'لا يوجد شاغر زمني للمعلم',
          'eligibleTeachers': eligibleTeachers.length,
          'eligibleUnderCap': underCap.length,
          'eligibleNotBlocked': notBlocked.length,
          'freeAtTime': 0,
        });
        continue;
      }

      _bump(reasonCounts, 'algorithmic_exclusion');
      fillableSlotsByClass[cid] = (fillableSlotsByClass[cid] ?? 0) + 1;
      unfilledSlotDiagnosis.add(<String, dynamic>{
        ...slot,
        'reason': 'algorithmic_exclusion',
        'reasonLabel': 'سبب خوارزمي/استبعادي',
        'freeAtTime': freeAtTime.length,
        'sampleTeachers': freeAtTime.take(6).map((id) {
          return <String, dynamic>{
            'teacherId': id,
            'teacherName': teacherNameById[id] ?? id,
            'load': teacherLoad[id] ?? 0,
            'maxWeeklyLoad': maxWeeklyLoadByTeacherId[id] ?? 0,
          };
        }).toList(),
      });
    }

    final subjectDemand = await _loadSaudiSubjectPlans();
    final requiredByClassSubject = _buildRequiredByClassSubject(
      snapshot: snapshot,
      plans: subjectDemand,
      normalizeKey: _normalizeKey,
    );
    final shortageByClassSubject = <Map<String, dynamic>>[];
    final shortageReasons = <Map<String, dynamic>>[];

    for (final entry in requiredByClassSubject.entries) {
      final cid = entry.key;
      final required = entry.value;
      final placed = classSubjectCount[cid] ?? const <String, int>{};
      for (final e in required.entries) {
        final subjectKey = e.key;
        final req = e.value;
        final plc = placed[subjectKey] ?? 0;
        final miss = req - plc;
        if (miss <= 0) continue;
        final subjectName = subjectNameById[subjectKey] ?? subjectKey;
        shortageByClassSubject.add(<String, dynamic>{
          'classId': cid,
          'className': classNameById[cid] ?? cid,
          'subjectId': subjectKey,
          'subjectName': subjectName,
          'required': req,
          'placed': plc,
          'missing': miss,
        });

        final missingReason = _diagnoseMissingSubject(
          classId: cid,
          subjectId: subjectKey,
          missingCount: miss,
          days: days,
          periods: periods,
          teacherSubjects: teacherSubjects,
          teacherAllowedClasses: teacherAllowedClasses,
          teacherBusy: teacherBusy,
          teacherBlocked: teacherBlocked,
          teacherLoad: teacherLoad,
          maxWeeklyLoadByTeacherId: maxWeeklyLoadByTeacherId,
          classBusy: classBusy,
          teacherNameById: teacherNameById,
        );
        shortageReasons.add(<String, dynamic>{
          'classId': cid,
          'className': classNameById[cid] ?? cid,
          'subjectId': subjectKey,
          'subjectName': subjectName,
          'missing': miss,
          ...missingReason,
        });
      }
    }

    shortageByClassSubject.sort((a, b) {
      final ma = (a['missing'] as num?)?.toInt() ?? 0;
      final mb = (b['missing'] as num?)?.toInt() ?? 0;
      if (ma != mb) return mb.compareTo(ma);
      final ca = (a['className'] ?? '').toString();
      final cb = (b['className'] ?? '').toString();
      final c = ca.compareTo(cb);
      if (c != 0) return c;
      return (a['subjectName'] ?? '').toString().compareTo(
        (b['subjectName'] ?? '').toString(),
      );
    });

    final teachersUnderused = <Map<String, dynamic>>[];
    for (final t in assignment.teachers) {
      if (t.isAdministrative) continue;
      final tid = t.teacherId;
      final load = teacherLoad[tid] ?? 0;
      final maxQ = t.maxWeeklyLoad;
      final remaining = maxQ > 0 ? (maxQ - load) : 0;
      final freeSlots = _countFreeTeacherSlots(
        days: days,
        periods: periods,
        teacherId: tid,
        teacherBusy: teacherBusy,
        teacherBlocked: teacherBlocked,
      );
      if (remaining <= 0 && freeSlots <= 0) continue;
      teachersUnderused.add(<String, dynamic>{
        'teacherId': tid,
        'teacherName': teacherNameById[tid] ?? tid,
        'load': load,
        'maxWeeklyLoad': maxQ,
        'remainingQuota': remaining,
        'freeSlots': freeSlots,
      });
    }
    teachersUnderused.sort((a, b) {
      final ra = (a['remainingQuota'] as num?)?.toInt() ?? 0;
      final rb = (b['remainingQuota'] as num?)?.toInt() ?? 0;
      if (ra != rb) return rb.compareTo(ra);
      final fa = (a['freeSlots'] as num?)?.toInt() ?? 0;
      final fb = (b['freeSlots'] as num?)?.toInt() ?? 0;
      if (fa != fb) return fb.compareTo(fa);
      return (a['teacherName'] ?? '').toString().compareTo(
        (b['teacherName'] ?? '').toString(),
      );
    });

    final classesFillable = <Map<String, dynamic>>[];
    final unfilledByClass = <String, int>{};
    for (final slot in unfilledSlots) {
      final cid = (slot['classId'] ?? '').toString();
      unfilledByClass[cid] = (unfilledByClass[cid] ?? 0) + 1;
    }
    for (final cid in classIds) {
      final unfilled = unfilledByClass[cid] ?? 0;
      final fillable = fillableSlotsByClass[cid] ?? 0;
      if (unfilled <= 0) continue;
      if (fillable <= 0) continue;
      classesFillable.add(<String, dynamic>{
        'classId': cid,
        'className': classNameById[cid] ?? cid,
        'unfilledSlots': unfilled,
        'fillableSlots': fillable,
      });
    }
    classesFillable.sort((a, b) {
      final fa = (a['fillableSlots'] as num?)?.toInt() ?? 0;
      final fb = (b['fillableSlots'] as num?)?.toInt() ?? 0;
      if (fa != fb) return fb.compareTo(fa);
      final ua = (a['unfilledSlots'] as num?)?.toInt() ?? 0;
      final ub = (b['unfilledSlots'] as num?)?.toInt() ?? 0;
      if (ua != ub) return ub.compareTo(ua);
      return (a['className'] ?? '').toString().compareTo(
        (b['className'] ?? '').toString(),
      );
    });

    return <String, dynamic>{
      'demandedLessons': balanced.demandedLessons,
      'placedLessons': balanced.placedLessons,
      'unplacedLessons': balanced.unplacedLessons,
      'solverQuotaSummary':
          (balanced.data['quotaSummary'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
      'solverSubjectEligibilityReport':
          (balanced.data['subjectEligibilityReport'] as List?)
                  ?.map((e) => e is Map ? e.cast<String, dynamic>() : <String, dynamic>{})
                  .toList() ??
              const <Map<String, dynamic>>[],
      'unfilledSlots': unfilledSlotDiagnosis.take(250).toList(),
      'unfilledSlotsTotal': unfilledSlotDiagnosis.length,
      'reasonsCount': reasonCounts,
      'shortageByClassSubject': shortageByClassSubject.take(300).toList(),
      'shortageByClassSubjectTotal': shortageByClassSubject.length,
      'shortageReasons': shortageReasons.take(250).toList(),
      'shortageReasonsTotal': shortageReasons.length,
      'teachersUnderused': teachersUnderused.take(120).toList(),
      'teachersUnderusedTotal': teachersUnderused.length,
      'classesFillable': classesFillable.take(120).toList(),
      'classesFillableTotal': classesFillable.length,
    };
  }

  Map<String, dynamic> _diagnoseMissingSubject({
    required String classId,
    required String subjectId,
    required int missingCount,
    required List<String> days,
    required int periods,
    required Map<String, List<String>> teacherSubjects,
    required Map<String, Set<String>> teacherAllowedClasses,
    required Map<String, Map<String, Set<int>>> teacherBusy,
    required Map<String, Map<String, Set<int>>> teacherBlocked,
    required Map<String, int> teacherLoad,
    required Map<String, int> maxWeeklyLoadByTeacherId,
    required Map<String, Map<String, Set<int>>> classBusy,
    required Map<String, String> teacherNameById,
  }) {
    final candidates = <String>[];
    final candidateDetails = <Map<String, dynamic>>[];
    
    for (final entry in teacherSubjects.entries) {
      final tid = entry.key;
      if (!entry.value.contains(subjectId)) continue;
      
      final allowed = teacherAllowedClasses[tid];
      final isAllowedForClass = allowed == null || 
                                 allowed.isEmpty || 
                                 allowed.contains(classId);
      
      final load = teacherLoad[tid] ?? 0;
      final maxQ = maxWeeklyLoadByTeacherId[tid] ?? 0;
      final remaining = maxQ > 0 ? maxQ - load : 0;
      
      // حساب الفترات المتاحة
      int availableSlots = 0;
      for (final day in days) {
        for (var p = 1; p <= periods; p++) {
          final blocked = teacherBlocked[tid]?[day]?.contains(p) == true;
          final busy = teacherBusy[tid]?[day]?.contains(p) == true;
          if (!blocked && !busy) availableSlots++;
        }
      }
      
      candidateDetails.add({
        'teacherId': tid,
        'teacherName': teacherNameById[tid] ?? tid,
        'load': load,
        'maxQuota': maxQ,
        'remaining': remaining,
        'availableSlots': availableSlots,
        'isAllowedForClass': isAllowedForClass,
        'allowedClassesCount': allowed?.length ?? 0,
        'subjects': entry.value,
      });
      
      if (isAllowedForClass) {
        candidates.add(tid);
      }
    }
    
    if (candidates.isEmpty) {
      return <String, dynamic>{
        'reason': 'no_eligible_teacher',
        'reasonLabel': 'لا يوجد معلم مؤهل للفصل',
        'candidates': 0,
        'allTeachersForSubject': candidateDetails.length,
        'teacherDetails': candidateDetails,
        'explanation': candidateDetails.isEmpty 
            ? 'لا يوجد معلمين لديهم هذه المادة'
            : 'جميع المعلمين غير مسموح لهم بهذا الفصل (allowedClasses)',
      };
    }

    final underCap = <String>[];
    final underCapDetails = <Map<String, dynamic>>[];
    
    for (final tid in candidates) {
      final maxQ = maxWeeklyLoadByTeacherId[tid] ?? 0;
      final load = teacherLoad[tid] ?? 0;
      
      final detail = candidateDetails.firstWhere((d) => d['teacherId'] == tid);
      
      if (maxQ > 0 && load >= maxQ) {
        // وصل للنصاب
        continue;
      }
      
      underCap.add(tid);
      underCapDetails.add(detail);
    }
    
    if (underCap.isEmpty) {
      return <String, dynamic>{
        'reason': 'quota_reached',
        'reasonLabel': 'بلوغ النصاب (حقيقي)',
        'candidates': candidates.length,
        'underCap': 0,
        'teacherDetails': candidateDetails.where((d) => candidates.contains(d['teacherId'])).toList(),
        'explanation': 'جميع المعلمين المؤهلين وصلوا للنصاب',
      };
    }

    final unfilledSlots = <_Slot>[];
    for (final day in days) {
      for (var p = 1; p <= periods; p++) {
        final busy = classBusy[classId]?[day]?.contains(p) == true;
        if (!busy) unfilledSlots.add(_Slot(day: day, period: p));
      }
    }
    
    if (unfilledSlots.isEmpty) {
      return <String, dynamic>{
        'reason': 'no_class_time',
        'reasonLabel': 'لا يوجد شاغر زمني للفصل',
        'candidates': candidates.length,
        'underCap': underCap.length,
        'teacherDetails': underCapDetails,
      };
    }

    // البحث عن أول فترة متاحة للفصل ومعلم متاح
    for (final slot in unfilledSlots) {
      for (final tid in underCap) {
        final blocked =
            teacherBlocked[tid]?[slot.day]?.contains(slot.period) == true;
        if (blocked) continue;
        final busy = teacherBusy[tid]?[slot.day]?.contains(slot.period) == true;
        if (busy) continue;
        
        // وجدنا فترة ومعلم متاحين!
        return <String, dynamic>{
          'reason': 'algorithmic_exclusion',
          'reasonLabel': 'سبب خوارزمي/استبعادي',
          'candidates': candidates.length,
          'underCap': underCap.length,
          'teacherDetails': underCapDetails,
          'evidence': <String, dynamic>{
            'day': slot.day,
            'period': slot.period,
            'teacherId': tid,
            'teacherName': teacherNameById[tid] ?? tid,
          },
          'explanation': 'يوجد معلم ووقت متاحين لكن المحلل لم يستخدمهما',
        };
      }
    }

    // التحقق من الأوقات المحجوبة
    var hasManualBlock = false;
    for (final slot in unfilledSlots.take(20)) {
      for (final tid in underCap) {
        final busy = teacherBusy[tid]?[slot.day]?.contains(slot.period) == true;
        if (busy) continue;
        final blocked =
            teacherBlocked[tid]?[slot.day]?.contains(slot.period) == true;
        if (blocked) {
          hasManualBlock = true;
          break;
        }
      }
      if (hasManualBlock) break;
    }

    if (hasManualBlock) {
      return <String, dynamic>{
        'reason': 'manual_constraint_conflict',
        'reasonLabel': 'تعارض قيد يدوي',
        'candidates': candidates.length,
        'underCap': underCap.length,
        'teacherDetails': underCapDetails,
        'explanation': 'المعلمون المتاحون لديهم أوقات محجوبة في جميع الفترات الفارغة',
      };
    }

    return <String, dynamic>{
      'reason': 'no_teacher_time',
      'reasonLabel': 'لا يوجد شاغر زمني للمعلم',
      'candidates': candidates.length,
      'underCap': underCap.length,
      'teacherDetails': underCapDetails,
      'explanation': 'المعلمون المتاحون مشغولون في جميع الفترات الفارغة للفصل',
    };
  }

  Future<SaudiSubjectPlans?> _loadSaudiSubjectPlans() async {
    try {
      final text = await rootBundle.loadString(
        'assets/config/saudi_subject_plans.json',
      );
      final decoded = jsonDecode(text);
      final map = decoded is Map ? decoded.cast<String, dynamic>() : null;
      if (map == null) return null;
      return SaudiSubjectPlans(map);
    } catch (_) {
      return null;
    }
  }

  Map<String, Map<String, int>> _buildRequiredByClassSubject({
    required SchoolSnapshot snapshot,
    required SaudiSubjectPlans? plans,
    required String Function(String) normalizeKey,
  }) {
    if (plans == null) return const <String, Map<String, int>>{};
    final out = <String, Map<String, int>>{};
    for (final c in snapshot.classes) {
      final cid = c.id.trim();
      if (cid.isEmpty) continue;
      if (c.gradeLevel <= 0) continue;
      final program = (c.secondaryProgramType ?? snapshot.secondaryProgramType)
          ?.trim();
      final track = (c.secondaryTrack ?? '').trim();
      final raw = plans.weeklyDemandForGrade(
        gradeLevel: c.gradeLevel,
        secondaryProgramType: program,
        secondaryTrack: track.isEmpty ? null : track,
      );
      if (raw.isEmpty) continue;
      final mapped = <String, int>{};
      for (final e in raw.entries) {
        final key = snapshot.subjectIdByAlias[normalizeKey(e.key)] ?? e.key;
        mapped[key] = (mapped[key] ?? 0) + e.value;
      }
      mapped.removeWhere((_, v) => v <= 0);
      if (mapped.isNotEmpty) out[cid] = mapped;
    }
    return out;
  }

  List<String> _daysFromPolicy(PolicyProfile policy, {Object? fallback}) {
    final raw = policy.raw['days'] ?? fallback;
    if (raw is List) {
      final out = raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (out.isNotEmpty) return out;
    }
    return const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
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

  int _countFreeTeacherSlots({
    required List<String> days,
    required int periods,
    required String teacherId,
    required Map<String, Map<String, Set<int>>> teacherBusy,
    required Map<String, Map<String, Set<int>>> teacherBlocked,
  }) {
    var free = 0;
    for (final day in days) {
      for (var p = 1; p <= periods; p++) {
        final busy = teacherBusy[teacherId]?[day]?.contains(p) == true;
        if (busy) continue;
        final blocked = teacherBlocked[teacherId]?[day]?.contains(p) == true;
        if (blocked) continue;
        free++;
      }
    }
    return free;
  }

  List<_Lesson> _readLessons(Object? rawLessons) {
    final out = <_Lesson>[];
    if (rawLessons is! List) return out;
    for (final e in rawLessons) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final cid = (m['classId'] ?? '').toString().trim();
      final day = (m['day'] ?? '').toString().trim();
      final period =
          (m['period'] as num?)?.toInt() ?? int.tryParse('${m['period']}');
      final teacherId = (m['teacherId'] ?? '').toString().trim();
      final subjectId = (m['subjectId'] ?? '').toString().trim();
      if (cid.isEmpty || day.isEmpty || period == null || period <= 0) continue;
      if (teacherId.isEmpty) continue;
      out.add(
        _Lesson(
          classId: cid,
          day: day,
          period: period,
          teacherId: teacherId,
          subjectId: subjectId,
        ),
      );
    }
    return out;
  }
}

class _Lesson {
  final String classId;
  final String day;
  final int period;
  final String teacherId;
  final String subjectId;

  const _Lesson({
    required this.classId,
    required this.day,
    required this.period,
    required this.teacherId,
    required this.subjectId,
  });
}

class _Slot {
  final String day;
  final int period;

  const _Slot({required this.day, required this.period});
}

void _bump(Map<String, int> m, String k) {
  m[k] = (m[k] ?? 0) + 1;
}
