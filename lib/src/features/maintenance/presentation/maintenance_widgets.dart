import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../domain/models/maintenance_report.dart';

// ============================================================================
// Maintenance Helper Widgets
// ============================================================================

class PriorityCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const PriorityCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const StatusCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildPrioritySection(BuildContext context, String title, List<MaintenanceReport> reports, Color color, {Function(BuildContext, MaintenanceReport)? onReportTap}) {
  return Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '$title (${reports.length})',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ...reports.take(3).map((report) => Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: GestureDetector(
            onTap: onReportTap != null ? () => onReportTap(context, report) : null,
            child: Text(
              '• ${report.title}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )),
        if (reports.length > 3)
          Text(
            'و ${reports.length - 3} بلاغات أخرى...',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    ),
  );
}

Widget buildTimelineItem(MaintenanceReport report) {
  final statusColor = _getStatusColor(report.status);
  final priorityColor = _getPriorityColor(report.priority);
  
  return Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        Container(
          width: 4.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: priorityColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                report.location,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt),
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            _getStatusLabel(report.status),
            style: TextStyle(
              fontSize: 10.sp,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildLocationFaultCard(String location, List<MaintenanceReport> reports) {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    child: Padding(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.orange.shade600, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${reports.length} بلاغ',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...reports.take(3).map((report) => Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(report.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    report.title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('dd/MM').format(report.createdAt),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          )),
          if (reports.length > 3)
            Text(
              'و ${reports.length - 3} بلاغات أخرى...',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    ),
  );
}

Widget buildReadinessItem(String title, int percentage, Color color) {
  return Container(
    padding: EdgeInsets.all(12.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 8.h),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget buildMaintenanceTaskCard(Map<String, dynamic> task) {
  final title = task['title'] as String;
  final dueDate = task['dueDate'] as DateTime;
  final status = task['status'] as String;
  
  Color statusColor;
  switch (status) {
    case 'عاجل':
      statusColor = Colors.red;
      break;
    case 'متأخر':
      statusColor = Colors.purple;
      break;
    case 'قادم':
      statusColor = Colors.blue;
      break;
    case 'مجدول':
      statusColor = Colors.green;
      break;
    default:
      statusColor = Colors.grey;
  }

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    child: Padding(
      padding: EdgeInsets.all(12.w),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.schedule,
              color: statusColor,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'موعد الاستحقاق: ${DateFormat('dd/MM/yyyy').format(dueDate)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11.sp,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildMaintenanceReportItem(MaintenanceReport report) {
  final priorityColor = _getPriorityColor(report.priority);
  final statusLabel = _getStatusLabel(report.status);
  final statusColor = _getStatusColor(report.status);

  return Row(
    children: [
      Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: priorityColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          Icons.construction,
          color: priorityColor,
          size: 20.sp,
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title.isNotEmpty ? report.title : 'بلاغ صيانة بدون عنوان',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              report.location.isNotEmpty ? report.location : 'موقع غير محدد',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: 8.w),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          statusLabel,
          style: TextStyle(
            fontSize: 11.sp,
            color: statusColor,
          ),
        ),
      ),
    ],
  );
}

// Helper functions
Color _getPriorityColor(MaintenancePriority priority) {
  switch (priority) {
    case MaintenancePriority.critical:
      return Colors.purple;
    case MaintenancePriority.high:
      return Colors.red;
    case MaintenancePriority.medium:
      return Colors.orange;
    case MaintenancePriority.low:
      return Colors.green;
  }
}

Color _getStatusColor(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pending:
      return Colors.blue;
    case MaintenanceStatus.inProgress:
      return Colors.orange;
    case MaintenanceStatus.completed:
      return Colors.green;
    case MaintenanceStatus.rejected:
      return Colors.red;
    case MaintenanceStatus.overdue:
      return Colors.purple;
  }
}

String _getStatusLabel(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pending:
      return 'قيد الانتظار';
    case MaintenanceStatus.inProgress:
      return 'قيد التنفيذ';
    case MaintenanceStatus.completed:
      return 'مكتمل';
    case MaintenanceStatus.rejected:
      return 'مرفوض';
    case MaintenanceStatus.overdue:
      return 'متأخر';
  }
}