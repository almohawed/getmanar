import 'dart:async';

import '../analyzer/school_analyzer.dart';
import '../assignment/assignment_engine.dart';
import '../balancer/balancer_engine.dart';
import '../diagnosis/unplaced_diagnosis_engine.dart';
import '../models/progress.dart';
import '../models/report.dart';
import '../policy/policy_engine.dart';
import '../publisher/publisher_engine.dart';
import '../solver/solver_engine.dart';
import '../solver/ultra_fast_solver.dart';

enum SolverMode {
  standard,
  ultraFast,
}

class SmartTimetableOrchestrator {
  final SchoolAnalyzer analyzer;
  final PolicyEngine policyEngine;
  final AssignmentEngine assignmentEngine;
  final SolverEngine solverEngine;
  final UltraFastSolver ultraFastSolver;
  final BalancerEngine balancerEngine;
  final PublisherEngine publisherEngine;
  final SolverMode solverMode;

  const SmartTimetableOrchestrator({
    this.analyzer = const SchoolAnalyzer(),
    this.policyEngine = const PolicyEngine(),
    this.assignmentEngine = const AssignmentEngine(),
    this.solverEngine = const SolverEngine(),
    this.ultraFastSolver = const UltraFastSolver(),
    this.balancerEngine = const BalancerEngine(),
    this.publisherEngine = const PublisherEngine(),
    this.solverMode = SolverMode.ultraFast,
  });

  Stream<ScheduleGenerationProgress> generateWithProgress(
    String schoolId, {
    bool publishDespiteUnplaced = false,
  }) {
    final controller = StreamController<ScheduleGenerationProgress>();
    () async {
      final sw = Stopwatch()..start();
      void emit(
        ScheduleGenerationPhase phase,
        String label, {
        double? progress,
        int? demandedLessons,
        int? placedLessons,
        int? unplacedLessons,
        Map<String, dynamic> data = const <String, dynamic>{},
        ScheduleReport? report,
        ScheduleGenerationArtifacts? artifacts,
      }) {
        controller.add(
          ScheduleGenerationProgress(
            phase: phase,
            label: label,
            elapsedMs: sw.elapsedMilliseconds,
            progress: progress,
            demandedLessons: demandedLessons,
            placedLessons: placedLessons,
            unplacedLessons: unplacedLessons,
            data: data,
            report: report,
            artifacts: artifacts,
          ),
        );
      }

      try {
        emit(ScheduleGenerationPhase.analyzer, 'Analyzer', progress: 0.02);
        final snapshot = await analyzer.analyze(schoolId);
        emit(
          ScheduleGenerationPhase.analyzer,
          'Analyzer',
          progress: 0.15,
          data: <String, dynamic>{
            'stage': snapshot.stage,
            'grades': snapshot.effectiveGradeLevels,
            'classes': snapshot.classesCount,
            'teachers': snapshot.teachersCount,
            'subjects': snapshot.subjectsCount,
          },
        );

        emit(ScheduleGenerationPhase.policy, 'Policy', progress: 0.2);
        final policy = await policyEngine.resolve(snapshot);
        emit(
          ScheduleGenerationPhase.policy,
          'Policy',
          progress: 0.3,
          data: <String, dynamic>{
            'policyStageKey': policy.stageKey,
            'policyFile': policy.policyFile,
          },
        );

        emit(ScheduleGenerationPhase.assignment, 'Assignment', progress: 0.35);
        final assignment = assignmentEngine.assign(snapshot, policy);
        final uncoveredSubjectNames = <String>[];
        if (assignment.uncoveredSubjectIds.isNotEmpty) {
          final nameById = {for (final s in snapshot.subjects) s.id: s.name};
          for (final id in assignment.uncoveredSubjectIds) {
            uncoveredSubjectNames.add(nameById[id] ?? id);
          }
        }
        emit(
          ScheduleGenerationPhase.assignment,
          'Assignment',
          progress: 0.45,
          data: <String, dynamic>{
            'assignmentSummary': assignment.summary.toMap(),
            'uncoveredSubjects': uncoveredSubjectNames,
          },
        );

        emit(ScheduleGenerationPhase.solver, 'Solver', progress: 0.5);
        final solver = solverMode == SolverMode.ultraFast
            ? await ultraFastSolver.solve(
                snapshot,
                policy,
                assignment,
                onProgress: ({
                  required int demandedLessons,
                  required int placedLessons,
                  required int unplacedLessons,
                  required String label,
                }) {
                  emit(
                    ScheduleGenerationPhase.solver,
                    label,
                    progress: 0.5 +
                        (demandedLessons > 0
                            ? 0.25 * (placedLessons / demandedLessons).clamp(0, 1)
                            : 0),
                    demandedLessons: demandedLessons,
                    placedLessons: placedLessons,
                    unplacedLessons: unplacedLessons,
                    data: <String, dynamic>{'solverMode': 'ultra_fast'},
                  );
                },
              )
            : await solverEngine.solve(
                snapshot,
                policy,
                assignment,
                onProgress: ({
                  required int demandedLessons,
                  required int placedLessons,
                  required int unplacedLessons,
                  required int solverPass,
                  required String label,
                }) {
                  emit(
                    ScheduleGenerationPhase.solver,
                    label,
                    progress: 0.5 +
                        (demandedLessons > 0
                            ? 0.25 * (placedLessons / demandedLessons).clamp(0, 1)
                            : 0),
                    demandedLessons: demandedLessons,
                    placedLessons: placedLessons,
                    unplacedLessons: unplacedLessons,
                    data: <String, dynamic>{'solverPass': solverPass, 'solverMode': 'standard'},
                  );
                },
              );
        emit(
          ScheduleGenerationPhase.solver,
          'Solver',
          progress: 0.75,
          demandedLessons: solver.demandedLessons,
          placedLessons: solver.placedLessons,
          unplacedLessons: solver.unplacedLessons,
          data: <String, dynamic>{
            ...solver.summary(),
            'unplacedBreakdown':
                (solver.data['unplacedBreakdown'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{},
          },
        );

        emit(ScheduleGenerationPhase.balancer, 'Balancer', progress: 0.78);
        final balanced = await balancerEngine.balance(
          snapshot: snapshot,
          policy: policy,
          assignment: assignment,
          demand: solver,
        );
        emit(
          ScheduleGenerationPhase.balancer,
          'Balancer',
          progress: 0.88,
          demandedLessons: solver.demandedLessons,
          placedLessons: solver.placedLessons,
          unplacedLessons: solver.unplacedLessons,
          data:
              (balanced.data['balancerSummary'] as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        );

        final v2Diagnosis = await const UnplacedDiagnosisEngine().diagnose(
          snapshot: snapshot,
          policy: policy,
          assignment: assignment,
          balanced: balanced,
        );

        final shouldPublish =
            solver.unplacedLessons <= 0 || publishDespiteUnplaced;
        Map<String, dynamic> publishSummary = const <String, dynamic>{
          'skipped': true,
          'reason': 'unplaced_lessons',
        };
        if (shouldPublish) {
          emit(ScheduleGenerationPhase.publisher, 'Publisher', progress: 0.92);
          publishSummary = await publisherEngine.publish(
            schoolId: snapshot.schoolId,
            snapshot: snapshot,
            policy: policy,
            assignment: assignment,
            balanced: balanced,
            allowIncomplete: publishDespiteUnplaced,
          );
          emit(
            ScheduleGenerationPhase.publisher,
            'Publisher',
            progress: 0.98,
            data: publishSummary,
          );
        } else {
          emit(
            ScheduleGenerationPhase.publisher,
            'Publisher (skipped)',
            progress: 0.92,
            demandedLessons: solver.demandedLessons,
            placedLessons: solver.placedLessons,
            unplacedLessons: solver.unplacedLessons,
            data: publishSummary,
          );
        }

        final report = ScheduleReport(
          schoolId: snapshot.schoolId,
          stage: snapshot.stage,
          policyId: policy.id,
          policyFile: policy.policyFile,
          grades: snapshot.grades,
          teachers: snapshot.teachersCount,
          subjects: snapshot.subjectsCount,
          classes: snapshot.classesCount,
          daysPerWeek: snapshot.daysPerWeek,
          periodsPerDay: snapshot.periodsPerDay,
          runtimeMs: sw.elapsedMilliseconds,
          data: <String, dynamic>{
            'secondaryProgramType': snapshot.secondaryProgramType,
            'secondaryStructure': snapshot.secondaryStructure,
            'enabledTracks': snapshot.enabledTracks,
            'schoolEducationProfile': snapshot.schoolEducationProfile,
            'policyStageKey': policy.stageKey,
            'lowerPrimaryClassesCount': snapshot.lowerPrimaryClassesCount,
            'upperPrimaryClassesCount': snapshot.upperPrimaryClassesCount,
            'assignmentSummary': assignment.summary.toMap(),
            'uncoveredSubjectsCount': assignment.uncoveredSubjectIds.length,
            'uncoveredSubjects': uncoveredSubjectNames,
            'solverSummary': solver.summary(),
            'demandedLessons': solver.demandedLessons,
            'placedLessons': solver.placedLessons,
            'unplacedLessons': solver.unplacedLessons,
            'unplacedBreakdown':
                (solver.data['unplacedBreakdown'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{},
            'teacherConflicts': solver.teacherConflicts,
            'classConflicts': solver.classConflicts,
            'balancerSummary':
                (balanced.data['balancerSummary'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{},
            'publisherSummary': publishSummary,
            'v2FinalDiagnosis': v2Diagnosis,
            'analyzerDebug': <String, dynamic>{
              'classesSourcePath': snapshot.classesSourcePath,
              'rawClassDocIds': snapshot.rawClassDocIds,
              'rawClassGradeLevels': snapshot.rawClassGradeLevels,
              'parsedClassGradeLevels': snapshot.parsedClassGradeLevels,
              'effectiveGradeLevels': snapshot.effectiveGradeLevels,
              'classInterpretationMode': snapshot.classInterpretationMode,
              'classDebugSample': snapshot.classDebugSample,
            },
          },
        );

        emit(
          ScheduleGenerationPhase.done,
          'Done',
          progress: 1.0,
          demandedLessons: solver.demandedLessons,
          placedLessons: solver.placedLessons,
          unplacedLessons: solver.unplacedLessons,
          data: <String, dynamic>{'v2FinalDiagnosis': v2Diagnosis},
          report: report,
          artifacts: ScheduleGenerationArtifacts(
            snapshot: snapshot,
            policy: policy,
            assignment: assignment,
            balanced: balanced,
          ),
        );
      } catch (e) {
        emit(
          ScheduleGenerationPhase.done,
          'Error',
          progress: 1.0,
          data: <String, dynamic>{'error': '$e'},
        );
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }

  Future<ScheduleReport> generate(
    String schoolId, {
    bool publishDespiteUnplaced = false,
  }) async {
    final sw = Stopwatch()..start();

    final snapshot = await analyzer.analyze(schoolId);
    final policy = await policyEngine.resolve(snapshot);
    final assignment = assignmentEngine.assign(snapshot, policy);
    if (snapshot.stage == 'primary_only') {
      final solver = solverMode == SolverMode.ultraFast
          ? await ultraFastSolver.solve(snapshot, policy, assignment)
          : await solverEngine.solve(snapshot, policy, assignment);
      final balanced = await balancerEngine.balance(
        snapshot: snapshot,
        policy: policy,
        assignment: assignment,
        demand: solver,
      );
      final v2Diagnosis = await const UnplacedDiagnosisEngine().diagnose(
        snapshot: snapshot,
        policy: policy,
        assignment: assignment,
        balanced: balanced,
      );
      final shouldPublish =
          solver.unplacedLessons <= 0 || publishDespiteUnplaced;
      final publishSummary = shouldPublish
          ? await publisherEngine.publish(
              schoolId: snapshot.schoolId,
              snapshot: snapshot,
              policy: policy,
              assignment: assignment,
              balanced: balanced,
              allowIncomplete: publishDespiteUnplaced,
            )
          : const <String, dynamic>{
              'skipped': true,
              'reason': 'unplaced_lessons',
            };
      return ScheduleReport(
        schoolId: snapshot.schoolId,
        stage: snapshot.stage,
        policyId: policy.id,
        policyFile: policy.policyFile,
        grades: snapshot.grades,
        teachers: snapshot.teachersCount,
        subjects: snapshot.subjectsCount,
        classes: snapshot.classesCount,
        daysPerWeek: snapshot.daysPerWeek,
        periodsPerDay: snapshot.periodsPerDay,
        runtimeMs: sw.elapsedMilliseconds,
        data: <String, dynamic>{
          'secondaryProgramType': snapshot.secondaryProgramType,
          'secondaryStructure': snapshot.secondaryStructure,
          'enabledTracks': snapshot.enabledTracks,
          'schoolEducationProfile': snapshot.schoolEducationProfile,
          'policyStageKey': policy.stageKey,
          'lowerPrimaryClassesCount': snapshot.lowerPrimaryClassesCount,
          'upperPrimaryClassesCount': snapshot.upperPrimaryClassesCount,
          'assignmentSummary': assignment.summary.toMap(),
          'uncoveredSubjectsCount': assignment.uncoveredSubjectIds.length,
          'solverSummary': solver.summary(),
          'demandedLessons': solver.demandedLessons,
          'placedLessons': solver.placedLessons,
          'unplacedLessons': solver.unplacedLessons,
          'teacherConflicts': solver.teacherConflicts,
          'classConflicts': solver.classConflicts,
          'balancerSummary':
              (balanced.data['balancerSummary'] as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{},
          'publisherSummary': publishSummary,
          'v2FinalDiagnosis': v2Diagnosis,
          'analyzerDebug': <String, dynamic>{
            'classesSourcePath': snapshot.classesSourcePath,
            'rawClassDocIds': snapshot.rawClassDocIds,
            'rawClassGradeLevels': snapshot.rawClassGradeLevels,
            'effectiveGradeLevels': snapshot.effectiveGradeLevels,
            'classInterpretationMode': snapshot.classInterpretationMode,
            'classDebugSample': snapshot.classDebugSample,
          },
        },
      );
    }
    final solver = solverMode == SolverMode.ultraFast
        ? await ultraFastSolver.solve(snapshot, policy, assignment)
        : await solverEngine.solve(snapshot, policy, assignment);
    final balanced = await balancerEngine.balance(
      snapshot: snapshot,
      policy: policy,
      assignment: assignment,
      demand: solver,
    );
    final v2Diagnosis = await const UnplacedDiagnosisEngine().diagnose(
      snapshot: snapshot,
      policy: policy,
      assignment: assignment,
      balanced: balanced,
    );
    final shouldPublish = solver.unplacedLessons <= 0 || publishDespiteUnplaced;
    final publishSummary = shouldPublish
        ? await publisherEngine.publish(
            schoolId: snapshot.schoolId,
            snapshot: snapshot,
            policy: policy,
            assignment: assignment,
            balanced: balanced,
            allowIncomplete: publishDespiteUnplaced,
          )
        : const <String, dynamic>{
            'skipped': true,
            'reason': 'unplaced_lessons',
          };

    return ScheduleReport(
      schoolId: snapshot.schoolId,
      stage: snapshot.stage,
      policyId: policy.id,
      policyFile: policy.policyFile,
      grades: snapshot.grades,
      teachers: snapshot.teachersCount,
      subjects: snapshot.subjectsCount,
      classes: snapshot.classesCount,
      daysPerWeek: snapshot.daysPerWeek,
      periodsPerDay: snapshot.periodsPerDay,
      runtimeMs: sw.elapsedMilliseconds,
      data: <String, dynamic>{
        'secondaryProgramType': snapshot.secondaryProgramType,
        'secondaryStructure': snapshot.secondaryStructure,
        'enabledTracks': snapshot.enabledTracks,
        'schoolEducationProfile': snapshot.schoolEducationProfile,
        'policyStageKey': policy.stageKey,
        'lowerPrimaryClassesCount': snapshot.lowerPrimaryClassesCount,
        'upperPrimaryClassesCount': snapshot.upperPrimaryClassesCount,
        'assignmentSummary': assignment.summary.toMap(),
        'uncoveredSubjectsCount': assignment.uncoveredSubjectIds.length,
        'solverSummary': solver.summary(),
        'balancerSummary':
            (balanced.data['balancerSummary'] as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{},
        'publisherSummary': publishSummary,
        'analyzerDebug': <String, dynamic>{
          'classesSourcePath': snapshot.classesSourcePath,
          'rawClassDocIds': snapshot.rawClassDocIds,
          'rawClassGradeLevels': snapshot.rawClassGradeLevels,
          'parsedClassGradeLevels': snapshot.parsedClassGradeLevels,
          'effectiveGradeLevels': snapshot.effectiveGradeLevels,
          'classInterpretationMode': snapshot.classInterpretationMode,
          'classDebugSample': snapshot.classDebugSample,
        },
      },
    );
  }
}
