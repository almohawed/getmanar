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

  // ─── مطابقة المواد المدمجة مباشرة ────────────────────────────────────────
  static const Map<String, String> _subjectAliases = {
    // عربي
    'عربي': 'اللغة العربية', 'لغتي': 'اللغة العربية', 'لغة عربية': 'اللغة العربية',
    'اللغة العربية': 'اللغة العربية', 'لغتي الخالدة': 'اللغة العربية',
    'الكفايات اللغوية': 'اللغة العربية', 'كفايات لغوية': 'اللغة العربية',
    // رياضيات
    'رياضيات': 'الرياضيات', 'الرياضيات': 'الرياضيات', 'حساب': 'الرياضيات',
    // علوم
    'علوم': 'العلوم', 'العلوم': 'العلوم', 'علوم طبيعية': 'العلوم',
    'احياء': 'العلوم', 'فيزياء': 'العلوم', 'كيمياء': 'العلوم',
    // انجليزي
    'انجليزي': 'اللغة الإنجليزية', 'إنجليزي': 'اللغة الإنجليزية',
    'اللغة الإنجليزية': 'اللغة الإنجليزية', 'لغة انجليزية': 'اللغة الإنجليزية',
    'انجليزية': 'اللغة الإنجليزية', 'إنجليزية': 'اللغة الإنجليزية',
    // اسلامية
    'اسلامية': 'التربية الإسلامية', 'إسلامية': 'التربية الإسلامية',
    'تربية اسلامية': 'التربية الإسلامية', 'تربية إسلامية': 'التربية الإسلامية',
    'دراسات اسلامية': 'التربية الإسلامية', 'الدراسات الإسلامية': 'التربية الإسلامية',
    // قرآن
    'قرآن': 'القرآن الكريم', 'قران': 'القرآن الكريم', 'تحفيظ': 'القرآن الكريم',
    'القرآن الكريم': 'القرآن الكريم', 'تحفيظ قرآن': 'القرآن الكريم',
    // اجتماعيات
    'اجتماعيات': 'الاجتماعيات', 'الاجتماعيات': 'الاجتماعيات',
    'دراسات اجتماعية': 'الاجتماعيات', 'إجتماعيات': 'الاجتماعيات',
    // رقمية
    'حاسب': 'التقنية الرقمية', 'حاسوب': 'التقنية الرقمية',
    'تقنية رقمية': 'التقنية الرقمية', 'الرقمية': 'التقنية الرقمية',
    'رقمية': 'التقنية الرقمية', 'حاسب آلي': 'التقنية الرقمية',
    // بدنية
    'بدنية': 'التربية البدنية', 'تربية بدنية': 'التربية البدنية',
    'رياضة': 'التربية البدنية', 'رياضية': 'التربية البدنية',
    // فنية
    'فنية': 'التربية الفنية', 'تربية فنية': 'التربية الفنية',
    'رسم': 'التربية الفنية', 'فنون': 'التربية الفنية',
    // مهارات الحياة
    'حياتية': 'مهارات الحياة', 'حياتيه': 'مهارات الحياة',
    'مهارات حياتية': 'مهارات الحياة', 'مهارات حياتيه': 'مهارات الحياة',
    'مهارات الحياة': 'مهارات الحياة', 'مهارات': 'مهارات الحياة',
    'مهارات حياه': 'مهارات الحياة', 'تنمية مهارات': 'مهارات الحياة',
    // برايل
    'برايل': 'برايل', 'لغة برايل': 'برايل',
  };

  String _normalizeForMatch(String s) {
    var v = s.trim().toLowerCase();
    v = v.replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي').replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    return v.trim();
  }

  String _matchSubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.length <= 1) return '';
    // تجاهل صيغ Excel
    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||
        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';
    // تجاهل أرقام بحتة
    if (RegExp(r'^[\d\s\.\,]+\$').hasMatch(s)) return '';
    // بحث مباشر
    final normalized = _normalizeForMatch(s);
    for (final entry in _subjectAliases.entries) {
      if (_normalizeForMatch(entry.key) == normalized) return entry.value;
    }
    // بحث جزئي
    for (final entry in _subjectAliases.entries) {
      final nk = _normalizeForMatch(entry.key);
      if (nk.length >= 3 && normalized.contains(nk)) return entry.value;
      if (normalized.length >= 3 && nk.contains(normalized)) return entry.value;
    }
    return ''; // غير معروف
  }

  bool _isKnownSubject(String raw) => _matchSubject(raw).isNotEmpty;


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
          final rawVal = row[c]?.value;
          // تجاهل صيغ Excel والقيم الرقمية
          if (rawVal == null) continue;
          final content = rawVal.toString().trim();
          if (content.isEmpty) continue;
          // تجاهل صيغ Excel
          if (content.startsWith('=') || content.contains('COUNTIF') ||
              content.contains('COUNTA') || content.contains('SUM(') ||
              content.contains('IF(') || content.contains('VLOOKUP')) continue;
          // تجاهل القيم الرقمية البحتة
          if (RegExp(r'^[\d\.\,\s]+\$').hasMatch(content)) continue;
          // تجاهل النصوص القصيرة جداً
          if (content.length <= 1) continue;
          String subject = content; String className = '';
          if (content.contains('\n')) {
            final pts = content.split('\n'); className = pts[0].trim();
            subject = pts.length > 1 ? pts[1].trim() : pts[0].trim();
          } else if (content.contains('-')) {
            final pts = content.split('-'); className = pts[0].trim();
            subject = pts.length > 1 ? pts[1].trim() : pts[0].trim();
          }
          rawSubjects.add(subject);
          final dayName = info['day'] as String;
          final dayIndex = _days.indexOf(dayName);
          // مطابقة المادة مباشرة
          final matchedSubject = _resolveSubject(subject);
          final mr = matchedSubject.isNotEmpty
              ? SubjectMatchResult(
                  rawName: subject,
                  matched: SubjectMaster(id: matchedSubject, officialName: matchedSubject, category: matchedSubject),
                  confidence: MatchConfidence.high)
              : SubjectMatchResult(rawName: subject, confidence: MatchConfidence.unknown);
          lessons.add(ImportedLesson(teacherName: teacherName, rawSubject: subject,
            matchResult: mr, className: className,
            dayName: dayName, dayIndex: dayIndex >= 0 ? dayIndex : 0, period: info['period'] as int));
        }
      }
      _knownCount = rawSubjects.where((s) => _resolveSubject(s).isNotEmpty).length;
      _unknownCount = rawSubjects.where((s) => _resolveSubject(s).isEmpty).length;
      _subjectStats = {};
      for (final s in rawSubjects) { _subjectStats[s] = (_subjectStats[s] ?? 0) + 1; }
      final reviewSubjects = rawSubjects.where((s) => _resolveSubject(s).isEmpty).toSet();
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
        _importResult = 'تم استيراد جدول ${teacherLessons.length} معلم بنجاح\n'
            'تم ربط $teacherCount معلم بجدوله\n'
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


  // مطابقة المواد — سلسلة if-else مباشرة لتجنب tree shaking
  String _resolveSubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.length <= 1) return '';
    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||
        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';
    // حصص الانتظار والنشاط — تُقبل كما هي
    if (s.contains('منتظر') || s.contains('انتظار') || s.contains('نوبة') ||
        s.contains('نوبه') || s.contains('مراقبة') || s.contains('مراقبه')) return s;
    if (s == 'نشاط' || s.contains('نشاط')) return 'نشاط';
    final n = s.replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي').replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي').trim().toLowerCase();
    if (n.isEmpty) return '';
    // عربي
    if (n == 'عربي' || n == 'لغتي' || n == 'لغه عربيه' || n == 'لغة عربية' ||
        n == 'اللغه العربيه' || n == 'اللغة العربية' || n == 'لغتي الخالده' ||
        n == 'الكفايات اللغويه' || n == 'كفايات لغويه') return 'اللغة العربية';
    // رياضيات
    if (n == 'رياضيات' || n == 'الرياضيات' || n == 'حساب' || n == 'رياضه' ||
        n == 'رياضيه') return 'الرياضيات';
    // علوم
    if (n == 'علوم' || n == 'العلوم' || n == 'علوم طبيعيه' || n == 'احياء' ||
        n == 'فيزياء' || n == 'كيمياء') return 'العلوم';
    // انجليزي
    if (n == 'انجليزي' || n == 'إنجليزي' || n == 'انجليزيه' || n == 'إنجليزيه' ||
        n == 'اللغه الإنجليزيه' || n == 'لغه انجليزيه' || n == 'انجليش') return 'اللغة الإنجليزية';
    // اسلامية
    if (n == 'اسلاميه' || n == 'إسلاميه' || n == 'تربيه اسلاميه' ||
        n == 'دراسات اسلاميه' || n == 'الدراسات الإسلاميه') return 'التربية الإسلامية';
    // قرآن
    if (n == 'قران' || n == 'تحفيظ' || n == 'القران الكريم' || n == 'تلاوه') return 'القرآن الكريم';
    // اجتماعيات
    if (n == 'اجتماعيات' || n == 'الاجتماعيات' || n == 'دراسات اجتماعيه' ||
        n == 'إجتماعيات') return 'الاجتماعيات';
    // رقمية
    if (n == 'حاسب' || n == 'حاسوب' || n == 'تقنيه رقميه' || n == 'الرقميه' ||
        n == 'رقميه' || n == 'حاسب الي') return 'المهارات الرقمية';
    // بدنية — جميع الأشكال
    if (n == 'بدنيه' || n == 'تربيه بدنيه' || n == 'التربيه البدنيه' ||
        n == 'تربيه البدنيه' || n == 'البدنيه' || n == 'رياضه' || n == 'رياضيه') return 'التربية البدنية';
    // فنية — جميع الأشكال
    if (n == 'فنيه' || n == 'تربيه فنيه' || n == 'التربيه الفنيه' ||
        n == 'تربيه الفنيه' || n == 'الفنيه' || n == 'رسم' || n == 'فنون') return 'التربية الفنية';
    // تفكير ناقد — جميع الأشكال
    if (n == 'تفكير ناقد' || n == 'التفكير الناقد' || n == 'ناقد' ||
        n == 'تفكيرناقد' || n == 'ناقدتفكير' || n == 'الناقد') return 'التفكير الناقد';
    // مهارات رقمية — جميع الأشكال
    if (n == 'مهارات رقميه' || n == 'المهارات الرقميه' || n == 'مهارات الرقميه' ||
        n == 'رقميه' || n == 'الرقميه' || n == 'تقنيه رقميه' || n == 'التقنيه الرقميه') return 'المهارات الرقمية';
    // مهارات الحياة — هذا هو الأهم
    if (n == 'حياتيه' || n == 'حياتيه' || n == 'مهارات حياتيه' ||
        n == 'مهارات الحياه' || n == 'مهارات' || n == 'مهاره' ||
        n == 'تنميه مهارات') return 'مهارات الحياة';
    // برايل
    if (n == 'برايل' || n == 'لغه برايل') return 'برايل';
    // بحث جزئي
    if (n.contains('عرب') || n.contains('لغتي')) return 'اللغة العربية';
    if (n.contains('رياضيات')) return 'الرياضيات';
    if (n.contains('علوم')) return 'العلوم';
    if (n.contains('انجليز') || n.contains('إنجليز')) return 'اللغة الإنجليزية';
    if (n.contains('اسلام') || n.contains('إسلام')) return 'التربية الإسلامية';
    if (n.contains('قران') || n.contains('تحفيظ')) return 'القرآن الكريم';
    if (n.contains('اجتماع')) return 'الاجتماعيات';
    if (n.contains('حاسب') || n.contains('رقمي') || n.contains('رقميه') ||
        n.contains('مهارات رقم')) return 'المهارات الرقمية';
    if (n.contains('بدني') || n.contains('بدنيه')) return 'التربية البدنية';
    if (n.contains('فني') || n.contains('فنيه') || n.contains('رسم')) return 'التربية الفنية';
    if (n.contains('حياتي') || n.contains('مهارات')) return 'مهارات الحياة';
    if (n.contains('تفكير') || n.contains('ناقد')) return 'التفكير الناقد';
    if (n.contains('برايل')) return 'برايل';
    return '';
  }

  // ─── Upload Step ─────────────────────────────────────────────────────────
  Widget _buildUpload() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const SizedBox(height: 8),
        // Drop zone
        GestureDetector(
          onTap: _pickFile,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: double.infinity, height: 200,
              decoration: BoxDecoration(
                color: _P.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _P.violet.withOpacity(0.25 + _glowAnim.value * 0.2), width: 1.5),
                boxShadow: [BoxShadow(color: _P.violet.withOpacity(_glowAnim.value * 0.06), blurRadius: 40)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_P.violet.withOpacity(0.2), _P.sky.withOpacity(0.1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(color: _P.violet.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: _P.violet.withOpacity(_glowAnim.value * 0.3), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: _P.violetLt, size: 34),
                ),
                const SizedBox(height: 16),
                const Text('اسحب الملف هنا أو اضغط للاختيار',
                    style: TextStyle(color: _P.text, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('يدعم .xlsx و .xls', style: const TextStyle(color: _P.muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Format guide
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _P.card, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _P.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 3, height: 18, decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_P.violet, _P.sky], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('الصيغة المدعومة: الجدول الذكي — جدول المعلمين',
                  style: TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 14),
            _fmtRow('B', 'المعلمون في العمود B من الصف 4', _P.muted),
            _fmtRow('C-I', 'الأحد: C-I', _P.sky),
            _fmtRow('J-P', 'الاثنين: J-P', _P.sky),
            _fmtRow('Q-W', 'الثلاثاء: Q-W', _P.sky),
            _fmtRow('X-AD', 'الأربعاء: X-AD', _P.sky),
            _fmtRow('Af-AK', 'الخميس: Af-AK', _P.sky),
            const SizedBox(height: 8),
            _fmtRow('●', 'كل خلية: رقم الصف / رقم الفصل + المادة', _P.amber),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: _btn('اختيار ملف Excel', Icons.folder_open_rounded, _pickFile, _P.violet)),
      ]),
    );
  }

  Widget _fmtRow(String tag, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Container(
          width: 32, height: 22,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Center(child: Text(tag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Text(desc, style: const TextStyle(color: _P.muted, fontSize: 12)),
      ]),
    );
  }

  // ─── Analyze Step ─────────────────────────────────────────────────────────
  Widget _buildAnalyze() {
    final total = _subjectStats.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: _P.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border)),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_rounded, color: _P.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_fileName, style: const TextStyle(color: _P.text, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _P.emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('تم التحليل', style: TextStyle(color: _P.emerald, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          _statTile(total.toString(), 'مادة مكتشفة', _P.sky, Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          _statTile(_knownCount.toString(), 'معروفة', _P.emerald, Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _statTile(_unknownCount.toString(), 'تحتاج مراجعة',
              _unknownCount > 0 ? _P.amber : _P.emerald, Icons.pending_rounded),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('المواد المكتشفة'),
        const SizedBox(height: 10),
        ..._subjectStats.entries.map((e) => _subjectRow(e.key, _resolveSubject(e.key), e.value)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: _btn(
          _reviewLessons.isEmpty ? 'متابعة للاستيراد' : 'مراجعة المواد غير المعروفة',
          Icons.arrow_forward_rounded,
          () {
            if (_reviewLessons.isEmpty) { _executeImport(); }
            else { setState(() => _step = _ImportStep.review); }
          }, _P.violet)),
      ]),
    );
  }

  Widget _statTile(String value, String label, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 10)])),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 10), textAlign: TextAlign.center),
      ]),
    ));
  }

  SubjectMatchResult _buildMatchResult(String raw) {
    final matched = _matchSubject(raw);
    if (matched.isNotEmpty) {
      return SubjectMatchResult(rawName: raw, matched: SubjectMaster(
        id: matched.toLowerCase().replaceAll(' ', '_'),
        officialName: matched, category: matched),
        confidence: MatchConfidence.high);
    }
    return SubjectMatchResult(rawName: raw, confidence: MatchConfidence.unknown);
  }

  Widget _subjectRow(String raw, String matchedName, int count) {
    Color color; String badge; IconData icon;
    if (matchedName.isNotEmpty) { color = _P.emerald; badge = 'معروفة'; icon = Icons.check_circle_rounded; }
    else { color = _P.rose; badge = 'غير معروفة'; icon = Icons.error_rounded; }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _P.card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(raw, style: const TextStyle(color: _P.text, fontWeight: FontWeight.w600, fontSize: 13)),
          if (matchedName.isNotEmpty)
            Text('→ ' + matchedName, style: TextStyle(color: color, fontSize: 11)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Text(count.toString() + ' حصة', style: const TextStyle(color: _P.muted, fontSize: 10)),
      ]),
    );
  }

  // ─── Review Step ─────────────────────────────────────────────────────────
  Widget _buildReview() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.amber.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.amber.withOpacity(0.25))),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _P.amber.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.rate_review_rounded, color: _P.amber, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_reviewLessons.length.toString() + ' مادة تحتاج تحديد يدوي',
                style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('كل تصحيح يُحفظ تلقائياً للمرات القادمة',
                style: TextStyle(color: _P.muted, fontSize: 11)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _reviewLessons.length,
        itemBuilder: (context, i) => _reviewCard(_reviewLessons[i]),
      )),
      Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: double.infinity, child: _btn(
          'تأكيد وإكمال الاستيراد', Icons.rocket_launch_rounded, _executeImport, _P.emerald)),
      ),
    ]);
  }

  Widget _reviewCard(ImportedLesson lesson) {
    final resolved = lesson.matchResult.matched != null || _matchSubject(lesson.rawSubject).isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resolved ? _P.emerald.withOpacity(0.3) : _P.amber.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: resolved ? _P.emerald.withOpacity(0.06) : _P.amber.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Icon(resolved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: resolved ? _P.emerald : _P.amber, size: 16),
            const SizedBox(width: 8),
            Text('"' + lesson.rawSubject + '"',
                style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 14)),
            if (resolved) ...[ const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _P.muted, size: 12),
              const SizedBox(width: 4),
              Text(lesson.matchResult.matched!.officialName,
                  style: const TextStyle(color: _P.emerald, fontSize: 12))],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<String>(
            value: lesson.matchResult.matched?.officialName,
            dropdownColor: _P.surface,
            style: const TextStyle(color: _P.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'اختر التصنيف الصحيح',
              labelStyle: const TextStyle(color: _P.muted, fontSize: 12),
              filled: true, fillColor: _P.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.violet, width: 1.5)),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('-- غير محدد --', style: TextStyle(color: _P.muted))),
              ..._subjectAliases.values.toSet().map((name) => DropdownMenuItem(
                value: name, child: Text(name, style: const TextStyle(color: _P.text)))),
            ],
            onChanged: (name) {
              if (name == null) return;
              setState(() {
                lesson.matchResult = SubjectMatchResult(
                  rawName: lesson.rawSubject,
                  matched: SubjectMaster(id: name.toLowerCase().replaceAll(' ', '_'), officialName: name, category: name),
                  confidence: MatchConfidence.high);
                for (final l in _allLessons) { if (l.rawSubject == lesson.rawSubject) l.matchResult = lesson.matchResult; }
              });
            },
          ),
        ),
        if (resolved)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              const Icon(Icons.bookmark_added_rounded, color: _P.emerald, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'سيُحفظ كمرادف: "' + lesson.rawSubject + '" → ' + (lesson.matchResult.matched?.officialName ?? ''),
                style: const TextStyle(color: _P.emerald, fontSize: 11))),
            ]),
          ),
      ]),
    );
  }

  // ─── Done Step ────────────────────────────────────────────────────────────
  Widget _buildDone() {
    final teacherCount = _allLessons.map((l) => l.teacherName).toSet().length;
    final subjectCount = _allLessons.map((l) => l.resolvedSubject).toSet().length;
    final classCount = _allLessons.map((l) => l.className).where((c) => c.isNotEmpty).toSet().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_P.emerald.withOpacity(0.2), Colors.transparent]),
              boxShadow: [BoxShadow(color: _P.emerald.withOpacity(_glowAnim.value * 0.35), blurRadius: 40)],
              border: Border.all(color: _P.emerald.withOpacity(0.5), width: 1.5),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _P.emerald, size: 50),
          ),
        ),
        const SizedBox(height: 20),
        const Text('تم الاستيراد بنجاح!',
            style: TextStyle(color: _P.text, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('تم حفظ الجدول وتوزيعه على المعلمين والفصول',
            style: const TextStyle(color: _P.muted, fontSize: 13)),
        const SizedBox(height: 28),
        Row(children: [
          _doneTile(Icons.people_rounded, teacherCount.toString(), 'معلم', _P.violet),
          const SizedBox(width: 10),
          _doneTile(Icons.menu_book_rounded, subjectCount.toString(), 'مادة', _P.sky),
          const SizedBox(width: 10),
          _doneTile(Icons.class_rounded, classCount.toString(), 'فصل', _P.amber),
          const SizedBox(width: 10),
          _doneTile(Icons.event_note_rounded, _allLessons.length.toString(), 'حصة', _P.emerald),
        ]),
        if (_importResult.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _P.emerald.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.emerald.withOpacity(0.2))),
            child: Text(_importResult, style: const TextStyle(color: _P.emerald, fontSize: 13, height: 1.6)),
          ),
        ],
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: _btn('استيراد جدول آخر', Icons.upload_file_rounded, _reset, _P.violet)),
          const SizedBox(width: 12),
          Expanded(child: _btn('العودة', Icons.arrow_back_rounded,
              () => Navigator.of(context).pop(), _P.muted)),
        ]),
      ]),
    );
  }

  Widget _doneTile(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 16)]),
      child: Column(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 10)),
      ]),
    ));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_P.violet, _P.sky],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color == _P.muted ? _P.card : color,
        foregroundColor: color == _P.muted ? _P.muted : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: color == _P.muted ? const BorderSide(color: _P.border) : BorderSide.none),
        elevation: 0,
      ),
    );
  }
}
