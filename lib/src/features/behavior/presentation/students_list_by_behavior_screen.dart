import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';

/// شاشة قائمة الطلاب حسب السلوك
class StudentsListByBehaviorScreen extends ConsumerStatefulWidget {
  const StudentsListByBehaviorScreen({super.key});

  @override
  ConsumerState<StudentsListByBehaviorScreen> createState() => _StudentsListByBehaviorScreenState();
}

class _StudentsListByBehaviorScreenState extends ConsumerState<StudentsListByBehaviorScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';

      // جلب بيانات المخالفات والسلوك الإيجابي بالتوازي
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('behavioral_violations').get(),
        FirebaseFirestore.instance.collection('positive_behavior').get(),
        FirebaseFirestore.instance.collection('behavioral_cases').get(),
      ]);

      final violationsQuery = results[0];
      final positiveBehaviorQuery = results[1];
      final casesQuery = results[2];

      // جلب الطلاب - نحاول من Schools/{schoolId}/Students أولاً ثم من students
      List<QueryDocumentSnapshot> studentDocs = [];

      if (schoolId.isNotEmpty) {
        final schoolStudents = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .get();
        studentDocs = schoolStudents.docs;
      }

      // إذا لم نجد طلاباً، نجلب من المخالفات والحالات مباشرة
      if (studentDocs.isEmpty) {
        // بناء قائمة الطلاب من بيانات المخالفات والحالات
        final Map<String, Map<String, dynamic>> studentsFromBehavior = {};

        for (var doc in violationsQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['studentName'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          studentsFromBehavior[name] ??= {
            'id': data['studentId'] ?? name,
            'name': name,
            'grade': data['studentGrade'] ?? '',
            'className': data['studentClass'] ?? '',
          };
        }

        for (var doc in casesQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['studentName'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          studentsFromBehavior[name] ??= {
            'id': data['studentId'] ?? name,
            'name': name,
            'grade': data['studentGrade'] ?? '',
            'className': data['studentClass'] ?? '',
          };
        }

        final studentsData = <Map<String, dynamic>>[];
        for (var entry in studentsFromBehavior.entries) {
          final studentName = entry.key;
          final studentId = entry.value['id'] as String;
          final studentGrade = entry.value['grade'] as String;
          final studentClass = entry.value['className'] as String;

          final studentViolations = violationsQuery.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['studentId'] == studentId || d['studentName'] == studentName;
          }).toList();

          final studentPositive = positiveBehaviorQuery.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['studentId'] == studentId || d['studentName'] == studentName;
          }).toList();

          final studentCases = casesQuery.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['studentId'] == studentId || d['studentName'] == studentName;
          }).toList();

          int violationPoints = 0;
          int positivePoints = 0;
          String lastViolationType = '';
          DateTime? lastViolationDate;

          for (var v in studentViolations) {
            final d = v.data() as Map<String, dynamic>;
            violationPoints += (d['points'] as int?) ?? 1;
            final ts = (d['timestamp'] as Timestamp?)?.toDate();
            if (lastViolationDate == null || (ts != null && ts.isAfter(lastViolationDate))) {
              lastViolationDate = ts;
              lastViolationType = d['violationType'] ?? '';
            }
          }
          for (var p in studentPositive) {
            final d = p.data() as Map<String, dynamic>;
            positivePoints += (d['points'] as int?) ?? 1;
          }

          studentsData.add(_buildStudentEntry(
            studentId: studentId,
            studentName: studentName,
            studentGrade: studentGrade,
            studentClass: studentClass,
            violationCount: studentViolations.length,
            positiveCount: studentPositive.length,
            casesCount: studentCases.length,
            violationPoints: violationPoints,
            positivePoints: positivePoints,
            lastViolationType: lastViolationType,
            lastViolationDate: lastViolationDate,
          ));
        }

        studentsData.sort((a, b) => (b['netScore'] as int).compareTo(a['netScore'] as int));
        setState(() {
          _students = studentsData;
          _isLoading = false;
        });
        return;
      }

      // معالجة الطلاب من Schools/{schoolId}/Students
      final studentsData = <Map<String, dynamic>>[];

      for (var studentDoc in studentDocs) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final studentId = studentDoc.id;
        final studentName = (studentData['name'] ??
            studentData['fullName'] ??
            studentData['studentName'] ??
            'غير محدد').toString();
        final studentGrade = (studentData['grade'] ??
            studentData['gradeLevel'] ??
            studentData['class'] ??
            '').toString();
        final studentClass = (studentData['className'] ??
            studentData['classRoom'] ??
            studentData['section'] ??
            '').toString();

        // حساب المخالفات
        final studentViolations = violationsQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['studentId'] == studentId || data['studentName'] == studentName;
        }).toList();

        // حساب السلوك الإيجابي
        final studentPositiveBehavior = positiveBehaviorQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['studentId'] == studentId || data['studentName'] == studentName;
        }).toList();

        final studentCases = casesQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['studentId'] == studentId || data['studentName'] == studentName;
        }).toList();

        // حساب النقاط
        int violationPoints = 0;
        int positivePoints = 0;
        String lastViolationType = '';
        DateTime? lastViolationDate;

        for (var violation in studentViolations) {
          final data = violation.data() as Map<String, dynamic>;
          violationPoints += (data['points'] as int?) ?? 1;
          
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          if (lastViolationDate == null || (timestamp != null && timestamp.isAfter(lastViolationDate))) {
            lastViolationDate = timestamp;
            lastViolationType = data['violationType'] ?? '';
          }
        }

        for (var positive in studentPositiveBehavior) {
          final data = positive.data() as Map<String, dynamic>;
          positivePoints += (data['points'] as int?) ?? 1;
        }

        studentsData.add(_buildStudentEntry(
          studentId: studentId,
          studentName: studentName,
          studentGrade: studentGrade,
          studentClass: studentClass,
          violationCount: studentViolations.length,
          positiveCount: studentPositiveBehavior.length,
          casesCount: studentCases.length,
          violationPoints: violationPoints,
          positivePoints: positivePoints,
          lastViolationType: lastViolationType,
          lastViolationDate: lastViolationDate,
        ));
      }

      studentsData.sort((a, b) => (b['netScore'] as int).compareTo(a['netScore'] as int));

      setState(() {
        _students = studentsData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildStudentEntry({
    required String studentId,
    required String studentName,
    required String studentGrade,
    required String studentClass,
    required int violationCount,
    required int positiveCount,
    required int casesCount,
    required int violationPoints,
    required int positivePoints,
    required String lastViolationType,
    required DateTime? lastViolationDate,
  }) {
    final netScore = positivePoints - violationPoints;
    String behaviorCategory;
    Color categoryColor;
    IconData categoryIcon;

    if (netScore >= 10) {
      behaviorCategory = 'ممتاز';
      categoryColor = Colors.green;
      categoryIcon = Icons.star;
    } else if (netScore >= 0) {
      behaviorCategory = 'جيد';
      categoryColor = Colors.blue;
      categoryIcon = Icons.thumb_up;
    } else if (netScore >= -5) {
      behaviorCategory = 'يحتاج متابعة';
      categoryColor = Colors.orange;
      categoryIcon = Icons.warning;
    } else {
      behaviorCategory = 'حرج';
      categoryColor = Colors.red;
      categoryIcon = Icons.priority_high;
    }

    return {
      'id': studentId,
      'name': studentName,
      'grade': studentGrade,
      'className': studentClass,
      'violationCount': violationCount,
      'positiveCount': positiveCount,
      'casesCount': casesCount,
      'violationPoints': violationPoints,
      'positivePoints': positivePoints,
      'netScore': netScore,
      'behaviorCategory': behaviorCategory,
      'categoryColor': categoryColor,
      'categoryIcon': categoryIcon,
      'lastViolationType': lastViolationType,
      'lastViolationDate': lastViolationDate,
    };
  }

  List<Map<String, dynamic>> get _filteredStudents {
    var filtered = _students.where((student) {
      // فلترة حسب البحث
      if (_searchQuery.isNotEmpty) {
        final name = student['name'] as String;
        final grade = student['grade'] as String;
        final className = student['className'] as String;
        
        if (!name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !grade.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !className.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // فلترة حسب التصنيف
      if (_selectedCategory != 'all') {
        final category = student['behaviorCategory'] as String;
        switch (_selectedCategory) {
          case 'excellent':
            return category == 'ممتاز';
          case 'good':
            return category == 'جيد';
          case 'needs_attention':
            return category == 'يحتاج متابعة';
          case 'critical':
            return category == 'حرج';
        }
      }

      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;

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
                colors: [Colors.purple.shade600, Colors.purple.shade700],
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
                    'الطلاب حسب السلوك',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => _loadStudents(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // شريط البحث والفلاتر
          Container(
            margin: const EdgeInsets.all(16),
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
              children: [
                // شريط البحث
                TextField(
                  decoration: InputDecoration(
                    hintText: 'البحث عن طالب...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                
                const SizedBox(height: 16),
                
                // فلتر التصنيف
                Row(
                  children: [
                    const Text('التصنيف: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip('all', 'الكل', Colors.grey),
                            const SizedBox(width: 8),
                            _buildCategoryChip('excellent', 'ممتاز', Colors.green),
                            const SizedBox(width: 8),
                            _buildCategoryChip('good', 'جيد', Colors.blue),
                            const SizedBox(width: 8),
                            _buildCategoryChip('needs_attention', 'يحتاج متابعة', Colors.orange),
                            const SizedBox(width: 8),
                            _buildCategoryChip('critical', 'حرج', Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // إحصائيات سريعة
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('إجمالي الطلاب', _students.length.toString(), Colors.purple),
                _buildQuickStat('ممتاز', _students.where((s) => s['behaviorCategory'] == 'ممتاز').length.toString(), Colors.green),
                _buildQuickStat('يحتاج متابعة', _students.where((s) => s['behaviorCategory'] == 'يحتاج متابعة').length.toString(), Colors.orange),
                _buildQuickStat('حرج', _students.where((s) => s['behaviorCategory'] == 'حرج').length.toString(), Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // قائمة الطلاب
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا توجد نتائج مطابقة للبحث'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _buildStudentCard(student, index + 1);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label, Color color) {
    final isSelected = _selectedCategory == value;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int rank) {
    final categoryColor = student['categoryColor'] as Color;
    final categoryIcon = student['categoryIcon'] as IconData;
    final netScore = student['netScore'] as int;
    final studentName = student['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // معلومات الطالب
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withOpacity(0.1),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${student['grade']} - ${student['className']}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        student['behaviorCategory'],
                        style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'النقاط: $netScore',
                      style: TextStyle(
                        fontSize: 10,
                        color: netScore >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(children: [
                  const Icon(Icons.star, color: Colors.green, size: 16),
                  Text('${student['positiveCount']}', style: const TextStyle(fontSize: 10)),
                ]),
                const SizedBox(width: 8),
                Column(children: [
                  const Icon(Icons.warning, color: Colors.red, size: 16),
                  Text('${student['violationCount']}', style: const TextStyle(fontSize: 10)),
                ]),
                const SizedBox(width: 8),
                Column(children: [
                  const Icon(Icons.folder_open, color: Colors.orange, size: 16),
                  Text('${student['casesCount'] ?? 0}', style: const TextStyle(fontSize: 10)),
                ]),
              ],
            ),
            onTap: () => _showStudentDetails(student),
          ),

          // أزرار الإجراءات
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // إضافة مخالفة
                Expanded(
                  child: _actionButton(
                    label: 'مخالفة',
                    icon: Icons.warning_amber,
                    color: Colors.red,
                    onTap: () => _addViolationForStudent(student),
                  ),
                ),
                const SizedBox(width: 8),
                // إنشاء حالة
                Expanded(
                  child: _actionButton(
                    label: 'حالة',
                    icon: Icons.folder_special,
                    color: Colors.deepOrange,
                    onTap: () => _createCaseForStudent(student),
                  ),
                ),
                const SizedBox(width: 8),
                // سلوك إيجابي
                Expanded(
                  child: _actionButton(
                    label: 'إيجابي',
                    icon: Icons.star,
                    color: Colors.green,
                    onTap: () => _addPositiveBehaviorForStudent(student),
                  ),
                ),
                const SizedBox(width: 8),
                // متابعة
                Expanded(
                  child: _actionButton(
                    label: 'متابعة',
                    icon: Icons.comment,
                    color: Colors.blue,
                    onTap: () => _showStudentDetails(student),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // إضافة مخالفة للطالب
  void _addViolationForStudent(Map<String, dynamic> student) {
    final descController = TextEditingController();
    String selectedType = 'تأخر عن الطابور';
    String selectedLevel = 'بسيط';
    bool isSubmitting = false;
    final outerContext = context;

    final violationTypes = ['تأخر عن الطابور', 'عدم أداء الواجب', 'إزعاج في الفصل',
        'عدم احترام المعلم', 'شجار مع زميل', 'استخدام الهاتف', 'أخرى'];
    final levelPoints = {'بسيط': 1, 'متوسط': 3, 'شديد': 5, 'خطير': 10};

    showDialog(
      context: outerContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('مخالفة: ${student['name']}', style: const TextStyle(fontSize: 15))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'نوع المخالفة', border: OutlineInputBorder()),
                items: violationTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) { if (v != null) setS(() => selectedType = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedLevel,
                decoration: const InputDecoration(labelText: 'المستوى', border: OutlineInputBorder()),
                items: levelPoints.keys.map((l) => DropdownMenuItem(
                  value: l,
                  child: Text('$l (${levelPoints[l]} نقاط)'),
                )).toList(),
                onChanged: (v) { if (v != null) setS(() => selectedLevel = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف (اختياري)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setS(() => isSubmitting = true);
                try {
                  await FirebaseFirestore.instance.collection('behavioral_violations').add({
                    'studentName': student['name'],
                    'studentId': student['id'] ?? '',
                    'studentGrade': student['grade'] ?? '',
                    'studentClass': student['className'] ?? '',
                    'violationType': selectedType,
                    'level': selectedLevel,
                    'description': descController.text.trim().isEmpty ? selectedType : descController.text.trim(),
                    'points': levelPoints[selectedLevel] ?? 1,
                    'timestamp': Timestamp.now(),
                    'status': 'active',
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل المخالفة بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadStudents();
                } catch (e) {
                  setS(() => isSubmitting = false);
                  ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
  }

  // إنشاء حالة للطالب
  void _createCaseForStudent(Map<String, dynamic> student) {
    final descController = TextEditingController();
    String selectedType = 'سلوكي';
    String selectedPriority = 'متوسط';
    String assignedTo = 'المرشد الطلابي';
    bool isSubmitting = false;
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.folder_special, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(child: Text('حالة: ${student['name']}', style: const TextStyle(fontSize: 15))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'نوع الحالة', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'سلوكي', child: Text('سلوكي')),
                  DropdownMenuItem(value: 'أكاديمي', child: Text('أكاديمي')),
                  DropdownMenuItem(value: 'اجتماعي', child: Text('اجتماعي')),
                  DropdownMenuItem(value: 'نفسي', child: Text('نفسي')),
                ],
                onChanged: (v) { if (v != null) setS(() => selectedType = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: const InputDecoration(labelText: 'الأولوية', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'منخفض', child: Text('منخفض')),
                  DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                  DropdownMenuItem(value: 'عالي', child: Text('عالي')),
                ],
                onChanged: (v) { if (v != null) setS(() => selectedPriority = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: assignedTo,
                decoration: const InputDecoration(labelText: 'المسؤول', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'المرشد الطلابي', child: Text('المرشد الطلابي')),
                  DropdownMenuItem(value: 'وكيل الطلاب', child: Text('وكيل الطلاب')),
                  DropdownMenuItem(value: 'مدير المدرسة', child: Text('مدير المدرسة')),
                ],
                onChanged: (v) { if (v != null) setS(() => assignedTo = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف الحالة', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setS(() => isSubmitting = true);
                try {
                  await FirebaseFirestore.instance.collection('behavioral_cases').add({
                    'studentName': student['name'],
                    'studentId': student['id'] ?? '',
                    'studentGrade': student['grade'] ?? '',
                    'studentClass': student['className'] ?? '',
                    'caseType': selectedType,
                    'priority': selectedPriority,
                    'description': descController.text.trim(),
                    'assignedTo': assignedTo,
                    'status': 'active',
                    'createdAt': Timestamp.now(),
                    'updatedAt': Timestamp.now(),
                    'followUps': [],
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('تم إنشاء الحالة بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadStudents();
                } catch (e) {
                  setS(() => isSubmitting = false);
                  ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  // إضافة سلوك إيجابي للطالب
  void _addPositiveBehaviorForStudent(Map<String, dynamic> student) {
    final descController = TextEditingController();
    String selectedType = 'مشاركة فعّالة';
    int points = 3;
    bool isSubmitting = false;
    final outerContext = context;

    final behaviorTypes = ['مشاركة فعّالة', 'مساعدة زميل', 'تفوق دراسي', 'سلوك مثالي', 'إنجاز مميز', 'أخرى'];
    final pointsOptions = [1, 2, 3, 5, 10];

    showDialog(
      context: outerContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.star, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('إيجابي: ${student['name']}', style: const TextStyle(fontSize: 15))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'نوع السلوك', border: OutlineInputBorder()),
                items: behaviorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) { if (v != null) setS(() => selectedType = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: points,
                decoration: const InputDecoration(labelText: 'النقاط', border: OutlineInputBorder()),
                items: pointsOptions.map((p) => DropdownMenuItem(value: p, child: Text('$p نقاط'))).toList(),
                onChanged: (v) { if (v != null) setS(() => points = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف (اختياري)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setS(() => isSubmitting = true);
                try {
                  await FirebaseFirestore.instance.collection('positive_behavior').add({
                    'studentName': student['name'],
                    'studentId': student['id'] ?? '',
                    'studentGrade': student['grade'] ?? '',
                    'studentClass': student['className'] ?? '',
                    'behaviorType': selectedType,
                    'description': descController.text.trim().isEmpty ? selectedType : descController.text.trim(),
                    'points': points,
                    'timestamp': Timestamp.now(),
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل السلوك الإيجابي بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadStudents();
                } catch (e) {
                  setS(() => isSubmitting = false);
                  ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الصف: ${student['grade']} - ${student['className']}'),
            const SizedBox(height: 8),
            Text('التصنيف السلوكي: ${student['behaviorCategory']}'),
            const SizedBox(height: 8),
            Text('إجمالي النقاط: ${student['netScore']}'),
            const SizedBox(height: 8),
            Text('السلوك الإيجابي: ${student['positiveCount']} (${student['positivePoints']} نقطة)'),
            const SizedBox(height: 8),
            Text('المخالفات: ${student['violationCount']} (${student['violationPoints']} نقطة)'),
            const SizedBox(height: 8),
            Text('الحالات السلوكية: ${student['casesCount'] ?? 0}'),
            if (student['lastViolationType'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('آخر مخالفة: ${student['lastViolationType']}'),
            ],
          ],
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
}