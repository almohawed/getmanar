import '../models/assignment.dart';
import '../models/demand.dart';
import '../models/policy.dart';
import '../models/snapshot.dart';
import '../collector/school_data_collector.dart';
import 'simple_clean_solver.dart';

/// محرك سريع يستخدم SimpleCleanSolver مع نموذج بيانات موحد
class UltraFastSolver {
  const UltraFastSolver();
  
  Future<DemandModel> solve(
    SchoolSnapshot snapshot,
    PolicyProfile policy,
    AssignmentModel assignment, {
    void Function({
      required int demandedLessons,
      required int placedLessons,
      required int unplacedLessons,
      required String label,
    })? onProgress,
  }) async {
    // جمع البيانات في نموذج موحد
    final collector = SchoolDataCollector();
    final unifiedModel = await collector.collect(
      snapshot: snapshot,
      assignment: assignment,
    );

    // تمرير النموذج الموحد للمحرك
    return const SimpleCleanSolver().solve(
      unifiedModel,
      onProgress: onProgress,
    );
  }
}
