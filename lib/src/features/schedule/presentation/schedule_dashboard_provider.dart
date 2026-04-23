import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule_stats.dart';

final scheduleStatsProvider = FutureProvider<ScheduleStats>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  
  if (schoolId == null || schoolId.isEmpty) {
    return ScheduleStats.empty();
  }

  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.getScheduleStats(schoolId);
});
