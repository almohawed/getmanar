import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleScheduleScreen extends ConsumerStatefulWidget {
  final String schoolId;
  
  const SimpleScheduleScreen({super.key, required this.schoolId});

  @override
  ConsumerState<SimpleScheduleScreen> createState() => _SimpleScheduleScreenState();
}

class _SimpleScheduleScreenState extends ConsumerState<SimpleScheduleScreen> {
  bool _isGenerating = false;
  String? _scheduleId;

  final _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final _colors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFF06B6D4), // Cyan
  ];

  Future<void> _generateSchedule() async {
    setState(() => _isGenerating = true);
    
    try {
      // جلب البيانات
      final classesSnap = await FirebaseFirestore.instance
          .collection('Schools/${widget.schoolId}/Classes')
          .get();
      
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools/${widget.schoolId}/Teachers')
          .get();
      
      if (classesSnap.docs.isEmpty || teachersSnap.docs.isEmpty) {
        throw 'لا توجد فصول أو معلمين';
      }

      // إنشاء جدول بسيط
      final schedule = <String, dynamic>{};
      final lessons = <Map<String, dynamic>>[];
      
      for (final classDoc in classesSnap.docs) {
        final className = classDoc.data()['name'] ?? classDoc.id;
        
        for (int dayIndex = 0; dayIndex < _days.length; dayIndex++) {
          final day = _days[dayIndex];
          
          for (int period = 1; period <= 7; period++) {
            // اختيار معلم عشوائي
            final teacher = teachersSnap.docs[
              (dayIndex * 7 + period) % teachersSnap.docs.length
            ];
            
            final teacherData = teacher.data();
            final teacherName = teacherData['name'] ?? 'معلم';
            final subject = teacherData['primarySubject'] ?? 
                           (teacherData['specialization'] ?? 'مادة');
            
            lessons.add({
              'classId': classDoc.id,
              'className': className,
              'day': day,
              'period': period,
              'teacherId': teacher.id,
              'teacherName': teacherName,
              'subject': subject,
              'color': _colors[period % _colors.length].value,
            });
          }
        }
      }

      // حفظ الجدول
      final scheduleRef = await FirebaseFirestore.instance
          .collection('Schools/${widget.schoolId}/Schedules')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'lessons': lessons,
        'version': 'simple_v1',
      });

      setState(() {
        _scheduleId = scheduleRef.id;
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء الجدول بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _approveSchedule() async {
    if (_scheduleId == null) return;

    try {
      // تحديث حالة الجدول
      await FirebaseFirestore.instance
          .doc('Schools/${widget.schoolId}/Schedules/$_scheduleId')
          .update({'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()});

      // جلب الجدول
      final scheduleDoc = await FirebaseFirestore.instance
          .doc('Schools/${widget.schoolId}/Schedules/$_scheduleId')
          .get();
      
      final lessons = List<Map<String, dynamic>>.from(
        scheduleDoc.data()?['lessons'] ?? []
      );

      // توزيع على الطلاب
      final studentsSnap = await FirebaseFirestore.instance
          .collection('Schools/${widget.schoolId}/Students')
          .get();

      for (final student in studentsSnap.docs) {
        final classId = student.data()['classId'];
        final studentLessons = lessons.where((l) => l['classId'] == classId).toList();
        
        await FirebaseFirestore.instance
            .doc('Schools/${widget.schoolId}/Students/${student.id}')
            .update({'schedule': studentLessons});
      }

      // توزيع على المعلمين
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools/${widget.schoolId}/Teachers')
          .get();

      for (final teacher in teachersSnap.docs) {
        final teacherLessons = lessons.where((l) => l['teacherId'] == teacher.id).toList();
        
        await FirebaseFirestore.instance
            .doc('Schools/${widget.schoolId}/Teachers/${teacher.id}')
            .update({'schedule': teacherLessons});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم اعتماد الجدول وتوزيعه على الجميع'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('الجدول الدراسي', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF6366F1),
        elevation: 0,
      ),
      body: _scheduleId == null ? _buildEmptyState() : _buildScheduleView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Color(0xFF6366F1).withOpacity(0.5)),
          SizedBox(height: 24),
          Text(
            'لا يوجد جدول حالياً',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          SizedBox(height: 12),
          Text(
            'قم بإنشاء جدول جديد للمدرسة',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateSchedule,
            icon: _isGenerating 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.auto_awesome),
            label: Text(_isGenerating ? 'جاري الإنشاء...' : 'إنشاء جدول تلقائي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .doc('Schools/${widget.schoolId}/Schedules/$_scheduleId')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return Center(child: Text('لا توجد بيانات'));

        final lessons = List<Map<String, dynamic>>.from(data['lessons'] ?? []);
        final status = data['status'] ?? 'draft';

        return Column(
          children: [
            _buildHeader(status),
            Expanded(child: _buildScheduleGrid(lessons)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(String status) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: status == 'approved' ? Color(0xFF10B981) : Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status == 'approved' ? 'معتمد' : 'مسودة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Spacer(),
          if (status != 'approved')
            ElevatedButton.icon(
              onPressed: _approveSchedule,
              icon: Icon(Icons.check_circle),
              label: Text('اعتماد الجدول'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _scheduleId = null);
            },
            icon: Icon(Icons.refresh),
            label: Text('جدول جديد'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(List<Map<String, dynamic>> lessons) {
    // تجميع الدروس حسب الفصل
    final classesList = <String>{};
    for (final lesson in lessons) {
      classesList.add(lesson['classId']);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: classesList.length,
      itemBuilder: (context, index) {
        final classId = classesList.elementAt(index);
        final classLessons = lessons.where((l) => l['classId'] == classId).toList();
        final className = classLessons.first['className'];

        return _buildClassSchedule(className, classLessons);
      },
    );
  }

  Widget _buildClassSchedule(String className, List<Map<String, dynamic>> lessons) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              className,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Color(0xFFF1F5F9)),
                columns: [
                  DataColumn(label: Text('الحصة', style: TextStyle(fontWeight: FontWeight.bold))),
                  ..._days.map((day) => DataColumn(label: Text(day, style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
                rows: List.generate(7, (period) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${period + 1}', style: TextStyle(fontWeight: FontWeight.bold))),
                      ..._days.map((day) {
                        final lesson = lessons.firstWhere(
                          (l) => l['day'] == day && l['period'] == period + 1,
                          orElse: () => {},
                        );
                        
                        if (lesson.isEmpty) {
                          return DataCell(Text('-'));
                        }

                        return DataCell(
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(lesson['color']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(lesson['color']), width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lesson['subject'],
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  lesson['teacherName'],
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
