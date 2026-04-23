import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../dashboard/presentation/web_access_footer.dart';
import '../../dashboard/presentation/dashboard_palette.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import '../../common/services/audit_service.dart';
import '../../maintenance/presentation/report_maintenance_screen.dart';
import '../../maintenance/data/firestore_maintenance_repository.dart'; // Import Maintenance Repository
import '../../admin_tasks/presentation/admin_task_providers.dart'; // Import Admin Tasks
import '../../school/presentation/screens/school_modules.dart';
import '../../dashboard/presentation/widgets/qr_scanner_fab.dart';

class SchoolAffairsDashboard extends ConsumerStatefulWidget {
  const SchoolAffairsDashboard({super.key});

  @override
  ConsumerState<SchoolAffairsDashboard> createState() =>
      _SchoolAffairsDashboardState();
}

class _SchoolAffairsDashboardState
    extends ConsumerState<SchoolAffairsDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'view_dashboard',
            description: 'User viewed School Affairs Dashboard',
            metadata: {'section': 'school_affairs'},
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

    // Ops Radar Data  
    final criticalCount = ref.watch(openCriticalCountProvider).when(
      data: (value) => value,
      loading: () => 0,
      error: (_, __) => 0,
    );
    final overdueCount = ref.watch(overdueCountProvider).when(
      data: (value) => value,
      loading: () => 0,
      error: (_, __) => 0,
    );
    final adminTasks = ref.watch(adminTasksStreamProvider).when(
      data: (value) => value,
      loading: () => [],
      error: (_, __) => [],
    );
    final myAdminTasksCount = adminTasks
        .where((t) => t.assignedToId == user?.id && t.status.name != 'done')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Stack(
            children: [
              Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(hasDelegatedAdmin),
              const SizedBox(height: 24),
              WelcomeBanner(
                userName: user?.name ?? 'وكيل الشؤون المدرسية',
                gradient: DashboardPalette.bannerGradient('deputySchool'),
              ),
              const SizedBox(height: 16),

              // Ops Radar
              _buildOpsRadar(criticalCount, overdueCount, myAdminTasksCount),
              const SizedBox(height: 24),

              _buildSection(
                context,
                title: 'الإدارة التشغيلية',
                color: Colors.teal.shade800,
                items: [
                  {
                    'icon': Icons.move_to_inbox,
                    'title': 'الصادر والوارد',
                    'route': '/mail-management',
                  },
                  {
                    'icon': Icons.notifications,
                    'title': 'أرشفة التعاميم',
                    'route': '/circulars-archive',
                  },
                  {
                    'icon': Icons.how_to_reg,
                    'title': 'متابعة حضور الموظفين',
                    'route': '/staff-attendance',
                  },
                  {
                    'icon': Icons.draw,
                    'title': 'سجل التوقيعات',
                    'route': '/signatures-log',
                  },
                ],
              ),

              _buildSection(
                context,
                title: 'الصيانة',
                color: Colors.orange.shade800,
                items: [
                  {
                    'icon': Icons.build,
                    'title': 'تسجيل بلاغ صيانة',
                    'route': '/report-maintenance',
                  },
                  {
                    'icon': Icons.priority_high,
                    'title': 'تحديد الأولوية',
                    'route': '/maintenance-priority',
                  },
                  {
                    'icon': Icons.track_changes,
                    'title': 'تتبع الحالة',
                    'route': '/maintenance-status',
                  },
                  {
                    'icon': Icons.history,
                    'title': 'سجل الأعطال',
                    'route': '/fault-log',
                  },
                ],
              ),

              _buildSection(
                context,
                title: 'الأمن والسلامة',
                color: Colors.red.shade800,
                items: [
                  {
                    'icon': Icons.run_circle,
                    'title': 'خطة الإخلاء',
                    'route': '/evacuation-plan',
                  },
                  {
                    'icon': Icons.timer,
                    'title': 'سجل التجارب',
                    'route': '/drills-log',
                  },
                  {
                    'icon': Icons.fire_extinguisher,
                    'title': 'فحص الطفايات',
                    'route': '/extinguishers-check',
                  },
                  {
                    'icon': Icons.meeting_room,
                    'title': 'مخارج الطوارئ',
                    'route': '/emergency-exits',
                  },
                ],
              ),

              _buildSection(
                context,
                title: 'المقصف والخدمات',
                color: Colors.blue.shade800,
                items: [
                  {
                    'icon': Icons.restaurant,
                    'title': 'اشتراطات الصحة',
                    'route': '/health-rules',
                  },
                  {
                    'icon': Icons.assignment_late,
                    'title': 'ملاحظات رقابية',
                    'route': '/observations-log',
                  },
                ],
              ),

              _buildSection(
                context,
                title: 'العهد والمستودع',
                color: Colors.brown.shade800,
                items: [
                  {
                    'icon': Icons.inventory,
                    'title': 'جرد إلكتروني',
                    'route': '/inventory-check',
                  },
                  {
                    'icon': Icons.list_alt,
                    'title': 'طلب مواد',
                    'route': '/material-request',
                  },
                ],
              ),

              const SizedBox(height: 32),
              const WebAccessFooter(),
            ],
          ),
          
          // الزر العائم
          Positioned(
            bottom: 16,
            left: 16,
            child: const QrScannerFab(),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildOpsRadar(
    int criticalCount,
    int overdueCount,
    int adminTasksCount,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرادار التشغيلي (Ops Radar)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRadarItem(
                  'بلاغات حرجة',
                  criticalCount.toString(),
                  criticalCount > 0 ? Colors.red : Colors.green,
                  Icons.warning,
                ),
                const SizedBox(width: 16),
                _buildRadarItem(
                  'بلاغات متأخرة',
                  overdueCount.toString(),
                  overdueCount > 0 ? Colors.orange : Colors.grey,
                  Icons.timer_off,
                ),
                const SizedBox(width: 16),
                _buildRadarItem(
                  'مهامي الإدارية',
                  adminTasksCount.toString(),
                  Colors.blue,
                  Icons.assignment_ind,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
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
        Container(
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
        ),
        LayoutBuilder(
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
                return _buildActionCard(
                  context,
                  icon: item['icon'] as IconData,
                  label: item['title'] as String,
                  color: color,
                  route: item['route'] as String,
                  badgeCount: _badgeCountForRoute(item['route'] as String),
                );
              },
            );
          },
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  int _badgeCountForRoute(String route) {
    if (route == '/mail-management') {
      return ref.watch(mailOpenCountProvider);
    }
    if (route == '/circulars-archive') {
      return ref.watch(unsignedCircularsCountProvider);
    }
    if (route == '/staff-attendance') {
      return ref.watch(staffAttendanceIssuesCountProvider);
    }
    if (route == '/report-maintenance' || route == '/maintenance-priority') {
      return ref.watch(openCriticalCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/maintenance-status' || route == '/fault-log') {
      return ref.watch(overdueCountProvider).when(
        data: (value) => value,
        loading: () => 0,
        error: (_, __) => 0,
      );
    }
    if (route == '/evacuation-plan') {
      return ref.watch(evacuationPlanMissingFlagProvider);
    }
    if (route == '/drills-log') {
      return ref.watch(safetyDrillsOverdueFlagProvider);
    }
    if (route == '/extinguishers-check') {
      return ref.watch(expiredExtinguishersCountProvider);
    }
    if (route == '/emergency-exits') {
      return ref.watch(blockedExitsCountProvider);
    }
    if (route == '/health-rules') {
      return ref.watch(healthIssuesCountProvider);
    }
    if (route == '/observations-log') {
      return ref.watch(openObservationsCountProvider);
    }
    if (route == '/inventory-check') {
      return ref.watch(lowStockCountProvider);
    }
    if (route == '/material-request') {
      return ref.watch(openMaterialRequestsCountProvider);
    }
    return 0;
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String route,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: () {
        ref
            .read(auditServiceProvider)
            .logAction(
              action: 'click_menu_item',
              description: 'Clicked on $label',
              metadata: {'route': route},
            );

        if (route == '/report-maintenance') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportMaintenanceScreen(),
            ),
          );
        } else if (route.startsWith('/')) {
          try {
            context.push(route);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تعذر فتح قسم "$label" حالياً، يرجى مراجعة مسؤول النظام.',
                ),
              ),
            );
          }
        }
      },
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
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(2.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 64.sp,
                ),
                SizedBox(height: 8.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
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
      ),
    );
  }

  Widget _buildHeader(bool hasDelegatedAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DashboardPalette.headerGradient('deputySchool'),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'وكيل الشؤون المدرسية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasDelegatedAdmin)
                PopupMenuButton<String>(
                  tooltip: 'خيارات اللوحة',
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6.w),
                        const Text(
                          'لوحة المدير',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'admin_dashboard') {
                      context.push('/admin-dashboard');
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'admin_dashboard',
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.indigo,
                          ),
                          SizedBox(width: 8),
                          Text('التحول إلى لوحة مدير المدرسة'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'إدارة المرافق والصيانة والمستودعات',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
