import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../application/modification_tracking_service.dart';
import '../domain/schedule_modification.dart';

// 📊 شاشة تحليلات التعديلات
class ModificationsAnalyticsScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const ModificationsAnalyticsScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  ConsumerState<ModificationsAnalyticsScreen> createState() =>
      _ModificationsAnalyticsScreenState();
}

class _ModificationsAnalyticsScreenState
    extends ConsumerState<ModificationsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  ModificationStatistics? _statistics;
  List<ModificationTrend>? _trends;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(modificationTrackingServiceProvider);

      final statistics = await service.calculateStatistics(
        schoolId: widget.schoolId,
      );

      final trends = await service.analyzeTrends(
        schoolId: widget.schoolId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        period: TrendPeriod.daily,
      );

      setState(() {
        _statistics = statistics;
        _trends = trends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 التحليلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: _statistics != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.pie_chart), text: 'التوزيع'),
                  Tab(icon: Icon(Icons.show_chart), text: 'الاتجاهات'),
                  Tab(icon: Icon(Icons.leaderboard), text: 'الأكثر تأثراً'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('حدث خطأ: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_statistics == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildDistributionTab(),
        _buildTrendsTab(),
        _buildMostAffectedTab(),
      ],
    );
  }

  // 📊 تبويب التوزيع
  Widget _buildDistributionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeDistributionCard(),
          const SizedBox(height: 16),
          _buildModifierDistributionCard(),
          const SizedBox(height: 16),
          _buildDayDistributionCard(),
          const SizedBox(height: 16),
          _buildHourDistributionCard(),
        ],
      ),
    );
  }

  Widget _buildTypeDistributionCard() {
    if (_statistics!.byType.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد بيانات'),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 التوزيع حسب النوع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _statistics!.byType.entries.map((entry) {
                    final percentage = (entry.value / _statistics!.totalModifications * 100);
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(0)}%',
                      color: _getTypeColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statistics!.byType.entries.map((entry) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: _getTypeColor(entry.key),
                  ),
                  label: Text('${_getTypeLabel(entry.key)}: ${entry.value}'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierDistributionCard() {
    if (_statistics!.byModifier.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = _statistics!.byModifier.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👥 التوزيع حسب المعدّل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sorted.take(5).map((entry) {
              final percentage = (entry.value / _statistics!.totalModifications * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('${entry.value} (${percentage.toStringAsFixed(0)}%)'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDistributionCard() {
    if (_statistics!.byDay.isEmpty) {
      return const SizedBox.shrink();
    }

    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 التوزيع حسب اليوم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _statistics!.byDay.values.isEmpty
                      ? 10
                      : _statistics!.byDay.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
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
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(days.length, (index) {
                    final day = days[index];
                    final count = _statistics!.byDay[day] ?? 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourDistributionCard() {
    if (_statistics!.byHour.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = _statistics!.byHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ التوزيع حسب الساعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sorted.take(5).map((entry) {
              return ListTile(
                leading: const Icon(Icons.access_time, color: Colors.orange),
                title: Text(entry.key),
                trailing: Chip(
                  label: Text('${entry.value}'),
                  backgroundColor: Colors.orange[100],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 📈 تبويب الاتجاهات
  Widget _buildTrendsTab() {
    if (_trends == null || _trends!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا توجد بيانات كافية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'يتطلب الأمر المزيد من البيانات لتحليل الاتجاهات',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrendChart(),
          const SizedBox(height: 16),
          _buildTrendSummary(),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 اتجاه التعديلات (آخر 30 يوم)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _trends!.length) {
                            final trend = _trends![value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${trend.period.day}/${trend.period.month}',
                                style: const TextStyle(fontSize: 8),
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
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _trends!.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.count.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
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

  Widget _buildTrendSummary() {
    final totalMods = _trends!.fold<int>(0, (sum, trend) => sum + trend.count);
    final avgMods = totalMods / _trends!.length;
    final maxDay = _trends!.reduce((a, b) => a.count > b.count ? a : b);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 ملخص الاتجاهات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('إجمالي التعديلات', '$totalMods'),
            _buildSummaryRow('متوسط يومي', avgMods.toStringAsFixed(1)),
            _buildSummaryRow('أكثر يوم نشاطاً', '${maxDay.period.day}/${maxDay.period.month} (${maxDay.count})'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // 🏆 تبويب الأكثر تأثراً
  Widget _buildMostAffectedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMostAffectedTeachersCard(),
          const SizedBox(height: 16),
          _buildMostAffectedClassesCard(),
        ],
      ),
    );
  }

  Widget _buildMostAffectedTeachersCard() {
    if (_statistics!.mostAffectedTeachers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👥 المعلمون الأكثر تأثراً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statistics!.mostAffectedTeachers.asMap().entries.map((entry) {
              final index = entry.key;
              final teacher = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(teacher),
                trailing: Icon(
                  Icons.trending_up,
                  color: _getRankColor(index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMostAffectedClassesCard() {
    if (_statistics!.mostAffectedClasses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏫 الصفوف الأكثر تأثراً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statistics!.mostAffectedClasses.asMap().entries.map((entry) {
              final index = entry.key;
              final className = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(className),
                trailing: Icon(
                  Icons.trending_up,
                  color: _getRankColor(index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 🎨 دوال مساعدة
  Color _getTypeColor(ModificationType type) {
    switch (type) {
      case ModificationType.scheduleReplacement:
        return Colors.red;
      case ModificationType.bulkEdit:
        return Colors.orange;
      case ModificationType.slotSwap:
      case ModificationType.slotMove:
        return Colors.blue;
      case ModificationType.teacherChange:
      case ModificationType.classChange:
        return Colors.purple;
      case ModificationType.slotAdd:
        return Colors.green;
      case ModificationType.slotRemove:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(ModificationType type) {
    switch (type) {
      case ModificationType.slotSwap:
        return 'تبديل';
      case ModificationType.slotMove:
        return 'نقل';
      case ModificationType.teacherChange:
        return 'تغيير معلم';
      case ModificationType.classChange:
        return 'تغيير صف';
      case ModificationType.subjectChange:
        return 'تغيير مادة';
      case ModificationType.periodChange:
        return 'تغيير وقت';
      case ModificationType.dayChange:
        return 'تغيير يوم';
      case ModificationType.slotAdd:
        return 'إضافة';
      case ModificationType.slotRemove:
        return 'حذف';
      case ModificationType.scheduleReplacement:
        return 'استبدال';
      case ModificationType.bulkEdit:
        return 'جماعي';
      case ModificationType.other:
        return 'أخرى';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}
