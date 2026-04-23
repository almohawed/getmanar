class ScheduleStats {
  final int classesCount;
  final int teachersCount;
  final bool hasActiveSchedule;
  final DateTime? lastUpdate;
  final int activeSchedulesCount;

  const ScheduleStats({
    required this.classesCount,
    required this.teachersCount,
    required this.hasActiveSchedule,
    this.lastUpdate,
    required this.activeSchedulesCount,
  });

  factory ScheduleStats.empty() {
    return const ScheduleStats(
      classesCount: 0,
      teachersCount: 0,
      hasActiveSchedule: false,
      lastUpdate: null,
      activeSchedulesCount: 0,
    );
  }
}
