import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/domain/models/user.dart';
import '../data/firestore_school_intelligence_repository.dart';
import '../domain/school_health_index.dart';
import '../../auth/presentation/auth_controller.dart';

final schoolIntelligenceSnapshotProvider = FutureProvider.family
    .autoDispose<SchoolIntelligenceSnapshot?, String>((ref, termId) async {
      final user = ref.watch(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) return null;

      final callable = FirebaseFunctions.instance.httpsCallable(
        'getLatestSchoolIntelligenceSnapshotForSchool',
      );
      final res = await callable
          .call({
            'schoolId': schoolId,
            'termId': termId.trim().isEmpty ? 'current' : termId.trim(),
          })
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map && data['item'] is Map) {
        final item = Map<String, dynamic>.from(data['item'] as Map);
        final id = (item['id'] ?? '').toString();
        item.remove('id');
        return SchoolIntelligenceSnapshot.fromMap(id, item);
      }
      return null;
    });

final schoolIntelligenceSnapshotOnceProvider =
    FutureProvider<SchoolIntelligenceSnapshot?>((ref) async {
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return null;
      return repo.getLatestSnapshotOnce(schoolId);
    });

Future<String?> _repairSchoolId() async {
  try {
    final res = await FirebaseFunctions.instance
        .httpsCallable('repairCurrentUserLink')
        .call({});
    final d = res.data;
    if (d is Map && d['schoolId'] != null) {
      final sid = d['schoolId'].toString().trim();
      return sid.isEmpty ? null : sid;
    }
  } catch (_) {}
  return null;
}

final riskPredictionsProvider =
    FutureProvider.autoDispose<List<RiskPrediction>>((ref) async {
      final user = ref.watch(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) return const <RiskPrediction>[];

      final callable = FirebaseFunctions.instance.httpsCallable(
        'listRiskPredictionsForSchool',
      );
      final res = await callable
          .call({'schoolId': schoolId})
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).whereType<Map>().map((m) {
          final mm = Map<String, dynamic>.from(m);
          final id = (mm['id'] ?? '').toString();
          mm.remove('id');
          return RiskPrediction.fromMap(id, mm);
        }).toList();
      }
      return const <RiskPrediction>[];
    });

final riskPredictionsOnceProvider = FutureProvider<List<RiskPrediction>>((
  ref,
) async {
  final repo = ref.read(schoolIntelligenceRepositoryProvider);
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const <RiskPrediction>[];
  return repo.getRiskPredictionsOnce(schoolId);
});

final schoolHealthIndexProvider =
    FutureProvider.autoDispose<SchoolHealthIndex?>((ref) async {
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return null;
      return repo.getSchoolHealthIndex(schoolId);
    });

final remedialPlansProvider = FutureProvider.family
    .autoDispose<List<RemedialPlan>, String?>((ref, status) async {
      final user = ref.watch(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) return const <RemedialPlan>[];

      final callable = FirebaseFunctions.instance.httpsCallable(
        'listRemedialPlansForSchool',
      );
      final res = await callable
          .call({
            'schoolId': schoolId,
            if (status?.isNotEmpty == true) 'status': status,
          })
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).whereType<Map>().map((m) {
          final mm = Map<String, dynamic>.from(m);
          final id = (mm['id'] ?? '').toString();
          mm.remove('id');
          return RemedialPlan.fromMap(id, mm);
        }).toList();
      }
      return const <RemedialPlan>[];
    });

final remedialPlansOnceProvider =
    FutureProvider.family<List<RemedialPlan>, String?>((ref, status) async {
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const <RemedialPlan>[];
      return repo.getRemedialPlansOnce(schoolId, status: status);
    });

class ComputeIntelligenceParams {
  final String termId;
  ComputeIntelligenceParams(this.termId);
}

final computeIntelligenceProvider = FutureProvider.family
    .autoDispose<void, ComputeIntelligenceParams>((ref, p) async {
      final user = ref.read(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) throw Exception('School ID مفقود');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('computeSchoolIntelligenceNow');
      try {
        await callable.call({
          'schoolId': schoolId,
          'termId': p.termId.trim().isEmpty ? 'current' : p.termId.trim(),
        });
      } catch (e) {
        if (e is FirebaseFunctionsException) {
          throw Exception(e.message ?? 'تعذر تشغيل التحليل حالياً');
        }
        rethrow;
      }
    });

class UpdateRemedialProgressParams {
  final String planId;
  final Map<String, dynamic> delta;
  UpdateRemedialProgressParams(this.planId, this.delta);
}

final updateRemedialProgressProvider = FutureProvider.family
    .autoDispose<void, UpdateRemedialProgressParams>((ref, p) async {
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      await repo.updateRemedialProgress(schoolId, p.planId, p.delta);
    });
