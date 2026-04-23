import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

class AssignSubjectsScreen extends ConsumerStatefulWidget {
  const AssignSubjectsScreen({super.key});

  @override
  ConsumerState<AssignSubjectsScreen> createState() => _AssignSubjectsScreenState();
}

class _AssignSubjectsScreenState extends ConsumerState<AssignSubjectsScreen> {
  String? _schoolId;
  String? _selectedClassId;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchoolId();
  }

  Future<void> _loadSchoolId() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      setState(() => _schoolId = user.schoolId);
      _loadTeachers();
    }
  }

  Future<void> _loadTeachers() async {
    if (_schoolId == null) return;

    try {
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .get();

      setState(() {
        _teachers = teachersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'معلم',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _assignSubject(
    String classId,
    String className,
    Map<String, dynamic> subject,
    int index,
  ) async {
    if (_schoolId == null) return;

    // Show dialog to select teacher
    final selectedTeacher = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر معلم لمادة ${subject['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _teachers.length,
            itemBuilder: (context, index) {
              final teacher = _teachers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(teacher['name']),
                onTap: () => Navigator.pop(context, teacher),
              );
            },
          ),
        ),
      ),
    );

    if (selectedTeacher == null) return;

    // Show dialog to enter weekly hours
    final weeklyHoursController = TextEditingController(
      text: subject['weeklyHours']?.toString() ?? '4',
    );

    final weeklyHours = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('عدد الحصص الأسبوعية'),
        content: TextField(
          controller: weeklyHoursController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'عدد الحصص',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(weeklyHoursController.text) ?? 4;
              Navigator.pop(context, hours);
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );

    if (weeklyHours == null) return;

    setState(() => _isLoading = true);

    try {
      // Get current class data
      final classDoc = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Classes')
          .doc(classId)
          .get();

      final classData = classDoc.data() ?? {};
      final subjects = List<Map<String, dynamic>>.from(classData['subjects'] ?? []);

      // Update the subject
      subjects[index] = {
        'id': subject['id'] ?? subject['name'],
        'name': subject['name'],
        'teacherId': selectedTeacher['id'],
        'teacherName': selectedTeacher['name'],
        'weeklyHours': weeklyHours,
      };

      // Save back to Firestore
      await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Classes')
          .doc(classId)
          .update({'subjects': subjects});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تعيين ${selectedTeacher['name']} لمادة ${subject['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the view
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'ربط المواد بالمعلمين',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: _schoolId == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Schools/$_schoolId/Classes')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final classDoc = snapshot.data!.docs[index];
                          final classData = classDoc.data() as Map<String, dynamic>;
                          return _buildClassCard(
                            classDoc.id,
                            classData['name'] ?? 'فصل',
                            classData['subjects'] ?? [],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.link, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'ربط المواد بالمعلمين',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'قم بتعيين معلم لكل مادة في كل فصل',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'لا توجد فصول',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'يرجى إضافة فصول أولاً',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    String classId,
    String className,
    List<dynamic> subjects,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.class_, color: Colors.indigo),
        ),
        title: Text(
          className,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${subjects.length} مادة',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          if (subjects.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'لا توجد مواد في هذا الفصل',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index] as Map<String, dynamic>;
                return _buildSubjectTile(classId, className, subject, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(
    String classId,
    String className,
    Map<String, dynamic> subject,
    int index,
  ) {
    final hasTeacher = subject['teacherId'] != null;
    final teacherName = subject['teacherName'] ?? 'غير محدد';
    final weeklyHours = subject['weeklyHours'] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: hasTeacher ? Colors.green.shade100 : Colors.orange.shade100,
        child: Icon(
          hasTeacher ? Icons.check : Icons.warning,
          color: hasTeacher ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        subject['name'] ?? 'مادة',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                teacherName,
                style: TextStyle(
                  color: hasTeacher ? Colors.grey[700] : Colors.orange,
                ),
              ),
            ],
          ),
          if (hasTeacher) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '$weeklyHours حصص أسبوعياً',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: ElevatedButton.icon(
        onPressed: _isLoading
            ? null
            : () => _assignSubject(classId, className, subject, index),
        icon: Icon(Icons.edit, size: 16),
        label: Text(hasTeacher ? 'تعديل' : 'تعيين'),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasTeacher ? Colors.blue : Colors.orange,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
