import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/schedule_api_service.dart';
import '../domain/schedule_models.dart';

class ORToolsScheduleScreen extends ConsumerStatefulWidget {
  const ORToolsScheduleScreen({super.key});

  @override
  ConsumerState<ORToolsScheduleScreen> createState() =>
      _ORToolsScheduleScreenState();
}

class _ORToolsScheduleScreenState
    extends ConsumerState<ORToolsScheduleScreen> {
  bool _isGenerating = false;
  String? _schoolId;
  String? _scheduleId;
  final _apiService = ScheduleApiService();

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
        .where('version', isEqualTo: 'ortools_v1.0')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() => _scheduleId = snap.docs.first.id);
    }
  }

  Future<void> _generateSchedule() async {
    if (_schoolId == null) return;

    setState(() => _isGenerating = true);

    try {
      // 1. جلب البيانات من Firestore
      final classesSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Classes')
          .get();

      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .where('isAdministrative', isEqualTo: false)
          .get();

      if (classesSnap.docs.isEmpty) {
        throw 'لا توجد فصول في المدرسة';
      }

      if (teachersSnap.docs.isEmpty) {
        throw 'لا يوجد معلمين في المدرسة';
      }

      // 2. تحويل البيانات
      final teachers = teachersSnap.docs.map((doc) {
        final data = doc.data();
        return TeacherModel(
          id: doc.id,
          name: data['name'] ?? 'معلم',
          subjects: _normalizeSubjects(data),
          assignedClassIds: List<String>.from(data['assignedClassIds'] ?? []),
          maxWeeklyLoad: data['maxWeeklyLoad'] ?? 24,
        );
      }).toList();

      final classes = classesSnap.docs.map((doc) {
        final data = doc.data();
        return ClassModel(
          id: doc.id,
          name: data['name'] ?? doc.id,
          gradeLevel: data['gradeLevel'] ?? 1,
          track: data['secondaryTrack'],
        );
      }).toList();

      // 3. الخطة الدراسية
      final subjectRequirements = _getSubjectRequirements();

      // 4. إنشاء الطلب
      final request = ScheduleRequest(
        schoolId: _schoolId!,
        schoolType: 'primary',
        teachers: teachers,
        classes: classes,
        subjectRequirements: subjectRequirements,
      );

      // 5. استدعاء API
      final response = await _apiService.generateSchedule(request);

      setState(() {
        _isGenerating = false;
        _scheduleId = response.stats['scheduleId'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${response.message}\n'
              'عدد الحصص: ${response.lessons.length}\n'
              'الوقت: ${response.executionTime.toStringAsFixed(2)} ثانية',
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
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<String> _normalizeSubjects(Map<String, dynamic> data) {
    final subjects = <String>{};

    if (data['assignedSubjects'] != null) {
      subjects.addAll(List<String>.from(data['assignedSubjects']));
    }
    if (data['primarySubject'] != null) {
      subjects.add(data['primarySubject']);
    }
    if (data['specialization'] != null) {
      subjects.add(data['specialization']);
    }

    return subjects.map(_normalizeSubject).where((s) => s.isNotEmpty).toList();
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
        s.contains('قرآن')) return 'التربية الإسلامية';
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

  Map<String, List<SubjectRequirement>> _getSubjectRequirements() {
    // خطة ابتدائي (الصفوف 1-6)
    final primaryPlan = [
      SubjectRequirement(subject: 'اللغة العربية', weeklyHours: 6),
      SubjectRequirement(subject: 'الرياضيات', weeklyHours: 5),
      SubjectRequirement(subject: 'العلوم', weeklyHours: 5),
      SubjectRequirement(subject: 'اللغة الإنجليزية', weeklyHours: 4),
      SubjectRequirement(subject: 'التربية الإسلامية', weeklyHours: 4),
      SubjectRequirement(subject: 'الاجتماعيات', weeklyHours: 3),
      SubjectRequirement(subject: 'التربية البدنية', weeklyHours: 3),
      SubjectRequirement(subject: 'الحاسب الآلي', weeklyHours: 3),
      SubjectRequirement(subject: 'التربية الفنية', weeklyHours: 2),
    ];

    return {
      '1': primaryPlan,
      '2': primaryPlan,
      '3': primaryPlan,
      '4': primaryPlan,
      '5': primaryPlan,
      '6': primaryPlan,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_schoolId == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'الجدول الذكي - OR-Tools',
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
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 80,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 40),
          Text(
            'جدول ذكي بتقنية OR-Tools',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'توليد جدول كامل في أقل من 30 ثانية',
            style: TextStyle(
              fontSize: 20,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'بدون تعارضات • توزيع عادل • احترافي',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 60),
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateSchedule,
            icon: _isGenerating
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.rocket_launch, size: 32),
            label: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _isGenerating ? 'جاري التوليد...' : 'توليد الجدول',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 60, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              shadowColor: Color(0xFF6366F1).withOpacity(0.5),
            ),
          ),
          if (_isGenerating) ...[
            SizedBox(height: 24),
            Text(
              'يتم حل المشكلة باستخدام Google OR-Tools...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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

        final lessons =
            List<Map<String, dynamic>>.from(data['lessons'] ?? []);
        final stats = data['stats'] as Map<String, dynamic>?;

        return Column(
          children: [
            _buildHeader(lessons.length, stats),
            Expanded(child: _buildScheduleGrid(lessons)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int totalLessons, Map<String, dynamic>? stats) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'الجدول معتمد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$totalLessons حصة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (stats != null) ...[
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'الوقت',
                  '${stats['executionTime']?.toStringAsFixed(1) ?? '0'} ث',
                  Icons.timer,
                ),
                _buildStatCard(
                  'الحالة',
                  stats['status'] ?? 'OPTIMAL',
                  Icons.verified,
                ),
                _buildStatCard(
                  'التقنية',
                  'OR-Tools',
                  Icons.psychology,
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _scheduleId = null);
                  },
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    'جدول جديد',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.white, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
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
        final classLessons =
            lessons.where((l) => l['classId'] == classId).toList();
        final className = classLessons.first['className'];

        return _buildClassSchedule(className, classLessons);
      },
    );
  }

  Widget _buildClassSchedule(
      String className, List<Map<String, dynamic>> lessons) {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF06B6D4),
    ];

    return Card(
      margin: EdgeInsets.only(bottom: 24),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.class_, color: Colors.white, size: 32),
                ),
                SizedBox(width: 16),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    MaterialStateProperty.all(Color(0xFFF1F5F9)),
                headingRowHeight: 60,
                dataRowHeight: 90,
                columnSpacing: 20,
                columns: [
                  DataColumn(
                    label: Text(
                      'الحصة',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  ...days.map((day) => DataColumn(
                        label: Text(
                          day,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      )),
                ],
                rows: List.generate(7, (period) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${period + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      ...days.map((day) {
                        final lesson = lessons.firstWhere(
                          (l) => l['day'] == day && l['period'] == period + 1,
                          orElse: () => {},
                        );

                        if (lesson.isEmpty) {
                          return DataCell(
                            Container(
                              padding: EdgeInsets.all(12),
                              child: Text('-',
                                  style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
                          );
                        }

                        final colorIndex =
                            lesson['subject'].hashCode % colors.length;

                        return DataCell(
                          Container(
                            width: 150,
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors[colorIndex].withOpacity(0.2),
                                  colors[colorIndex].withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors[colorIndex].withOpacity(0.5),
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
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.person,
                                        size: 14, color: Color(0xFF64748B)),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        lesson['teacherName'],
                                        style: TextStyle(
                                          fontSize: 12,
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
