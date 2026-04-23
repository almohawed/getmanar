import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_teacher_repository.dart';
import 'behavior_controller.dart';

class DeputyViolationsScreen extends ConsumerWidget {
  const DeputyViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violationsAsync = ref.watch(pendingViolationsProvider);
    final teachersFuture = ref
        .watch(mockTeacherRepositoryProvider)
        .getTeachers();
    final studentsAsync = ref.watch(studentsProvider);
    final students = studentsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('اعتماد المخالفات السلوكية')),
      backgroundColor: Colors.white,
      body: FutureBuilder<List<User>>(
        future: teachersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teachers = snapshot.data ?? [];

          String getUserName(String userId) {
            try {
              return teachers.firstWhere((u) => u.id == userId).name;
            } catch (_) {
              try {
                return students.firstWhere((u) => u.id == userId).name;
              } catch (_) {
                return userId;
              }
            }
          }

          return violationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('خطأ: $e')),
            data: (violations) {
              if (violations.isEmpty) {
                return const Center(child: Text('لا يوجد مخالفات معلقة'));
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: violations.length,
                itemBuilder: (context, index) {
                  final violation = violations[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12.h),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 24.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  getUserName(violation.studentId),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                              Text(
                                violation.timestamp.toString().substring(0, 16),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text('المخالفة: ${violation.description}'),
                          SizedBox(height: 4.h),
                          Text(
                            'المعلم: ${getUserName(violation.teacherId)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _rejectViolation(context, ref, violation),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('رفض'),
                              ),
                              SizedBox(width: 12.w),
                              ElevatedButton(
                                onPressed: () => _approveViolation(
                                  context,
                                  ref,
                                  violation,
                                  getUserName(violation.studentId),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('اعتماد'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _approveViolation(
    BuildContext context,
    WidgetRef ref,
    BehaviorRecord record,
    String studentName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإرسال'),
        content: const Text('هل تريد إرسال هذه المخالفة واعتمادها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref
                  .read(behaviorControllerProvider.notifier)
                  .approveViolation(record, studentName);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم الاعتماد وإرسال إشعار لولي الأمر'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الإرسال'),
          ),
        ],
      ),
    );
  }

  void _rejectViolation(
    BuildContext context,
    WidgetRef ref,
    BehaviorRecord record,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: 'اكتب سبب الرفض...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(behaviorControllerProvider.notifier)
                    .rejectViolation(record, reasonController.text);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الرفض وإشعار المعلم')),
                  );
                }
              },
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );
  }
}
