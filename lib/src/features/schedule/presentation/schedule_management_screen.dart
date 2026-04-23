import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import 'dart:math';

class ScheduleManagementScreen extends ConsumerStatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  ConsumerState<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState
    extends ConsumerState<ScheduleManagementScreen> {
  bool _isGenerating = false;
  String? _scheduleId;
  String? _schoolId;

  final _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final _colors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _loadSchoolId();
  }

  Future<void> _loadSchoolId() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      setState(() => _schoolId = user.schoolId);
      _checkExistingSchedule();
    }
  }

  Future<void> _checkExistingSchedule() async {
    if (_schoolId == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('Schools/$_schoolId/Schedules')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() => _scheduleId = snap.docs.first.id);
    }
  }

  String _normalizeSubject(String subject) {
    final s = subject.trim().toLowerCase();

    if (s.contains('عرب')) return 'اللغة العربية';
    if (s.contains('رياض')) return 'الرياضيات';
    if (s.contains('علوم')) return 'العلوم';
    if (s.contains('إنجليز') || s.contains('انجليز') || s.contains('english'))
      return 'اللغة الإنجليزية';
    if (s.contains('إسلام') ||
        s.contains('اسلام') ||
        s.contains('دين') ||
        s.contains('قرآن'))
      return 'التربية الإسلامية';
    if (s.contains('اجتماع') || s.contains('تاريخ') || s.contains('جغراف'))
      return 'الاجتماعيات';
    if (s.contains('بدن') || s.contains('رياضة')) return 'التربية البدنية';
    if (s.contains('حاسب') || s.contains('كمبيوتر') || s.contains('computer'))
      return 'الحاسب الآلي';
    if (s.contains('فن') || s.contains('رسم') || s.contains('art'))
      return 'التربية الفنية';
    if (s.contains('أسر') || s.contains('اسر') || s.contains('منزل'))
      return 'التربية الأسرية';

    return '';
  }

  Future<void> _generateSchedule() async {
    if (_schoolId == null) return;

    setState(() => _isGenerating = true);

    try {
      final classesSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Classes')
          .get();

      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .get();

      if (classesSnap.docs.isEmpty) {
        throw 'لا توجد فصول في المدرسة';
      }

      final activeTeachers = teachersSnap.docs
          .where((doc) => doc.data()['isAdministrative'] != true)
          .toList();

      if (activeTeachers.isEmpty) {
        throw 'لا يوجد معلمين في المدرسة';
      }

      final random = Random();

      final teacherInfo = <String, Map<String, dynamic>>{};
      for (final teacherDoc in activeTeachers) {
        final data = teacherDoc.data();
        final maxLoadRaw = data['maxWeeklyLoad'];
        teacherInfo[teacherDoc.id] = {
          'id': teacherDoc.id,
          'name': (data['name'] ?? 'معلم').toString(),
          'assignedClassIds': List<String>.from(
            data['assignedClassIds'] ?? const [],
          ),
          'maxLoad': maxLoadRaw is num
              ? maxLoadRaw.toInt()
              : (int.tryParse('${maxLoadRaw ?? ''}') ?? 24),
        };
      }

      int? asInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString().trim());
      }

      String? asString(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      // هياكل البيانات للجدول
      final schedule = <String, Map<String, Map<int, Map<String, dynamic>>>>{};
      for (final classDoc in classesSnap.docs) {
        schedule[classDoc.id] = {
          for (final day in _days) day: <int, Map<String, dynamic>>{},
        };
      }

      final teacherLoad = <String, int>{};
      final classSubjectPlan = <String, Map<String, Map<String, dynamic>>>{};
      final classSubjectsOrder = <String, List<String>>{};

      for (final classDoc in classesSnap.docs) {
        final classId = classDoc.id;
        final classData = classDoc.data();
        final rawSubjects = classData['subjects'];
        if (rawSubjects is! List || rawSubjects.isEmpty) {
          throw 'الفصل ${(classData['name'] ?? classId).toString()} لا يحتوي مواد مرتبطة. اربط المواد بالمعلمين لكل فصل أولاً.';
        }

        final plan = <String, Map<String, dynamic>>{};
        final order = <String>[];
        var sumHours = 0;

        for (final item in rawSubjects) {
          if (item is! Map) continue;
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          final subjectName =
              asString(m['name']) ??
              asString(m['id']) ??
              asString(m['subjectId']);
          if (subjectName == null) continue;
          final weekly = asInt(m['weeklyHours']) ?? 0;
          if (weekly <= 0) continue;
          final teacherId = asString(m['teacherId']);
          if (teacherId == null) {
            throw 'مادة $subjectName في الفصل ${(classData['name'] ?? classId).toString()} بدون معلم مسند.';
          }
          final info = teacherInfo[teacherId];
          if (info == null) {
            throw 'المعلم $teacherId غير موجود ضمن قائمة معلمي المدرسة.';
          }
          final teacherName =
              asString(m['teacherName']) ?? info['name'] as String;
          plan[subjectName] = {
            'teacherId': teacherId,
            'teacherName': teacherName,
            'remaining': weekly,
          };
          order.add(subjectName);
          sumHours += weekly;
        }

        final requiredPerClass = _days.length * 7;
        if (sumHours != requiredPerClass) {
          throw 'إجمالي الحصص الأسبوعية للفصل ${(classData['name'] ?? classId).toString()} = $sumHours ولا يساوي إجمالي حصص الأسبوع $requiredPerClass. راجع weeklyHours لكل مادة.';
        }

        order.shuffle(random);
        classSubjectPlan[classId] = plan;
        classSubjectsOrder[classId] = order;
      }

      int placedCount = 0;
      int phase1Count = 0;
      int phase2Count = 0;
      const int phase3Count = 0;

      final subjectColorCache = <String, int>{};
      int colorIndex = 0;

      int colorForSubject(String subject) {
        return subjectColorCache.putIfAbsent(subject, () {
          final v = _colors[colorIndex % _colors.length].value;
          colorIndex += 1;
          return v;
        });
      }

      for (final day in _days) {
        for (int period = 1; period <= 7; period++) {
          final usedTeachers = <String>{};

          for (final classDoc in classesSnap.docs) {
            final classId = classDoc.id;
            final className = (classDoc.data()['name'] ?? classDoc.id)
                .toString();
            if (schedule[classId]![day]!.containsKey(period)) continue;

            final plan = classSubjectPlan[classId];
            if (plan == null || plan.isEmpty) continue;

            final subjectCountToday = <String, int>{};
            for (final lesson in schedule[classId]![day]!.values) {
              final s = (lesson['subject'] ?? '').toString();
              if (s.isEmpty) continue;
              subjectCountToday[s] = (subjectCountToday[s] ?? 0) + 1;
            }

            final subjects = List<String>.from(
              classSubjectsOrder[classId] ?? plan.keys,
            );
            subjects.shuffle(random);
            subjects.sort((a, b) {
              final ra = (plan[a]?['remaining'] as int?) ?? 0;
              final rb = (plan[b]?['remaining'] as int?) ?? 0;
              if (ra != rb) return rb.compareTo(ra);
              return a.compareTo(b);
            });

            String? chosenSubject;
            String? chosenTeacher;
            String? chosenTeacherName;

            bool tryPick({required bool allowRepeat}) {
              for (final subject in subjects) {
                final entry = plan[subject];
                if (entry == null) continue;
                final remaining = (entry['remaining'] as int?) ?? 0;
                if (remaining <= 0) continue;
                if (!allowRepeat && (subjectCountToday[subject] ?? 0) >= 1)
                  continue;

                final teacherId = (entry['teacherId'] ?? '').toString().trim();
                if (teacherId.isEmpty) continue;
                if (usedTeachers.contains(teacherId)) continue;

                final info = teacherInfo[teacherId];
                if (info == null) continue;
                final maxLoad = info['maxLoad'] as int? ?? 24;
                if ((teacherLoad[teacherId] ?? 0) >= maxLoad) continue;

                final assignedClasses = List<String>.from(
                  info['assignedClassIds'] ?? const [],
                );
                if (assignedClasses.isNotEmpty &&
                    !assignedClasses.contains(classId))
                  continue;

                chosenSubject = subject;
                chosenTeacher = teacherId;
                chosenTeacherName = (entry['teacherName'] ?? info['name'])
                    .toString();
                return true;
              }
              return false;
            }

            final picked = tryPick(allowRepeat: false);
            if (picked) {
              phase1Count += 1;
            } else {
              final picked2 = tryPick(allowRepeat: true);
              if (!picked2) continue;
              phase2Count += 1;
            }

            schedule[classId]![day]![period] = {
              'classId': classId,
              'className': className,
              'day': day,
              'period': period,
              'teacherId': chosenTeacher,
              'teacherName': chosenTeacherName,
              'subject': chosenSubject,
              'color': colorForSubject(chosenSubject!),
            };

            final p = classSubjectPlan[classId]![chosenSubject]!;
            p['remaining'] = ((p['remaining'] as int?) ?? 1) - 1;

            teacherLoad[chosenTeacher!] =
                (teacherLoad[chosenTeacher!] ?? 0) + 1;
            usedTeachers.add(chosenTeacher!);
            placedCount++;
          }
        }
      }

      final requiredPerClass = _days.length * 7;
      final expected = classesSnap.docs.length * requiredPerClass;
      if (placedCount != expected) {
        final missing = <String>[];
        for (final classDoc in classesSnap.docs) {
          final classId = classDoc.id;
          for (final day in _days) {
            for (int period = 1; period <= 7; period++) {
              if (!schedule[classId]![day]!.containsKey(period)) {
                missing.add('$classId:$day:$period');
                if (missing.length >= 12) break;
              }
            }
            if (missing.length >= 12) break;
          }
          if (missing.length >= 12) break;
        }
        throw 'تعذر إكمال الجدول. تأكد من: (1) مجموع weeklyHours = 35 لكل فصل (2) كل مادة لها معلم (3) نصاب المعلمين كافٍ. أمثلة فراغات: ${missing.join(', ')}';
      }

      // تحويل الجدول إلى قائمة
      final lessons = <Map<String, dynamic>>[];
      for (final classId in schedule.keys) {
        for (final day in _days) {
          for (final lesson in schedule[classId]![day]!.values) {
            lessons.add(lesson);
          }
        }
      }

      final totalRequired =
          classesSnap.docs.length * 35; // 12 classes × 35 lessons

      final scheduleRef = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Schedules')
          .add({
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'draft',
            'lessons': lessons,
            'version': 'class_subject_teacher_v1.0',
            'totalLessons': lessons.length,
            'requiredLessons': totalRequired,
            'phase1Lessons': phase1Count,
            'phase2Lessons': phase2Count,
            'phase3Lessons': phase3Count,
            'completionRate': ((lessons.length / totalRequired) * 100)
                .toStringAsFixed(1),
          });

      setState(() {
        _scheduleId = scheduleRef.id;
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ تم إنشاء الجدول\n'
              'المرحلة 1: $phase1Count حصة\n'
              'المرحلة 2: $phase2Count حصة\n'
              'المرحلة 3: $phase3Count حصة\n'
              'الإجمالي: ${lessons.length}/$totalRequired (${((lessons.length / totalRequired) * 100).toStringAsFixed(1)}%)',
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveSchedule() async {
    if (_scheduleId == null || _schoolId == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('Schools/$_schoolId/Schedules/$_scheduleId')
          .update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });

      final scheduleDoc = await FirebaseFirestore.instance
          .doc('Schools/$_schoolId/Schedules/$_scheduleId')
          .get();

      final lessons = List<Map<String, dynamic>>.from(
        scheduleDoc.data()?['lessons'] ?? [],
      );

      final batch = FirebaseFirestore.instance.batch();

      // توزيع على الطلاب
      final studentsSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Students')
          .get();

      for (final student in studentsSnap.docs) {
        final classId = student.data()['classId'];
        final studentLessons = lessons
            .where((l) => l['classId'] == classId)
            .toList();
        batch.update(student.reference, {'schedule': studentLessons});
      }

      // توزيع على المعلمين
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .get();

      for (final teacher in teachersSnap.docs) {
        final teacherLessons = lessons
            .where((l) => l['teacherId'] == teacher.id)
            .toList();
        batch.update(teacher.reference, {'schedule': teacherLessons});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم اعتماد الجدول وتوزيعه على الجميع'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_schoolId == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'الجدول الدراسي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today,
              size: 80,
              color: Color(0xFF6366F1),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'لا يوجد جدول حالياً',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'قم بإنشاء جدول جديد للمدرسة',
            style: TextStyle(fontSize: 18, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateSchedule,
            icon: _isGenerating
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.auto_awesome, size: 28),
            label: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _isGenerating ? 'جاري الإنشاء...' : 'إنشاء جدول تلقائي',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .doc('Schools/$_schoolId/Schedules/$_scheduleId')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return Center(child: Text('لا توجد بيانات'));

        final lessons = List<Map<String, dynamic>>.from(data['lessons'] ?? []);
        final status = data['status'] ?? 'draft';
        final totalLessons = data['totalLessons'] ?? lessons.length;

        return Column(
          children: [
            _buildHeader(status, totalLessons),
            Expanded(child: _buildScheduleGrid(lessons)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(String status, int totalLessons) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: status == 'approved'
                  ? Color(0xFF10B981)
                  : Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Icon(
                  status == 'approved' ? Icons.check_circle : Icons.pending,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  status == 'approved' ? 'معتمد' : 'مسودة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              '$totalLessons حصة',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Spacer(),
          if (status != 'approved') ...[
            ElevatedButton.icon(
              onPressed: _approveSchedule,
              icon: Icon(Icons.check_circle),
              label: Text('اعتماد الجدول'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(width: 12),
          ],
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _scheduleId = null);
            },
            icon: Icon(Icons.refresh),
            label: Text('جدول جديد'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(List<Map<String, dynamic>> lessons) {
    final classesList = <String>{};
    for (final lesson in lessons) {
      classesList.add(lesson['classId']);
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: classesList.length,
      itemBuilder: (context, index) {
        final classId = classesList.elementAt(index);
        final classLessons = lessons
            .where((l) => l['classId'] == classId)
            .toList();
        final className = classLessons.first['className'];

        return _buildClassSchedule(className, classLessons);
      },
    );
  }

  Widget _buildClassSchedule(
    String className,
    List<Map<String, dynamic>> lessons,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.class_, color: Color(0xFF6366F1), size: 28),
                ),
                SizedBox(width: 16),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Color(0xFFF1F5F9)),
                headingRowHeight: 56,
                dataRowHeight: 80,
                columnSpacing: 16,
                columns: [
                  DataColumn(
                    label: Text(
                      'الحصة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ..._days.map(
                    (day) => DataColumn(
                      label: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: List.generate(7, (period) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${period + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                      ..._days.map((day) {
                        final lesson = lessons.firstWhere(
                          (l) => l['day'] == day && l['period'] == period + 1,
                          orElse: () => {},
                        );

                        if (lesson.isEmpty) {
                          return DataCell(
                            Container(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '-',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ),
                          );
                        }

                        return DataCell(
                          Container(
                            width: 140,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(lesson['color']).withOpacity(0.15),
                                  Color(lesson['color']).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(lesson['color']).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lesson['subject'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        lesson['teacherName'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
