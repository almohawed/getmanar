import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/domain/ministry_pdf_template.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final comprehensiveReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return {};

  final db = FirebaseFirestore.instance;

  final results = await Future.wait([
    db.collection('behavioral_cases').get(),
    db.collection('behavioral_violations').get(),
    db.collection('positive_behavior').get(),
    db.collection('counseling_sessions').get(),
  ]);

  final cases = results[0].docs;
  final violations = results[1].docs;
  final positive = results[2].docs;
  final sessions = results[3].docs;

  final total = cases.length;
  final resolved = cases.where((d) {
    final s = (d.data()['status'] ?? '').toString().toLowerCase();
    return s == 'closed' || s == 'resolved' || s == 'مغلقة';
  }).length;

  // Resolution days
  double totalDays = 0;
  int countWithDays = 0;
  for (final doc in cases) {
    final data = doc.data();
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final closed = (data['closedAt'] as Timestamp?)?.toDate();
    if (created != null && closed != null) {
      totalDays += closed.difference(created).inDays.toDouble();
      countWithDays++;
    }
  }
  final avgDays = countWithDays > 0 ? (totalDays / countWithDays) : 0.0;

  // Case type distribution
  final typeCounts = <String, int>{
    'سلوكي': 0,
    'أكاديمي': 0,
    'اجتماعي': 0,
    'نفسي': 0,
    'أخرى': 0,
  };
  for (final doc in cases) {
    final t = (doc.data()['caseType'] ?? doc.data()['type'] ?? '').toString();
    if (t.contains('سلوك') || t.contains('behavioral')) {
      typeCounts['سلوكي'] = (typeCounts['سلوكي'] ?? 0) + 1;
    } else if (t.contains('أكاديم') || t.contains('academic')) {
      typeCounts['أكاديمي'] = (typeCounts['أكاديمي'] ?? 0) + 1;
    } else if (t.contains('اجتماع') || t.contains('social')) {
      typeCounts['اجتماعي'] = (typeCounts['اجتماعي'] ?? 0) + 1;
    } else if (t.contains('نفس') || t.contains('psych')) {
      typeCounts['نفسي'] = (typeCounts['نفسي'] ?? 0) + 1;
    } else {
      typeCounts['أخرى'] = (typeCounts['أخرى'] ?? 0) + 1;
    }
  }

  // Monthly trend (last 6 months)
  final now = DateTime.now();
  final monthly = <String, int>{};
  for (var i = 5; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('MMM', 'ar').format(m);
    monthly[key] = 0;
  }
  for (final doc in cases) {
    final created = (doc.data()['createdAt'] as Timestamp?)?.toDate();
    if (created != null) {
      final diff = now.month - created.month + (now.year - created.year) * 12;
      if (diff >= 0 && diff < 6) {
        final key = DateFormat('MMM', 'ar').format(created);
        monthly[key] = (monthly[key] ?? 0) + 1;
      }
    }
  }

  // Top 5 students needing attention
  final studentCounts = <String, Map<String, dynamic>>{};
  for (final doc in cases) {
    final data = doc.data();
    final sid = (data['studentId'] ?? '').toString();
    final sname = (data['studentName'] ?? 'طالب').toString();
    if (sid.isNotEmpty) {
      studentCounts[sid] = {
        'name': sname,
        'count': ((studentCounts[sid]?['count'] ?? 0) as int) + 1,
      };
    }
  }
  final topStudents = studentCounts.entries.toList()
    ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

  return {
    'total': total,
    'resolved': resolved,
    'resolutionRate': total > 0 ? (resolved / total * 100).round() : 0,
    'avgDays': avgDays,
    'typeCounts': typeCounts,
    'monthly': monthly,
    'topStudents': topStudents.take(5).toList(),
    'violations': violations.length,
    'positive': positive.length,
    'sessions': sessions.length,
  };
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ComprehensiveReportScreen extends ConsumerWidget {
  const ComprehensiveReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(comprehensiveReportProvider);

    return Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        body: dataAsync.when(
          data: (data) => _Body(data: data),
          loading: () => const _LoadingView(),
          error: (e, _) => _ErrorView(error: e.toString()),
        ),
      );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(context),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildKpiRow(data),
              SizedBox(height: 20.h),
              _DonutChartCard(typeCounts: data['typeCounts'] as Map<String, int>),
              SizedBox(height: 20.h),
              _MonthlyBarChart(monthly: data['monthly'] as Map<String, int>),
              SizedBox(height: 20.h),
              _TopStudentsCard(students: data['topStudents'] as List),
              SizedBox(height: 20.h),
              _RecommendationsCard(data: data),
              SizedBox(height: 24.h),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160.h,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF4527A0), Color(0xFF6A1B9A)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.analytics_rounded, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('التقرير الشامل',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold)),
                          Text('نظرة شاملة على أداء الإرشاد',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13.sp)),
                        ],
                      ),
                      const Spacer(),
                      _ExportButton(data: data),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF1A237E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildKpiRow(Map<String, dynamic> data) {
    final kpis = [
      _KpiData('إجمالي الحالات', '${data['total']}', Icons.folder_open_rounded, const Color(0xFF3949AB)),
      _KpiData('الحالات المغلقة', '${data['resolved']}', Icons.check_circle_rounded, const Color(0xFF00897B)),
      _KpiData('نسبة الحل', '${data['resolutionRate']}%', Icons.pie_chart_rounded, const Color(0xFF8E24AA)),
      _KpiData('متوسط الأيام', '${(data['avgDays'] as double).toStringAsFixed(1)}', Icons.timer_rounded, const Color(0xFFE65100)),
    ];

    return Row(
      children: kpis.map((kpi) => Expanded(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [BoxShadow(color: kpi.color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(color: kpi.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8.r)),
                child: Icon(kpi.icon, color: kpi.color, size: 18.sp),
              ),
              SizedBox(height: 8.h),
              Text(kpi.value, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: kpi.color)),
              SizedBox(height: 2.h),
              Text(kpi.label, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600), maxLines: 2),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _ExportButton({required this.data});

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final user = ref.read(authStateProvider).value;
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy', 'ar').format(now);

      // جلب اسم المدرسة
      String schoolName = 'المدرسة';
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('Schools').doc(schoolId).get();
          schoolName = doc.data()?['name'] ?? schoolName;
        } catch (_) {}
      }

      // جلب الحالات من Firebase
      final casesSnap = await FirebaseFirestore.instance
          .collection('behavioral_cases').get();

      final tableHeaders = ['م', 'اسم الطالب', 'نوع الحالة', 'الأولوية', 'الحالة', 'التاريخ'];
      final tableData = casesSnap.docs.take(100).toList().asMap().entries.map((e) {
        final i = e.key + 1;
        final d = e.value.data();
        final name = (d['studentName'] ?? '—').toString();
        final type = (d['caseType'] ?? d['type'] ?? '—').toString();
        final priority = (d['priority'] ?? '—').toString();
        final status = (d['status'] == 'closed' || d['status'] == 'مغلقة') ? 'مغلقة' : 'نشطة';
        final ts = d['createdAt'] as Timestamp?;
        final date = ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';
        return ['$i', name, type, priority, status, date];
      }).toList();

      // إحصائيات ملخصة
      final total = widget.data['total'] ?? 0;
      final resolved = widget.data['resolved'] ?? 0;
      final rate = widget.data['resolutionRate'] ?? 0;
      final avgDays = (widget.data['avgDays'] as double? ?? 0).toStringAsFixed(1);

      final pdf = await MinistryPdfTemplate.generateReport(
        title: 'التقرير الشامل للإرشاد الطلابي',
        schoolName: schoolName,
        subTitle: 'نظرة شاملة على أداء الإرشاد | $dateStr',
        tableHeaders: tableHeaders,
        tableData: tableData,
        footerText: 'أُعدّ بواسطة: ${user?.name ?? 'مستخدم'} | $dateStr',
        dateFrom: dateStr,
        dateTo: dateStr,
        contentWidgets: [
          // ملخص إحصائي
          _buildSummaryWidget(total, resolved, rate, avgDays),
        ],
        includeSignatures: true,
      );

      final fileName = 'التقرير_الشامل_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تصدير التقرير الشامل بنجاح'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _exporting ? null : _export,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _exporting ? Colors.amber.shade300 : Colors.amber.shade600,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _exporting
                ? SizedBox(width: 16.w, height: 16.h,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.download_rounded, color: Colors.white, size: 16.sp),
            SizedBox(width: 4.w),
            Text(
              _exporting ? 'جاري...' : 'تصدير',
              style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: kpi.color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: kpi.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 22.sp),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kpi.value,
                  style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: kpi.color)),
              Text(kpi.label,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartCard extends StatelessWidget {
  final Map<String, int> typeCounts;
  const _DonutChartCard({required this.typeCounts});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF3949AB),
      const Color(0xFF00897B),
      const Color(0xFFE65100),
      const Color(0xFF8E24AA),
      const Color(0xFF546E7A),
    ];
    final total = typeCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final entries = typeCounts.entries.where((e) => e.value > 0).toList();
    final sections = entries.asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      return PieChartSectionData(
        color: colors[idx % colors.length],
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).round()}%',
        radius: 55.r,
        titleStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return _SectionCard(
      title: 'توزيع أنواع الحالات',
      icon: Icons.donut_large_rounded,
      iconColor: const Color(0xFF3949AB),
      child: Row(
        children: [
          SizedBox(
            height: 160.h,
            width: 160.w,
            child: PieChart(PieChartData(
              sections: sections,
              sectionsSpace: 3,
              centerSpaceRadius: 40.r,
            )),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: colors[idx % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text('${entry.key} (${entry.value})',
                            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, int> monthly;
  const _MonthlyBarChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final entries = monthly.entries.toList();
    final maxY = entries.isEmpty ? 10.0 : (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 2).toDouble();

    final groups = entries.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value.toDouble(),
            gradient: const LinearGradient(
              colors: [Color(0xFF4527A0), Color(0xFF6A1B9A)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 18.w,
            borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
          ),
        ],
      );
    }).toList();

    return _SectionCard(
      title: 'الاتجاه الشهري (آخر 6 أشهر)',
      icon: Icons.bar_chart_rounded,
      iconColor: const Color(0xFF4527A0),
      child: SizedBox(
        height: 180.h,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: groups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                    return Text(entries[idx].key,
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStudentsCard extends StatelessWidget {
  final List students;
  const _TopStudentsCard({required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'أكثر الطلاب احتياجاً للمتابعة',
      icon: Icons.people_alt_rounded,
      iconColor: const Color(0xFFE65100),
      child: Column(
        children: students.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value as MapEntry;
          final name = (entry.value as Map)['name'] as String;
          final count = (entry.value as Map)['count'] as int;
          final colors = [
            const Color(0xFFE53935),
            const Color(0xFFE65100),
            const Color(0xFFF9A825),
            const Color(0xFF43A047),
            const Color(0xFF1E88E5),
          ];
          return Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: colors[idx].withOpacity(0.06),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colors[idx].withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: colors[idx],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${idx + 1}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(name,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors[idx],
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text('$count حالة',
                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecommendationsCard({required this.data});

  List<String> _generateRecommendations() {
    final recs = <String>[];
    final rate = data['resolutionRate'] as int;
    final total = data['total'] as int;
    final avgDays = data['avgDays'] as double;

    if (rate < 50) {
      recs.add('نسبة الحل منخفضة (${rate}%) — يُنصح بمراجعة استراتيجيات التدخل وتكثيف الجلسات.');
    } else if (rate >= 80) {
      recs.add('أداء ممتاز في حل الحالات (${rate}%) — استمر في تطبيق المنهجية الحالية.');
    }
    if (avgDays > 14) {
      recs.add('متوسط أيام الحل مرتفع (${avgDays.toStringAsFixed(0)} يوم) — يُقترح تسريع دورة المتابعة.');
    }
    if (total > 20) {
      recs.add('عدد الحالات مرتفع — يُنصح بتفعيل برامج الوقاية والإرشاد الجماعي.');
    }
    final typeCounts = data['typeCounts'] as Map<String, int>;
    final maxType = typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (maxType.value > 0) {
      recs.add('الحالات ${maxType.key} هي الأكثر شيوعاً — يُنصح بتخصيص برامج متخصصة لها.');
    }
    if (recs.isEmpty) {
      recs.add('البيانات الحالية تشير إلى أداء متوازن. استمر في المتابعة الدورية.');
    }
    return recs;
  }

  @override
  Widget build(BuildContext context) {
    final recs = _generateRecommendations();
    return _SectionCard(
      title: 'توصيات ذكية',
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFFF9A825),
      child: Column(
        children: recs.asMap().entries.map((e) {
          return Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFFF8E1), Colors.white],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: const Color(0xFFF9A825), size: 18.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(e.value,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, height: 1.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Text(title,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }
}

pw.Widget _buildSummaryWidget(int total, int resolved, int rate, String avgDays) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('F1F8F1'),
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfColor.fromHex('2E7D32')),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _summaryItem('إجمالي الحالات', '$total'),
        _summaryItem('الحالات المغلقة', '$resolved'),
        _summaryItem('نسبة الحل', '$rate%'),
        _summaryItem('متوسط الأيام', avgDays),
      ],
    ),
  );
}

pw.Widget _summaryItem(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('2E7D32'))),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ],
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF4527A0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60.sp, color: Colors.red.shade300),
          SizedBox(height: 12.h),
          Text('حدث خطأ في تحميل البيانات', style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
