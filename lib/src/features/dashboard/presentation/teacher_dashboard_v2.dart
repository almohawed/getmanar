import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/motivational_quotes.dart';
import '../../auth/presentation/auth_controller.dart';
import 'teacher_alerts_center_screen.dart';
import '../../circulars/presentation/circulars_providers.dart';
import 'widgets/qr_scanner_fab.dart';

/// لوحة المعلم V2 - تصميم احترافي موحد
class TeacherDashboardV2 extends ConsumerWidget {
  const TeacherDashboardV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final teacherId = user?.id ?? '';
    final schoolId = user?.schoolId ?? '';
    final waitsAsync = ref.watch(teacherWaitsProvider(teacherId));
    final unreadCirculars = ref.watch(unreadCircularsCountProvider).value ?? 0;
    final waitCount = waitsAsync.value?.length ?? 0;

    // Read broadcast permission live from GlobalUsers
    final broadcastPerm = (schoolId.isNotEmpty && teacherId.isNotEmpty)
        ? ref.watch(_broadcastPermV2Provider(teacherId))
        : const AsyncData<bool>(false);
    final showBroadcast = user?.delegatedPermissions?['isBroadcastSupervisor'] == true ||
        broadcastPerm.when(data: (v) => v, loading: () => false, error: (_, __) => false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: const QrScannerFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, user, unreadCirculars, waitCount),
              SizedBox(height: 24.h),

              _buildSection(context, ref,
                title: 'التدريس',
                color: Colors.blue.shade800,
                items: [
                  {'icon': Icons.calendar_today, 'title': 'جدولي الدراسي', 'route': '/teacher-schedule'},
                  {'icon': Icons.group, 'title': 'فصولي', 'route': '/classes-list'},
                  {'icon': Icons.person, 'title': 'الطلاب', 'route': '/students-list'},
                  {'icon': Icons.fact_check, 'title': 'السلوك الصفي', 'route': '/classroom-behavior-indicators'},
                ],
              ),

              _buildSection(context, ref,
                title: 'التقييم',
                color: Colors.orange.shade800,
                items: [
                  {'icon': Icons.assignment_turned_in, 'title': 'الواجبات', 'route': '/assignments'},
                  {'icon': Icons.quiz, 'title': 'الاختبارات', 'route': '/tests'},
                  {'icon': Icons.emoji_events, 'title': 'تعزيز السلوك', 'route': '/behavior-enhancement'},
                  {'icon': Icons.star, 'title': 'تميز الطلاب', 'route': '/student-excellence-compensation?tab=excellence'},
                  {'icon': Icons.refresh, 'title': 'تعويض السلوك', 'route': '/student-excellence-compensation?tab=compensation'},
                  {'icon': Icons.bar_chart, 'title': 'التقارير', 'route': '/reports'},
                ],
              ),

              _buildSection(context, ref,
                title: 'الإشراف',
                color: const Color(0xFF0D47A1),
                items: [
                  {'icon': Icons.supervisor_account_rounded, 'title': 'الإشراف والمناوبة', 'route': '/supervision-duty'},
                ],
              ),

              _buildSection(context, ref,
                title: 'الإدارة',
                color: Colors.indigo.shade800,
                items: [
                  {'icon': Icons.picture_as_pdf, 'title': unreadCirculars > 0 ? 'التعاميم ($unreadCirculars)' : 'التعاميم', 'route': '/circulars/inbox', 'badge': unreadCirculars},
                  {'icon': Icons.notifications_active, 'title': 'التنبيهات', 'route': '/teacher/alerts', 'badge': waitCount},
                  {'icon': Icons.campaign, 'title': 'إرسال إعلان', 'route': '/send-announcement'},
                  {'icon': Icons.drafts, 'title': 'المسودات', 'route': '/teacher-drafts'},
                ],
              ),

              _buildSection(context, ref,
                title: 'الأدوات',
                color: Colors.teal.shade800,
                items: [
                  {'icon': Icons.settings, 'title': 'الإعدادات', 'route': '/settings'},
                  {'icon': Icons.exit_to_app, 'title': 'طلب استئذان', 'route': '/teacher-leave-request'},
                  if (showBroadcast)
                    {'icon': Icons.mic, 'title': 'الإذاعة المدرسية', 'route': '/broadcast'},
                ],
              ),

              _TeacherSmsSection(schoolId: user?.schoolId ?? ''),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, int unreadCirculars, int waitCount) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12.r)),
                child: Icon(Icons.school, color: Colors.white, size: 28.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أهلاً بك، ${user?.name ?? "المعلم"}',
                        style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text(
                      MotivationalQuotes.getQuoteForRole('teacher'),
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.sp, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unreadCirculars > 0) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                _buildQuickStat(icon: Icons.campaign, label: 'تعاميم جديدة', value: unreadCirculars.toString(), color: Colors.orange),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStat({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8.r)),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, WidgetRef ref, {
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
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border(left: BorderSide(color: color, width: 4.w)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.r)),
                child: Icon(Icons.folder_special, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.9), fontSize: 18.sp, letterSpacing: 0.3)),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: LayoutBuilder(
            builder: (context, constraints) {
              int cols = 2;
              if (constraints.maxWidth > 600) cols = 3;
              if (constraints.maxWidth > 900) cols = 4;
              if (constraints.maxWidth > 1200) cols = 5;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.1,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildActionCard(context,
                    icon: item['icon'] as IconData,
                    label: item['title'] as String,
                    color: color,
                    route: item['route'] as String,
                    badge: item['badge'] as int? ?? 0,
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

  Widget _buildActionCard(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String route,
    int badge = 0,
  }) {
    return InkWell(
      onTap: () {
        try { context.push(route); } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح "$label"')));
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 1))],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(2.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 64.sp),
                SizedBox(height: 8.h),
                Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade800, height: 1.2),
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

/// قسم SMS للمعلم
class _TeacherSmsSection extends StatelessWidget {
  final String schoolId;
  const _TeacherSmsSection({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    if (schoolId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Schools').doc(schoolId).collection('Settings').doc('sms').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data?.data() as Map?;
        if (data == null || data['enabled'] != true) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 14.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00838F).withOpacity(0.08), const Color(0xFF00838F).withOpacity(0.02)],
                    begin: Alignment.centerRight, end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border(right: BorderSide(color: const Color(0xFF00838F), width: 4.w)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00838F),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [BoxShadow(color: const Color(0xFF00838F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Icon(Icons.sms_rounded, color: Colors.white, size: 18.sp),
                    ),
                    SizedBox(width: 12.w),
                    Text('رسائل أولياء الأمور',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF00838F))),
                  ],
                ),
              ),
              InkWell(
                onTap: () => context.push('/teacher-sms'),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFF00838F).withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: const Color(0xFF00838F).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF00838F).withOpacity(0.15), const Color(0xFF00838F).withOpacity(0.06)],
                            begin: Alignment.topRight, end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.send_rounded, color: const Color(0xFF00838F), size: 24.sp),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إرسال رسالة لأولياء الأمور',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                            SizedBox(height: 3.h),
                            Text('أرسل رسائل SMS مباشرة لأولياء أمور طلابك',
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Provider to read broadcast permission live from GlobalUsers
final _broadcastPermV2Provider = StreamProvider.family<bool, String>((ref, teacherId) {
  if (teacherId.isEmpty) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('GlobalUsers')
      .doc(teacherId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return false;
        final perms = doc.data()?['delegatedPermissions'] as Map? ?? {};
        return perms['isBroadcastSupervisor'] == true;
      });
});
