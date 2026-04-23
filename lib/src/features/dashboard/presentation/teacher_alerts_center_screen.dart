import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:collection/collection.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../wait_management/data/mock_wait_repository.dart';
import '../../behavior/presentation/behavior_controller.dart';

// Providers for this screen
final teacherWaitsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) async {
  final repo = ref.watch(mockWaitRepositoryProvider);
  return repo.getTeacherWaits(teacherId);
});

final rejectedViolationsProvider = FutureProvider.family<List<BehaviorRecord>, String>((ref, teacherId) async {
  final repo = ref.watch(behaviorRepositoryProvider);
  return repo.getRejectedViolations(teacherId);
});

class TeacherAlertsCenterScreen extends ConsumerStatefulWidget {
  const TeacherAlertsCenterScreen({super.key});

  @override
  ConsumerState<TeacherAlertsCenterScreen> createState() =>
      _TeacherAlertsCenterScreenState();
}

class _TeacherAlertsCenterScreenState
    extends ConsumerState<TeacherAlertsCenterScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final teacherId = userAsync.value?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFD32F2F)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مركز التنبيهات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('حصص الانتظار والمخالفات المرفوضة', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // تبويبات مخصصة
          Container(
            color: const Color(0xFFB71C1C),
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Row(
              children: [
                Expanded(child: _buildTab(0, 'حصص الانتظار', Icons.access_time_rounded)),
                SizedBox(width: 10.w),
                Expanded(child: _buildTab(1, 'المرفوضات', Icons.cancel_rounded)),
              ],
            ),
          ),
          Expanded(
            child: _selectedIndex == 0
                ? _WaitsTab(teacherId: teacherId)
                : _RejectedTab(teacherId: teacherId),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final selected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: selected ? Colors.white : Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp, color: selected ? const Color(0xFFB71C1C) : Colors.white),
            SizedBox(width: 6.w),
            Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: selected ? const Color(0xFFB71C1C) : Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _WaitsTab extends ConsumerWidget {
  final String teacherId;
  const _WaitsTab({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitsAsync = ref.watch(teacherWaitsProvider(teacherId));
    return waitsAsync.when(
      data: (waits) {
        final sorted = waits.sorted((a, b) {
          final ad = _dayOrder(a['day']?.toString() ?? '');
          final bd = _dayOrder(b['day']?.toString() ?? '');
          if (ad != bd) return ad.compareTo(bd);
          final ap = int.tryParse('${a['period']}') ?? 0;
          final bp = int.tryParse('${b['period']}') ?? 0;
          return ap.compareTo(bp);
        });

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.08), Colors.amber.withOpacity(0.04)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time_rounded, size: 64.sp, color: Colors.orange.shade600),
                ),
                SizedBox(height: 16.h),
                Text('لا توجد حصص انتظار حالية', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final w = sorted[index];
            final day = '${w['day']}';
            final period = '${w['period']}';
            final klass = '${w['class']}';
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.shade200),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 6.w,
                    height: 70.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.amber.shade600], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(16.r), bottomRight: Radius.circular(16.r)),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.access_time_filled_rounded, color: Colors.orange.shade700, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الحصة $period - فصل $klass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.grey.shade900)),
                        SizedBox(height: 3.h),
                        Text(day, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 12.w),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text('انتظار', style: TextStyle(color: Colors.orange.shade800, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 12.w),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  int _dayOrder(String day) {
    final ar = [
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة'
    ];
    final en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final arIdx = ar.indexOf(day);
    if (arIdx >= 0) return arIdx;
    final enIdx = en.indexOf(day);
    if (enIdx >= 0) return enIdx;
    return 999; // unknown days go last
  }
}

class _RejectedTab extends ConsumerWidget {
  final String teacherId;
  const _RejectedTab({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejectedAsync = ref.watch(rejectedViolationsProvider(teacherId));
    return rejectedAsync.when(
      data: (violations) {
        final sorted = [...violations]
          ..sort(
            (a, b) => b.timestamp.compareTo(a.timestamp),
          );

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.withOpacity(0.08), Colors.teal.withOpacity(0.04)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline_rounded, size: 64.sp, color: Colors.green.shade600),
                ),
                SizedBox(height: 16.h),
                Text('لا توجد مخالفات مرفوضة', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                SizedBox(height: 8.h),
                Text('ممتاز! جميع مخالفاتك معتمدة', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final BehaviorRecord v = sorted[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.red.shade200),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16.r), topRight: Radius.circular(16.r)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10.r)),
                          child: Icon(Icons.cancel_rounded, color: Colors.red.shade700, size: 18.sp),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(v.description, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.grey.shade900)),
                        ),
                        Text(_timeAgo(v.timestamp), style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.red.shade100)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14.sp, color: Colors.red.shade700),
                          SizedBox(width: 8.w),
                          Expanded(child: Text('سبب الرفض: ${v.rejectionReason ?? "غير محدد"}', style: TextStyle(fontSize: 12.sp, color: Colors.red.shade800))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }
}
