import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../application/workload_analysis_service.dart';
import '../domain/workload_analysis.dart';
import 'teacher_workload_detail_screen.dart';
import 'workload_learning_screen.dart';

// 📊 شاشة تحليل نصاب المعلمين - نظام حقيقي وذكي
class WorkloadAnalysisScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const WorkloadAnalysisScreen({Key? key, required this.schoolId})
    : super(key: key);

  @override
  ConsumerState<WorkloadAnalysisScreen> createState() =>
      _WorkloadAnalysisScreenState();
}

class _WorkloadAnalysisScreenState
    extends ConsumerState<WorkloadAnalysisScreen> {
  WorkloadAnalysis? _analysis;
  bool _isLoading = true;
  String? _error;
  String _effectiveSchoolId = '';

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  String _resolveSchoolId() {
    final direct = widget.schoolId.trim();
    if (direct.isNotEmpty) return direct;
    final fromAuth = (ref.read(authStateProvider).value?.schoolId ?? '').trim();
    return fromAuth;
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resolved = _resolveSchoolId();
      if (resolved.isEmpty) {
        setState(() {
          _effectiveSchoolId = '';
          _analysis = null;
          _isLoading = false;
          _error = 'لا يمكن تحديد المدرسة الحالية.';
        });
        return;
      }
      _effectiveSchoolId = resolved;
      final service = ref.read(workloadAnalysisServiceProvider);
      final analysis = await service.analyzeWorkload(_effectiveSchoolId);

      setState(() {
        _analysis = analysis;
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
        title: const Text('📊 توزيع نصاب المعلمين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'رؤى الذكاء الاصطناعي',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkloadLearningScreen(schoolId: _effectiveSchoolId),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnalysis),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final msg = _error ?? '';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('حدث خطأ: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalysis,
              child: const Text('إعادة المحاولة'),
            ),
            if (msg.contains('No teachers found')) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.push('/teachers-list'),
                child: const Text('فتح قائمة المعلمين'),
              ),
            ],
            if (msg.contains('No schedule found')) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.push('/smart-schedule'),
                child: const Text('فتح الجدول الذكي'),
              ),
            ],
          ],
        ),
      );
    }

    if (_analysis == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    return RefreshIndicator(
      onRefresh: _loadAnalysis,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFairnessCard(),
            const SizedBox(height: 16),
            _buildStatisticsCards(),
            const SizedBox(height: 16),
            _buildRecommendationsSection(),
            const SizedBox(height: 16),
            _buildTeachersSection(),
          ],
        ),
      ),
    );
  }

  // 🎯 بطاقة العدالة الرئيسية
  Widget _buildFairnessCard() {
    final fairness = _analysis!.fairnessScore;
    final color = _getFairnessColor(fairness);
    final emoji = _getFairnessEmoji(fairness);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'مؤشر العدالة',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${fairness.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 48,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getFairnessLabel(fairness),
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // 📊 بطاقات الإحصائيات
  Widget _buildStatisticsCards() {
    final stats = _analysis!.statistics;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '⚖️',
            'متوازن',
            '${stats['balanced']}',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '⚠️',
            'محمّل',
            '${stats['overloaded']}',
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '📉',
            'أقل',
            '${stats['underloaded']}',
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
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
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 قسم التوصيات الذكية
  Widget _buildRecommendationsSection() {
    final recommendations = _analysis!.recommendations;

    if (recommendations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                '✨ التوزيع ممتاز!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'لا توجد توصيات للتحسين',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '💡 توصيات ذكية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Chip(
              label: Text('${recommendations.length}'),
              backgroundColor: Colors.blue,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recommendations.take(5).map((rec) => _buildRecommendationCard(rec)),
        if (recommendations.length > 5)
          TextButton(
            onPressed: () {
              _showAllRecommendations();
            },
            child: Text('عرض جميع التوصيات (${recommendations.length})'),
          ),
      ],
    );
  }

  Widget _buildRecommendationCard(SmartRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(rec.priority),
          child: Text(
            '${rec.priority}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          rec.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text('تأثير: ${rec.impactScore.toStringAsFixed(1)}%'),
                const SizedBox(width: 16),
                if (rec.autoApplicable)
                  const Chip(
                    label: Text('تلقائي', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: rec.autoApplicable
            ? IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                onPressed: () => _applyRecommendation(rec),
              )
            : const Icon(Icons.info_outline, color: Colors.grey),
        onTap: () => _showRecommendationDetails(rec),
      ),
    );
  }

  // 👥 قسم المعلمين
  Widget _buildTeachersSection() {
    final teachers = _analysis!.teachers;

    // ترتيب حسب الحالة
    final sorted = List<TeacherWorkload>.from(teachers);
    sorted.sort((a, b) {
      if (a.status != b.status) {
        if (a.status == WorkloadStatus.overloaded) return -1;
        if (b.status == WorkloadStatus.overloaded) return 1;
        if (a.status == WorkloadStatus.underloaded) return -1;
        if (b.status == WorkloadStatus.underloaded) return 1;
      }
      return b.difference.abs().compareTo(a.difference.abs());
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👥 المعلمون',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...sorted.map((teacher) => _buildTeacherCard(teacher)),
      ],
    );
  }

  Widget _buildTeacherCard(TeacherWorkload teacher) {
    final statusColor = _getStatusColor(teacher.status);
    final statusIcon = _getStatusIcon(teacher.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherWorkloadDetailScreen(
                schoolId: widget.schoolId,
                teacher: teacher,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher.teacherName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          teacher.subject,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${teacher.currentLoad} حصة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'المثالي: ${teacher.idealLoad}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              if (teacher.issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...teacher.issues
                    .take(2)
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                issue,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 دوال مساعدة للألوان والأيقونات
  Color _getFairnessColor(double fairness) {
    if (fairness >= 80) return Colors.green;
    if (fairness >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getFairnessEmoji(double fairness) {
    if (fairness >= 90) return '🌟';
    if (fairness >= 80) return '😊';
    if (fairness >= 70) return '🙂';
    if (fairness >= 60) return '😐';
    return '😟';
  }

  String _getFairnessLabel(double fairness) {
    if (fairness >= 90) return 'ممتاز جداً';
    if (fairness >= 80) return 'جيد جداً';
    if (fairness >= 70) return 'جيد';
    if (fairness >= 60) return 'مقبول';
    return 'يحتاج تحسين';
  }

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

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 4) return Colors.orange;
    if (priority >= 3) return Colors.blue;
    return Colors.grey;
  }

  // 🔧 دوال التفاعل
  Future<void> _applyRecommendation(SmartRecommendation rec) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تطبيق التوصية'),
        content: Text('هل تريد تطبيق: ${rec.description}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(workloadAnalysisServiceProvider);
        await service.applyRecommendation(
          schoolId: widget.schoolId,
          recommendation: rec,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تطبيق التوصية بنجاح')),
          );
          _loadAnalysis();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ خطأ: $e')));
        }
      }
    }
  }

  void _showRecommendationDetails(SmartRecommendation rec) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('💡 ${rec.description}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('الأولوية', '${rec.priority}/5'),
              _buildDetailRow(
                'التأثير',
                '${rec.impactScore.toStringAsFixed(1)}%',
              ),
              _buildDetailRow(
                'تطبيق تلقائي',
                rec.autoApplicable ? 'نعم' : 'لا',
              ),
              _buildDetailRow(
                'المعلمون المتأثرون',
                '${rec.affectedTeachers.length}',
              ),
              const Divider(),
              const Text(
                'التفاصيل:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...rec.details.entries.map(
                (e) => Padding(
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
          if (rec.autoApplicable)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyRecommendation(rec);
              },
              child: const Text('تطبيق'),
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

  void _showAllRecommendations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '💡 جميع التوصيات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _analysis!.recommendations.length,
                itemBuilder: (context, index) {
                  return _buildRecommendationCard(
                    _analysis!.recommendations[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
