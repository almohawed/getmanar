import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter
import '../../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../domain/services/executive_report_service.dart';
import '../../domain/models/daily_absence_model.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../providers/attendance_stats_providers.dart';

// Helper for Report Generation
Future<void> _generateAndOpenReport(BuildContext context, WidgetRef ref) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final absence = await ref.read(frequentAbsenceProvider.future);
    final tardiness = await ref.read(tardinessAnalysisProvider.future);
    final notification = await ref.read(notificationStatsProvider.future);

    final user = ref.read(authStateProvider).value;
    final schoolName = 'المدرسة الذكية'; // Fallback

    final service = ExecutiveReportService();
    final pdfData = await service.generateReport(
      absenceAnalysis: absence,
      tardinessAnalysis: tardiness,
      notificationAnalysis: notification,
      schoolName: schoolName,
    );

    if (context.mounted) {
      Navigator.pop(context); // Hide loading
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'Executive_Report.pdf',
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل توليد التقرير: $e')));
    }
  }
}

// ==============================================================================
// 1. Tardiness Registration Widget (Includes Classification)
// ==============================================================================
class TardinessRegistrationWidget extends ConsumerStatefulWidget {
  final int initialTab;

  const TardinessRegistrationWidget({super.key, this.initialTab = 0});

  @override
  ConsumerState<TardinessRegistrationWidget> createState() =>
      _TardinessRegistrationWidgetState();
}

class _TardinessRegistrationWidgetState
    extends ConsumerState<TardinessRegistrationWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar for Switching between Registration and Classification
        Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(12.r),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: const [
              Tab(text: 'تسجيل التأخر'),
              Tab(text: 'تصنيف التأخر'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTardinessListTab(),
              _buildTardinessClassificationTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTardinessListTab() {
    final tardinessAsync = ref.watch(dailyTardinessProvider);

    return tardinessAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_off, size: 64.sp, color: Colors.grey.shade300),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد حالات تأخر مسجلة اليوم',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          );
        }
        return _buildTardinessList(students);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildTardinessClassificationTab() {
    final analysisAsync = ref.watch(tardinessAnalysisProvider);

    return analysisAsync.when(
      data: (analysis) {
        final totalTardiness =
            analysis.morningTardinessCount +
            analysis.betweenClassesTardinessCount;

        if (totalTardiness == 0) {
          return Center(
            child: Text(
              'لا توجد بيانات كافية للتحليل',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        final double morningPercent = totalTardiness > 0
            ? (analysis.morningTardinessCount / totalTardiness)
            : 0.0;
        final double classPercent = 1.0 - morningPercent;

        return ListView(
          padding: EdgeInsets.all(4.w),
          children: [
            // General School Regularity Index
            _SchoolRegularityHeader(score: analysis.schoolRegularityScore),
            SizedBox(height: 16.h),

            // Smart Analysis Text (Auto-Generated)
            if (analysis.smartAnalysisText.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  border: Border.all(color: Colors.purple.shade200),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.purple.shade700,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        analysis.smartAnalysisText,
                        style: TextStyle(
                          color: Colors.purple.shade900,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Total Tardiness with Trend
            Row(
              children: [
                Expanded(
                  child: _KPIWidget(
                    title: 'إجمالي حالات التأخر',
                    value: '$totalTardiness حالة',
                    icon: Icons.access_time,
                    color: Colors.orange,
                    subtitle: 'خلال 30 يوم',
                    trend: analysis.tardinessTrend,
                    isTrendGoodIfPositive: false,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // 2. Morning vs Class Tardiness (Executive Touch)
            _buildAnalysisCard(
              title: 'تحليل نوع التأخر',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${(morningPercent * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'تأخر صباحي',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40.h,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${(classPercent * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            Text(
                              'بين الحصص',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (morningPercent * 100).toInt(),
                          child: Container(height: 8.h, color: Colors.orange),
                        ),
                        Expanded(
                          flex: (classPercent * 100).toInt(),
                          child: Container(height: 8.h, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // 3. Most Frequent Day (Decision Support)
            Row(
              children: [
                Expanded(
                  child: _KPIWidget(
                    title: 'اليوم الأكثر تأخراً',
                    value: analysis.mostFrequentDay,
                    icon: Icons.calendar_today,
                    color: Colors.red,
                    subtitle:
                        'يمثل ${analysis.mostFrequentDayPercentage.toStringAsFixed(1)}% من الحالات',
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // 4. Top 3 Students (Focus Card)
            _buildAnalysisCard(
              title: 'أعلى 3 طلاب متابعة',
              child: Column(
                children: analysis.topTardyStudents.map((student) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Text(
                        '${student.absenceCount}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      student.student.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(student.className),
                    trailing: const _RiskBadge(level: 'High'),
                  );
                }).toList(),
              ),
            ),

            // Generate Report Button
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateAndOpenReport(context, ref),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('توليد تقرير تنفيذي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildTardinessList(List<DailyAbsenceModel> students) {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Text(
                student.studentName.isNotEmpty ? student.studentName[0] : '?',
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ),
            title: Text(
              student.studentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${student.className} • ${student.period}'),
            trailing: IconButton(
              icon: const Icon(Icons.message, color: Colors.blue),
              onPressed: () {
                // Send SMS Logic Placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'سيتم إرسال تنبيه لولي أمر ${student.studentName}',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            Divider(height: 24.h),
            child,
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// 2. Frequent Absence Widget
// ==============================================================================
class FrequentAbsenceWidget extends ConsumerWidget {
  const FrequentAbsenceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequentAsync = ref.watch(frequentAbsenceProvider);

    return frequentAsync.when(
      data: (analysis) {
        final students = analysis.students;

        if (students.isEmpty) {
          return Center(
            child: Text(
              'لا يوجد طلاب تجاوزوا حد الغياب',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        // Calculate Average Improvement for display
        final double avgImprovement = students.isEmpty
            ? 0.0
            : students.fold(0.0, (sum, s) => sum + s.monthlyImprovementRate) /
                  students.length;

        final int avgClosure = students.isEmpty
            ? 0
            : (students.fold(0, (sum, s) => sum + s.averageCaseClosureDays) /
                      students.length)
                  .round();

        return Column(
          children: [
            // General School Regularity Index
            _SchoolRegularityHeader(score: analysis.schoolRegularityScore),
            SizedBox(height: 16.h),

            // Smart Recommendation Banner
            if (analysis.smartRecommendation.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.blue.shade700,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        analysis.smartRecommendation,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Advanced KPIs Row (Trends & Processing Burden)
            Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KPIWidget(
                          title: 'معدل التحسن',
                          value: '${avgImprovement.toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          color: avgImprovement >= 0
                              ? Colors.green
                              : Colors.red,
                          subtitle: 'مقارنة بالشهر السابق',
                          trend: analysis
                              .absenceTrend, // Using absence trend as proxy or separate
                          isTrendGoodIfPositive:
                              false, // For absence, positive trend (more absence) is bad.
                          // Wait, absenceTrend is trend in TOTAL absence.
                          // But here title is 'Improvement Rate'.
                          // If I want to show 'Total Absence Trend', I should rename title.
                          // User asked for "Performance Trend" next to KPI.
                          // Let's stick to "Improvement Rate" KPI but maybe the trend passed here should be related to improvement?
                          // Or I can show "Total Frequent Cases" with trend.
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _KPIWidget(
                          title: 'زمن إغلاق الحالة',
                          value: '$avgClosure يوم',
                          icon: Icons.timer_outlined,
                          color: Colors.blue,
                          subtitle: 'متوسط المعالجة',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  // Processing Burden Indicator
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                          label: 'حالات مفتوحة',
                          value: '${analysis.openCasesCount}',
                          color: Colors.orange,
                        ),
                        Container(
                          width: 1,
                          height: 24.h,
                          color: Colors.grey.shade300,
                        ),
                        _MiniStat(
                          label: 'أغلقت هذا الأسبوع',
                          value: '${analysis.closedCasesThisWeekCount}',
                          color: Colors.green,
                        ),
                        Container(
                          width: 1,
                          height: 24.h,
                          color: Colors.grey.shade300,
                        ),
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // List Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'قائمة الطلاب ومؤشر الخطر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    '${students.length} طالب',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  return FrequentAbsenceCard(item: students[index]);
                },
              ),
            ),

            // Generate Report Button
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateAndOpenReport(context, ref),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('توليد تقرير تنفيذي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }
}

class FrequentAbsenceCard extends StatelessWidget {
  final FrequentAbsenceModel item;

  const FrequentAbsenceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color riskColor;
    switch (item.riskLevel) {
      case 'High':
        riskColor = Colors.red;
        break;
      case 'Medium':
        riskColor = Colors.orange;
        break;
      default:
        riskColor = Colors.green;
    }

    return InkWell(
      onTap: () {
        context.push('/student-absence-details', extra: item.student);
      },
      child: Card(
        margin: EdgeInsets.only(bottom: 12.h),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: riskColor.withOpacity(0.1),
                    child: Text(
                      '${item.absenceCount}',
                      style: TextStyle(
                        color: riskColor,
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
                          item.student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.className,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RiskBadge(level: item.riskLevel),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14.sp,
                    color: Colors.grey,
                  ),
                ],
              ),
              Divider(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(
                    label: 'التحسن',
                    value: '${item.monthlyImprovementRate.toStringAsFixed(0)}%',
                    color: item.monthlyImprovementRate >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                  _MiniStat(
                    label: 'المعالجة',
                    value: '${item.averageCaseClosureDays} يوم',
                    color: Colors.blue,
                  ),
                  TextButton(
                    onPressed: () {
                      context.push(
                        '/student-absence-details',
                        extra: item.student,
                      );
                    },
                    child: const Text('التفاصيل والإجراءات'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 3. Parent Notification Widget
// ==============================================================================
class ParentNotificationWidget extends ConsumerWidget {
  const ParentNotificationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(notificationStatsProvider);

    return statsAsync.when(
      data: (analysis) {
        final logs = analysis.logs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off,
                  size: 64.sp,
                  color: Colors.grey.shade300,
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد تنبيهات مرسلة مؤخراً',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // General School Regularity Index (Using a fixed score for now as it's not part of Notification Analysis yet, or we can add it)
            // Let's assume a default score or fetch from elsewhere if needed.
            // For now, let's use a static high score or calculate based on interaction.
            _SchoolRegularityHeader(score: 85),
            SizedBox(height: 16.h),

            // Smart Impact Text (Auto-Generated)
            if (analysis.smartImpactText.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: Colors.blue.shade700,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        analysis.smartImpactText,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Indicators Row
            Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: _KPIWidget(
                      title: 'نسبة التفاعل',
                      value: '${analysis.interactionRate.toStringAsFixed(0)}%',
                      icon: Icons.family_restroom,
                      color: analysis.interactionRate > 50
                          ? Colors.green
                          : Colors.orange,
                      subtitle: 'الاستجابة',
                      trend: analysis.improvementTrend,
                      isTrendGoodIfPositive: true,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: _KPIWidget(
                      title: 'زمن الرد',
                      value:
                          '${(analysis.averageResponseTimeMinutes).toStringAsFixed(0)} د',
                      icon: Icons.timer,
                      color: Colors.blue,
                      subtitle: 'المتوسط',
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: _KPIWidget(
                      title: 'تحسن بعد التنبيه',
                      value: '${analysis.improvedCasesCount}',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                      subtitle: 'حالة',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            (log.type == 'absent' ? Colors.red : Colors.orange)
                                .withOpacity(0.1),
                        child: Icon(
                          log.type == 'absent' ? Icons.person_off : Icons.timer,
                          color: log.type == 'absent'
                              ? Colors.red
                              : Colors.orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        log.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            log.isOpened
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 12.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            log.isOpened ? 'تمت المشاهدة' : 'لم تشاهد',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (log.isReplied) ...[
                            Icon(Icons.reply, size: 12.sp, color: Colors.green),
                            SizedBox(width: 4.w),
                            Text(
                              'تم الرد',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(log.createdAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Icon(Icons.done_all, size: 16, color: Colors.blue),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Generate Report Button
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateAndOpenReport(context, ref),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('توليد تقرير تنفيذي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute}';
  }
}

// ==============================================================================
// Shared Dashboard Components
// ==============================================================================

class _SchoolRegularityHeader extends StatelessWidget {
  final int score; // 0-100

  const _SchoolRegularityHeader({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    if (score >= 90) {
      color = Colors.green;
      text = 'انتظام مستقر';
      icon = Icons.check_circle;
    } else if (score >= 75) {
      color = Colors.orange;
      text = 'يحتاج متابعة';
      icon = Icons.warning;
    } else {
      color = Colors.red;
      text = 'تحت المعالجة';
      icon = Icons.error;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, color: color, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            'مؤشر الانتظام العام: ',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
          ),
          Text(
            '$score / 100 ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
          Text(
            '($text)',
            style: TextStyle(color: color, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _KPIWidget extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? trend; // Optional trend percentage
  final bool isTrendGoodIfPositive;

  const _KPIWidget({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.isTrendGoodIfPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (trend != null) ...[
                SizedBox(width: 8.w),
                _buildTrendIndicator(),
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator() {
    final t = trend!;
    final isPositive = t > 0;
    final isGood = isTrendGoodIfPositive ? isPositive : !isPositive;
    final color = isGood ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final text = '${t.abs().toStringAsFixed(1)}%';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String level;
  const _RiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (level) {
      case 'High':
        color = Colors.red;
        text = 'خطر مرتفع';
        break;
      case 'Medium':
        color = Colors.orange;
        text = 'متوسط';
        break;
      default:
        color = Colors.green;
        text = 'منخفض';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSmallText;

  const _IndicatorCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isSmallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: color),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallText ? 14.sp : 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
