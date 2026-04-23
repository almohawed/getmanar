import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../admin/data/mock_staff_repository.dart';
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import '../../dashboard/presentation/dashboard_palette.dart';
import '../../dashboard/presentation/web_access_footer.dart';
import 'admin_dashboard_providers.dart';
import '../../dashboard/presentation/widgets/qr_scanner_fab.dart';

// Live counts provider
final _adminLiveCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return {};
  final db = FirebaseFirestore.instance;
  final school = db.collection('Schools').doc(schoolId);
  final now = DateTime.now();
  final todayTs = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
  try {
    final results = await Future.wait<AggregateQuerySnapshot>([
      db.collection('behavioral_cases').where('status', isEqualTo: 'active').count().get(),
      db.collection('behavioral_violations').where('timestamp', isGreaterThanOrEqualTo: todayTs).count().get(),
      school.collection('HealthCases').count().get(),
      school.collection('MaintenanceTickets').where('status', whereIn: ['open', 'pending']).count().get(),
      school.collection('Permissions').where('status', isEqualTo: 'pending').count().get(),
      school.collection('StudentAttendance').where('date', isGreaterThanOrEqualTo: todayTs).where('status', isEqualTo: 'absent').count().get(),
    ]);
    return {
      'behaviorCases': results[0].count ?? 0,
      'violations': results[1].count ?? 0,
      'healthCases': results[2].count ?? 0,
      'maintenance': results[3].count ?? 0,
      'permissions': results[4].count ?? 0,
      'absences': results[5].count ?? 0,
    };
  } catch (_) { return {}; }
});

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final Map<String, dynamic>? extra;
  const _ActionItem({required this.icon, required this.label, required this.color, required this.route, this.extra});
}

class AdminDashboardV2 extends ConsumerWidget {
  const AdminDashboardV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final schoolName = ref.watch(schoolProvider(schoolId).select((v) => v.value?.name ?? ''));
    final studentsCount = ref.watch(studentsProvider.select((v) => v.value?.length ?? 0));
    final classesCount = ref.watch(classesProvider.select((v) => v.value?.length ?? 0));
    final teachersCount = ref.watch(teachersProvider.select((v) => v.value?.length ?? 0));
    final staffCount = ref.watch(staffProvider.select((v) => v.value?.length ?? 0));
    final schoolStatus = ref.watch(schoolStatusProvider).value ?? SchoolStatusMetrics();
    final actionNeeded = ref.watch(actionNeededProvider).value ?? [];
    final liveCounts = ref.watch(_adminLiveCountsProvider(schoolId)).value ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: const QrScannerFab(),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context, schoolName),
              SizedBox(height: 24.h),

              // Welcome Banner
              WelcomeBanner(
                userName: user?.name ?? 'المدير',
                gradient: DashboardPalette.bannerGradient('admin'),
              ),
              SizedBox(height: 16.h),

              // تنبيهات
              if (actionNeeded.isNotEmpty) ...[
                _buildActionNeeded(context, actionNeeded),
                SizedBox(height: 16.h),
              ],

              // بطاقات الإحصائيات
              Row(children: [
                Expanded(child: _buildStatCard(context, 'الطلاب', '$studentsCount', Colors.indigo)),
                SizedBox(width: 16.w),
                Expanded(child: _buildStatCard(context, 'الفصول', '$classesCount', Colors.teal)),
              ]),
              SizedBox(height: 16.h),
              Row(children: [
                Expanded(child: _buildStatCard(context, 'المعلمين', '$teachersCount', Colors.orange)),
                SizedBox(width: 16.w),
                Expanded(child: _buildStatCard(context, 'الموظفين', '$staffCount', Colors.purple)),
              ]),
              SizedBox(height: 16.h),

              // شريط الحالة اليومية
              _buildDailyStatus(context, schoolStatus),
              SizedBox(height: 32.h),

              // الأقسام
              _buildSectionHeader(context, 'القيادة المدرسية'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.auto_awesome_motion, label: 'الخلاصة الاستراتيجية', color: Colors.deepPurple, route: '/smart-placeholder', extra: {'title': 'الحالة الاستراتيجية للمدرسة', 'color': Colors.deepPurple, 'icon': Icons.auto_awesome_motion}),
                _ActionItem(icon: Icons.account_tree_outlined, label: 'إطار الحوكمة', color: Colors.indigo, route: '/governance-framework'),
                _ActionItem(icon: Icons.bar_chart, label: 'التقارير', color: Colors.indigo, route: '/smart-placeholder', extra: {'title': 'مركز التقارير والتحليل'}),
                _ActionItem(icon: Icons.trending_up, label: 'الخطط التطويرية', color: Colors.blue, route: '/development-plans'),
                _ActionItem(icon: Icons.menu_book, label: 'الدليل الإجرائي', color: Colors.teal, route: '/school-guide'),
                _ActionItem(icon: Icons.groups, label: 'الاجتماعات', color: Colors.teal, route: '/smart-placeholder', extra: {'title': 'سجل الاجتماعات واللجان'}),
              ]),

              _buildSectionHeader(context, 'الشؤون الأكاديمية'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.people_alt, label: 'الطلاب', color: Colors.blue.shade700, route: '/students-list'),
                _ActionItem(icon: Icons.qr_code_2, label: 'ملصقات الطلاب', color: Colors.indigo.shade700, route: '/student-barcodes'),
                _ActionItem(icon: Icons.family_restroom, label: 'أولياء الأمور', color: Colors.purple.shade700, route: '/parents'),
                _ActionItem(icon: Icons.person_pin, label: 'المعلمين', color: Colors.green.shade700, route: '/teachers-list'),
                _ActionItem(icon: Icons.class_, label: 'الفصول', color: Colors.orange.shade700, route: '/classes-list'),
                _ActionItem(icon: Icons.auto_awesome, label: 'الجدول المدرسي', color: Colors.indigo.shade700, route: '/smart-schedule'),
                _ActionItem(icon: Icons.assignment, label: 'الاختبارات', color: Colors.red.shade700, route: '/smart-exams'),
              ]),

              _buildSectionHeader(context, 'شؤون الطلاب'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.fact_check, label: liveCounts['absences'] != null && liveCounts['absences']! > 0 ? 'الحضور والغياب (${liveCounts['absences']})' : 'الحضور والغياب', color: Colors.teal, route: '/school-attendance-dashboard'),
                _ActionItem(icon: Icons.gavel, label: liveCounts['behaviorCases'] != null && liveCounts['behaviorCases']! > 0 ? 'السلوك والمواظبة (${liveCounts['behaviorCases']})' : 'السلوك والمواظبة', color: Colors.orange, route: '/behavior'),
                _ActionItem(icon: Icons.psychology, label: 'التوجيه الطلابي', color: Colors.purple, route: '/counselor-dashboard'),
                _ActionItem(icon: Icons.local_activity, label: 'النشاط الطلابي', color: Colors.teal, route: '/activity-dashboard'),
                _ActionItem(icon: Icons.health_and_safety, label: liveCounts['healthCases'] != null && liveCounts['healthCases']! > 0 ? 'الصحة المدرسية (${liveCounts['healthCases']})' : 'الصحة المدرسية', color: Colors.cyan, route: '/health-dashboard'),
              ]),

              _buildSectionHeader(context, 'الشؤون الإدارية'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.badge, label: 'الموظفين', color: Colors.indigo, route: '/staff-list'),
                _ActionItem(icon: Icons.assignment_ind, label: 'التكليفات الإدارية', color: Colors.blue, route: '/admin-tasks'),
                _ActionItem(icon: Icons.build, label: liveCounts['maintenance'] != null && liveCounts['maintenance']! > 0 ? 'الصيانة (${liveCounts['maintenance']})' : 'الصيانة', color: Colors.brown, route: '/smart-placeholder', extra: {'title': 'مركز عمليات الصيانة'}),
                _ActionItem(icon: Icons.inventory, label: 'العهد', color: Colors.blueGrey, route: '/smart-placeholder', extra: {'title': 'إدارة العهد والممتلكات'}),
                _ActionItem(icon: Icons.directions_bus, label: 'النقل المدرسي', color: Colors.yellow.shade800, route: '/smart-placeholder', extra: {'title': 'مراقبة النقل والأسطول'}),
                _ActionItem(icon: Icons.security, label: 'الأمن والسلامة', color: Colors.red, route: '/safety-dashboard'),
              ]),

              _buildSectionHeader(context, 'التواصل والإعلام'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.inbox, label: 'الوارد', color: Colors.green, route: '/incoming-mail', extra: {'schoolId': user?.schoolId, 'userId': user?.id, 'userName': user?.name}),
                _ActionItem(icon: Icons.outbox, label: 'الصادر', color: Colors.blue, route: '/smart-placeholder', extra: {'title': 'سجل الصادر الرقمي', 'schoolId': user?.schoolId, 'userName': user?.name, 'userRole': user?.role.name}),
                _ActionItem(icon: Icons.campaign, label: 'التعاميم', color: Colors.orange, route: '/circulars'),
                _ActionItem(icon: Icons.notifications_active, label: 'الإعلانات', color: Colors.amber, route: '/smart-placeholder', extra: {'title': 'مركز الإعلانات والاتصال'}),
              ]),

              _buildSectionHeader(context, 'خدمة الرسائل SMS'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.settings_cell, label: 'إعدادات SMS', color: const Color(0xFF00838F), route: '/admin/sms-settings'),
              ]),

              _buildSectionHeader(context, 'الإعدادات'),
              _buildActionGrid(context, ref, [
                _ActionItem(icon: Icons.settings, label: 'إعدادات المدرسة', color: Colors.grey, route: '/settings'),
                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),
                _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),
                _ActionItem(icon: Icons.mic, label: 'مسؤول الإذاعة', color: const Color(0xFF1A237E), route: '/assign-broadcast-supervisor'),
              ]),

              SizedBox(height: 32.h),
              const WebAccessFooter(),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String schoolName) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: DashboardPalette.headerGradient('admin'),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 26.sp),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (schoolName.isNotEmpty) ...[
                    Text(schoolName, style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                  ],
                  Text('مدير المدرسة', style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text('إدارة المدرسة والإشراف على جميع الأقسام', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.85), color.withOpacity(0.95)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8), spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 15.sp, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600))),
              Container(padding: EdgeInsets.all(10.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12.r)), child: Icon(Icons.trending_up, color: Colors.white, size: 20.sp)),
            ],
          ),
          SizedBox(height: 16.h),
          Text(value, style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
          SizedBox(height: 4.h),
          Container(height: 3.h, width: 40.w, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(2.r))),
        ],
      ),
    );
  }

  Widget _buildDailyStatus(BuildContext context, SchoolStatusMetrics status) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D1B4B), Color(0xFF1A237E)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حالة المدرسة اليوم', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 12.h),
          Row(children: [
            _SI('وارد اليوم', status.incomingToday, Icons.call_received, Colors.blue.shade200),
            _SD(),
            _SI('صادر اليوم', status.outgoingToday, Icons.call_made, Colors.green.shade200),
            _SD(),
            _SI('معلقة', status.pendingTransactions, Icons.hourglass_empty, Colors.orange.shade200),
            _SD(),
            _SI('متأخرة', status.delayedTransactions, Icons.warning, Colors.red.shade200),
            _SD(),
            _SI('صيانة', status.openMaintenanceReports, Icons.build, Colors.brown.shade200),
            _SD(),
            _SI('طلبات', status.requestsAwaitingApproval, Icons.approval, Colors.purple.shade200),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionNeeded(BuildContext context, List<ActionNeededItem> items) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: Colors.red.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notification_important, color: Colors.red.shade700, size: 18.sp),
            SizedBox(width: 8.w),
            Text('يحتاج إجراء الآن', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            const Spacer(),
            Container(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10.r)), child: Text('${items.length}', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold))),
          ]),
          SizedBox(height: 10.h),
          ...items.take(3).map((item) => Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: Row(children: [
              Icon(Icons.circle, size: 7.sp, color: Colors.red),
              SizedBox(width: 8.w),
              Expanded(child: Text(item.title, style: TextStyle(fontSize: 12.sp, color: Colors.red.shade900))),
              Text(item.timeAgo, style: TextStyle(fontSize: 10.sp, color: Colors.red.shade600)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h, top: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.indigo.shade100.withOpacity(0.3)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(left: BorderSide(color: Colors.indigo.shade700, width: 4.w)),
      ),
      child: Row(
        children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: Colors.indigo.shade700, borderRadius: BorderRadius.circular(8.r)), child: Icon(Icons.folder_special, color: Colors.white, size: 20.sp)),
          SizedBox(width: 12.w),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 18.sp, letterSpacing: 0.3))),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, WidgetRef ref, List<_ActionItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) crossAxisCount = 3;
        if (constraints.maxWidth > 900) crossAxisCount = 4;
        if (constraints.maxWidth > 1200) crossAxisCount = 5;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _buildActionCard(context, icon: item.icon, label: item.label, color: item.color, onTap: () {
              final implemented = ['/students-list','/teachers-list','/classes-list','/schedule-management','/smart-schedule','/assign-subjects','/admin-tasks','/staff-list','/admin-assignments','/smart-exams','/parents','/maintenance-requests','/school-guide','/activity-dashboard','/counselor-dashboard','/health-dashboard','/safety-dashboard','/attendance','/behavior','/settings','/code-management','/governance-framework','/incoming-mail','/circulars','/circulars/create','/school-attendance-dashboard','/development-plans','/permissions-dashboard','/subscription-plans','/student-barcodes','/admin/sms-settings','/deputy-sms','/assign-broadcast-supervisor'];
              if (implemented.contains(item.route)) {
                context.push(item.route, extra: item.extra);
              } else {
                context.push('/smart-placeholder', extra: item.extra ?? {'title': item.label, 'color': item.color, 'icon': item.icon});
              }
            });
          },
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.15), width: 1.0),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 1), spreadRadius: 0)],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(2.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 64.sp),
                SizedBox(height: 8.h),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade800, height: 1.2, letterSpacing: -0.1), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SI extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color color;
  const _SI(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: color, size: 16.sp),
    SizedBox(height: 3.h),
    Text('$value', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: Colors.white60, fontSize: 9.sp), textAlign: TextAlign.center),
  ]));
}

class _SD extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36.h, color: Colors.white.withOpacity(0.15));
}
