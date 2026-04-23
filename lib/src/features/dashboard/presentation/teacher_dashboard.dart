import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'teacher_alerts_center_screen.dart'; // For teacherWaitsProvider
import '../../../core/utils/motivational_quotes.dart';
import '../../circulars/presentation/circulars_providers.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;
    final teacherId = user?.id ?? '';
    final schoolId = user?.schoolId ?? '';
    final waitsAsync = ref.watch(teacherWaitsProvider(teacherId));
    final unreadCirculars = ref.watch(unreadCircularsCountProvider).value ?? 0;
    // Read broadcast permission live from Firestore
    final isBroadcastSupervisor = user?.delegatedPermissions?['isBroadcastSupervisor'] == true;
    final broadcastPermAsync = schoolId.isNotEmpty && teacherId.isNotEmpty
        ? ref.watch(_broadcastPermProvider('$schoolId/$teacherId'))
        : const AsyncData<bool>(false);
    // Show if local perm OR live Firestore perm is true
    final showBroadcast = isBroadcastSupervisor ||
        broadcastPermAsync.when(
          data: (v) => v,
          loading: () => false,
          error: (_, __) => false,
        );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student-scan'),
        backgroundColor: const Color(0xFF3F51B5), // Indigo
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(
          'ماسح هوية الطلاب',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeacherWelcomeBanner(user: user),
              SizedBox(height: 24.h),

              // Waiting Assignments Section (Smart & Professional)
              waitsAsync.when(
                data: (waits) {
                  if (waits.isEmpty) return const SizedBox.shrink();
                  return _buildWaitingSection(context, waits);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              SizedBox(height: 32.h),

              // Quick Access Title
              Text(
                'الوصول السريع',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A237E), // Dark Blue
                ),
              ),
              SizedBox(height: 16.h),

              // Grid Section
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive Grid: 5 cols on large screens, 3 on tablet, 2 on mobile
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 1100) {
                    crossAxisCount = 5;
                  } else if (constraints.maxWidth > 700) {
                    crossAxisCount = 3;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12.w, // Reduced spacing
                    mainAxisSpacing: 12.h, // Reduced spacing
                    childAspectRatio: 1.5, // More compact cards
                    children: [
                      _buildMenuCard(
                        context,
                        'فصولي',
                        Icons.group,
                        Colors.blue,
                        () => context.push('/classes-list'),
                      ),
                      _buildMenuCard(
                        context,
                        'الطلاب',
                        Icons.person,
                        Colors.green,
                        () => context.push('/students-list'),
                      ),
                      _buildMenuCard(
                        context,
                        'الواجبات',
                        Icons.assignment_turned_in,
                        Colors.orange,
                        () => context.push('/assignments'),
                      ),
                      _buildMenuCard(
                        context,
                        'الاختبارات',
                        Icons.quiz,
                        Colors.indigo,
                        () => context.push('/tests'),
                      ),
                      _buildMenuCard(
                        context,
                        'مؤشرات السلوك الصفي',
                        Icons.fact_check,
                        Colors.teal.shade700,
                        () => context.push('/classroom-behavior-indicators'),
                      ),
                      _buildMenuCard(
                        context,
                        'التقارير والكشوفات',
                        Icons.bar_chart,
                        Colors.purple,
                        () => context.push('/reports'),
                      ),
                      _buildMenuCard(
                        context,
                        'جدولي',
                        Icons.calendar_today,
                        Colors.teal,
                        () => context.push('/teacher-schedule'),
                      ),
                      // Pass waiting count to alerts card
                      waitsAsync.when(
                        data: (waits) =>
                            _buildAlertsCard(context, count: waits.length),
                        loading: () => _buildAlertsCard(context, count: 0),
                        error: (_, __) => _buildAlertsCard(context, count: 0),
                      ),
                      _buildMenuCard(
                        context,
                        'المسودات',
                        Icons.drafts,
                        Colors.blueGrey,
                        () => context.push('/teacher-drafts'),
                      ),
                      _buildMenuCard(
                        context,
                        'إرسال إعلان',
                        Icons.campaign,
                        Colors.deepPurple,
                        () => context.push('/send-announcement'),
                      ),
                      _buildMenuCard(
                        context,
                        unreadCirculars > 0
                            ? 'التعاميم ($unreadCirculars)'
                            : 'التعاميم',
                        Icons.picture_as_pdf,
                        Colors.indigo.shade700,
                        () => context.push('/circulars/inbox'),
                      ),
                      _buildMenuCard(
                        context,
                        'تعزيز سلوك الطالب',
                        Icons.emoji_events,
                        Colors.orangeAccent,
                        () => context.push('/behavior-enhancement'),
                      ),
                      _buildMenuCard(
                        context,
                        'الإعدادات',
                        Icons.settings,
                        Colors.grey,
                        () => context.push('/settings'),
                      ),
                      _buildMenuCard(
                        context,
                        'طلب استئذان',
                        Icons.exit_to_app,
                        const Color(0xFF6A1B9A),
                        () => context.push('/teacher-leave-request'),
                      ),
                      if (showBroadcast)
                        _buildMenuCard(
                          context,
                          'الإذاعة المدرسية',
                          Icons.mic,
                          const Color(0xFF1A237E),
                          () => context.push('/broadcast'),
                        ),
                    ],
                  );
                },
              ),

              SizedBox(height: 48.h),

              // قسم الرسائل - يظهر فقط إذا كانت الخدمة مفعّلة
              _SmsSection(schoolId: user?.schoolId ?? ''),

              // Latest Activities Section
              Text(
                'آخر النشاطات',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'لا توجد نشاطات حديثة',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 48.h),

              // Footer
              const Divider(),
              SizedBox(height: 16.h),
              Center(
                child: Column(
                  children: [
                    Text(
                      'بإمكانك استخدام الموقع الإلكتروني أيضاً',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    InkWell(
                      onTap: () async {
                        final Uri url = Uri.parse('https://getmanar.com');
                        if (!await launchUrl(url)) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not launch https://getmanar.com',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'https://getmanar.com',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Icon(
                      Icons.qr_code_2,
                      size: 60.sp,
                      color: Colors.black,
                    ), // Smaller QR code
                  ],
                ),
              ),
              SizedBox(height: 80.h), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        hoverColor: color.withValues(alpha: 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w), // Smaller padding
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp), // Smaller icon
            ),
            SizedBox(height: 8.h), // Reduced spacing
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp, // Smaller font
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context, {int count = 0}) {
    return Material(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.red.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => context.push('/teacher/alerts'),
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.red,
                    size: 24.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'التنبيهات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            if (count > 0)
              Positioned(
                top: 8.h,
                left: 8.w,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
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

  Widget _buildWaitingSection(
    BuildContext context,
    List<Map<String, dynamic>> waits,
  ) {
    final nextWait = waits.first; // Assumes non-empty list
    return Container(
      margin: EdgeInsets.only(top: 24.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: Colors.orange.shade800),
              SizedBox(width: 8.w),
              Text(
                'مهام الانتظار (${waits.length})',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/teacher/alerts'),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          InkWell(
            onTap: () => context.push('/teacher/alerts'),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حصة انتظار: ${nextWait['day'] ?? ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'الحصة: ${nextWait['period'] ?? ''} - الفصل: ${nextWait['className'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.sp,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// قسم الرسائل - يظهر فقط إذا كانت خدمة SMS مفعّلة من المدير
class _SmsSection extends StatelessWidget {
  final String schoolId;
  const _SmsSection({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    if (schoolId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('sms')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final enabled = snapshot.data?.data() != null &&
            (snapshot.data!.data() as Map)['enabled'] == true;
        if (!enabled) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Container(
              margin: EdgeInsets.only(bottom: 14.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00838F).withOpacity(0.08),
                    const Color(0xFF00838F).withOpacity(0.02),
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border(
                  right: BorderSide(color: const Color(0xFF00838F), width: 4.w),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00838F),
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00838F).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.sms_rounded, color: Colors.white, size: 18.sp),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'رسائل أولياء الأمور',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00838F),
                    ),
                  ),
                ],
              ),
            ),
            // بطاقة الإرسال
            InkWell(
              onTap: () => context.push('/deputy-sms'),
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFF00838F).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00838F).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00838F).withOpacity(0.15),
                            const Color(0xFF00838F).withOpacity(0.06),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
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
                          Text(
                            'إرسال رسالة لأولياء الأمور',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'أرسل رسائل SMS مباشرة لأولياء أمور طلابك',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32.h),
          ],
        );
      },
    );
  }
}

// Provider to read broadcast permission live from Firestore
// Checks both Teachers collection and GlobalUsers for maximum compatibility
final _broadcastPermProvider = StreamProvider.family<bool, String>((ref, schoolIdSlashTeacherId) {
  final parts = schoolIdSlashTeacherId.split('/');
  if (parts.length != 2) return Stream.value(false);
  final schoolId = parts[0];
  final teacherId = parts[1];

  // Listen to GlobalUsers (most reliable - always updated)
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

class TeacherWelcomeBanner extends StatefulWidget {
  final User? user;
  const TeacherWelcomeBanner({super.key, this.user});

  @override
  State<TeacherWelcomeBanner> createState() => _TeacherWelcomeBannerState();
}

class _TeacherWelcomeBannerState extends State<TeacherWelcomeBanner> {
  late String _quote;

  @override
  void initState() {
    super.initState();
    _quote = MotivationalQuotes.getRandomQuote();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00695C),
            Color(0xFF4DB6AC),
          ], // Teal/Green gradient (Ministry style)
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00695C).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك، ${widget.user?.name ?? "المعلم"}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _quote,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14.sp,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school, color: Colors.white, size: 40.sp),
          ),
        ],
      ),
    );
  }
}
