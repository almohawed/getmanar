import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../dashboard/presentation/web_access_footer.dart';
import '../../dashboard/presentation/dashboard_palette.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/services/audit_service.dart';
import '../../behavior/presentation/add_violation_screen.dart';
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart'; // For preview
import '../../reports/presentation/student_reports_generator.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../behavior/domain/bathroom_pass.dart';
import 'widgets/student_affairs_ops_radar.dart';
import 'widgets/daily_danger_card.dart';
import 'widgets/discipline_pressure_card.dart';
import 'widgets/daily_attendance_card.dart';
import 'command_center_providers.dart';
import 'student_affairs_providers.dart';
import '../../behavior/presentation/behavior_enhancement_dashboard_screen.dart';
import '../../academic/data/school_repository.dart';
import '../../behavior/presentation/behavior_controller.dart';

class StudentAffairsDashboard extends ConsumerStatefulWidget {
  const StudentAffairsDashboard({super.key});

  @override
  ConsumerState<StudentAffairsDashboard> createState() =>
      _StudentAffairsDashboardState();
}

class _StudentAffairsDashboardState
    extends ConsumerState<StudentAffairsDashboard> {
  @override
  void initState() {
    super.initState();
    // Log dashboard access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'view_dashboard',
            description: 'User viewed Student Affairs Dashboard',
            metadata: {'section': 'student_affairs'},
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final hasDelegatedAdmin =
        user != null &&
        user.delegatedPermissions != null &&
        user.delegatedPermissions!.isNotEmpty;
    final inboxCount = ref.watch(pendingTeacherNotesProvider).when(
      data: (notes) => notes.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student-scan'),
        backgroundColor: Colors.indigo.shade700,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'ماسح هوية الطلاب',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(hasDelegatedAdmin),
                SizedBox(height: 16.h),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final children = const [
                      DailyDangerCard(),
                      DisciplinePressureCard(),
                      DailyAttendanceCard(),
                    ];

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: children[0]),
                          SizedBox(width: 12.w),
                          Expanded(child: children[1]),
                          SizedBox(width: 12.w),
                          Expanded(child: children[2]),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        children[0],
                        SizedBox(height: 12.h),
                        children[1],
                        SizedBox(height: 12.h),
                        children[2],
                      ],
                    );
                  },
                ),

                SizedBox(height: 16.h),
                WelcomeBanner(
                  userName: user?.name ?? 'وكيل شؤون الطلاب',
                  gradient: DashboardPalette.bannerGradient('deputyStudent'),
                ),
                SizedBox(height: 16.h),

                // Ops Radar
                const StudentAffairsOpsRadar(),
                SizedBox(height: 24.h),

                // Stat Cards
                _buildStatCardsSection(),
                SizedBox(height: 16.h),

                _buildSection(
                  context,
                  title: 'الإشراف والمناوبة',
                  color: const Color(0xFF0D47A1),
                  items: [
                    {
                      'icon': Icons.supervisor_account_rounded,
                      'title': 'الإشراف والمناوبة',
                      'route': '/supervision-duty',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'الاستئذانات',
                  color: Colors.amber.shade800,
                  items: [
                    {
                      'icon': Icons.exit_to_app,
                      'title': 'إذن خروج طالب',
                      'route': '/student-exit-permission',
                    },
                    {
                      'icon': Icons.list_alt,
                      'title': 'طلبات الاستئذان',
                      'route': '/deputy-requests',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'الانضباط اليومي',
                  color: Colors.orange.shade800,
                  items: [
                    {
                      'icon': Icons.calendar_today,
                      'title': 'الحضور والغياب',
                      'route': '/attendance',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'إدارة السلوك',
                  color: Colors.red.shade800,
                  items: [
                    {
                      'icon': Icons.inbox,
                      'title': inboxCount > 0
                          ? 'وارد المعلمين ($inboxCount)'
                          : 'وارد المعلمين',
                      'route': '/behavior-inbox',
                    },
                    {
                      'icon': Icons.print,
                      'title': 'لائحة السلوك',
                      'route': '/print-notice',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'هوية الطلاب',
                  color: Colors.indigo.shade700,
                  items: [
                    {
                      'icon': Icons.qr_code_2,
                      'title': 'ملصقات تعريف الطلاب',
                      'route': '/student-barcodes',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'الحالات الطلابية',
                  color: Colors.purple.shade800,
                  items: [
                    {
                      'icon': Icons.folder_shared,
                      'title': 'الملف السلوكي',
                      'route': '/student-profile',
                    },
                    {
                      'icon': Icons.call,
                      'title': 'استدعاء ولي أمر',
                      'route': '/call-parent',
                    },
                    {
                      'icon': Icons.groups,
                      'title': 'توثيق اجتماع',
                      'route': '/meeting-log',
                    },
                    {
                      'icon': Icons.psychology,
                      'title': 'تحويل للمرشد',
                      'route': '/refer-counselor',
                    },
                    {
                      'icon': Icons.archive,
                      'title': 'الأرشيف',
                      'route': '/archive',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'الإشراف اليومي',
                  color: Colors.blue.shade800,
                  items: [
                    {
                      'icon': Icons.directions_walk,
                      'title': 'متابعة الاصطفاف',
                      'route': '/assembly',
                    },
                    {
                      'icon': Icons.fastfood,
                      'title': 'متابعة الفسحة',
                      'route': '/recess',
                    },
                    {
                      'icon': Icons.mosque,
                      'title': 'متابعة الصلاة',
                      'route': '/prayer',
                    },
                    {
                      'icon': Icons.exit_to_app,
                      'title': 'متابعة الانصراف',
                      'route': '/dismissal',
                    },
                    {
                      'icon': Icons.report_problem,
                      'title': 'بلاغ فوري',
                      'route': '/immediate-report',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'التقارير',
                  color: Colors.green.shade800,
                  items: [
                    {
                      'icon': Icons.timer,
                      'title': 'كشف التأخر',
                      'route': 'action:report_tardy',
                    },
                    {
                      'icon': Icons.person_off,
                      'title': 'كشف الغياب',
                      'route': 'action:report_absence',
                    },
                    {
                      'icon': Icons.gavel,
                      'title': 'كشف المخالفات',
                      'route': 'action:report_violations',
                    },
                  ],
                ),

                _buildSection(
                  context,
                  title: 'لوحة التقارير المتقدمة',
                  color: Colors.teal.shade800,
                  items: [
                    {
                      'icon': Icons.report,
                      'title': 'تقارير السلوك',
                      'route': '/behavior-report',
                    },
                    {
                      'icon': Icons.fact_check,
                      'title': 'تقارير المواظبة',
                      'route': '/attendance-report',
                    },
                    {
                      'icon': Icons.insert_chart,
                      'title': 'إحصائيات المخالفات',
                      'route': '/violation-stats',
                    },
                    {
                      'icon': Icons.picture_as_pdf,
                      'title': 'تصدير السجلات',
                      'route': '/export-records',
                    },
                  ],
                ),

                SizedBox(height: 24.h),
                const WebAccessFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Map<String, dynamic>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title, color),
        _buildActionGrid(context, items, color),
        SizedBox(height: 24.h),
      ],
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h, top: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(
            color: color,
            width: 4.w,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.folder_special,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
                fontSize: 18.sp,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionGrid(BuildContext context, List<Map<String, dynamic>> items, Color color) {
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
            childAspectRatio: 1.1, // Balanced proportions
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final badgeCount = _badgeCountForRoute(item['route'] as String);
            
            return _buildActionCard(
              context,
              icon: item['icon'] as IconData,
              label: item['title'] as String,
              color: color,
              badgeCount: badgeCount,
              onTap: () {
                ref.read(auditServiceProvider).logAction(
                  action: 'click_menu_item',
                  description: 'Clicked on ${item['title']}',
                  metadata: {'route': item['route']},
                );

                final route = item['route'] as String;
                if (route.startsWith('action:')) {
                  _showReportOptions(context, route, item['title'] as String);
                  return;
                }

                if (route == '/add-violation') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddViolationScreen(),
                    ),
                  );
                } else if (route.startsWith('/')) {
                  try {
                    context.push(route);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تعذر فتح قسم "${item['title']}" حالياً، يرجى مراجعة مسؤول النظام.',
                        ),
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Centered content with balanced padding
            Center(
              child: Padding(
                padding: EdgeInsets.all(2.w), // Reduced to 2.w for tighter spacing
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon - much bigger and clearer
                    Icon(
                      icon,
                      color: color,
                      size: 64.sp, // Increased to 64.sp for maximum clarity
                    ),
                    SizedBox(height: 8.h),
                    // Text - slightly bigger to match larger icon
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.sp, // Increased from 11.sp to 12.sp
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Badge
            if (badgeCount > 0)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _badgeCountForRoute(String route) {
    if (route == '/attendance') {
      final overview = ref.watch(dailyDisciplineOverviewProvider).value;
      return overview?['absent'] ?? 0;
    }
    if (route == '/tardiness' || route == '/tardiness-classification') {
      final overview = ref.watch(dailyDisciplineOverviewProvider).value;
      return overview?['late'] ?? 0;
    }
    if (route == '/notify-parents') {
      return ref.watch(smsStatsProvider).when(
        data: (sms) => sms['queued'] ?? 0,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/deputy-sms') {
      return ref.watch(smsStatsProvider).when(
        data: (sms) => sms['failed'] ?? 0,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/escalation') {
      return ref.watch(behaviorStatsProvider).when(
        data: (behavior) => behavior['escalationDue'] ?? 0,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/undertakings') {
      return ref.watch(activeUndertakingsCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/call-parent') {
      return ref.watch(openParentSummonsCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/meeting-log') {
      return ref.watch(upcomingMeetingsCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/refer-counselor') {
      return ref.watch(openCounselorReferralsCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/immediate-report') {
      return ref.watch(supervisionOpenTodayCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/assembly' ||
        route == '/recess' ||
        route == '/prayer' ||
        route == '/dismissal') {
      return ref.watch(supervisionChecksTodayCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/behavior-report' || route == '/violation-stats') {
      return ref.watch(behaviorStatsProvider).when(
        data: (behavior) => behavior['open'] ?? 0,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/behavior') {
      return ref.watch(pendingBehaviorNoticesCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/print-notice') {
      return ref.watch(pendingBehaviorNoticesCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/behavior-analysis') {
      return ref.watch(behaviorWeakCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/behavior-enhancement') {
      return ref.watch(behaviorEnhancementDashboardProvider).when(
        data: (data) => data.needsSupportCount,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/attendance-report') {
      return ref.watch(dailyDisciplineOverviewProvider).when(
        data: (overview) => overview['absent'] ?? 0,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/export-records') {
      return ref.watch(unseenReportExportsCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    return 0;
  }

  Widget _buildStatCardsSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final disciplineAsync = ref.watch(dailyDisciplineOverviewProvider);
                  
                  return disciplineAsync.when(
                    data: (data) {
                      final total = data['total'] ?? 0;
                      return _buildStatCard(
                        context,
                        'الطلاب',
                        '$total',
                        Colors.indigo,
                      );
                    },
                    loading: () => _buildStatCardLoading(context, 'الطلاب', Colors.indigo),
                    error: (_, __) => _buildStatCard(context, 'الطلاب', '0', Colors.indigo),
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final disciplineAsync = ref.watch(dailyDisciplineOverviewProvider);
                  
                  return disciplineAsync.when(
                    data: (data) {
                      final absent = data['absent'] ?? 0;
                      return _buildStatCard(
                        context,
                        'الغياب اليوم',
                        '$absent',
                        Colors.red,
                      );
                    },
                    loading: () => _buildStatCardLoading(context, 'الغياب اليوم', Colors.red),
                    error: (_, __) => _buildStatCard(context, 'الغياب اليوم', '0', Colors.red),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final disciplineAsync = ref.watch(dailyDisciplineOverviewProvider);
                  
                  return disciplineAsync.when(
                    data: (data) {
                      final late = data['late'] ?? 0;
                      return _buildStatCard(
                        context,
                        'التأخر اليوم',
                        '$late',
                        Colors.orange,
                      );
                    },
                    loading: () => _buildStatCardLoading(context, 'التأخر اليوم', Colors.orange),
                    error: (_, __) => _buildStatCard(context, 'التأخر اليوم', '0', Colors.orange),
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final behaviorAsync = ref.watch(behaviorStatsProvider);
                  
                  return behaviorAsync.when(
                    data: (data) {
                      final open = data['open'] ?? 0;
                      return _buildStatCard(
                        context,
                        'المخالفات المفتوحة',
                        '$open',
                        Colors.purple,
                      );
                    },
                    loading: () => _buildStatCardLoading(context, 'المخالفات المفتوحة', Colors.purple),
                    error: (_, __) => _buildStatCard(context, 'المخالفات المفتوحة', '0', Colors.purple),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatCardLoading(BuildContext context, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          right: BorderSide(
            color: color.withOpacity(0.3),
            width: 3.w,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: SizedBox(
              width: 16.w,
              height: 16.h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '...',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.85),
            color.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  _getIconForLabel(label),
                  color: Colors.white,
                  size: 18.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            height: 3.h,
            width: 40.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    if (label.contains('الطلاب')) return Icons.people;
    if (label.contains('الغياب')) return Icons.person_off;
    if (label.contains('التأخر')) return Icons.access_time;
    if (label.contains('المخالفات')) return Icons.warning;
    return Icons.info;
  }

  Widget _buildHeader(bool hasDelegatedAdmin) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: DashboardPalette.headerGradient('deputyStudent'),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 26.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'وكيل شؤون الطلاب',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (hasDelegatedAdmin)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'لوحة المدير',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'إدارة السلوك، الانضباط، والإشراف اليومي',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) return;

    try {
      String dateKey(DateTime dt) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }

      List<DateTime> daysInRange(DateTime from, DateTime toExclusive) {
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(
          toExclusive.year,
          toExclusive.month,
          toExclusive.day,
        );
        final days = <DateTime>[];
        for (
          var dt = start;
          dt.isBefore(end);
          dt = dt.add(const Duration(days: 1))
        ) {
          days.add(dt);
        }
        return days;
      }

      final school = await ref
          .read(schoolRepositoryProvider)
          .getSchool(user.schoolId!);
      final schoolName = (school?.name.trim().isNotEmpty ?? false)
          ? school!.name
          : 'المدرسة';

      if (action == 'action:report_tardy') {
        final days = daysInRange(dateFrom, dateTo);
        if (days.length > 60) {
          throw Exception('المدة كبيرة جدًا. اختر فترة لا تتجاوز 60 يوم.');
        }

        final List<StudentAttendance> list = [];
        for (final day in days) {
          final snap = await FirebaseFirestore.instance
              .collection('Schools')
              .doc(user.schoolId)
              .collection('StudentAttendance')
              .where('dateKey', isEqualTo: dateKey(day))
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            data['id'] = d.id;
            final rec = StudentAttendance.fromMap(data);
            if (rec.status == StudentAttendanceStatus.late) {
              list.add(rec);
            }
          }
        }

        list.sort((a, b) => b.date.compareTo(a.date));

        final pdf = await StudentReportsGenerator.generateTardyReport(
          schoolName: schoolName,
          attendanceList: list,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        await Printing.layoutPdf(onLayout: (_) => pdf);
      } else if (action == 'action:report_absence') {
        final days = daysInRange(dateFrom, dateTo);
        if (days.length > 60) {
          throw Exception('المدة كبيرة جدًا. اختر فترة لا تتجاوز 60 يوم.');
        }

        final List<StudentAttendance> list = [];
        for (final day in days) {
          final snap = await FirebaseFirestore.instance
              .collection('Schools')
              .doc(user.schoolId)
              .collection('StudentAttendance')
              .where('dateKey', isEqualTo: dateKey(day))
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            data['id'] = d.id;
            final rec = StudentAttendance.fromMap(data);
            if (rec.status == StudentAttendanceStatus.absent ||
                rec.status == StudentAttendanceStatus.excused) {
              list.add(rec);
            }
          }
        }

        list.sort((a, b) => b.date.compareTo(a.date));

        final pdf = await StudentReportsGenerator.generateAbsenceReport(
          schoolName: schoolName,
          attendanceList: list,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        await Printing.layoutPdf(onLayout: (_) => pdf);
      } else if (action == 'action:report_violations') {
        DateTime? parseTs(dynamic v) {
          if (v is Timestamp) return v.toDate();
          if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
          if (v is String) return DateTime.tryParse(v);
          if (v is DateTime) return v;
          return null;
        }

        final snapshot = await FirebaseFirestore.instance
            .collection('behavior_records')
            .where('schoolId', isEqualTo: user.schoolId)
            .limit(1500)
            .get();

        final list =
            snapshot.docs
                .map((d) {
                  final data = d.data();
                  final ts = parseTs(data['timestamp']);
                  if (ts == null) return null;
                  if (ts.isBefore(dateFrom) || !ts.isBefore(dateTo))
                    return null;
                  return {...data, 'timestamp': ts};
                })
                .whereType<Map<String, dynamic>>()
                .toList()
              ..sort((a, b) {
                final aT = a['timestamp'] as DateTime;
                final bT = b['timestamp'] as DateTime;
                return bT.compareTo(aT);
              });

        final pdf = await StudentReportsGenerator.generateBehaviorReport(
          schoolName: schoolName,
          violations: list,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        await Printing.layoutPdf(onLayout: (_) => pdf);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في إنشاء التقرير: $e')));
      }
    }
  }

  Future<void> _showReportOptions(
    BuildContext context,
    String action,
    String title,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر الفترة الزمنية للتقرير:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('اليوم'),
                  subtitle: const Text('عرض بيانات هذا اليوم فقط'),
                  onTap: () => Navigator.pop(context, 'today'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: const Text('آخر ٧ أيام'),
                  subtitle: const Text('متابعة النمط خلال الأسبوع الحالي'),
                  onTap: () => Navigator.pop(context, 'week'),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('تحديد فترة مخصصة'),
                  subtitle: const Text('اختيار فترة زمنية حسب احتياجك'),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    DateTime from = todayStart;
    DateTime to = todayEnd;

    if (choice == 'week') {
      from = todayStart.subtract(const Duration(days: 7));
    } else if (choice == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 1),
        initialDateRange: DateTimeRange(start: todayStart, end: todayEnd),
        helpText: 'اختيار الفترة الزمنية للتقرير',
        cancelText: 'إلغاء',
        confirmText: 'تأكيد',
      );

      if (range == null) return;
      from = DateTime(range.start.year, range.start.month, range.start.day);
      to = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
    }

    if (!mounted) return;
    await _handleAction(context, action, dateFrom: from, dateTo: to);
  }
}

class _StatChip {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);
}
