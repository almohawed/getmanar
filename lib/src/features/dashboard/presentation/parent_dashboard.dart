import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/school_repository.dart';
import '../../requests/presentation/parent_permission_sheet.dart';
import '../../requests/data/geofence_service.dart';
import '../../subscription/domain/subscription_logic.dart';
import 'child_detail_screen.dart';
import 'pages/academic_calendar_screen.dart';
import 'pages/contact_staff_sheet.dart';
import 'providers/dashboard_providers.dart';
import 'providers/parent_summary_provider.dart';
import 'widgets/welcome_banner.dart';
import 'dashboard_palette.dart';

class ParentDashboard extends ConsumerStatefulWidget {
  final User parent;

  const ParentDashboard({super.key, required this.parent});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolAsync = ref.read(
        schoolProvider(widget.parent.schoolId ?? ''),
      );
      if (schoolAsync.hasValue) {
        final school = schoolAsync.value;
        if (school != null && school.hasAccess(AppFeature.geofenceArrival)) {
          ref
              .read(geofenceServiceProvider)
              .startMonitoring(widget.parent.id, widget.parent.name);
        }
      }
    });
  }

  @override
  void dispose() {
    ref.read(geofenceServiceProvider).stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(parentChildrenProvider(widget.parent.id));
    final schoolAsync = ref.watch(schoolProvider(widget.parent.schoolId ?? ''));

    ref.listen(schoolProvider(widget.parent.schoolId ?? ''), (previous, next) {
      next.whenData((school) {
        if (school != null && school.hasAccess(AppFeature.geofenceArrival)) {
          ref
              .read(geofenceServiceProvider)
              .startMonitoring(widget.parent.id, widget.parent.name);
        } else {
          ref.read(geofenceServiceProvider).stopMonitoring();
        }
      });
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Banner
          WelcomeBanner(
            userName: widget.parent.name,
            gradient: DashboardPalette.bannerGradient('parent'),
          ),
          SizedBox(height: 12.h),

          // Geofence Status Indicator (Optional - keep for arrival/pickup context if needed, but not "Live Timer")
          // User said "No live timer for parent" referring to bathroom/class timer.
          // Arrival notification is different. I'll keep it subtle.
          schoolAsync.when(
            data: (school) {
              if (school != null &&
                  school.hasAccess(AppFeature.geofenceArrival)) {
                return Container(
                  margin: EdgeInsets.only(bottom: 24.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_searching,
                        color: Colors.green,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'نظام التتبع الجغرافي مفعل: سيتم تنبيه المدرسة تلقائياً عند وصولك.',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox(height: 24.h);
            },
            loading: () => SizedBox(height: 24.h),
            error: (_, _) => SizedBox(height: 24.h),
          ),

          // Section 1: My Children
          Text(
            'ملخص الأسبوع',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
          SizedBox(height: 12.h),
          childrenAsync.when(
            data: (children) {
              if (children.isEmpty) {
                return const Center(
                  child: Text('لا يوجد أبناء مرتبطين بهذا الحساب'),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  return _buildChildSummaryCard(context, child, ref);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),

          SizedBox(height: 32.h),

          // Section 2: Quick Services
          Text(
            'الخدمات والتواصل',
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

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
                childAspectRatio: 1.4,
                children: [
                  _buildServiceCard(
                    context,
                    'الإشعارات',
                    Icons.notifications,
                    Colors.orange,
                    () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Consumer(
                          builder: (context, ref, child) {
                            final notificationsAsync = ref.watch(
                              parentNotificationsProvider(widget.parent.id),
                            );
                            return Container(
                              padding: EdgeInsets.all(16.w),
                              height: 500.h,
                              child: Column(
                                children: [
                                  Text(
                                    'الإشعارات والمخالفات',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  SizedBox(height: 16.h),
                                  Expanded(
                                    child: notificationsAsync.when(
                                      data: (notifications) {
                                        if (notifications.isEmpty) {
                                          return const Center(
                                            child: Text('لا توجد إشعارات'),
                                          );
                                        }
                                        return ListView.separated(
                                          itemCount: notifications.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(),
                                          itemBuilder: (context, index) {
                                            final n = notifications[index];
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.notifications_active,
                                                color: Colors.orange,
                                              ),
                                              title: Text(n.title),
                                              subtitle: Text(
                                                '${n.body}\n${n.timestamp.toString().substring(0, 16)}',
                                              ),
                                              isThreeLine: true,
                                            );
                                          },
                                        );
                                      },
                                      loading: () => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      error: (e, s) =>
                                          Center(child: Text('Error: $e')),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _buildServiceCard(
                    context,
                    'طلب استئذان',
                    Icons.door_front_door,
                    Colors.red,
                    () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                        ),
                        builder: (context) =>
                            ParentPermissionSheet(parent: widget.parent),
                      );
                    },
                    isLocked:
                        schoolAsync.value != null &&
                        !schoolAsync.value!.hasAccess(
                          AppFeature.digitalPermission,
                        ),
                  ),
                  // New: Request Appointment
                  _buildServiceCard(
                    context,
                    'طلب موعد',
                    Icons.event_available,
                    Colors.purple,
                    () {
                      // Logic for requesting appointment (Open sheet or dialog)
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                        ),
                        builder: (context) => ContactStaffSheet(
                          parent: widget.parent,
                          targetRole: 'manager', // Or general appointment
                          title: 'طلب موعد رسمي',
                          initialType: 'appointment',
                        ),
                      );
                    },
                  ),
                  _buildServiceCard(
                    context,
                    'مراسلة المدرسة',
                    Icons.message,
                    Colors.blue,
                    () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                        ),
                        builder: (context) => ContactStaffSheet(
                          parent: widget.parent,
                          targetRole: 'deputy',
                          title: 'تواصل مع الإدارة',
                          initialType: 'general',
                        ),
                      );
                    },
                  ),
                  _buildServiceCard(
                    context,
                    'التواصل مع المرشد',
                    Icons.psychology,
                    Colors.teal,
                    () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                        ),
                        builder: (context) => ContactStaffSheet(
                          parent: widget.parent,
                          targetRole: 'counselor',
                          title: 'التواصل مع المرشد',
                        ),
                      );
                    },
                  ),
                  _buildServiceCard(
                    context,
                    'التقويم الدراسي',
                    Icons.calendar_month,
                    Colors.blueGrey,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AcademicCalendarScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChildSummaryCard(
    BuildContext context,
    User child,
    WidgetRef ref,
  ) {
    final summaryAsync = ref.watch(parentWeeklySummaryProvider(child.id));

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChildDetailScreen(student: child),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      child.name.isNotEmpty ? child.name[0] : '?',
                      style: TextStyle(
                        fontSize: 20.sp,
                        color: Colors.indigo.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'عرض التفاصيل >',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              summaryAsync.when(
                data: (summary) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusChip(
                        'السلوك',
                        summary.behaviorStatus == 'stable'
                            ? 'مستقر'
                            : 'يحتاج متابعة',
                        summary.behaviorStatus == 'stable'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      _buildStatusChip(
                        'الحضور',
                        summary.attendanceStatus == 'excellent'
                            ? 'ممتاز'
                            : 'يوجد ملاحظات',
                        summary.attendanceStatus == 'excellent'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      _buildStatusChip(
                        'الواجبات',
                        summary.homeworkStatus == 'regular' ? 'منتظم' : 'متأخر',
                        summary.homeworkStatus == 'regular'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (_, __) => const Text('تعذر تحميل الملخص'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isLocked = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey.withValues(alpha: 0.1)
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isLocked) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.lock, size: 14.sp, color: Colors.grey),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
