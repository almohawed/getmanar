// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_controller.dart';
import 'providers/daily_absence_provider.dart';
import 'providers/attendance_stats_providers.dart';
import '../domain/models/daily_absence_model.dart';

const _kPrimary   = Color(0xFF004D40);
const _kSecondary = Color(0xFF00897B);
const _kAccent    = Color(0xFF26C6DA);
const _kGold      = Color(0xFFFFB300);
const _kSuccess   = Color(0xFF43A047);
const _kWarning   = Color(0xFFF57C00);
const _kDanger    = Color(0xFFE53935);
const _kBg        = Color(0xFFF0F7F5);

final _weeklyTrendProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) return List.filled(7, 0);
  final schoolId = user.schoolId!;
  final now = DateTime.now();
  final List<double> counts = [];
  for (int i = 6; i >= 0; i--) {
    final day = DateTime(now.year, now.month, now.day - i);
    final next = day.add(const Duration(days: 1));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('StudentAttendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('date', isLessThan: Timestamp.fromDate(next))
          .where('status', isEqualTo: 'absent')
          .count().get();
      counts.add((snap.count ?? 0).toDouble());
    } catch (_) { counts.add(0); }
  }
  return counts;
});

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  _RingPainter({required this.progress, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final bgPaint = Paint()..color = backgroundColor..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    final fgPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class SmartAttendanceDashboard extends ConsumerStatefulWidget {
  const SmartAttendanceDashboard({super.key});
  @override
  ConsumerState<SmartAttendanceDashboard> createState() => _SmartAttendanceDashboardState();
}

class _SmartAttendanceDashboardState extends ConsumerState<SmartAttendanceDashboard> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _ringController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<int> _getTotalStudents(String schoolId) async {
    if (schoolId.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance.collection('Schools').doc(schoolId).collection('Students').count().get();
      return snap.count ?? 0;
    } catch (_) { return 0; }
  }

  Color _rateColor(double rate) {
    if (rate >= 90) return _kSuccess;
    if (rate >= 70) return _kWarning;
    return _kDanger;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return name.isNotEmpty ? name[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final absences = ref.watch(dailyAbsenceProvider).value ?? [];
    final tardiness = ref.watch(dailyTardinessProvider).value ?? [];

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeroHeader(context, absences, tardiness, schoolId),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0), child: _buildAttendanceRateCard(absences.length, tardiness.length, schoolId))),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0), child: _buildQuickStatsRow(absences.length, tardiness.length, schoolId))),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0), child: _buildSmartInsightsCard(absences, tardiness))),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 8.h), child: _buildSectionHeader('الطلاب الغائبون والمتأخرون', Icons.people_alt_rounded, '${absences.length + tardiness.length} طالب'))),
              _buildStudentsList(context, absences, tardiness),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0), child: _buildActionButtons(context))),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 40.h), child: _buildWeeklyTrendChart())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, List<DailyAbsenceModel> absences, List<DailyAbsenceModel> tardiness, String schoolId) {
    final now = DateTime.now();
    String dateStr;
    try { dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now); } catch (_) { dateStr = '${now.day}/${now.month}/${now.year}'; }

    return SliverAppBar(
      expandedHeight: 230.h,
      pinned: true,
      stretch: true,
      backgroundColor: _kPrimary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
      actions: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            margin: EdgeInsets.only(left: 12.w, top: 10.h, bottom: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7.w, height: 7.w, decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle)),
              SizedBox(width: 5.w),
              Text('مباشر', style: GoogleFonts.cairo(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF003D33), _kPrimary, _kSecondary, _kAccent], begin: Alignment.topRight, end: Alignment.bottomLeft),
          ),
          child: Stack(children: [
            Positioned(top: -50.h, left: -50.w, child: Container(width: 200.w, height: 200.w, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
            Positioned(bottom: -30.h, right: -40.w, child: Container(width: 160.w, height: 160.w, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 52.h, 16.w, 16.h),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: _kGold.withOpacity(0.4), width: 1)),
                      child: Icon(Icons.school_rounded, color: Colors.white, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('مركز الحضور والانضباط المدرسي', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                      Text(dateStr, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.75), fontSize: 10.5.sp)),
                    ])),
                  ]),
                  SizedBox(height: 16.h),
                  FutureBuilder<int>(
                    future: _getTotalStudents(schoolId),
                    builder: (context, snap) {
                      final total = snap.data ?? 0;
                      final absCount = absences.length;
                      final tardCount = tardiness.length;
                      final present = total > 0 ? total - absCount : 0;
                      final rate = total > 0 ? ((present / total) * 100).clamp(0, 100).toDouble() : 0.0;
                      return Row(children: [
                        _buildKpiChip('نسبة الحضور', total > 0 ? '${rate.toStringAsFixed(1)}%' : '—', Icons.trending_up_rounded, _kSuccess),
                        SizedBox(width: 8.w),
                        _buildKpiChip('الغائبون', '$absCount', Icons.person_off_rounded, _kDanger),
                        SizedBox(width: 8.w),
                        _buildKpiChip('المتأخرون', '$tardCount', Icons.schedule_rounded, _kWarning),
                        SizedBox(width: 8.w),
                        _buildKpiChip('الإجمالي', '$total', Icons.people_rounded, _kAccent),
                      ]);
                    },
                  ),
                ]),
              ),
            ),
          ]),
        ),
        title: Text('لوحة الحضور الذكية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
        titlePadding: EdgeInsetsDirectional.only(start: 56.w, bottom: 14.h),
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.45), width: 1),
          boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(height: 2.h),
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.82), fontSize: 8.sp), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildAttendanceRateCard(int absCount, int tardCount, String schoolId) {
    return FutureBuilder<int>(
      future: _getTotalStudents(schoolId),
      builder: (context, snap) {
        final total = snap.data ?? 0;
        final present = total > 0 ? (total - absCount).clamp(0, total) : 0;
        final rate = total > 0 ? (present / total * 100).clamp(0, 100).toDouble() : 0.0;
        final rateColor = _rateColor(rate);

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            AnimatedBuilder(
              animation: _ringAnimation,
              builder: (context, _) {
                return SizedBox(
                  width: 110.w,
                  height: 110.w,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: Size(110.w, 110.w),
                      painter: _RingPainter(progress: _ringAnimation.value * rate / 100, color: rateColor, backgroundColor: rateColor.withOpacity(0.12)),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(rate * _ringAnimation.value).toStringAsFixed(0)}%', style: GoogleFonts.cairo(fontSize: 22.sp, fontWeight: FontWeight.w800, color: rateColor)),
                      Text('حضور', style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade500)),
                    ]),
                  ]),
                );
              },
            ),
            SizedBox(width: 20.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نسبة الحضور الكلية اليوم', style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _kPrimary)),
              SizedBox(height: 10.h),
              _buildRateRow(Icons.check_circle_rounded, 'حاضر', '$present', _kSuccess),
              SizedBox(height: 4.h),
              _buildRateRow(Icons.cancel_rounded, 'غائب', '$absCount', _kDanger),
              SizedBox(height: 4.h),
              _buildRateRow(Icons.access_time_rounded, 'متأخر', '$tardCount', _kWarning),
              SizedBox(height: 4.h),
              _buildRateRow(Icons.people_rounded, 'الإجمالي', '$total', _kPrimary),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(color: rateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: rateColor.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(rate >= 90 ? Icons.sentiment_very_satisfied_rounded : rate >= 70 ? Icons.sentiment_neutral_rounded : Icons.sentiment_dissatisfied_rounded, color: rateColor, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text(rate >= 90 ? 'ممتاز' : rate >= 70 ? 'مقبول' : 'يحتاج تدخل', style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.w600, color: rateColor)),
                ]),
              ),
            ])),
          ]),
        );
      },
    );
  }

  Widget _buildRateRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 13.sp),
      SizedBox(width: 5.w),
      Text(label, style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey.shade600)),
      const Spacer(),
      Text(value, style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildQuickStatsRow(int absCount, int tardCount, String schoolId) {
    return FutureBuilder<int>(
      future: _getTotalStudents(schoolId),
      builder: (context, snap) {
        final total = snap.data ?? 0;
        final present = total > 0 ? (total - absCount).clamp(0, total) : 0;
        return Row(children: [
          _buildStatCard('حاضر', '$present', Icons.how_to_reg_rounded, _kSuccess),
          SizedBox(width: 8.w),
          _buildStatCard('غائب', '$absCount', Icons.person_off_rounded, _kDanger),
          SizedBox(width: 8.w),
          _buildStatCard('متأخر', '$tardCount', Icons.schedule_rounded, _kWarning),
          SizedBox(width: 8.w),
          _buildStatCard('الكل', '$total', Icons.people_rounded, _kPrimary),
        ]);
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18.sp)),
          SizedBox(height: 6.h),
          Text(value, style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildSmartInsightsCard(List<DailyAbsenceModel> absences, List<DailyAbsenceModel> tardiness) {
    final frequentAsync = ref.watch(frequentAbsenceProvider);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10.r)), child: Icon(Icons.auto_awesome_rounded, color: Colors.amber.shade300, size: 18.sp)),
          SizedBox(width: 10.w),
          Text('توصيات ذكية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)),
          const Spacer(),
          frequentAsync.when(
            data: (analysis) {
              final trend = analysis.absenceTrend;
              final isUp = trend > 0;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: isUp ? _kDanger.withOpacity(0.25) : _kSuccess.withOpacity(0.25), borderRadius: BorderRadius.circular(20.r)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: isUp ? _kDanger : _kSuccess, size: 14.sp),
                  SizedBox(width: 3.w),
                  Text('${trend.abs().toStringAsFixed(1)}%', style: GoogleFonts.cairo(color: isUp ? _kDanger : _kSuccess, fontSize: 11.sp, fontWeight: FontWeight.w700)),
                ]),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ]),
        SizedBox(height: 14.h),
        _buildInsightItem(Icons.warning_amber_rounded, Colors.amber.shade300,
          absences.isEmpty ? 'لا يوجد غياب مسجل اليوم — أداء ممتاز!' : 'يوجد ${absences.length} طالب غائب اليوم، يُنصح بالتواصل مع أولياء الأمور.'),
        SizedBox(height: 8.h),
        _buildInsightItem(Icons.access_time_filled_rounded, Colors.orange.shade300,
          tardiness.isEmpty ? 'لا يوجد تأخر مسجل اليوم.' : 'تأخر ${tardiness.length} طالب — راجع الطابور الصباحي.'),
        SizedBox(height: 8.h),
        frequentAsync.when(
          data: (analysis) => _buildInsightItem(Icons.lightbulb_rounded, Colors.cyan.shade300,
            analysis.smartRecommendation.isNotEmpty ? analysis.smartRecommendation : 'استمر في متابعة الحضور اليومي لتحسين الانضباط.'),
          loading: () => _buildInsightItem(Icons.lightbulb_rounded, Colors.cyan.shade300, 'جارٍ تحليل البيانات...'),
          error: (_, __) => _buildInsightItem(Icons.lightbulb_rounded, Colors.cyan.shade300, 'تعذّر تحميل التوصيات.'),
        ),
      ]),
    );
  }

  Widget _buildInsightItem(IconData icon, Color iconColor, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: EdgeInsets.all(6.w), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8.r)), child: Icon(icon, color: iconColor, size: 14.sp)),
      SizedBox(width: 10.w),
      Expanded(child: Text(text, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.9), fontSize: 11.5.sp, height: 1.5))),
    ]);
  }

  Widget _buildSectionHeader(String title, IconData icon, String badge) {
    return Row(children: [
      Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10.r)), child: Icon(icon, color: _kPrimary, size: 18.sp)),
      SizedBox(width: 10.w),
      Text(title, style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w700, color: _kPrimary)),
      const Spacer(),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(20.r)),
        child: Text(badge, style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.w600, color: _kPrimary)),
      ),
    ]);
  }

  Widget _buildStudentsList(BuildContext context, List<DailyAbsenceModel> absences, List<DailyAbsenceModel> tardiness) {
    final all = [
      ...absences.map((a) => MapEntry('absent', a)),
      ...tardiness.map((t) => MapEntry('late', t)),
    ];

    if (all.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Container(
            padding: EdgeInsets.all(30.w),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), boxShadow: [BoxShadow(color: _kSuccess.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))]),
            child: Column(children: [
              Icon(Icons.check_circle_outline_rounded, color: _kSuccess, size: 48.sp),
              SizedBox(height: 12.h),
              Text('جميع الطلاب حاضرون اليوم', style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w700, color: _kSuccess)),
              SizedBox(height: 4.h),
              Text('لا يوجد غياب أو تأخر مسجل', style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey.shade500)),
            ]),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = all[index];
          final isAbsent = entry.key == 'absent';
          final student = entry.value;
          final color = isAbsent ? _kDanger : _kWarning;
          final statusLabel = isAbsent ? 'غائب' : 'متأخر';
          final statusIcon = isAbsent ? Icons.person_off_rounded : Icons.access_time_rounded;

          return Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
                border: Border(right: BorderSide(color: color, width: 4)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: color.withOpacity(0.12),
                    child: Text(_initials(student.studentName), style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w700, color: color)),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(student.studentName, style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                    SizedBox(height: 3.h),
                    Row(children: [
                      Icon(Icons.class_rounded, size: 11.sp, color: Colors.grey.shade500),
                      SizedBox(width: 3.w),
                      Text(student.className, style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade600)),
                      SizedBox(width: 8.w),
                      Icon(Icons.schedule_rounded, size: 11.sp, color: Colors.grey.shade500),
                      SizedBox(width: 3.w),
                      Text('الحصة: ${student.period}', style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade600)),
                    ]),
                  ])),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: color.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, color: color, size: 12.sp),
                      SizedBox(width: 4.w),
                      Text(statusLabel, style: GoogleFonts.cairo(fontSize: 10.sp, fontWeight: FontWeight.w700, color: color)),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
        childCount: all.length,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/attendance'),
          icon: Icon(Icons.how_to_reg_rounded, size: 18.sp),
          label: Text('تسجيل الحضور', style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            elevation: 4,
          ),
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/school-attendance-dashboard'),
          icon: Icon(Icons.bar_chart_rounded, size: 18.sp),
          label: Text('تقرير الغياب', style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _kPrimary,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r), side: const BorderSide(color: _kPrimary, width: 1.5)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Widget _buildWeeklyTrendChart() {
    final trendAsync = ref.watch(_weeklyTrendProvider);
    final days = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمس', 'جمع', 'سبت'];
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      const names = ['اثن', 'ثلا', 'أرب', 'خمس', 'جمع', 'سبت', 'أحد'];
      return names[(d.weekday - 1) % 7];
    });

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10.r)), child: Icon(Icons.bar_chart_rounded, color: _kPrimary, size: 18.sp)),
          SizedBox(width: 10.w),
          Text('اتجاه الغياب - آخر 7 أيام', style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w700, color: _kPrimary)),
        ]),
        SizedBox(height: 20.h),
        trendAsync.when(
          data: (counts) {
            final maxVal = counts.isEmpty ? 1.0 : (counts.reduce((a, b) => a > b ? a : b) + 2);
            return SizedBox(
              height: 160.h,
              child: BarChart(
                BarChartData(
                  maxY: maxVal,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28.w, getTitlesWidget: (val, meta) {
                      if (val == val.roundToDouble()) {
                        return Text(val.toInt().toString(), style: GoogleFonts.cairo(fontSize: 9.sp, color: Colors.grey.shade500));
                      }
                      return const SizedBox.shrink();
                    })),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24.h, getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(dayLabels[idx], style: GoogleFonts.cairo(fontSize: 9.sp, color: Colors.grey.shade600)),
                      );
                    })),
                  ),
                  barGroups: List.generate(counts.length, (i) {
                    final isToday = i == counts.length - 1;
                    final val = counts[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: val == 0 ? 0.1 : val,
                        color: isToday ? _kDanger : (val > 5 ? _kWarning : _kSecondary),
                        width: 18.w,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(6.r), topRight: Radius.circular(6.r)),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVal, color: Colors.grey.shade100),
                      ),
                    ]);
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} غائب',
                          GoogleFonts.cairo(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => SizedBox(height: 160.h, child: const Center(child: CircularProgressIndicator())),
          error: (_, __) => SizedBox(height: 160.h, child: Center(child: Text('تعذّر تحميل البيانات', style: GoogleFonts.cairo(color: Colors.grey)))),
        ),
        SizedBox(height: 12.h),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildLegendDot(_kSecondary, 'طبيعي'),
          SizedBox(width: 16.w),
          _buildLegendDot(_kWarning, 'مرتفع'),
          SizedBox(width: 16.w),
          _buildLegendDot(_kDanger, 'اليوم'),
        ]),
      ]),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10.w, height: 10.w, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      SizedBox(width: 5.w),
      Text(label, style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade600)),
    ]);
  }
}
