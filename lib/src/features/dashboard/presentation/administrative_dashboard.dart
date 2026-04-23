import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../academic/data/school_repository.dart';
import '../../subscription/domain/subscription_logic.dart';
import '../../requests/data/permission_repository.dart';
import '../../requests/domain/permission_request.dart';
import '../../academic/presentation/school_location_screen.dart';
import '../../maintenance/data/firestore_maintenance_repository.dart';
import 'web_access_footer.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/welcome_banner.dart';
import '../../circulars/presentation/circulars_providers.dart';

import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';

class AdministrativeDashboard extends ConsumerWidget {
  const AdministrativeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final user = ref.watch(authStateProvider).value;
    final schoolAsync = ref.watch(schoolProvider(user?.schoolId ?? ''));
    final approvedRequests = requests
        .where((r) => r.status == PermissionRequestStatus.approved)
        .toList();
    final openCriticalAsync = ref.watch(openCriticalCountProvider);
    final overdueMaintenanceAsync = ref.watch(overdueCountProvider);
    final unreadCirculars = ref.watch(unreadCircularsCountProvider).value ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECEFF1), Color(0xFFCFD8DC)], // Blue Grey
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(user),
            SizedBox(height: 24.h),
            _buildStatsRow(
              context,
              requests,
              approvedRequests,
              openCriticalAsync,
              overdueMaintenanceAsync,
            ),
            SizedBox(height: 32.h),
            _buildActionGrid(context, schoolAsync.value, unreadCirculars),
            SizedBox(height: 32.h),
            schoolAsync.when(
              data: (school) {
                if (school == null ||
                    !school.hasAccess(AppFeature.digitalPermission)) {
                  return const SizedBox.shrink();
                }
                return _buildApprovedPermissionsList(approvedRequests);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),
            SizedBox(height: 32.h),
            _buildRecentFilesList(),
            SizedBox(height: 32.h),
            const WebAccessFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Icon(Icons.folder_shared, size: 64.sp, color: Colors.blueGrey),
              SizedBox(height: 12.h),
              Text(
                'المكتب الإداري',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        // Welcome Banner
        WelcomeBanner(userName: user?.name ?? 'الإداري'),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    List<PermissionRequest> allRequests,
    List<PermissionRequest> approvedRequests,
    AsyncValue<int> openCriticalAsync,
    AsyncValue<int> overdueMaintenanceAsync,
  ) {
    final now = DateTime.now();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final totalToday = allRequests
        .where((r) => isSameDay(r.createdAt, now))
        .length;
    final approvedToday = approvedRequests
        .where((r) => r.decidedAt != null && isSameDay(r.decidedAt!, now))
        .length;
    final pendingCount = allRequests
        .where((r) => r.status == PermissionRequestStatus.pending)
        .length;
    final rejectedCount = allRequests
        .where((r) => r.status == PermissionRequestStatus.rejected)
        .length;

    String _asyncValueToString(AsyncValue<int> value) {
      return value.when(
        data: (v) => v.toString(),
        loading: () => '...',
        error: (_, __) => '-',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            context,
            title: 'طلبات استئذان اليوم',
            value: totalToday.toString(),
            color: Colors.indigo,
            icon: Icons.today,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context,
            title: 'موافقات اليوم',
            value: approvedToday.toString(),
            color: Colors.green,
            icon: Icons.check_circle,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context,
            title: 'معلّقة الآن',
            value: pendingCount.toString(),
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context,
            title: 'مرفوضة',
            value: rejectedCount.toString(),
            color: Colors.red,
            icon: Icons.cancel,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context,
            title: 'بلاغات صيانة حرجة مفتوحة',
            value: _asyncValueToString(openCriticalAsync),
            color: Colors.deepPurple,
            icon: Icons.report_problem,
          ),
          SizedBox(width: 12.w),
          _buildStatCard(
            context,
            title: 'بلاغات صيانة متأخرة',
            value: _asyncValueToString(overdueMaintenanceAsync),
            color: Colors.brown,
            icon: Icons.timer_off,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 190.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    School? school,
    int unreadCirculars,
  ) {
    bool isLocked(AppFeature feature) =>
        school != null && !school.hasAccess(feature);

    final items = [
      {
        'label': 'الصادر',
        'icon': Icons.outbox,
        'color': const Color(0xFF6D5DF6),
        'onTap': () => context.push('/mail-management'),
        'locked': isLocked(AppFeature.adminHierarchy),
      },
      {
        'label': 'الوارد',
        'icon': Icons.inbox,
        'color': const Color(0xFF4ECDC4),
        'onTap': () => context.push('/mail-management'),
        'locked': isLocked(AppFeature.adminHierarchy),
      },
      {
        'label': 'أرشيف الملفات',
        'icon': Icons.archive,
        'color': const Color(0xFFFFC857),
        'onTap': () => context.push('/circulars-archive'),
        'locked': isLocked(AppFeature.adminHierarchy),
      },
      {
        'label': unreadCirculars > 0
            ? 'التعاميم ($unreadCirculars)'
            : 'التعاميم',
        'icon': Icons.announcement,
        'color': const Color(0xFFEE6352),
        'onTap': () => context.push('/circulars/inbox'),
        'locked': isLocked(AppFeature.adminHierarchy),
      },
      {
        'label': 'موقع المدرسة',
        'icon': Icons.location_on,
        'color': const Color(0xFF3F88C5),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SchoolLocationScreen()),
        ),
        'locked': false,
      },
      {
        'label': 'الإعدادات',
        'icon': Icons.settings,
        'color': const Color(0xFF687980),
        'onTap': () => context.push('/settings'),
        'locked': false,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260.w,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 2.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildActionCard(
          context,
          item['label'] as String,
          item['icon'] as IconData,
          item['color'] as Color,
          item['onTap'] as VoidCallback,
          isLocked: item['locked'] as bool,
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: isLocked
          ? () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('خاصية مقيدة'),
                  content: const Text(
                    'هذه الخاصية غير متاحة في باقة المدرسة الحالية.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              );
            }
          : onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            if (isLocked)
              Positioned(
                left: 10.w,
                top: 10.h,
                child: Icon(Icons.lock, color: Colors.grey, size: 20.sp),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isLocked ? Colors.grey : color,
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: isLocked ? Colors.grey : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedPermissionsList(List<PermissionRequest> requests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أذونات الاستئذان المعتمدة',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        if (requests.isEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Center(child: Text('لا توجد أذونات معتمدة حديثاً')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          req.studentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(req.decidedAt ?? DateTime.now()),
                          style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'السبب: ${req.reason}',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentFilesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أحدث الملفات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        _buildFileItem('تعميم إداري رقم 55', 'منذ ساعة', Icons.picture_as_pdf),
        SizedBox(height: 12.h),
        _buildFileItem('قائمة الغياب اليومي', 'منذ 3 ساعات', Icons.table_chart),
      ],
    );
  }

  Widget _buildFileItem(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.download, color: Colors.grey),
      ),
    );
  }
}
