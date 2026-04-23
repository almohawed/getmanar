import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../command_center_providers.dart';
import '../critical_cases_screen.dart';

class DailyDangerCard extends ConsumerWidget {
  const DailyDangerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(combinedDangerStatsProvider);

    return Card(
      elevation: 2,
      shadowColor: Colors.red.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.red.shade100, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 20.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'خطر اليوم',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'يتطلب تدخلاً',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            statsAsync.when(
              data: (stats) => Column(
                children: [
                  _buildDangerRow(
                    label: 'طلاب في نطاق الخطر',
                    count: stats.dangerZoneCount,
                    color: Colors.red,
                    icon: Icons.person_off,
                  ),
                  SizedBox(height: 8.h),
                  _buildDangerRow(
                    label: 'تأخرات اليوم',
                    count: stats.repeatedLateCount,
                    color: Colors.orange,
                    icon: Icons.timer_off,
                  ),
                  SizedBox(height: 8.h),
                  _buildDangerRow(
                    label: 'تجاوز حد الاستئذان',
                    count: stats.permissionViolationCount,
                    color: Colors.deepOrange,
                    icon: Icons.no_meeting_room,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ في التحميل', style: TextStyle(fontSize: 11.sp))),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CriticalCasesScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                child: Text('عرض الحالات', style: TextStyle(fontSize: 12.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerRow({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}
