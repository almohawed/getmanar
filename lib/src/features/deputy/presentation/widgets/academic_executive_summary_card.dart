import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../intelligence/data/firestore_school_intelligence_repository.dart';

class AcademicExecutiveSummaryCard extends ConsumerStatefulWidget {
  final String schoolId;

  const AcademicExecutiveSummaryCard({super.key, required this.schoolId});

  @override
  ConsumerState<AcademicExecutiveSummaryCard> createState() =>
      _AcademicExecutiveSummaryCardState();
}

class _AcademicExecutiveSummaryCardState
    extends ConsumerState<AcademicExecutiveSummaryCard> {
  late Future<_AcademicSummaryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadOnce();
  }

  @override
  void didUpdateWidget(covariant AcademicExecutiveSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.schoolId.trim();
    final newId = widget.schoolId.trim();
    if (oldId != newId && newId.isNotEmpty) {
      setState(() {
        _future = _loadOnce();
      });
    }
  }

  Future<_AcademicSummaryData> _loadOnce() async {
    final sid = widget.schoolId.trim();
    if (sid.isEmpty) {
      return const _AcademicSummaryData();
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'getAcademicExecutiveSummary',
      );
      final res = await callable.call({'schoolId': sid});
      final m = res.data;
      if (m is Map) {
        return _AcademicSummaryData.fromServer(Map<String, dynamic>.from(m));
      }
      return const _AcademicSummaryData();
    } catch (_) {
      return const _AcademicSummaryData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AcademicSummaryData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        final data = snap.data ?? const _AcademicSummaryData();
        final status = data.status;
        final priorities = data.priorities;
        final recommendation = data.recommendation;
        final forwardStability = data.forwardStability;
        final interventionEfficiency = data.interventionEfficiency;
        final institutionalTier = data.institutionalTier;

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Executive Intelligence Row (Top Layer)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildIntelligenceItem(
                        icon: Icons.timeline,
                        label: 'الاستقرار المستقبلي',
                        value: forwardStability.label,
                        color: forwardStability.color,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24.h,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: _buildIntelligenceItem(
                        icon: Icons.trending_up,
                        label: 'كفاءة التدخل',
                        value: '$interventionEfficiency%',
                        color: _getEfficiencyColor(
                          interventionEfficiency / 100.0,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24.h,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: _buildIntelligenceItem(
                        icon: Icons.emoji_events_outlined,
                        label: 'الأداء المؤسسي',
                        value: institutionalTier.label,
                        color: institutionalTier.color,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Summary Body
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Side Color Bar
                    Container(width: 6.w, color: status.color),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Status
                            Row(
                              children: [
                                Icon(
                                  status.icon,
                                  color: status.color,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),

                            // Priorities
                            ...priorities.map(
                              (p) => Padding(
                                padding: EdgeInsets.only(bottom: 4.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 6.h),
                                      child: Icon(
                                        Icons.circle,
                                        size: 6.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        p,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 12.h),
                            Divider(height: 1, color: Colors.grey[200]),
                            SizedBox(height: 12.h),

                            // Recommendation
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 16.sp,
                                  color: Colors.amber[700],
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'التوصية: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        TextSpan(
                                          text: recommendation,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntelligenceItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.sp, color: Colors.grey[600]),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // --- Executive Intelligence Logic ---

  _ForwardStability _calculateForwardStability(
    SchoolIntelligenceSnapshot? snapshot,
    List<RiskPrediction> risks,
    List<RemedialPlan> plans,
  ) {
    if (snapshot == null) return _ForwardStability.stable;

    final highRisks = risks.where((r) => r.riskLevel == 'RED').length;
    final overduePlans = plans.where((p) => p.status == 'overdue').length;
    final riskDensity =
        (highRisks * 2) + risks.where((r) => r.riskLevel != 'RED').length;

    // Logic: High risk density or overdue plans -> Low Stability
    if (highRisks > 3 || overduePlans > 1 || riskDensity > 10) {
      return _ForwardStability.declining;
    }

    // Logic: Moderate risks -> Warning
    if (highRisks > 0 || overduePlans > 0 || riskDensity > 5) {
      return _ForwardStability.atRisk;
    }

    return _ForwardStability.stable;
  }

  double _calculateInterventionEfficiency(List<RemedialPlan> plans) {
    if (plans.isEmpty)
      return 1.0; // Default to 100% if no plans needed yet (optimistic)

    int effectivePlans = 0;
    for (final plan in plans) {
      final isCompleted = plan.status == 'completed';
      final hasImprovement = plan.improvementScore > 0;
      final isNotOverdue = plan.status != 'overdue';

      // Weighting: Completed = 1.0, Active with improvement = 0.8, Active no improvement = 0.5, Overdue = 0.0
      if (isCompleted) {
        effectivePlans += 100; // 100%
      } else if (isNotOverdue && hasImprovement) {
        effectivePlans += 80; // 80%
      } else if (isNotOverdue) {
        effectivePlans += 50; // 50%
      } else {
        effectivePlans += 0; // 0%
      }
    }

    return (effectivePlans / plans.length) / 100.0;
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 0.8) return Colors.green;
    if (efficiency >= 0.6) return Colors.amber.shade700;
    return Colors.red;
  }

  _InstitutionalTier _calculateInstitutionalTier(
    SchoolIntelligenceSnapshot? snapshot,
    List<RemedialPlan> plans,
  ) {
    if (snapshot == null) return _InstitutionalTier.B; // Default stable

    // Base score from school health (0-100)
    double score = snapshot.schoolHealthScore;

    // Penalize for overdue plans
    final overduePlans = plans.where((p) => p.status == 'overdue').length;
    score -= (overduePlans * 5);

    if (score >= 90) return _InstitutionalTier.A;
    if (score >= 80) return _InstitutionalTier.B;
    if (score >= 70) return _InstitutionalTier.C;
    return _InstitutionalTier.D;
  }

  _ExecutiveStatus _calculateStatus(
    SchoolIntelligenceSnapshot? snapshot,
    List<RiskPrediction> risks,
    List<RemedialPlan> plans,
  ) {
    if (snapshot == null) return _ExecutiveStatus.stable;

    final riskClassesCount = snapshot.riskClasses.length;
    final riskSubjectsCount = snapshot.riskSubjects.length;
    final overduePlansCount = plans.where((p) => p.status == 'overdue').length;

    // Red Condition: Many risk classes/subjects OR overdue plans
    if (riskClassesCount > 2 ||
        riskSubjectsCount > 2 ||
        overduePlansCount > 0) {
      return _ExecutiveStatus.critical;
    }

    // Yellow Condition: Some risk indicators
    if (riskClassesCount > 0 || riskSubjectsCount > 0) {
      return _ExecutiveStatus.warning;
    }

    // Green Condition: Clean slate
    return _ExecutiveStatus.stable;
  }

  List<String> _getTopPriorities(
    SchoolIntelligenceSnapshot? snapshot,
    List<RiskPrediction> risks,
    List<RemedialPlan> plans,
  ) {
    final priorities = <String>[];

    if (snapshot != null) {
      // 1. Add specific risk classes
      for (final cls in snapshot.riskClasses.take(2)) {
        // In real app, resolve class name. For now use ID or generic text if ID looks like UUID
        // Assuming snapshot stores ID, we might show "فصل (ID)"
        priorities.add('فصل $cls يحتاج متابعة (أداء منخفض)');
      }

      // 2. Add specific risk subjects
      for (final subj in snapshot.riskSubjects.take(2)) {
        priorities.add('مادة $subj تشهد انخفاضاً في الدرجات');
      }
    }

    // 3. Overdue Plans
    final overduePlans = plans.where((p) => p.status == 'overdue').toList();
    if (overduePlans.isNotEmpty) {
      priorities.add('${overduePlans.length} خطط علاجية متأخرة التنفيذ');
    }

    // 4. Critical Student Risks (if space permits)
    if (priorities.length < 3) {
      final highRisks = risks.where((r) => r.riskLevel == 'RED').length;
      if (highRisks > 0) {
        priorities.add('$highRisks طلاب في مرحلة الخطر الأكاديمي');
      }
    }

    if (priorities.isEmpty) {
      priorities.add('لا توجد أولويات حرجة هذا الأسبوع');
    }

    return priorities.take(3).toList();
  }

  String _generateRecommendation(
    _ExecutiveStatus status,
    List<String> priorities,
  ) {
    switch (status) {
      case _ExecutiveStatus.stable:
        return 'الاستمرار في المتابعة الدورية، لا توجد مؤشرات خطر حالياً.';
      case _ExecutiveStatus.warning:
        return 'متابعة أداء الطلاب المعرضين للخطر وتحديث الخطط العلاجية.';
      case _ExecutiveStatus.critical:
        return 'تدخل فوري مطلوب لمعالجة حالات الخطر وتفعيل الخطط المتأخرة.';
    }
  }

  Widget _buildCard(
    BuildContext context,
    _ExecutiveStatus status,
    List<String> priorities,
    String recommendation,
  ) {
    final color = status.color;
    final icon = status.icon;
    final label = status.label;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Side Color Bar
            Container(width: 6.w, color: color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Status
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Priorities
                    ...priorities.map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Icon(
                                Icons.circle,
                                size: 6.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 12.h),
                    Divider(height: 1, color: Colors.grey[200]),
                    SizedBox(height: 12.h),

                    // Recommendation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16.sp,
                          color: Colors.amber[700],
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'التوصية: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                TextSpan(
                                  text: recommendation,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'جاري تحميل التحليل الأكاديمي...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicSummaryData {
  final _ExecutiveStatus status;
  final _ForwardStability forwardStability;
  final int interventionEfficiency;
  final _InstitutionalTier institutionalTier;
  final List<String> priorities;
  final String recommendation;

  const _AcademicSummaryData({
    this.status = _ExecutiveStatus.stable,
    this.forwardStability = _ForwardStability.stable,
    this.interventionEfficiency = 100,
    this.institutionalTier = _InstitutionalTier.B,
    this.priorities = const <String>[],
    this.recommendation =
        'استمر في المتابعة الدورية وتفعيل الإجراءات الوقائية.',
  });

  factory _AcademicSummaryData.fromServer(Map<String, dynamic> m) {
    final statusKey = (m['statusKey'] ?? '').toString();
    final forwardKey = (m['forwardStabilityKey'] ?? '').toString();
    final tierKey = (m['institutionalTierKey'] ?? '').toString();
    final eff = m['interventionEfficiency'];
    final effValue = eff is Map ? (eff['value'] ?? 100) : 100;
    final priorities = (m['priorities'] is List)
        ? (m['priorities'] as List).map((e) => e.toString()).toList()
        : const <String>[];
    final rec = (m['recommendation'] ?? '').toString().trim();

    return _AcademicSummaryData(
      status: _parseStatus(statusKey),
      forwardStability: _parseForward(forwardKey),
      interventionEfficiency: int.tryParse(effValue.toString()) ?? 100,
      institutionalTier: _parseTier(tierKey),
      priorities: priorities,
      recommendation: rec.isEmpty
          ? 'استمر في المتابعة الدورية وتفعيل الإجراءات الوقائية.'
          : rec,
    );
  }
}

_ExecutiveStatus _parseStatus(String key) {
  switch (key) {
    case 'critical':
      return _ExecutiveStatus.critical;
    case 'warning':
      return _ExecutiveStatus.warning;
    default:
      return _ExecutiveStatus.stable;
  }
}

_ForwardStability _parseForward(String key) {
  switch (key) {
    case 'declining':
      return _ForwardStability.declining;
    case 'atRisk':
      return _ForwardStability.atRisk;
    default:
      return _ForwardStability.stable;
  }
}

_InstitutionalTier _parseTier(String key) {
  switch (key) {
    case 'A':
      return _InstitutionalTier.A;
    case 'B':
      return _InstitutionalTier.B;
    case 'C':
      return _InstitutionalTier.C;
    case 'D':
      return _InstitutionalTier.D;
    default:
      return _InstitutionalTier.B;
  }
}

enum _ExecutiveStatus {
  stable,
  warning,
  critical;

  Color get color {
    switch (this) {
      case _ExecutiveStatus.stable:
        return Colors.green;
      case _ExecutiveStatus.warning:
        return Colors.amber.shade700;
      case _ExecutiveStatus.critical:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case _ExecutiveStatus.stable:
        return Icons.check_circle;
      case _ExecutiveStatus.warning:
        return Icons.warning_amber_rounded;
      case _ExecutiveStatus.critical:
        return Icons.report_problem;
    }
  }

  String get label {
    switch (this) {
      case _ExecutiveStatus.stable:
        return 'الحالة الأكاديمية مستقرة';
      case _ExecutiveStatus.warning:
        return 'توجد مؤشرات تحتاج متابعة';
      case _ExecutiveStatus.critical:
        return 'يوجد خطر أكاديمي يتطلب تدخل فوري';
    }
  }
}

enum _ForwardStability {
  stable,
  atRisk,
  declining;

  String get label {
    switch (this) {
      case _ForwardStability.stable:
        return 'مستقر';
      case _ForwardStability.atRisk:
        return 'تحذير';
      case _ForwardStability.declining:
        return 'منخفض';
    }
  }

  Color get color {
    switch (this) {
      case _ForwardStability.stable:
        return Colors.green;
      case _ForwardStability.atRisk:
        return Colors.amber.shade700;
      case _ForwardStability.declining:
        return Colors.red;
    }
  }
}

enum _InstitutionalTier {
  A,
  B,
  C,
  D;

  String get label {
    switch (this) {
      case _InstitutionalTier.A:
        return 'متميز (A)';
      case _InstitutionalTier.B:
        return 'مستقر (B)';
      case _InstitutionalTier.C:
        return 'يحتاج تطوير (C)';
      case _InstitutionalTier.D:
        return 'تدخل عاجل (D)';
    }
  }

  Color get color {
    switch (this) {
      case _InstitutionalTier.A:
        return Colors.green;
      case _InstitutionalTier.B:
        return Colors.blue;
      case _InstitutionalTier.C:
        return Colors.amber.shade700;
      case _InstitutionalTier.D:
        return Colors.red;
    }
  }
}
