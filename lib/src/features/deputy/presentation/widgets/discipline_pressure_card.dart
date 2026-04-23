import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../command_center_providers.dart';

import 'package:go_router/go_router.dart';
import '../critical_cases_screen.dart';

class DisciplinePressureCard extends ConsumerWidget {
  const DisciplinePressureCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressureAsync = ref.watch(disciplinePressureProvider);
    final escalationAsync = ref.watch(escalationCasesProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مؤشر ضغط الانضباط',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                pressureAsync.when(
                  data: (pressure) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: pressure.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, color: pressure.color, size: 12.sp),
                        SizedBox(width: 3.w),
                        Text(
                          pressure.label,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: pressure.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            pressureAsync.when(
              data: (pressure) => GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                crossAxisSpacing: 6.w,
                mainAxisSpacing: 6.h,
                children: [
                  _buildMetricTile(context, 'مخالفات مفتوحة', pressure.openViolations.toString(), Colors.orange, Icons.folder_open, '/behavior-report'),
                  _buildMetricTile(context, 'تم التصعيد', pressure.escalatedViolations.toString(), Colors.red, Icons.arrow_upward, '/escalation'),
                  _buildMetricTile(context, 'تحويل للمرشد', pressure.counselorReferrals.toString(), Colors.purple, Icons.psychology, '/refer-counselor'),
                  _buildMetricTile(context, 'استدعاء ولي أمر', pressure.parentSummons.toString(), Colors.deepOrange, Icons.phone_callback, '/call-parent'),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ في التحميل', style: TextStyle(fontSize: 11.sp))),
            ),
            SizedBox(height: 10.h),
            const Divider(height: 1),
            SizedBox(height: 6.h),
            escalationAsync.when(
              data: (cases) {
                final pendingCount = cases.length;
                return Row(
                  children: [
                    Icon(Icons.security, size: 14.sp, color: pendingCount > 0 ? Colors.orange : Colors.green),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        pendingCount > 0 ? 'تنبيه: $pendingCount حالات تستحق التصعيد' : 'نظام التصعيد: مفعل',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: pendingCount > 0 ? Colors.orange.shade800 : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pendingCount > 0)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CriticalCasesScreen(initialIndex: 2)));
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text('تنفيذ', style: TextStyle(fontSize: 10.sp, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value, Color color, IconData icon, String route) {
    return InkWell(
      onTap: () {
        try {
          context.push(route);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جاري العمل على: $label')));
        }
      },
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16.sp),
            SizedBox(height: 3.h),
            Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 8.sp, color: Colors.grey.shade700, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
