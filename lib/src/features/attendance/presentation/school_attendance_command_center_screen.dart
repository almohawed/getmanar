// ignore_for_file: deprecated_member_use
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/daily_absence_provider.dart';
import 'providers/attendance_stats_providers.dart';
import '../domain/models/daily_absence_model.dart';
import '../../auth/presentation/auth_controller.dart';

class SchoolAttendanceCommandCenterScreen extends ConsumerStatefulWidget {
  const SchoolAttendanceCommandCenterScreen({super.key});
  @override
  ConsumerState<SchoolAttendanceCommandCenterScreen> createState() => _State();
}

class _State extends ConsumerState<SchoolAttendanceCommandCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<int> _getTotalStudents(String schoolId) async {
    if (schoolId.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('Students').count().get();
      return snap.count ?? 0;
    } catch (_) { return 0; }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final absences = ref.watch(dailyAbsenceProvider).value ?? [];
    final tardiness = ref.watch(dailyTardinessProvider).value ?? [];
    final absCount = absences.length;
    final tardCount = tardiness.length;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF004D40),
          title: Text('مركز الحضور والانضباط', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
          bottom: TabBar(
            controller: _tab,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [Tab(text: 'اليوم'), Tab(text: 'الغياب المتكرر'), Tab(text: 'التحليلات')],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _buildTodayTab(context, absences, tardiness, absCount, tardCount, schoolId),
            _buildFrequentTab(context),
            _buildAnalyticsTab(context, schoolId),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, List<DailyAbsenceModel> absences, List<DailyAbsenceModel> tardiness, int absCount, int tardCount, String schoolId) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(children: [
        FutureBuilder<int>(
          future: _getTotalStudents(schoolId),
          builder: (context, snap) {
            final total = snap.data ?? 0;
            final present = total > 0 ? (total - absCount).clamp(0, total) : 0;
            final rate = total > 0 ? (present / total * 100).clamp(0, 100).toDouble() : 0.0;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _statItem('الحضور', '${rate.toStringAsFixed(1)}%', Colors.green),
                  _statItem('حاضر', '$present', Colors.teal),
                  _statItem('غائب', '$absCount', Colors.red),
                  _statItem('متأخر', '$tardCount', Colors.orange),
                ]),
              ),
            );
          },
        ),
        SizedBox(height: 16.h),
        if (absences.isEmpty && tardiness.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 48.sp),
                SizedBox(height: 8.h),
                Text('جميع الطلاب حاضرون اليوم', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
            ),
          )
        else
          ...absences.map((a) => _studentCard(a, true)),
        ...tardiness.map((t) => _studentCard(t, false)),
      ]),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
    ]);
  }

  Widget _studentCard(DailyAbsenceModel s, bool isAbsent) {
    final color = isAbsent ? Colors.red : Colors.orange;
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: color.withOpacity(0.3))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Text(s.studentName.isNotEmpty ? s.studentName[0] : '؟', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        title: Text(s.studentName, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
        subtitle: Text('${s.className} • الحصة: ${s.period}', style: TextStyle(fontSize: 11.sp)),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
          child: Text(isAbsent ? 'غائب' : 'متأخر', style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildFrequentTab(BuildContext context) {
    final frequentAsync = ref.watch(frequentAbsenceProvider);
    return frequentAsync.when(
      data: (analysis) => SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(children: [
          if (analysis.students.isEmpty)
            Center(child: Padding(padding: EdgeInsets.all(32.w), child: Text('لا يوجد طلاب بغياب متكرر', style: TextStyle(fontSize: 14.sp, color: Colors.grey))))
          else
            ...analysis.students.map((s) => Card(
              margin: EdgeInsets.only(bottom: 8.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.red.withOpacity(0.1), child: Text('${s.absenceCount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                title: Text(s.student.name, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                subtitle: Text(s.className, style: TextStyle(fontSize: 11.sp)),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                  child: Text('${s.absenceCount} غياب', style: TextStyle(color: Colors.red, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
              ),
            )),
        ]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, String schoolId) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.analytics_rounded, size: 64.sp, color: const Color(0xFF004D40)),
          SizedBox(height: 16.h),
          Text('للاطلاع على التحليلات المتقدمة', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF004D40))),
          SizedBox(height: 8.h),
          Text('استخدم لوحة الحضور الذكية', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/smart-attendance-dashboard'),
            icon: const Icon(Icons.dashboard_rounded),
            label: const Text('فتح لوحة الحضور الذكية'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
          ),
        ]),
      ),
    );
  }
}
