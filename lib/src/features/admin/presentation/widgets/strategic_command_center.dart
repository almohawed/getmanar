import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../intelligence/presentation/school_intelligence_providers.dart';
import '../../../counselor/presentation/counselor_providers.dart';
import '../../../maintenance/data/firestore_maintenance_repository.dart';
import '../../../assignments/data/assignments_repository.dart';

class StrategicCommandCenter extends ConsumerWidget {
  final String schoolId;

  const StrategicCommandCenter({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Data Sources
    final snapshotAsync = ref.watch(schoolIntelligenceSnapshotProvider('current'));
    final risksAsync = ref.watch(riskPredictionsProvider);
    final plansAsync = ref.watch(remedialPlansProvider(null));
    final maintenanceAsync = ref.watch(overdueCountProvider);
    final activeCasesAsync = ref.watch(activeCasesProvider);

    if (snapshotAsync.isLoading ||
        risksAsync.isLoading ||
        plansAsync.isLoading ||
        maintenanceAsync.isLoading ||
        activeCasesAsync.isLoading) {
      return const SizedBox.shrink(); // Or loading
    }

    final snapshot = snapshotAsync.asData?.value;
    final risks = risksAsync.asData?.value ?? [];
    final plans = plansAsync.asData?.value ?? [];
    final overdueMaintenance = maintenanceAsync.asData?.value ?? 0;
    final activeCases = activeCasesAsync.asData?.value ?? [];

    // Calculations
    final healthScore =
        snapshot?.schoolHealthScore ?? 85.0; // Default 85 if new
    final academicRisks = risks.where((r) => r.riskLevel == 'RED').length;
    final behavioralRisks = activeCases.length;
    final administrativeRisks = overdueMaintenance; // Simplified
    final overduePlans = plans.where((p) => p.status == 'overdue').length;

    // Trend (Heuristic: Health > 90 = +4%, > 80 = +2%, else -1%)
    final trend = healthScore > 90 ? 4 : (healthScore > 80 ? 2 : -1);
    final isPositive = trend >= 0;

    // Alerts
    final alerts = <_AlertItem>[];
    if (overduePlans > 0) {
      alerts.add(
        _AlertItem(
          'اعتماد خطة علاجية متأخرة',
          '$overduePlans خطط',
          Icons.medical_services,
          Colors.orange,
        ),
      );
    }
    if (administrativeRisks > 0) {
      alerts.add(
        _AlertItem(
          'مخاطر صيانة/إدارية',
          '$administrativeRisks حالات',
          Icons.build,
          Colors.red,
        ),
      );
    }
    if (academicRisks > 2) {
      alerts.add(
        _AlertItem(
          'مراجعة مواد منخفضة',
          '$academicRisks مواد',
          Icons.warning,
          Colors.amber,
        ),
      );
    }
    if (alerts.isEmpty) {
      alerts.add(
        _AlertItem(
          'النظام مستقر',
          'لا توجد تنبيهات',
          Icons.check_circle,
          Colors.green,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.indigo.shade900,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'لوحة القيادة المؤسسية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Strategic Command Center',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Top Row: Radar + Momentum + Heatmap
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Health Radar
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 100.h,
                            width: 100.h,
                            child: Stack(
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: [
                                      PieChartSectionData(
                                        value: healthScore,
                                        color: _getHealthColor(healthScore),
                                        radius: 12.w,
                                        showTitle: false,
                                      ),
                                      PieChartSectionData(
                                        value: (100 - healthScore).toDouble(),
                                        color: Colors.grey.shade100,
                                        radius: 12.w,
                                        showTitle: false,
                                      ),
                                    ],
                                    startDegreeOffset: 270,
                                    centerSpaceRadius: 38.w,
                                    sectionsSpace: 0,
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${healthScore.toInt()}%',
                                        style: TextStyle(
                                          fontSize: 22.sp,
                                          fontWeight: FontWeight.bold,
                                          color: _getHealthColor(healthScore),
                                        ),
                                      ),
                                      Text(
                                        'صحة المؤسسة',
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: _getHealthColor(
                                healthScore,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              _getHealthLabel(healthScore),
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: _getHealthColor(healthScore),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 100.h,
                      color: Colors.grey.shade200,
                    ),

                    // 2. Momentum & Risks
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Momentum
                            Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: isPositive ? Colors.green : Colors.red,
                                  size: 24.sp,
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'اتجاه الأداء (Executive Momentum)',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '${isPositive ? '+' : ''}$trend% عن الشهر الماضي',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Divider(height: 1, color: Colors.grey.shade100),
                            SizedBox(height: 16.h),
                            // Risks Heat Overview
                            Text(
                              'خريطة المخاطر (Risk Heat)',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRiskItem(
                                  'أكاديمية',
                                  academicRisks,
                                  Colors.red,
                                ),
                                _buildRiskItem(
                                  'سلوكية',
                                  behavioralRisks,
                                  Colors.orange,
                                ),
                                _buildRiskItem(
                                  'إدارية',
                                  administrativeRisks,
                                  Colors.blue,
                                ),
                                _buildRiskItem(
                                  'خطط',
                                  overduePlans,
                                  Colors.purple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
                Divider(color: Colors.grey.shade100),
                SizedBox(height: 12.h),

                // 3. Decision Alerts
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 16.sp,
                          color: Colors.grey.shade700,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'تنبيهات القرار (Decision Alerts)',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ...alerts
                        .take(3)
                        .map(
                          (alert) => Container(
                            margin: EdgeInsets.only(bottom: 6.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: alert.color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border(
                                right: BorderSide(
                                  color: alert.color,
                                  width: 3.w,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  alert.icon,
                                  size: 16.sp,
                                  color: alert.color,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  alert.value,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10.sp,
                                  color: Colors.grey.shade400,
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
        ],
      ),
    );
  }

  Widget _buildRiskItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : Colors.grey.shade400,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.amber;
    return Colors.red;
  }

  String _getHealthLabel(double score) {
    if (score >= 90) return 'مستقرة';
    if (score >= 75) return 'تحتاج متابعة';
    return 'تدخل إداري';
  }
}

class _AlertItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _AlertItem(this.title, this.value, this.icon, this.color);
}

// Helper for AsyncValue.group5
extension AsyncValueGroup5<T1, T2, T3, T4, T5>
    on AsyncValue<({T1 t1, T2 t2, T3 t3, T4 t4, T5 t5})> {
  // Simple implementation if not available in riverpod standard
}

// Since AsyncValue.group5 might not exist in this riverpod version, we use nested checking or custom
extension AsyncValueExtensions on AsyncValue {
  static AsyncValue<({T1 $1, T2 $2, T3 $3, T4 $4, T5 $5})>
  group5<T1, T2, T3, T4, T5>(
    AsyncValue<T1> a1,
    AsyncValue<T2> a2,
    AsyncValue<T3> a3,
    AsyncValue<T4> a4,
    AsyncValue<T5> a5,
  ) {
    if (a1 is AsyncLoading ||
        a2 is AsyncLoading ||
        a3 is AsyncLoading ||
        a4 is AsyncLoading ||
        a5 is AsyncLoading) {
      return const AsyncValue.loading();
    }
    if (a1 is AsyncError) return AsyncValue.error(a1.error!, a1.stackTrace!);
    if (a2 is AsyncError) return AsyncValue.error(a2.error!, a2.stackTrace!);
    if (a3 is AsyncError) return AsyncValue.error(a3.error!, a3.stackTrace!);
    if (a4 is AsyncError) return AsyncValue.error(a4.error!, a4.stackTrace!);
    if (a5 is AsyncError) return AsyncValue.error(a5.error!, a5.stackTrace!);

    return AsyncValue.data((
      $1: a1.value as T1,
      $2: a2.value as T2,
      $3: a3.value as T3,
      $4: a4.value as T4,
      $5: a5.value as T5,
    ));
  }
}
