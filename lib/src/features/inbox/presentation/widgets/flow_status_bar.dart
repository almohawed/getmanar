import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../application/inbox_service.dart';
import '../../domain/transaction.dart';

class FlowStatusBar extends StatelessWidget {
  final String schoolId;
  final InboxService inboxService;

  const FlowStatusBar({
    super.key,
    required this.schoolId,
    required this.inboxService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InboxStatistics>(
      future: inboxService.getStatistics(schoolId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120.h,
            color: Color(0xFF1565C0),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final stats = snapshot.data!;
        final isHighPressure = stats.flowStatus == 'ضغط مرتفع';
        final isMediumPressure = stats.flowStatus == 'ضغط متوسط';

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHighPressure
                  ? [Colors.red.shade700, Colors.red.shade900]
                  : isMediumPressure
                      ? [Colors.orange.shade600, Colors.orange.shade800]
                      : [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // العنوان
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'حالة التدفق الإداري',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isHighPressure
                              ? Icons.warning_amber_rounded
                              : isMediumPressure
                                  ? Icons.info_outline
                                  : Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          stats.flowStatus,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // الإحصائيات
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.inbox,
                    label: 'إجمالي الوارد اليوم',
                    value: stats.totalToday.toString(),
                    color: Colors.white,
                  ),
                  SizedBox(width: 12.w),
                  _buildStatCard(
                    icon: Icons.pending_actions,
                    label: 'المعاملات غير الموجهة',
                    value: stats.unrouted.toString(),
                    color: Colors.amber.shade300,
                  ),
                  SizedBox(width: 12.w),
                  _buildStatCard(
                    icon: Icons.schedule,
                    label: 'المعاملات المتأخرة',
                    value: stats.delayed.toString(),
                    color: Colors.red.shade300,
                  ),
                  SizedBox(width: 12.w),
                  _buildStatCard(
                    icon: Icons.timer,
                    label: 'متوسط زمن المعالجة',
                    value: '${stats.averageProcessingTime.toStringAsFixed(1)} ساعة',
                    color: Colors.green.shade300,
                  ),
                  SizedBox(width: 12.w),
                  _buildStatCard(
                    icon: Icons.priority_high,
                    label: 'المعاملات الحرجة',
                    value: stats.critical.toString(),
                    color: Colors.deepOrange.shade300,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.sp,
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
