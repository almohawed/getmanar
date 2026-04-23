import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';

class BehaviorDistributionChart extends StatelessWidget {
  final int excellent;
  final int veryGood;
  final int needsSupport;

  const BehaviorDistributionChart({
    super.key,
    required this.excellent,
    required this.veryGood,
    required this.needsSupport,
  });

  @override
  Widget build(BuildContext context) {
    final total = excellent + veryGood + needsSupport;
    // Show empty state if no data
    if (total == 0) {
      return SizedBox(
        height: 160.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40.r,
                sections: [
                  PieChartSectionData(
                    color: Colors.grey.shade200,
                    value: 1,
                    title: '',
                    radius: 20.r,
                  ),
                ],
              ),
            ),
            Text(
              "0%",
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 160.h,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40.r,
          sections: [
            if (excellent > 0)
              PieChartSectionData(
                color: Colors.green,
                value: excellent.toDouble(),
                title: '${((excellent / total) * 100).toStringAsFixed(0)}%',
                radius: 50.r,
                titleStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (veryGood > 0)
              PieChartSectionData(
                color: Colors.blue,
                value: veryGood.toDouble(),
                title: '${((veryGood / total) * 100).toStringAsFixed(0)}%',
                radius: 50.r,
                titleStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (needsSupport > 0)
              PieChartSectionData(
                color: Colors.orange,
                value: needsSupport.toDouble(),
                title: '${((needsSupport / total) * 100).toStringAsFixed(0)}%',
                radius: 50.r,
                titleStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  final Map<String, int> data;
  final String title;
  final Color barColor;

  const SimpleBarChart({
    super.key,
    required this.data,
    required this.title,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState(context);
    }

    final sortedEntries = data.entries.toList();
    final maxValue = sortedEntries.fold<int>(
      0,
      (m, e) => e.value > m ? e.value : m,
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxValue + 1).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final key = sortedEntries[group.x.toInt()].key;
                      return BarTooltipItem(
                        '$key\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: (rod.toY - 1).toInt().toString(),
                            style: const TextStyle(color: Colors.yellow),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= sortedEntries.length)
                          return const SizedBox.shrink();
                        final label = sortedEntries[value.toInt()].key;
                        // Truncate if too long
                        final displayLabel = label.length > 8
                            ? '${label.substring(0, 6)}..'
                            : label;
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            displayLabel,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.sp,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedEntries.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: barColor,
                        width: 16.w,
                        borderRadius: BorderRadius.circular(4.r),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (maxValue + 1).toDouble(),
                          color: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      height: 200.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 40.sp, color: Colors.grey.shade300),
            SizedBox(height: 8.h),
            Text(
              "لا توجد بيانات للعرض",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
