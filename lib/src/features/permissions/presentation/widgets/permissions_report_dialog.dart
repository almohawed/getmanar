import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/permission_model.dart';
import '../../application/permission_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class PermissionsReportDialog extends StatelessWidget {
  final List<PermissionUser> users;
  final List<PermissionLog> logs;

  const PermissionsReportDialog({
    super.key,
    required this.users,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 900.w,
        height: 700.h,
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تقرير الصلاحيات الشامل',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSummaryCards(),
                    SizedBox(height: 24.h),
                    _buildChartsSection(),
                    SizedBox(height: 24.h),
                    _buildRecentActivityList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildReportCard('إجمالي الصلاحيات', '${users.length}', Icons.security, Colors.blue),
        _buildReportCard('صلاحيات كاملة', '${users.where((u) => u.permissionLevel == PermissionLevel.full).length}', Icons.admin_panel_settings, Colors.red),
        _buildReportCard('صلاحيات متوسطة', '${users.where((u) => u.permissionLevel == PermissionLevel.medium).length}', Icons.manage_accounts, Colors.orange),
        _buildReportCard('صلاحيات محدودة', '${users.where((u) => u.permissionLevel == PermissionLevel.limited).length}', Icons.person_outline, Colors.green),
      ],
    );
  }

  Widget _buildReportCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
        border: Border(top: BorderSide(color: color, width: 3.h)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 300.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text('توزيع الصلاحيات حسب المستوى', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(color: Colors.red, value: users.where((u) => u.permissionLevel == PermissionLevel.full).length.toDouble(), title: 'كاملة', radius: 40),
                        PieChartSectionData(color: Colors.orange, value: users.where((u) => u.permissionLevel == PermissionLevel.medium).length.toDouble(), title: 'متوسطة', radius: 40),
                        PieChartSectionData(color: Colors.green, value: users.where((u) => u.permissionLevel == PermissionLevel.limited).length.toDouble(), title: 'محدودة', radius: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Container(
            height: 300.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text('نشاط الصلاحيات الأخير', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.separated(
                    itemCount: logs.length > 5 ? 5 : logs.length,
                    separatorBuilder: (_, __) => Divider(),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.history, size: 16.sp, color: Colors.grey),
                        title: Text(log.action, style: TextStyle(fontSize: 12.sp)),
                        subtitle: Text(timeago.format(log.timestamp, locale: 'ar'), style: TextStyle(fontSize: 10.sp)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('سجل العمليات التفصيلي', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 10 ? 10 : logs.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade50,
                  child: Icon(Icons.person, size: 16.sp, color: Colors.blueGrey),
                ),
                title: Text(log.action),
                subtitle: Text('للموظف: ${log.targetUser} - بواسطة: ${log.performedBy}'),
                trailing: Text(timeago.format(log.timestamp, locale: 'ar'), style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
              );
            },
          ),
        ),
      ],
    );
  }
}
