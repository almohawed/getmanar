import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../exams/data/firestore_exams_repository.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/domain/classroom.dart';

class ExamScheduleFilters {
  final String? termId;
  final String? classId;
  final String? subjectId;
  final DateTime? date;
  ExamScheduleFilters({this.termId, this.classId, this.subjectId, this.date});

  @override
  bool operator ==(Object other) {
    return other is ExamScheduleFilters &&
        other.termId == termId &&
        other.classId == classId &&
        other.subjectId == subjectId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(termId, classId, subjectId, date);
}

final examSchedulesProvider = StreamProvider.family
    .autoDispose<List<ExamSchedule>, ExamScheduleFilters>((ref, filters) {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) {
        return Stream.value(const <ExamSchedule>[]);
      }
      return repo.watchSchedules(
        schoolId,
        termId: filters.termId,
        classId: filters.classId,
        subjectId: filters.subjectId,
        date: filters.date,
      );
    });

class CreateScheduleParams {
  final String termId;
  final String stage;
  final String grade;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String examType;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String roomId;
  final int maxPerDayPerClass;
  final bool preventTwoCoreSameDay;
  CreateScheduleParams({
    required this.termId,
    required this.stage,
    required this.grade,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.examType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    this.maxPerDayPerClass = 2,
    this.preventTwoCoreSameDay = false,
  });
}

final createScheduleProvider = FutureProvider.family
    .autoDispose<String, CreateScheduleParams>((ref, p) async {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final createdBy = user?.id ?? '';
      return repo.createSchedule(
        schoolId,
        payload: {
          'termId': p.termId,
          'stage': p.stage,
          'grade': p.grade,
          'classId': p.classId,
          'subjectId': p.subjectId,
          'teacherId': p.teacherId,
          'examType': p.examType,
          'date': p.date,
          'startTime': p.startTime,
          'endTime': p.endTime,
          'roomId': p.roomId,
        },
        createdBy: createdBy,
        maxPerDayPerClass: p.maxPerDayPerClass,
        preventTwoCoreSameDay: p.preventTwoCoreSameDay,
      );
    });

final publishScheduleProvider = FutureProvider.family.autoDispose<void, String>(
  (ref, scheduleId) async {
    final repo = ref.read(examsRepositoryProvider);
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    await repo.publishSchedule(schoolId, scheduleId);
  },
);

class AmendScheduleParams {
  final String scheduleId;
  final Map<String, dynamic> changes;
  final String reason;
  AmendScheduleParams({
    required this.scheduleId,
    required this.changes,
    required this.reason,
  });
}

final amendScheduleProvider = FutureProvider.family
    .autoDispose<void, AmendScheduleParams>((ref, p) async {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final actorId = user?.id ?? '';
      await repo.amendSchedule(
        schoolId,
        p.scheduleId,
        changes: p.changes,
        reason: p.reason,
        actorId: actorId,
      );
    });

final deleteScheduleProvider = FutureProvider.family.autoDispose<void, String>((
  ref,
  scheduleId,
) async {
  final repo = ref.read(examsRepositoryProvider);
  final user = ref.read(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  await repo.deleteSchedule(schoolId, scheduleId);
});

class RoomConflictsParams {
  final String roomId;
  final DateTime date;
  RoomConflictsParams(this.roomId, this.date);
}

final roomConflictsProvider = FutureProvider.family
    .autoDispose<List<ExamSchedule>, RoomConflictsParams>((ref, p) async {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      return repo.getRoomConflicts(schoolId, p.roomId, p.date);
    });

final studentExamsProvider = StreamProvider.autoDispose<List<ExamSchedule>>((
  ref,
) async* {
  final repo = ref.read(examsRepositoryProvider);
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) {
    yield const <ExamSchedule>[];
    return;
  }
  yield* repo.watchSchedulesForStudent(schoolId, user!.id);
});

final teacherExamsProvider = StreamProvider.autoDispose<List<ExamSchedule>>((
  ref,
) async* {
  final repo = ref.read(examsRepositoryProvider);
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) {
    yield const <ExamSchedule>[];
    return;
  }
  yield* repo.watchSchedulesForTeacher(schoolId, user!.id);
});

final committeesProvider = StreamProvider.family
    .autoDispose<List<ExamCommittee>, String?>((ref, termId) {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) {
        return Stream.value(const <ExamCommittee>[]);
      }
      return repo.watchCommittees(schoolId, termId: termId);
    });

class CreateCommitteeParams {
  final String termId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String roomId;
  final String supervisorId;
  final String? backupSupervisorId;
  final List<String> assignedClassIds;
  CreateCommitteeParams({
    required this.termId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.supervisorId,
    this.backupSupervisorId,
    required this.assignedClassIds,
  });
}

final createCommitteeProvider = FutureProvider.family
    .autoDispose<String, CreateCommitteeParams>((ref, p) async {
      final repo = ref.read(examsRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final createdBy = user?.id ?? '';
      return repo.createCommittee(
        schoolId,
        payload: {
          'termId': p.termId,
          'date': p.date,
          'startTime': p.startTime,
          'endTime': p.endTime,
          'roomId': p.roomId,
          'supervisorId': p.supervisorId,
          'backupSupervisorId': p.backupSupervisorId,
          'assignedClassIds': p.assignedClassIds,
        },
        createdBy: createdBy,
      );
    });

final gradesTrackingProvider = FutureProvider.family
    .autoDispose<List<ExamGradesTrack>, ({String? termId, String? classId})>((
      ref,
      f,
    ) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const <ExamGradesTrack>[];
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'listExamGradesTrackingForSchool',
        );
        final res = await callable
            .call({
              'schoolId': schoolId,
              if (f.termId?.isNotEmpty == true) 'termId': f.termId,
              if (f.classId?.isNotEmpty == true) 'classId': f.classId,
            })
            .timeout(const Duration(seconds: 15));
        final data = res.data;
        if (data is Map && data['items'] is List) {
          return (data['items'] as List).whereType<Map>().map((m) {
            final mm = Map<String, dynamic>.from(m);
            final id = (mm['id'] ?? '').toString();
            mm.remove('id');
            return ExamGradesTrack.fromMap(id, mm);
          }).toList();
        }
      } catch (_) {}
      return const <ExamGradesTrack>[];
    });

final examClassesProvider = FutureProvider.autoDispose<List<Classroom>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const <Classroom>[];
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'listClassesForSchool',
    );
    final res = await callable
        .call({'schoolId': schoolId})
        .timeout(const Duration(seconds: 15));
    final data = res.data;
    if (data is Map && data['classes'] is List) {
      final list = (data['classes'] as List)
          .whereType<Map>()
          .map((m) => Classroom.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      list.sort((a, b) => a.preferredLabel.compareTo(b.preferredLabel));
      return list;
    }
  } catch (_) {}
  return const <Classroom>[];
});

final recalcGradesTrackProvider = FutureProvider.family
    .autoDispose<void, String>((ref, trackId) async {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      final callable = FirebaseFunctions.instance.httpsCallable(
        'recalcExamGradesTrack',
      );
      await callable.call({'schoolId': schoolId, 'trackId': trackId});
    });

class RecordExamAttendanceParams {
  final String termId;
  final String scheduleId;
  final String studentId;
  final String classId;
  final String subjectId;
  final String status;
  final String? excuseDocUrl;
  RecordExamAttendanceParams({
    required this.termId,
    required this.scheduleId,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.status,
    this.excuseDocUrl,
  });
}

final examAttendanceProvider = FutureProvider.family
    .autoDispose<List<ExamAttendanceRecord>, ExamScheduleFilters>((
      ref,
      f,
    ) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const <ExamAttendanceRecord>[];
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'listExamAttendanceForSchool',
        );
        final res = await callable
            .call({
              'schoolId': schoolId,
              if (f.termId?.isNotEmpty == true) 'termId': f.termId,
              if (f.classId?.isNotEmpty == true) 'classId': f.classId,
              if (f.subjectId?.isNotEmpty == true) 'subjectId': f.subjectId,
              if (f.date != null) 'date': f.date!.toIso8601String(),
            })
            .timeout(const Duration(seconds: 15));
        final data = res.data;
        if (data is Map && data['items'] is List) {
          return (data['items'] as List).whereType<Map>().map((m) {
            final mm = Map<String, dynamic>.from(m);
            final id = (mm['id'] ?? '').toString();
            mm.remove('id');
            return ExamAttendanceRecord.fromMap(id, mm);
          }).toList();
        }
      } catch (_) {}
      return const <ExamAttendanceRecord>[];
    });

final recordExamAttendanceProvider = FutureProvider.family
    .autoDispose<void, RecordExamAttendanceParams>((ref, p) async {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      final id = FirebaseFirestore.instance.collection('_').doc().id;
      final callable = FirebaseFunctions.instance.httpsCallable(
        'upsertExamAttendanceRecord',
      );
      await callable.call({
        'schoolId': schoolId,
        'id': id,
        'termId': p.termId,
        'scheduleId': p.scheduleId,
        'studentId': p.studentId,
        'classId': p.classId,
        'subjectId': p.subjectId,
        'status': p.status,
        if (p.excuseDocUrl?.isNotEmpty == true) 'excuseDocUrl': p.excuseDocUrl,
      });
    });

class AddGradeEntryParams {
  final String trackId;
  final String studentId;
  final String subjectId;
  final String termId;
  final String teacherId;
  final double score;
  AddGradeEntryParams({
    required this.trackId,
    required this.studentId,
    required this.subjectId,
    required this.termId,
    required this.teacherId,
    required this.score,
  });
}

final addGradeEntryProvider = FutureProvider.family
    .autoDispose<void, AddGradeEntryParams>((ref, p) async {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      final callable = FirebaseFunctions.instance.httpsCallable(
        'upsertExamGradeEntry',
      );
      await callable.call({
        'schoolId': schoolId,
        'trackId': p.trackId,
        'studentId': p.studentId,
        'subjectId': p.subjectId,
        'termId': p.termId,
        'teacherId': p.teacherId,
        'score': p.score,
      });
    });

final examTermsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const <String>[];
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'listExamTermsForSchool',
    );
    final res = await callable
        .call({'schoolId': schoolId})
        .timeout(const Duration(seconds: 15));
    final data = res.data;
    if (data is Map && data['terms'] is List) {
      return (data['terms'] as List).map((e) => e.toString()).toList();
    }
  } catch (_) {}
  return const <String>[];
});
