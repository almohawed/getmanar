import '../models/assignment.dart';
import '../models/demand.dart';
import '../models/policy.dart';
import '../models/snapshot.dart';

class BalancerEngine {
  const BalancerEngine();

  Future<DemandModel> balance({
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required AssignmentModel assignment,
    required DemandModel demand,
  }) async {
    final rawLessons = demand.data['lessons'];
    final rawDays = demand.data['days'];
    final days = rawDays is List
        ? rawDays
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : _daysFromPolicy(policy);
    final periodsPerDay =
        (demand.data['periodsPerDay'] as num?)?.toInt() ??
        snapshot.periodsPerDay;

    final lessonByClass = <String, Map<String, Map<int, _Lesson>>>{};
    final classIds =
        snapshot.classes
            .map((c) => c.id.trim())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort();
    for (final cid in classIds) {
      lessonByClass[cid] = {for (final d in days) d: <int, _Lesson>{}};
    }

    if (rawLessons is List) {
      for (final e in rawLessons) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final cid = (m['classId'] ?? '').toString();
        final day = (m['day'] ?? '').toString();
        final period =
            (m['period'] as num?)?.toInt() ?? int.tryParse('${m['period']}');
        final teacherId = (m['teacherId'] ?? '').toString();
        final subjectId = (m['subjectId'] ?? '').toString();
        if (cid.isEmpty || day.isEmpty || period == null || period <= 0)
          continue;
        if (!lessonByClass.containsKey(cid)) continue;
        if (!lessonByClass[cid]!.containsKey(day)) continue;
        if (teacherId.isEmpty) continue;
        lessonByClass[cid]![day]![period] = _Lesson(
          teacherId: teacherId,
          subjectId: subjectId,
        );
      }
    }

    final subjectTeacherIds = assignment.teachers
        .where((t) => !t.isAdministrative && t.assignedSubjects.isNotEmpty)
        .map((t) => t.teacherId)
        .toSet();

    final teacherBusy = <String, Map<String, Map<int, int>>>{};
    final teacherDayLoad = <String, Map<String, int>>{
      for (final tid in subjectTeacherIds) tid: {for (final d in days) d: 0},
    };

    for (final cid in classIds) {
      for (final day in days) {
        for (final entry in lessonByClass[cid]![day]!.entries) {
          final period = entry.key;
          final lesson = entry.value;
          _incBusy(teacherBusy, lesson.teacherId, day, period);
          if (teacherDayLoad.containsKey(lesson.teacherId)) {
            teacherDayLoad[lesson.teacherId]![day] =
                (teacherDayLoad[lesson.teacherId]![day] ?? 0) + 1;
          }
        }
      }
    }

    final maxDailyCap = periodsPerDay >= 7 ? 6 : periodsPerDay;
    var balanceMoves = 0;

    int emptyTeacherDaysBefore = _countEmptyTeacherDays(teacherDayLoad, days);
    for (int iter = 0; iter < 250; iter++) {
      if (iter > 0 && iter % 25 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final t = _pickTeacherWithEmptyDay(teacherDayLoad, days);
      if (t == null) break;
      final emptyDay = _firstEmptyDay(teacherDayLoad[t]!, days);
      if (emptyDay == null) break;

      final donor = _pickDonorLessonForTeacher(
        teacherId: t,
        teacherDayLoad: teacherDayLoad,
        lessonByClass: lessonByClass,
        days: days,
      );
      if (donor == null) break;

      final swapped = _swapWithinClassToFillEmptyDay(
        teacherId: t,
        emptyDay: emptyDay,
        donor: donor,
        lessonByClass: lessonByClass,
        teacherBusy: teacherBusy,
        teacherDayLoad: teacherDayLoad,
        days: days,
      );
      if (swapped) {
        balanceMoves++;
        continue;
      }
      break;
    }

    for (int iter = 0; iter < 250; iter++) {
      if (iter > 0 && iter % 25 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final candidate = _pickTeacherOverCap(
        teacherDayLoad: teacherDayLoad,
        days: days,
        cap: maxDailyCap,
      );
      if (candidate == null) break;
      final teacherId = candidate.teacherId;
      final heavyDay = candidate.day;
      final lightDay = _pickMinLoadDay(teacherDayLoad[teacherId]!, days);
      if (lightDay == null || lightDay == heavyDay) break;

      final donor = _pickDonorLessonForTeacherOnDay(
        teacherId: teacherId,
        day: heavyDay,
        lessonByClass: lessonByClass,
      );
      if (donor == null) break;

      final swapped = _swapWithinClassAcrossDays(
        teacherId: teacherId,
        fromDay: heavyDay,
        toDay: lightDay,
        donor: donor,
        lessonByClass: lessonByClass,
        teacherBusy: teacherBusy,
        teacherDayLoad: teacherDayLoad,
      );
      if (swapped) {
        balanceMoves++;
        continue;
      }
      break;
    }

    final emptyTeacherDaysAfter = _countEmptyTeacherDays(teacherDayLoad, days);
    final maxDailyLoad = _maxDailyLoad(teacherDayLoad, days);
    final minDailyLoad = _minDailyLoad(teacherDayLoad, days);
    final balanceScore = _balanceScore(
      emptyTeacherDays: emptyTeacherDaysAfter,
      maxDailyLoad: maxDailyLoad,
      minDailyLoad: minDailyLoad,
    );

    final outLessons = <Map<String, dynamic>>[];
    for (final cid in classIds) {
      for (final day in days) {
        final byPeriod = lessonByClass[cid]![day]!;
        for (final e in byPeriod.entries) {
          outLessons.add(<String, dynamic>{
            'classId': cid,
            'day': day,
            'period': e.key,
            'teacherId': e.value.teacherId,
            'subjectId': e.value.subjectId,
          });
        }
      }
    }

    final data = Map<String, dynamic>.from(demand.data);
    data['lessons'] = outLessons;
    data['balancerSummary'] = <String, dynamic>{
      'emptyTeacherDays': emptyTeacherDaysAfter,
      'maxDailyLoad': maxDailyLoad,
      'minDailyLoad': minDailyLoad,
      'balanceScore': balanceScore,
      'balanceMoves': balanceMoves,
      'emptyTeacherDaysBefore': emptyTeacherDaysBefore,
    };

    return DemandModel(
      demandedLessons: demand.demandedLessons,
      placedLessons: demand.placedLessons,
      unplacedLessons: demand.unplacedLessons,
      teacherConflicts: demand.teacherConflicts,
      classConflicts: demand.classConflicts,
      solverPasses: demand.solverPasses,
      retryCount: demand.retryCount,
      swapCount: demand.swapCount,
      data: data,
    );
  }

  List<String> _daysFromPolicy(PolicyProfile policy) {
    final rawDays = policy.raw['days'];
    if (rawDays is List) {
      final out = rawDays
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (out.isNotEmpty) return out;
    }
    return const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  }

  int _countEmptyTeacherDays(
    Map<String, Map<String, int>> teacherDayLoad,
    List<String> days,
  ) {
    var n = 0;
    for (final entry in teacherDayLoad.entries) {
      for (final d in days) {
        if ((entry.value[d] ?? 0) == 0) n++;
      }
    }
    return n;
  }

  String? _pickTeacherWithEmptyDay(
    Map<String, Map<String, int>> teacherDayLoad,
    List<String> days,
  ) {
    String? best;
    var bestEmpty = 0;
    for (final entry in teacherDayLoad.entries) {
      var empty = 0;
      for (final d in days) {
        if ((entry.value[d] ?? 0) == 0) empty++;
      }
      if (empty > bestEmpty) {
        bestEmpty = empty;
        best = entry.key;
      }
    }
    return bestEmpty > 0 ? best : null;
  }

  String? _firstEmptyDay(Map<String, int> dayLoad, List<String> days) {
    for (final d in days) {
      if ((dayLoad[d] ?? 0) == 0) return d;
    }
    return null;
  }

  _Donor? _pickDonorLessonForTeacher({
    required String teacherId,
    required Map<String, Map<String, int>> teacherDayLoad,
    required Map<String, Map<String, Map<int, _Lesson>>> lessonByClass,
    required List<String> days,
  }) {
    final loads = teacherDayLoad[teacherId];
    if (loads == null) return null;
    String? heavyDay;
    var heavy = -1;
    for (final d in days) {
      final v = loads[d] ?? 0;
      if (v > heavy) {
        heavy = v;
        heavyDay = d;
      }
    }
    if (heavyDay == null || heavy <= 0) return null;
    for (final classEntry in lessonByClass.entries) {
      final cid = classEntry.key;
      final byDay = classEntry.value[heavyDay];
      if (byDay == null) continue;
      for (final e in byDay.entries) {
        if (e.value.teacherId == teacherId) {
          return _Donor(classId: cid, day: heavyDay, period: e.key);
        }
      }
    }
    return null;
  }

  _Donor? _pickDonorLessonForTeacherOnDay({
    required String teacherId,
    required String day,
    required Map<String, Map<String, Map<int, _Lesson>>> lessonByClass,
  }) {
    for (final classEntry in lessonByClass.entries) {
      final cid = classEntry.key;
      final byDay = classEntry.value[day];
      if (byDay == null) continue;
      for (final e in byDay.entries) {
        if (e.value.teacherId == teacherId) {
          return _Donor(classId: cid, day: day, period: e.key);
        }
      }
    }
    return null;
  }

  bool _swapWithinClassToFillEmptyDay({
    required String teacherId,
    required String emptyDay,
    required _Donor donor,
    required Map<String, Map<String, Map<int, _Lesson>>> lessonByClass,
    required Map<String, Map<String, Map<int, int>>> teacherBusy,
    required Map<String, Map<String, int>> teacherDayLoad,
    required List<String> days,
  }) {
    final cid = donor.classId;
    final fromDay = donor.day;
    final fromPeriod = donor.period;
    final fromLesson = lessonByClass[cid]![fromDay]![fromPeriod];
    if (fromLesson == null) return false;
    if (fromLesson.teacherId != teacherId) return false;
    final targetDayMap = lessonByClass[cid]![emptyDay]!;
    if (targetDayMap.isEmpty) return false;

    final candidates = targetDayMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in candidates) {
      final targetPeriod = e.key;
      final targetLesson = e.value;
      if (targetLesson.teacherId == teacherId) continue;
      if (_isBusy(teacherBusy, targetLesson.teacherId, fromDay, fromPeriod)) {
        continue;
      }

      if (_isBusy(teacherBusy, teacherId, emptyDay, targetPeriod)) continue;

      lessonByClass[cid]![fromDay]![fromPeriod] = targetLesson;
      lessonByClass[cid]![emptyDay]![targetPeriod] = fromLesson;

      _decBusy(teacherBusy, teacherId, fromDay, fromPeriod);
      _decBusy(teacherBusy, targetLesson.teacherId, emptyDay, targetPeriod);
      _incBusy(teacherBusy, targetLesson.teacherId, fromDay, fromPeriod);
      _incBusy(teacherBusy, teacherId, emptyDay, targetPeriod);

      teacherDayLoad[teacherId]![fromDay] =
          (teacherDayLoad[teacherId]![fromDay] ?? 0) - 1;
      teacherDayLoad[teacherId]![emptyDay] =
          (teacherDayLoad[teacherId]![emptyDay] ?? 0) + 1;

      if (teacherDayLoad.containsKey(targetLesson.teacherId)) {
        teacherDayLoad[targetLesson.teacherId]![emptyDay] =
            (teacherDayLoad[targetLesson.teacherId]![emptyDay] ?? 0) - 1;
        teacherDayLoad[targetLesson.teacherId]![fromDay] =
            (teacherDayLoad[targetLesson.teacherId]![fromDay] ?? 0) + 1;
      }
      return true;
    }
    return false;
  }

  bool _swapWithinClassAcrossDays({
    required String teacherId,
    required String fromDay,
    required String toDay,
    required _Donor donor,
    required Map<String, Map<String, Map<int, _Lesson>>> lessonByClass,
    required Map<String, Map<String, Map<int, int>>> teacherBusy,
    required Map<String, Map<String, int>> teacherDayLoad,
  }) {
    final cid = donor.classId;
    final fromPeriod = donor.period;
    final fromLesson = lessonByClass[cid]![fromDay]![fromPeriod];
    if (fromLesson == null) return false;
    if (fromLesson.teacherId != teacherId) return false;

    final toMap = lessonByClass[cid]![toDay]!;
    if (toMap.isEmpty) return false;
    final candidates = toMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in candidates) {
      final toPeriod = e.key;
      final toLesson = e.value;
      if (_isBusy(teacherBusy, toLesson.teacherId, fromDay, fromPeriod))
        continue;
      if (_isBusy(teacherBusy, teacherId, toDay, toPeriod)) continue;

      lessonByClass[cid]![fromDay]![fromPeriod] = toLesson;
      lessonByClass[cid]![toDay]![toPeriod] = fromLesson;

      _decBusy(teacherBusy, teacherId, fromDay, fromPeriod);
      _decBusy(teacherBusy, toLesson.teacherId, toDay, toPeriod);
      _incBusy(teacherBusy, toLesson.teacherId, fromDay, fromPeriod);
      _incBusy(teacherBusy, teacherId, toDay, toPeriod);

      teacherDayLoad[teacherId]![fromDay] =
          (teacherDayLoad[teacherId]![fromDay] ?? 0) - 1;
      teacherDayLoad[teacherId]![toDay] =
          (teacherDayLoad[teacherId]![toDay] ?? 0) + 1;

      if (teacherDayLoad.containsKey(toLesson.teacherId)) {
        teacherDayLoad[toLesson.teacherId]![toDay] =
            (teacherDayLoad[toLesson.teacherId]![toDay] ?? 0) - 1;
        teacherDayLoad[toLesson.teacherId]![fromDay] =
            (teacherDayLoad[toLesson.teacherId]![fromDay] ?? 0) + 1;
      }
      return true;
    }
    return false;
  }

  _TeacherDay? _pickTeacherOverCap({
    required Map<String, Map<String, int>> teacherDayLoad,
    required List<String> days,
    required int cap,
  }) {
    String? bestTeacher;
    String? bestDay;
    var bestLoad = cap;
    for (final entry in teacherDayLoad.entries) {
      for (final d in days) {
        final v = entry.value[d] ?? 0;
        if (v > bestLoad) {
          bestLoad = v;
          bestTeacher = entry.key;
          bestDay = d;
        }
      }
    }
    if (bestTeacher == null || bestDay == null) return null;
    return _TeacherDay(teacherId: bestTeacher, day: bestDay, load: bestLoad);
  }

  String? _pickMinLoadDay(Map<String, int> dayLoad, List<String> days) {
    String? bestDay;
    var best = 1 << 30;
    for (final d in days) {
      final v = dayLoad[d] ?? 0;
      if (v < best) {
        best = v;
        bestDay = d;
      }
    }
    return bestDay;
  }

  int _maxDailyLoad(
    Map<String, Map<String, int>> teacherDayLoad,
    List<String> days,
  ) {
    var m = 0;
    for (final entry in teacherDayLoad.entries) {
      for (final d in days) {
        final v = entry.value[d] ?? 0;
        if (v > m) m = v;
      }
    }
    return m;
  }

  int _minDailyLoad(
    Map<String, Map<String, int>> teacherDayLoad,
    List<String> days,
  ) {
    var m = 1 << 30;
    for (final entry in teacherDayLoad.entries) {
      for (final d in days) {
        final v = entry.value[d] ?? 0;
        if (v < m) m = v;
      }
    }
    return m == (1 << 30) ? 0 : m;
  }

  double _balanceScore({
    required int emptyTeacherDays,
    required int maxDailyLoad,
    required int minDailyLoad,
  }) {
    final penalty = emptyTeacherDays * 10 + (maxDailyLoad - minDailyLoad) * 2;
    final score = 100.0 * (1.0 / (1.0 + (penalty / 100.0)));
    return double.parse(score.toStringAsFixed(2));
  }

  bool _isBusy(
    Map<String, Map<String, Map<int, int>>> busy,
    String id,
    String day,
    int period,
  ) {
    final byDay = busy[id];
    if (byDay == null) return false;
    final byPeriod = byDay[day];
    if (byPeriod == null) return false;
    return (byPeriod[period] ?? 0) > 0;
  }

  void _incBusy(
    Map<String, Map<String, Map<int, int>>> busy,
    String id,
    String day,
    int period,
  ) {
    busy.putIfAbsent(id, () => <String, Map<int, int>>{});
    busy[id]!.putIfAbsent(day, () => <int, int>{});
    busy[id]![day]![period] = (busy[id]![day]![period] ?? 0) + 1;
  }

  void _decBusy(
    Map<String, Map<String, Map<int, int>>> busy,
    String id,
    String day,
    int period,
  ) {
    final byDay = busy[id];
    if (byDay == null) return;
    final byPeriod = byDay[day];
    if (byPeriod == null) return;
    final v = (byPeriod[period] ?? 0) - 1;
    if (v <= 0) {
      byPeriod.remove(period);
    } else {
      byPeriod[period] = v;
    }
    if (byPeriod.isEmpty) byDay.remove(day);
    if (byDay.isEmpty) busy.remove(id);
  }
}

class _Lesson {
  final String teacherId;
  final String subjectId;

  const _Lesson({required this.teacherId, required this.subjectId});
}

class _Donor {
  final String classId;
  final String day;
  final int period;

  const _Donor({
    required this.classId,
    required this.day,
    required this.period,
  });
}

class _TeacherDay {
  final String teacherId;
  final String day;
  final int load;

  const _TeacherDay({
    required this.teacherId,
    required this.day,
    required this.load,
  });
}
