import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../common/presentation/smart_section_scaffold.dart';
import '../../domain/administrative_assignment.dart';
import '../../data/assignments_repository.dart';

class AssignmentsManagementScreen extends ConsumerWidget {
  const AssignmentsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(assignmentsProvider);

    return SmartSectionScaffold(
      title: 'التكليفات الإدارية',
      icon: Icons.assignment_ind,
      themeColor: Colors.blue,
      initialRecommendation:
          'توصي الوزارة بتوزيع المهام الإدارية بالتساوي بين الكادر التعليمي لضمان سير العمل بفعالية.',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-admin-task'),
        label: const Text('إضافة تكليف جديد'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: assignmentsAsync.when(
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(child: Text('لا توجد تكليفات حالياً'));
          }
          return ListView.separated(
            itemCount: assignments.length,
            padding: EdgeInsets.all(16.w),
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black26),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(12.w),
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForType(assignment.type),
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    assignment.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14.sp, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            'المكلف: ${assignment.teacherName}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ],
                      ),
                      if (assignment.stage != null) ...[
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.school, size: 14.sp, color: Colors.grey),
                            SizedBox(width: 4.w),
                            Text(
                              'المرحلة: ${assignment.stage!} ${assignment.gradeLevel != null ? "- ${assignment.gradeLevel}" : ""}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${DateFormat('yyyy-MM-dd').format(assignment.startDate)} - ${assignment.endDate != null ? DateFormat('yyyy-MM-dd').format(assignment.endDate!) : "مستمر"}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (!assignment.isActive) ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'منتهى',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'deactivate') {
                        ref
                            .read(assignmentsRepositoryProvider)
                            .deactivateAssignment(assignment.id);
                        ref.invalidate(assignmentsProvider);
                      } else if (value == 'delete') {
                        ref
                            .read(assignmentsRepositoryProvider)
                            .deleteAssignment(assignment.id);
                        ref.invalidate(assignmentsProvider);
                      }
                    },
                    itemBuilder: (context) => [
                      if (assignment.isActive)
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('إنهاء التكليف'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _getIconForType(AssignmentType type) {
    switch (type) {
      case AssignmentType.healthGuide:
        return Icons.health_and_safety;
      case AssignmentType.safetyOfficer:
        return Icons.security;
      case AssignmentType.activityLeader:
        return Icons.sports_soccer;
      case AssignmentType.classLeader:
        return Icons.class_;
      case AssignmentType.deputy:
        return Icons.admin_panel_settings;
      case AssignmentType.stageDeputy:
        return Icons.supervisor_account;
      case AssignmentType.committee:
        return Icons.groups;
    }
  }

  void _showAddAssignmentDialog(BuildContext context, WidgetRef ref) {
    // This dialog is no longer used, we navigate to create-admin-task instead
    context.push('/create-admin-task');
  }
}
