import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// شاشة تقييم التقدم
class PlanProgressScreen extends StatefulWidget {
  final String planId;

  const PlanProgressScreen({
    required this.planId,
    super.key,
  });

  @override
  State<PlanProgressScreen> createState() => _PlanProgressScreenState();
}

class _PlanProgressScreenState extends State<PlanProgressScreen> {
  late TextEditingController _progressController;
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _progressController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('education_plans').doc(widget.planId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('تقييم التقدم')),
            body: const Center(child: Text('لم يتم العثور على الخطة')),
          );
        }

        final planData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text(
              'تقييم التقدم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue.shade700,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlanHeader(planData),
                const SizedBox(height: 24),
                _buildProgressMetrics(planData),
                const SizedBox(height: 24),
                _buildProgressChart(planData),
                const SizedBox(height: 24),
                _buildObjectivesProgress(planData),
                const SizedBox(height: 24),
                _buildUpdateProgressForm(planData),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanHeader(Map<String, dynamic> planData) {
    final planName = planData['planName'] ?? planData['title'] ?? 'خطة';
    final studentName = planData['studentName'] ?? 'طالب';
    final createdAt = (planData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final targetDate = (planData['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الطالب: $studentName',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.flag, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(targetDate),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetrics(Map<String, dynamic> planData) {
    final progress = (planData['progress'] as num?)?.toDouble() ?? 0.0;
    final completedObjectives = (planData['completedObjectives'] as num?)?.toInt() ?? 0;
    final totalObjectives = (planData['totalObjectives'] as num?)?.toInt() ?? 1;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مؤشرات التقدم',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'التقدم العام',
                    '${progress.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'الأهداف المكتملة',
                    '$completedObjectives/$totalObjectives',
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart(Map<String, dynamic> planData) {
    final progress = (planData['progress'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مخطط التقدم',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: progress,
                      color: Colors.green,
                      title: '${progress.toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: 100 - progress,
                      color: Colors.grey.shade300,
                      title: '${(100 - progress).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectivesProgress(Map<String, dynamic> planData) {
    final objectives = List<String>.from(planData['goals'] ?? planData['objectives'] ?? []);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقدم الأهداف',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (objectives.isEmpty)
              const Text('لا توجد أهداف محددة')
            else
              ...objectives.asMap().entries.map((entry) {
                final index = entry.key;
                final objective = entry.value;
                final isCompleted = index < (planData['completedObjectives'] ?? 0);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          objective,
                          style: TextStyle(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? Colors.grey : null,
                          ),
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

  Widget _buildUpdateProgressForm(Map<String, dynamic> planData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحديث التقدم',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _progressController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نسبة التقدم (%)',
                border: OutlineInputBorder(),
                hintText: 'أدخل نسبة التقدم من 0 إلى 100',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                hintText: 'أدخل ملاحظات حول التقدم',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateProgress(planData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'تحديث التقدم',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProgress(Map<String, dynamic> planData) async {
    if (_progressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال نسبة التقدم'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final progress = double.tryParse(_progressController.text);
    if (progress == null || progress < 0 || progress > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال نسبة صحيحة بين 0 و 100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('education_plans')
          .doc(widget.planId)
          .update({
        'progress': progress,
        'notes': _notesController.text,
        'lastUpdated': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث التقدم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        
        _progressController.clear();
        _notesController.clear();
        
        // إعادة تحميل الصفحة لإظهار التحديثات
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}