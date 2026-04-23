import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

/// شاشة تحليل السلوك المتقدمة
class BehaviorAnalysisScreen extends ConsumerStatefulWidget {
  const BehaviorAnalysisScreen({super.key});

  @override
  ConsumerState<BehaviorAnalysisScreen> createState() => _BehaviorAnalysisScreenState();
}

class _BehaviorAnalysisScreenState extends ConsumerState<BehaviorAnalysisScreen> {
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  String _selectedPeriod = 'month';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalyticsData());
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      DateTime startDate;
      switch (_selectedPeriod) {
        case 'month':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case 'quarter':
          startDate = DateTime.now().subtract(const Duration(days: 90));
          break;
        case 'year':
          startDate = DateTime.now().subtract(const Duration(days: 365));
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 30));
      }

      final startTimestamp = Timestamp.fromDate(startDate);

      // جلب البيانات بالتوازي - بدون فلتر timestamp أولاً للتأكد من وجود بيانات
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('behavioral_violations')
            .get(),
        FirebaseFirestore.instance
            .collection('positive_behavior')
            .get(),
        FirebaseFirestore.instance
            .collection('behavioral_cases')
            .get(),
      ]);

      var violationsDocs = results[0].docs;
      var positiveDocs = results[1].docs;
      var casesDocs = results[2].docs;

      // فلترة حسب التاريخ يدوياً (لتجنب مشكلة الـ index)
      violationsDocs = violationsDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['timestamp'] as Timestamp?;
        return ts == null || ts.compareTo(startTimestamp) >= 0;
      }).toList();

      positiveDocs = positiveDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['timestamp'] as Timestamp?;
        return ts == null || ts.compareTo(startTimestamp) >= 0;
      }).toList();

      casesDocs = casesDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['createdAt'] as Timestamp?;
        return ts == null || ts.compareTo(startTimestamp) >= 0;
      }).toList();

      // جلب عدد الطلاب من Schools/{schoolId}/Students
      int totalStudents = 0;
      try {
        final user = ref.read(authStateProvider).value;
        final schoolId = user?.schoolId ?? '';
        if (schoolId.isNotEmpty) {
          final studentsSnap = await FirebaseFirestore.instance
              .collection('Schools')
              .doc(schoolId)
              .collection('Students')
              .count()
              .get();
          totalStudents = studentsSnap.count ?? 0;
        }
      } catch (_) {}

      final analytics = _analyzeData(
        violationsDocs,
        positiveDocs,
        casesDocs,
        totalStudents,
      );

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _analyzeData(
    List<QueryDocumentSnapshot> violations,
    List<QueryDocumentSnapshot> positiveBehavior,
    List<QueryDocumentSnapshot> cases,
    int totalStudents,
  ) {
    // تحليل المخالفات حسب النوع والوقت
    Map<String, int> violationsByType = {};
    Map<String, int> violationsByGrade = {};
    Map<String, int> violationsByDay = {};
    Map<String, int> violationsByHour = {};
    Map<String, int> casesByType = {};
    Map<String, int> casesByPriority = {};

    for (var doc in violations) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      final type = data['violationType'] ?? 'غير محدد';
      violationsByType[type] = (violationsByType[type] ?? 0) + 1;

      final grade = (data['studentGrade'] ?? data['grade'] ?? 'غير محدد').toString();
      if (grade.isNotEmpty && grade != 'غير محدد') {
        violationsByGrade[grade] = (violationsByGrade[grade] ?? 0) + 1;
      }

      final dayKey = '${timestamp.day}/${timestamp.month}';
      violationsByDay[dayKey] = (violationsByDay[dayKey] ?? 0) + 1;

      final hour = timestamp.hour.toString();
      violationsByHour[hour] = (violationsByHour[hour] ?? 0) + 1;
    }

    // تحليل الحالات
    for (var doc in cases) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['caseType'] ?? 'غير محدد';
      final priority = data['priority'] ?? 'غير محدد';
      casesByType[type] = (casesByType[type] ?? 0) + 1;
      casesByPriority[priority] = (casesByPriority[priority] ?? 0) + 1;
    }

    // تحليل السلوك الإيجابي
    Map<String, int> positiveBehaviorByType = {};
    for (var doc in positiveBehavior) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['behaviorType'] ?? 'غير محدد';
      positiveBehaviorByType[type] = (positiveBehaviorByType[type] ?? 0) + 1;
    }

    final totalViolations = violations.length;
    final totalPositive = positiveBehavior.length;
    final totalCases = cases.length;
    final activeCases = cases.where((d) => (d.data() as Map)['status'] == 'active').length;
    
    final behaviorRatio = (totalPositive + totalViolations) > 0
        ? (totalPositive / (totalPositive + totalViolations) * 100)
        : 0.0;

    final problematicHours = violationsByHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final problematicGrades = violationsByGrade.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'violationsByType': violationsByType,
      'violationsByGrade': violationsByGrade,
      'violationsByDay': violationsByDay,
      'violationsByHour': violationsByHour,
      'positiveBehaviorByType': positiveBehaviorByType,
      'casesByType': casesByType,
      'casesByPriority': casesByPriority,
      'totalViolations': totalViolations,
      'totalPositive': totalPositive,
      'totalCases': totalCases,
      'activeCases': activeCases,
      'totalStudents': totalStudents,
      'behaviorRatio': behaviorRatio.round(),
      'problematicHours': problematicHours.take(3).toList(),
      'problematicGrades': problematicGrades.take(3).toList(),
      'improvementRate': _calculateImprovementRate(violations),
    };
  }

  double _calculateImprovementRate(List<QueryDocumentSnapshot> violations) {
    if (violations.length < 2) return 0;

    // تقسيم البيانات إلى نصفين زمنيين
    violations.sort((a, b) {
      final aTime = (a.data() as Map)['timestamp'] as Timestamp;
      final bTime = (b.data() as Map)['timestamp'] as Timestamp;
      return aTime.compareTo(bTime);
    });

    final midPoint = violations.length ~/ 2;
    final firstHalf = violations.take(midPoint).length;
    final secondHalf = violations.skip(midPoint).length;

    if (firstHalf == 0) return 0;
    
    return ((firstHalf - secondHalf) / firstHalf * 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // الشريط العلوي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.indigo.shade700],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const Expanded(
                  child: Text(
                    'تحليل السلوك المتقدم',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => _loadAnalyticsData(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // فلتر الفترة الزمنية
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Text('الفترة الزمنية: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'month', child: Text('آخر شهر')),
                      DropdownMenuItem(value: 'quarter', child: Text('آخر 3 أشهر')),
                      DropdownMenuItem(value: 'year', child: Text('آخر سنة')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                        _loadAnalyticsData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // المؤشرات الرئيسية
                        _buildMainIndicators(),
                        
                        const SizedBox(height: 24),
                        
                        // الرسوم البيانية
                        _buildChartsSection(),
                        
                        const SizedBox(height: 24),
                        
                        // التحليلات المتقدمة
                        _buildAdvancedAnalytics(),
                        
                        const SizedBox(height: 24),
                        
                        // التوصيات
                        _buildRecommendations(),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainIndicators() {
    final behaviorRatio = _analyticsData['behaviorRatio'] ?? 0;
    final improvementRate = _analyticsData['improvementRate'] ?? 0.0;
    final totalViolations = _analyticsData['totalViolations'] ?? 0;
    final totalPositive = _analyticsData['totalPositive'] ?? 0;
    final totalCases = _analyticsData['totalCases'] ?? 0;
    final activeCases = _analyticsData['activeCases'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المؤشرات الرئيسية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                'نسبة السلوك الإيجابي',
                '$behaviorRatio%',
                Icons.trending_up,
                behaviorRatio >= 70 ? Colors.green : behaviorRatio >= 50 ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'معدل التحسن',
                '${(improvementRate as double).toStringAsFixed(1)}%',
                Icons.show_chart,
                improvementRate >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                'إجمالي المخالفات',
                totalViolations.toString(),
                Icons.warning,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'السلوك الإيجابي',
                totalPositive.toString(),
                Icons.star,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                'إجمالي الحالات',
                totalCases.toString(),
                Icons.folder_open,
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'الحالات النشطة',
                activeCases.toString(),
                Icons.pending_actions,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicatorCard(String title, String value, IconData icon, Color color) {
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التحليلات البيانية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildViolationsByTypeChart(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // رسم بياني للمخالفات حسب الساعة
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
                'المخالفات حسب الساعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildViolationsByHourChart(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViolationsByTypeChart() {
    final violationsByType = _analyticsData['violationsByType'] as Map<String, int>? ?? {};
    
    if (violationsByType.isEmpty) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
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
                      child: Text(entry.key, style: const TextStyle(fontSize: 12)),
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

  Widget _buildViolationsByHourChart() {
    final violationsByHour = _analyticsData['violationsByHour'] as Map<String, int>? ?? {};
    
    if (violationsByHour.isEmpty) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
    }

    final spots = violationsByHour.entries
        .map((entry) => FlSpot(double.parse(entry.key), entry.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedAnalytics() {
    final problematicHours = _analyticsData['problematicHours'] as List? ?? [];
    final problematicGrades = _analyticsData['problematicGrades'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التحليلات المتقدمة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الأوقات الأكثر إشكالية',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...problematicHours.take(3).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${entry.key}:00'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الصفوف الأكثر إشكالية',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...problematicGrades.take(3).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    final behaviorRatio = _analyticsData['behaviorRatio'] ?? 0;
    final improvementRate = _analyticsData['improvementRate'] ?? 0;
    final problematicHours = _analyticsData['problematicHours'] as List? ?? [];

    List<String> recommendations = [];

    if (behaviorRatio < 50) {
      recommendations.add('نسبة السلوك الإيجابي منخفضة - يُنصح بتكثيف برامج التحفيز');
    }
    
    if (improvementRate < 0) {
      recommendations.add('هناك تراجع في السلوك - يُنصح بمراجعة الاستراتيجيات المطبقة');
    }
    
    if (problematicHours.isNotEmpty) {
      final topHour = problematicHours.first;
      recommendations.add('الساعة ${topHour.key}:00 هي الأكثر إشكالية - يُنصح بزيادة الإشراف');
    }

    if (recommendations.isEmpty) {
      recommendations.add('الوضع السلوكي جيد - استمروا في تطبيق الاستراتيجيات الحالية');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text(
                'التوصيات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((recommendation) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}