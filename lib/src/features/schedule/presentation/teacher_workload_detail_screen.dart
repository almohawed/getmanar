import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../domain/workload_analysis.dart';

// 👤 شاشة تفاصيل نصاب معلم واحد
class TeacherWorkloadDetailScreen extends StatelessWidget {
  final String schoolId;
  final TeacherWorkload teacher;

  const TeacherWorkloadDetailScreen({
    Key? key,
    required this.schoolId,
    required this.teacher,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teacher.teacherName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildLoadComparisonCard(),
            const SizedBox(height: 16),
            _buildDailyDistributionCard(),
            const SizedBox(height: 16),
            if (teacher.issues.isNotEmpty) _buildIssuesCard(),
          ],
        ),
      ),
    );
  }

  // 📊 بطاقة الملخص
  Widget _buildSummaryCard() {
    final statusColor = _getStatusColor(teacher.status);
    final statusLabel = _getStatusLabel(teacher.status);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(
                _getStatusIcon(teacher.status),
                size: 40,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              teacher.teacherName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              teacher.subject,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📈 بطاقة مقارنة الحمل
  Widget _buildLoadComparisonCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 مقارنة الحمل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildLoadBar('الحصص الفعلية', teacher.currentLoad, Colors.blue),
            const SizedBox(height: 12),
            _buildLoadBar('النصاب المثالي', teacher.idealLoad, Colors.green),
            const SizedBox(height: 12),
            _buildLoadBar('حصص الانتظار', teacher.waitingSlots, Colors.orange),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('الإجمالي', '${teacher.totalLoad}', Colors.purple),
                _buildStatColumn('الفرق', '${teacher.difference > 0 ? '+' : ''}${teacher.difference}', 
                  teacher.difference > 0 ? Colors.red : Colors.green),
                _buildStatColumn('النسبة', '${((teacher.currentLoad / teacher.idealLoad) * 100).toStringAsFixed(0)}%', 
                  Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadBar(String label, int value, Color color) {
    final maxValue = [teacher.currentLoad, teacher.idealLoad, teacher.waitingSlots].reduce((a, b) => a > b ? a : b);
    final percentage = maxValue > 0 ? value / maxValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 📅 بطاقة التوزيع اليومي
  Widget _buildDailyDistributionCard() {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final distribution = teacher.dailyDistribution;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 التوزيع اليومي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 8,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(days.length, (index) {
                    final day = days[index];
                    final count = distribution[day] ?? 0;
                    final color = _getDayColor(count);

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: color,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: days.map((day) {
                final count = distribution[day] ?? 0;
                final color = _getDayColor(count);
                return Chip(
                  label: Text('$day: $count'),
                  backgroundColor: color.withOpacity(0.2),
                  labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ⚠️ بطاقة المشاكل
  Widget _buildIssuesCard() {
    return Card(
      elevation: 4,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'مشاكل مكتشفة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...teacher.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      issue,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // 🎨 دوال مساعدة
  Color _getStatusColor(WorkloadStatus status) {
    switch (status) {
      case WorkloadStatus.balanced:
        return Colors.green;
      case WorkloadStatus.overloaded:
        return Colors.red;
      case WorkloadStatus.underloaded:
        return Colors.blue;
    }
  }

  String _getStatusLabel(WorkloadStatus status) {
    switch (status) {
      case WorkloadStatus.balanced:
        return '⚖️ متوازن';
      case WorkloadStatus.overloaded:
        return '⚠️ محمّل';
      case WorkloadStatus.underloaded:
        return '📉 أقل من المطلوب';
    }
  }

  IconData _getStatusIcon(WorkloadStatus status) {
    switch (status) {
      case WorkloadStatus.balanced:
        return Icons.check_circle;
      case WorkloadStatus.overloaded:
        return Icons.warning;
      case WorkloadStatus.underloaded:
        return Icons.trending_down;
    }
  }

  Color _getDayColor(int count) {
    if (count >= 7) return Colors.red;
    if (count >= 5) return Colors.orange;
    if (count >= 3) return Colors.blue;
    return Colors.green;
  }
}
