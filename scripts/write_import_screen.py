import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')

dart = """\
/// schedule_import_screen.dart
/// شاشة استيراد جدول المعلمين — تصميم Obsidian Premium
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';
import '../../auth/presentation/auth_controller.dart';
import '../services/subject_matcher.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _P {
  static const bg       = Color(0xFF080810);
  static const surface  = Color(0xFF10101C);
  static const card     = Color(0xFF18182A);
  static const violet   = Color(0xFF7C3AED);
  static const violetLt = Color(0xFFA78BFA);
  static const amber    = Color(0xFFF59E0B);
  static const emerald  = Color(0xFF10B981);
  static const sky      = Color(0xFF38BDF8);
  static const rose     = Color(0xFFF43F5E);
  static const border   = Color(0xFF252538);
  static const text     = Color(0xFFF1F5F9);
  static const muted    = Color(0xFF64748B);
}

enum _ImportStep { upload, analyze, review, done }

class ImportedLesson {
  final String teacherName;
  final String rawSubject;
  SubjectMatchResult matchResult;
  final String className;
  final String dayName;
  final int dayIndex;
  final int period;
  ImportedLesson({required this.teacherName, required this.rawSubject,
    required this.matchResult, required this.className, required this.dayName,
    required this.dayIndex, required this.period});
  String get resolvedSubject => matchResult.matched?.officialName ?? rawSubject;
}

class ScheduleImportScreen extends ConsumerStatefulWidget {
  const ScheduleImportScreen({super.key});
  @override
  ConsumerState<ScheduleImportScreen> createState() => _ScheduleImportScreenState();
}

class _ScheduleImportScreenState extends ConsumerState<ScheduleImportScreen>
    with TickerProviderStateMixin {
  _ImportStep _step = _ImportStep.upload;
  bool _isLoading = false;
  String _fileName = '';
  excel.Excel? _workbook;
  List<ImportedLesson> _allLessons = [];
  List<ImportedLesson> _reviewLessons = [];
  Map<String, int> _subjectStats = {};
  int _knownCount = 0;
  int _unknownCount = 0;
  String? _schoolId;
  String _importResult = '';
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        setState(() => _schoolId = user.schoolId);
        SubjectMatcher.loadFromFirestore(user.schoolId ?? '');
      }
    });
  }

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result == null) { setState(() => _isLoading = false); return; }
      final pf = result.files.first;
      final bytes = kIsWeb ? pf.bytes! : (pf.bytes ?? await XFile(pf.path!).readAsBytes());
      _workbook = excel.Excel.decodeBytes(bytes);
      _fileName = pf.name;
      setState(() { _isLoading = false; _step = _ImportStep.analyze; });
      await _analyzeFile();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('فشل قراءة الملف: $e', _P.rose);
    }
  }

  Future<void> _analyzeFile() async {
    if (_workbook == null) return;
    setState(() => _isLoading = true);
    try {
      final sheetName = _workbook!.tables.keys.first;
      final sheet = _workbook!.tables[sheetName]!;
      if (sheet.rows.length < 3) {
        _showSnack('الملف لا يحتوي على بيانات كافية', _P.amber);
        setState(() => _isLoading = false); return;
      }
      final dayRow = sheet.rows[1];
      final periodRow = sheet.rows[2];
      final colInfo = <int, Map<String, dynamic>>{};
      String currentDay = '';
      for (var c = 1; c < dayRow.length; c++) {
        final dv = dayRow[c]?.value?.toString().trim() ?? '';
        if (_days.contains(dv)) currentDay = dv;
        final pv = periodRow.length > c ? periodRow[c]?.value?.toString().trim() : null;
        final period = int.tryParse(pv ?? '');
        if (currentDay.isNotEmpty && period != null) colInfo[c] = {'day': currentDay, 'period': period};
      }
      final lessons = <ImportedLesson>[];
      final rawSubjects = <String>{};
      for (var r = 3; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;
        final teacherName = row[0]?.value?.toString().trim() ?? '';
        if (teacherName.isEmpty) continue;
        for (var c = 1; c < row.length; c++) {
          final info = colInfo[c]; if (info == null) continue;
          final content = row[c]?.value?.toString().trim() ?? '';
          if (content.isEmpty) continue;
          String subject = content; String className = '';
          if (content.contains('\\n')) {
            final pts = content.split('\\n'); className = pts[0].trim();
            subject = pts.length > 1 ? pts[1].trim() : pts[0].trim();
          } else if (content.contains('-')) {
            final pts = content.split('-'); className = pts[0].trim();
            subject = pts.length > 1 ? pts[1].trim() : pts[0].trim();
          }
          rawSubjects.add(subject);
          final dayName = info['day'] as String;
          final dayIndex = _days.indexOf(dayName);
          lessons.add(ImportedLesson(teacherName: teacherName, rawSubject: subject,
            matchResult: SubjectMatcher.match(subject), className: className,
            dayName: dayName, dayIndex: dayIndex >= 0 ? dayIndex : 0, period: info['period'] as int));
        }
      }
      _knownCount = rawSubjects.where((s) => !SubjectMatcher.match(s).needsReview).length;
      _unknownCount = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).length;
      _subjectStats = {};
      for (final s in rawSubjects) { _subjectStats[s] = (_subjectStats[s] ?? 0) + 1; }
      final reviewSubjects = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).toSet();
      _reviewLessons = reviewSubjects.map((s) => lessons.firstWhere((l) => l.rawSubject == s)).toList();
      _allLessons = lessons;
      setState(() { _isLoading = false; _step = _reviewLessons.isEmpty ? _ImportStep.done : _ImportStep.review; });
      if (_reviewLessons.isEmpty) await _executeImport();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('خطأ في التحليل: $e', _P.rose);
    }
  }

  Future<void> _executeImport() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      final classesSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Classes').get();
      final classNameToId = <String, String>{};
      for (final cls in classesSnap.docs) {
        final name = (cls.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) { classNameToId[name] = cls.id; classNameToId[name.replaceAll(' ', '')] = cls.id; }
      }
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Teachers').get();
      final teacherNameToId = <String, String>{};
      for (final t in teachersSnap.docs) {
        final name = (t.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) teacherNameToId[name] = t.id;
      }
      final teacherLessons = <String, List<Map<String, dynamic>>>{};
      final classLessons = <String, List<Map<String, dynamic>>>{};
      for (final lesson in _allLessons) {
        final classId = classNameToId[lesson.className] ?? classNameToId[lesson.className.replaceAll(' ', '')];
        final lessonMap = {'period': lesson.period, 'dayIndex': lesson.dayIndex, 'dayName': lesson.dayName,
          'day': lesson.dayName, 'subject': lesson.resolvedSubject, 'rawSubject': lesson.rawSubject,
          'className': lesson.className, 'teacherName': lesson.teacherName,
          if (classId != null) 'classId': classId};
        teacherLessons.putIfAbsent(lesson.teacherName, () => []).add(lessonMap);
        if (classId != null) classLessons.putIfAbsent(classId, () => []).add(lessonMap);
      }
      await FirebaseFirestore.instance.collection('Schools').doc(_schoolId)
          .collection('GeneralSchedule').add({'teacherSchedules': teacherLessons,
          'source': 'schedule_import_screen', 'status': 'approved', 'createdAt': FieldValue.serverTimestamp()});
      int teacherCount = 0;
      for (final entry in teacherLessons.entries) {
        String? tid = teacherNameToId[entry.key];
        if (tid == null) {
          for (final e in teacherNameToId.entries) {
            if (entry.key.contains(e.key) || e.key.contains(entry.key)) { tid = e.value; break; }
          }
        }
        if (tid == null) continue;
        await FirebaseFirestore.instance.collection('Schools').doc(_schoolId)
            .collection('Teachers').doc(tid)
            .update({'schedule': entry.value, 'scheduleUpdatedAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('Schools').doc(_schoolId)
            .collection('TeacherSchedules').doc(tid)
            .set({'slots': entry.value, 'updatedAt': FieldValue.serverTimestamp(), 'source': 'schedule_import_screen'});
        teacherCount++;
      }
      for (final entry in classLessons.entries) {
        await FirebaseFirestore.instance.collection('Schools').doc(_schoolId)
            .collection('Classes').doc(entry.key).collection('ClassSchedules')
            .add({'lessons': entry.value, 'source': 'schedule_import_screen',
                  'status': 'approved', 'createdAt': FieldValue.serverTimestamp()});
      }
      setState(() {
        _isLoading = false;
        _step = _ImportStep.done;
        _importResult = 'تم استيراد جدول ${teacherLessons.length} معلم بنجاح\\n'
            'تم ربط $teacherCount معلم بجدوله\\n'
            'تم توزيع الجدول على ${classLessons.length} فصل';
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('فشل الاستيراد: $e', _P.rose);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _reset() => setState(() {
    _step = _ImportStep.upload; _fileName = ''; _workbook = null;
    _allLessons = []; _reviewLessons = []; _subjectStats = {};
    _knownCount = 0; _unknownCount = 0; _importResult = '';
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Column(children: [
        _buildTopBar(),
        _buildStepRail(),
        Expanded(child: _isLoading ? _buildLoading() : _buildBody()),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      decoration: BoxDecoration(
        color: _P.surface,
        border: Border(bottom: BorderSide(color: _P.border)),
        boxShadow: [BoxShadow(color: _P.violet.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _P.card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _P.border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _P.muted, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_P.violet, _P.sky],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _P.violet.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('استيراد جدول المعلمين',
              style: TextStyle(color: _P.text, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('الجداول الدراسية', style: TextStyle(color: _P.muted, fontSize: 11)),
        ])),
        if (_step != _ImportStep.upload)
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('بدء من جديد', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: _P.muted),
          ),
      ]),
    );
  }

  Widget _buildStepRail() {
    final steps = [
      (Icons.upload_file_rounded, 'رفع الملف'),
      (Icons.analytics_rounded, 'مراجعة المطابقة'),
      (Icons.check_circle_rounded, 'اكتمل الاستيراد'),
    ];
    final idx = _step == _ImportStep.upload ? 0 : _step == _ImportStep.analyze || _step == _ImportStep.review ? 1 : 2;
    return Container(
      color: _P.surface,
      child: Row(children: List.generate(steps.length, (i) {
        final done = i < idx;
        final active = i == idx;
        final color = done ? _P.emerald : active ? _P.violet : _P.border;
        return Expanded(child: InkWell(
          onTap: null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: active ? _P.violet : done ? _P.emerald : Colors.transparent, width: 2),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? _P.emerald.withOpacity(0.15) : active ? _P.violet.withOpacity(0.15) : Colors.transparent,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Center(child: done
                    ? const Icon(Icons.check_rounded, color: _P.emerald, size: 13)
                    : Icon(steps[i].$1, color: active ? _P.violetLt : _P.muted, size: 13)),
              ),
              const SizedBox(width: 8),
              Text(steps[i].$2, style: TextStyle(
                  color: active ? _P.violetLt : done ? _P.emerald : _P.muted,
                  fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            ]),
          ),
        ));
      })),
    );
  }

  Widget _buildLoading() {
    return Center(child: AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _P.violet.withOpacity(_glowAnim.value), width: 2),
            boxShadow: [BoxShadow(color: _P.violet.withOpacity(_glowAnim.value * 0.3), blurRadius: 30)],
          ),
          child: const Center(child: CircularProgressIndicator(color: _P.violetLt, strokeWidth: 2)),
        ),
        const SizedBox(height: 20),
        const Text('جاري التحليل الذكي...', style: TextStyle(color: _P.text, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('يتم مطابقة المواد مع قاعدة البيانات', style: const TextStyle(color: _P.muted, fontSize: 12)),
      ]),
    ));
  }

  Widget _buildBody() {
    switch (_step) {
      case _ImportStep.upload:  return _buildUpload();
      case _ImportStep.analyze: return _buildAnalyze();
      case _ImportStep.review:  return _buildReview();
      case _ImportStep.done:    return _buildDone();
    }
  }
"""

p.write_text(dart, encoding='utf-8')
print('part1 ok')
