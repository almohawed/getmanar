
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../application/inbox_service.dart';
import '../../domain/transaction.dart';

class WorkloadMapPanel extends StatelessWidget {
  final String schoolId;
  final InboxService inboxService;

  const WorkloadMapPanel({
    super.key,
    required this.schoolId,
    required this.inboxService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خريطة الضغط الإداري',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          FutureBuilder<WorkloadMap>(
            future: inboxService.getWorkloadMap(schoolId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final workload = snapshot.data!;
              return Column(
                children: [
                  _buildWorkloadItem(
                    icon: Icons.groups_outlined,
                    label: 'الموظف الأكثر استلاماً',
                    value: '${workload.mostReceivedStaff} (${workload.mostReceivedCount})',
                    color: Colors.green.shade700,
                  ),
                  SizedBox(height: 10.h),
                  _buildWorkloadItem(
                    icon: Icons.running_with_errors_outlined,
                    label: 'الموظف الأكثر تأخيراً',
                    value: '${workload.mostDelayedStaff} (${workload.mostDelayedCount})',
                    color: Colors.red.shade700,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
