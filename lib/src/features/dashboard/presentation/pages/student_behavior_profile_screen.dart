import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/domain/models/user.dart';
import '../../../../core/domain/models/behavior_record.dart';
import '../../../behavior/presentation/behavior_controller.dart';
import '../../../behavior/data/firestore_behavior_profile_repository.dart';
import '../providers/student_performance_provider.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../academic/services/class_climate_service.dart';
import '../../../academic/presentation/friends_list_screen.dart';
import '../../../academic/presentation/students_provider.dart';

class StudentBehaviorProfileScreen extends ConsumerWidget {
  final User student;

  const StudentBehaviorProfileScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider).value ?? const <User>[];
    final studentDoc = ref.watch(studentByIdProvider(student.id)).value;
    final resolvedStudent = (() {
      if (studentDoc != null) return studentDoc;
      try {
        return students.firstWhere((s) => s.id == student.id);
      } catch (_) {
        return student;
      }
    })();

    final profileAsync = ref.watch(studentBehaviorProfileProvider(student.id));
    final performanceAsync = ref.watch(studentPerformanceProvider(student));
    final pledgesCountAsync = ref.watch(studentPledgesCountProvider(student));
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));
    final classClimateAsync = ref.watch(classClimateProvider(student));
    final currentUser = ref.watch(authStateProvider).value;
    final isStaffView = currentUser != null && isStaffRole(currentUser.role);
    final pendingCount = isStaffView
        ? (behaviorAsync.value ?? const <BehaviorRecord>[])
              .where((r) => r.status == BehaviorStatus.pending)
              .length
        : 0;
    final studentPendingCount = (!isStaffView &&
            currentUser != null &&
            currentUser.role == UserRole.student)
        ? (behaviorAsync.value ?? const <BehaviorRecord>[])
            .where((r) => r.status == BehaviorStatus.pending)
            .length
        : 0;

    final fallbackScore = student.excellenceScore.clamp(0, 100);
    final fallbackRisk = _fallbackRiskLevel(fallbackScore);
    final fallbackTrend = _fallbackTrend(
      fallbackScore,
      student.lastViolationDate,
    );

    final profile = profileAsync.value;

    final score = profile?.score ?? fallbackScore;
    final riskLevel = profile?.riskLevel ?? fallbackRisk;
    final trend = profile?.trend ?? fallbackTrend;
    final riskColor = _riskColor(riskLevel);
    final size = MediaQuery.of(context).size;
    final isMobileLayout = size.shortestSide < 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('ملف الطالب الشامل'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              context,
              score,
              riskLevel,
              trend,
              riskColor,
              pledgesCountAsync,
              isStaffView,
              isMobileLayout,
            ),
            if (isStaffView && pendingCount > 0) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: Colors.orange.shade800),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'يوجد $pendingCount ملاحظة قيد الاعتماد.\nلن تؤثر على مؤشر السلوك حتى يتم اعتمادها.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push('/student-violations', extra: student),
                      child: const Text('عرض'),
                    ),
                  ],
                ),
              ),
            ],
            if (!isStaffView && studentPendingCount > 0) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.blueGrey.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blueGrey.shade700,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'تم تسجيل $studentPendingCount ملاحظة تربوية قيد الاعتماد.\nسيتم تحديث المؤشر بعد اعتمادها من المدرسة.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (profileAsync.isLoading && profile == null) ...[
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'جاري تحميل نموذج التحليل المتقدم...',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
            SizedBox(height: 24.h),
            if (isMobileLayout) ...[
              _buildTrendChart(behaviorAsync, score, riskColor),
              SizedBox(height: 16.h),
              _buildPerformanceOverview(performanceAsync),
            ] else
              Row(
                children: [
                  Expanded(
                    child: _buildTrendChart(behaviorAsync, score, riskColor),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildPerformanceOverview(performanceAsync)),
                ],
              ),
            SizedBox(height: 16.h),
            _buildQrCard(resolvedStudent),
            SizedBox(height: 24.h),
            if (profile?.topDrivers.isNotEmpty ?? false)
              _buildSection(
                context,
                title: 'أهم العوامل المؤثرة في السلوك',
                icon: Icons.psychology,
                color: Colors.blue.shade800,
                items: profile!.topDrivers,
              ),
            if (profile?.recommendations.isNotEmpty ?? false) ...[
              SizedBox(height: 24.h),
              _buildSection(
                context,
                title: 'نصائح لتحسين السلوك',
                icon: Icons.lightbulb,
                color: Colors.green.shade800,
                items: profile!.recommendations,
              ),
            ],
            if (profile == null) ...[
              SizedBox(height: 16.h),
              _buildFallbackInfoBanner(),
            ],
            SizedBox(height: 24.h),
            _buildFriendsPreview(context, ref),
            SizedBox(height: 24.h),
            _buildClassClimateIndicator(context, classClimateAsync),
            SizedBox(height: 24.h),
            _buildQuickActions(context),
            if (profile != null) ...[
              SizedBox(height: 24.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'آخر تحديث لمؤشر السلوك: ${profile.lastUpdatedAt.toString().split(' ').first}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int score,
    String riskLevel,
    String trend,
    Color riskColor,
    AsyncValue<int> pledgesCountAsync,
    bool isStaffView,
    bool isMobileLayout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32.r,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '?',
                style: TextStyle(fontSize: 24.sp, color: Colors.indigo),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'هذا المؤشر يساعدك على متابعة تقدمك السلوكي في المدرسة.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        if (isMobileLayout) ...[
          _buildScoreGaugeCard(
            score: score,
            trend: trend,
            color: riskColor,
            compact: true,
          ),
          SizedBox(height: 16.h),
          _buildSupportBadgeCard(riskLevel: riskLevel, color: riskColor),
          SizedBox(height: 12.h),
          _buildPledgesSummary(
            pledgesCountAsync,
            isStaffView: isStaffView,
            compact: false,
          ),
        ] else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildScoreGaugeCard(
                  score: score,
                  trend: trend,
                  color: riskColor,
                  compact: false,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildSupportBadgeCard(
                      riskLevel: riskLevel,
                      color: riskColor,
                    ),
                    SizedBox(height: 12.h),
                    _buildPledgesSummary(
                      pledgesCountAsync,
                      isStaffView: isStaffView,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildScoreGaugeCard({
    required int score,
    required String trend,
    required Color color,
    required bool compact,
  }) {
    final value = (score.clamp(0, 100)) / 100.0;
    final trendLabel = _trendShortLabel(trend);
    final trendIcon = _trendIcon(trend);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'مؤشر السلوك العام',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          SizedBox(height: compact ? 8.h : 12.h),
          SizedBox(
            height: compact ? 120.w : 140.w,
            width: compact ? 120.w : 140.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: compact ? 120.w : 140.w,
                  width: compact ? 120.w : 140.w,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 10.w,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, size: 18.sp, color: color),
                        SizedBox(width: 4.w),
                        Text(
                          trendLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'يعكس التزام الطالب خلال آخر فترة متابعة.',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade800),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportBadgeCard({
    required String riskLevel,
    required Color color,
  }) {
    final label = _translateRisk(riskLevel);
    Color bg;
    Color textColor;
    if (riskLevel == 'Low') {
      bg = Colors.green.withValues(alpha: 0.12);
      textColor = Colors.green.shade800;
    } else if (riskLevel == 'Medium') {
      bg = Colors.orange.withValues(alpha: 0.12);
      textColor = Colors.orange.shade800;
    } else {
      bg = Colors.red.withValues(alpha: 0.12);
      textColor = Colors.red.shade800;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مستوى الاحتياج للدعم السلوكي',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
          SizedBox(height: 8.h),
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
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        ...items.map(
          (text) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  margin: EdgeInsets.only(top: 6.h),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceOverview(
    AsyncValue<StudentPerformance> performanceAsync,
  ) {
    return performanceAsync.when(
      data: (performance) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ملخص الغياب والواجبات الدراسية',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'أيام الغياب',
                    value: performance.absenceDays.toString(),
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCard(
                    label: 'واجبات/اختبارات متأخرة',
                    value: performance.missingAssignments.toString(),
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildPledgesSummary(
    AsyncValue<int> pledgesCountAsync, {
    required bool isStaffView,
    bool compact = false,
  }) {
    return pledgesCountAsync.when(
      data: (count) {
        final hasOpenOpportunities = count > 0;

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(compact ? 16.r : 18.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.volunteer_activism, color: Colors.purple.shade700),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'فرص الدعم والتحسين السلوكي',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Center(
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: compact ? 22.sp : 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
              ),
              if (!compact) ...[
                SizedBox(height: 4.h),
                Center(
                  child: Text(
                    hasOpenOpportunities
                        ? 'فرص تحتاج إلى متابعة وخطة دعم تربوي.'
                        : 'لا توجد فرص مفتوحة حالياً، مؤشرات الالتزام جيدة.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.purple.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (isStaffView && !compact) ...[
                SizedBox(height: 6.h),
                Text(
                  'يرتبط هذا المؤشر بالتعهدات والخطط المسجَّلة في سجل الطالب السلوكي.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.fact_check, color: Colors.purple.shade200),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                height: 14.h,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildQrCard(User resolvedStudent) {
    // Priority: MN Code (Short) -> Username/Identity (Short) -> Student Code (Legacy)
    final code = resolvedStudent.mnCode ??
        resolvedStudent.identityNumber ??
        resolvedStudent.studentCode ??
        '';
    if (code.isEmpty) {
      return const SizedBox.shrink();
    }

    final isStudentCode =
        (resolvedStudent.mnCode ?? '').trim().isNotEmpty ||
        (resolvedStudent.identityNumber ?? '').trim().isNotEmpty ||
        (resolvedStudent.studentCode ?? '').trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStudentCode ? 'كود الطالب' : 'اسم المستخدم',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isStudentCode
                      ? 'استخدم هذا الكود للدخول والمتابعة.'
                      : 'يمكن استخدام هذا الباركود في المتابعة والدخول السريع.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade800,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 96.w,
            height: 96.w,
            child: QrImageView(data: code, version: QrVersions.auto),
          ),
        ],
      ),
    );
  }

  Widget _buildClassClimateIndicator(
    BuildContext context,
    AsyncValue<ClassClimateResult> classClimateAsync,
  ) {
    return classClimateAsync.when(
      data: (result) {
        if (result.status == ClassClimateStatus.unknown) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: result.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: result.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(result.icon, color: result.color, size: 28.sp),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مؤشر البيئة الصفية',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: result.color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      result.message,
                      style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildFriendsPreview(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsDetailsProvider(student));

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'شبكة الأصدقاء',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.push('/friends-list', extra: student);
                  },
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 80.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friends.length > 5 ? 5 : friends.length,
                separatorBuilder: (context, index) => SizedBox(width: 16.w),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return GestureDetector(
                    onTap: () {
                      context.push('/student-behavior-profile', extra: friend);
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(
                            friend.name.isNotEmpty ? friend.name[0] : '?',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          width: 60.w,
                          child: Text(
                            friend.name.split(' ').first,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجلات المتابعة السلوكية التفصيلية',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                context.push('/student-violations', extra: student);
              },
              icon: const Icon(Icons.track_changes),
              label: const Text('سجل المتابعة السلوكية'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                context.push('/student-attendance', extra: student);
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('سجل الغياب والحضور'),
            ),
          ],
        ),
      ],
    );
  }

  static Color _riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _translateRisk(String riskLevel) {
    switch (riskLevel) {
      case 'Low':
        return 'منخفض';
      case 'Medium':
        return 'متوسط';
      case 'High':
        return 'مرتفع';
      case 'Critical':
        return 'حرج';
      default:
        return 'غير محدد';
    }
  }

  static String _fallbackRiskLevel(int score) {
    if (score >= 90) return 'Low';
    if (score >= 75) return 'Medium';
    return 'High';
  }

  static String _fallbackTrend(int score, DateTime? lastViolationDate) {
    if (lastViolationDate == null) {
      return 'Improving';
    }

    final now = DateTime.now();
    final daysSinceLast = now.difference(lastViolationDate).inDays;

    if (daysSinceLast > 30 && score >= 80) {
      return 'Improving';
    }
    if (daysSinceLast < 7 && score < 75) {
      return 'Declining';
    }
    return 'Stable';
  }

  Widget _buildTrendChart(
    AsyncValue<List<BehaviorRecord>> behaviorAsync,
    int currentScore,
    Color color,
  ) {
    return behaviorAsync.when(
      data: (records) {
        final now = DateTime.now();
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));

        final Map<int, int> dailyDelta = {};

        for (final r in records) {
          if (r.status != BehaviorStatus.approved &&
              r.status != BehaviorStatus.warning) {
            continue;
          }

          final dayOnly = DateTime(
            r.timestamp.year,
            r.timestamp.month,
            r.timestamp.day,
          ); // ignore time
          if (dayOnly.isBefore(start)) continue;

          final diff = dayOnly.difference(start).inDays;
          if (diff < 0 || diff > 29) continue;

          dailyDelta[diff] = (dailyDelta[diff] ?? 0) + r.points;
        }

        final totalDelta = dailyDelta.values.fold<int>(0, (sum, v) => sum + v);

        double baseScore = (currentScore - totalDelta).toDouble();
        if (baseScore < 0) baseScore = 0;
        if (baseScore > 100) baseScore = 100;

        final points = <FlSpot>[];
        double running = baseScore;

        for (var i = 0; i < 30; i++) {
          final delta = dailyDelta[i] ?? 0;
          running += delta;
          if (running < 0) running = 0;
          if (running > 100) running = 100;
          points.add(FlSpot(i.toDouble(), running));
        }

        if (points.isEmpty) {
          points.addAll([
            FlSpot(0, currentScore.toDouble().clamp(0, 100)),
            FlSpot(29, currentScore.toDouble().clamp(0, 100)),
          ]);
        }

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: color),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'منحنى تطور السلوك آخر ٣٠ يومًا',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 140.h,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        spots: points,
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox(
          height: 140.h,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5.w,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  String _trendShortLabel(String trend) {
    switch (trend) {
      case 'Improving':
        return 'تحسّن';
      case 'Declining':
        return 'يحتاج لتحسين';
      default:
        return 'مستقر';
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Improving':
        return Icons.arrow_upward;
      case 'Declining':
        return Icons.arrow_downward;
      default:
        return Icons.horizontal_rule;
    }
  }

  Widget _buildFallbackInfoBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'يتم عرض المؤشرات اعتماداً على سجل الغياب والواجبات ومؤشر التميز العام، في حال تعذر تحميل نموذج التحليل المتقدم.',
              style: TextStyle(fontSize: 11.sp, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
