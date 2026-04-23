import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../application/workload_learning_service.dart';

// 🧠 شاشة رؤى الذكاء الاصطناعي
class WorkloadLearningScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const WorkloadLearningScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  ConsumerState<WorkloadLearningScreen> createState() => _WorkloadLearningScreenState();
}

class _WorkloadLearningScreenState extends ConsumerState<WorkloadLearningScreen>
    with SingleTickerProviderStateMixin {
  LearningInsights? _insights;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  String _effectiveSchoolId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInsights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resolved = widget.schoolId.trim().isNotEmpty
          ? widget.schoolId.trim()
          : (ref.read(authStateProvider).value?.schoolId ?? '').trim();
      if (resolved.isEmpty) {
        setState(() {
          _effectiveSchoolId = '';
          _insights = null;
          _isLoading = false;
          _error = 'لا يمكن تحديد المدرسة الحالية.';
        });
        return;
      }
      _effectiveSchoolId = resolved;
      final service = ref.read(workloadLearningServiceProvider);
      final insights = await service.analyzeHistoricalPatterns(_effectiveSchoolId);
      
      setState(() {
        _insights = insights;
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
        title: const Text('🧠 رؤى الذكاء الاصطناعي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
          ),
        ],
        bottom: _insights != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.lightbulb), text: 'التوصيات'),
                  Tab(icon: Icon(Icons.pattern), text: 'الأنماط'),
                  Tab(icon: Icon(Icons.favorite), text: 'التفضيلات'),
                  Tab(icon: Icon(Icons.trending_up), text: 'الاتجاهات'),
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
              onPressed: _loadInsights,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_insights == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    return Column(
      children: [
        _buildSummaryHeader(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecommendationsTab(),
              _buildPatternsTab(),
              _buildPreferencesTab(),
              _buildTrendsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // 📊 رأس الملخص
  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحليل ذكي للبيانات التاريخية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم تحليل ${_insights!.totalSchedulesAnalyzed} جدول دراسي',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _buildStatBadge('${_insights!.patterns.length}', 'نمط'),
              const SizedBox(height: 8),
              _buildStatBadge('${_insights!.preferences.length}', 'تفضيل'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // 💡 تبويب التوصيات
  Widget _buildRecommendationsTab() {
    final recommendations = _insights!.smartRecommendations;

    if (recommendations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.lightbulb_outline,
        title: 'لا توجد توصيات',
        subtitle: 'سيتم توليد توصيات عند توفر المزيد من البيانات',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final rec = recommendations[index];
        return _buildRecommendationCard(rec);
      },
    );
  }

  Widget _buildRecommendationCard(SmartLearningRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          rec.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: _getImpactColor(rec.impact),
                    radius: 20,
                    child: Text(
                      '${rec.impact.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                rec.description,
                style: const TextStyle(fontSize: 14),
              ),
              if (rec.actionable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'قابل للتطبيق',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🔍 تبويب الأنماط
  Widget _buildPatternsTab() {
    final patterns = _insights!.patterns;

    if (patterns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pattern,
        title: 'لا توجد أنماط',
        subtitle: 'لم يتم اكتشاف أنماط واضحة بعد',
      );
    }

    // تجميع حسب النوع
    final grouped = <PatternType, List<DiscoveredPattern>>{};
    for (final pattern in patterns) {
      grouped.putIfAbsent(pattern.type, () => []);
      grouped[pattern.type]!.add(pattern);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return _buildPatternGroup(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildPatternGroup(PatternType type, List<DiscoveredPattern> patterns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_getPatternIcon(type), color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                _getPatternTypeLabel(type),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text('${patterns.length}'),
                backgroundColor: Colors.purple[100],
              ),
            ],
          ),
        ),
        ...patterns.map((pattern) => _buildPatternCard(pattern)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPatternCard(DiscoveredPattern pattern) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getConfidenceColor(pattern.confidence),
          child: Text(
            '${pattern.confidence.toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          pattern.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('تكرر ${pattern.occurrences} مرة'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showPatternDetails(pattern),
      ),
    );
  }

  // 💖 تبويب التفضيلات
  Widget _buildPreferencesTab() {
    final preferences = _insights!.preferences;

    if (preferences.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'لا توجد تفضيلات',
        subtitle: 'لم يتم اكتشاف تفضيلات واضحة للمعلمين',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: preferences.length,
      itemBuilder: (context, index) {
        final pref = preferences[index];
        return _buildPreferenceCard(pref);
      },
    );
  }

  Widget _buildPreferenceCard(TeacherPreference pref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.pink[100],
          child: const Icon(Icons.person, color: Colors.pink),
        ),
        title: Text(
          pref.teacherName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(pref.description),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: pref.confidence / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConfidenceColor(pref.confidence),
              ),
            ),
          ],
        ),
        trailing: Text(
          '${pref.confidence.toInt()}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getConfidenceColor(pref.confidence),
          ),
        ),
        onTap: () => _showPreferenceDetails(pref),
      ),
    );
  }

  // 📈 تبويب الاتجاهات
  Widget _buildTrendsTab() {
    final trends = _insights!.trends;

    if (trends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'لا توجد اتجاهات',
        subtitle: 'لم يتم رصد اتجاهات واضحة بعد',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trends.length,
      itemBuilder: (context, index) {
        final trend = trends[index];
        return _buildTrendCard(trend);
      },
    );
  }

  Widget _buildTrendCard(Trend trend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getTrendColor(trend.direction).withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getTrendIcon(trend.direction),
                    color: _getTrendColor(trend.direction),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trend.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('الحجم: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${trend.magnitude.toStringAsFixed(1)}%'),
                  const SizedBox(width: 16),
                  const Text('الاتجاه: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_getTrendDirectionLabel(trend.direction)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 حالة فارغة
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🔧 دوال مساعدة
  Color _getImpactColor(double impact) {
    if (impact >= 70) return Colors.green;
    if (impact >= 40) return Colors.orange;
    return Colors.grey;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 70) return Colors.green;
    if (confidence >= 50) return Colors.orange;
    return Colors.red;
  }

  IconData _getPatternIcon(PatternType type) {
    switch (type) {
      case PatternType.subjectDayPreference:
        return Icons.calendar_today;
      case PatternType.subjectPeriodPreference:
        return Icons.access_time;
      case PatternType.teacherTimePreference:
        return Icons.person;
      case PatternType.consecutivePattern:
        return Icons.view_week;
    }
  }

  String _getPatternTypeLabel(PatternType type) {
    switch (type) {
      case PatternType.subjectDayPreference:
        return 'تفضيلات الأيام للمواد';
      case PatternType.subjectPeriodPreference:
        return 'تفضيلات الحصص للمواد';
      case PatternType.teacherTimePreference:
        return 'تفضيلات المعلمين';
      case PatternType.consecutivePattern:
        return 'أنماط الحصص المتتالية';
    }
  }

  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.increasing:
        return Colors.red;
      case TrendDirection.decreasing:
        return Colors.blue;
      case TrendDirection.stable:
        return Colors.green;
    }
  }

  IconData _getTrendIcon(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.increasing:
        return Icons.trending_up;
      case TrendDirection.decreasing:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
    }
  }

  String _getTrendDirectionLabel(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.increasing:
        return 'تصاعدي';
      case TrendDirection.decreasing:
        return 'تنازلي';
      case TrendDirection.stable:
        return 'مستقر';
    }
  }

  void _showPatternDetails(DiscoveredPattern pattern) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 تفاصيل النمط'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pattern.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('الثقة', '${pattern.confidence.toInt()}%'),
              _buildDetailRow('التكرار', '${pattern.occurrences} مرة'),
              const Divider(),
              const Text('التفاصيل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pattern.details.entries.map((e) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showPreferenceDetails(TeacherPreference pref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('💖 ${pref.teacherName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pref.description),
              const SizedBox(height: 16),
              _buildDetailRow('الثقة', '${pref.confidence.toInt()}%'),
              const Divider(),
              const Text('التفاصيل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pref.details.entries.map((e) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
