import 'assignment.dart';
import 'demand.dart';
import 'policy.dart';
import 'report.dart';
import 'snapshot.dart';

enum ScheduleGenerationPhase {
  analyzer,
  policy,
  assignment,
  solver,
  balancer,
  publisher,
  done,
}

class ScheduleGenerationArtifacts {
  final SchoolSnapshot snapshot;
  final PolicyProfile policy;
  final AssignmentModel assignment;
  final DemandModel balanced;

  const ScheduleGenerationArtifacts({
    required this.snapshot,
    required this.policy,
    required this.assignment,
    required this.balanced,
  });
}

class ScheduleGenerationProgress {
  final ScheduleGenerationPhase phase;
  final String label;
  final int elapsedMs;
  final double? progress;

  final int? demandedLessons;
  final int? placedLessons;
  final int? unplacedLessons;

  final Map<String, dynamic> data;
  final ScheduleReport? report;
  final ScheduleGenerationArtifacts? artifacts;

  const ScheduleGenerationProgress({
    required this.phase,
    required this.label,
    required this.elapsedMs,
    this.progress,
    this.demandedLessons,
    this.placedLessons,
    this.unplacedLessons,
    this.data = const <String, dynamic>{},
    this.report,
    this.artifacts,
  });
}

