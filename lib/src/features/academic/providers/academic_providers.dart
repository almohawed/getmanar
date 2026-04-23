import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/success_rates_service.dart';
import '../services/learning_gaps_service.dart';
import '../services/teacher_performance_service.dart';
import '../domain/performance_stats.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../schedule/data/schedule_repository.dart';

// Service Providers
final successRatesServiceProvider = Provider<SuccessRatesService>((ref) {
  return SuccessRatesService();
});

final learningGapsServiceProvider = Provider<LearningGapsService>((ref) {
  return LearningGapsService();
});

final teacherPerformanceServiceProvider = Provider<TeacherPerformanceService>((ref) {
  return TeacherPerformanceService();
});

// Data Providers
final performanceStatsProvider = FutureProvider<PerformanceStats>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return PerformanceStats.empty();
  }

  final service = ref.watch(successRatesServiceProvider);
  return await service.calculatePerformanceStats(user.schoolId!);
});

final gapStatsProvider = FutureProvider<GapStats>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return GapStats.empty();
  }

  final service = ref.watch(learningGapsServiceProvider);
  return await service.calculateGapStats(user.schoolId!);
});

final teacherStatsProvider = FutureProvider<List<TeacherStats>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return [];
  }

  final service = ref.watch(teacherPerformanceServiceProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);
  return await service.calculateAllTeachersStats(user.schoolId!, scheduleRepo);
});
