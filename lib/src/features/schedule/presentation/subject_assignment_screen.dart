import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

class SubjectAssignmentScreen extends ConsumerStatefulWidget {
  const SubjectAssignmentScreen({super.key});

  @override
  ConsumerState<SubjectAssignmentScreen> createState() => _SubjectAssignmentScreenState();
}

class _SubjectAssignmentScreenState extends ConsumerState<SubjectAssignmentScreen> {
  String? _schoolId;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];
  Map<String, List<Map<String, dynamic>>> _assignments = {}; // classId -> [assignments]
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Clipboard for copy/paste
  List<Map<String, dynamic>>? _copiedAssignments;
  String? _copiedFromClassName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _schoolId = user.schoolId;
      _isLoading = true;
    });

    try {
      // Load classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Classes')
          .get();

      _classes = classesSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc.data()['name'] ?? doc.id,
        };
      }).toList();

      // Load teachers
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .get();

      _teachers = teachersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'معلم',
          'specialization': data['specialization'] ?? 'غير محدد',
          'nisab': data['nisab'] ?? data['weeklyQuota'] ?? 24,
        };
      }).toList();

      // Load existing assignments
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/SubjectAssignments')
          .get();

      _assignments = {};
      for (var doc in assignmentsSnapshot.docs) {
        final data = doc.data();
        final classId = data['classId'];
        if (!_assignments.containsKey(classId)) {
          _assignments[classId] = [];
        }
        _assignments[classId]!.add({
          'id': doc.id,
          'teacherId': data['teacherId'],
          'teacherName': data['teacherName'],
          'subjectName': data['subjectName'],
          'weeklyHours': data['weeklyHours'] ?? 5,
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAssignment(String classId, String className) async {
    String? selectedTeacherId;
    String? subjectName;
    int weeklyHours = 5;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('إسناد مادة - $className'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedTeacherId,
                  decoration: InputDecoration(
                    labelText: 'اختر المعلم',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _teachers.map((teacher) {
                    return DropdownMenuItem<String>(
                      value: teacher['id'] as String,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(teacher['name'] as String),
                          Text(
                            teacher['specialization'] as String,
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedTeacherId = value;
                      final teacher = _teachers.firstWhere((t) => t['id'] == value);
                      subjectName = teacher['specialization'];
                    });
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  initialValue: subjectName,
                  decoration: InputDecoration(
                    labelText: 'اسم المادة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book),
                  ),
                  onChanged: (value) => subjectName = value,
                ),
                SizedBox(height: 16),
                TextFormField(
                  initialValue: weeklyHours.toString(),
                  decoration: InputDecoration(
                    labelText: 'عدد الحصص الأسبوعية',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => weeklyHours = int.tryParse(value) ?? 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedTeacherId != null && subjectName != null && subjectName!.isNotEmpty) {
                  final teacher = _teachers.firstWhere((t) => t['id'] == selectedTeacherId);
                  Navigator.pop(context, {
                    'teacherId': selectedTeacherId,
                    'teacherName': teacher['name'],
                    'subjectName': subjectName,
                    'weeklyHours': weeklyHours,
                  });
                }
              },
              child: Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('Schools/$_schoolId/SubjectAssignments')
            .add({
          'classId': classId,
          'className': className,
          'teacherId': result['teacherId'],
          'teacherName': result['teacherName'],
          'subjectName': result['subjectName'],
          'weeklyHours': result['weeklyHours'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          if (!_assignments.containsKey(classId)) {
            _assignments[classId] = [];
          }
          _assignments[classId]!.add({
            'id': docRef.id,
            ...result,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم إسناد المادة بنجاح')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e')),
        );
      }
    }
  }

  Future<void> _deleteAssignment(String classId, String assignmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/SubjectAssignments')
          .doc(assignmentId)
          .delete();

      setState(() {
        _assignments[classId]?.removeWhere((a) => a['id'] == assignmentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حذف الإسناد')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e')),
      );
    }
  }

  void _copyAssignments(String classId, String className) {
    final assignments = _assignments[classId] ?? [];
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ لا توجد إسنادات لنسخها')),
      );
      return;
    }

    setState(() {
      _copiedAssignments = List.from(assignments);
      _copiedFromClassName = className;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ ${assignments.length} إسناد من $className'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pasteAssignments(String classId, String className) async {
    if (_copiedAssignments == null || _copiedAssignments!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ لا توجد إسنادات منسوخة')),
      );
      return;
    }

    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تأكيد اللصق'),
          content: Text(
            'هل تريد لصق ${_copiedAssignments!.length} إسناد من $_copiedFromClassName إلى $className؟\n\n'
            'سيتم إضافة الإسنادات الجديدة مع الإسنادات الموجودة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('لصق'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Paste assignments
      for (var assignment in _copiedAssignments!) {
        final docRef = await FirebaseFirestore.instance
            .collection('Schools/$_schoolId/SubjectAssignments')
            .add({
          'classId': classId,
          'className': className,
          'teacherId': assignment['teacherId'],
          'teacherName': assignment['teacherName'],
          'subjectName': assignment['subjectName'],
          'weeklyHours': assignment['weeklyHours'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!_assignments.containsKey(classId)) {
          _assignments[classId] = [];
        }
        _assignments[classId]!.add({
          'id': docRef.id,
          'teacherId': assignment['teacherId'],
          'teacherName': assignment['teacherName'],
          'subjectName': assignment['subjectName'],
          'weeklyHours': assignment['weeklyHours'],
        });
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم لصق ${_copiedAssignments!.length} إسناد بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('إسناد المواد للمعلمين', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          if (_copiedAssignments != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_paste, size: 16, color: Colors.blue.shade700),
                  SizedBox(width: 4),
                  Text(
                    '${_copiedAssignments!.length} منسوخ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildClassesList()),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.assignment_ind, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'إدارة إسناد المواد',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'حدد المعلم والمادة لكل فصل بدقة',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.yellow.shade200, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'نصيحة: استخدم نسخ/لصق لتوفير الوقت',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList() {
    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text('لا توجد فصول', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classData = _classes[index];
        final classId = classData['id'];
        final className = classData['name'];
        final assignments = _assignments[classId] ?? [];

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.class_, color: Colors.deepPurple),
            ),
            title: Text(
              className,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${assignments.length} مادة مسندة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (assignments.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.content_copy, color: Colors.blue, size: 20),
                    onPressed: () => _copyAssignments(classId, className),
                    tooltip: 'نسخ الإسنادات',
                  ),
                if (_copiedAssignments != null && _copiedAssignments!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.content_paste, color: Colors.green, size: 20),
                    onPressed: () => _pasteAssignments(classId, className),
                    tooltip: 'لصق الإسنادات',
                  ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.orange),
                  onPressed: () => _addAssignment(classId, className),
                  tooltip: 'إضافة مادة',
                ),
              ],
            ),
            children: [
              if (assignments.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'لا توجد مواد مسندة',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'اضغط + لإضافة مادة أو 📋 للصق من فصل آخر',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: assignments.length,
                  itemBuilder: (context, i) {
                    final assignment = assignments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.book, color: Colors.blue.shade700, size: 20),
                      ),
                      title: Text(
                        assignment['subjectName'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${assignment['teacherName']} • ${assignment['weeklyHours']} حصة/أسبوع',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAssignment(classId, assignment['id']),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
