import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/behavior_data_service.dart';

/// شاشة سريعة لإضافة مخالفة سلوكية (لاختبار النظام)
class AddViolationQuickScreen extends StatefulWidget {
  const AddViolationQuickScreen({super.key});

  @override
  State<AddViolationQuickScreen> createState() => _AddViolationQuickScreenState();
}

class _AddViolationQuickScreenState extends State<AddViolationQuickScreen> {
  final _studentNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedViolationType = 'تأخر عن الطابور';
  String _selectedLevel = 'بسيط';
  int _points = 1;
  bool _isLoading = false;

  final List<String> _violationTypes = [
    'تأخر عن الطابور',
    'عدم أداء الواجب',
    'إزعاج في الفصل',
    'عدم احترام المعلم',
    'شجار مع زميل',
    'استخدام الهاتف',
    'عدم ارتداء الزي المدرسي',
    'أخرى',
  ];

  final Map<String, int> _levelPoints = {
    'بسيط': 1,
    'متوسط': 3,
    'شديد': 5,
    'خطير': 10,
  };

  @override
  void initState() {
    super.initState();
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
                colors: [Colors.red.shade600, Colors.red.shade700],
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
                    'إضافة مخالفة سلوكية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // للتوازن
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
                  // معلومات الطالب
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
                          'معلومات الطالب',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _studentNameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الطالب',
                            hintText: 'أدخل اسم الطالب',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // تفاصيل المخالفة
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
                          'تفاصيل المخالفة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        // نوع المخالفة
                        DropdownButtonFormField<String>(
                          value: _selectedViolationType,
                          decoration: const InputDecoration(
                            labelText: 'نوع المخالفة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.warning),
                          ),
                          items: _violationTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          )).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedViolationType = value);
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // مستوى المخالفة
                        DropdownButtonFormField<String>(
                          value: _selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'مستوى المخالفة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.priority_high),
                          ),
                          items: _levelPoints.keys.map((level) => DropdownMenuItem(
                            value: level,
                            child: Text('$level (${_levelPoints[level]} نقاط)'),
                          )).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLevel = value;
                                _points = _levelPoints[value] ?? 1;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // الوصف
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'وصف المخالفة (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // عرض النقاط
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'سيتم خصم $_points نقطة من الطالب',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // أزرار الإجراءات
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _studentNameController.text.isEmpty) ? null : _addViolation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('إضافة المخالفة'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ملاحظة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم تحديث جميع الإحصائيات تلقائياً عند إضافة المخالفة',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addViolation() async {
    if (_studentNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الطالب')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // إضافة المخالفة باستخدام الخدمة المركزية
      await BehaviorDataService.addBehavioralViolation(
        studentName: _studentNameController.text.trim(),
        studentId: '', // لا نحتاج studentId
        violationType: _selectedViolationType,
        level: _selectedLevel,
        description: _descriptionController.text.trim().isEmpty 
            ? _selectedViolationType 
            : _descriptionController.text.trim(),
        points: _points,
        studentGrade: '', // لا نحتاج studentGrade
        studentClass: '', // لا نحتاج studentClass
      );

      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة المخالفة بنجاح وتحديث جميع الإحصائيات'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إضافة المخالفة: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}