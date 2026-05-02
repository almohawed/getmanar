import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../academic/data/school_repository.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import '../../dashboard/presentation/dashboard_palette.dart';
import '../../../core/domain/models/user.dart';
import '../application/permission_service.dart';
import '../../assignments/data/firestore_assignments_repository.dart';
import '../domain/services/administrative_report_service.dart';
import 'admin_dashboard_providers.dart';
import '../../../core/domain/models/school.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Permission Service
    ref.watch(permissionServiceProvider);

    // Check user role
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;
    final isDeputy = user?.role == UserRole.deputy;
    final isAcademicDeputy =
        user?.role == UserRole.deputy && user?.deputyType == 'academic';

    // Fetch School Data for Header
    final schoolAsync = ref.watch(schoolProvider(user?.schoolId ?? ''));
    final school = schoolAsync.value;

    // Fetch Manager Name
    final managerNameAsync = ref.watch(
      schoolManagerNameProvider((
        userId: school?.ownerId ?? '',
        schoolId: school?.id ?? '',
      )),
    );

    // Watch new executive providers
    final schoolStatus =
        ref.watch(schoolStatusProvider).value ?? SchoolStatusMetrics();
    final actionNeeded = ref.watch(actionNeededProvider).value ?? [];
    final disciplineIndex = ref.watch(adminDisciplineIndexProvider);

    return Container(
      color: const Color(0xFFF0F2F8),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header فاخر
            _buildHeader(context, schoolAsync, isDeputy),
            SizedBox(height: 20.h),

            // Welcome Banner
            WelcomeBanner(
              userName: user?.name ?? 'المدير',
              gradient: DashboardPalette.bannerGradient('admin'),
              role: 'admin',
              trailing: _AdminAssignmentChips(userId: user?.id ?? ''),
            ),

            // Delegated Mode Banner
            if (isAcademicDeputy) ...[
              SizedBox(height: 16.h),
              _buildDelegatedBanner(context, user, managerNameAsync),
            ],

            SizedBox(height: 20.h),

            // 1. School Status Today
            _buildSchoolStatusBar(schoolStatus),
            SizedBox(height: 20.h),

            // 2. Action Needed Now
            if (actionNeeded.isNotEmpty) ...[
              _buildActionNeededSection(actionNeeded),
              SizedBox(height: 20.h),
            ],

            // 3. Admin Discipline Index
            _buildDisciplineIndexCard(disciplineIndex),
            SizedBox(height: 20.h),

            // 4. Executive Report Button
            _buildExecutiveReportButton(
              context,
              ref,
              school?.name ?? 'المدرسة',
              user?.name ?? 'المدير',
            ),
            SizedBox(height: 20.h),

            // 5. Sections
            _buildDashboardSections(context, ref),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<School?> schoolAsync,
    bool isDeputy,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // شعار المدرسة
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28.r,
                  backgroundColor: Colors.white,
                  child: Image.asset('images/mylogo.png', width: 44.w, height: 44.h),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    schoolAsync.when(
                      data: (school) => Text(
                        school?.name ?? 'لوحة التحكم الإدارية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => Text(
                        'لوحة التحكم الإدارية',
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.amber.shade300, size: 14.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'مدير المدرسة',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isDeputy)
                PopupMenuButton<String>(
                  tooltip: 'خيارات اللوحة',
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: Colors.white, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text('لوحة الوكيل', style: TextStyle(color: Colors.white, fontSize: 11.sp)),
                        Icon(Icons.arrow_drop_down, color: Colors.white, size: 18.sp),
                      ],
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'deputy_dashboard') {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                      else context.go('/academic-affairs');
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: 'deputy_dashboard',
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('العودة إلى لوحة الوكيل'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16.h),
          // شريط مؤشرات سريعة
          Row(
            children: [
              _buildHeaderStat(Icons.school, 'المدرسة', 'نشطة', Colors.green.shade300),
              _buildHeaderDivider(),
              _buildHeaderStat(Icons.verified_user, 'الصلاحية', 'كاملة', Colors.amber.shade300),
              _buildHeaderDivider(),
              _buildHeaderStat(Icons.star, 'المستوى', 'مدير', Colors.blue.shade200),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16.sp),
          SizedBox(width: 6.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Colors.white60, fontSize: 10.sp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDivider() {
    return Container(width: 1, height: 30.h, color: Colors.white.withOpacity(0.2));
  }

  Widget _buildDelegatedBanner(
    BuildContext context,
    User? user,
    AsyncValue<String?> managerNameAsync,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Colors.amber.shade800),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنت تعمل بصلاحيات مفوضة من المدير',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 14.sp,
                  ),
                ),
                managerNameAsync.when(
                  data: (name) => Text(
                    'المدير المفوض: ${name ?? 'المدير'}',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 12.sp,
                    ),
                  ),
                  loading: () => Text(
                    'جاري تحميل البيانات...',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 12.sp,
                    ),
                  ),
                  error: (_, __) => Text(
                    'المدير المفوض: غير معروف',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'الأقسام المتاحة لك:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                    color: Colors.amber.shade900,
                  ),
                ),
                SizedBox(height: 4.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children:
                      (user?.delegatedPermissions?.keys.map((key) {
                        final sectionNames = {
                          'leadership': 'القيادة',
                          'classes': 'الفصول',
                          'students': 'الطلاب',
                          'teachers': 'المعلمين',
                          'administrative': 'التكليفات الإدارية',
                          'schedule': 'الجداول',
                          'exams': 'الاختبارات',
                          'roles': 'الصلاحيات',
                          'reports': 'التقارير',
                          'settings': 'الإعدادات',
                        };
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            sectionNames[key] ?? key,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        );
                      }).toList() ??
                      []),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolStatusBar(SchoolStatusMetrics status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حالة المدرسة اليوم',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 120, // Increased height for better card layout
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildStatusCard(
                'وارد اليوم',
                status.incomingToday.toString(),
                Colors.blue,
                Icons.call_received,
              ),
              _buildStatusCard(
                'صادر اليوم',
                status.outgoingToday.toString(),
                Colors.green,
                Icons.call_made,
              ),
              _buildStatusCard(
                'معاملات معلقة',
                status.pendingTransactions.toString(),
                Colors.orange,
                Icons.hourglass_empty,
              ),
              _buildStatusCard(
                'متأخرة',
                status.delayedTransactions.toString(),
                Colors.red,
                Icons.warning,
              ),
              _buildStatusCard(
                'بلاغات صيانة',
                status.openMaintenanceReports.toString(),
                Colors.brown,
                Icons.build,
              ),
              _buildStatusCard(
                'طلبات اعتماد',
                status.requestsAwaitingApproval.toString(),
                Colors.purple,
                Icons.approval,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 150.w,
      margin: EdgeInsets.only(left: 12.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, color.withOpacity(0.04)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: color, size: 18.sp),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionNeededSection(List<ActionNeededItem> items) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notification_important, color: Colors.red.shade700),
              SizedBox(width: 8.w),
              Text(
                'يحتاج إجراء الآن',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${items.length} مهام',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...items
              .take(3)
              .map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8.sp, color: Colors.red),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.red.shade700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12.sp,
                        color: Colors.red.shade300,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildDisciplineIndexCard(AdminDisciplineIndex index) {
    final color = index.score >= 80
        ? Colors.green
        : (index.score >= 50 ? Colors.orange : Colors.red);
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D1B4B), const Color(0xFF1A237E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.analytics_rounded, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مؤشر الانضباط الإداري',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'يقيس كفاءة وسرعة إنجاز المعاملات',
                      style: TextStyle(fontSize: 11.sp, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64.w,
                height: 64.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
                ),
                child: Text(
                  '${index.score}',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIndexMetric('نسبة الإنجاز (24س)', '${index.closureRate24h.toStringAsFixed(0)}%', Colors.blue.shade200),
                Container(width: 1, height: 30.h, color: Colors.white24),
                _buildIndexMetric('متوسط وقت المعالجة', '${index.avgProcessingTimeHours}h', Colors.purple.shade200),
                Container(width: 1, height: 30.h, color: Colors.white24),
                _buildIndexMetric('رضا المستفيدين', '${index.beneficiarySatisfaction}/5', Colors.amber.shade300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.white60), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildExecutiveReportButton(
    BuildContext context,
    WidgetRef ref,
    String schoolName,
    String managerName,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () async {
            final index = ref.read(adminDisciplineIndexProvider);
            final status = ref.read(schoolStatusProvider).value ?? SchoolStatusMetrics();
            final service = AdministrativeReportService();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('جاري إعداد التقرير الإداري...')),
            );
            try {
              await service.generateAndOpenReport(
                schoolName: schoolName,
                managerName: managerName,
                totalTransactions: status.incomingToday + status.outgoingToday,
                avgProcessingTime: index.avgProcessingTimeHours,
                completionRate: index.closureRate24h,
                keyChallenges: [
                  'تأخر في اعتماد طلبات الصيانة',
                  'تراكم المعاملات الصادرة',
                  'نقص في توثيق الشواهد للإجراءات',
                ],
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('حدث خطأ أثناء تصدير التقرير: $e')),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: Colors.amber.shade300, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تصدير التقرير التنفيذي الإداري',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'تقرير PDF شامل بمؤشرات الأداء',
                      style: TextStyle(color: Colors.white60, fontSize: 11.sp),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSections(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).value;
    return Column(
      children: [
        _buildSectionGroup(
          context,
          'القيادة المدرسية',
          [
            _NavItem(
              'الخلاصة الاستراتيجية',
              Icons.auto_awesome_motion,
              Colors.deepPurple,
              '/smart-placeholder',
              extra: {
                'title': 'الحالة الاستراتيجية للمدرسة',
                'color': Colors.deepPurple,
                'icon': Icons.auto_awesome_motion,
              },
            ),
            _NavItem(
              'إطار الحوكمة والتنظيم',
              Icons.account_tree_outlined,
              Colors.indigo,
              '/governance-framework',
            ),
            _NavItem(
              'التقارير',
              Icons.bar_chart,
              Colors.indigo,
              '/smart-placeholder',
              extra: {'title': 'مركز التقارير والتحليل'},
            ),
            _NavItem(
              'الخطط التطويرية',
              Icons.trending_up,
              Colors.blue,
              '/development-plans',
            ),
            _NavItem(
              'الدليل الإجرائي',
              Icons.menu_book,
              Colors.teal,
              '/school-guide',
            ),
            _NavItem(
              'الاجتماعات',
              Icons.groups,
              Colors.teal,
              '/smart-placeholder',
              extra: {'title': 'سجل الاجتماعات واللجان المدرسية'},
            ),
          ],
          subtitle: 'اللجان المدرسية – إدارة المخاطر – خطط التحسين – التقارير',
        ),
        _buildSectionGroup(
          context,
          'الشؤون الأكاديمية',
          [
            _NavItem(
              'الطلاب',
              Icons.people_alt,
              Colors.blue.shade700,
              '/students-list',
            ),
            _NavItem(
              'ملصقات تعريف الطلاب',
              Icons.qr_code_2,
              Colors.indigo.shade700,
              '/student-barcodes',
            ),
            _NavItem(
              'أولياء الأمور',
              Icons.family_restroom,
              Colors.purple.shade700,
              '/parents',
            ),
            _NavItem(
              'المعلمين',
              Icons.person_pin,
              Colors.green.shade700,
              '/teachers-list',
            ),
            _NavItem(
              'الفصول',
              Icons.class_,
              Colors.orange.shade700,
              '/classes-list',
            ),
            _NavItem(
              'الجدول المدرسي',
              Icons.auto_awesome,
              Colors.indigo.shade700,
              '/smart-schedule',
            ),
            _NavItem(
              'الإشراف والمناوبة',
              Icons.supervisor_account_rounded,
              const Color(0xFF0D47A1),
              '/supervision-duty',
            ),
            _NavItem(
              'الاختبارات',
              Icons.assignment,
              Colors.red.shade700,
              '/smart-exams',
            ),
          ],
          subtitle: 'نواتج التعلم – تحليل النتائج – خطط التحسين',
        ),
        _buildSectionGroup(context, 'شؤون الطلاب', [
          _NavItem(
            'الحضور والغياب',
            Icons.fact_check,
            Colors.teal,
            '/school-attendance-dashboard', // Updated path
            extra: {'title': 'تحليل الحضور والانضباط'},
          ),
          _NavItem('السلوك والمواظبة', Icons.gavel, Colors.orange, '/behavior'),
          _NavItem(
            'التوجيه الطلابي',
            Icons.psychology,
            Colors.purple,
            '/counselor-dashboard',
          ),
          _NavItem(
            'النشاط الطلابي',
            Icons.local_activity,
            Colors.teal,
            '/activity-dashboard',
          ),
          _NavItem(
            'الصحة المدرسية',
            Icons.health_and_safety,
            Colors.cyan,
            '/health-dashboard',
          ),
        ]),
        _buildSectionGroup(
          context,
          'الشؤون الإدارية',
          [
            _NavItem('الموظفين', Icons.badge, Colors.indigo, '/staff-list'),
            _NavItem(
              'التكليفات الإدارية',
              Icons.assignment_ind,
              Colors.blue,
              '/admin-tasks',
            ),
            _NavItem(
              'الصيانة',
              Icons.build,
              Colors.brown,
              '/smart-placeholder',
              extra: {'title': 'مركز عمليات الصيانة'},
            ),
            _NavItem(
              'العهد',
              Icons.inventory,
              Colors.blueGrey,
              '/smart-placeholder',
              extra: {'title': 'إدارة العهد والممتلكات'},
            ),
            _NavItem(
              'النقل المدرسي',
              Icons.directions_bus,
              Colors.yellow.shade800,
              '/smart-placeholder',
              extra: {'title': 'مراقبة النقل والأسطول'},
            ),
            _NavItem(
              'الأمن والسلامة',
              Icons.security,
              Colors.red,
              '/safety-dashboard',
            ),
          ],
          subtitle: 'الأمن والسلامة – السجلات النظامية – المتابعة',
        ),
        _buildSectionGroup(context, 'التواصل والإعلام', [
          _NavItem(
            'الوارد',
            Icons.inbox,
            Colors.green,
            '/incoming-mail',
            extra: {
              'schoolId': user?.schoolId,
              'userId': user?.id,
              'userName': user?.name,
            },
          ),
          _NavItem(
            'الصادر',
            Icons.outbox,
            Colors.blue,
            '/smart-placeholder',
            extra: {
              'title': 'سجل الصادر الرقمي',
              'schoolId': user?.schoolId,
              'userName': user?.name,
              'userRole': user?.role.name,
            },
          ),
          _NavItem('التعاميم', Icons.campaign, Colors.orange, '/circulars'),
          _NavItem(
            'الإعلانات',
            Icons.notifications_active,
            Colors.amber,
            '/smart-placeholder',
            extra: {'title': 'مركز الإعلانات والاتصال'},
          ),
        ]),
        _buildSectionGroup(context, 'خدمة الرسائل SMS', [
          _NavItem('إعدادات SMS', Icons.settings_cell, Colors.teal, '/admin/sms-settings'),
          _NavItem('سجل الرسائل', Icons.history, Colors.blue, '/deputy-sms'),
        ]),
        _buildSectionGroup(context, 'الإعدادات', [
          _NavItem('إعدادات المدرسة', Icons.settings, Colors.grey, '/settings'),
          _NavItem('موقع المدرسة', Icons.location_on, const Color(0xFF00897B), '/school-location'),
          _NavItem(
            'الصلاحيات',
            Icons.lock_person,
            Colors.blueGrey,
            '/permissions-dashboard',
          ),
          _NavItem(
            'الاشتراك',
            Icons.card_membership,
            Colors.amber,
            '/subscription-plans',
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionGroup(
    BuildContext context,
    String title,
    List<_NavItem> items, {
    String? subtitle,
  }) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final sectionColors = {
      'القيادة المدرسية': const Color(0xFF4527A0),
      'الشؤون الأكاديمية': const Color(0xFF1565C0),
      'شؤون الطلاب': const Color(0xFF00695C),
      'الشؤون الإدارية': const Color(0xFF37474F),
      'التواصل والإعلام': const Color(0xFFE65100),
      'خدمة الرسائل SMS': const Color(0xFF00838F),
      'الإعدادات': const Color(0xFF546E7A),
    };
    final sectionIcons = {
      'القيادة المدرسية': Icons.auto_awesome_motion,
      'الشؤون الأكاديمية': Icons.school_rounded,
      'شؤون الطلاب': Icons.people_alt_rounded,
      'الشؤون الإدارية': Icons.business_center_rounded,
      'التواصل والإعلام': Icons.campaign_rounded,
      'خدمة الرسائل SMS': Icons.sms_rounded,
      'الإعدادات': Icons.settings_rounded,
    };
    final sectionColor = sectionColors[title] ?? const Color(0xFF1A237E);
    final sectionIcon = sectionIcons[title] ?? Icons.folder_special;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 14.h, top: 6.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [sectionColor.withOpacity(0.08), sectionColor.withOpacity(0.02)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border(right: BorderSide(color: sectionColor, width: 4.w)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [BoxShadow(color: sectionColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(sectionIcon, color: Colors.white, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: sectionColor, letterSpacing: 0.3),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(subtitle, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: sectionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text('${items.length}', style: TextStyle(color: sectionColor, fontSize: 12.sp, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isWeb ? 150 : 150.w,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildNavCard(context, item.title, item.icon, item.color, item.route, extra: item.extra);
          },
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildNavCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route, {
    Map<String, dynamic>? extra,
  }) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    return InkWell(
      onTap: () {
        final implementedRoutes = [
          '/students-list', '/teachers-list', '/classes-list',
          '/schedule-management', '/smart-schedule', '/assign-subjects',
          '/admin-tasks', '/staff-list', '/admin-assignments', '/smart-exams',
          '/parents', '/maintenance-requests', '/school-guide',
          '/activity-dashboard', '/counselor-dashboard', '/health-dashboard',
          '/safety-dashboard', '/attendance', '/behavior', '/settings',
          '/school-location',
          '/code-management', '/governance-framework', '/incoming-mail',
          '/circulars', '/circulars/create', '/school-attendance-dashboard',
          '/development-plans', '/permissions-dashboard', '/subscription-plans',
          '/student-barcodes', '/admin/sms-settings', '/deputy-sms',
          '/supervision-duty',
        ];
        if (implementedRoutes.contains(route)) {
          context.push(route, extra: extra);
        } else {
          context.push('/smart-placeholder', extra: extra ?? {'title': title, 'color': color, 'icon': icon});
        }
      },
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(isWeb ? 10 : 10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isWeb ? 10 : 10.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.06)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: isWeb ? 24 : 22.sp),
            ),
            SizedBox(height: isWeb ? 8 : 8.h),
            Text(
              title,
              style: TextStyle(fontSize: isWeb ? 12 : 12.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final Map<String, dynamic>? extra;

  _NavItem(this.title, this.icon, this.color, this.route, {this.extra});
}

class _AdminAssignmentChips extends StatelessWidget {
  final String userId;
  const _AdminAssignmentChips({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final assignmentsAsync = ref.watch(teacherAssignmentsProvider(userId));

        return assignmentsAsync.when(
          data: (assignments) {
            if (assignments.isEmpty) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: assignments.take(2).map((assignment) {
                return Container(
                  margin: EdgeInsets.only(left: 4.w),
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    assignment.title,
                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
}
