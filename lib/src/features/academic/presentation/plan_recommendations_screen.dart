import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// شاشة التوصيات والمقترحات
class PlanRecommendationsScreen extends StatefulWidget {
  final String planId;

  const PlanRecommendationsScreen({
    required this.planId,
    super.key,
  });

  @override
  State<PlanRecommendationsScreen> createState() => _PlanRecommendationsScreenState();
}

class _PlanRecommendationsScreenState extends State<PlanRecommendationsScreen> {
  final TextEditingController _recommendationController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _recommendationController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('education_plans')
          .doc(widget.planId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final recommendations = List<Map<String, dynamic>>.from(
          data['recommendations'] ?? [
            {'text': 'متابعة مستمرة للخطة', 'priority': 'عالية', 'completed': false, 'createdAt': Timestamp.now()},
            {'text': 'تقييم دوري للتقدم', 'priority': 'متوسطة', 'completed': false, 'createdAt': Timestamp.now()},
            {'text': 'تعديل الاستراتيجيات حسب الحاجة', 'priority': 'عالية', 'completed': false, 'createdAt': Timestamp.now()},
          ]
        );
        
        setState(() {
          _recommendations = recommendations;
        });
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }

  Future<void> _addRecommendation() async {
    if (_recommendationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال نص التوصية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newRecommendation = {
        'text': _recommendationController.text.trim(),
        'priority': _priorityController.text.trim().isEmpty ? 'متوسطة' : _priorityController.text.trim(),
        'completed': false,
        'createdAt': Timestamp.now(),
      };

      _recommendations.add(newRecommendation);

      await FirebaseFirestore.instance
          .collection('education_plans')
          .doc(widget.planId)
          .update({
        'recommendations': _recommendations,
        'lastUpdated': Timestamp.now(),
      });

      _recommendationController.clear();
      _priorityController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إضافة التوصية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRecommendation(int index) async {
    setState(() {
      _recommendations[index]['completed'] = !_recommendations[index]['completed'];
    });

    try {
      await FirebaseFirestore.instance
          .collection('education_plans')
          .doc(widget.planId)
          .update({
        'recommendations': _recommendations,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating recommendation: $e');
    }
  }

  Future<void> _deleteRecommendation(int index) async {
    setState(() {
      _recommendations.removeAt(index);
    });

    try {
      await FirebaseFirestore.instance
          .collection('education_plans')
          .doc(widget.planId)
          .update({
        'recommendations': _recommendations,
        'lastUpdated': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حذف التوصية'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error deleting recommendation: $e');
    }
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
            appBar: AppBar(title: const Text('التوصيات')),
            body: const Center(child: Text('لم يتم العثور على الخطة')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final planName = data['planName'] ?? data['title'] ?? 'خطة';
        final studentName = data['studentName'] ?? 'طالب';

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Column(
            children: [
              // الشريط العلوي البرتقالي
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade600, Colors.purple.shade700],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'التوصيات والمقترحات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showAddRecommendationDialog(),
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              
              // المحتوى
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // بطاقة معلومات الخطة
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade100, Colors.purple.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade300, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        planName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade800,
                                        ),
                                      ),
                                      Text(
                                        'الطالب: $studentName',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // إحصائيات التوصيات
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'إجمالي التوصيات',
                              _recommendations.length.toString(),
                              Icons.list_alt,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'المكتملة',
                              _recommendations.where((r) => r['completed'] == true).length.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'المعلقة',
                              _recommendations.where((r) => r['completed'] != true).length.toString(),
                              Icons.pending,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // عنوان التوصيات مع زر الإضافة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'قائمة التوصيات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddRecommendationDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('إضافة توصية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // قائمة التوصيات
                      if (_recommendations.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد توصيات حالياً',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اضغط على "إضافة توصية" لبدء إضافة التوصيات',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final recommendation = _recommendations[index];
                            return _buildRecommendationCard(recommendation, index);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation, int index) {
    final isCompleted = recommendation['completed'] == true;
    final priority = recommendation['priority'] ?? 'متوسطة';
    
    Color priorityColor;
    switch (priority) {
      case 'عالية':
        priorityColor = Colors.red;
        break;
      case 'متوسطة':
        priorityColor = Colors.orange;
        break;
      case 'منخفضة':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleRecommendation(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.transparent,
                      border: Border.all(
                        color: isCompleted ? Colors.green : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation['text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted ? Colors.grey.shade600 : Colors.black87,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 12,
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(index);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRecommendationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة توصية جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _recommendationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'نص التوصية',
                border: OutlineInputBorder(),
                hintText: 'أدخل التوصية هنا...',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priorityController.text.isEmpty ? 'متوسطة' : _priorityController.text,
              decoration: const InputDecoration(
                labelText: 'الأولوية',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'عالية', child: Text('عالية')),
                DropdownMenuItem(value: 'متوسطة', child: Text('متوسطة')),
                DropdownMenuItem(value: 'منخفضة', child: Text('منخفضة')),
              ],
              onChanged: (value) {
                _priorityController.text = value ?? 'متوسطة';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _recommendationController.clear();
              _priorityController.clear();
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    _addRecommendation();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التوصية'),
        content: const Text('هل تريد حذف هذه التوصية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecommendation(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}