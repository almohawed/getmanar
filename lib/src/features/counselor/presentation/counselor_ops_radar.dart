import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'counselor_providers.dart';
import '../../admin_tasks/domain/admin_task_entity.dart';

class CounselorOpsRadar extends ConsumerWidget {
  const CounselorOpsRadar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCases = ref.watch(activeCasesProvider);
    final todaySessions = ref.watch(todaySessionsProvider);
    final activePlans = ref.watch(activePlansProvider);
    final myTasks = ref.watch(counselorTasksProvider);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Text(
            'رادار العمليات (Ops Radar)',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _buildRadarItem(
                context,
                title: 'حالات نشطة',
                count: activeCases.when(
                  data: (d) => d.length,
                  loading: () => 0,
                  error: (_, __) => 0,
                ),
                color: Colors.orange,
                icon: Icons.folder_open,
                route: '/student-profile',
              ),
              SizedBox(width: 12.w),
              _buildRadarItem(
                context,
                title: 'جلسات اليوم',
                count: todaySessions.when(
                  data: (d) => d.length,
                  loading: () => 0,
                  error: (_, __) => 0,
                ),
                color: Colors.blue,
                icon: Icons.access_time,
                route: '/counselor/sessions',
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildRadarItem(
                context,
                title: 'خطط نشطة',
                count: activePlans.when(
                  data: (d) => d.length,
                  loading: () => 0,
                  error: (_, __) => 0,
                ),
                color: Colors.purple,
                icon: Icons.assignment,
                route: '/counselor/plans',
              ),
              SizedBox(width: 12.w),
              myTasks.when(
                data: (d) {
                  final overdue = d
                      .where((t) =>
                          t.isOverdue || t.status == AdminTaskStatus.overdue)
                      .length;
                  final hasUrgent =
                      d.any((t) => t.priority == AdminTaskPriority.urgent);
                  final hasHigh =
                      d.any((t) => t.priority == AdminTaskPriority.high);
                  final hasMedium =
                      d.any((t) => t.priority == AdminTaskPriority.medium);
                  final color = _priorityColorByPresence(
                    hasUrgent: hasUrgent,
                    hasHigh: hasHigh,
                    hasMedium: hasMedium,
                  );
                  final totalOpen = d.length;
                  return _buildTasksRadarItem(
                    context,
                    overdueCount: overdue,
                    totalOpenCount: totalOpen,
                    color: color,
                    route: '/admin-tasks',
                  );
                },
                loading: () {
                  final color = _priorityColorByPresence(
                    hasUrgent: false,
                    hasHigh: false,
                    hasMedium: false,
                  );
                  return _buildTasksRadarItem(
                    context,
                    overdueCount: 0,
                    totalOpenCount: 0,
                    color: color,
                    route: '/admin-tasks',
                  );
                },
                error: (_, __) {
                  final color = _priorityColorByPresence(
                    hasUrgent: false,
                    hasHigh: false,
                    hasMedium: false,
                  );
                  return _buildTasksRadarItem(
                    context,
                    overdueCount: 0,
                    totalOpenCount: 0,
                    color: color,
                    route: '/admin-tasks',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  Color _priorityColorByPresence({
    required bool hasUrgent,
    required bool hasHigh,
    required bool hasMedium,
  }) {
    if (hasUrgent) return Colors.red;
    if (hasHigh) return Colors.orange;
    if (hasMedium) return Colors.amber;
    return Colors.blueGrey;
  }

  Widget _buildTasksRadarItem(
    BuildContext context, {
    required int overdueCount,
    required int totalOpenCount,
    required Color color,
    required String route,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.task_alt, color: color, size: 24.sp),
                  Row(
                    children: [
                      Text(
                        '$overdueCount',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          'متأخرة',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'مهامي',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'إجمالي مفتوحة: $totalOpenCount',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 10.sp, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarItem(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required String route,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24.sp),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 10.sp, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
