import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../domain/models/counselor_session.dart';
import '../../auth/presentation/auth_controller.dart';

/// Provider لإحصائيات الجلسات
final sessionsStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  
  if (user == null || schoolId == null || schoolId.isEmpty) {
    return {};
  }

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfWeek = now.subtract(Duration(days: now.weekday % 7));

  // جلب جميع الجلسات للمدرسة
  final allSnapshot = await FirebaseFirestore.instance
      .collection('counseling_sessions')
      .where('schoolId', isEqualTo: schoolId)
      .get();

  final allSessions = allSnapshot.docs
      .map((doc) => CounselorSession.fromMap(doc.data(), doc.id))
      .toList();

  // فلترة في الذاكرة
  final monthSessions = allSessions
      .where((s) => s.scheduledAt.isAfter(startOfMonth.subtract(const Duration(days: 1))))
      .toList();
  
  final weekSessions = allSessions
      .where((s) => s.scheduledAt.isAfter(startOfWeek.subtract(const Duration(days: 1))))
      .toList();

  // إحصائيات حسب الحالة
  final statusCounts = <SessionStatus, int>{};
  final typeCounts = <SessionType, int>{};
  
  for (var session in monthSessions) {
    statusCounts[session.status] = (statusCounts[session.status] ?? 0) + 1;
    typeCounts[session.type] = (typeCounts[session.type] ?? 0) + 1;
  }

  // متوسط مدة الجلسات
  final completedSessions = monthSessions.where((s) => s.status == SessionStatus.completed).toList();
  final avgDuration = completedSessions.isEmpty
      ? 0.0
      : completedSessions.map((s) => s.durationMinutes).reduce((a, b) => a + b) / completedSessions.length;

  return {
    'totalMonth': monthSessions.length,
    'totalWeek': weekSessions.length,
    'completed': statusCounts[SessionStatus.completed] ?? 0,
    'scheduled': statusCounts[SessionStatus.scheduled] ?? 0,
    'cancelled': statusCounts[SessionStatus.cancelled] ?? 0,
    'noShow': statusCounts[SessionStatus.no_show] ?? 0,
    'individual': typeCounts[SessionType.individual] ?? 0,
    'group': typeCounts[SessionType.group] ?? 0,
    'family': typeCounts[SessionType.family] ?? 0,
    'teacherMeeting': typeCounts[SessionType.teacher_meeting] ?? 0,
    'avgDuration': avgDuration,
    'statusCounts': statusCounts,
    'typeCounts': typeCounts,
  };
});

/// شاشة تقارير الجلسات - تصميم احترافي مع رسوم بيانية
class SessionsReportsScreen extends ConsumerWidget {
  const SessionsReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(sessionsStatsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'تقارير الجلسات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
      ),
      body: statsAsync.when(
        data: (stats) {
          if (stats.isEmpty || stats['totalMonth'] == 0) {
            return _buildEmptyState();
          }
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(stats),
                SizedBox(height: 24.h),
                _buildStatusChart(stats),
                SizedBox(height: 24.h),
                _buildTypeChart(stats),
                SizedBox(height: 24.h),
                _buildDetailedStats(stats),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإحصائيات السريعة',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'جلسات الشهر',
                stats['totalMonth'].toString(),
                Icons.calendar_month,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'جلسات الأسبوع',
                stats['totalWeek'].toString(),
                Icons.calendar_today,
                Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'مكتملة',
                stats['completed'].toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'متوسط المدة',
                '${stats['avgDuration'].toStringAsFixed(0)} دقيقة',
                Icons.timer,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.shade400, color.shade600],
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: Colors.white, size: 24.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> stats) {
    final statusCounts = stats['statusCounts'] as Map<SessionStatus, int>;
    
    if (statusCounts.isEmpty) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final colors = {
      SessionStatus.completed: Colors.green,
      SessionStatus.scheduled: Colors.blue,
      SessionStatus.cancelled: Colors.red,
      SessionStatus.no_show: Colors.orange,
    };
    final labels = {
      SessionStatus.completed: 'مكتملة',
      SessionStatus.scheduled: 'مجدولة',
      SessionStatus.cancelled: 'ملغاة',
      SessionStatus.no_show: 'لم يحضر',
    };

    statusCounts.forEach((status, count) {
      final color = colors[status] ?? Colors.grey;
      final percentage = (count / stats['totalMonth'] * 100).toStringAsFixed(1);
      
      sections.add(
        PieChartSectionData(
          color: color,
          value: count.toDouble(),
          title: '$percentage%',
          radius: 100.r,
          titleStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع الجلسات حسب الحالة',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 200.h,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40.r,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: statusCounts.entries.map((entry) {
              final color = colors[entry.key] ?? Colors.grey;
              final label = labels[entry.key] ?? entry.key;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '$label (${entry.value})',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChart(Map<String, dynamic> stats) {
    final typeCounts = stats['typeCounts'] as Map<SessionType, int>;
    
    if (typeCounts.isEmpty) return const SizedBox.shrink();

    final colors = {
      SessionType.individual: Colors.purple,
      SessionType.group: Colors.teal,
      SessionType.family: Colors.pink,
      SessionType.teacher_meeting: Colors.indigo,
    };
    final labels = {
      SessionType.individual: 'فردية',
      SessionType.group: 'جماعية',
      SessionType.family: 'عائلية',
      SessionType.teacher_meeting: 'اجتماع معلمين',
    };

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع الجلسات حسب النوع',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20.h),
          ...typeCounts.entries.map((entry) {
            final color = colors[entry.key] ?? Colors.grey;
            final label = labels[entry.key] ?? entry.key.name;
            final percentage = (entry.value / stats['totalMonth'] * 100).toStringAsFixed(1);
            
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${entry.value} ($percentage%)',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  LinearProgressIndicator(
                    value: entry.value / stats['totalMonth'],
                    backgroundColor: color.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8.h,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> stats) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات تفصيلية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          _buildDetailRow('إجمالي الجلسات هذا الشهر', stats['totalMonth'].toString(), Colors.blue),
          _buildDetailRow('الجلسات المكتملة', stats['completed'].toString(), Colors.green),
          _buildDetailRow('الجلسات المجدولة', stats['scheduled'].toString(), Colors.blue),
          _buildDetailRow('الجلسات الملغاة', stats['cancelled'].toString(), Colors.red),
          _buildDetailRow('لم يحضر', stats['noShow'].toString(), Colors.orange),
          _buildDetailRow('الجلسات الفردية', stats['individual'].toString(), Colors.purple),
          _buildDetailRow('الجلسات الجماعية', stats['group'].toString(), Colors.teal),
          _buildDetailRow('الجلسات العائلية', stats['family'].toString(), Colors.pink),
          _buildDetailRow('اجتماعات المعلمين', stats['teacherMeeting'].toString(), Colors.indigo),
          Divider(height: 24.h, thickness: 1),
          _buildDetailRow(
            'معدل الإنجاز',
            '${((stats['completed'] / stats['totalMonth']) * 100).toStringAsFixed(1)}%',
            Colors.green,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 15.sp : 13.sp,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: isHighlight ? 16.sp : 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد بيانات كافية',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابدأ بإضافة جلسات لعرض التقارير',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.sp,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
