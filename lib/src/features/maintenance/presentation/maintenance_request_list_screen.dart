import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../domain/models/maintenance_report.dart';
import '../data/firestore_maintenance_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class MaintenanceRequestListScreen extends ConsumerWidget {
  const MaintenanceRequestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    final reportsAsync = ref.watch(maintenanceReportsStreamProvider);

    return SmartSectionScaffold(
      title: 'الصيانة والخدمات',
      icon: Icons.build,
      themeColor: Colors.brown,
      initialRecommendation:
          'توصي الوزارة بإغلاق بلاغات الصيانة ذات الأولوية القصوى خلال 24 ساعة.',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/report-maintenance'),
        label: const Text('بلاغ جديد'),
        icon: const Icon(Icons.add_a_photo),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64.sp,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد بلاغات صيانة نشطة',
                    style: TextStyle(fontSize: 18.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: reports.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(context, report);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('حدث خطأ: $error')),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, MaintenanceReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _getPriorityColor(report.priority).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.build, color: _getPriorityColor(report.priority)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                report.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
            _buildStatusChip(report.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            Text(
              report.location,
              style: TextStyle(color: Colors.grey[700], fontSize: 14.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt),
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to details
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سيتم عرض تفاصيل البلاغ قريباً')),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.critical:
        return Colors.red;
      case MaintenancePriority.high:
        return Colors.orange;
      case MaintenancePriority.medium:
        return Colors.blue;
      case MaintenancePriority.low:
        return Colors.green;
    }
  }

  Widget _buildStatusChip(MaintenanceStatus status) {
    Color color;
    String label;

    switch (status) {
      case MaintenanceStatus.pending:
        color = Colors.orange;
        label = 'قيد الانتظار';
        break;
      case MaintenanceStatus.inProgress:
        color = Colors.blue;
        label = 'جاري العمل';
        break;
      case MaintenanceStatus.completed:
        color = Colors.green;
        label = 'مكتمل';
        break;
      case MaintenanceStatus.rejected:
        color = Colors.grey;
        label = 'مرفوض';
        break;
      case MaintenanceStatus.overdue:
        color = Colors.red;
        label = 'متأخر';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
