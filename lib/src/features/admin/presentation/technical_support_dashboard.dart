import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../deputy/presentation/academic_affairs_dashboard.dart';
import '../../deputy/presentation/school_affairs_dashboard.dart';
import '../../deputy/presentation/student_affairs_dashboard.dart';
import '../../academic/presentation/students_provider.dart';
import '../../super_admin/data/super_admin_repository.dart';
import '../../academic/data/school_repository.dart'; // Import School Repository
import '../data/mock_class_repository.dart';
import '../data/mock_staff_repository.dart'; // Import Staff Repository
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart'; // Import Auth Controller
import '../../dashboard/presentation/widgets/welcome_banner.dart';
import '../../behavior/presentation/behavior_controller.dart'; // Import Behavior Controller
import '../../subscription/domain/subscription_logic.dart'; // Import Subscription Logic
import '../../dashboard/presentation/web_access_footer.dart';
import '../../distinguished_students/presentation/distinguished_list_widget.dart';

// Provider for Support Staff
final supportStaffProvider = StreamProvider.autoDispose
    .family<List<User>, String>((ref, schoolId) {
      return ref.watch(staffRepositoryProvider).watchSupportStaff(schoolId);
    });

class TechnicalSupportDashboard extends ConsumerWidget {
  const TechnicalSupportDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check user role
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;

    // Technical Support has full access to all features regardless of school plan
    bool isLocked(AppFeature feature) {
      return false;
    }

    // Calculate stats
    final studentsListAsync = ref.watch(studentsProvider);
    final studentsList = studentsListAsync.value ?? [];
    final studentsCount = studentsList.length;

    final classesAsync = ref.watch(classesProvider);
    final classesCount = classesAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    // Fetch pending violations count
    final pendingViolationsAsync = ref.watch(pendingViolationsProvider);
    final pendingCount = pendingViolationsAsync.maybeWhen(
      data: (data) => data.length,
      orElse: () => 0,
    );

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo & Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'images/mylogo.png',
                      width: 80.w,
                      height: 80.h,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'لوحة الدعم الفني',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Welcome Banner
            WelcomeBanner(userName: user?.name ?? 'الدعم الفني'),
            SizedBox(height: 24.h),

            // Distinguished Students (published)
            DistinguishedStudentsWidget(schoolId: user?.schoolId ?? ''),
            SizedBox(height: 16.h),

            // Stats Row
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

            SizedBox(height: 32.h),

            Text(
              'الوصول الكامل',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 16.h),

            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 600) crossAxisCount = 3;
                if (constraints.maxWidth > 900) crossAxisCount = 4;
                if (constraints.maxWidth > 1200) crossAxisCount = 5;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 1.5,
                  children: [
                    _buildActionCard(
                      context,
                      icon: Icons.people,
                      label: 'شؤون الطلاب',
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('وكيل شؤون الطلاب'),
                            ),
                            body: const StudentAffairsDashboard(),
                          ),
                        ),
                      ),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.manage_accounts,
                      label: 'إدارة مدير المدرسة',
                      color: Colors.red.shade900,
                      onTap: () => _showManagePrincipalDialog(
                        context,
                        ref,
                        user?.schoolId,
                      ),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.menu_book,
                      label: 'الشؤون التعليمية',
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('وكيل الشؤون التعليمية'),
                            ),
                            body: const AcademicAffairsDashboard(),
                          ),
                        ),
                      ),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.admin_panel_settings,
                      label: 'الشؤون المدرسية',
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('وكيل الشؤون المدرسية'),
                            ),
                            body: const SchoolAffairsDashboard(),
                          ),
                        ),
                      ),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    // Show Subscription Section only if allowed
                    ref
                        .watch(schoolProvider(user?.schoolId ?? ''))
                        .when(
                          data: (school) {
                            if (school != null &&
                                school.showSubscriptionSection) {
                              return _buildActionCard(
                                context,
                                icon: Icons.workspace_premium,
                                label: 'الاشتراكات',
                                color: Colors.amber.shade800,
                                onTap: () =>
                                    context.push('/subscription-plans'),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                        ),
                    _buildActionCard(
                      context,
                      icon: Icons.assignment_ind,
                      label: 'التكليفات الإدارية',
                      color: Colors.orange,
                      onTap: () => context.push('/assignments-management'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.person_add,
                      label: 'إضافة معلم',
                      color: Colors.green,
                      onTap: () => context.push('/add-teacher'),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.people_alt,
                      label: 'قائمة المعلمين',
                      color: Colors.orange,
                      onTap: () => context.push('/teachers-list'),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.school,
                      label: 'قائمة الطلاب',
                      color: Colors.blue,
                      onTap: () => context.push('/students-list'),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.qr_code,
                      label: 'باركود الطلاب',
                      color: Colors.black87,
                      onTap: () => context.push('/student-barcodes'),
                      isLocked: isLocked(AppFeature.studentCardsQR),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.class_,
                      label: 'إدارة الفصول',
                      color: Colors.purple,
                      onTap: () => context.push('/classes-list'),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.bar_chart,
                      label: 'التقارير والكشوفات',
                      color: Colors.red,
                      onTap: () => context.push('/reports'),
                      isLocked: isLocked(AppFeature.advancedReports),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.support_agent,
                      label: 'إدارة فريق الدعم',
                      color: Colors.blueGrey,
                      onTap: () => _showSupportManagementDialog(
                        context,
                        ref,
                        user?.schoolId,
                      ),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.calendar_view_week,
                      label: 'الجداول الدراسية',
                      color: Colors.indigo,
                      onTap: () => context.push('/current-schedule'),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.calendar_month,
                      label: 'إدارة الجدول المدرسي',
                      color: Colors.cyan,
                      onTap: () =>
                          context.push('/schedule-management?v=2'),
                      isLocked: isLocked(AppFeature.smartSchedule),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.timer,
                      label: 'إدارة الانتظار',
                      color: Colors.brown,
                      onTap: () => context.push('/wait-management'),
                      isLocked: isLocked(AppFeature.smartSubstitution),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.gavel,
                      label: 'اعتماد المخالفات',
                      color: Colors.redAccent,
                      onTap: () => context.push('/deputy-violations'),
                      badgeCount: pendingCount,
                      isLocked: isLocked(AppFeature.basicBehavior),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.assignment_late,
                      label: 'المخالفات السلوكية',
                      color: Colors.deepOrange,
                      onTap: () => context.push('/behavioral-violations'),
                      isLocked: isLocked(AppFeature.basicBehavior),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.history_edu,
                      label: 'سجل المخالفات',
                      color: Colors.brown,
                      onTap: () => context.push('/violations-log'),
                      isLocked: isLocked(AppFeature.basicBehavior),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.access_time_filled,
                      label: 'تحضير المعلمين',
                      color: Colors.green.shade800,
                      onTap: () => context.push('/attendance-days'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.timer,
                      label: 'وقت الدوام',
                      color: Colors.blue.shade800,
                      onTap: () =>
                          _showSchoolTimeDialog(context, ref, user?.schoolId),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.settings,
                      label: 'الإعدادات',
                      color: Colors.grey,
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 32.h),
            Text(
              'إدارة الكادر الإداري',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 16.h),
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 600) crossAxisCount = 3;
                if (constraints.maxWidth > 900) crossAxisCount = 4;
                if (constraints.maxWidth > 1200) crossAxisCount = 5;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 1.5,
                  children: [
                    _buildActionCard(
                      context,
                      icon: Icons.people_outline,
                      label: 'قائمة الموظفين',
                      color: Colors.brown,
                      onTap: () => context.push('/staff-list'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.support_agent,
                      label: 'إضافة مرشد',
                      color: Colors.teal,
                      onTap: () => context.push('/add-counselor'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.admin_panel_settings,
                      label: 'إضافة إداري',
                      color: Colors.blueGrey,
                      onTap: () => context.push('/add-admin-staff'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.security,
                      label: 'إضافة وكيل',
                      color: Colors.deepPurple,
                      onTap: () => context.push('/add-deputy'),
                      isLocked: isLocked(AppFeature.adminHierarchy),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 40.h),
            const WebAccessFooter(),
          ],
        ),
      ),
    );
  }

  Future<void> _showSchoolTimeDialog(
    BuildContext context,
    WidgetRef ref,
    String? schoolId,
  ) async {
    if (schoolId == null) return;

    TimeOfDay initialTime = const TimeOfDay(hour: 6, minute: 30);
    final schoolAsync = ref.read(schoolProvider(schoolId));
    if (schoolAsync.hasValue && schoolAsync.value != null) {
      final parts = schoolAsync.value!.startTime.split(':');
      if (parts.length == 2) {
        initialTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    final newTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'أدخل وقت بدء الدوام',
      confirmText: 'حفظ',
      cancelText: 'إلغاء',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (newTime != null && context.mounted) {
      _updateSchoolTime(context, ref, schoolId, newTime);
    }
  }

  Future<void> _updateSchoolTime(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    TimeOfDay newTime,
  ) async {
    final formattedTime =
        '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
    try {
      await ref
          .read(schoolRepositoryProvider)
          .updateSchoolStartTime(schoolId, formattedTime);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث وقت الدوام إلى $formattedTime')),
        );
        ref.invalidate(schoolProvider(schoolId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.analytics_outlined,
            color: Colors.white.withValues(alpha: 0.8),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14.sp,
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
    int badgeCount = 0,
    bool isLocked = false,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
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
          child: Container(
            decoration: BoxDecoration(
              color: isLocked ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isLocked ? Colors.grey.shade300 : Colors.grey.shade100,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLocked
                      ? Colors.grey.withValues(alpha: 0.1)
                      : Colors.lightBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ColorFiltered(
              colorFilter: isLocked
                  ? const ColorFilter.mode(Colors.grey, BlendMode.srcIn)
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.shade200
                          : color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isLocked ? Colors.grey : color,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLocked)
          Positioned(
            top: 8,
            left: 8,
            child: Icon(Icons.lock, color: Colors.grey.shade400, size: 20.sp),
          ),
        if (badgeCount > 0 && !isLocked)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showManagePrincipalDialog(
    BuildContext context,
    WidgetRef ref,
    String? schoolId,
  ) async {
    if (schoolId == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final school = await ref
          .read(schoolRepositoryProvider)
          .getSchool(schoolId);
      if (context.mounted) Navigator.pop(context); // Dismiss loading

      if (school == null) return;

      final ownerId = school.ownerId;

      // Show loading again for user fetch
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      final owner = await ref
          .read(superAdminRepositoryProvider)
          .getSchoolUser(schoolId, ownerId);
      if (context.mounted) Navigator.pop(context); // Dismiss loading

      if (owner == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بيانات المدير غير موجودة')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final nameController = TextEditingController(text: owner.name);
      final passwordController = TextEditingController();

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إدارة مدير المدرسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المدير'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  helperText:
                      'اتركه فارغاً إذا لم ترد التغيير (تغييرها سيحذف الحساب القديم وينشئ جديداً بنفس البيانات)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(context); // Close dialog

                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري تحديث البيانات...')),
                  );

                  // Update Name
                  if (nameController.text != owner.name) {
                    await ref
                        .read(superAdminRepositoryProvider)
                        .updateManagerName(
                          ownerId,
                          schoolId,
                          nameController.text,
                        );
                  }

                  // Update Password (Requires Replace)
                  if (passwordController.text.isNotEmpty) {
                    if (passwordController.text.length < 6) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('كلمة المرور قصيرة جداً'),
                          ),
                        );
                      }
                      return;
                    }

                    await ref
                        .read(superAdminRepositoryProvider)
                        .replaceManager(
                          schoolId: schoolId,
                          oldManagerId: ownerId,
                          newName: nameController.text,
                          newEmail: owner.email,
                          newPassword: passwordController.text,
                        );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات المدير بنجاح'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ غير متوقع: $e')));
      }
    }
  }

  // ==========================================================================
  // SUPPORT MANAGEMENT METHODS
  // ==========================================================================

  void _showSupportManagementDialog(
    BuildContext context,
    WidgetRef ref,
    String? schoolId,
  ) {
    if (schoolId == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600.w,
          height: 700.h,
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إدارة فريق الدعم الفني',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              SizedBox(height: 16.h),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final staffAsync = ref.watch(
                      supportStaffProvider(schoolId),
                    );
                    return staffAsync.when(
                      data: (staff) {
                        if (staff.isEmpty) {
                          return Center(
                            child: Text('لا يوجد أعضاء في فريق الدعم'),
                          );
                        }
                        return ListView.separated(
                          itemCount: staff.length,
                          separatorBuilder: (context, index) => Divider(),
                          itemBuilder: (context, index) {
                            final member = staff[index];
                            final isSupportAdmin =
                                member.role == UserRole.supportAdmin;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSupportAdmin
                                    ? Colors.purple.shade100
                                    : Colors.blue.shade100,
                                child: Icon(
                                  isSupportAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.support_agent,
                                  color: isSupportAdmin
                                      ? Colors.purple
                                      : Colors.blue,
                                ),
                              ),
                              title: Text(
                                member.name,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member.email),
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSupportAdmin
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isSupportAdmin
                                          ? 'مدير دعم (Admin)'
                                          : 'دعم فني',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: isSupportAdmin
                                            ? Colors.purple
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteSupportUser(
                                  context,
                                  ref,
                                  member.id,
                                  schoolId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('حدث خطأ: $err')),
                    );
                  },
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.add),
                  label: Text('إضافة عضو جديد'),
                  onPressed: () =>
                      _showAddSupportMemberDialog(context, ref, schoolId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSupportMemberDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
  ) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'tech_support'; // Default
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('إضافة عضو دعم فني'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'الدور',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'tech_support',
                      child: Text('دعم فني (Tech Support)'),
                    ),
                    DropdownMenuItem(
                      value: 'support_admin',
                      child: Text('مدير دعم (Support Admin)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => selectedRole = val!),
                ),
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('يرجى ملء جميع الحقول')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await ref
                            .read(staffRepositoryProvider)
                            .createSupportUser(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                              name: nameController.text.trim(),
                              role: selectedRole,
                              schoolId: schoolId,
                            );

                        if (context.mounted) {
                          Navigator.pop(context); // Close Add Dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تمت الإضافة بنجاح')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: ${e.toString()}')),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
              child: Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSupportUser(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String schoolId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف هذا العضو؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    try {
      // Show Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()),
      );

      await ref
          .read(staffRepositoryProvider)
          .deleteSupportUser(uid: uid, schoolId: schoolId);

      if (context.mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم الحذف بنجاح')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }
}
