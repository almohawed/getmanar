import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:uuid/uuid.dart';
import '../domain/administrative_assignment.dart';

// In-memory storage
class AssignmentsRepository {
  final List<AdministrativeAssignment> _assignments = [];

  AssignmentsRepository() {
    // Add some mock data
    // _assignments.addAll([
    //   AdministrativeAssignment(
    //     id: const Uuid().v4(),
    //     teacherId: 'teacher1', // Assuming a valid teacher ID
    //     teacherName: 'أحمد محمد',
    //     type: AssignmentType.healthGuide,
    //     title: 'المرشد الصحي',
    //     startDate: DateTime.now().subtract(const Duration(days: 30)),
    //     isActive: true,
    //   ),
    //   AdministrativeAssignment(
    //     id: const Uuid().v4(),
    //     teacherId: 'teacher2',
    //     teacherName: 'خالد علي',
    //     type: AssignmentType.safetyOfficer,
    //     title: 'مسؤول الأمن والسلامة',
    //     startDate: DateTime.now().subtract(const Duration(days: 15)),
    //     isActive: true,
    //   ),
    // ]);
  }

  Future<List<AdministrativeAssignment>> getAssignments() async {
    return _assignments;
  }

  Future<List<AdministrativeAssignment>> getAssignmentsForTeacher(
    String teacherId,
  ) async {
    return _assignments
        .where((a) => a.teacherId == teacherId && a.isActive)
        .toList();
  }

  Future<void> addAssignment(AdministrativeAssignment assignment) async {
    _assignments.add(assignment);
  }

  Future<void> updateAssignment(AdministrativeAssignment assignment) async {
    final index = _assignments.indexWhere((a) => a.id == assignment.id);
    if (index != -1) {
      _assignments[index] = assignment;
    }
  }

  Future<void> deleteAssignment(String id) async {
    _assignments.removeWhere((a) => a.id == id);
  }

  Future<void> deactivateAssignment(String id) async {
    final index = _assignments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _assignments[index] = _assignments[index].copyWith(
        isActive: false,
        endDate: DateTime.now(),
      );
    }
  }
}

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return AssignmentsRepository();
});

final assignmentsProvider = FutureProvider<List<AdministrativeAssignment>>((
  ref,
) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  return repo.getAssignments();
});

final teacherAssignmentsProvider =
    FutureProvider.family<List<AdministrativeAssignment>, String>((
      ref,
      teacherId,
    ) async {
      final repo = ref.watch(assignmentsRepositoryProvider);
      return repo.getAssignmentsForTeacher(teacherId);
    });
