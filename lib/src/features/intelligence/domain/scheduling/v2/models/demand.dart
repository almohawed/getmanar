class DemandModel {
  final int demandedLessons;
  final int placedLessons;
  final int unplacedLessons;
  final int teacherConflicts;
  final int classConflicts;
  final int solverPasses;
  final int retryCount;
  final int swapCount;
  final Map<String, dynamic> data;

  const DemandModel({
    required this.demandedLessons,
    required this.placedLessons,
    required this.unplacedLessons,
    required this.teacherConflicts,
    required this.classConflicts,
    required this.solverPasses,
    required this.retryCount,
    required this.swapCount,
    this.data = const <String, dynamic>{},
  });

  Map<String, dynamic> summary() {
    return {
      'demandedLessons': demandedLessons,
      'placedLessons': placedLessons,
      'unplacedLessons': unplacedLessons,
      'teacherConflicts': teacherConflicts,
      'classConflicts': classConflicts,
      'solverPasses': solverPasses,
      'retryCount': retryCount,
      'swapCount': swapCount,
    };
  }
}
