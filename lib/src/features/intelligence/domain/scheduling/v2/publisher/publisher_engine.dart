import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/assignment.dart';
import '../models/demand.dart';
import '../models/policy.dart';
import '../models/snapshot.dart';

class PublisherEngine {
  const PublisherEngine();

  Future<Map<String, dynamic>> publish({
    required String schoolId,
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required AssignmentModel assignment,
    required DemandModel balanced,
    bool allowIncomplete = false,
  }) async {
    if (!allowIncomplete && balanced.unplacedLessons > 0) {
      return <String, dynamic>{
        'skipped': true,
        'reason': 'unplaced_lessons',
        'unplacedLessons': balanced.unplacedLessons,
      };
    }
    final isPrimaryOnly = snapshot.stage == 'primary_only';
    final rawDays = balanced.data['days'];
    final days = rawDays is List
        ? rawDays
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : const <String>[];
    final effectiveDays = days.isNotEmpty
        ? days
        : const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final periodsPerDay =
        (balanced.data['periodsPerDay'] as num?)?.toInt() ??
        snapshot.periodsPerDay;

    final classNameById = <String, String>{
      for (final c in snapshot.classes) c.id: c.name,
    };
    final subjectNameById = <String, String>{
      for (final s in snapshot.subjects) s.id: s.name,
    };

    final teacherSchedule = <String, List<Map<String, dynamic>>>{};
    final classSchedule = <String, List<Map<String, dynamic>>>{};

    final teacherBusy = <String, Map<String, Map<int, bool>>>{};

    final rawLessons = balanced.data['lessons'];
    if (rawLessons is List) {
      for (final e in rawLessons) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final cid = (m['classId'] ?? '').toString().trim();
        final day = (m['day'] ?? '').toString().trim();
        final period =
            (m['period'] as num?)?.toInt() ?? int.tryParse('${m['period']}');
        final teacherId = (m['teacherId'] ?? '').toString().trim();
        final subjectId = (m['subjectId'] ?? '').toString().trim();
        if (cid.isEmpty || day.isEmpty || period == null || period <= 0)
          continue;
        if (teacherId.isEmpty) continue;

        final className = classNameById[cid] ?? cid;
        final subjectName = subjectNameById[subjectId] ?? subjectId;

        classSchedule.putIfAbsent(cid, () => <Map<String, dynamic>>[]);
        classSchedule[cid]!.add(<String, dynamic>{
          'day': day,
          'period': period,
          'className': className,
          'subject': subjectName,
          'teacherId': teacherId,
        });

        teacherSchedule.putIfAbsent(teacherId, () => <Map<String, dynamic>>[]);
        teacherSchedule[teacherId]!.add(<String, dynamic>{
          'day': day,
          'period': period,
          'className': className,
          'subject': subjectName,
          'teacherId': teacherId,
        });

        teacherBusy.putIfAbsent(teacherId, () => <String, Map<int, bool>>{});
        teacherBusy[teacherId]!.putIfAbsent(day, () => <int, bool>{});
        teacherBusy[teacherId]![day]![period] = true;
      }
    }

    final waitEligibleTeacherIds =
        assignment.teachers
            .where(
              (t) =>
                  !t.isAdministrative && (!isPrimaryOnly || !t.isMedicalExempt),
            )
            .map((t) => t.teacherId)
            .toList()
          ..sort();

    final weeklyLoad = <String, int>{
      for (final tid in waitEligibleTeacherIds)
        tid: teacherSchedule[tid]?.length ?? 0,
    };
    final waitQuota = <String, int>{
      for (final tid in waitEligibleTeacherIds)
        tid: _waitQuota(weeklyLoad[tid] ?? 0),
    };
    final waitAssigned = <String, int>{
      for (final tid in waitEligibleTeacherIds) tid: 0,
    };

    final waitingCfg =
        (policy.raw['waiting'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final waitingSlotsPerPeriod =
        (waitingCfg['waitingSlotsPerPeriod'] as num?)?.toInt() ??
        (policy.raw['waitingSlotsPerPeriod'] as num?)?.toInt() ??
        2;
    final maxSlotsPerPeriod = waitingSlotsPerPeriod.clamp(0, 4);

    var waitingSlotsCreated = 0;
    for (final day in effectiveDays) {
      for (int period = 1; period <= periodsPerDay; period++) {
        final candidates = <String>[];
        for (final tid in waitEligibleTeacherIds) {
          final busy = teacherBusy[tid]?[day]?[period] == true;
          if (busy) continue;
          candidates.add(tid);
        }

        candidates.sort((a, b) {
          final qa = waitQuota[a] ?? 0;
          final qb = waitQuota[b] ?? 0;
          final wa = waitAssigned[a] ?? 0;
          final wb = waitAssigned[b] ?? 0;
          final ra = qa > 0 ? (wa / qa) : 9999.0;
          final rb = qb > 0 ? (wb / qb) : 9999.0;
          final c = ra.compareTo(rb);
          if (c != 0) return c;
          final d = wa.compareTo(wb);
          if (d != 0) return d;
          return a.compareTo(b);
        });

        final picked = <String>[];
        for (final tid in candidates) {
          if (picked.length >= maxSlotsPerPeriod) break;
          final q = waitQuota[tid] ?? 0;
          final w = waitAssigned[tid] ?? 0;
          if (q > 0 && w >= q) continue;
          picked.add(tid);
        }
        if (picked.length < maxSlotsPerPeriod) {
          for (final tid in candidates) {
            if (picked.length >= maxSlotsPerPeriod) break;
            if (picked.contains(tid)) continue;
            picked.add(tid);
          }
        }

        for (var i = 0; i < picked.length; i++) {
          final tid = picked[i];
          final label = _waitingLabel(i + 1);
          teacherSchedule.putIfAbsent(tid, () => <Map<String, dynamic>>[]);
          teacherSchedule[tid]!.add(<String, dynamic>{
            'day': day,
            'period': period,
            'className': '',
            'subject': label,
            'teacherId': tid,
          });
          waitAssigned[tid] = (waitAssigned[tid] ?? 0) + 1;
          waitingSlotsCreated++;
        }
      }
    }

    for (final entry in teacherSchedule.entries) {
      entry.value.sort((a, b) {
        final da = (a['day'] ?? '').toString();
        final db = (b['day'] ?? '').toString();
        final c = da.compareTo(db);
        if (c != 0) return c;
        final pa = (a['period'] as num?)?.toInt() ?? 0;
        final pb = (b['period'] as num?)?.toInt() ?? 0;
        return pa.compareTo(pb);
      });
    }
    for (final entry in classSchedule.entries) {
      entry.value.sort((a, b) {
        final da = (a['day'] ?? '').toString();
        final db = (b['day'] ?? '').toString();
        final c = da.compareTo(db);
        if (c != 0) return c;
        final pa = (a['period'] as num?)?.toInt() ?? 0;
        final pb = (b['period'] as num?)?.toInt() ?? 0;
        return pa.compareTo(pb);
      });
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    int teacherDocsWritten = 0;
    int classDocsWritten = 0;

    for (final entry in teacherSchedule.entries) {
      final ref = firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TeacherSchedules')
          .doc(entry.key);
      batch.set(ref, {
        'slots': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'v2_publisher',
      });
      teacherDocsWritten++;
    }

    for (final entry in classSchedule.entries) {
      final ref = firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('ClassSchedules')
          .doc(_classDocId(entry.key));
      batch.set(ref, {
        'slots': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'v2_publisher',
      });
      classDocsWritten++;
    }

    final timetableRef = firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Timetables')
        .doc();
    batch.set(timetableRef, {
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'v2',
      'variant': 'base',
      'teacherCount': teacherDocsWritten,
      'classCount': classDocsWritten,
      'waitingSlotsPerPeriod': maxSlotsPerPeriod,
      'policyStageKey': policy.stageKey,
    });

    final scheduleStatusRef = firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('schedule_status');
    batch.set(scheduleStatusRef, {
      'isPublished': true,
      'publishedAt': FieldValue.serverTimestamp(),
      'timetableId': timetableRef.id,
      'source': 'v2',
    }, SetOptions(merge: true));

    final variantRef = firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('schedule_variant');
    batch.set(variantRef, {
      'active': 'base',
      'updatedAt': FieldValue.serverTimestamp(),
      'timetableId': timetableRef.id,
    }, SetOptions(merge: true));

    await batch.commit();

    var notificationsSent = 0;
    String? notificationError;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendSchoolNotification',
      );
      await callable.call({
        'schoolId': schoolId,
        'title': 'تم اعتماد الجدول الدراسي',
        'body': 'تم نشر جدول الحصص الجديد. يمكنك الآن الاطلاع على جدولك.',
        'targetRole': 'teacher',
        'route': '/current-schedule',
        'data': <String, dynamic>{
          'type': 'schedule_published',
          'timetableId': timetableRef.id,
        },
      });
      notificationsSent++;
    } catch (e) {
      notificationError = e.toString();
    }

    return <String, dynamic>{
      'teacherDocsWritten': teacherDocsWritten,
      'classDocsWritten': classDocsWritten,
      'waitingSlotsCreated': waitingSlotsCreated,
      'waitingSlotsPerPeriod': maxSlotsPerPeriod,
      'timetableId': timetableRef.id,
      'notificationsSent': notificationsSent,
      'notificationError': notificationError,
    };
  }

  String _classDocId(String classId) {
    return classId.replaceAll('/', '_');
  }

  int _waitQuota(int weeklyLoad) {
    if (weeklyLoad >= 24) return 0;
    if (weeklyLoad >= 22) return 2;
    if (weeklyLoad >= 20) return 4;
    if (weeklyLoad >= 18) return 6;
    return 8;
  }

  String _waitingLabel(int rank) {
    if (rank == 1) return 'منتظر أول';
    if (rank == 2) return 'منتظر ثاني';
    if (rank == 3) return 'منتظر ثالث';
    return 'منتظر';
  }
}
