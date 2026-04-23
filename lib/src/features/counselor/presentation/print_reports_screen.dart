import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/domain/ministry_pdf_template.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _ReportCard {
  final String id, title, description;
  final IconData icon;
  final Color color;
  final List<String> collections;
  const _ReportCard({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.collections,
  });
}

// ─── Providers ───────────────────────────────────────────────────────────────

final printReportCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return {};

  final db = FirebaseFirestore.instance;
  final results = await Future.wait([
    db.collection('behavioral_cases').get(),
    db.collection('behavioral_violations').get(),
    db.collection('positive_behavior').get(),
  ]);

  final cases = results[0].docs;
  final violations = results[1].docs;
  final positive = results[2].docs;

  final activeCases = cases.where((d) {
    final s = (d.data()['status'] ?? '').toString().toLowerCase();
    return s != 'closed' && s != 'resolved' && s != 'مغلقة';
  }).length;

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthCases = cases.where((d) {
    final ts = (d.data()['createdAt'] as Timestamp?)?.toDate();
    return ts != null && ts.isAfter(monthStart);
  }).length;

  final followedStudents = <String>{};
  for (final doc in cases) {
    final sid = (doc.data()['studentId'] ?? '').toString();
    if (sid.isNotEmpty) followedStudents.add(sid);
  }

  return {
    'active_cases': activeCases,
    'monthly_stats': monthCases,
    'followed_students': followedStudents.length,
    'positive_behavior': positive.length,
    'total_violations': violations.length,
  };
});

final printHistoryProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('generated_reports')
      .where('schoolId', isEqualTo: schoolId)
      .snapshots()
      .map((s) {
        final docs = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        docs.sort((a, b) {
          final at = (a['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bt = (b['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
        return docs.take(20).toList();
      });
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class PrintReportsScreen extends ConsumerWidget {
  const PrintReportsScreen({super.key});

  static const _reports = [
    _ReportCard(
      id: 'active_cases',
      title: 'تقرير الحالات النشطة',
      description: 'جميع الحالات المفتوحة وقيد المعالجة حالياً',
      icon: Icons.folder_open_rounded,
      color: Color(0xFF1565C0),
      collections: ['behavioral_cases'],
    ),
    _ReportCard(
      id: 'monthly_stats',
      title: 'تقرير الإحصائيات الشهرية',
      description: 'ملخص إحصائي شامل لحالات الشهر الحالي',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF2E7D32),
      collections: ['behavioral_cases', 'behavioral_violations'],
    ),
    _ReportCard(
      id: 'followed_students',
      title: 'تقرير الطلاب المتابَعين',
      description: 'قائمة الطلاب الذين يخضعون للمتابعة الإرشادية',
      icon: Icons.people_alt_rounded,
      color: Color(0xFFE65100),
      collections: ['behavioral_cases'],
    ),
    _ReportCard(
      id: 'positive_behavior',
      title: 'تقرير السلوك الإيجابي',
      description: 'إنجازات وسلوكيات الطلاب الإيجابية المسجلة',
      icon: Icons.star_rounded,
      color: Color(0xFF6A1B9A),
      collections: ['positive_behavior'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(printReportCountsProvider);
    final historyAsync = ref.watch(printHistoryProvider);

    return Scaffold(
        backgroundColor: const Color(0xFFF1F8F1),
        body: CustomScrollView(
          slivers: [
            _buildHeader(context),
            SliverPadding(
              padding: EdgeInsets.all(16.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('أنواع التقارير',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                  SizedBox(height: 12.h),
                  countsAsync.when(
                    data: (counts) => _ReportsGrid(reports: _reports, counts: counts, ref: ref),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ReportsGrid(reports: _reports, counts: const {}, ref: ref),
                  ),
                  SizedBox(height: 24.h),
                  Text('سجل التقارير المُنشأة',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                  SizedBox(height: 12.h),
                  historyAsync.when(
                    data: (history) => _PrintHistory(history: history),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const _EmptyHistory(),
                  ),
                  SizedBox(height: 24.h),
                ]),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150.h,
      pinned: true,
      backgroundColor: const Color(0xFF1B5E20),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF66BB6A)],
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
                        child: Icon(Icons.print_rounded, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طباعة التقارير',
                              style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
                          Text('إنشاء وتصدير التقارير الرسمية',
                              style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportsGrid extends StatelessWidget {
  final List<_ReportCard> reports;
  final Map<String, int> counts;
  final WidgetRef ref;
  const _ReportsGrid({required this.reports, required this.counts, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ReportCardWidget(report: reports[0], count: counts[reports[0].id] ?? 0, ref: ref)),
            SizedBox(width: 12.w),
            Expanded(child: _ReportCardWidget(report: reports[1], count: counts[reports[1].id] ?? 0, ref: ref)),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ReportCardWidget(report: reports[2], count: counts[reports[2].id] ?? 0, ref: ref)),
            SizedBox(width: 12.w),
            Expanded(child: _ReportCardWidget(report: reports[3], count: counts[reports[3].id] ?? 0, ref: ref)),
          ],
        ),
      ],
    );
  }
}

class _ReportCardWidget extends StatefulWidget {
  final _ReportCard report;
  final int count;
  final WidgetRef ref;
  const _ReportCardWidget({required this.report, required this.count, required this.ref});

  @override
  State<_ReportCardWidget> createState() => _ReportCardWidgetState();
}

class _ReportCardWidgetState extends State<_ReportCardWidget> {
  bool _generating = false;
  String? _lastGenerated;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final user = widget.ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy', 'ar').format(now);

      // جلب اسم المدرسة
      String schoolName = 'المدرسة';
      if (schoolId.isNotEmpty) {
        try {
          final schoolDoc = await FirebaseFirestore.instance
              .collection('Schools').doc(schoolId).get();
          schoolName = schoolDoc.data()?['name'] ?? schoolName;
        } catch (_) {}
      }

      // جلب البيانات من Firebase
      final List<Map<String, dynamic>> records = [];
      for (final col in widget.report.collections) {
        final snap = await FirebaseFirestore.instance.collection(col).get();
        for (final doc in snap.docs) {
          records.add({'_col': col, 'id': doc.id, ...doc.data()});
        }
      }

      // بناء صفوف الجدول
      final tableHeaders = ['م', 'اسم الطالب', 'النوع / الحالة', 'الأولوية', 'التاريخ'];
      final tableData = records.take(100).toList().asMap().entries.map((e) {
        final i = e.key + 1;
        final r = e.value;
        final studentName = (r['studentName'] ?? r['name'] ?? '—').toString();
        final type = (r['caseType'] ?? r['violationType'] ?? r['behaviorType'] ?? r['type'] ?? '—').toString();
        final priority = (r['priority'] ?? r['level'] ?? '—').toString();
        final ts = r['createdAt'] as Timestamp? ?? r['timestamp'] as Timestamp?;
        final date = ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';
        return ['$i', studentName, type, priority, date];
      }).toList();

      // توليد PDF باستخدام كليشة وزارة التعليم
      final pdf = await MinistryPdfTemplate.generateReport(
        title: widget.report.title,
        schoolName: schoolName,
        subTitle: widget.report.description,
        tableHeaders: tableHeaders,
        tableData: tableData,
        footerText: 'أُعدّ بواسطة: ${user?.name ?? 'مستخدم'} | $dateStr',
        dateFrom: dateStr,
        dateTo: dateStr,
        includeSignatures: true,
      );

      // تحميل PDF
      final fileName = '${widget.report.title}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);

      // حفظ في Firebase
      if (schoolId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('generated_reports').add({
          'reportType': widget.report.id,
          'reportTitle': widget.report.title,
          'schoolId': schoolId,
          'generatedAt': FieldValue.serverTimestamp(),
          'recordCount': records.length,
          'generatedBy': user?.name ?? 'مستخدم',
        });
      }

      setState(() => _lastGenerated = DateFormat('HH:mm', 'ar').format(now));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8.w),
                Text('تم إنشاء ${widget.report.title} وتحميله'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
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
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.report.color;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: c.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top colored section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, c.withOpacity(0.75)], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Row(
              children: [
                Icon(widget.report.icon, color: Colors.white, size: 20.sp),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8.r)),
                  child: Text('${widget.count}', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.report.title,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: 3.h),
                Text(widget.report.description,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade500),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (_lastGenerated != null) ...[
                  SizedBox(height: 3.h),
                  Text('آخر إنشاء: $_lastGenerated', style: TextStyle(fontSize: 9.sp, color: c)),
                ],
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  height: 32.h,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? SizedBox(width: 12.w, height: 12.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.print_rounded, size: 13.sp),
                    label: Text(_generating ? 'جاري...' : 'إنشاء', style: TextStyle(fontSize: 11.sp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintHistory extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _PrintHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const _EmptyHistory();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: history.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          final ts = (item['generatedAt'] as Timestamp?)?.toDate();
          final dateStr = ts != null ? DateFormat('dd/MM/yyyy HH:mm', 'ar').format(ts) : '—';
          final title = (item['reportTitle'] ?? 'تقرير').toString();
          final count = (item['recordCount'] ?? 0) as int;
          final by = (item['generatedBy'] ?? '').toString();

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(Icons.description_rounded, color: const Color(0xFF2E7D32), size: 20.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                          Text('$dateStr • $by',
                              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text('$count سجل',
                          style: TextStyle(fontSize: 11.sp, color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              if (idx < history.length - 1)
                Divider(height: 1, indent: 16.w, endIndent: 16.w, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 50.sp, color: Colors.grey.shade300),
          SizedBox(height: 8.h),
          Text('لا يوجد سجل تقارير بعد',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
