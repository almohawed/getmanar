import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/web_access_footer.dart';
import '../../academic/data/school_repository.dart';

// ---------------------------------------------------------------------------
// Stats Provider
// ---------------------------------------------------------------------------

final _stageDeputyStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, schoolId) async {
    if (schoolId.isEmpty) return {'students': 0, 'classes': 0, 'absent': 0, 'violations': 0};

    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      // Students count
      db
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .count()
          .get()
          .then((s) => s.count ?? 0)
          .catchError((_) => 0),

      // Classes count
      db
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .count()
          .get()
          .then((s) => s.count ?? 0)
          .catchError((_) => 0),

      // Today absent count
      db
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentAttendance')
          .where('date', isEqualTo: todayStr)
          .where('status', isEqualTo: 'absent')
          .count()
          .get()
          .then((s) => s.count ?? 0)
          .catchError((_) => 0),

      // Today violations count
      db
          .collection('Schools')
          .doc(schoolId)
          .collection('behavioral_violations')
          .where('date', isEqualTo: todayStr)
          .count()
          .get()
          .then((s) => s.count ?? 0)
          .catchError((_) => 0),
    ]);

    return {
      'students': results[0],
      'classes': results[1],
      'absent': results[2],
      'violations': results[3],
    };
  },
);

// ---------------------------------------------------------------------------
// Dashboard Widget
// ---------------------------------------------------------------------------

class StageDeputyDashboard extends ConsumerWidget {
  const StageDeputyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final statsAsync = ref.watch(_stageDeputyStatsProvider(schoolId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
                _StageDeputyHeader(user: user, ref: ref),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Welcome Banner ───────────────────────────────────
                      _WelcomeBanner(name: user?.name ?? 'وكيل المرحلة'),
                      SizedBox(height: 20.h),

                      // ── Stats Row ────────────────────────────────────────
                      statsAsync.when(
                        data: (stats) => _StatsRow(stats: stats),
                        loading: () => const _StatsRowLoading(),
                        error: (_, __) => _StatsRow(
                          stats: {'students': 0, 'classes': 0, 'absent': 0, 'violations': 0},
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // ── Action Sections ──────────────────────────────────
                      _buildSection(
                        context,
                        ref,
                        title: 'الاستئذانات',
                        color: Colors.amber.shade700,
                        icon: Icons.door_front_door_outlined,
                        items: [
                          _ActionItem(
                            icon: Icons.exit_to_app,
                            label: 'إذن خروج طالب',
                            route: '/student-exit-permission',
                          ),
                          _ActionItem(
                            icon: Icons.list_alt,
                            label: 'طلبات الاستئذان',
                            route: '/deputy-requests',
                          ),
                        ],
                      ),

                      _buildSection(
                        context,
                        ref,
                        title: 'الحضور والغياب',
                        color: Colors.teal.shade600,
                        icon: Icons.how_to_reg,
                        items: [
                          _ActionItem(
                            icon: Icons.fact_check_outlined,
                            label: 'الحضور والغياب',
                            route: '/school-attendance-dashboard',
                          ),
                          _ActionItem(
                            icon: Icons.timer_outlined,
                            label: 'كشف التأخر',
                            route: '/attendance',
                          ),
                        ],
                      ),

                      _buildSection(
                        context,
                        ref,
                        title: 'السلوك والانضباط',
                        color: Colors.deepOrange.shade600,
                        icon: Icons.gavel,
                        items: [
                          _ActionItem(
                            icon: Icons.inbox,
                            label: 'وارد المعلمين',
                            route: '/behavior-inbox',
                          ),
                          _ActionItem(
                            icon: Icons.remove_circle_outline,
                            label: 'رصد المخالفات',
                            route: '/behavior',
                          ),
                          _ActionItem(
                            icon: Icons.print_outlined,
                            label: 'لائحة السلوك',
                            route: '/print-notice',
                          ),
                        ],
                      ),

                      _buildSection(
                        context,
                        ref,
                        title: 'الجدول الدراسي',
                        color: const Color(0xFF6C63FF),
                        icon: Icons.calendar_month_outlined,
                        items: [
                          _ActionItem(
                            icon: Icons.auto_awesome_mosaic_outlined,
                            label: 'الجدول المدرسي',
                            route: '/smart-schedule',
                          ),
                          _ActionItem(
                            icon: Icons.pending_actions_outlined,
                            label: 'جدول الانتظار',
                            route: '/wait-management',
                          ),
                        ],
                      ),

                      _buildSection(
                        context,
                        ref,
                        title: 'التقارير',
                        color: Colors.green.shade600,
                        icon: Icons.bar_chart,
                        items: [
                          _ActionItem(
                            icon: Icons.event_available_outlined,
                            label: 'تقارير الحضور',
                            route: '/attendance-report',
                          ),
                          _ActionItem(
                            icon: Icons.assessment_outlined,
                            label: 'تقارير السلوك',
                            route: '/behavior-report',
                          ),
                        ],
                      ),

                      _buildSection(
                        context,
                        ref,
                        title: 'الإعدادات',
                        color: Colors.blueGrey.shade500,
                        icon: Icons.settings_outlined,
                        items: [
                          _ActionItem(
                            icon: Icons.settings,
                            label: 'الإعدادات',
                            route: '/settings',
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),
                      const WebAccessFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Color color,
    required IconData icon,
    required List<_ActionItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title, color, icon),
        _buildActionGrid(context, ref, items, color),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(color: color, width: 4.w),
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
            child: Icon(icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
              fontSize: 17.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    WidgetRef ref,
    List<_ActionItem> items,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) crossAxisCount = 3;
        if (constraints.maxWidth > 900) crossAxisCount = 4;

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
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildActionCard(
              context,
              ref,
              icon: item.icon,
              label: item.label,
              color: color,
              route: item.route,
              badge: item.badge,
            );
          },
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required Color color,
    required String route,
    int? badge,
  }) {
    return InkWell(
      onTap: () {
        try {
          context.push(route);
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر فتح "$label" حالياً'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(icon, color: color, size: 28.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (badge != null && badge > 0)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
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
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _StageDeputyHeader extends ConsumerWidget {
  const _StageDeputyHeader({required this.user, required this.ref});

  final dynamic user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final schoolId = user?.schoolId ?? '';
    final schoolAsync = watchRef.watch(schoolProvider(schoolId));
    final schoolName = schoolAsync.when(
      data: (school) => school?.name ?? 'المدرسة',
      loading: () => 'المدرسة',
      error: (_, __) => 'المدرسة',
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Row(
            children: [
              // School icon
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 14.w),
              // Title block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'وكيل المرحلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Logout button
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تسجيل الخروج'),
                      content: const Text('هل تريد تسجيل الخروج؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'خروج',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await watchRef
                        .read(authStateProvider.notifier)
                        .logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome Banner
// ---------------------------------------------------------------------------

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Row(
          children: [
            // Colored strip
            Container(
              width: 6.w,
              height: 80.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، $name',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6C63FF),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'نتمنى لك يوماً مثمراً في خدمة الطلاب والمعلمين',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 8.w),
              child: Icon(
                Icons.waving_hand_rounded,
                color: const Color(0xFF8B5CF6),
                size: 32.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final cards = [
          _StatCard(
            label: 'الطلاب',
            value: '${stats['students'] ?? 0}',
            icon: Icons.people_alt_outlined,
            color: Colors.teal.shade600,
          ),
          _StatCard(
            label: 'الفصول',
            value: '${stats['classes'] ?? 0}',
            icon: Icons.class_outlined,
            color: Colors.orange.shade600,
          ),
          _StatCard(
            label: 'الغياب اليوم',
            value: '${stats['absent'] ?? 0}',
            icon: Icons.person_off_outlined,
            color: Colors.red.shade500,
          ),
          _StatCard(
            label: 'المخالفات',
            value: '${stats['violations'] ?? 0}',
            icon: Icons.warning_amber_outlined,
            color: Colors.amber.shade700,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: cards.indexOf(c) < cards.length - 1 ? 8.w : 0,
                        ),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                SizedBox(width: 8.w),
                Expanded(child: cards[1]),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(child: cards[2]),
                SizedBox(width: 8.w),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRowLoading extends StatelessWidget {
  const _StatsRowLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final colors = [
          Colors.teal.shade600,
          Colors.orange.shade600,
          Colors.red.shade500,
          Colors.amber.shade700,
        ];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i < 3 ? 8.w : 0),
            child: Container(
              height: 72.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: colors[i].withOpacity(0.2)),
              ),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class for action items
// ---------------------------------------------------------------------------

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.route,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String route;
  final int? badge;
}
