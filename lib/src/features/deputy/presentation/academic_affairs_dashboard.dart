import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../dashboard/presentation/web_access_footer.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import '../../dashboard/presentation/dashboard_palette.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../common/services/audit_service.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/data/school_repository.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../admin/data/mock_staff_repository.dart';
import '../../../core/domain/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../distinguished_students/presentation/distinguished_list_widget.dart';
import 'widgets/academic_executive_summary_card.dart';
import '../../behavior/presentation/behavior_controller.dart';

class AcademicAffairsDashboard extends ConsumerStatefulWidget {
  const AcademicAffairsDashboard({super.key});

  @override
  ConsumerState<AcademicAffairsDashboard> createState() =>
      _AcademicAffairsDashboardState();
}

class _AcademicAffairsDashboardState
    extends ConsumerState<AcademicAffairsDashboard> {
  bool _isPresentationMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'view_dashboard',
            description: 'User viewed Academic Affairs Dashboard',
            metadata: {'section': 'academic_affairs'},
          );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    bool hasDelegatedAdmin,
    String schoolName,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: DashboardPalette.headerGradient('deputyAcademic'),
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
                      Icons.menu_book,
                      color: Colors.white,
                      size: 26.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (schoolName.isNotEmpty) ...[
                        Text(
                          schoolName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                      ],
                      Text(
                        _isPresentationMode
                            ? 'تقرير الأداء المؤسسي'
                            : 'وكيل الشؤون التعليمية',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Presentation Mode Toggle
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isPresentationMode = !_isPresentationMode;
                      });
                    },
                    tooltip: _isPresentationMode
                        ? 'إيقاف وضع العرض'
                        : 'وضع العرض الرسمي',
                    icon: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _isPresentationMode
                            ? Colors.amber
                            : Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPresentationMode
                            ? Icons.close_fullscreen
                            : Icons.slideshow,
                        color: _isPresentationMode
                            ? Colors.black
                            : Colors.white,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  if (hasDelegatedAdmin && !_isPresentationMode)
                    PopupMenuButton<String>(
                      tooltip: 'خيارات اللوحة',
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
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
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'admin_dashboard') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminDashboard(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
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
            ],
          ),
          if (!_isPresentationMode) ...[
            SizedBox(height: 8.h),
            Text(
              'إدارة التحصيل، الاختبارات، والخطط العلاجية الأكاديمية',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final schoolName = ref.watch(
      schoolProvider(schoolId).select((v) => v.value?.name ?? ''),
    );

    final studentsCount = ref.watch(
      studentsProvider.select((v) => v.value?.length ?? 0),
    );
    final classesCount = ref.watch(
      classesProvider.select((v) => v.value?.length ?? 0),
    );
    final teachersCount = ref.watch(
      teachersProvider.select((v) => v.value?.length ?? 0),
    );
    final staffCount = ref.watch(
      staffProvider.select((v) => v.value?.length ?? 0),
    );

    final inboxCount =
        ref.watch(pendingTeacherNotesProvider).value?.length ?? 0;

    final hasDelegatedAdmin =
        user != null &&
        user.delegatedPermissions != null &&
        user.delegatedPermissions!.isNotEmpty;

    final bg = _isPresentationMode ? Colors.grey[100] : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: _isPresentationMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/student-scan'),
              backgroundColor: Colors.indigo.shade700,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text(
                'ماسح هوية الطلاب',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: Container(
        color: bg,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, hasDelegatedAdmin, schoolName),
              SizedBox(height: 24.h),

              if (!_isPresentationMode) ...[
                // Welcome Banner (Hide in Presentation Mode)
                WelcomeBanner(
                  userName: user?.name ?? 'الوكيل',
                  gradient: DashboardPalette.bannerGradient('deputyAcademic'),
                ),
                SizedBox(height: 16.h),
              ],

              // Always show Executive Summary (Focus of Presentation Mode)
              AcademicExecutiveSummaryCard(schoolId: user?.schoolId ?? ''),

              if (!_isPresentationMode) ...[
                // Delegated Mode Banner (Hide in Presentation Mode)
                if (user?.role == UserRole.deputy &&
                    user?.deputyType == 'academic') ...[
                  SizedBox(height: 16.h),
                  Container(
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
                              Consumer(
                                builder: (context, ref, child) {
                                  final schoolAsync = ref.watch(
                                    schoolProvider(user?.schoolId ?? ''),
                                  );
                                  final school = schoolAsync.value;
                                  final managerNameAsync = ref.watch(
                                    schoolManagerNameProvider((
                                      userId: school?.ownerId ?? '',
                                      schoolId: school?.id ?? '',
                                    )),
                                  );
                                  return managerNameAsync.when(
                                    data: (name) => Text(
                                      'المدير المفوض: ${name ?? 'غير معروف'}',
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
                                  );
                                },
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
                                    (user?.delegatedPermissions?.keys.map((
                                      key,
                                    ) {
                                      final sectionNames = {
                                        'academic_affairs': 'الشؤون الأكاديمية',
                                        'leadership': 'القيادة',
                                        'classes': 'الفصول',
                                        'students': 'الطلاب',
                                        'teachers': 'المعلمين',
                                        'administrative': 'الإدارية',
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
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.shade300,
                                          ),
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
                  ),
                ],
              ],

              SizedBox(height: 16.h),

              // Distinguished Students (Always Keep - Shows Success)
              if (_isPresentationMode)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'التميز الطلابي',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              DistinguishedStudentsWidget(schoolId: user?.schoolId ?? ''),
              SizedBox(height: 16.h),

              SizedBox(height: 24.h),

              // Stat Cards (Keep for overview)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'الطلاب',
                      '$studentsCount',
                      Colors.indigo,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'الفصول',
                      '$classesCount',
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'المعلمين',
                      '$teachersCount',
                      Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'الإداريين',
                      '$staffCount',
                      Colors.purple,
                    ),
                  ),
                ],
              ),

              if (_isPresentationMode) ...[
                SizedBox(height: 40.h),
                Center(
                  child: Text(
                    'تم إنشاء هذا التقرير آلياً بواسطة نظام المنار الذكي',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                ),
              ],

              SizedBox(height: 32.h),

              // Sections
              _buildSectionHeader(context, 'السجلات والبيانات الأساسية'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.inbox,
                  label: inboxCount > 0
                      ? 'وارد المعلمين ($inboxCount)'
                      : 'وارد المعلمين',
                  color: Colors.indigo,
                  route: '/behavior-inbox',
                ),
                _ActionItem(
                  icon: Icons.school,
                  label: 'قائمة الطلاب',
                  color: Colors.blue,
                  route: '/students-list',
                ),
                _ActionItem(
                  icon: Icons.qr_code_2,
                  label: 'ملصقات تعريف الطلاب',
                  color: Colors.indigo.shade700,
                  route: '/student-barcodes',
                ),
                _ActionItem(
                  icon: Icons.campaign,
                  label: 'إرسال إعلان',
                  color: Colors.amber.shade800,
                  route: '/send-announcement',
                ),
                _ActionItem(
                  icon: Icons.picture_as_pdf,
                  label: 'إرسال تعميم',
                  color: Colors.indigo,
                  route: '/circulars/create',
                ),
                _ActionItem(
                  icon: Icons.class_,
                  label: 'إدارة الفصول',
                  color: Colors.purple,
                  route: '/classes-list',
                ),
                _ActionItem(
                  icon: Icons.people_alt,
                  label: 'قائمة المعلمين',
                  color: Colors.orange,
                  route: '/teachers-list',
                ),
                _ActionItem(
                  icon: Icons.bar_chart,
                  label: 'التقارير العامة',
                  color: Colors.indigo,
                  route: '/reports',
                ),
              ]),

              _buildSectionHeader(context, 'الإشراف الأكاديمي'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.insights,
                  label: 'الجاهزية التعليمية والتخطيط التدريسي',
                  color: Colors.teal,
                  route: '/lesson-prep',
                ),
                _ActionItem(
                  icon: Icons.timeline,
                  label: 'مستوى الالتزام بالخطة الدراسية',
                  color: Colors.indigo,
                  route: '/curriculum-progress',
                ),
                _ActionItem(
                  icon: Icons.grid_view_rounded,
                  label: 'مؤشرات تحسين الأداء التعليمي',
                  color: Colors.orange,
                  route: '/performance-alerts',
                ),
              ]),
              _buildSectionHeader(context, 'إدارة الجداول'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.calendar_view_week,
                  label: 'عرض جدول الحصص',
                  color: Colors.blue,
                  route: '/current-schedule',
                ),
                _ActionItem(
                  icon: Icons.auto_mode,
                  label: 'الجدول الذكي',
                  color: Colors.green,
                  route: '/smart-schedule',
                ),
                _ActionItem(
                  icon: Icons.supervisor_account_rounded,
                  label: 'الإشراف والمناوبة',
                  color: const Color(0xFF0D47A1),
                  route: '/supervision-duty',
                ),
                _ActionItem(
                  icon: Icons.groups,
                  label: 'الجدول التشاركي',
                  color: Colors.teal,
                  route: '/collaborative-schedule',
                ),
                _ActionItem(
                  icon: Icons.pie_chart,
                  label: 'توزيع نصاب المعلمين',
                  color: Colors.indigo,
                  route: '/teacher-load',
                ),
                _ActionItem(
                  icon: Icons.restore,
                  label: 'سجل التعديلات',
                  color: Colors.grey,
                  route: '/schedule-log',
                ),
              ]),

              _buildSectionHeader(context, 'الاختبارات والتقويم'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.grade,
                  label: 'متابعة رصد الدرجات',
                  color: Colors.green,
                  route: '/grade-entry',
                ),
                _ActionItem(
                  icon: Icons.person_off,
                  label: 'كشف غياب الاختبار',
                  color: Colors.red,
                  route: '/exam-absence',
                ),
              ]),

              _buildSectionHeader(context, 'التحليل الأكاديمي'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.analytics,
                  label: 'تحليل النتائج (مادة)',
                  color: Colors.purple,
                  route: '/subject-analysis',
                ),
                _ActionItem(
                  icon: Icons.mood_bad,
                  label: 'كشف منخفضي التحصيل',
                  color: Colors.red,
                  route: '/low-achievers',
                ),
                _ActionItem(
                  icon: Icons.bar_chart,
                  label: 'مقارنة الفصول',
                  color: Colors.blue,
                  route: '/class-comparison',
                ),
                _ActionItem(
                  icon: Icons.lightbulb,
                  label: 'توصيات التحسين',
                  color: Colors.amber.shade800,
                  route: '/improvement-recommendations',
                ),
                _ActionItem(
                  icon: Icons.insights,
                  label: '📊 مؤشر صحة المدرسة',
                  color: Colors.indigo,
                  route: '/school-health-index',
                ),
              ]),

              _buildSectionHeader(context, 'الخطط العلاجية'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.medical_services,
                  label: 'إنشاء خطة علاجية',
                  color: Colors.teal,
                  route: '/create-remedial-plan',
                ),
                _ActionItem(
                  icon: Icons.link,
                  label: 'ربط الطالب بالمعلم',
                  color: Colors.indigo,
                  route: '/link-student-teacher',
                ),
                _ActionItem(
                  icon: Icons.track_changes,
                  label: 'متابعة التنفيذ',
                  color: Colors.orange,
                  route: '/plan-followup',
                ),
                _ActionItem(
                  icon: Icons.show_chart,
                  label: 'قياس التحسن',
                  color: Colors.green,
                  route: '/measure-improvement',
                ),
              ]),

              _buildSectionHeader(context, 'التقارير'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.percent,
                  label: 'تقرير نسب النجاح',
                  color: Colors.blue,
                  route: '/success-rates',
                ),
                _ActionItem(
                  icon: Icons.compare_arrows,
                  label: 'تقرير فجوات تعليمية',
                  color: Colors.orange,
                  route: '/learning-gaps',
                ),
                _ActionItem(
                  icon: Icons.person,
                  label: 'تقرير أداء معلم',
                  color: Colors.purple,
                  route: '/teacher-performance-report',
                ),
                _ActionItem(
                  icon: Icons.picture_as_pdf,
                  label: 'تصدير PDF رسمي',
                  color: Colors.red,
                  route: '/export-academic-reports',
                ),
              ]),
              SizedBox(height: 32.h),

              // ── قسم الاستئذانات ──────────────────────────────────────
              _buildSectionHeader(context, 'الاستئذانات'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.exit_to_app,
                  label: 'إذن خروج طالب',
                  color: Colors.amber.shade700,
                  route: '/student-exit-permission',
                ),
                _ActionItem(
                  icon: Icons.assignment_ind,
                  label: 'لوحة إدارة الاستئذانات',
                  color: Colors.purple.shade700,
                  route: '/deputy-leave-dashboard',
                ),
                _ActionItem(
                  icon: Icons.assignment_return,
                  label: 'طلبات الاستئذان',
                  color: Colors.cyan.shade700,
                  route: '/deputy-requests',
                ),
              ]),

              // ── السلوك والانضباط ──────────────────────────────────────
              _buildSectionHeader(context, 'السلوك والانضباط'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.qr_code_scanner,
                  label: 'رصد الحضور بالباركود',
                  color: Colors.indigo.shade700,
                  route: '/smart-attendance-dashboard',
                ),
                _ActionItem(
                  icon: Icons.access_time,
                  label: 'رصد التأخير',
                  color: Colors.orange.shade700,
                  route: '/teacher-attendance',
                ),
                _ActionItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'رصد المخالفات',
                  color: Colors.red.shade700,
                  route: '/deputy-violations',
                ),
                _ActionItem(
                  icon: Icons.build_circle,
                  label: 'تجهيز المخالفات',
                  color: Colors.deepOrange.shade700,
                  route: '/violations-log',
                ),
              ]),

              // ── إدارة المعلمين ──────────────────────────────────────
              _buildSectionHeader(context, 'إدارة المعلمين'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.swap_horiz,
                  label: 'ترحيل المعلمين',
                  color: Colors.purple.shade700,
                  route: '/teacher-migration',
                ),
                _ActionItem(
                  icon: Icons.how_to_reg,
                  label: 'حضور المعلمين',
                  color: Colors.green.shade700,
                  route: '/staff-attendance',
                ),
              ]),

              // ── خدمة الرسائل SMS ──────────────────────────────────────
              _buildSectionHeader(context, 'خدمة الرسائل SMS'),
              _buildActionGrid(context, [
                _ActionItem(
                  icon: Icons.settings_cell,
                  label: 'إعدادات SMS',
                  color: const Color(0xFF00838F),
                  route: '/deputy-sms',
                ),
                _ActionItem(
                  icon: Icons.tune,
                  label: 'حدود رسائل المعلمين',
                  color: const Color(0xFF1565C0),
                  route: '/teacher-sms-limits',
                ),
              ]),

              SizedBox(height: 32.h),
              const WebAccessFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h, top: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade50,
            Colors.indigo.shade100.withOpacity(0.3),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(
            color: Colors.indigo.shade700,
            width: 4.w,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
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
                color: Colors.indigo.shade900,
                fontSize: 18.sp,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, List<_ActionItem> items) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final userId = user?.id ?? '';

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

            // Build route with parameters for new sections
            String finalRoute = item.route;
            if (item.route == '/collaborative-schedule') {
              finalRoute =
                  '/collaborative-schedule?schoolId=$schoolId&userId=$userId';
            } else if (item.route == '/teacher-load') {
              finalRoute = '/teacher-load?schoolId=$schoolId';
            } else if (item.route == '/schedule-log') {
              finalRoute = '/schedule-log?schoolId=$schoolId';
            }

            return _buildActionCard(
              context,
              icon: item.icon,
              label: item.label,
              color: item.color,
              onTap: () => context.push(finalRoute),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
                    fontSize: 15.sp,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 32.sp,
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

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
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
        child: Center(
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
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}
