import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../domain/admin_task_entity.dart';
import 'admin_task_providers.dart';

class AdminTaskDetailsScreen extends ConsumerWidget {
  final String taskId;
  const AdminTaskDetailsScreen({super.key, required this.taskId});

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

  String _getPriorityLabel(AdminTaskPriority priority) {
    switch (priority) {
      case AdminTaskPriority.low:
        return 'منخفضة';
      case AdminTaskPriority.medium:
        return 'متوسطة';
      case AdminTaskPriority.high:
        return 'عالية';
      case AdminTaskPriority.urgent:
        return 'عاجلة';
    }
  }

  Color _getPriorityColor(AdminTaskPriority priority) {
    switch (priority) {
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

  String _getTypeLabel(AdminTaskType type) {
    switch (type) {
      case AdminTaskType.healthGuide:
        return 'المشرف الصحي';
      case AdminTaskType.safetyOfficer:
        return 'مسؤول الأمن والسلامة';
      case AdminTaskType.activityLeader:
        return 'مسؤول النشاط';
      case AdminTaskType.classLeader:
        return 'رائد فصل';
      case AdminTaskType.deputy:
        return 'وكيل';
      case AdminTaskType.stageDeputy:
        return 'وكيل مرحلة';
      case AdminTaskType.floorSupervisor:
        return 'مشرف دور';
      case AdminTaskType.committee:
        return 'عضو لجنة';
      case AdminTaskType.general:
        return 'مهمة عامة';
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

  String _getSmartRecommendation(AdminTaskType type) {
    switch (type) {
      case AdminTaskType.healthGuide:
        return 'تأكد من تحديث سجلات الحالات الصحية للطلاب وتفقد العيادة المدرسية.';
      case AdminTaskType.safetyOfficer:
        return 'قم بجولة تفقدية لمخارج الطوارئ وأجهزة الإنذار وتوثيق أي ملاحظات.';
      case AdminTaskType.activityLeader:
        return 'حفز الطلاب للمشاركة في الأنشطة اللاصفية ووثق المشاركات المميزة.';
      case AdminTaskType.floorSupervisor:
        return 'تابع حركة الطلاب أثناء الفسحة وتأكد من خلو الممرات أثناء الحصص.';
      default:
        return 'قم بتوثيق إنجاز المهمة بالشواهد (صور أو ملفات) لضمان التقييم العادل.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return taskAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('حدث خطأ: $e')),
      ),
      data: (task) {
        if (task == null) {
          return const Scaffold(
            body: Center(child: Text('المهمة غير موجودة')),
          );
        }

        return SmartSectionScaffold(
          title: 'تفاصيل المهمة',
          icon: Icons.assignment,
          themeColor: _getStatusColor(task.status),
          initialRecommendation: _getSmartRecommendation(task.type),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getTypeIcon(task.type),
                              size: 24.sp, color: Colors.indigo),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          _buildStatusChip(task.status),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      if (task.description != null) ...[
                        Text(
                          task.description!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      Divider(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem(
                            Icons.person,
                            'المكلف',
                            task.assignedToName ?? 'غير محدد',
                          ),
                          _buildInfoItem(
                            Icons.flag,
                            'الأولوية',
                            _getPriorityLabel(task.priority),
                            color: _getPriorityColor(task.priority),
                          ),
                          _buildInfoItem(
                            Icons.calendar_today,
                            'الاستحقاق',
                            task.dueDate.toString().split(' ')[0],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // Actions Section (Placeholder for now)
                Text(
                  'الإجراءات والشواهد',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.upload_file,
                            size: 40.sp, color: Colors.grey),
                        SizedBox(height: 8.h),
                        Text(
                          'لا توجد شواهد مرفقة حالياً',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement file upload
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('سيتم تفعيل رفع الشواهد قريباً')),
                            );
                          },
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('إرفاق شاهد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(AdminTaskStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          fontSize: 12.sp,
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value,
      {Color? color}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14.sp, color: Colors.grey),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
