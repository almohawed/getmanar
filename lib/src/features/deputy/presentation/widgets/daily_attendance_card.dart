import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../attendance/presentation/providers/daily_absence_provider.dart';

class DailyAttendanceCard extends ConsumerWidget {
  const DailyAttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absenceAsync = ref.watch(dailyAbsenceProvider);

    return Card(
      elevation: 2,
      shadowColor: Colors.orange.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.orange.shade100, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.orange.shade800,
                  size: 20.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'الغياب اليومي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const Spacer(),
                absenceAsync.when(
                  data: (list) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${list.length} طالب',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            absenceAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Text(
                        'لا يوجد غياب مسجل اليوم',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  );
                }

                final displayList = students.take(2).toList();

                return Column(
                  children: [
                    ...displayList.map(
                      (student) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14.r,
                              backgroundColor: Colors.orange.shade100,
                              child: Text(
                                student.studentName.characters.first,
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.studentName,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${student.className} • ${student.period}',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (students.length > 2)
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          '+ ${students.length - 2} آخرين',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(
                  child: Text(
                    'خطأ في التحميل',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 11.sp),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.push('/attendance');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade50,
                  foregroundColor: Colors.orange.shade900,
                  elevation: 0,
                  side: BorderSide(color: Colors.orange.shade200),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text('عرض الكشف الكامل', style: TextStyle(fontSize: 12.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
