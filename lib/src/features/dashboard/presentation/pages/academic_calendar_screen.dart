import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../features/auth/presentation/auth_controller.dart';
import '../../../../features/academic_calendar/presentation/academic_calendar_manage_screen.dart';

class AcademicCalendarScreen extends ConsumerWidget {
  const AcademicCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final eventsAsync = ref.watch(academicCalendarProvider(schoolId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('التقويم الدراسي',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        color: Colors.white12, size: 64.sp),
                    SizedBox(height: 16.h),
                    Text('لم يتم إضافة التقويم الدراسي بعد',
                        style: TextStyle(color: Colors.white38, fontSize: 16.sp)),
                    SizedBox(height: 8.h),
                    Text('سيتم إضافته من قِبل إدارة المدرسة',
                        style: TextStyle(color: Colors.white24, fontSize: 12.sp),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          // Group by month
          final Map<String, List<AcademicEvent>> grouped = {};
          for (final e in events) {
            final key = intl.DateFormat('MMMM yyyy', 'ar').format(e.date);
            grouped.putIfAbsent(key, () => []).add(e);
          }

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month header
                Container(
                  margin: EdgeInsets.only(bottom: 10.h, top: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(entry.key,
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp,
                          fontWeight: FontWeight.w600)),
                ),
                ...entry.value.map((event) => _buildEventTile(event)),
              ],
            )).toList(),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white38)),
        error: (e, _) => Center(
            child: Text('خطأ في التحميل',
                style: TextStyle(color: Colors.white38, fontSize: 14.sp))),
      ),
    );
  }

  Widget _buildEventTile(AcademicEvent event) {
    final isPast = event.date.isBefore(DateTime.now());
    final dateStr = intl.DateFormat('EEEE، d MMMM', 'ar').format(event.date);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isPast
            ? Colors.white.withValues(alpha: 0.03)
            : event.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPast ? Colors.white12 : event.color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40.w, height: 40.w,
          decoration: BoxDecoration(
            color: (isPast ? Colors.white24 : event.color).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(event.icon,
              color: isPast ? Colors.white24 : event.color, size: 20.sp)),
        SizedBox(width: 12.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title,
                style: TextStyle(
                    color: isPast ? Colors.white38 : Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white24)),
            Text(dateStr,
                style: TextStyle(
                    color: isPast ? Colors.white24 : Colors.white54,
                    fontSize: 11.sp)),
            if (event.endDate != null)
              Text('حتى: ${intl.DateFormat('d MMMM', 'ar').format(event.endDate!)}',
                  style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
            if (event.description != null && event.description!.isNotEmpty)
              Text(event.description!,
                  style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
          ],
        )),
        if (isPast)
          Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 18.sp),
      ]),
    );
  }
}
