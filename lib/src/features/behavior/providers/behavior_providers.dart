import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/behavior_data_service.dart';

/// Provider للإحصائيات العامة للسلوك (محدث تلقائياً)
final behaviorStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return BehaviorDataService.getBehaviorStatsStream();
});

/// Provider للحالات النشطة (محدث تلقائياً)
final activeBehaviorCasesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return BehaviorDataService.getActiveCasesStream();
});

/// Provider لعدد الحالات النشطة
final activeCasesCountProvider = Provider<int>((ref) {
  final activeCasesAsync = ref.watch(activeBehaviorCasesProvider);
  return activeCasesAsync.when(
    data: (cases) => cases.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider لعدد الحالات الحرجة
final criticalCasesCountProvider = Provider<int>((ref) {
  final activeCasesAsync = ref.watch(activeBehaviorCasesProvider);
  return activeCasesAsync.when(
    data: (cases) => cases.where((case_) => case_['priority'] == 'عالي').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider لمؤشر السلوك العام
final behaviorScoreProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(behaviorStatsProvider);
  return statsAsync.when(
    data: (stats) => stats['behaviorScore'] as int? ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider لإجمالي المخالفات
final totalViolationsProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(behaviorStatsProvider);
  return statsAsync.when(
    data: (stats) => stats['totalViolations'] as int? ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider لإجمالي السلوك الإيجابي
final totalPositiveBehaviorProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(behaviorStatsProvider);
  return statsAsync.when(
    data: (stats) => stats['totalPositive'] as int? ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});