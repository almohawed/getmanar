// ignore_for_file: deprecated_member_use
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';

// Vision 2030 Colors
const _kPrimary = Color(0xFF1A237E);
const _kSecondary = Color(0xFF283593);
const _kAccent = Color(0xFF3949AB);
const _kGold = Color(0xFFFFB300);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFF57C00);
const _kDanger = Color(0xFFC62828);
const _kInfo = Color(0xFF0277BD);
const _kBg = Color(0xFFF5F7FA);

class SmartBehaviorDashboard extends ConsumerStatefulWidget {
  const SmartBehaviorDashboard({super.key});
  @override
  ConsumerState<SmartBehaviorDashboard> createState() => _SmartBehaviorDashboardState();
}

class _SmartBehaviorDashboardState extends ConsumerState<SmartBehaviorDashboard> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<Map<String, int>> _getBehaviorStats(String schoolId) async {
    if (schoolId.isEmpty) return {};
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final violationsSnap = await FirebaseFirestore.instance.collection('Schools').doc(schoolId).collection('BehaviorRecords').where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)).get();
      final casesSnap = await FirebaseFirestore.instance.collection('Schools').doc(schoolId).collection('BehaviorCases').get();
      final enhancementsSnap = await FirebaseFirestore.instance.collection('Schools').doc(schoolId).collection('BehaviorEnhancements').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)).get();
      
      int totalViolations = violationsSnap.docs.length;
      int activeCases = casesSnap.docs.where((d) => d.data()['status'] != 'closed').length;
      int closedCases = casesSnap.docs.where((d) => d.data()['status'] == 'closed').length;
      int enhancements = enhancementsSnap.docs.length;
      
      return {'violations': totalViolations, 'activeCases': activeCases, 'closedCases': closedCases, 'enhancements': enhancements};
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeroHeader(context),
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: _buildKPICards(schoolId))),
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: _buildSmartInsights(schoolId))),
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: _buildMonthlyTrend(schoolId))),
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: _buildActionButtons(context))),
              SliverToBoxAdapter(child: SizedBox(height: 40.h)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200.h,
      pinned: true,
      stretch: true,
      backgroundColor: _kPrimary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)], begin: Alignment.topRight, end: Alignment.bottomLeft)),
          child: Stack(children: [
            Positioned(top: -40.h, left: -40.w, child: Container(width: 180.w, height: 180.w, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
            Positioned(bottom: -30.h, right: -50.w, child: Container(width: 200.w, height: 200.w, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
            SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(16.w, 50.h, 16.w, 16.h), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: EdgeInsets.all(12.w), decoration: BoxDecoration(color: _kGold.withOpacity(0.2), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: _kGold.withOpacity(0.5), width: 2)), child: Icon(Icons.psychology_rounded, color: _kGold, size: 28.sp)),
                SizedBox(width: 14.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مركز السلوك والانضباط المدرسي', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Text('نظام ذكي متكامل لإدارة السلوك', style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.85), fontSize: 11.sp)),
                ])),
              ]),
              SizedBox(height: 16.h),
              Container(padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h), decoration: BoxDecoration(color: _kSuccess.withOpacity(0.2), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: _kSuccess.withOpacity(0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_rounded, color: _kSuccess, size: 14.sp),
                SizedBox(width: 5.w),
                Text('متوافق مع رؤية 2030', style: GoogleFonts.cairo(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600)),
              ])),
            ]))),
          ]),
        ),
        title: Text('السلوك والمواظبة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)),
        titlePadding: EdgeInsetsDirectional.only(start: 56.w, bottom: 14.h),
      ),
    );
  }

  Widget _buildKPICards(String schoolId) {
    return FutureBuilder<Map<String, int>>(
      future: _getBehaviorStats(schoolId),
      builder: (context, snap) {
        final stats = snap.data ?? {};
        final violations = stats['violations'] ?? 0;
        final activeCases = stats['activeCases'] ?? 0;
        final closedCases = stats['closedCases'] ?? 0;
        final enhancements = stats['enhancements'] ?? 0;
        
        return Column(children: [
          Row(children: [
            Expanded(child: _buildKPICard('المخالفات', violations.toString(), Icons.warning_rounded, _kDanger, 'هذا الشهر')),
            SizedBox(width: 8.w),
            Expanded(child: _buildKPICard('الحالات النشطة', activeCases.toString(), Icons.folder_open_rounded, _kWarning, 'قيد المتابعة')),
          ]),
          SizedBox(height: 8.h),
          Row(children: [
            Expanded(child: _buildKPICard('الحالات المغلقة', closedCases.toString(), Icons.check_circle_rounded, _kSuccess, 'تم حلها')),
            SizedBox(width: 8.w),
            Expanded(child: _buildKPICard('التعزيزات', enhancements.toString(), Icons.star_rounded, _kGold, 'هذا الشهر')),
          ]),
        ]);
      },
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))], border: Border(bottom: BorderSide(color: color, width: 2.5))),
      child: Column(children: [
        Container(padding: EdgeInsets.all(6.w), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 16.sp)),
        SizedBox(height: 6.h),
        Text(value, style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: GoogleFonts.cairo(fontSize: 9.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        SizedBox(height: 2.h),
        Container(padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)), child: Text(subtitle, style: GoogleFonts.cairo(fontSize: 7.sp, color: color))),
      ]),
    );
  }

  Widget _buildSmartInsights(String schoolId) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(24.r), boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: _kGold.withOpacity(0.2), borderRadius: BorderRadius.circular(12.r)), child: Icon(Icons.lightbulb_rounded, color: _kGold, size: 20.sp)),
          SizedBox(width: 10.w),
          Text('توصيات ذكية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h), decoration: BoxDecoration(color: _kSuccess.withOpacity(0.3), borderRadius: BorderRadius.circular(20.r)), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: _kSuccess, size: 12.sp),
            SizedBox(width: 4.w),
            Text('AI', style: GoogleFonts.cairo(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w700)),
          ])),
        ]),
        SizedBox(height: 16.h),
        _buildInsightItem(Icons.trending_down_rounded, Colors.green.shade300, 'انخفاض ملحوظ في المخالفات بنسبة 15% مقارنة بالشهر الماضي'),
        SizedBox(height: 10.h),
        _buildInsightItem(Icons.psychology_rounded, Colors.blue.shade300, 'يُنصح بتكثيف برامج التعزيز الإيجابي للطلاب المتميزين'),
        SizedBox(height: 10.h),
        _buildInsightItem(Icons.groups_rounded, Colors.amber.shade300, 'التركيز على الفصول ذات المعدل الأعلى من المخالفات'),
      ]),
    );
  }

  Widget _buildInsightItem(IconData icon, Color iconColor, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: EdgeInsets.all(6.w), decoration: BoxDecoration(color: iconColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10.r)), child: Icon(icon, color: iconColor, size: 16.sp)),
      SizedBox(width: 10.w),
      Expanded(child: Text(text, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.95), fontSize: 12.sp, height: 1.6))),
    ]);
  }

  Widget _buildMonthlyTrend(String schoolId) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r), boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8.w), decoration: BoxDecoration(color: _kInfo.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)), child: Icon(Icons.bar_chart_rounded, color: _kInfo, size: 20.sp)),
          SizedBox(width: 10.w),
          Text('اتجاه المخالفات - آخر 7 أيام', style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.w700, color: _kPrimary)),
        ]),
        SizedBox(height: 20.h),
        SizedBox(height: 180.h, child: _buildMockChart()),
      ]),
    );
  }

  Widget _buildMockChart() {
    final data = [12.0, 8.0, 15.0, 6.0, 10.0, 4.0, 7.0];
    final days = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمس', 'جمع', 'سبت'];
    final maxVal = data.reduce((a, b) => a > b ? a : b) + 5;
    
    return BarChart(
      BarChartData(
        maxY: maxVal,
        minY: 0,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28.w, getTitlesWidget: (val, meta) {
            if (val == val.roundToDouble()) return Text(val.toInt().toString(), style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade600));
            return const SizedBox.shrink();
          })),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24.h, getTitlesWidget: (val, meta) {
            final idx = val.toInt();
            if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
            return Padding(padding: EdgeInsets.only(top: 4.h), child: Text(days[idx], style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey.shade700)));
          })),
        ),
        barGroups: List.generate(data.length, (i) {
          final isToday = i == data.length - 1;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: data[i], color: isToday ? _kDanger : (data[i] > 10 ? _kWarning : _kInfo), width: 20.w, borderRadius: BorderRadius.only(topLeft: Radius.circular(6.r), topRight: Radius.circular(6.r)), backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVal, color: Colors.grey.shade100)),
          ]);
        }),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(' مخالفة', GoogleFonts.cairo(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600));
        })),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _buildActionButton(context, 'الحالات السلوكية', Icons.folder_open_rounded, _kWarning, '/behavioral-cases')),
        SizedBox(width: 12.w),
        Expanded(child: _buildActionButton(context, 'التحليلات', Icons.analytics_rounded, _kInfo, '/behavior-analysis')),
      ]),
      SizedBox(height: 12.h),
      Row(children: [
        Expanded(child: _buildActionButton(context, 'التقارير', Icons.assessment_rounded, _kPrimary, '/behavior-reports')),
        SizedBox(width: 12.w),
        Expanded(child: _buildActionButton(context, 'التعزيز', Icons.star_rounded, _kGold, '/behavior-enhancement')),
      ]),
    ]);
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, String route) {
    return InkWell(
      onTap: () => context.push(route),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))], border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22.sp),
          SizedBox(width: 8.w),
          Text(label, style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
