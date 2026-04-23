import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../admin/presentation/admin_dashboard_v2.dart';
import '../../admin/presentation/technical_support_dashboard.dart';
import '../../super_admin/presentation/super_admin_dashboard.dart';
import '../../academic/data/school_repository.dart';
import 'student_dashboard.dart';
import 'parent_dashboard.dart';
import 'counselor_dashboard_v2.dart';
import 'administrative_dashboard.dart';
import '../../deputy/presentation/academic_affairs_dashboard.dart';
import '../../deputy/presentation/school_affairs_dashboard.dart';
import '../../deputy/presentation/student_affairs_dashboard.dart';
import '../../requests/presentation/geofence_listener.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../../core/domain/models/school.dart';
import 'package:masar_app/src/features/dashboard/presentation/teacher_dashboard_v2.dart';

class DashboardScreen extends ConsumerWidget {
  final Widget child; // For nested navigation if needed later

  const DashboardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          // Should redirect to login, handled by router redirect logic usually
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذر المصادقة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('حدث خطأ أثناء تحميل بيانات المستخدم'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(authRepositoryProvider).logout();
                      context.go('/login');
                    },
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          );
        }

        // Special check for Super Admin
        if (user.role == UserRole.superAdmin) {
          return const SuperAdminDashboard();
        }

        final schoolAsync = ref.watch(schoolProvider(user.schoolId ?? ''));

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            toolbarHeight: 80,
            centerTitle: true,
            title: schoolAsync.when(
              data: (school) => Column(
                children: [
                  Text(
                    school != null ? 'منار | ${school.name}' : 'منار',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              loading: () => Column(
                children: [
                  Text(
                    'منار',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                    width: 10,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
              error: (_, _) => Column(
                children: [
                  Text(
                    'منار',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final unreadCount = ref.watch(
                    unreadNotificationsCountProvider,
                  );
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () => context.push('/notifications'),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تسجيل الخروج'),
                      content: const Text(
                        'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'نعم، خروج',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (context.mounted && confirm == true) {
                    ref.read(authStateProvider.notifier).logout();
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
          body: GeofenceListener(
            child: schoolAsync.when(
              data: (school) => _buildRoleDashboard(context, user, school),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildRoleDashboard(BuildContext context, User user, School? school) {
    // Check subscription for Admin (Manager)
    if (user.role == UserRole.admin && school != null) {
      if (!school.isLifetimeAccess) {
        final now = DateTime.now();
        if (school.trialEndsAt != null && school.trialEndsAt!.isBefore(now)) {
          return _buildSubscriptionExpiredScreen(context);
        }
      }
    }

    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboardV2();
      case UserRole.teacher:
        return const TeacherDashboardV2();
      case UserRole.student:
        return StudentDashboard(student: user);
      case UserRole.parent:
        return ParentDashboard(parent: user);
      case UserRole.counselor:
        return const CounselorDashboardV2();
      case UserRole.administrative:
        return const AdministrativeDashboard();
      case UserRole.deputy:
        // Route based on Deputy Type
        if (user.deputyType == 'academic') {
          return const AcademicAffairsDashboard();
        } else if (user.deputyType == 'school') {
          return const SchoolAffairsDashboard();
        } else if (user.deputyType == 'student') {
          return const StudentAffairsDashboard();
        }
        // Default fallback (e.g. if type not set)
        return const AdminDashboardV2();
      case UserRole.superAdmin:
        return const SuperAdminDashboard();
      case UserRole.technicalSupport:
      case UserRole.supportAdmin:
        return const TechnicalSupportDashboard();
    }
  }

  Widget _buildSubscriptionExpiredScreen(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'انتهت الفترة التجريبية',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لقد انتهت فترة الـ 3 أيام المجانية. يرجى الاشتراك للاستمرار في استخدام النظام.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.push('/subscription-plans');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Colors.indigo,
              ),
              child: const Text(
                'اشترك الآن',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
