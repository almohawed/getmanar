import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/teacher_follow_up.dart';

final teacherFollowUpsProvider =
    FutureProvider<Map<String, TeacherFollowUp>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const <String, TeacherFollowUp>{};
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listTeacherFollowUpsForSchool');
    final res = await callable.call({'schoolId': schoolId});
    final data = res.data;
    if (data is Map && data['items'] is List) {
      final items = (data['items'] as List)
          .whereType<Map>()
          .map((e) => TeacherFollowUp.fromMap(Map<String, dynamic>.from(e)))
          .where((f) => f.teacherId.trim().isNotEmpty)
          .toList();
      return {for (final f in items) f.teacherId: f};
    }
  } catch (_) {}
  return const <String, TeacherFollowUp>{};
});

class UpsertTeacherFollowUpParams {
  final String teacherId;
  final String status;
  final String note;
  final DateTime? nextReviewAt;

  const UpsertTeacherFollowUpParams({
    required this.teacherId,
    required this.status,
    required this.note,
    required this.nextReviewAt,
  });
}

final upsertTeacherFollowUpProvider =
    FutureProvider.family<void, UpsertTeacherFollowUpParams>((ref, p) async {
  final user = ref.read(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) throw Exception('missing_school');
  final callable =
      FirebaseFunctions.instance.httpsCallable('upsertTeacherFollowUp');
  await callable.call({
    'schoolId': schoolId,
    'teacherId': p.teacherId,
    'status': p.status,
    'note': p.note,
    if (p.nextReviewAt != null)
      'nextReviewAt': p.nextReviewAt!.toIso8601String(),
  });
});

final teacherFollowUpLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty || teacherId.trim().isEmpty) return const [];
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listTeacherFollowUpLogs');
    final res = await callable.call({'schoolId': schoolId, 'teacherId': teacherId});
    final data = res.data;
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  } catch (_) {}
  return const [];
});

