import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/academic_supervision_repository.dart';
import '../../../core/domain/models/user.dart';

final academicSupervisionRepositoryProvider =
    Provider<AcademicSupervisionRepository>((ref) {
      return AcademicSupervisionRepository(FirebaseFirestore.instance);
    });

class CurriculumFilters {
  final String? classId;
  final String? subjectId;
  const CurriculumFilters({this.classId, this.subjectId});

  @override
  bool operator ==(Object other) {
    return other is CurriculumFilters &&
        other.classId == classId &&
        other.subjectId == subjectId;
  }

  @override
  int get hashCode => Object.hash(classId, subjectId);
}

final curriculumProgressProvider = FutureProvider.family
    .autoDispose<List<CurriculumProgress>, CurriculumFilters>((
      ref,
      filters,
    ) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const <CurriculumProgress>[];
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'listCurriculumProgressForSchool',
        );
        final res = await callable
            .call({
              'schoolId': schoolId,
              if (filters.classId?.isNotEmpty == true)
                'classId': filters.classId,
              if (filters.subjectId?.isNotEmpty == true)
                'subjectId': filters.subjectId,
            })
            .timeout(const Duration(seconds: 15));
        final data = res.data;
        if (data is Map && data['items'] is List) {
          return (data['items'] as List)
              .whereType<Map>()
              .map(
                (m) => CurriculumProgress.fromMap(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      } catch (_) {}
      return const <CurriculumProgress>[];
    });

final schoolTeachersMapProvider = FutureProvider.autoDispose<Map<String, User>>(
  (ref) async {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return {};
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'listTeachersForSchool',
      );
      final res = await callable
          .call({'schoolId': schoolId})
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map && data['teachers'] is List) {
        final list = (data['teachers'] as List)
            .whereType<Map>()
            .map((m) => User.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        return {for (final t in list) t.id: t};
      }
      return {};
    } catch (_) {
      return {};
    }
  },
);

class WeekRange {
  final DateTime from;
  final DateTime to;
  final String? teacherId;
  const WeekRange({required this.from, required this.to, this.teacherId});

  @override
  bool operator ==(Object other) {
    return other is WeekRange &&
        other.from == from &&
        other.to == to &&
        other.teacherId == teacherId;
  }

  @override
  int get hashCode => Object.hash(from, to, teacherId);
}

class LessonPrepCompliance {
  final int totalRecords;
  final int preparedCount;
  final double complianceRate;
  final List<LessonPrepRecord> records;
  LessonPrepCompliance({
    required this.totalRecords,
    required this.preparedCount,
    required this.complianceRate,
    required this.records,
  });
}

final lessonPrepComplianceProvider = FutureProvider.family
    .autoDispose<LessonPrepCompliance, WeekRange>((ref, range) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        return LessonPrepCompliance(
          totalRecords: 0,
          preparedCount: 0,
          complianceRate: 0.0,
          records: const <LessonPrepRecord>[],
        );
      }
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'listLessonPrepRecordsForSchool',
        );
        final res = await callable
            .call({
              'schoolId': schoolId,
              'from': range.from.toIso8601String(),
              'to': range.to.toIso8601String(),
              if (range.teacherId?.isNotEmpty == true)
                'teacherId': range.teacherId,
            })
            .timeout(const Duration(seconds: 15));
        final data = res.data;
        final items = (data is Map && data['items'] is List)
            ? (data['items'] as List)
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
            : const <Map<String, dynamic>>[];
        final records = items.map((m) {
          final id = (m['id'] ?? '').toString();
          final map = Map<String, dynamic>.from(m);
          map.remove('id');
          return LessonPrepRecord.fromMap(map, id);
        }).toList();
        final total = records.length;
        final prepared = records.where((r) => r.prepared).length;
        final rate = total == 0 ? 0.0 : (prepared / total) * 100.0;
        return LessonPrepCompliance(
          totalRecords: total,
          preparedCount: prepared,
          complianceRate: rate,
          records: records,
        );
      } catch (_) {
        return LessonPrepCompliance(
          totalRecords: 0,
          preparedCount: 0,
          complianceRate: 0.0,
          records: const <LessonPrepRecord>[],
        );
      }
    });

final pacingDelayProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(academicSupervisionRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null || user.schoolId!.isEmpty) {
        return [];
      }
      return repo.getPacingDelays(user.schoolId!);
    });

class AlertFilters {
  final String? severity;
  final String? status;
  const AlertFilters({this.severity, this.status});

  @override
  bool operator ==(Object other) {
    return other is AlertFilters &&
        other.severity == severity &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(severity, status);
}

final academicAlertsProvider = StreamProvider.family
    .autoDispose<List<AcademicAlert>, AlertFilters>((ref, filters) {
      final repo = ref.watch(academicSupervisionRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null || user.schoolId!.isEmpty) {
        return Stream.value(const <AcademicAlert>[]);
      }
      return repo
          .watchAcademicAlerts(
            user.schoolId!,
            severity: filters.severity,
            status: filters.status,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: (sink) {
              sink.add(const <AcademicAlert>[]);
              sink.close();
            },
          );
    });
