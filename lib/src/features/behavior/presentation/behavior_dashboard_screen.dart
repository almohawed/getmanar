import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'behavior_analysis_screen.dart';
import 'behavior_reports_screen.dart';
import 'students_list_by_behavior_screen.dart';
import 'behavioral_cases_screen.dart';
import 'add_violation_quick_screen.dart';
import '../services/behavior_data_service.dart';

/// لوحة تحكم السلوك والانضباط الاحترافية
class BehaviorDashboardScreen extends StatefulWidget {
  const BehaviorDashboardScreen({super.key});

  @override
  State<BehaviorDashboardScreen> createState() => _BehaviorDashboardScreenState();
}

class _BehaviorDashboardScreenState extends State<BehaviorDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBehaviorStats();
  }

  Future<void> _loadBehaviorStats() async {
    try {
      // تحديث الإحصائيات من البيانات الموجودة أولاً
      await BehaviorDataService.refreshStatsFromExistingData();

      // ثم الاستماع للتحديثات المباشرة
      BehaviorDataService.getBehaviorStatsStream().listen((stats) {
        if (mounted) {
          setState(() {
            _stats = stats;
            _isLoading = false;
          });
        }
      });

      final currentStats = await BehaviorDataService.getGeneralBehaviorStats();
      if (mounted) {
        setState(() {
          _stats = currentStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading behavior stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade800, Colors.orange.shade600, Colors.amber.shade600],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السلوك والانضباط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('تحليل ومتابعة السلوك المدرسي', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _loadBehaviorStats(),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقات الإحصائيات الرئيسية
                  _buildMainStatsCards(),
                  
                  const SizedBox(height: 24),
                  
                  // مؤشر السلوك العام
                  _buildBehaviorScoreCard(),
                  
                  const SizedBox(height: 24),
                  
                  // الأقسام الرئيسية
                  _buildMainSections(),
                  
                  const SizedBox(height: 24),
                  
                  // الرسوم البيانية
                  _buildChartsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // التقارير السريعة
                  _buildQuickReports(),
                  
                  const SizedBox(height: 24),
                  
                  // إجراءات سريعة
                  _buildQuickActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildMainStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'إجمالي المخالفات',
            _stats['totalViolations']?.toString() ?? '0',
            Icons.warning,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'السلوك الإيجابي',
            _stats['totalPositiveBehavior']?.toString() ?? '0',
            Icons.star,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الحالات الحرجة',
            _stats['criticalCases']?.toString() ?? '0',
            Icons.priority_high,
            Colors.deepOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
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
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorScoreCard() {
    final score = _stats['behaviorScore'] ?? 0;
    Color scoreColor;
    String scoreText;
    
    if (score >= 80) {
      scoreColor = Colors.green;
      scoreText = 'ممتاز';
    } else if (score >= 60) {
      scoreColor = Colors.orange;
      scoreText = 'جيد';
    } else {
      scoreColor = Colors.red;
      scoreText = 'يحتاج تحسين';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'مؤشر السلوك العام للمدرسة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    scoreText,
                    style: TextStyle(
                      fontSize: 14,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأقسام الرئيسية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildSectionCard(
              'تحليل السلوك',
              'تحليلات متقدمة وإحصائيات',
              Icons.analytics,
              Colors.blue,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BehaviorAnalysisScreen()),
              ),
            ),
            _buildSectionCard(
              'تقرير السلوك',
              'تقارير مفصلة حسب الفترة',
              Icons.assessment,
              Colors.green,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BehaviorReportsScreen()),
              ),
            ),
            _buildSectionCard(
              'الطلاب حسب السلوك',
              'تصنيف الطلاب سلوكياً',
              Icons.people,
              Colors.purple,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StudentsListByBehaviorScreen()),
              ),
            ),
            _buildSectionCard(
              'حالات سلوكية',
              'إدارة الحالات السلوكية',
              Icons.warning,
              Colors.orange,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BehavioralCasesScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التحليلات البيانية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // رسم بياني للمخالفات حسب النوع
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المخالفات حسب النوع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildViolationsByTypeChart(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViolationsByTypeChart() {
    final violationsByType = _stats['violationsByType'] as Map<String, int>? ?? {};
    
    if (violationsByType.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات للعرض'),
      );
    }

    final sections = violationsByType.entries.map((entry) {
      final colors = [Colors.red, Colors.orange, Colors.blue, Colors.green, Colors.purple];
      final colorIndex = violationsByType.keys.toList().indexOf(entry.key) % colors.length;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        color: colors[colorIndex],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: violationsByType.entries.map((entry) {
              final colors = [Colors.red, Colors.orange, Colors.blue, Colors.green, Colors.purple];
              final colorIndex = violationsByType.keys.toList().indexOf(entry.key) % colors.length;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[colorIndex],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التقارير السريعة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickReportCard(
                'تقرير يومي',
                'مخالفات اليوم',
                Icons.today,
                Colors.blue,
                () => _generateDailyReport(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickReportCard(
                'تقرير أسبوعي',
                'مخالفات الأسبوع',
                Icons.date_range,
                Colors.green,
                () => _generateWeeklyReport(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickReportCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateDailyReport() {
    // تنفيذ تقرير يومي
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري إنشاء التقرير اليومي...')),
    );
  }

  void _generateWeeklyReport() {
    // تنفيذ تقرير أسبوعي
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري إنشاء التقرير الأسبوعي...')),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddViolationQuickScreen()),
                ),
                icon: const Icon(Icons.add_alert, color: Colors.white),
                label: const Text('إضافة مخالفة', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const BehavioralCasesScreen()),
                ),
                icon: const Icon(Icons.folder_open, color: Colors.white),
                label: const Text('إدارة الحالات', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}