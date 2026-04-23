import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../admin/data/firestore_teacher_repository.dart'; // Changed to Firestore
import '../../admin/data/firestore_class_repository.dart';
import '../data/schedule_repository.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/teacher_constraints_profile.dart';
// import 'smart_schedule_screen.dart'; // REMOVED: File does not exist

class TeacherQuotasScreen extends ConsumerStatefulWidget {
  const TeacherQuotasScreen({super.key});

  @override
  ConsumerState<TeacherQuotasScreen> createState() =>
      _TeacherQuotasScreenState();
}

class _TeacherQuotasScreenState extends ConsumerState<TeacherQuotasScreen> {
  bool _isLoading = true;
  String _schoolName = 'المدرسة';
  List<User> _teachers = [];
  Map<String, TeacherConstraintsProfile> _profiles = {};
  Map<String, int> _teacherLoadById = {};
  int _totalClasses = 0;

  // Stats
  int _totalWeeklySlotsNeeded = 0;
  int _totalTeacherCapacity = 0;
  Map<String, int> _subjectDeficit = {};
  Map<String, int> _subjectDemand = {};
  Map<String, int> _subjectSupply = {};

  // Subject Catalog (managed from Firestore)
  Map<String, String> _subjectTranslation = {
    'Arabic': 'اللغة العربية',
    'Math': 'الرياضيات',
    'Science': 'العلوم',
    'English': 'اللغة الإنجليزية',
    'Islamic': 'التربية الإسلامية',
    'Social': 'الاجتماعيات',
    'PE': 'التربية البدنية',
    'Art': 'التربية الفنية',
    'Computer': 'الحاسب الآلي',
  };
  Map<String, int> _subjectWeights = {
    'Arabic': 6,
    'Math': 5,
    'Science': 4,
    'English': 4,
    'Islamic': 4,
    'Social': 3,
    'PE': 2,
    'Art': 2,
    'Computer': 2,
  };
  Map<String, double> _assignmentWeights = {
    'primary': 1.0,
    'additional': 0.6,
    'emergency': 0.3,
  };
  Map<String, List<String>> _subjectAliases = {
    'Arabic': [
      'اللغة العربية',
      'لغتي',
      'لغة عربية',
      'لغه عربيه',
      'اللغه العربيه',
    ],
    'Math': ['الرياضيات', 'رياضيات'],
    'Science': ['العلوم'],
    'English': ['اللغة الإنجليزية', 'الانجليزية', 'الإنجليزية', 'انجليزي'],
    'Islamic': [
      'التربية الإسلامية',
      'التربية الاسلامية',
      'الإسلامية',
      'اسلامية',
    ],
    'Social': ['الدراسات الاجتماعية', 'الاجتماعيات', 'اجتماعيات'],
    'Computer': ['الحاسب الآلي', 'الحاسب', 'حاسب', 'كمبيوتر'],
    'Art': ['التربية الفنية', 'الفنية'],
    'PE': ['التربية البدنية', 'البدنية'],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadSubjectCatalog(String schoolId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .get();
      if (doc.exists) {
        final data = doc.data();
        final subjects = data?['subjects'] as Map<String, dynamic>?;
        final assignW = data?['assignmentWeights'];
        if (assignW is Map<String, dynamic>) {
          final p = double.tryParse('${assignW['primary'] ?? 1.0}') ?? 1.0;
          final a = double.tryParse('${assignW['additional'] ?? 0.6}') ?? 0.6;
          final e = double.tryParse('${assignW['emergency'] ?? 0.3}') ?? 0.3;
          _assignmentWeights = {'primary': p, 'additional': a, 'emergency': e};
        }
        if (subjects != null && subjects.isNotEmpty) {
          final trans = <String, String>{};
          final weights = <String, int>{};
          final aliases = <String, List<String>>{};
          subjects.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final name = (value['name'] ?? key).toString();
              final weight = (value['weight'] is int)
                  ? value['weight'] as int
                  : int.tryParse('${value['weight'] ?? 0}') ?? 0;
              final rawAliases = value['aliases'];
              final aliasList = <String>[];
              if (rawAliases is List) {
                for (final a in rawAliases) {
                  if (a == null) continue;
                  final s = a.toString().trim();
                  if (s.isNotEmpty) aliasList.add(s);
                }
              }
              trans[key] = name;
              weights[key] = weight;
              aliases[key] = aliasList;
            }
          });
          if (trans.isNotEmpty) _subjectTranslation = trans;
          if (weights.isNotEmpty) _subjectWeights = weights;
          if (aliases.isNotEmpty) _subjectAliases = aliases;
        }
      }
    } catch (e) {
      debugPrint('Failed to load subject catalog: $e');
    }
  }

  Future<void> _saveSubjectCatalog(String schoolId) async {
    try {
      final map = <String, dynamic>{};
      _subjectTranslation.forEach((key, name) {
        map[key] = {
          'name': name,
          'weight': _subjectWeights[key] ?? 0,
          'aliases': _subjectAliases[key] ?? const [],
        };
      });
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .set(
            {'subjects': map, 'assignmentWeights': _assignmentWeights},
            SetOptions(merge: false),
          ); // Changed merge: true to false to allow deletions
    } catch (e) {
      debugPrint('Failed to save subject catalog: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ المواد: $e')));
    }
  }

  String _localizeSubjectName(String subject) {
    // Try direct match
    if (_subjectTranslation.containsKey(subject)) {
      return _subjectTranslation[subject]!;
    }
    // Try case-insensitive match
    final lower = subject.toLowerCase();
    for (final entry in _subjectTranslation.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    // If arabic, keep it
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(subject)) return subject;

    return subject; // Fallback
  }

  String _normalizeKey(String s) {
    var v = s.trim().toLowerCase();
    v = v
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
    return v;
  }

  Map<String, String> _buildAliasLookup() {
    final map = <String, String>{};
    for (final id in _subjectTranslation.keys) {
      map[_normalizeKey(id)] = id;
      map[_normalizeKey(_subjectTranslation[id] ?? id)] = id;
      final aliases = _subjectAliases[id] ?? const [];
      for (final a in aliases) {
        map[_normalizeKey(a)] = id;
      }
    }
    return map;
  }

  String? _resolveSubjectId(String? input) {
    if (input == null) return null;
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final lookup = _buildAliasLookup();
    return lookup[_normalizeKey(raw)];
  }

  final ScrollController _pageScrollController = ScrollController();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;

      await _loadSubjectCatalog(schoolId);

      // Fetch School Name
      final schoolDoc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .get();
      if (schoolDoc.exists) {
        _schoolName =
            (schoolDoc.data()?['name'] ??
                    schoolDoc.data()?['schoolName'] ??
                    'المدرسة')
                .toString();
      }

      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final classRepo = ref.read(classRepositoryProvider);

      // 1. Load Teachers & Classes
      final teachers = await teacherRepo.getTeachers(schoolId: schoolId);
      final classes = await classRepo.getClasses(schoolId);
      final profilesList = await scheduleRepo.getTeacherConstraints(schoolId);
      final profilesMap = {for (final p in profilesList) p.teacherId: p};

      final loadById = <String, int>{};
      const chunkSize = 12;
      for (var i = 0; i < teachers.length; i += chunkSize) {
        final chunk = teachers.skip(i).take(chunkSize).toList();
        final results = await Future.wait(
          chunk.map((t) async {
            try {
              final load = await scheduleRepo.getTeacherLoad(schoolId, t.id);
              return MapEntry(t.id, load);
            } catch (_) {
              return MapEntry(t.id, 0);
            }
          }),
        );
        for (final e in results) {
          loadById[e.key] = e.value;
        }
        await Future.delayed(Duration.zero);
      }

      // 2. Calculate Capacity (Supply)
      // Correct Logic: Supply = Sum of quotas of teachers for each subject
      int totalCapacity = 0;
      final capacityBySubject = <String, int>{};

      // Initialize all known subjects with 0
      for (final key in _subjectTranslation.keys) {
        capacityBySubject[key] = 0;
      }

      for (final t in teachers) {
        final quota = _effectiveQuotaForTeacher(t, profilesMap);
        totalCapacity += quota;

        final primary =
            _resolveSubjectId(t.primarySubjectId) ??
            _resolveSubjectId(t.specialization);
        final assignments = t.subjectAssignments ?? const [];
        final additional = assignments
            .where((a) => a.type == SubjectAssignmentType.additional)
            .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
            .where((s) => s.trim().isNotEmpty)
            .toList();
        final emergency = assignments
            .where((a) => a.type == SubjectAssignmentType.emergency)
            .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
            .where((s) => s.trim().isNotEmpty)
            .toList();

        if (primary == null && additional.isEmpty && emergency.isEmpty) {
          continue;
        }
        final unique = <String>{
          if (primary != null) primary,
          ...additional,
          ...emergency,
        }.toList();

        final baseWeights = <String, double>{};
        for (final id in unique) {
          if (id == primary) {
            baseWeights[id] = _assignmentWeights['primary'] ?? 1.0;
          } else if (additional.contains(id)) {
            baseWeights[id] = _assignmentWeights['additional'] ?? 0.6;
          } else {
            baseWeights[id] = _assignmentWeights['emergency'] ?? 0.3;
          }
        }

        final sum = baseWeights.values.fold<double>(0.0, (a, b) => a + b);
        final shares = <String, int>{};
        var used = 0;
        for (final entry in baseWeights.entries) {
          final share = (quota * (entry.value / sum)).floor();
          shares[entry.key] = share;
          used += share;
        }
        final remainder = quota - used;
        final primaryKey = primary ?? unique.first;
        shares[primaryKey] = (shares[primaryKey] ?? 0) + remainder;

        for (final entry in shares.entries) {
          capacityBySubject.putIfAbsent(entry.key, () => 0);
          capacityBySubject[entry.key] =
              (capacityBySubject[entry.key] ?? 0) + entry.value;
        }
      }

      // 3. Calculate Demand from Catalog Weights
      // Assuming 35 periods per week standard
      const periodsPerClass = 35;
      final totalNeeded = classes.length * periodsPerClass;

      final subjectDemand = <String, int>{};
      for (final s in _subjectTranslation.keys) {
        final weight = _subjectWeights[s] ?? 0;
        subjectDemand[s] = classes.length * weight;
      }

      // Adjust total needed to match sum of subject demands if we want precise subject tracking
      // Or keep totalNeeded as strictly ClassCount * 35
      // Here we keep totalNeeded as macro indicator

      // 4. Calculate Deficit/Surplus per Subject
      final subjectDeficit = <String, int>{};
      for (final s in subjectDemand.keys) {
        final demand = subjectDemand[s]!;
        final supply = capacityBySubject[s] ?? 0;
        subjectDeficit[s] = demand - supply; // Positive = Deficit
      }

      if (mounted) {
        setState(() {
          _teachers = teachers;
          _profiles = profilesMap;
          _teacherLoadById = loadById;
          _totalClasses = classes.length;
          _totalWeeklySlotsNeeded = totalNeeded;
          _totalTeacherCapacity = totalCapacity;
          _subjectDeficit = subjectDeficit;
          _subjectDemand = subjectDemand;
          _subjectSupply = capacityBySubject;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading quota data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQuota(String teacherId, int newQuota) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    setState(() {
      final oldProfile = _profiles[teacherId];
      if (oldProfile != null) {
        _profiles[teacherId] = oldProfile.copyWith(weeklyQuota: newQuota);
      } else {
        _profiles[teacherId] = TeacherConstraintsProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          teacherId: teacherId,
          schoolId: schoolId,
          weeklyQuota: newQuota,
        );
      }

      // Re-calculate totals
      _totalTeacherCapacity = _profiles.values.fold(
        0,
        (sum, p) => sum + p.weeklyQuota,
      );
    });

    try {
      final repo = ref.read(scheduleRepositoryProvider);
      var profile = _profiles[teacherId]!;
      await repo.saveTeacherConstraints(profile);
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
      final teacher = _teachers.firstWhere(
        (t) => t.id == teacherId,
        orElse: () => User(
          id: teacherId,
          name: '',
          email: '',
          role: UserRole.teacher,
          schoolId: schoolId,
        ),
      );
      if (teacher.name.isNotEmpty) {
        await teacherRepo.updateTeacher(
          teacher.copyWith(maxWeeklyClasses: newQuota),
        );
      }
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final overallDeficit = _subjectDeficit.values
        .where((v) => v > 0)
        .fold<int>(0, (a, b) => a + b);
    final coveragePercent = _totalWeeklySlotsNeeded > 0
        ? ((_totalTeacherCapacity / _totalWeeklySlotsNeeded) * 100)
              .clamp(0, 100)
              .toInt()
        : 100;
    final isReady = overallDeficit <= 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('لوحة قيادة الأنصبة'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تقرير الاحتياج',
            onPressed: _showRequirementReport,
            icon: const Icon(Icons.assessment_outlined),
          ),
          IconButton(
            tooltip: 'إدارة المواد',
            onPressed: _openManageSubjectsDialog,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        controller: _pageScrollController,
        padding: EdgeInsets.only(bottom: 100.h),
        children: [
          // 1. Dashboard KPIs (General Status)
          _buildDashboardHeader(overallDeficit, coveragePercent),

          // 2. Decision Center (Main Problem & Suggested Action)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _buildDecisionCenter(
              overallDeficit: overallDeficit,
              isReady: isReady,
            ),
          ),

          // 3. Actionable Quick Recommendations (Executive Buttons) - Hidden when ready
          if (!isReady) ...[
            _buildActionableRecommendations(),
            SizedBox(height: 12.h),
          ],

          // 4. Detailed Analysis (Collapsible Details)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [
                  _buildCollapsibleSection(
                    title: 'تحليل المواد التفصيلي',
                    subtitle: 'توزيع الحصص والعجز لكل مادة',
                    icon: Icons.analytics_outlined,
                    child: _buildSubjectStatusList(),
                  ),
                  SizedBox(height: 12.h),
                  _buildCollapsibleSection(
                    title: 'قائمة المعلمين والأنصبة',
                    subtitle:
                        '${_teachers.length} معلم | متوسط النصاب: ${(_totalTeacherCapacity / (_teachers.isEmpty ? 1 : _teachers.length)).toStringAsFixed(1)}',
                    icon: Icons.people_outline,
                    child: _buildTeacherCompactList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(isReady),
    );
  }

  Future<void> _showRequirementReport() async {
    final user = ref.read(authStateProvider).value;
    final schoolName = _schoolName;
    final date = intl.DateFormat('yyyy/MM/dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Colors.teal),
            SizedBox(width: 8.w),
            const Text('تقرير الاحتياج المدرسي الرسمي'),
          ],
        ),
        content: SizedBox(
          width: 800.w,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportHeader(schoolName, date),
                SizedBox(height: 20.h),
                _buildReportStatusBanner(),
                SizedBox(height: 16.h),
                _buildReportTable(),
                SizedBox(height: 24.h),
                _buildReportSummary(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () => _generateRequirementPdf(schoolName, date),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('تحميل التقرير PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(String schoolName, String date) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المدرسة: $schoolName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('العام الدراسي: 1445هـ'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('التاريخ: $date'),
                  const Text('الفصل الدراسي: الثاني'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportStatusBanner() {
    final overallDeficit = _subjectDeficit.values
        .where((v) => v > 0)
        .fold<int>(0, (a, b) => a + b);
    final isReady = overallDeficit <= 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isReady ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isReady ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.warning,
            color: isReady ? Colors.green : Colors.orange.shade800,
          ),
          SizedBox(width: 8.w),
          Text(
            isReady
                ? 'المدرسة متوازنة ولا يوجد احتياج إضافي.'
                : 'تنبيه: يوجد عجز في أنصبة بعض المواد، يرجى مراجعة الجدول أدناه.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReady ? Colors.green.shade800 : Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(2), // Subject
        1: FlexColumnWidth(1), // Classes
        2: FlexColumnWidth(1), // Slots/Class
        3: FlexColumnWidth(1.2), // Total Slots
        4: FlexColumnWidth(1.2), // Standard Quota
        5: FlexColumnWidth(1.2), // Required Teachers
        6: FlexColumnWidth(1), // Current Teachers
        7: FlexColumnWidth(1.2), // Status
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.teal.shade50),
          children: [
            _buildTableHeaderCell('المادة'),
            _buildTableHeaderCell('الفصول'),
            _buildTableHeaderCell('حصص/فصل'),
            _buildTableHeaderCell('إجمالي الحصص'),
            _buildTableHeaderCell('النصاب المعتمد'),
            _buildTableHeaderCell('الاحتياج الفعلي'),
            _buildTableHeaderCell('المعلمون الحاليون'),
            _buildTableHeaderCell('الحالة'),
          ],
        ),
        ..._subjectTranslation.keys.map((subjectId) {
          final name = _subjectTranslation[subjectId] ?? subjectId;
          final classesCount = _totalClasses;
          final slotsPerClass = _subjectWeights[subjectId] ?? 0;
          final totalSlots = _subjectDemand[subjectId] ?? 0;
          const standardQuota = 24;
          final requiredTeachers = (totalSlots / standardQuota).toStringAsFixed(
            1,
          );

          // Current teachers count (approximate based on capacity)
          final supply = _subjectSupply[subjectId] ?? 0;
          final currentTeachers = (supply / standardQuota).toStringAsFixed(1);

          final deficit = _subjectDeficit[subjectId] ?? 0;
          String status;
          Color statusColor;
          if (deficit > 0) {
            status = 'عجز $deficit';
            statusColor = Colors.red.shade700;
          } else if (deficit < 0) {
            status = 'فائض ${-deficit}';
            statusColor = Colors.blue.shade700;
          } else {
            status = 'متوازن';
            statusColor = Colors.green.shade700;
          }

          return TableRow(
            children: [
              _buildTableCell(name),
              _buildTableCell('$classesCount'),
              _buildTableCell('$slotsPerClass'),
              _buildTableCell('$totalSlots'),
              _buildTableCell('$standardQuota'),
              _buildTableCell(requiredTeachers),
              _buildTableCell(currentTeachers),
              _buildTableCell(status, color: statusColor),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? color}) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildReportSummary() {
    final overallDeficit = _subjectDeficit.values.fold<int>(0, (a, b) => a + b);
    const standardQuota = 24;
    final totalRequiredTeachers = (_totalWeeklySlotsNeeded / standardQuota)
        .toStringAsFixed(1);
    final totalCurrentTeachers = (_totalTeacherCapacity / standardQuota)
        .toStringAsFixed(1);

    String schoolStatus;
    Color statusColor;
    if (overallDeficit > 0) {
      schoolStatus = 'يوجد عجز إجمالي بمقدار $overallDeficit حصة أسبوعية';
      statusColor = Colors.red.shade800;
    } else if (overallDeficit < 0) {
      schoolStatus = 'يوجد فائض إجمالي بمقدار ${-overallDeficit} حصة أسبوعية';
      statusColor = Colors.blue.shade800;
    } else {
      schoolStatus = 'المدرسة متوازنة تماماً';
      statusColor = Colors.green.shade800;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص التقرير النهائي:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          _buildSummaryLine(
            'إجمالي الحصص الأسبوعية المطلوبة:',
            '$_totalWeeklySlotsNeeded',
          ),
          _buildSummaryLine(
            'إجمالي السعة التدريسية المتاحة:',
            '$_totalTeacherCapacity',
          ),
          _buildSummaryLine(
            'الاحتياج الفعلي الكلي (معلمين):',
            totalRequiredTeachers,
          ),
          _buildSummaryLine(
            'عدد المعلمين الحاليين (مكافئ):',
            totalCurrentTeachers,
          ),
          const Divider(),
          Row(
            children: [
              const Text(
                'حالة المدرسة الإجمالية: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                schoolStatus,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _generateRequirementPdf(String schoolName, String date) async {
    final pdf = pw.Document();

    // Arabic Font Support
    final font = await PdfGoogleFonts.notoKufiArabicRegular();
    final fontBold = await PdfGoogleFonts.notoKufiArabicBold();

    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('images/logo1.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }

    final overallDeficit = _subjectDeficit.values.fold<int>(0, (a, b) => a + b);
    const standardQuota = 24;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Stack(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'المملكة العربية السعودية',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          ),
                          pw.Text(
                            'وزارة التعليم',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          ),
                          pw.Text(
                            'مدرسة $schoolName',
                            style: pw.TextStyle(font: fontBold, fontSize: 12),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'تقرير احتياج الكادر التعليمي',
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                          pw.Text(
                            'التاريخ: $date',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          ),
                          pw.Text(
                            'العام الدراسي: 1445هـ',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Align(
                      alignment: pw.Alignment.topCenter,
                      child: pw.Image(logoImage, width: 60, height: 60),
                    ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Status Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: overallDeficit <= 0
                      ? PdfColors.green50
                      : PdfColors.orange50,
                  border: pw.Border.all(
                    color: overallDeficit <= 0
                        ? PdfColors.green200
                        : PdfColors.orange200,
                  ),
                ),
                child: pw.Text(
                  overallDeficit <= 0
                      ? 'إفادة: المدرسة متوازنة ولا يوجد احتياج إضافي حالياً.'
                      : 'تنبيه: يوجد احتياج تعليمي في بعض التخصصات كما هو موضح أدناه.',
                  style: pw.TextStyle(
                    font: fontBold,
                    color: overallDeficit <= 0
                        ? PdfColors.green800
                        : PdfColors.orange900,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _pdfTableCell('الحالة', fontBold, isHeader: true),
                        _pdfTableCell('الحالي', fontBold, isHeader: true),
                        _pdfTableCell(
                          'الاحتياج الفعلي',
                          fontBold,
                          isHeader: true,
                        ),
                        _pdfTableCell('النصاب', fontBold, isHeader: true),
                        _pdfTableCell('إجمالي الحصص', fontBold, isHeader: true),
                        _pdfTableCell('حصص/فصل', fontBold, isHeader: true),
                        _pdfTableCell('الفصول', fontBold, isHeader: true),
                        _pdfTableCell('المادة', fontBold, isHeader: true),
                      ],
                    ),
                    // Rows
                    ..._subjectTranslation.keys.map((subjectId) {
                      final totalSlots = _subjectDemand[subjectId] ?? 0;
                      final supply = _subjectSupply[subjectId] ?? 0;
                      final deficit = _subjectDeficit[subjectId] ?? 0;

                      return pw.TableRow(
                        children: [
                          _pdfTableCell(
                            deficit > 0
                                ? 'عجز $deficit'
                                : (deficit < 0 ? 'فائض ${-deficit}' : 'متوازن'),
                            fontBold,
                            color: deficit > 0
                                ? PdfColors.red
                                : (deficit < 0
                                      ? PdfColors.blue
                                      : PdfColors.green),
                          ),
                          _pdfTableCell(
                            (supply / standardQuota).toStringAsFixed(1),
                            font,
                          ),
                          _pdfTableCell(
                            (totalSlots / standardQuota).toStringAsFixed(1),
                            font,
                          ),
                          _pdfTableCell('$standardQuota', font),
                          _pdfTableCell('$totalSlots', font),
                          _pdfTableCell(
                            '${_subjectWeights[subjectId] ?? 0}',
                            font,
                          ),
                          _pdfTableCell('$_totalClasses', font),
                          _pdfTableCell(
                            _subjectTranslation[subjectId] ?? subjectId,
                            font,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'الملخص النهائي للتقرير:',
                      style: pw.TextStyle(font: fontBold),
                    ),
                    pw.SizedBox(height: 10),
                    _pdfSummaryRow(
                      'إجمالي الحصص الأسبوعية المطلوبة:',
                      '$_totalWeeklySlotsNeeded',
                      font,
                    ),
                    _pdfSummaryRow(
                      'إجمالي السعة التدريسية المتاحة:',
                      '$_totalTeacherCapacity',
                      font,
                    ),
                    _pdfSummaryRow(
                      'الاحتياج الفعلي الكلي (معلمين):',
                      (_totalWeeklySlotsNeeded / standardQuota).toStringAsFixed(
                        1,
                      ),
                      font,
                    ),
                    _pdfSummaryRow(
                      'عدد المعلمين الحاليين (مكافئ):',
                      (_totalTeacherCapacity / standardQuota).toStringAsFixed(
                        1,
                      ),
                      font,
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'حالة الجاهزية الإجمالية:',
                          style: pw.TextStyle(font: fontBold),
                        ),
                        pw.Text(
                          overallDeficit <= 0
                              ? 'مكتمل وجاهز'
                              : 'يوجد احتياج متبقي',
                          style: pw.TextStyle(
                            font: fontBold,
                            color: overallDeficit <= 0
                                ? PdfColors.green
                                : PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('ختم المدرسة', style: pw.TextStyle(font: font)),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        '....................',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'توقيع مدير المدرسة',
                        style: pw.TextStyle(font: font),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        '....................',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _pdfTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 9 : 8,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
            color: Colors.grey.shade900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
        ),
        childrenPadding: EdgeInsets.all(12.w),
        children: [child],
      ),
    );
  }

  Future<void> _openManageSubjectsDialog() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    final defaultAssignmentWeights = <String, double>{
      'primary': 1.0,
      'additional': 0.6,
      'emergency': 0.3,
    };

    await showDialog(
      context: context,
      builder: (context) {
        final localTranslation = Map<String, String>.from(_subjectTranslation);
        final localWeights = Map<String, int>.from(_subjectWeights);
        final localAliases = <String, List<String>>{
          for (final e in _subjectAliases.entries)
            e.key: List<String>.from(e.value),
        };

        final localNameControllers = <String, TextEditingController>{};
        final localWeightControllers = <String, TextEditingController>{};
        final localAliasControllers = <String, TextEditingController>{};

        final localKeys = localTranslation.keys.toList();
        for (final k in localKeys) {
          localNameControllers[k] = TextEditingController(
            text: localTranslation[k],
          );
          localWeightControllers[k] = TextEditingController(
            text: '${localWeights[k] ?? 0}',
          );
          localAliasControllers[k] = TextEditingController(
            text: (localAliases[k] ?? const []).join(', '),
          );
        }

        final primaryWeightController = TextEditingController(
          text:
              '${_assignmentWeights['primary'] ?? defaultAssignmentWeights['primary']!}',
        );
        final additionalWeightController = TextEditingController(
          text:
              '${_assignmentWeights['additional'] ?? defaultAssignmentWeights['additional']!}',
        );
        final emergencyWeightController = TextEditingController(
          text:
              '${_assignmentWeights['emergency'] ?? defaultAssignmentWeights['emergency']!}',
        );

        final newKeyController = TextEditingController();
        final newNameController = TextEditingController();
        final newWeightController = TextEditingController(text: '0');

        return StatefulBuilder(
          builder: (context, setModalState) {
            void deleteSubject(String id) {
              final name = localTranslation[id] ?? id;
              localTranslation.remove(id);
              localWeights.remove(id);
              localAliases.remove(id);
              localNameControllers.remove(id)?.dispose();
              localWeightControllers.remove(id)?.dispose();
              localAliasControllers.remove(id)?.dispose();
              localKeys.remove(id);
              setModalState(() {});

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تم حذف $name')));
            }

            void addSubject() {
              final name = newNameController.text.trim();
              final w = int.tryParse(newWeightController.text.trim()) ?? 0;
              var id = newKeyController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المادة')),
                );
                return;
              }
              if (id.isEmpty) {
                // Create a better ID from the name if possible, otherwise use timestamp
                final slug = name
                    .replaceAll(RegExp(r'[^\w\s]'), '')
                    .replaceAll(RegExp(r'\s+'), '_');
                id = slug.isNotEmpty
                    ? slug
                    : 'Subject${DateTime.now().millisecondsSinceEpoch}';
              }

              if (localTranslation.containsKey(id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('المعرّف أو المادة موجودة مسبقاً'),
                  ),
                );
                return;
              }

              localTranslation[id] = name;
              localWeights[id] = w;
              localAliases[id] = [name];
              localKeys.add(id);
              localNameControllers[id] = TextEditingController(text: name);
              localWeightControllers[id] = TextEditingController(text: '$w');
              localAliasControllers[id] = TextEditingController(text: name);
              newKeyController.clear();
              newNameController.clear();
              newWeightController.text = '0';
              setModalState(() {});

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تمت إضافة $name بنجاح')));
            }

            localKeys.sort(
              (a, b) =>
                  _localizeSubjectName(a).compareTo(_localizeSubjectName(b)),
            );

            return AlertDialog(
              title: const Text('إدارة المواد الدراسية'),
              content: SizedBox(
                width: 580.w,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المواد الحالية:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12.h),
                        ...localKeys.map((k) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 16.h),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: localNameControllers[k],
                                        decoration: const InputDecoration(
                                          labelText: 'اسم المادة',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      flex: 1,
                                      child: TextFormField(
                                        controller: localWeightControllers[k],
                                        decoration: const InputDecoration(
                                          labelText: 'حصص/فصل',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => deleteSubject(k),
                                      tooltip: 'حذف المادة',
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                TextFormField(
                                  controller: localAliasControllers[k],
                                  decoration: const InputDecoration(
                                    labelText: 'المرادفات (افصل بفاصلة)',
                                    hintText: 'مثلاً: لغتي، القراءة، التعبير',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'المعرّف الداخلي: $k',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 32),
                        const Text(
                          'إضافة مادة جديدة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.teal.shade100),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: newNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'الاسم العربي',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: newWeightController,
                                      decoration: const InputDecoration(
                                        labelText: 'حصص/فصل',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: newKeyController,
                                      decoration: const InputDecoration(
                                        labelText: 'المعرّف (اختياري)',
                                        hintText: 'يُستخدم داخلياً للربط',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  ElevatedButton.icon(
                                    onPressed: addSubject,
                                    icon: const Icon(Icons.add),
                                    label: const Text('إضافة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 32),
                        const Text(
                          'أوزان نوع الإسناد (تحليل السعة):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'هذه الأوزان تؤثر على تحليل السعة وتوزيع نصاب المعلم بين المواد.\n'
                          'ولا تغيّر أولوية الجدولة؛ لأن أولوية الجدولة ثابتة: أساسي ثم إضافي ثم طارئ.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: primaryWeightController,
                                decoration: const InputDecoration(
                                  labelText: 'الأساسية',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextFormField(
                                controller: additionalWeightController,
                                decoration: const InputDecoration(
                                  labelText: 'الإضافية',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextFormField(
                                controller: emergencyWeightController,
                                decoration: const InputDecoration(
                                  labelText: 'الطارئة',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              primaryWeightController.text =
                                  '${defaultAssignmentWeights['primary']!}';
                              additionalWeightController.text =
                                  '${defaultAssignmentWeights['additional']!}';
                              emergencyWeightController.text =
                                  '${defaultAssignmentWeights['emergency']!}';
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('الافتراضية'),
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final c in localNameControllers.values) {
                      c.dispose();
                    }
                    for (final c in localWeightControllers.values) {
                      c.dispose();
                    }
                    for (final c in localAliasControllers.values) {
                      c.dispose();
                    }
                    newKeyController.dispose();
                    newNameController.dispose();
                    newWeightController.dispose();
                    primaryWeightController.dispose();
                    additionalWeightController.dispose();
                    emergencyWeightController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (final k in localKeys) {
                      final name = localNameControllers[k]?.text.trim() ?? '';
                      localTranslation[k] = name.isEmpty
                          ? (localTranslation[k] ?? k)
                          : name;
                      localWeights[k] =
                          int.tryParse(
                            localWeightControllers[k]?.text.trim() ?? '',
                          ) ??
                          (localWeights[k] ?? 0);
                      final raw = localAliasControllers[k]?.text ?? '';
                      final list = raw
                          .split(RegExp(r'[,\\n]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      localAliases[k] = list;
                    }

                    final p = double.tryParse(
                      primaryWeightController.text.trim(),
                    );
                    final a = double.tryParse(
                      additionalWeightController.text.trim(),
                    );
                    final e = double.tryParse(
                      emergencyWeightController.text.trim(),
                    );
                    final localAssignmentWeights = {
                      'primary': p ?? defaultAssignmentWeights['primary']!,
                      'additional':
                          a ?? defaultAssignmentWeights['additional']!,
                      'emergency': e ?? defaultAssignmentWeights['emergency']!,
                    };

                    setState(() {
                      _subjectTranslation = Map<String, String>.from(
                        localTranslation,
                      );
                      _subjectWeights = Map<String, int>.from(localWeights);
                      _subjectAliases = {
                        for (final entry in localAliases.entries)
                          entry.key: List<String>.from(entry.value),
                      };
                      _assignmentWeights = Map<String, double>.from(
                        localAssignmentWeights,
                      );
                    });

                    await _saveSubjectCatalog(schoolId);
                    await _loadData();

                    for (final c in localNameControllers.values) {
                      c.dispose();
                    }
                    for (final c in localWeightControllers.values) {
                      c.dispose();
                    }
                    for (final c in localAliasControllers.values) {
                      c.dispose();
                    }
                    newKeyController.dispose();
                    newNameController.dispose();
                    newWeightController.dispose();
                    primaryWeightController.dispose();
                    additionalWeightController.dispose();
                    emergencyWeightController.dispose();

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardHeader(int deficit, int coveragePercent) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32.r),
          bottomRight: Radius.circular(32.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKPIItem(
                'الاحتياج',
                '$_totalWeeklySlotsNeeded',
                Icons.calendar_view_week,
              ),
              _buildKPIItem(
                'السعة',
                '$_totalTeacherCapacity',
                Icons.people_alt,
              ),
              _buildKPIItem(
                'العجز',
                '$deficit',
                Icons.warning_rounded,
                color: deficit > 0 ? Colors.orangeAccent : Colors.white,
              ),
              _buildKPIItem(
                'التغطية',
                '$coveragePercent%',
                Icons.pie_chart_rounded,
                color: coveragePercent >= 100
                    ? Colors.lightGreenAccent
                    : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.white,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.9), size: 24.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCenter({
    required int overallDeficit,
    required bool isReady,
  }) {
    final top = _subjectDeficit.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSubject = top.isNotEmpty ? top.first.key : null;
    final topSubjectName = topSubject != null
        ? _localizeSubjectName(topSubject)
        : '';
    final topSubjectDef = topSubject != null
        ? _subjectDeficit[topSubject] ?? 0
        : 0;

    // Recommendation logic
    String diagnosis;
    String recommendation;
    IconData icon;
    Color color;

    if (isReady) {
      diagnosis = 'جاهزية تامة لإنشاء الجدول';
      recommendation =
          'تمت موازنة جميع الأنصبة بنجاح، يمكنك الآن الاعتماد والبدء.';
      icon = Icons.verified_user_rounded;
      color = Colors.teal;
    } else {
      diagnosis = 'عجز في مادة $topSubjectName';
      recommendation =
          'هناك نقص بمقدار $topSubjectDef حصص. يوصى بزيادة النصاب أو الإسناد.';
      icon = Icons.error_outline;
      color = Colors.orange.shade800;
    }

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التشخيص والقرار:',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      diagnosis,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isReady) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: () {
                      if (topSubject != null) {
                        _showQuickQuotaAdjustment(
                          context,
                          topSubject,
                          _localizeSubjectName(topSubject),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('حل الآن'),
                        SizedBox(width: 4.w),
                        Icon(Icons.arrow_back, size: 16.sp), // Arabic direction
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 12.h),
            const Divider(),
            SizedBox(height: 8.h),
            Text(
              recommendation,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectStatusList() {
    final items = _subjectTranslation.keys.toList();
    items.sort((a, b) {
      final da = _subjectDeficit[a] ?? 0;
      final db = _subjectDeficit[b] ?? 0;
      final pa = da > 0 ? 0 : 1;
      final pb = db > 0 ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      if (da != db) return db.compareTo(da);
      return _localizeSubjectName(a).compareTo(_localizeSubjectName(b));
    });

    return Column(
      children: items.map((subjectId) {
        final name = _localizeSubjectName(subjectId);
        final def = _subjectDeficit[subjectId] ?? 0;
        final isOk = def <= 0;
        final MaterialColor color = isOk ? Colors.green : Colors.orange;
        final statusText = isOk ? 'متوازن' : 'عجز $def حصص';
        return Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 10.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => _showQuickQuotaAdjustment(context, subjectId, name),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  Icon(
                    isOk ? Icons.check_circle : Icons.warning_amber,
                    color: color,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: color.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.arrow_back_ios,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeacherCompactList() {
    final highLoad = <User>[];
    final balanced = <User>[];
    final lowLoad = <User>[];

    for (final teacher in _teachers) {
      final profile = _profiles[teacher.id];
      final quota = profile?.weeklyQuota ?? 24;
      final load = _teacherLoadById[teacher.id] ?? 0;

      if (load > quota) {
        highLoad.add(teacher);
      } else if (load < (quota * 0.5).floor()) {
        lowLoad.add(teacher);
      } else {
        balanced.add(teacher);
      }
    }

    // Sort each list
    highLoad.sort((a, b) => a.name.compareTo(b.name));
    balanced.sort((a, b) => a.name.compareTo(b.name));
    lowLoad.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        if (lowLoad.isNotEmpty)
          _buildTeacherCategoryGroup(
            'نصاب منخفض / فائض (حلول متاحة)',
            lowLoad,
            Colors.blue,
          ),
        if (balanced.isNotEmpty)
          _buildTeacherCategoryGroup('نصاب متوازن', balanced, Colors.green),
        if (highLoad.isNotEmpty)
          _buildTeacherCategoryGroup(
            'نصاب مرتفع / عجز',
            highLoad,
            Colors.orange,
          ),
      ],
    );
  }

  Widget _buildTeacherCategoryGroup(
    String title,
    List<User> teachers,
    MaterialColor color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                  color: color.shade900,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '(${teachers.length})',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
        ...teachers.map((teacher) => _buildTeacherItemCard(teacher)),
        SizedBox(height: 12.h),
      ],
    );
  }

  Widget _buildTeacherItemCard(User teacher) {
    final profile = _profiles[teacher.id];
    final quota = profile?.weeklyQuota ?? 24;
    final load = _teacherLoadById[teacher.id] ?? 0;
    final ratioText = '$load / $quota';

    String status = 'متوازن';
    Color statusColor = Colors.green;
    if (load < (quota * 0.5).floor()) {
      status = 'منخفض';
      statusColor = Colors.blue;
    } else if (load > quota) {
      status = 'مرتفع';
      statusColor = Colors.orange;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showTeacherDetails(teacher),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: Colors.teal.shade50,
                child: Text(
                  teacher.name.isNotEmpty ? teacher.name[0] : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'النصاب: $ratioText',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  GestureDetector(
                    onTap: () => _assignTeacherSubject(teacher),
                    child: Text(
                      'إسناد سريع',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTeacherDetails(User teacher) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: _buildTeacherCard(teacher),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReadinessDetails() async {
    if (!mounted) return;
    final overallDeficit = _subjectDeficit.values
        .where((v) => v > 0)
        .fold<int>(0, (a, b) => a + b);
    final readinessPercent = _totalWeeklySlotsNeeded > 0
        ? (100 - ((overallDeficit / _totalWeeklySlotsNeeded) * 100))
              .clamp(0, 100)
              .toInt()
        : 100;

    final reasons = _subjectDeficit.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('مؤشر جاهزية الجدول'),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جاهزية الجدول: $readinessPercent%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10.h),
                if (reasons.isEmpty)
                  const Text('لا توجد أسباب تمنع إنشاء الجدول حالياً.')
                else ...[
                  const Text(
                    'الأسباب:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  ...reasons
                      .take(8)
                      .map(
                        (e) => Text(
                          '• عجز في ${_localizeSubjectName(e.key)}: ${e.value} حصص',
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _autoBalanceSchool();
              },
              child: const Text('إصلاح تلقائي'),
            ),
          ],
        );
      },
    );
  }

  final ScrollController _subjectScrollController = ScrollController();

  int _rankMaxQuota(String? rank) {
    if (rank == 'advanced') return 22;
    if (rank == 'expert') return 18;
    return 24;
  }

  int _effectiveQuotaForTeacher(
    User teacher,
    Map<String, TeacherConstraintsProfile> profilesMap,
  ) {
    final fromProfile = profilesMap[teacher.id]?.weeklyQuota;
    final fromTeacher = teacher.maxWeeklyClasses;
    return fromProfile ?? fromTeacher ?? _rankMaxQuota(teacher.teacherRank);
  }

  ({Map<String, int> demand, Map<String, int> supply, Map<String, int> deficit})
  _computeSubjectMetrics({
    required List<User> teachers,
    required Map<String, int> quotaByTeacherId,
  }) {
    final capacityBySubject = <String, int>{};
    for (final key in _subjectTranslation.keys) {
      capacityBySubject[key] = 0;
    }

    for (final t in teachers) {
      final quota =
          quotaByTeacherId[t.id] ??
          t.maxWeeklyClasses ??
          _rankMaxQuota(t.teacherRank);

      final primary =
          _resolveSubjectId(t.primarySubjectId) ??
          _resolveSubjectId(t.specialization);
      final assignments = t.subjectAssignments ?? const [];
      final additional = assignments
          .where((a) => a.type == SubjectAssignmentType.additional)
          .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final emergency = assignments
          .where((a) => a.type == SubjectAssignmentType.emergency)
          .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
          .where((s) => s.trim().isNotEmpty)
          .toList();

      if (primary == null && additional.isEmpty && emergency.isEmpty) {
        continue;
      }
      final unique = <String>{
        if (primary != null) primary,
        ...additional,
        ...emergency,
      }.toList();

      final baseWeights = <String, double>{};
      for (final id in unique) {
        if (id == primary) {
          baseWeights[id] = _assignmentWeights['primary'] ?? 1.0;
        } else if (additional.contains(id)) {
          baseWeights[id] = _assignmentWeights['additional'] ?? 0.6;
        } else {
          baseWeights[id] = _assignmentWeights['emergency'] ?? 0.3;
        }
      }

      final sum = baseWeights.values.fold<double>(0.0, (a, b) => a + b);
      final shares = <String, int>{};
      var used = 0;
      for (final entry in baseWeights.entries) {
        final share = (quota * (entry.value / sum)).floor();
        shares[entry.key] = share;
        used += share;
      }
      final remainder = quota - used;
      final primaryKey = primary ?? unique.first;
      shares[primaryKey] = (shares[primaryKey] ?? 0) + remainder;

      for (final entry in shares.entries) {
        capacityBySubject.putIfAbsent(entry.key, () => 0);
        capacityBySubject[entry.key] =
            (capacityBySubject[entry.key] ?? 0) + entry.value;
      }
    }

    final subjectDemand = <String, int>{};
    for (final s in _subjectTranslation.keys) {
      final weight = _subjectWeights[s] ?? 0;
      subjectDemand[s] = _totalClasses * weight;
    }

    final subjectDeficit = <String, int>{};
    for (final s in subjectDemand.keys) {
      final demand = subjectDemand[s]!;
      final supply = capacityBySubject[s] ?? 0;
      subjectDeficit[s] = demand - supply;
    }

    return (
      demand: subjectDemand,
      supply: capacityBySubject,
      deficit: subjectDeficit,
    );
  }

  Widget _buildActionableRecommendations() {
    final top = _subjectDeficit.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSubject = top.isNotEmpty ? top.first.key : null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'إصلاح تلقائي',
                  icon: Icons.auto_fix_high,
                  color: Colors.deepOrange,
                  onPressed: _autoBalanceSchool,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionButton(
                  label: 'معالجة يدوية',
                  icon: Icons.edit_note,
                  color: Colors.teal,
                  onPressed: () {
                    if (topSubject != null) {
                      _showQuickQuotaAdjustment(
                        context,
                        topSubject,
                        _localizeSubjectName(topSubject),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يوجد عجز يتطلب معالجة يدوية'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              label: 'إسناد مادة إضافية لمعلم',
              icon: Icons.person_add_alt_1,
              color: Colors.blue.shade700,
              onPressed: _openManageSubjectsDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20.sp),
      label: Text(
        label,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _autoBalanceSchool() async {
    int totalDeficit(Map<String, int> deficitBySubject) {
      return deficitBySubject.values
          .where((d) => d > 0)
          .fold<int>(0, (a, b) => a + b);
    }

    final initialQuotaByTeacherId = <String, int>{
      for (final t in _teachers) t.id: _effectiveQuotaForTeacher(t, _profiles),
    };
    final base = _computeSubjectMetrics(
      teachers: _teachers,
      quotaByTeacherId: initialQuotaByTeacherId,
    );
    final baseTotalDeficit = totalDeficit(base.deficit);
    if (baseTotalDeficit <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('المدرسة متوازنة بالفعل')));
      return;
    }

    final teacherById = {for (final t in _teachers) t.id: t};
    final simTeacherById = Map<String, User>.from(teacherById);
    final simQuotaByTeacherId = Map<String, int>.from(initialQuotaByTeacherId);

    final actions = <Map<String, dynamic>>[];
    var current = base;
    var currentTotalDeficit = baseTotalDeficit;

    bool alreadyAssignedTo(User t, String subjectId) {
      final primary =
          _resolveSubjectId(t.primarySubjectId) ??
          _resolveSubjectId(t.specialization);
      if (primary == subjectId) return true;
      return (t.subjectAssignments ?? const []).any((a) {
        final sid = _resolveSubjectId(a.subjectId) ?? a.subjectId;
        return sid == subjectId;
      });
    }

    int quotaOf(User t) {
      return simQuotaByTeacherId[t.id] ??
          t.maxWeeklyClasses ??
          _rankMaxQuota(t.teacherRank);
    }

    ({
      Map<String, int> demand,
      Map<String, int> supply,
      Map<String, int> deficit,
    })
    recompute() {
      return _computeSubjectMetrics(
        teachers: simTeacherById.values.toList(),
        quotaByTeacherId: simQuotaByTeacherId,
      );
    }

    bool applyIfImproves({
      required Map<String, dynamic> action,
      required ({
        Map<String, int> demand,
        Map<String, int> supply,
        Map<String, int> deficit,
      })
      next,
      required void Function() commit,
    }) {
      final nextTotal = totalDeficit(next.deficit);
      final improvement = currentTotalDeficit - nextTotal;
      if (improvement <= 0) return false;
      action['beforeTotalDeficit'] = currentTotalDeficit;
      action['afterTotalDeficit'] = nextTotal;
      action['improvement'] = improvement;
      final subjectId = action['subjectId'];
      if (subjectId is String) {
        action['beforeSubjectDeficit'] = current.deficit[subjectId] ?? 0;
        action['afterSubjectDeficit'] = next.deficit[subjectId] ?? 0;
      }
      commit();
      actions.add(action);
      current = next;
      currentTotalDeficit = nextTotal;
      return true;
    }

    final maxActions = 12;
    while (actions.length < maxActions && currentTotalDeficit > 0) {
      Map<String, dynamic>? bestAction;
      ({
        Map<String, int> demand,
        Map<String, int> supply,
        Map<String, int> deficit,
      })?
      bestNext;
      var bestImprovement = 0;

      for (final t in simTeacherById.values) {
        final primary =
            _resolveSubjectId(t.primarySubjectId) ??
            _resolveSubjectId(t.specialization);
        if (primary == null) continue;
        if ((current.deficit[primary] ?? 0) <= 0) continue;
        final currentQuota = quotaOf(t);
        final maxQuota = _rankMaxQuota(t.teacherRank);
        if (currentQuota >= maxQuota) continue;

        final nextQuotaByTeacherId = Map<String, int>.from(simQuotaByTeacherId);
        nextQuotaByTeacherId[t.id] = maxQuota;
        final nextMetrics = _computeSubjectMetrics(
          teachers: simTeacherById.values.toList(),
          quotaByTeacherId: nextQuotaByTeacherId,
        );
        final nextTotal = totalDeficit(nextMetrics.deficit);
        final improvement = currentTotalDeficit - nextTotal;
        if (improvement > bestImprovement) {
          bestImprovement = improvement;
          bestAction = {
            'type': 'quota',
            'teacherId': t.id,
            'teacherName': t.name,
            'from': currentQuota,
            'to': maxQuota,
            'subjectId': primary,
          };
          bestNext = nextMetrics;
        }
      }

      if (bestAction != null && bestNext != null && bestImprovement > 0) {
        final t = simTeacherById[bestAction['teacherId']]!;
        final target = bestAction['to'] as int;
        final ok = applyIfImproves(
          action: bestAction,
          next: bestNext,
          commit: () {
            simQuotaByTeacherId[t.id] = target;
          },
        );
        if (ok) continue;
      }

      bestAction = null;
      bestNext = null;
      bestImprovement = 0;

      final deficitSubjects =
          current.deficit.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      for (final e in deficitSubjects) {
        final subjectId = e.key;
        for (final t in simTeacherById.values) {
          if (alreadyAssignedTo(t, subjectId)) continue;
          final primary =
              _resolveSubjectId(t.primarySubjectId) ??
              _resolveSubjectId(t.specialization);
          if (primary == null) continue;
          if ((current.deficit[primary] ?? 0) > 0 && actions.length < 2) {
            continue;
          }

          final nextTeacherById = Map<String, User>.from(simTeacherById);
          final currentAssignments = (t.subjectAssignments ?? const [])
              .toList();
          currentAssignments.add(
            SubjectAssignment(
              subjectId: subjectId,
              type: SubjectAssignmentType.additional,
            ),
          );
          nextTeacherById[t.id] = t.copyWith(
            subjectAssignments: currentAssignments,
          );
          final nextMetrics = _computeSubjectMetrics(
            teachers: nextTeacherById.values.toList(),
            quotaByTeacherId: simQuotaByTeacherId,
          );
          final nextTotal = totalDeficit(nextMetrics.deficit);
          final improvement = currentTotalDeficit - nextTotal;
          if (improvement > bestImprovement) {
            bestImprovement = improvement;
            bestAction = {
              'type': 'assign',
              'teacherId': t.id,
              'teacherName': t.name,
              'subjectId': subjectId,
              'assignmentType': 'additional',
            };
            bestNext = nextMetrics;
          }
        }
      }

      if (bestAction != null && bestNext != null && bestImprovement > 0) {
        final teacherId = bestAction['teacherId'] as String;
        final subjectId = bestAction['subjectId'] as String;
        final t = simTeacherById[teacherId]!;
        final currentAssignments = (t.subjectAssignments ?? const []).toList();
        currentAssignments.add(
          SubjectAssignment(
            subjectId: subjectId,
            type: SubjectAssignmentType.additional,
          ),
        );
        final ok = applyIfImproves(
          action: bestAction,
          next: bestNext,
          commit: () {
            simTeacherById[teacherId] = t.copyWith(
              subjectAssignments: currentAssignments,
            );
          },
        );
        if (ok) continue;
      }

      bestAction = null;
      bestNext = null;
      bestImprovement = 0;

      for (final e in deficitSubjects) {
        final subjectId = e.key;
        for (final t in simTeacherById.values) {
          if (alreadyAssignedTo(t, subjectId)) continue;
          final primary =
              _resolveSubjectId(t.primarySubjectId) ??
              _resolveSubjectId(t.specialization);
          if (primary == null) continue;
          if ((current.deficit[primary] ?? 0) > 0) continue;

          final nextTeacherById = Map<String, User>.from(simTeacherById);
          final currentAssignments = (t.subjectAssignments ?? const [])
              .toList();
          currentAssignments.add(
            SubjectAssignment(
              subjectId: subjectId,
              type: SubjectAssignmentType.emergency,
            ),
          );
          nextTeacherById[t.id] = t.copyWith(
            subjectAssignments: currentAssignments,
          );
          final nextMetrics = _computeSubjectMetrics(
            teachers: nextTeacherById.values.toList(),
            quotaByTeacherId: simQuotaByTeacherId,
          );
          final nextTotal = totalDeficit(nextMetrics.deficit);
          final improvement = currentTotalDeficit - nextTotal;
          if (improvement > bestImprovement) {
            bestImprovement = improvement;
            bestAction = {
              'type': 'assign',
              'teacherId': t.id,
              'teacherName': t.name,
              'subjectId': subjectId,
              'assignmentType': 'emergency',
            };
            bestNext = nextMetrics;
          }
        }
      }

      if (bestAction != null && bestNext != null && bestImprovement > 0) {
        final teacherId = bestAction['teacherId'] as String;
        final subjectId = bestAction['subjectId'] as String;
        final t = simTeacherById[teacherId]!;
        final currentAssignments = (t.subjectAssignments ?? const []).toList();
        currentAssignments.add(
          SubjectAssignment(
            subjectId: subjectId,
            type: SubjectAssignmentType.emergency,
          ),
        );
        final ok = applyIfImproves(
          action: bestAction,
          next: bestNext,
          commit: () {
            simTeacherById[teacherId] = t.copyWith(
              subjectAssignments: currentAssignments,
            );
          },
        );
        if (ok) continue;
      }

      break;
    }

    final finalSim = recompute();
    final finalTotalDeficit = totalDeficit(finalSim.deficit);

    String actionTitle(Map<String, dynamic> a) {
      if (a['type'] == 'quota') {
        return 'رفع نصاب: ${a['teacherName']} (${a['from']} → ${a['to']})';
      }
      final subjectName = _localizeSubjectName(a['subjectId'] as String);
      final type = a['assignmentType'] == 'emergency' ? 'طارئة' : 'إضافية';
      return 'إسناد مادة $type: ${a['teacherName']} → $subjectName';
    }

    String actionImpact(Map<String, dynamic> a) {
      final improvement = (a['improvement'] as int?) ?? 0;
      final beforeS = a['beforeSubjectDeficit'];
      final afterS = a['afterSubjectDeficit'];
      final subjectDelta = (beforeS is int && afterS is int)
          ? ' | عجز المادة: $beforeS → $afterS'
          : '';
      return improvement > 0
          ? 'تحسين العجز الإجمالي: $improvement حصص$subjectDelta'
          : 'بدون أثر';
    }

    String formatBalance(int v) {
      if (v > 0) return 'عجز $v';
      if (v < 0) return 'فائض ${v.abs()}';
      return 'متوازن';
    }

    List<String> buildSubjectDeltaLines({
      required Map<String, int> before,
      required Map<String, int> after,
      int limit = 14,
    }) {
      final keys = <String>{...before.keys, ...after.keys}.toList();
      keys.sort((a, b) {
        final da = (before[a] ?? 0) - (after[a] ?? 0);
        final db = (before[b] ?? 0) - (after[b] ?? 0);
        final aa = da.abs();
        final ab = db.abs();
        if (aa != ab) return ab.compareTo(aa);
        return _localizeSubjectName(a).compareTo(_localizeSubjectName(b));
      });
      final lines = <String>[];
      for (final k in keys) {
        final b = before[k] ?? 0;
        final a = after[k] ?? 0;
        if (b == a) continue;
        lines.add(
          '${_localizeSubjectName(k)}: ${formatBalance(b)} → ${formatBalance(a)}',
        );
        if (lines.length >= limit) break;
      }
      return lines;
    }

    if (actions.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('موازنة المدرسة تلقائيًا'),
            content: const Text(
              'لم يتم العثور على موازنة داخلية فعّالة دون تجاوز النصاب أو الاعتماد على إسناد طارئ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('محاكاة موازنة المدرسة'),
              content: SizedBox(
                width: 420.w,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العجز قبل: $baseTotalDeficit حصص',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'العجز بعد المحاكاة: $finalTotalDeficit حصص',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8.h),
                      const Divider(),
                      const Text(
                        'التعديلات المقترحة (لن تُطبّق إلا بعد التأكيد):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8.h),
                      ...actions.map((a) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  actionTitle(a),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(actionImpact(a)),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      const Text(
                        'تغير العجز/الفائض لكل مادة (قبل → بعد):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6.h),
                      ...buildSubjectDeltaLines(
                        before: base.deficit,
                        after: finalSim.deficit,
                      ).map((s) => Text('• $s')),
                      SizedBox(height: 10.h),
                      const Text(
                        'الوضع المتوقع بعد المحاكاة (مواد فيها عجز):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6.h),
                      ...finalSim.deficit.entries
                          .where((e) => e.value > 0)
                          .toList()
                          .map(
                            (e) => Text(
                              '• ${_localizeSubjectName(e.key)}: عجز ${e.value} حصص',
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('تطبيق التعديلات المقترحة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    var loadingShown = false;
    if (mounted) {
      loadingShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;

      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);

      final quotaChanges = <String, int>{};
      final assignChanges = <Map<String, dynamic>>[];
      for (final a in actions) {
        if (a['type'] == 'quota') {
          quotaChanges[a['teacherId'] as String] = a['to'] as int;
        } else if (a['type'] == 'assign') {
          assignChanges.add(a);
        }
      }

      for (final entry in quotaChanges.entries) {
        final teacherId = entry.key;
        final teacher = teacherById[teacherId];
        if (teacher == null) continue;
        final maxQuota = _rankMaxQuota(teacher.teacherRank);
        final target = entry.value > maxQuota ? maxQuota : entry.value;
        final existing = _profiles[teacherId];
        final profile = existing != null
            ? existing.copyWith(weeklyQuota: target, schoolId: schoolId)
            : TeacherConstraintsProfile(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                teacherId: teacherId,
                schoolId: schoolId,
                weeklyQuota: target,
              );
        await scheduleRepo.saveTeacherConstraints(profile);
        await teacherRepo.updateTeacher(
          teacher.copyWith(maxWeeklyClasses: target),
        );
      }

      for (final a in assignChanges) {
        final teacherId = a['teacherId'] as String;
        final teacher = teacherById[teacherId];
        if (teacher == null) continue;
        final subjectId = a['subjectId'] as String;
        final typeStr = a['assignmentType'] as String? ?? 'additional';
        final type = typeStr == 'emergency'
            ? SubjectAssignmentType.emergency
            : SubjectAssignmentType.additional;

        if (type == SubjectAssignmentType.emergency) {
          final stillHasDeficit =
              (_subjectDeficit[subjectId] ?? 0) > 0 ||
              (finalSim.deficit[subjectId] ?? 0) > 0;
          if (!stillHasDeficit) continue;
        }

        if (alreadyAssignedTo(teacher, subjectId)) continue;
        final currentAssignments = (teacher.subjectAssignments ?? const [])
            .toList();
        currentAssignments.add(
          SubjectAssignment(subjectId: subjectId, type: type),
        );
        await teacherRepo.updateTeacher(
          teacher.copyWith(subjectAssignments: currentAssignments),
        );
      }

      await _loadData();
    } finally {
      if (loadingShown && mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }

    if (!mounted) return;
    final afterDef = totalDeficit(_subjectDeficit);
    final subjectDeltaAfterApply = buildSubjectDeltaLines(
      before: base.deficit,
      after: _subjectDeficit,
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('نتيجة الموازنة'),
          content: SizedBox(
            width: 420.w,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'العجز بعد التطبيق: $afterDef حصص',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  const Divider(),
                  const Text(
                    'تغير العجز/الفائض لكل مادة (قبل → بعد):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  ...subjectDeltaAfterApply.map((s) => Text('• $s')),
                  SizedBox(height: 10.h),
                  const Text(
                    'مواد ما زال فيها عجز:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  ..._subjectDeficit.entries
                      .where((e) => e.value > 0)
                      .toList()
                      .map(
                        (e) => Text(
                          '• ${_localizeSubjectName(e.key)}: عجز ${e.value} حصص',
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickQuotaAdjustment(
    BuildContext context,
    String subjectKey,
    String subjectName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter teachers for this subject
            final teachersForSubject = _teachers.where((t) {
              final primary =
                  _resolveSubjectId(t.primarySubjectId) ??
                  _resolveSubjectId(t.specialization);
              if (primary == subjectKey) return true;
              final assignments = t.subjectAssignments ?? const [];
              return assignments.any((a) {
                final sid = _resolveSubjectId(a.subjectId) ?? a.subjectId;
                return sid == subjectKey;
              });
            }).toList();

            return Container(
              padding: EdgeInsets.all(16.w),
              height: 500.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'معلمو $subjectName',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Builder(
                    builder: (_) {
                      final demand = _subjectDemand[subjectKey] ?? 0;
                      final supply = _subjectSupply[subjectKey] ?? 0;
                      final def = _subjectDeficit[subjectKey] ?? 0;
                      const baseQuota = 24;
                      final requiredTeachers = demand > 0
                          ? (demand / baseQuota).ceil()
                          : 0;
                      final remainder = demand > 0 ? (demand % baseQuota) : 0;
                      final statusColor = def <= 0
                          ? Colors.green
                          : Colors.deepOrange;
                      final statusText = def <= 0 ? 'متوازن' : 'عجز $def حصص';
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  def <= 0
                                      ? Icons.check_circle
                                      : Icons.warning_amber,
                                  color: statusColor,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'الطلب: $demand | العرض: $supply | المتبقي: ${def > 0 ? def : 0}',
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'عدد المعلمين المطلوب (تقريبي): $requiredTeachers | كسر الاحتياج: $remainder',
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _autoBalanceSchool,
                                    icon: const Icon(Icons.psychology),
                                    label: const Text('إصلاح تلقائي'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10.h,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      User? picked;
                                      final availableTeachers = _teachers.where(
                                        (t) {
                                          final isAssigned =
                                              (t.subjectAssignments ?? const [])
                                                  .any((a) {
                                                    final sid =
                                                        _resolveSubjectId(
                                                          a.subjectId,
                                                        ) ??
                                                        a.subjectId;
                                                    return sid == subjectKey;
                                                  });
                                          final isPrimary =
                                              (_resolveSubjectId(
                                                    t.primarySubjectId,
                                                  ) ??
                                                  t.primarySubjectId) ==
                                              subjectKey;
                                          return !isAssigned && !isPrimary;
                                        },
                                      ).toList();

                                      if (availableTeachers.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'جميع المعلمين مسندين لهذه المادة بالفعل',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      await showDialog(
                                        context: context,
                                        builder: (dctx) {
                                          return AlertDialog(
                                            title: const Text(
                                              'إسناد مادة إضافية',
                                            ),
                                            content:
                                                DropdownButtonFormField<String>(
                                                  value: null,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'اختر المعلم',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                  items: availableTeachers
                                                      .map(
                                                        (t) => DropdownMenuItem(
                                                          value: t.id,
                                                          child: Text(t.name),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (v) {
                                                    if (v == null) return;
                                                    picked = availableTeachers
                                                        .firstWhere(
                                                          (t) => t.id == v,
                                                        );
                                                  },
                                                ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dctx),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(dctx),
                                                child: const Text('متابعة'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (picked == null) return;
                                      await _persistTeacherSubjectAssignment(
                                        picked!,
                                        subjectKey,
                                        SubjectAssignmentType.additional,
                                      );
                                      setModalState(() {});
                                    },
                                    icon: const Icon(Icons.add_task),
                                    label: const Text('إسناد إضافي'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.teal.shade800,
                                      side: BorderSide(
                                        color: Colors.teal.shade300,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10.h,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                  if (teachersForSubject.isEmpty)
                    Center(
                      child: Text(
                        'لا يوجد معلمين لهذا التخصص',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: teachersForSubject.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final teacher = teachersForSubject[index];
                          final profile = _profiles[teacher.id];
                          final quota = profile?.weeklyQuota ?? 24;

                          return Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: Colors.teal.shade100,
                                  child: Text(
                                    teacher.name[0],
                                    style: TextStyle(
                                      color: Colors.teal.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    teacher.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        onPressed: quota > 0
                                            ? () async {
                                                await _updateQuota(
                                                  teacher.id,
                                                  quota - 1,
                                                );
                                                setModalState(() {});
                                              }
                                            : null,
                                      ),
                                      Container(
                                        width: 30.w,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quota',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        onPressed: quota < 40
                                            ? () async {
                                                await _updateQuota(
                                                  teacher.id,
                                                  quota + 1,
                                                );
                                                setModalState(() {});
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherCard(User teacher) {
    final profile = _profiles[teacher.id];
    final quota = profile?.weeklyQuota ?? 24;
    final rank = teacher.teacherRank ?? 'practitioner';

    final primaryId =
        _resolveSubjectId(teacher.primarySubjectId) ??
        _resolveSubjectId(teacher.specialization);
    final primaryName = primaryId != null
        ? _localizeSubjectName(primaryId)
        : 'غير محدد';

    final assignments = teacher.subjectAssignments ?? const [];
    final additionalIds = assignments
        .where((a) => a.type == SubjectAssignmentType.additional)
        .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    final emergencyIds = assignments
        .where((a) => a.type == SubjectAssignmentType.emergency)
        .map((a) => _resolveSubjectId(a.subjectId) ?? a.subjectId)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();

    // Load Status Logic
    String status = 'متوازن';
    Color statusColor = Colors.green;
    if (quota > 24) {
      status = 'مرتفع';
      statusColor = Colors.orange;
    } else if (quota < 10) {
      status = 'منخفض';
      statusColor = Colors.blue;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundColor: Colors.teal.shade50,
            child: Text(
              teacher.name[0],
              style: TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'أساسي: $primaryName',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: rank,
                          items: const [
                            DropdownMenuItem(
                              value: 'practitioner',
                              child: Text('ممارس (24)'),
                            ),
                            DropdownMenuItem(
                              value: 'advanced',
                              child: Text('متقدم (22)'),
                            ),
                            DropdownMenuItem(
                              value: 'expert',
                              child: Text('خبير (18)'),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            final repo = ref.read(
                              firestoreTeacherRepositoryProvider,
                            );
                            final updated = teacher.copyWith(teacherRank: v);
                            await repo.updateTeacher(updated);
                            final newQuota = _rankMaxQuota(v);
                            await _updateQuota(teacher.id, newQuota);
                            if (mounted) {
                              setState(() {
                                final idx = _teachers.indexWhere(
                                  (t) => t.id == teacher.id,
                                );
                                if (idx != -1) _teachers[idx] = updated;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (additionalIds.isNotEmpty || emergencyIds.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    'إسنادات المواد:',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      ...additionalIds.map((id) {
                        final name = _localizeSubjectName(id);
                        return InputChip(
                          label: Text(
                            'إضافي: $name',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: TextStyle(color: Colors.blue.shade800),
                          onPressed: () =>
                              _editTeacherSubjectAssignment(teacher, id),
                          onDeleted: () =>
                              _removeTeacherSubjectAssignment(teacher, id),
                          deleteIconColor: Colors.blue.shade700,
                        );
                      }),
                      ...emergencyIds.map((id) {
                        final name = _localizeSubjectName(id);
                        return InputChip(
                          label: Text(
                            'طارئ: $name',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          backgroundColor: Colors.orange.shade50,
                          labelStyle: TextStyle(color: Colors.orange.shade900),
                          onPressed: () =>
                              _editTeacherSubjectAssignment(teacher, id),
                          onDeleted: () =>
                              _removeTeacherSubjectAssignment(teacher, id),
                          deleteIconColor: Colors.orange.shade800,
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Quota Stepper
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      quota > 0 ? _updateQuota(teacher.id, quota - 1) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                Container(
                  width: 30.w,
                  alignment: Alignment.center,
                  child: Text(
                    '$quota',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      quota < 40 ? _updateQuota(teacher.id, quota + 1) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton.icon(
            onPressed: () => _assignTeacherSubject(teacher),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إسناد مادة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTeacherSubject(User teacher) async {
    String? selectedId;
    String customName = '';
    SubjectAssignmentType selectedType = SubjectAssignmentType.additional;
    final keys = _subjectTranslation.keys.toList()..sort();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إسناد مادة للمعلم'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      hint: const Text('اختر المادة'),
                      items: [
                        ...keys.map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(_localizeSubjectName(k)),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '__other__',
                          child: Text('أخرى'),
                        ),
                      ],
                      onChanged: (v) => setState(() => selectedId = v),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<SubjectAssignmentType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع الإسناد',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SubjectAssignmentType.primary,
                          child: Text('مادة أساسية'),
                        ),
                        DropdownMenuItem(
                          value: SubjectAssignmentType.additional,
                          child: Text('مادة إضافية'),
                        ),
                        DropdownMenuItem(
                          value: SubjectAssignmentType.emergency,
                          child: Text('مادة طارئة'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedType = v);
                      },
                    ),
                    if (selectedId == '__other__') ...[
                      SizedBox(height: 12.h),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'اسم المادة',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => customName = v,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                String subjectId;
                if (selectedId == null) return;
                if (selectedId == '__other__') {
                  if (customName.trim().isEmpty) return;
                  subjectId = await _ensureCustomSubjectExists(
                    customName.trim(),
                  );
                } else {
                  subjectId = selectedId!;
                }
                await _persistTeacherSubjectAssignment(
                  teacher,
                  subjectId,
                  selectedType,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _ensureCustomSubjectExists(String displayName) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return displayName;

    final existingId = _resolveSubjectId(displayName);
    if (existingId != null) return existingId;

    final ascii = displayName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '');
    final id = ascii.isNotEmpty
        ? ascii
        : 'Custom${DateTime.now().millisecondsSinceEpoch}';

    if (_subjectTranslation.containsKey(id)) return id;

    _subjectTranslation[id] = displayName;
    _subjectWeights[id] = _subjectWeights[id] ?? 0;
    _subjectAliases[id] = [displayName];
    await _saveSubjectCatalog(schoolId);
    return id;
  }

  Future<void> _persistTeacherSubjectAssignment(
    User teacher,
    String subjectId,
    SubjectAssignmentType type,
  ) async {
    final repo = ref.read(firestoreTeacherRepositoryProvider);
    final normalized = _resolveSubjectId(subjectId) ?? subjectId;
    if (type != SubjectAssignmentType.primary &&
        (teacher.primarySubjectId ?? '').trim() == normalized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه المادة هي المادة الأساسية بالفعل')),
      );
      return;
    }

    final current = teacher.subjectAssignments ?? const [];
    final next = current
        .where(
          (a) => (_resolveSubjectId(a.subjectId) ?? a.subjectId) != normalized,
        )
        .where(
          (a) => type != SubjectAssignmentType.primary
              ? true
              : a.type != SubjectAssignmentType.primary,
        )
        .toList();

    if (type != SubjectAssignmentType.primary) {
      next.add(SubjectAssignment(subjectId: normalized, type: type));
    }

    final updated = teacher.copyWith(
      primarySubjectId: type == SubjectAssignmentType.primary
          ? normalized
          : teacher.primarySubjectId,
      subjectAssignments: next,
    );
    try {
      await repo.updateTeacher(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      return;
    }
    // Update local list
    setState(() {
      final idx = _teachers.indexWhere((t) => t.id == teacher.id);
      if (idx != -1) _teachers[idx] = updated;
    });
    await _loadData(); // Recompute indicators
  }

  Future<void> _removeTeacherSubjectAssignment(
    User teacher,
    String subjectId,
  ) async {
    final key = _resolveSubjectId(subjectId) ?? subjectId;
    final repo = ref.read(firestoreTeacherRepositoryProvider);
    final updated = teacher.copyWith(
      subjectAssignments: (teacher.subjectAssignments ?? const [])
          .where((a) => a.subjectId != key)
          .toList(),
      primarySubjectId: teacher.primarySubjectId == key
          ? null
          : teacher.primarySubjectId,
    );
    await repo.updateTeacher(updated);
    setState(() {
      final idx = _teachers.indexWhere((t) => t.id == teacher.id);
      if (idx != -1) _teachers[idx] = updated;
    });
    await _loadData();
  }

  Future<void> _editTeacherSubjectAssignment(
    User teacher,
    String subjectId,
  ) async {
    final key = _resolveSubjectId(subjectId) ?? subjectId;
    final current = teacher.subjectAssignments ?? const [];
    final existing = current.firstWhere(
      (a) => a.subjectId == key,
      orElse: () => SubjectAssignment(
        subjectId: key,
        type: SubjectAssignmentType.additional,
      ),
    );
    SubjectAssignmentType selectedType = existing.type;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل نوع الإسناد: ${_localizeSubjectName(key)}'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<SubjectAssignmentType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الإسناد',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SubjectAssignmentType.primary,
                    child: Text('مادة أساسية'),
                  ),
                  DropdownMenuItem(
                    value: SubjectAssignmentType.additional,
                    child: Text('مادة إضافية'),
                  ),
                  DropdownMenuItem(
                    value: SubjectAssignmentType.emergency,
                    child: Text('مادة طارئة'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => selectedType = v);
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _persistTeacherSubjectAssignment(
                  teacher,
                  key,
                  selectedType,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomAction(bool isReady) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isReady
                ? Colors.teal.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isReady
                ? Colors.teal.withOpacity(0.2)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReady)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'المدرسة جاهزة تماماً للجدولة',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () async {
                if (isReady) {
                  Navigator.pop(context, true);
                  return;
                }
                await _showReadinessDetails();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isReady ? Colors.teal : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: isReady ? 6 : 0,
                shadowColor: Colors.teal.withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isReady
                        ? 'اعتماد الأنصبة والبدء في الجدول'
                        : 'عرض معوقات الجدول',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isReady) ...[
                    SizedBox(width: 8.w),
                    const Icon(Icons.arrow_forward),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
