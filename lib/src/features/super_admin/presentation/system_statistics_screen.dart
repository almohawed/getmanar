import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class SystemStatisticsScreen extends StatefulWidget {
  const SystemStatisticsScreen({super.key});

  @override
  State<SystemStatisticsScreen> createState() => _SystemStatisticsScreenState();
}

class _SystemStatisticsScreenState extends State<SystemStatisticsScreen> {
  bool _isLoading = true;
  int _schoolsCount = 0;
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _activeSchools = 0;
  int _trialSchools = 0;
  int _lifetimeSchools = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      // 1) إحصائيات أساسية من GlobalUsers (إن وجدت)
      final schoolIds = <String>{};
      int studentsCount = 0;
      int teachersCount = 0;

      try {
        final globalUsersSnapshot = await FirebaseFirestore.instance
            .collection('GlobalUsers')
            .get();
        final globalDocs = globalUsersSnapshot.docs;

        for (final doc in globalDocs) {
          final data = doc.data();
          final role = data['role'];
          final schoolId = data['schoolId'];

          if (schoolId is String && schoolId.isNotEmpty) {
            schoolIds.add(schoolId);
          }
          if (role == 'student') {
            studentsCount++;
          } else if (role == 'teacher') {
            teachersCount++;
          }
        }
      } catch (_) {
        // في حال فشل قراءة GlobalUsers نكمل بالبدائل
      }

      // 2) مصادر بديلة في حال لم نجد بيانات كافية في GlobalUsers
      if (studentsCount == 0) {
        try {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collectionGroup('Students')
              .get();
          studentsCount = studentsSnapshot.size;
        } catch (_) {}
      }

      if (teachersCount == 0) {
        try {
          final teachersSnapshot = await FirebaseFirestore.instance
              .collectionGroup('Teachers')
              .get();
          teachersCount = teachersSnapshot.size;
        } catch (_) {}
      }

      int effectiveSchoolsCount = schoolIds.length;
      if (effectiveSchoolsCount == 0) {
        try {
          final schoolsSnapshot = await FirebaseFirestore.instance
              .collection('Schools')
              .get();
          effectiveSchoolsCount = schoolsSnapshot.size;
        } catch (_) {}
      }
      if (effectiveSchoolsCount == 0) {
        try {
          final schoolRequestsSnapshot = await FirebaseFirestore.instance
              .collection('SchoolRequests')
              .where('status', isNotEqualTo: 'rejected')
              .get();
          effectiveSchoolsCount = schoolRequestsSnapshot.size;
        } catch (_) {}
      }

      final activeSnapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .where('showSubscriptionSection', isEqualTo: true)
          .get();

      final trialSnapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .where('subscriptionPlan', isEqualTo: 'trial')
          .get();

      final lifetimeSnapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .where('isLifetimeAccess', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _schoolsCount = effectiveSchoolsCount;
          _studentsCount = studentsCount;
          _teachersCount = teachersCount;
          _activeSchools = activeSnapshot.size;
          _trialSchools = trialSnapshot.size;
          _lifetimeSchools = lifetimeSnapshot.size;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إحصائيات المنصة'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'نظرة عامة على المنصة',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;

                      final maxCount = [
                        _schoolsCount,
                        _studentsCount,
                        _teachersCount,
                      ].fold<int>(0, (prev, v) => v > prev ? v : prev);

                      final totalUsers = _studentsCount + _teachersCount;
                      final studentsPercent = totalUsers == 0
                          ? 0
                          : ((_studentsCount / totalUsers) * 100).round();
                      final teachersPercent = totalUsers == 0
                          ? 0
                          : ((_teachersCount / totalUsers) * 100).round();

                      final headerRow = Row(
                        children: [
                          Expanded(
                            child: _buildCircularStat(
                              title: 'المدارس المسجلة',
                              value: _schoolsCount,
                              color: Colors.blue,
                              maxValue: maxCount,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildCircularStat(
                              title: 'إجمالي الطلاب',
                              value: _studentsCount,
                              color: Colors.orange,
                              maxValue: maxCount,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildCircularStat(
                              title: 'إجمالي المعلمين',
                              value: _teachersCount,
                              color: Colors.purple,
                              maxValue: maxCount,
                            ),
                          ),
                        ],
                      );

                      final table = Container(
                        margin: EdgeInsets.only(top: 16.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'المؤشر',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'القيمة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'النسبة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildMetricRow(
                              label: 'متوسط الطلاب لكل مدرسة',
                              value: _schoolsCount == 0
                                  ? '-'
                                  : (_studentsCount / _schoolsCount)
                                        .toStringAsFixed(1),
                              suffix: 'طالب',
                              percentText: '-',
                            ),
                            _buildMetricRow(
                              label: 'متوسط المعلمين لكل مدرسة',
                              value: _schoolsCount == 0
                                  ? '-'
                                  : (_teachersCount / _schoolsCount)
                                        .toStringAsFixed(1),
                              suffix: 'معلم',
                              percentText: '-',
                            ),
                            _buildMetricRow(
                              label: 'نسبة الطلاب من إجمالي المستخدمين',
                              value: '$studentsPercent',
                              suffix: '٪',
                              percentText: '$studentsPercent٪',
                            ),
                            _buildMetricRow(
                              label: 'نسبة المعلمين من إجمالي المستخدمين',
                              value: '$teachersPercent',
                              suffix: '٪',
                              percentText: '$teachersPercent٪',
                            ),
                          ],
                        ),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: headerRow),
                            SizedBox(width: 24.w),
                            Expanded(flex: 4, child: table),
                          ],
                        );
                      } else {
                        return Column(children: [headerRow, table]);
                      }
                    },
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    'توزيع المستخدمين',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    height: 250.h,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child:
                        _schoolsCount == 0 &&
                            _studentsCount == 0 &&
                            _teachersCount == 0
                        ? const Center(
                            child: Text(
                              'لا توجد بيانات كافية للرسم البياني',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  color: Colors.orange,
                                  value: _studentsCount.toDouble(),
                                  title: 'طلاب',
                                  radius: 50,
                                  titleStyle: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  color: Colors.purple,
                                  value: _teachersCount.toDouble(),
                                  title: 'معلمين',
                                  radius: 50,
                                  titleStyle: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  color: Colors.blue,
                                  value: _schoolsCount.toDouble(),
                                  title: 'مدارس',
                                  radius: 50,
                                  titleStyle: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    'حالة الاشتراكات في المدارس',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        int otherSchools =
                            _schoolsCount -
                            _activeSchools -
                            _trialSchools -
                            _lifetimeSchools;
                        if (otherSchools < 0) {
                          otherSchools = 0;
                        }

                        final table = Column(
                          children: [
                            _buildSubscriptionRow(
                              label: 'مدارس مفعلة',
                              value: _activeSchools,
                              color: Colors.green,
                            ),
                            SizedBox(height: 8.h),
                            _buildSubscriptionRow(
                              label: 'مدارس فترة تجريبية',
                              value: _trialSchools,
                              color: Colors.orange,
                            ),
                            SizedBox(height: 8.h),
                            _buildSubscriptionRow(
                              label: 'وصول مدى الحياة',
                              value: _lifetimeSchools,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 8.h),
                            _buildSubscriptionRow(
                              label: 'مجانية / أخرى',
                              value: otherSchools,
                              color: Colors.grey,
                            ),
                          ],
                        );

                        final charts = SizedBox(
                          height: 230.h,
                          child: Row(
                            children: [
                              Expanded(child: _buildSubscriptionPieChart()),
                              SizedBox(width: 16.w),
                              Expanded(child: _buildSubscriptionBarChart()),
                            ],
                          ),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: table),
                              SizedBox(width: 24.w),
                              Expanded(child: charts),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              table,
                              SizedBox(height: 24.h),
                              charts,
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCircularStat({
    required String title,
    required int value,
    required Color color,
    required int maxValue,
  }) {
    final normalizedMax = maxValue <= 0 ? 1 : maxValue;
    final progress = value <= 0 ? 0.0 : value / normalizedMax;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 80.w,
            width: 80.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 80.w,
                  width: 80.w,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 8.w,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required String suffix,
    required String percentText,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800),
            ),
          ),
          Expanded(
            child: Text(
              value == '-' ? '-' : '$value $suffix',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              percentText,
              style: TextStyle(fontSize: 13.sp, color: Colors.indigo.shade700),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow({
    required String label,
    required int value,
    required Color color,
  }) {
    final percent = _schoolsCount == 0
        ? 0
        : ((value / _schoolsCount) * 100).round();

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          width: 160.w,
          child: LinearProgressIndicator(
            value: _schoolsCount == 0 ? 0 : value / _schoolsCount,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '$value ($percent٪)',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSubscriptionPieChart() {
    final total = _schoolsCount;
    if (total == 0) {
      return Center(
        child: Text(
          'لا توجد بيانات للاشتراكات',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
          textAlign: TextAlign.center,
        ),
      );
    }

    int otherSchools =
        _schoolsCount - _activeSchools - _trialSchools - _lifetimeSchools;
    if (otherSchools < 0) {
      otherSchools = 0;
    }

    final items = [
      {'label': 'مفعلة', 'value': _activeSchools, 'color': Colors.green},
      {'label': 'تجريبية', 'value': _trialSchools, 'color': Colors.orange},
      {'label': 'مدى الحياة', 'value': _lifetimeSchools, 'color': Colors.blue},
      {'label': 'مجانية', 'value': otherSchools, 'color': Colors.grey},
    ].where((item) => (item['value'] as int) > 0).toList();

    if (items.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات للاشتراكات',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
          textAlign: TextAlign.center,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: items.map((item) {
          final value = (item['value'] as int).toDouble();
          final percent = ((value / total) * 100).round();
          return PieChartSectionData(
            color: item['color'] as Color,
            value: value,
            title: '$percent٪',
            radius: 50,
            titleStyle: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscriptionBarChart() {
    int otherSchools =
        _schoolsCount - _activeSchools - _trialSchools - _lifetimeSchools;
    if (otherSchools < 0) {
      otherSchools = 0;
    }

    final values = [
      _activeSchools.toDouble(),
      _trialSchools.toDouble(),
      _lifetimeSchools.toDouble(),
      otherSchools.toDouble(),
    ];

    double maxValue = 0;
    for (final v in values) {
      if (v > maxValue) {
        maxValue = v;
      }
    }

    if (maxValue == 0) {
      return Center(
        child: Text(
          'لا توجد بيانات للرسم البياني',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
          textAlign: TextAlign.center,
        ),
      );
    }

    final maxY = maxValue * 1.2;
    final interval = maxValue <= 5 ? 1.0 : (maxValue / 4).roundToDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                String text;
                switch (value.toInt()) {
                  case 0:
                    text = 'مفعلة';
                    break;
                  case 1:
                    text = 'تجريبية';
                    break;
                  case 2:
                    text = 'مدى الحياة';
                    break;
                  case 3:
                    text = 'مجانية';
                    break;
                  default:
                    text = '';
                }
                return Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 10.sp),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: _activeSchools.toDouble(),
                color: Colors.green,
                width: 16.w,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: _trialSchools.toDouble(),
                color: Colors.orange,
                width: 16.w,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: _lifetimeSchools.toDouble(),
                color: Colors.blue,
                width: 16.w,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ],
          ),
          BarChartGroupData(
            x: 3,
            barRods: [
              BarChartRodData(
                toY: otherSchools.toDouble(),
                color: Colors.grey,
                width: 16.w,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
