import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/schedule_api_v2.dart';
import '../domain/schedule_models_v2.dart';

class ORToolsV2Screen extends ConsumerStatefulWidget {
  const ORToolsV2Screen({super.key});

  @override
  ConsumerState<ORToolsV2Screen> createState() => _ORToolsV2ScreenState();
}

class _ORToolsV2ScreenState extends ConsumerState<ORToolsV2Screen> {
  bool _isGenerating = false;
  bool _isPrechecking = false;
  String? _schoolId;
  String? _scheduleId;
  PrecheckReportV2? _precheckReport;
  final _api = ScheduleApiV2();

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
        .where('version', isEqualTo: 'ortools_v2_production')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() => _scheduleId = snap.docs.first.id);
    }
  }

  Future<void> _runPrecheck() async {
    if (_schoolId == null) return;

    setState(() => _isPrechecking = true);

    try {
      final request = await _buildRequest();
      final report = await _api.precheck(request);

      setState(() {
        _precheckReport = report;
        _isPrechecking = false;
      });

      if (mounted) {
        _showPrecheckDialog(report);
      }
    } catch (e) {
      setState(() => _isPrechecking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في Precheck: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateSchedule() async {
    if (_schoolId == null) return;

    setState(() => _isGenerating = true);

    try {
      final request = await _buildRequest();
      final response = await _api.generateSchedule(request);

      setState(() {
        _isGenerating = false;
        if (response.success) {
          _scheduleId = response.scheduleId;
        }
      });

      if (mounted) {
        if (response.success) {
          final stats = response.solverStats;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${response.message}\n'
                'الحصص: ${stats['lessonsPlaced']}/${stats['totalLessons']}\n'
                'الوقت: ${stats['executionTime'].toStringAsFixed(2)} ثانية',
              ),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${response.message}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
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

  Future<ScheduleRequestV2> _buildRequest() async {
    final classesSnap = await FirebaseFirestore.instance
        .collection('Schools/$_schoolId/Classes')
        .get();

    final teachersSnap = await FirebaseFirestore.instance
        .collection('Schools/$_schoolId/Teachers')
        .where('isAdministrative', isEqualTo: false)
        .get();

    final teachers = teachersSnap.docs.map((doc) {
      final data = doc.data();
      return TeacherV2(
        id: doc.id,
        name: data['name'] ?? 'معلم',
        subjects: _normalizeSubjects(data),
        assignedClassIds: List<String>.from(data['assignedClassIds'] ?? []),
        maxWeeklyLoad: data['maxWeeklyLoad'] ?? 24,
      );
    }).toList();

    final classes = classesSnap.docs.map((doc) {
      final data = doc.data();
      return ClassV2(
        id: doc.id,
        name: data['name'] ?? doc.id,
        gradeLevel: data['gradeLevel'] ?? 1,
        schoolType: 'primary',
      );
    }).toList();

    final subjectPlan = {
      'اللغة العربية': 6,
      'الرياضيات': 5,
      'العلوم': 5,
      'اللغة الإنجليزية': 4,
      'التربية الإسلامية': 4,
      'الاجتماعيات': 3,
      'التربية البدنية': 3,
      'الحاسب الآلي': 3,
      'التربية الفنية': 2,
    };

    final subjects = subjectPlan.entries.map((e) => SubjectV2(
      id: e.key,
      name: e.key,
      normalizedName: e.key,
      weeklyHours: e.value,
      maxPerDay: (e.key == 'اللغة العربية' || e.key == 'التربية الإسلامية') ? 2 : 1,
      isHeavy: ['اللغة العربية', 'الرياضيات', 'العلوم'].contains(e.key),
    )).toList();

    final assignments = <AssignmentV2>[];
    for (final classInfo in classes) {
      for (final subject in subjects) {
        final qualifiedTeacher = teachers.firstWhere(
          (t) => t.subjects.contains(subject.normalizedName),
          orElse: () => teachers.first,
        );

        assignments.add(AssignmentV2(
          teacherId: qualifiedTeacher.id,
          classId: classInfo.id,
          subjectId: subject.id,
          weeklyHours: subject.weeklyHours,
        ));
      }
    }

    return ScheduleRequestV2(
      schoolId: _schoolId!,
      schoolType: 'primary',
      teachers: teachers,
      classes: classes,
      subjects: subjects,
      assignments: assignments,
    );
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
    if (s.contains('إسلام') || s.contains('اسلام') || s.contains('دين') || s.contains('قرآن'))
      return 'التربية الإسلامية';
    if (s.contains('اجتماع') || s.contains('تاريخ') || s.contains('جغراف'))
      return 'الاجتماعيات';
    if (s.contains('بدن') || s.contains('رياضة')) return 'التربية البدنية';
    if (s.contains('حاسب') || s.contains('كمبيوتر') || s.contains('computer'))
      return 'الحاسب الآلي';
    if (s.contains('فن') || s.contains('رسم') || s.contains('art'))
      return 'التربية الفنية';

    return '';
  }

  void _showPrecheckDialog(PrecheckReportV2 report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              report.canGenerate ? Icons.check_circle : Icons.error,
              color: report.canGenerate ? Colors.green : Colors.red,
            ),
            SizedBox(width: 12),
            Text(report.canGenerate ? 'يمكن التوليد' : 'لا يمكن التوليد'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الطلب الكلي: ${report.totalDemand}'),
              Text('الطاقة الكلية: ${report.totalCapacity}'),
              SizedBox(height: 16),
              Text('المشاكل (${report.issues.length}):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...report.issues.map((issue) => Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      issue.severity == 'critical' ? Icons.error :
                      issue.severity == 'warning' ? Icons.warning : Icons.info,
                      size: 16,
                      color: issue.severity == 'critical' ? Colors.red :
                             issue.severity == 'warning' ? Colors.orange : Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(child: Text(issue.message)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
          if (report.canGenerate)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateSchedule();
              },
              child: Text('توليد الجدول'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_schoolId == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('الجدول الذكي v2 - Production',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 80, color: Colors.white),
          ),
          SizedBox(height: 40),
          Text('نظام الجدولة الإنتاجي',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Precheck + Hard/Soft Constraints + Repair Mode',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isPrechecking ? null : _runPrecheck,
                icon: _isPrechecking
                    ? SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.fact_check, size: 28),
                label: Text(_isPrechecking ? 'جاري الفحص...' : 'فحص الجاهزية',
                    style: TextStyle(fontSize: 20)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSchedule,
                icon: _isGenerating
                    ? SizedBox(width: 28, height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : Icon(Icons.rocket_launch, size: 32),
                label: Text(_isGenerating ? 'جاري التوليد...' : 'توليد الجدول',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 60, vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          if (_precheckReport != null) ...[
            SizedBox(height: 40),
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 100),
              decoration: BoxDecoration(
                color: _precheckReport!.canGenerate ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _precheckReport!.canGenerate ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _precheckReport!.canGenerate ? '✅ يمكن التوليد' : '❌ لا يمكن التوليد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('المشاكل: ${_precheckReport!.issues.length}'),
                ],
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

        final stats = data['stats'] as Map<String, dynamic>?;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: Colors.green),
              SizedBox(height: 20),
              Text('تم توليد الجدول بنجاح!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              if (stats != null) ...[
                SizedBox(height: 20),
                Text('الحصص: ${stats['lessonsPlaced']}/${stats['totalLessons']}',
                    style: TextStyle(fontSize: 20)),
                Text('الوقت: ${stats['executionTime']?.toStringAsFixed(2)} ثانية',
                    style: TextStyle(fontSize: 20)),
                Text('الحالة: ${stats['status']}',
                    style: TextStyle(fontSize: 20)),
              ],
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => setState(() => _scheduleId = null),
                child: Text('جدول جديد'),
              ),
            ],
          ),
        );
      },
    );
  }
}
