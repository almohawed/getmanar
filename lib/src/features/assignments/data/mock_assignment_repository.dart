import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/assignment.dart';

class MockAssignmentRepository {
  final List<Assignment> _assignments = [
    // Student 1 Assignments
    Assignment(
      id: '1',
      title: 'حل تمارين ص 25',
      subject: 'الرياضيات',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      status: AssignmentStatus.pending,
      studentId: 's1',
      description: 'حل المسائل من 1 إلى 5',
    ),
    Assignment(
      id: '2',
      title: 'حفظ سورة النبأ',
      subject: 'القرآن الكريم',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      status: AssignmentStatus.submitted,
      studentId: 's1',
      description: 'تسميع السورة كاملة',
    ),
    Assignment(
      id: '3',
      title: 'رسم دورة حياة النبات',
      subject: 'العلوم',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      status: AssignmentStatus.approved,
      studentId: 's1',
      description: 'رسم توضيحي في كراسة الرسم',
    ),
    Assignment(
      id: '4',
      title: 'نسخ الدرس الأول',
      subject: 'لغتي',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      status: AssignmentStatus.approved,
      studentId: 's1',
    ),
    Assignment(
      id: '5',
      title: 'مشروع الوحدة',
      subject: 'المهارات الرقمية',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      status: AssignmentStatus.pending,
      studentId: 's1',
      description: 'تصميم عرض تقديمي',
    ),
  ];

  Future<List<Assignment>> getAssignmentsForStudent(String studentId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return _assignments.where((a) => a.studentId == studentId).toList();
  }

  Future<List<Assignment>> getAssignmentsForTeacher(String teacherId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _assignments.where((a) => a.teacherId == teacherId).toList();
  }

  Future<void> addAssignment(Assignment assignment) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _assignments.add(assignment);
  }

  Future<void> submitAssignment(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _assignments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _assignments[index] = _assignments[index].copyWith(
        status: AssignmentStatus.submitted,
      );
    }
  }
}

final mockAssignmentRepositoryProvider = Provider<MockAssignmentRepository>((
  ref,
) {
  return MockAssignmentRepository();
});

final studentAssignmentsProvider =
    FutureProvider.family<List<Assignment>, String>((ref, studentId) async {
      final repo = ref.watch(mockAssignmentRepositoryProvider);
      return repo.getAssignmentsForStudent(studentId);
    });
