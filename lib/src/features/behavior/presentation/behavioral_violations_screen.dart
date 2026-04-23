import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../data/violation_data.dart';
import '../domain/models/behavior_violation_type.dart';
import '../domain/models/violation.dart';
import 'sent_violations_provider.dart';

class BehavioralViolationsScreen extends ConsumerWidget {
  const BehavioralViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('المخالفات السلوكية')),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: predefinedViolations.length,
        itemBuilder: (context, index) {
          final violationType = predefinedViolations[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            child: ListTile(
              title: Text(
                violationType.text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('المستوى: ${violationType.level}'),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'خصم ${violationType.deduction}',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => _showStudentSelection(context, ref, violationType),
            ),
          );
        },
      ),
    );
  }

  void _showStudentSelection(
    BuildContext context,
    WidgetRef ref,
    BehaviorViolationType violationType,
  ) {
    showDialog(
      context: context,
      builder: (context) => SelectStudentDialog(
        onStudentSelected: (student) {
          // Close selection dialog
          Navigator.pop(context);

          // Show confirmation
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد الإرسال'),
              content: Text(
                'هل تريد إرسال مخالفة "${violationType.text}" للطالب ${student.name}؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Send Violation
                    final newViolation = Violation(
                      id: const Uuid().v4(),
                      studentId:
                          student.name, // Using name for display simplicity
                      teacherId: 'deputy', // Current user ID
                      type: ViolationType
                          .minor, // Mapping to enum if needed, or ignore
                      description: violationType.text,
                      timestamp: DateTime.now(),
                      pointsDeducted: violationType.deduction,
                    );

                    ref
                        .read(sentViolationsProvider.notifier)
                        .addViolation(newViolation);

                    Navigator.pop(context); // Close confirmation dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إرسال المخالفة للطالب ${student.name}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('تأكيد الإرسال'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SelectStudentDialog extends ConsumerStatefulWidget {
  final Function(User) onStudentSelected;

  const SelectStudentDialog({super.key, required this.onStudentSelected});

  @override
  ConsumerState<SelectStudentDialog> createState() =>
      _SelectStudentDialogState();
}

class _SelectStudentDialogState extends ConsumerState<SelectStudentDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allStudentsAsync = ref.watch(studentsProvider);
    final allStudents = allStudentsAsync.value ?? [];
    final filteredStudents = allStudents
        .where((s) => s.name.contains(_searchQuery))
        .toList();

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: 500.h),
        child: Column(
          children: [
            Text(
              'اختر الطالب',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث عن طالب',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.builder(
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        student.name.isNotEmpty ? student.name[0] : '?',
                      ),
                    ),
                    title: Text(student.name),
                    subtitle: Text(student.email),
                    onTap: () => widget.onStudentSelected(student),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
