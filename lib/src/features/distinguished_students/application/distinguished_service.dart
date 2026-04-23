import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/firestore_student_repository.dart';
import '../../behavior/data/firestore_behavior_repository.dart';
import '../data/distinguished_repository.dart';
import '../domain/distinguished_cycle.dart';
import '../domain/distinguished_nomination.dart';

// Defines the logic for picking top students
class DistinguishedStudentService {
  final DistinguishedRepository _distinguishedRepo;
  final FirestoreStudentRepository _studentRepo; // Or generic StudentRepository
  final FirestoreBehaviorRepository _behaviorRepo;

  DistinguishedStudentService(
    this._distinguishedRepo,
    this._studentRepo,
    this._behaviorRepo,
  );

  // Main entry point: Check if we need to start a cycle, or move to next stage
  Future<void> checkAndRunCycle(String schoolId) async {
    DistinguishedCycle? currentCycle = await _distinguishedRepo.getCurrentCycle(
      schoolId,
    );
    final now = DateTime.now();

    // If no active cycle, or last cycle ended more than 2 weeks ago (logic depends on "every 2 weeks")
    // For simplicity: If no cycle exists, or the latest one is 'archived' or 'published' and old enough.
    // We will assume "Active" cycle means we are collecting data.

    if (currentCycle == null) {
      // Start a new cycle
      await _startNewCycle(schoolId);
    } else {
      // Check if active cycle period has ended (2 weeks passed)
      if (currentCycle.status == CycleStatus.active &&
          now.isAfter(currentCycle.endDate)) {
        // Move to Pending Deputy
        await _generateNominations(schoolId, currentCycle);
        final updatedCycle = DistinguishedCycle(
          id: currentCycle.id,
          schoolId: currentCycle.schoolId,
          startDate: currentCycle.startDate,
          endDate: currentCycle.endDate,
          status: CycleStatus.pendingDeputy,
        );
        await _distinguishedRepo.updateCycle(schoolId, updatedCycle);
      }

      // Check if published cycle has expired (1 week visibility)
      if (currentCycle.status == CycleStatus.published &&
          currentCycle.publishedAt != null &&
          now.difference(currentCycle.publishedAt!).inDays > 7) {
        // Archive it and maybe start new immediately?
        // For now just archive.
        final archivedCycle = DistinguishedCycle(
          id: currentCycle.id,
          schoolId: currentCycle.schoolId,
          startDate: currentCycle.startDate,
          endDate: currentCycle.endDate,
          status: CycleStatus.archived,
          publishedAt: currentCycle.publishedAt,
        );
        await _distinguishedRepo.updateCycle(schoolId, archivedCycle);

        // Start next cycle immediately?
        await _startNewCycle(schoolId);
      }
    }
  }

  Future<void> _startNewCycle(String schoolId) async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14)); // 2 weeks cycle
    final newCycle = DistinguishedCycle(
      id: const Uuid().v4(),
      schoolId: schoolId,
      startDate: now,
      endDate: endDate,
      status: CycleStatus.active,
    );
    await _distinguishedRepo.createCycle(schoolId, newCycle);
  }

  Future<void> _generateNominations(
    String schoolId,
    DistinguishedCycle cycle,
  ) async {
    // 1. Fetch all students for the school
    // This might be heavy for large schools, but necessary for calculation.
    // Better optimization: Fetch by stage/grade in batches.
    // We rely on repository to get stream or list.
    // Since we don't have a direct "getAllStudents" method in repo that returns List<User> easily without stream,
    // we'll assume we can get them.
    // Ideally we should use a cloud function, but here we do client-side logic.

    // For now, we simulate fetching via a known method or extend StudentRepo
    // Let's assume we can watch/get all.
    // Using `watchStudents` returns a stream, we can take first.
    final students = await _studentRepo.watchStudents(schoolId).first;

    // 2. Fetch Behavior Records for the cycle period
    // We need records between startDate and endDate.
    // Repo currently gets by student or class.
    // We need "getAllBehaviorForSchool(schoolId, dateRange)".
    // Since that doesn't exist, we iterate (inefficient but works for MVP).
    // Or we fetch per student.

    List<DistinguishedNomination> nominations = [];

    for (var student in students) {
      double score = await _calculateStudentScore(
        student,
        cycle.startDate,
        cycle.endDate,
      );

      nominations.add(
        DistinguishedNomination(
          id: const Uuid().v4(),
          cycleId: cycle.id,
          studentId: student.id,
          studentName: student.name,
          gradeLevel: _extractGradeLevel(student),
          stage: student.stage ?? 'Primary',
          score: score,
          // Breakdown (mocked for now inside calc)
          behaviorScore: score, // simplified
          attendanceScore: 0,
          academicScore: 0,
        ),
      );
    }

    // 3. Sort and Pick Top 10 per Grade
    // Group by Grade
    Map<String, List<DistinguishedNomination>> byGrade = {};
    for (var nom in nominations) {
      byGrade.putIfAbsent(nom.gradeLevel, () => []).add(nom);
    }

    List<DistinguishedNomination> finalNominations = [];

    byGrade.forEach((grade, list) {
      list.sort((a, b) => b.score.compareTo(a.score)); // Descending
      // Take top 10 + reserves (e.g. 20 total) to allow for replacement
      final top = list.take(20).toList();
      finalNominations.addAll(top);
    });

    await _distinguishedRepo.saveNominations(schoolId, finalNominations);
  }

  Future<double> _calculateStudentScore(
    User student,
    DateTime start,
    DateTime end,
  ) async {
    // Fetch behavior
    final records = await _behaviorRepo.getStudentBehavior(student.id);

    // Filter by date
    final cycleRecords = records
        .where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList();

    double points = 0;

    // Behavior Logic
    for (var r in cycleRecords) {
      if (r.type == BehaviorType.positive) points += r.points;
      if (r.type == BehaviorType.negative) {
        points -= r.points;
      } // Assume points are positive int in DB
      if (r.type == BehaviorType.escape) points -= 20; // Heavy penalty
    }

    // Add base score so everyone starts positive?
    points += 100;

    // Attendance Logic (Mocked if no repo)
    // If student has "Absence" record? (Assume handled in behavior or separate)

    return points;
  }

  String _extractGradeLevel(User student) {
    // Try to infer from assignedClassIds or stage
    // Ideally User model should have 'gradeLevel'.
    // If not, we use 'stage'.
    // If assignedClassIds is like 'Class 1-A', we parse '1'.
    return student.stage ?? 'Unknown';
  }

  // Deputy Actions
  Future<void> approveNomination(String schoolId, String nomId) async {
    // Get nom, set approved = true
  }

  Future<void> rejectNominationAndReplace(String schoolId, String nomId) async {
    // 1. Mark current nom as rejected/removed (or just delete?)
    // 2. Find next best in same grade from the pool we saved (we saved top 20).
    // 3. Promote next one to 'candidate' status.
    // Implementation requires status field in Nomination (e.g. candidate, reserve).
    // For MVP, we just set isApprovedByDeputy = false.
  }
}

final distinguishedStudentServiceProvider =
    Provider<DistinguishedStudentService>((ref) {
      return DistinguishedStudentService(
        ref.read(distinguishedRepositoryProvider),
        ref.read(
          firestoreStudentRepositoryProvider,
        ), // Need to export this provider
        ref.read(firestoreBehaviorRepositoryProvider), // Need to export this
      );
    });

// Need to ensure providers are available in respective files
final firestoreStudentRepositoryProvider = Provider<FirestoreStudentRepository>(
  (ref) {
    return FirestoreStudentRepository(FirebaseFirestore.instance);
  },
);

final firestoreBehaviorRepositoryProvider =
    Provider<FirestoreBehaviorRepository>((ref) {
      return FirestoreBehaviorRepository();
    });
