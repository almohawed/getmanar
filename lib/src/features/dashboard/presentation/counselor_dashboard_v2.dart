import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../counselor/presentation/counselor_providers.dart';
import '../../behavior/services/behavior_data_service.dart';
import '../../behavior/providers/behavior_providers.dart';
import 'widgets/qr_scanner_fab.dart';

/// لوحة المرشد الطلابي V2 - تصميم احترافي مبهر ✨
class CounselorDashboardV2 extends ConsumerWidget {
  const CounselorDashboardV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    
    // البيانات الحقيقية من Firestore
    final activeCases = ref.watch(activeCasesProvider).value ?? [];
    final todaySessions = ref.watch(todaySessionsProvider).value ?? [];
    final activePlans = ref.watch(activePlansProvider).value ?? [];
    
    // إحصائيات إضافية
    final totalStudentsAsync = ref.watch(_totalStudentsProvider(schoolId));
    final activeCasesCount = ref.watch(activeCasesCountProvider);
    final criticalCasesCount = ref.watch(criticalCasesCountProvider);
    final behaviorScore = ref.watch(behaviorScoreProvider);
    final healthCasesAsync = ref.watch(_healthCasesProvider(schoolId));
    final closedCasesAsync = ref.watch(_closedCasesThisMonthProvider(schoolId));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: const QrScannerFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, user?.name ?? 'المرشد الطلابي'),
              SizedBox(height: 24.h),
              
              // الإحصائيات السريعة
              _buildQuickStats(
                context,
                activeCases: activeCases.length,
                todaySessions: todaySessions.length,
                activePlans: activePlans.length,
                totalStudents: totalStudentsAsync.value ?? 0,
                behaviorCases: activeCasesCount,
                behaviorScore: behaviorScore,
                healthCases: healthCasesAsync.value ?? 0,
                closedCases: closedCasesAsync.value ?? 0,
              ),
              SizedBox(height: 24.h),
              
              // الأقسام الرئيسية
              _buildSection(
                context,
                ref,
                title: 'إدارة الحالات',
                color: Colors.purple.shade800,
                items: [
                  {
                    'icon': Icons.person_add,
                    'title': 'إضافة حالة جديدة',
                    'route': '/add-student-case',
                    'count': 0,
                  },
                  {
                    'icon': Icons.folder_open,
                    'title': 'الحالات النشطة',
                    'route': '/counselor/active-cases',
                    'count': activeCases.length,
                  },
                  {
                    'icon': Icons.history,
                    'title': 'الحالات المغلقة',
                    'route': '/counselor/closed-cases',
                    'count': closedCasesAsync.value ?? 0,
                  },
                  {
                    'icon': Icons.search,
                    'title': 'بحث في الحالات',
                    'route': '/counselor/search-cases',
                    'count': 0,
                  },
                ],
              ),

              _buildSection(
                context,
                ref,
                title: 'الجلسات الإرشادية',
                color: Colors.blue.shade800,
                items: [
                  {
                    'icon': Icons.event_note,
                    'title': 'تسجيل جلسة',
                    'route': '/add-counseling-session',
                    'count': 0,
                  },
                  {
                    'icon': Icons.today,
                    'title': 'جلسات اليوم',
                    'route': '/counselor/sessions',
                    'count': todaySessions.length,
                  },
                  {
                    'icon': Icons.calendar_month,
                    'title': 'جدول الجلسات',
                    'route': '/counselor/sessions-calendar',
                    'count': 0,
                  },
                  {
                    'icon': Icons.assessment,
                    'title': 'تقارير الجلسات',
                    'route': '/counselor/sessions-reports',
                    'count': 0,
                  },
                ],
              ),

              _buildSection(
                context,
                ref,
                title: 'خطط التعديل والمتابعة',
                color: Colors.teal.shade800,
                items: [
                  {
                    'icon': Icons.playlist_add,
                    'title': 'إنشاء خطة تعديل',
                    'route': '/counselor/create-plan',
                    'count': 0,
                  },
                  {
                    'icon': Icons.assignment,
                    'title': 'الخطط النشطة',
                    'route': '/counselor/plans',
                    'count': activePlans.length,
                  },
                  {
                    'icon': Icons.playlist_add_check,
                    'title': 'إضافة متابعة',
                    'route': '/add-case-followup',
                    'count': 0,
                  },
                  {
                    'icon': Icons.trending_up,
                    'title': 'تقييم التقدم',
                    'route': 'DIRECT_PROGRESS_EVALUATION',
                    'count': 0,
                  },
                ],
              ),

              _buildSection(
                context,
                ref,
                title: 'السلوك والانضباط',
                color: Colors.orange.shade800,
                items: [
                  {
                    'icon': Icons.warning,
                    'title': 'حالات سلوكية',
                    'route': '/behavioral-cases',
                    'count': activeCasesCount,
                  },
                  {
                    'icon': Icons.people,
                    'title': 'الطلاب حسب السلوك',
                    'route': '/students-by-behavior',
                    'count': behaviorScore,
                  },
                  {
                    'icon': Icons.star,
                    'title': 'تعزيز السلوك',
                    'route': '/behavior-enhancement',
                    'count': criticalCasesCount,
                  },
                  {
                    'icon': Icons.analytics,
                    'title': 'تحليل السلوك',
                    'route': '/behavior-analysis',
                    'count': behaviorScore,
                  },
                ],
              ),

              _buildSection(
                context,
                ref,
                title: 'الصحة المدرسية',
                color: Colors.green.shade800,
                items: [
                  {
                    'icon': Icons.health_and_safety,
                    'title': 'الحالات الصحية',
                    'route': '/health-cases',
                    'count': healthCasesAsync.value ?? 0,
                  },
                  {
                    'icon': Icons.medical_services,
                    'title': 'إضافة حالة صحية',
                    'route': '/add-health-case',
                    'count': 0,
                  },
                  {
                    'icon': Icons.local_hospital,
                    'title': 'الحوادث الصحية',
                    'route': '/add-health-incident',
                    'count': 0,
                  },
                  {
                    'icon': Icons.medication,
                    'title': 'متابعة الأدوية',
                    'route': '/counselor/medications',
                    'count': 0,
                  },
                ],
              ),

              _buildSection(
                context,
                ref,
                title: 'التقارير والإحصائيات',
                color: Colors.indigo.shade800,
                items: [
                  {
                    'icon': Icons.bar_chart,
                    'title': 'تقرير شامل',
                    'route': '/counselor/comprehensive-report',
                    'count': 0,
                  },
                  {
                    'icon': Icons.pie_chart,
                    'title': 'إحصائيات الحالات',
                    'route': '/counselor/cases-statistics',
                    'count': 0,
                  },
                  {
                    'icon': Icons.timeline,
                    'title': 'تطور الحالات',
                    'route': '/counselor/cases-timeline',
                    'count': 0,
                  },
                  {
                    'icon': Icons.print,
                    'title': 'طباعة التقارير',
                    'route': '/counselor/print-reports',
                    'count': 0,
                  },
                ],
              ),

              // قسم التواصل مع أولياء الأمور
              _buildSection(
                context,
                ref,
                title: 'التواصل مع أولياء الأمور',
                color: const Color(0xFF1565C0),
                items: [
                  {
                    'icon': Icons.sms,
                    'title': 'إرسال رسالة SMS',
                    'route': '/counselor/sms',
                    'count': 0,
                  },
                ],
              ),

              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade700,
            Colors.purple.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، $userName',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'التوجيه والإرشاد الطلابي',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context, {
    required int activeCases,
    required int todaySessions,
    required int activePlans,
    required int totalStudents,
    required int behaviorCases,
    required int behaviorScore,
    required int healthCases,
    required int closedCases,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات السريعة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth > 600) crossAxisCount = 3;
              if (constraints.maxWidth > 900) crossAxisCount = 4;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    'الحالات النشطة',
                    activeCases.toString(),
                    Icons.folder_open,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'جلسات اليوم',
                    todaySessions.toString(),
                    Icons.today,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'الخطط النشطة',
                    activePlans.toString(),
                    Icons.assignment,
                    Colors.teal,
                  ),
                  _buildStatCard(
                    'حالات سلوكية',
                    behaviorCases.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'مؤشر السلوك',
                    '$behaviorScore%',
                    Icons.analytics,
                    behaviorScore >= 70 ? Colors.green : behaviorScore >= 50 ? Colors.orange : Colors.red,
                  ),
                  _buildStatCard(
                    'حالات صحية',
                    healthCases.toString(),
                    Icons.health_and_safety,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'حالات مغلقة',
                    closedCases.toString(),
                    Icons.check_circle,
                    Colors.indigo,
                  ),
                  _buildStatCard(
                    'إجمالي الطلاب',
                    totalStudents.toString(),
                    Icons.people,
                    Colors.cyan,
                  ),
                  _buildStatCard(
                    'معدل النجاح',
                    closedCases > 0 
                        ? '${((closedCases / (closedCases + activeCases)) * 100).toStringAsFixed(0)}%'
                        : '0%',
                    Icons.trending_up,
                    Colors.pink,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    MaterialColor color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.shade400, color.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Color color,
    required List<Map<String, dynamic>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 20.h, top: 16.h, left: 16.w, right: 16.w),
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
                  style: TextStyle(
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: LayoutBuilder(
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
                  childAspectRatio: 1.1,
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
                    count: item['count'] as int? ?? 0,
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String route,
    int count = 0,
  }) {
    return InkWell(
      onTap: () {
        try {
          if (route == 'DIRECT_PROGRESS_EVALUATION') {
            // فتح شاشة تقييم التقدم مباشرة
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const _ProgressEvaluationScreen(),
              ),
            );
          } else {
            context.push(route);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر فتح "$label"'),
            ),
          );
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
        child: Stack(
          children: [
            Center(
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
            if (count > 0)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(999.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count.toString(),
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

// Providers للبيانات الحقيقية
final _totalStudentsProvider = FutureProvider.family<int, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return 0;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('schoolId', isEqualTo: schoolId)
        .where('role', isEqualTo: 'student')
        .count()
        .get();
    return snapshot.count ?? 0;
  } catch (e) {
    return 0;
  }
});

final _behaviorCasesProvider = FutureProvider.family<int, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return 0;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('student_cases')
        .where('schoolId', isEqualTo: schoolId)
        .where('caseType', isEqualTo: 'behavior')
        .where('status', isEqualTo: 'active')
        .count()
        .get();
    return snapshot.count ?? 0;
  } catch (e) {
    return 0;
  }
});

final _healthCasesProvider = FutureProvider.family<int, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return 0;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('health_cases')
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: 'active')
        .count()
        .get();
    return snapshot.count ?? 0;
  } catch (e) {
    return 0;
  }
});

final _closedCasesThisMonthProvider = FutureProvider.family<int, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return 0;
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final snapshot = await FirebaseFirestore.instance
        .collection('student_cases')
        .where('schoolId', isEqualTo: schoolId)
        .where('status', isEqualTo: 'closed')
        .where('closedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();
    return snapshot.count ?? 0;
  } catch (e) {
    return 0;
  }
});


/// شاشة تقييم التقدم - تعرض إحصائيات حقيقية من Firebase
class _ProgressEvaluationScreen extends ConsumerWidget {
  const _ProgressEvaluationScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCasesAsync = ref.watch(activeCasesProvider);
    final activePlansAsync = ref.watch(activePlansProvider);
    final todaySessionsAsync = ref.watch(todaySessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم التقدم'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCasesProvider);
          ref.invalidate(activePlansProvider);
          ref.invalidate(todaySessionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تقرير تقييم التقدم',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'التاريخ: ${DateTime.now().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'الإحصائيات الحالية',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'الحالات النشطة',
                      asyncValue: activeCasesAsync,
                      icon: Icons.folder_open,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'الخطط النشطة',
                      asyncValue: activePlansAsync,
                      icon: Icons.assignment,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'جلسات اليوم',
                asyncValue: todaySessionsAsync,
                icon: Icons.event,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'التفاصيل',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'الحالات النشطة',
                asyncValue: activeCasesAsync,
                icon: Icons.folder_open,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'الخطط النشطة',
                asyncValue: activePlansAsync,
                icon: Icons.assignment,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'جلسات اليوم',
                asyncValue: todaySessionsAsync,
                icon: Icons.event,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required AsyncValue asyncValue,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            asyncValue.when(
              data: (data) {
                final count = (data as List).length;
                return Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, stack) => Text(
                'خطأ',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required AsyncValue asyncValue,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            asyncValue.when(
              data: (data) {
                final items = data as List;
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'لا توجد بيانات',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.take(5).map((item) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        (item as dynamic).studentName ?? 'بيان',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        (item as dynamic).title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'خطأ في تحميل البيانات',
                    style: TextStyle(color: Colors.red[300]),
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
