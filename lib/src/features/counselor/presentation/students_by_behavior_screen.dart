import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../academic/presentation/students_provider.dart';

final recordsByTypeProvider = FutureProvider.autoDispose
    .family<List<BehaviorRecord>, BehaviorType>((ref, type) async {
      final repo = ref.watch(behaviorRepositoryProvider);
      return repo.getRecordsByType(type);
    });

class StudentsByBehaviorScreen extends ConsumerWidget {
  final BehaviorType behaviorType;

  const StudentsByBehaviorScreen({super.key, required this.behaviorType});

  String get _title {
    switch (behaviorType) {
      case BehaviorType.positive:
        return 'الطلاب المتميزين سلوكياً (إيجابي)';
      case BehaviorType.distinguished:
        return 'الطلاب المتميزين (السلوك المتميز)';
      default:
        return 'الطلاب';
    }
  }

  Color get _themeColor {
    switch (behaviorType) {
      case BehaviorType.positive:
        return Colors.green;
      case BehaviorType.distinguished:
        return Colors.amber.shade700;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsByTypeProvider(behaviorType));
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text('لا يوجد طلاب مسجلين في هذه الفئة حالياً'),
                ],
              ),
            );
          }

          // Group records by student
          final studentRecords = <String, List<BehaviorRecord>>{};
          for (var record in records) {
            if (!studentRecords.containsKey(record.studentId)) {
              studentRecords[record.studentId] = [];
            }
            studentRecords[record.studentId]!.add(record);
          }

          final studentIds = studentRecords.keys.toList();

          return studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('حدث خطأ: $e')),
            data: (students) {
              final byId = {for (final s in students) s.id: s};
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: studentIds.length,
                itemBuilder: (context, index) {
                  final studentId = studentIds[index];
                  final student = byId[studentId] ??
                      User(id: studentId, name: 'طالب غير معروف', email: '', role: UserRole.student);
                  final myRecords = studentRecords[studentId]!;
                  final totalPoints =
                      myRecords.fold(0, (sum, r) => sum + r.points);

                  final initial =
                      student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';

                  return Card(
                    margin: EdgeInsets.only(bottom: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _themeColor.withValues(alpha: 0.1),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: _themeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      subtitle: Text(
                        '${myRecords.length} سجلات - المجموع: $totalPoints نقطة',
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16.sp,
                        color: Colors.grey,
                      ),
                      onTap: () {},
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to a screen to add behavior to a student
          // Ideally, pick a class -> pick a student -> add record
          context.push(
            '/classes-list',
          ); // Reusing classes list for now as entry point
        },
        backgroundColor: _themeColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
