import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'admin_task_providers.dart';
import '../domain/admin_task_entity.dart';
import '../../common/presentation/smart_section_scaffold.dart';

class AdminTasksListScreen extends ConsumerWidget {
  const AdminTasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminTasksStreamProvider);
    return SmartSectionScaffold(
      title: 'التكليفات والمهام الإدارية',
      icon: Icons.assignment_ind,
      themeColor: Colors.blue,
      initialRecommendation:
          'توصي الوزارة بمتابعة إنجاز المهام أولاً بأول وتوثيق الشواهد للإغلاق.',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-admin-task'),
        label: const Text('إسناد مهمة جديدة'),
        icon: const Icon(Icons.add_task),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('لا توجد مهام حالياً'));
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskTile(task: task);
            },
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final AdminTaskEntity task;
  const _TaskTile({required this.task});

  Color _priorityColor(AdminTaskPriority p) {
    switch (p) {
      case AdminTaskPriority.low:
        return Colors.green;
      case AdminTaskPriority.medium:
        return Colors.blue;
      case AdminTaskPriority.high:
        return Colors.orange;
      case AdminTaskPriority.urgent:
        return Colors.red;
    }
  }

  String _getStatusLabel(AdminTaskStatus status) {
    switch (status) {
      case AdminTaskStatus.open:
        return 'مفتوحة';
      case AdminTaskStatus.in_progress:
        return 'قيد التنفيذ';
      case AdminTaskStatus.done:
        return 'مكتملة';
      case AdminTaskStatus.overdue:
        return 'متأخرة';
    }
  }

  IconData _getTypeIcon(AdminTaskType type) {
    switch (type) {
      case AdminTaskType.healthGuide:
        return Icons.medical_services;
      case AdminTaskType.safetyOfficer:
        return Icons.security;
      case AdminTaskType.activityLeader:
        return Icons.sports_soccer;
      case AdminTaskType.classLeader:
        return Icons.school;
      case AdminTaskType.deputy:
        return Icons.admin_panel_settings;
      case AdminTaskType.stageDeputy:
        return Icons.supervisor_account;
      case AdminTaskType.floorSupervisor:
        return Icons.layers;
      case AdminTaskType.committee:
        return Icons.groups;
      case AdminTaskType.general:
        return Icons.assignment;
    }
  }

  Color _getStatusColor(AdminTaskStatus status) {
    switch (status) {
      case AdminTaskStatus.open:
        return Colors.blue;
      case AdminTaskStatus.in_progress:
        return Colors.orange;
      case AdminTaskStatus.done:
        return Colors.green;
      case AdminTaskStatus.overdue:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black26),
      ),
      child: InkWell(
        onTap: () => context.push('/admin-task/${task.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 80.h,
                decoration: BoxDecoration(
                  color: _priorityColor(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getTypeIcon(task.type),
                          size: 16.sp,
                          color: Colors.indigo,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    if (task.assignedToName != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'المكلف: ${task.assignedToName}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (task.description != null)
                      Text(
                        task.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        _buildChip(
                          label: _getStatusLabel(task.status),
                          color: _getStatusColor(task.status).withOpacity(0.1),
                          textColor: _getStatusColor(task.status),
                        ),
                        SizedBox(width: 8.w),
                        _buildChip(
                          label: task.dueDate.toString().split(' ')[0],
                          icon: Icons.calendar_today,
                          color: Colors.grey.shade100,
                          textColor: Colors.grey.shade800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    IconData? icon,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.sp, color: textColor),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
