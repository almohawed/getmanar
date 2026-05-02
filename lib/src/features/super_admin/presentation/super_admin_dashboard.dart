import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../data/super_admin_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import 'super_admin_settings_screen.dart';
import 'schools_list_screen.dart';
import 'system_statistics_screen.dart';
import 'subscriptions_management_screen.dart';
import 'active_schools_screen.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolRequestsAsync = ref.watch(pendingSchoolRequestsProvider);
    final schoolRequestsCount = schoolRequestsAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (e, s) => 0,
    );
    final userState = ref.watch(authStateProvider);
    final userName = userState.value?.name ?? 'Super Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          // ─── Hero AppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200.h,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E1A),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0D1B2A),
                          Color(0xFF1A237E),
                          Color(0xFF283593),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    top: -30,
                    left: -30,
                    child: Container(
                      width: 150.w,
                      height: 150.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                                  ),
                                  borderRadius: BorderRadius.circular(14.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3949AB).withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.admin_panel_settings,
                                    color: Colors.white, size: 26.sp),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'مرحباً، $userName',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 3.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.w, vertical: 3.h),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(
                                            color: Colors.amber.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        'Super Admin • إدارة النظام الكاملة',
                                        style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Logout
                              IconButton(
                                icon: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Icon(Icons.logout,
                                      color: Colors.white, size: 18.sp),
                                ),
                                onPressed: () => _confirmLogout(context, ref),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          // Stats row
                          if (schoolRequestsCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_active,
                                      color: Colors.red, size: 14.sp),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '$schoolRequestsCount طلب مدرسة بانتظار الموافقة',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Grid ─────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.all(16.w),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _buildCard(
                  context,
                  icon: Icons.verified_rounded,
                  label: 'المدارس المفعّلة',
                  subtitle: 'إدارة قسم الاشتراك',
                  gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ActiveSchoolsScreen())),
                ),
                _buildCard(
                  context,
                  icon: Icons.school_rounded,
                  label: 'المدارس المسجلة',
                  subtitle: 'عرض وإدارة المدارس',
                  gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SchoolsListScreen())),
                ),
                _buildCard(
                  context,
                  icon: Icons.manage_accounts_rounded,
                  label: 'إدارة الحسابات',
                  subtitle: 'المستخدمون العالميون',
                  gradient: const [Color(0xFFB71C1C), Color(0xFFE53935)],
                  onTap: () => context.push('/global-accounts'),
                ),
                _buildCard(
                  context,
                  icon: Icons.add_business_rounded,
                  label: 'إضافة مدرسة',
                  subtitle: 'تسجيل مدرسة جديدة',
                  gradient: const [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                  onTap: () => context.push('/add-school'),
                ),
                _buildCard(
                  context,
                  icon: Icons.domain_add_rounded,
                  label: 'طلبات المدارس',
                  subtitle: 'مراجعة وقبول الطلبات',
                  gradient: const [Color(0xFFAD1457), Color(0xFFE91E63)],
                  onTap: () => context.push('/school-requests-list'),
                  badge: schoolRequestsCount,
                ),
                _buildCard(
                  context,
                  icon: Icons.subscriptions_rounded,
                  label: 'الاشتراكات',
                  subtitle: 'إدارة باقات المدارس',
                  gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionsManagementScreen())),
                ),
                _buildCard(
                  context,
                  icon: Icons.campaign_rounded,
                  label: 'إرسال إعلانات',
                  subtitle: 'إعلانات لجميع المدارس',
                  gradient: const [Color(0xFFE65100), Color(0xFFF57C00)],
                  onTap: () => context.push('/announcements'),
                ),
                _buildCard(
                  context,
                  icon: Icons.analytics_rounded,
                  label: 'الإحصائيات',
                  subtitle: 'تقارير وبيانات النظام',
                  gradient: const [Color(0xFF1B5E20), Color(0xFF388E3C)],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SystemStatisticsScreen())),
                ),
                _buildCard(
                  context,
                  icon: Icons.settings_rounded,
                  label: 'الإعدادات',
                  subtitle: 'إعدادات النظام',
                  gradient: const [Color(0xFF263238), Color(0xFF455A64)],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SuperAdminSettingsScreen())),
                ),
              ]),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(context),
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1.15,
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 40.h)),
        ],
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 1200) return 5;
    if (w > 900) return 4;
    if (w > 600) return 3;
    return 2;
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradient[0].withValues(alpha: 0.85),
              gradient[1].withValues(alpha: 0.85),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24.sp),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Badge
            if (badge > 0)
              Positioned(
                top: 10.h,
                left: 10.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 6)
                    ],
                  ),
                  child: Text(
                    badge.toString(),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج',
            style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}
