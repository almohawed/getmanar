import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../admin/data/firestore_class_repository.dart' as firestoreClasses;
import '../../academic/domain/classroom.dart';
import '../../attendance/domain/school_schedule.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule_slot.dart';
import '../../../core/domain/models/user.dart';
import '../../notifications/domain/notification_record.dart';
import '../services/schedule_cache_manager.dart';
import '../../notifications/presentation/notifications_provider.dart';

class CurrentScheduleScreen extends ConsumerStatefulWidget {
  final bool isPreview;
  final int initialTabIndex;
  final Map<String, List<ScheduleSlot>>? previewSchedule; // New Parameter

  const CurrentScheduleScreen({
    super.key,
    this.isPreview = false,
    this.initialTabIndex = 0,
    this.previewSchedule,
  });

  @override
  ConsumerState<CurrentScheduleScreen> createState() =>
      _CurrentScheduleScreenState();
}

class _CurrentScheduleScreenState extends ConsumerState<CurrentScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, String> _subjectNameById = {};
  Map<String, String> _subjectIdByAlias = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.isPreview
          ? 2
          : widget.initialTabIndex, // Use initialTabIndex
    );

    Future.microtask(() async {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;
      final data = await _loadSubjectCatalog(schoolId);
      if (!mounted) return;
      setState(() {
        _subjectNameById = data.$1;
        _subjectIdByAlias = data.$2;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _persistPreviewSchedule({
    required String schoolId,
    required Map<String, List<ScheduleSlot>> previewSchedule,
  }) async {
    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final classRepo = ref.read(firestoreClasses.classRepositoryProvider);
    final teachers = await ref.read(teachersProvider.future);
    final teacherIds = teachers.map((t) => t.id).toSet();

    final filtered = <String, List<ScheduleSlot>>{};
    for (final entry in previewSchedule.entries) {
      if (!teacherIds.contains(entry.key)) continue;
      filtered[entry.key] = entry.value;
    }

    await scheduleRepo.saveFullSchedule(schoolId, filtered);

    final classes = await classRepo.getClasses(schoolId);
    final classNameById = {for (final c in classes) c.id: c.name};
    final classIdByName = {for (final c in classes) c.name: c.id};

    final classSchedules = <String, List<ScheduleSlot>>{};
    for (final entry in filtered.entries) {
      final teacherId = entry.key;
      for (final slot in entry.value) {
        if (slot.className.isEmpty) continue;
        String targetClassId;
        String resolvedName;
        if (slot.className.startsWith('Class ')) {
          targetClassId = slot.className.substring(6);
          resolvedName = classNameById[targetClassId] ?? targetClassId;
        } else {
          resolvedName = slot.className;
          final mapped = classIdByName[resolvedName];
          if (mapped == null) continue;
          targetClassId = mapped;
        }

        classSchedules.putIfAbsent(targetClassId, () => <ScheduleSlot>[]);
        classSchedules[targetClassId]!.add(
          ScheduleSlot(
            day: slot.day,
            period: slot.period,
            className: resolvedName,
            subject: slot.subject,
            teacherId: teacherId,
          ),
        );
      }
    }

    for (final entry in classSchedules.entries) {
      await scheduleRepo.saveClassSchedule(schoolId, entry.key, entry.value);
    }

    await scheduleRepo.setActiveScheduleVariant(schoolId, 'base');
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

  Future<(Map<String, String>, Map<String, String>)> _loadSubjectCatalog(
    String schoolId,
  ) async {
    final nameById = <String, String>{};
    final aliasLookup = <String, String>{};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .get();
      final data = doc.data();
      final subjects = data?['subjects'];
      if (subjects is Map<String, dynamic>) {
        for (final entry in subjects.entries) {
          final id = entry.key.trim();
          if (id.isEmpty) continue;
          aliasLookup[_normalizeKey(id)] = id;
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final name = (value['name'] ?? id).toString().trim();
            nameById[id] = name.isEmpty ? id : name;
            if (name.isNotEmpty) {
              aliasLookup[_normalizeKey(name)] = id;
            }
            final rawAliases = value['aliases'];
            if (rawAliases is List) {
              for (final a in rawAliases) {
                if (a == null) continue;
                final s = a.toString().trim();
                if (s.isEmpty) continue;
                aliasLookup[_normalizeKey(s)] = id;
              }
            }
          } else {
            nameById[id] = id;
          }
        }
      }
    } catch (_) {}
    return (nameById, aliasLookup);
  }

  String _displaySubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;
    final id = _subjectIdByAlias[_normalizeKey(s)] ?? s;
    final name = _subjectNameById[id];
    if (name != null && name.trim().isNotEmpty) return name;
    return _localizeSubject(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.teal.shade600],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24.r),
                  bottomRight: Radius.circular(24.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isPreview ? 'الجدول المقترح' : 'عرض جدول الحصص',
                        style:
                            theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ) ??
                            TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.isPreview
                        ? 'هذه نسخة مبدئية من الجدول الذكي، يمكنك اعتمادها أو تعديلها.'
                        : 'لوحة تنفيذية لمتابعة جدول الحصص على مستوى المدرسة.',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ) ??
                        TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.sp,
                        ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentTab('حصة', 0),
                        _buildSegmentTab('يوم دراسي', 1),
                        _buildSegmentTab('الأسبوع', 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PeriodViewTab(previewSchedule: widget.previewSchedule),
                  DayViewTab(previewSchedule: widget.previewSchedule),
                  WeekViewTab(previewSchedule: widget.previewSchedule),
                ],
              ),
            ),
            if (widget.isPreview) ...[
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final user = ref.read(authStateProvider).value;
                            final schoolId = user?.schoolId ?? '';
                            if (schoolId.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'خطأ: لم يتم العثور على معرف المدرسة',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              return;
                            }
                            if (widget.previewSchedule != null) {
                              await _persistPreviewSchedule(
                                schoolId: schoolId,
                                previewSchedule: widget.previewSchedule!,
                              );
                            }
                            await ref
                                .read(scheduleRepositoryProvider)
                                .publishSchedule(schoolId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم اعتماد الجدول الذكي ونشره للمعلمين والطلاب',
                                  ),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                              Navigator.of(context).maybePop();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'حدث خطأ أثناء اعتماد الجدول: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('اعتماد الجدول'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          context.push('/smart-schedule?auto=1');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: const Text('تغيير الجدول'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.teal.shade800 : Colors.white,
                fontSize: 13.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PeriodViewTab extends ConsumerStatefulWidget {
  final Map<String, List<ScheduleSlot>>? previewSchedule;
  const PeriodViewTab({this.previewSchedule});

  @override
  ConsumerState<PeriodViewTab> createState() => _PeriodViewTabState();
}

class _PeriodViewTabState extends ConsumerState<PeriodViewTab> {
  static final Map<String, _PeriodBaseCache> _baseCacheBySchoolId = {};
  
  int _selectedPeriod = 1;
  String _selectedDay = 'الأحد';
  bool _isBootstrapping = true;
  bool _isMonitoringLoading = false;
  String? _bootstrapError;
  List<Classroom> _classesCache = [];
  Map<String, User> _teacherByIdCache = {};
  Map<String, Map<String, Map<int, _TeacherSlotInfo>>> _baseByClassId = {};
  Map<String, Map<String, dynamic>> _monitoringByClassId = {};
  List<_PeriodClassEntry> _entries = [];
  int _monitorSeq = 0;
  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  List<_WaitingCandidate>? _waitingCandidatesCache;
  String? _waitingCandidatesCacheKey;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = _calculateCurrentPeriod();
    _selectedDay = _getCurrentDayName();
    // 🔥 Set the cache reference for ScheduleCacheManager
    ScheduleCacheManager.setPeriodViewCache(_baseCacheBySchoolId);
    Future.microtask(() => _bootstrap());
  }

  int _calculateCurrentPeriod() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes < 420 + 50) return 1;
    if (minutes < 420 + 100) return 2;
    if (minutes < 420 + 150) return 3;
    if (minutes < 420 + 200) return 4;
    if (minutes < 420 + 250) return 5;
    if (minutes < 420 + 300) return 6;
    return 7;
  }

  String _getCurrentDayName() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      default:
        return 'الأحد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اليوم',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: _selectedDay,
                            isExpanded: true,
                            items: _days
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDay = val);
                                _recomputeEntries();
                                _refreshMonitoring();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رقم الحصة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<int>(
                            value: _selectedPeriod,
                            isExpanded: true,
                            items: List.generate(7, (i) => i + 1)
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text('الحصة $p'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPeriod = val);
                                _recomputeEntries();
                                _refreshMonitoring();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isMonitoringLoading) ...[
                  SizedBox(height: 10.h),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(child: _buildPeriodBody()),
        ],
      ),
    );
  }

  Widget _buildPeriodBody() {
    if (_bootstrapError != null) {
      return Center(
        child: Text(
          _bootstrapError!,
          style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_isBootstrapping) {
      return ListView.builder(
        padding: EdgeInsets.all(8.w),
        itemCount: 8,
        itemBuilder: (_, __) {
          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            height: 92.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12.r),
            ),
          );
        },
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'لم يتم إنشاء جدول حتى الآن',
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'يمكنك إنشاء جدول جديد من صفحة إدارة الجدول المدرسي',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final totalClasses = _entries.length;
    final uniqueTeachers = _entries
        .map((e) => e.displayTeacherId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final vacantCount = _entries.where((row) => row.isVacant).length;
    const conflictsCount = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodSummaryBar(
          classesCount: totalClasses,
          teachersCount: uniqueTeachers.length,
          vacantCount: vacantCount,
          conflictsCount: conflictsCount,
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return _FieldTrackingClassCard(
                entry: entry,
                onWhatsApp: () => _openWhatsApp(entry),
                onPresent: () =>
                    _setAttendanceStatus(entry, AttendanceStatus.present),
                onLate: () =>
                    _setAttendanceStatus(entry, AttendanceStatus.late),
                onAbsent: () =>
                    _setAttendanceStatus(entry, AttendanceStatus.absent),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _bootstrap() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
          _entries = [];
        });
      }
      return;
    }

    final cached = _baseCacheBySchoolId[schoolId];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(hours: 6)) {
      if (mounted) {
        setState(() {
          _classesCache = cached.classes;
          _teacherByIdCache = cached.teacherById;
          _baseByClassId = cached.baseByClassId;
          _isBootstrapping = false;
          _bootstrapError = null;
        });
      }
      _recomputeEntries();
      _refreshMonitoring();
      return;
    }

    try {
      final classRepo = ref.read(firestoreClasses.classRepositoryProvider);
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);

      final results = await Future.wait([
        classRepo.getClasses(schoolId),
        () async {
          try {
            return await teacherRepo.getTeachers(schoolId: schoolId);
          } catch (_) {
            final fallback = ref.read(mockTeacherRepositoryProvider);
            return await fallback.getTeachers(schoolId: schoolId);
          }
        }(),
      ]);

      final classes = (results[0] as List<Classroom>);
      final teachers = (results[1] as List<User>);
      final teacherById = <String, User>{for (final t in teachers) t.id: t};
      final classIdByName = <String, String>{
        for (final c in classes) c.name: c.id,
      };
      final classIds = classes.map((c) => c.id).toSet();

      final teacherSchedules = await Future.wait(
        teachers.map((t) => scheduleRepo.getSchedule(schoolId, t.id)),
      );

      final baseByClassId = <String, Map<String, Map<int, _TeacherSlotInfo>>>{};
      for (int i = 0; i < teachers.length; i++) {
        final t = teachers[i];
        final slots = teacherSchedules[i];
        for (final s in slots) {
          if (s.subject.startsWith('منتظر')) continue;
          final classId = _resolveClassId(s.className, classIdByName, classIds);
          if (classId.isEmpty) continue;
          baseByClassId.putIfAbsent(classId, () => {});
          baseByClassId[classId]!.putIfAbsent(s.day, () => {});
          baseByClassId[classId]![s.day]![s.period] = _TeacherSlotInfo(
            teacherId: t.id,
            subject: _localizeSubject(s.subject),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _classesCache = classes;
        _teacherByIdCache = teacherById;
        _baseByClassId = baseByClassId;
        _isBootstrapping = false;
        _bootstrapError = null;
      });
      _baseCacheBySchoolId[schoolId] = _PeriodBaseCache(
        createdAt: DateTime.now(),
        classes: classes,
        teacherById: teacherById,
        baseByClassId: baseByClassId,
      );
      _recomputeEntries();
      _refreshMonitoring();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
        _bootstrapError = 'تعذر تحميل بيانات الحصة. حاول مرة أخرى.';
      });
    }
  }

  String _resolveClassId(
    String rawClassName,
    Map<String, String> classIdByName,
    Set<String> classIds,
  ) {
    final raw = rawClassName.trim();
    if (raw.startsWith('Class ')) {
      final id = raw.substring(6).trim();
      return classIds.contains(id) ? id : '';
    }
    if (classIds.contains(raw)) return raw;
    return classIdByName[raw] ?? '';
  }

  void _recomputeEntries() {
    if (_isBootstrapping) return;

    final day = _selectedDay;
    final period = _selectedPeriod;
    final results = <_PeriodClassEntry>[];

    for (final classroom in _classesCache) {
      final base = _baseByClassId[classroom.id]?[day]?[period];
      final rawTeacherId = base?.teacherId ?? '';
      final teacher = _teacherByIdCache[rawTeacherId];
      final teacherName = (teacher?.name ?? '').trim();
      final teacherPhone = (teacher?.phoneNumber ?? '').trim();

      final monitoring = _monitoringByClassId[classroom.id];
      final primaryStatus = _parseAttendanceStatus(
        (monitoring?['primaryStatus'] ?? '').toString(),
      );
      final standbyTeacherId = (monitoring?['standbyTeacherId'] ?? '')
          .toString();
      final standbyTeacherName = (monitoring?['standbyTeacherName'] ?? '')
          .toString();
      final standbyTeacherPhone = (monitoring?['standbyTeacherPhone'] ?? '')
          .toString();
      final standbyStatus = _parseAttendanceStatus(
        (monitoring?['standbyStatus'] ?? '').toString(),
      );

      String displayTeacherId = rawTeacherId;
      String displayTeacherName = teacherName.isEmpty
          ? 'غير محدد'
          : teacherName;
      String displayTeacherPhone = teacherPhone;
      AttendanceStatus displayStatus = primaryStatus;

      if (primaryStatus == AttendanceStatus.absent &&
          standbyTeacherId.trim().isNotEmpty) {
        displayTeacherId = standbyTeacherId;
        displayTeacherName = standbyTeacherName.isEmpty
            ? 'منتظر'
            : standbyTeacherName;
        displayTeacherPhone = standbyTeacherPhone;
        displayStatus = standbyStatus;
      }

      final subject = base?.subject.trim().isNotEmpty == true
          ? base!.subject
          : 'غير محددة';

      results.add(
        _PeriodClassEntry(
          schoolId: ref.read(authStateProvider).value?.schoolId ?? '',
          day: day,
          period: period,
          classId: classroom.id,
          className: classroom.name,
          subject: subject,
          primaryTeacherId: rawTeacherId,
          primaryTeacherName: teacherName.isEmpty ? 'غير محدد' : teacherName,
          primaryTeacherPhone: teacherPhone,
          primaryStatus: primaryStatus,
          standbyTeacherId: standbyTeacherId,
          standbyTeacherName: standbyTeacherName,
          standbyTeacherPhone: standbyTeacherPhone,
          standbyStatus: standbyStatus,
          displayTeacherId: displayTeacherId,
          displayTeacherName: base == null ? 'غير مسند' : displayTeacherName,
          displayTeacherPhone: displayTeacherPhone,
          displayStatus: displayStatus,
          isVacant: base == null,
        ),
      );
    }

    results.sort((a, b) => a.className.compareTo(b.className));
    if (!mounted) return;
    setState(() {
      _entries = results;
    });
  }

  Future<void> _refreshMonitoring() async {
    if (_isBootstrapping) return;

    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    final seq = ++_monitorSeq;
    setState(() => _isMonitoringLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('periodMonitoring')
          .where('schoolId', isEqualTo: schoolId)
          .where('dateKey', isEqualTo: _dateKeyNow())
          .where('day', isEqualTo: _selectedDay)
          .where('period', isEqualTo: _selectedPeriod)
          .get();
      if (!mounted || seq != _monitorSeq) return;

      final map = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final classId = (data['classId'] ?? '').toString();
        if (classId.isEmpty) continue;
        map[classId] = data;
      }
      setState(() {
        _monitoringByClassId = map;
        _isMonitoringLoading = false;
      });
      _recomputeEntries();
    } catch (_) {
      if (!mounted || seq != _monitorSeq) return;
      setState(() => _isMonitoringLoading = false);
    }
  }

  Widget _buildPeriodTable() {
    return FutureBuilder(
      future: _fetchPeriodEntries(_selectedDay, _selectedPeriod),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            padding: EdgeInsets.all(8.w),
            itemCount: 4,
            itemBuilder: (_, __) {
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                height: 64.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              );
            },
          );
        }

        final data = snapshot.data as List<_PeriodClassEntry>;

        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64.sp,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'لم يتم إنشاء جدول حتى الآن',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'يمكنك إنشاء جدول جديد من صفحة إدارة الجدول المدرسي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        final totalClasses = data.length;
        final uniqueTeachers = data
            .map((e) => e.displayTeacherId)
            .where((id) => id.trim().isNotEmpty)
            .toSet();
        final vacantCount = data.where((row) => row.isVacant).length;
        const conflictsCount = 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodSummaryBar(
              classesCount: totalClasses,
              teachersCount: uniqueTeachers.length,
              vacantCount: vacantCount,
              conflictsCount: conflictsCount,
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final entry = data[index];
                  return _FieldTrackingClassCard(
                    entry: entry,
                    onWhatsApp: () => _openWhatsApp(entry),
                    onPresent: () =>
                        _setAttendanceStatus(entry, AttendanceStatus.present),
                    onLate: () =>
                        _setAttendanceStatus(entry, AttendanceStatus.late),
                    onAbsent: () =>
                        _setAttendanceStatus(entry, AttendanceStatus.absent),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _dateKeyNow() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<List<_PeriodClassEntry>> _fetchPeriodEntries(
    String day,
    int period,
  ) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return [];

    final classRepo = ref.read(firestoreClasses.classRepositoryProvider);
    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);

    final classes = await classRepo.getClasses(schoolId);
    List<User> teachers;
    try {
      teachers = await teacherRepo.getTeachers(schoolId: schoolId);
    } catch (_) {
      final fallback = ref.read(mockTeacherRepositoryProvider);
      teachers = await fallback.getTeachers(schoolId: schoolId);
    }
    final teacherById = <String, User>{for (final t in teachers) t.id: t};

    final monitoringSnap = await FirebaseFirestore.instance
        .collection('periodMonitoring')
        .where('schoolId', isEqualTo: schoolId)
        .where('dateKey', isEqualTo: _dateKeyNow())
        .where('day', isEqualTo: day)
        .where('period', isEqualTo: period)
        .get();

    final monitoringByClassId = <String, Map<String, dynamic>>{};
    for (final doc in monitoringSnap.docs) {
      final data = doc.data();
      final classId = (data['classId'] ?? '').toString();
      if (classId.isEmpty) continue;
      monitoringByClassId[classId] = data;
    }

    final classIdByName = <String, String>{
      for (final c in classes) c.name: c.id,
    };
    final teacherIdByClassId = <String, String>{};
    for (final t in teachers) {
      final slots = await scheduleRepo.getSchedule(schoolId, t.id);
      for (final s in slots) {
        if (s.day != day || s.period != period) continue;
        if (s.subject.startsWith('منتظر')) continue;
        String classId = '';
        final raw = s.className.trim();
        if (raw.startsWith('Class ')) {
          classId = raw.substring(6).trim();
        } else if (classIdByName.containsKey(raw)) {
          classId = classIdByName[raw]!;
        } else if (classes.any((c) => c.id == raw)) {
          classId = raw;
        }
        if (classId.isNotEmpty) {
          teacherIdByClassId[classId] = t.id;
        }
      }
    }

    final results = <_PeriodClassEntry>[];

    for (final classroom in classes) {
      ScheduleSlot? slot;

      if (widget.previewSchedule != null) {
        final classKeyId = 'Class ${classroom.id}';
        final classKeyName = classroom.name;
        for (final entry in widget.previewSchedule!.entries) {
          for (final s in entry.value) {
            if (s.day != day || s.period != period) continue;
            if (s.className == classKeyId ||
                s.className == classKeyName ||
                s.className == classroom.id) {
              slot = ScheduleSlot(
                day: day,
                period: period,
                className: classroom.name,
                subject: s.subject,
                teacherId: entry.key,
              );
              break;
            }
          }
          if (slot != null) break;
        }
      } else {
        var slots = await scheduleRepo.getClassSchedule(schoolId, classroom.id);
        if (slots.isEmpty) {
          slots = await scheduleRepo.getClassSchedule(schoolId, classroom.name);
        }
        slot = slots.firstWhere(
          (s) => s.day == day && s.period == period,
          orElse: () => ScheduleSlot(
            day: day,
            period: period,
            className: classroom.name,
            subject: '',
            teacherId: '',
          ),
        );
      }

      final rawSubject = (slot?.subject ?? '').trim();
      final subject = rawSubject.isEmpty
          ? 'غير محددة'
          : _localizeSubject(rawSubject);
      var teacherId = (slot?.teacherId ?? '').trim();
      if (teacherId.isEmpty && rawSubject.isNotEmpty) {
        teacherId = (teacherIdByClassId[classroom.id] ?? '').trim();
      }
      final teacher = teacherById[teacherId];
      final teacherName = (teacher?.name ?? '').trim();
      final teacherPhone = (teacher?.phoneNumber ?? '').trim();

      final monitoring = monitoringByClassId[classroom.id];
      final primaryStatus = _parseAttendanceStatus(
        (monitoring?['primaryStatus'] ?? '').toString(),
      );
      final standbyTeacherId = (monitoring?['standbyTeacherId'] ?? '')
          .toString();
      final standbyTeacherName = (monitoring?['standbyTeacherName'] ?? '')
          .toString();
      final standbyTeacherPhone = (monitoring?['standbyTeacherPhone'] ?? '')
          .toString();
      final standbyStatus = _parseAttendanceStatus(
        (monitoring?['standbyStatus'] ?? '').toString(),
      );

      String displayTeacherId = teacherId;
      String displayTeacherName = teacherName.isEmpty
          ? 'غير محدد'
          : teacherName;
      String displayTeacherPhone = teacherPhone;
      AttendanceStatus displayStatus = primaryStatus;

      if (primaryStatus == AttendanceStatus.absent) {
        if (standbyTeacherId.isNotEmpty) {
          displayTeacherId = standbyTeacherId;
          displayTeacherName = standbyTeacherName.isEmpty
              ? 'منتظر'
              : standbyTeacherName;
          displayTeacherPhone = standbyTeacherPhone;
          displayStatus = standbyStatus;
        } else {
          displayTeacherId = '';
          displayTeacherName = 'منتظر';
          displayTeacherPhone = '';
          displayStatus = AttendanceStatus.pending;
        }
      }

      results.add(
        _PeriodClassEntry(
          schoolId: schoolId,
          day: day,
          period: period,
          classId: classroom.id,
          className: classroom.name,
          subject: subject,
          primaryTeacherId: teacherId,
          primaryTeacherName: teacherName.isEmpty ? 'غير محدد' : teacherName,
          primaryTeacherPhone: teacherPhone,
          primaryStatus: primaryStatus,
          standbyTeacherId: standbyTeacherId,
          standbyTeacherName: standbyTeacherName,
          standbyTeacherPhone: standbyTeacherPhone,
          standbyStatus: standbyStatus,
          displayTeacherId: displayTeacherId,
          displayTeacherName: displayTeacherName,
          displayTeacherPhone: displayTeacherPhone,
          displayStatus: displayStatus,
          isVacant: rawSubject.isEmpty || teacherId.trim().isEmpty,
        ),
      );
    }

    results.sort((a, b) => a.className.compareTo(b.className));
    return results;
  }

  AttendanceStatus _parseAttendanceStatus(String raw) {
    final v = raw.trim();
    return AttendanceStatus.values.firstWhere(
      (s) => s.name == v,
      orElse: () => AttendanceStatus.pending,
    );
  }

  Future<List<_WaitingCandidate>> _getWaitingCandidates({
    required String schoolId,
    required String day,
    required int period,
    required List<User> teachers,
    required ScheduleRepository scheduleRepo,
  }) async {
    final key = '$schoolId|$day|$period';
    if (_waitingCandidatesCacheKey == key && _waitingCandidatesCache != null) {
      return _waitingCandidatesCache!;
    }

    final candidates = <_WaitingCandidate>[];
    final teacherById = <String, User>{for (final t in teachers) t.id: t};

    if (widget.previewSchedule != null) {
      for (final entry in widget.previewSchedule!.entries) {
        final tid = entry.key;
        final t = teacherById[tid];
        for (final s in entry.value) {
          if (s.day != day || s.period != period) continue;
          if (!s.subject.startsWith('منتظر')) continue;
          candidates.add(
            _WaitingCandidate(
              teacherId: tid,
              teacherName: (t?.name ?? tid).toString(),
              teacherPhone: (t?.phoneNumber ?? '').toString(),
              level: _parseWaitingLevel(s.subject),
            ),
          );
          break;
        }
      }
    } else {
      for (final t in teachers) {
        final slots = await scheduleRepo.getSchedule(schoolId, t.id);
        final match = slots.firstWhere(
          (s) =>
              s.day == day &&
              s.period == period &&
              s.subject.startsWith('منتظر'),
          orElse: () => ScheduleSlot(
            day: '',
            period: -1,
            className: '',
            subject: '',
            teacherId: '',
          ),
        );
        if (match.period == -1) continue;
        candidates.add(
          _WaitingCandidate(
            teacherId: t.id,
            teacherName: t.name,
            teacherPhone: t.phoneNumber ?? '',
            level: _parseWaitingLevel(match.subject),
          ),
        );
      }
    }

    candidates.sort((a, b) {
      if (a.level != b.level) return a.level.compareTo(b.level);
      return a.teacherName.compareTo(b.teacherName);
    });

    _waitingCandidatesCacheKey = key;
    _waitingCandidatesCache = candidates;
    return candidates;
  }

  int _parseWaitingLevel(String subject) {
    if (subject.contains('أول')) return 1;
    if (subject.contains('ثاني')) return 2;
    if (subject.contains('ثالث')) return 3;
    if (subject.contains('رابع')) return 4;
    if (subject.contains('خامس')) return 5;
    final digits = RegExp(r'\d+').firstMatch(subject)?.group(0);
    final parsed = int.tryParse(digits ?? '');
    return parsed ?? 1;
  }

  String _sanitizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) {
      return digits.substring(2);
    }
    if (digits.startsWith('0') &&
        digits.length == 10 &&
        digits.startsWith('05')) {
      return '966${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _openWhatsApp(_PeriodClassEntry entry) async {
    final phone = _sanitizePhone(entry.displayTeacherPhone);
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد رقم واتساب مسجل لهذا المعلم')),
        );
      }
      return;
    }

    final msg =
        'أنت لديك حصة الآن في الفصل ${entry.className} الرجاء التوجه فوراً';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  Future<void> _setAttendanceStatus(
    _PeriodClassEntry entry,
    AttendanceStatus status,
  ) async {
    if (entry.isVacant) return;

    final user = ref.read(authStateProvider).value;
    final actorId = user?.id ?? '';
    final dateKey = _dateKeyNow();

    final docId = _monitoringDocId(
      entry.schoolId,
      dateKey,
      entry.day,
      entry.period,
      entry.classId,
    );

    final docRef = FirebaseFirestore.instance
        .collection('periodMonitoring')
        .doc(docId);

    final base = <String, dynamic>{
      'id': docId,
      'schoolId': entry.schoolId,
      'dateKey': dateKey,
      'day': entry.day,
      'period': entry.period,
      'classId': entry.classId,
      'className': entry.className,
      'subject': entry.subject,
      'primaryTeacherId': entry.primaryTeacherId,
      'primaryTeacherName': entry.primaryTeacherName,
      'primaryTeacherPhone': entry.primaryTeacherPhone,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    };

    final update = <String, dynamic>{...base};

    if (entry.primaryStatus != AttendanceStatus.absent) {
      update['primaryStatus'] = status.name;
      if (status == AttendanceStatus.absent) {
        final standby = await _pickStandbyTeacher(
          entry: entry,
          dateKey: dateKey,
        );
        if (standby != null) {
          update['standbyTeacherId'] = standby.teacherId;
          update['standbyTeacherName'] = standby.teacherName;
          update['standbyTeacherPhone'] = standby.teacherPhone;
          update['standbyStatus'] = AttendanceStatus.pending.name;
        }
      } else {
        update['standbyTeacherId'] = FieldValue.delete();
        update['standbyTeacherName'] = FieldValue.delete();
        update['standbyTeacherPhone'] = FieldValue.delete();
        update['standbyStatus'] = FieldValue.delete();
      }
    } else {
      if (entry.standbyTeacherId.trim().isNotEmpty) {
        update['standbyTeacherId'] = entry.standbyTeacherId;
        update['standbyTeacherName'] = entry.standbyTeacherName;
        update['standbyTeacherPhone'] = entry.standbyTeacherPhone;
        update['standbyStatus'] = status.name;
      } else {
        update['primaryStatus'] = status.name;
      }
    }

    final scheduleDocId = _schoolScheduleDocId(
      entry.schoolId,
      entry.day,
      entry.period,
      entry.classId,
    );
    final scheduleRef = FirebaseFirestore.instance
        .collection('schoolSchedules')
        .doc(scheduleDocId);

    final actingOnStandby =
        entry.primaryStatus == AttendanceStatus.absent &&
        entry.standbyTeacherId.trim().isNotEmpty;
    final scheduleTeacherId = actingOnStandby
        ? entry.standbyTeacherId
        : entry.primaryTeacherId;

    final scheduleData = <String, dynamic>{
      'schoolId': entry.schoolId,
      'day': entry.day,
      'period': entry.period,
      'teacherId': scheduleTeacherId,
      'subject': entry.subject,
      'className': entry.className,
      'classId': entry.classId,
      'attendanceStatus': status.name,
      'attendanceTimestamp': FieldValue.serverTimestamp(),
      'recordedBy': actorId,
    };

    if (entry.primaryStatus == AttendanceStatus.absent ||
        status == AttendanceStatus.absent) {
      scheduleData['originalTeacherId'] = entry.primaryTeacherId;
      scheduleData['originalTeacherName'] = entry.primaryTeacherName;
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, update, SetOptions(merge: true));
    batch.set(scheduleRef, scheduleData, SetOptions(merge: true));
    await batch.commit();

    if (!mounted) return;

    final standbyId = update['standbyTeacherId'] is String
        ? update['standbyTeacherId']
        : '';
    final standbyName = update['standbyTeacherName'] is String
        ? update['standbyTeacherName']
        : '';
    final standbyPhone = update['standbyTeacherPhone'] is String
        ? update['standbyTeacherPhone']
        : '';
    final standbyStatus = update['standbyStatus'] is String
        ? update['standbyStatus']
        : '';

    final next = <String, dynamic>{
      'classId': entry.classId,
      'primaryStatus': (update['primaryStatus'] ?? entry.primaryStatus.name)
          .toString(),
      'standbyTeacherId': standbyId.toString(),
      'standbyTeacherName': standbyName.toString(),
      'standbyTeacherPhone': standbyPhone.toString(),
      'standbyStatus': standbyStatus.toString(),
    };

    if (next['standbyTeacherId'].toString().trim().isEmpty) {
      next.remove('standbyTeacherId');
      next.remove('standbyTeacherName');
      next.remove('standbyTeacherPhone');
      next.remove('standbyStatus');
    }

    setState(() {
      _monitoringByClassId = {..._monitoringByClassId, entry.classId: next};
    });
    _recomputeEntries();
  }

  String _schoolScheduleDocId(
    String schoolId,
    String day,
    int period,
    String classId,
  ) {
    final raw = '$schoolId|$day|$period|$classId';
    return raw.replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF]+'), '_');
  }

  String _monitoringDocId(
    String schoolId,
    String dateKey,
    String day,
    int period,
    String classId,
  ) {
    final raw = '$schoolId|$dateKey|$day|$period|$classId';
    return raw.replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF]+'), '_');
  }

  Future<_WaitingCandidate?> _pickStandbyTeacher({
    required _PeriodClassEntry entry,
    required String dateKey,
  }) async {
    final monitoringSnap = await FirebaseFirestore.instance
        .collection('periodMonitoring')
        .where('schoolId', isEqualTo: entry.schoolId)
        .where('dateKey', isEqualTo: dateKey)
        .where('day', isEqualTo: entry.day)
        .where('period', isEqualTo: entry.period)
        .get();
    final used = <String>{};
    for (final doc in monitoringSnap.docs) {
      final data = doc.data();
      final id = (data['standbyTeacherId'] ?? '').toString();
      if (id.isNotEmpty) used.add(id);
    }

    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
    List<User> teachers;
    try {
      teachers = await teacherRepo.getTeachers(schoolId: entry.schoolId);
    } catch (_) {
      final fallback = ref.read(mockTeacherRepositoryProvider);
      teachers = await fallback.getTeachers(schoolId: entry.schoolId);
    }
    final candidates = await _getWaitingCandidates(
      schoolId: entry.schoolId,
      day: entry.day,
      period: entry.period,
      teachers: teachers,
      scheduleRepo: scheduleRepo,
    );

    for (final c in candidates) {
      if (c.teacherId == entry.primaryTeacherId) continue;
      if (used.contains(c.teacherId)) continue;
      return c;
    }
    return null;
  }

  Future<void> _sendTeacherReminder(
    WidgetRef ref,
    String teacherId,
    String teacherName,
    String className,
    String subject,
  ) async {
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن إرسال الإشعار لعدم وجود معلم مرتبط بهذه الحصة',
          ),
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (user == null || schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إرسال الإشعار بدون بيانات المدرسة'),
        ),
      );
      return;
    }

    try {
      final repo = ref.read(notificationRepositoryProvider);
      final notification = NotificationRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'تذكير بالحصة الدراسية',
        body:
            'أستاذ/أستاذة $teacherName\n\nنذكّرك بلطف بأن لديك الآن حصة مادة $subject في فصل $className لليوم $_selectedDay (الحصة $_selectedPeriod).\nنشكر لك حرصك وتعاونك التربوي.',
        timestamp: DateTime.now(),
        isRead: false,
        schoolId: schoolId,
        userId: teacherId,
        targetRole: 'teacher',
        data: {
          'type': 'schedule_reminder',
          'day': _selectedDay,
          'period': _selectedPeriod.toString(),
          'className': className,
          'subject': subject,
          'senderId': user.id,
          'senderName': user.name,
        },
      );

      await repo.sendNotification(notification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال إشعار للمعلم بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الإشعار: $e')));
      }
    }
  }

  Future<List<Map<String, String>>> _fetchSessionDetails(
    WidgetRef ref,
    String day,
    int period,
  ) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return [];

    final repo = ref.read(scheduleRepositoryProvider);
    final teacherRepo = ref.read(mockTeacherRepositoryProvider);
    final results = <Map<String, String>>[];

    final teacherLookup = <String, String>{};
    final teacherIdLookup = <String, String>{};

    final teachers = await teacherRepo.getTeachers(schoolId: schoolId);

    // Use Preview Schedule if available
    if (widget.previewSchedule != null) {
      widget.previewSchedule!.forEach((teacherId, slots) {
        final teacher = teachers.firstWhere(
          (t) => t.id == teacherId,
          orElse: () => User(
            id: teacherId,
            name: 'Unknown',
            role: UserRole.teacher,
            email: '',
          ),
        );
        for (final slot in slots) {
          if (slot.day == day && slot.period == period) {
            // If className starts with 'Class ', strip it for lookup if needed, but here we store as is
            // Actually we need to match what we do below.
            // In generateSchedule, className is usually 'Class ID' or 'Name'.
            // Let's normalize it to Name if possible.
            // We need class lookup first.
            // But wait, the key in teacherLookup is className.

            // For Preview, we might have Class ID in slot.className (e.g. "Class uuid")
            // We need to resolve it to Name.
            teacherLookup[slot.className] = teacher.name;
            teacherIdLookup[slot.className] = teacher.id;
          }
        }
      });
    } else {
      for (final teacher in teachers) {
        final slots = await repo.getSchedule(schoolId, teacher.id);
        for (final slot in slots) {
          if (slot.day == day && slot.period == period) {
            teacherLookup[slot.className] = teacher.name;
            teacherIdLookup[slot.className] = teacher.id;
          }
        }
      }
    }

    final classRepo = ref.read(firestoreClasses.classRepositoryProvider);
    final classes = await classRepo.getClasses(schoolId);
    final classIdMap = {for (final c in classes) c.id: c.name};

    for (final classroom in classes) {
      ScheduleSlot slot;

      if (widget.previewSchedule != null) {
        // Search in preview schedule
        // We have to iterate all teachers to find who teaches this class at this time?
        // Or simpler: We built teacherLookup using slot.className.
        // But slot.className in preview might be 'Class ID'.
        // So we need to check both 'Class ID' and 'Name'.

        // Let's try to find the slot directly from the preview data structure if possible.
        // Actually, `teacherLookup` is keyed by `slot.className`.
        // If `slot.className` is "Class <ID>", we need to lookup using that key.

        final classKeyId = 'Class ${classroom.id}';
        final classKeyName = classroom.name;

        // We need to find the subject too.
        // Iterate all teachers in preview to find the slot for this class/time
        String foundSubject = '';
        String foundTeacherId = '';
        String foundTeacherName = 'غير محدد';

        for (final entry in widget.previewSchedule!.entries) {
          final tId = entry.key;
          final tSlots = entry.value;
          for (final s in tSlots) {
            if (s.day == day && s.period == period) {
              if (s.className == classKeyId ||
                  s.className == classKeyName ||
                  s.className == classroom.id) {
                foundSubject = s.subject;
                foundTeacherId = tId;
                // Find teacher name
                final t = teachers.firstWhere(
                  (u) => u.id == tId,
                  orElse: () => User(
                    id: tId,
                    name: 'Unknown',
                    role: UserRole.teacher,
                    email: '',
                  ),
                );
                foundTeacherName = t.name;
                break;
              }
            }
          }
          if (foundSubject.isNotEmpty) break;
        }

        if (foundSubject.isNotEmpty) {
          slot = ScheduleSlot(
            day: day,
            period: period,
            className: classroom.name,
            subject: foundSubject,
            teacherId: foundTeacherId,
          );
          // Manually populate lookup for result construction below if needed, or just use variables
          // The code below uses `slot` and `teacherLookup`.
          // Let's mock `teacherLookup` or just construct result directly.

          results.add({
            'class': classroom.name,
            'subject': foundSubject,
            'teacher': foundTeacherName,
            'teacherId': foundTeacherId,
            'isVacant': 'false',
          });
          continue; // Skip standard logic
        } else {
          // Vacant
          results.add({
            'class': classroom.name,
            'subject': 'غير محددة',
            'teacher': 'غير مسند',
            'teacherId': '',
            'isVacant': 'true',
          });
          continue;
        }
      } else {
        var slots = await repo.getClassSchedule(schoolId, classroom.id);
        if (slots.isEmpty) {
          slots = await repo.getClassSchedule(schoolId, classroom.name);
        }
        slot = slots.firstWhere(
          (s) => s.day == day && s.period == period,
          orElse: () => ScheduleSlot(
            day: day,
            period: period,
            className: '',
            subject: '',
          ),
        );
      }

      final hasSubject = slot.subject.isNotEmpty;
      final teacherName = hasSubject
          ? (teacherLookup[classroom.name] ?? 'غير محدد')
          : 'غير مسند';
      final teacherId = hasSubject
          ? (teacherIdLookup[classroom.name] ?? '')
          : '';

      results.add({
        'class': classroom.name,
        'subject': hasSubject ? slot.subject : 'غير محددة',
        'teacher': teacherName,
        'teacherId': teacherId,
        'isVacant': hasSubject ? 'false' : 'true',
      });
    }

    // Sort by class name for better readability
    results.sort((a, b) => a['class']!.compareTo(b['class']!));

    return results;
  }
}

class DayViewTab extends ConsumerStatefulWidget {
  final Map<String, List<ScheduleSlot>>? previewSchedule;
  const DayViewTab({this.previewSchedule});

  @override
  ConsumerState<DayViewTab> createState() => _DayViewTabState();
}

class _DayViewTabState extends ConsumerState<DayViewTab> {
  String _selectedDay = 'الأحد';

  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  List<Classroom> _classes = [];
  bool _isLoading = true;
  List<_DayScheduleRow> _rows = [];
  final ScrollController _dayHorizontalController = ScrollController();
  Map<String, User> _teacherById = {};
  Map<String, Map<String, Map<int, _TeacherSlotInfo>>> _baseByClassId = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _bootstrapBase());
  }

  @override
  void dispose() {
    _dayHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapBase() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (mounted) {
        setState(() {
          _classes = [];
          _rows = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.previewSchedule == null) {
        final cached = _PeriodViewTabState._baseCacheBySchoolId[schoolId];
        if (cached != null &&
            DateTime.now().difference(cached.createdAt) <
                const Duration(hours: 6)) {
          if (!mounted) return;
          setState(() {
            _classes = cached.classes;
            _teacherById = cached.teacherById;
            _baseByClassId = cached.baseByClassId;
            _isLoading = false;
          });
          _recomputeRows();
          return;
        }
      }

      final classRepo = ref.read(firestoreClasses.classRepositoryProvider);
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);

      final results = await Future.wait([
        classRepo.getClasses(schoolId),
        () async {
          try {
            return await teacherRepo.getTeachers(schoolId: schoolId);
          } catch (_) {
            final fallback = ref.read(mockTeacherRepositoryProvider);
            return await fallback.getTeachers(schoolId: schoolId);
          }
        }(),
      ]);

      final classes = (results[0] as List<Classroom>);
      final teachers = (results[1] as List<User>);
      final teacherById = <String, User>{for (final t in teachers) t.id: t};
      final classIdByName = <String, String>{
        for (final c in classes) c.name: c.id,
      };
      final classIds = classes.map((c) => c.id).toSet();

      final baseByClassId = <String, Map<String, Map<int, _TeacherSlotInfo>>>{};

      if (widget.previewSchedule != null) {
        widget.previewSchedule!.forEach((teacherId, slots) {
          for (final s in slots) {
            if (s.subject.startsWith('منتظر')) continue;
            final classId = _resolveClassId(
              s.className,
              classIdByName,
              classIds,
            );
            if (classId.isEmpty) continue;
            baseByClassId.putIfAbsent(classId, () => {});
            baseByClassId[classId]!.putIfAbsent(s.day, () => {});
            baseByClassId[classId]![s.day]![s.period] = _TeacherSlotInfo(
              teacherId: teacherId,
              subject: _localizeSubject(s.subject),
            );
          }
        });
      } else {
        final teacherSchedules = await Future.wait(
          teachers.map((t) => scheduleRepo.getSchedule(schoolId, t.id)),
        );
        for (int i = 0; i < teachers.length; i++) {
          final t = teachers[i];
          final slots = teacherSchedules[i];
          for (final s in slots) {
            if (s.subject.startsWith('منتظر')) continue;
            final classId = _resolveClassId(
              s.className,
              classIdByName,
              classIds,
            );
            if (classId.isEmpty) continue;
            baseByClassId.putIfAbsent(classId, () => {});
            baseByClassId[classId]!.putIfAbsent(s.day, () => {});
            baseByClassId[classId]![s.day]![s.period] = _TeacherSlotInfo(
              teacherId: t.id,
              subject: _localizeSubject(s.subject),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _teacherById = teacherById;
        _baseByClassId = baseByClassId;
        _isLoading = false;
      });

      if (widget.previewSchedule == null) {
        _PeriodViewTabState._baseCacheBySchoolId[schoolId] = _PeriodBaseCache(
          createdAt: DateTime.now(),
          classes: classes,
          teacherById: teacherById,
          baseByClassId: baseByClassId,
        );
      }

      _recomputeRows();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل تحميل اليوم الدراسي')));
    }
  }

  String _resolveClassId(
    String rawClassName,
    Map<String, String> classIdByName,
    Set<String> classIds,
  ) {
    final raw = rawClassName.trim();
    if (raw.startsWith('Class ')) {
      final id = raw.substring(6).trim();
      return classIds.contains(id) ? id : '';
    }
    if (classIds.contains(raw)) return raw;
    return classIdByName[raw] ?? '';
  }

  String _displayClassName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;
    if (s.startsWith('Class ')) {
      final id = s.substring(6).trim();
      if (id.isEmpty) return raw;
      for (final c in _classes) {
        if (c.id == id) return c.preferredLabel;
      }
      return id;
    }
    for (final c in _classes) {
      if (c.name == s || c.id == s) return c.preferredLabel;
    }
    return raw;
  }

  void _recomputeRows() {
    final rows = <_DayScheduleRow>[];
    for (final classroom in _classes) {
      final cells = <_DayCellData>[];
      for (int period = 1; period <= 7; period++) {
        final base = _baseByClassId[classroom.id]?[_selectedDay]?[period];
        final teacherId = base?.teacherId ?? '';
        final teacherName = base == null
            ? 'غير مسند'
            : ((_teacherById[teacherId]?.name ?? '').trim().isEmpty
                  ? 'غير محدد'
                  : _teacherById[teacherId]!.name);
        final subject = base?.subject.trim().isNotEmpty == true
            ? base!.subject
            : 'غير محددة';
        cells.add(
          _DayCellData(
            period: period,
            subject: base == null ? 'غير محددة' : subject,
            teacherName: teacherName,
            teacherId: teacherId,
            isVacant: base == null,
            className: classroom.name,
            day: _selectedDay,
          ),
        );
      }
      rows.add(_DayScheduleRow(className: classroom.name, cells: cells));
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      return const Center(child: Text('لا توجد فصول متاحة'));
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اليوم الدراسي',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4.h),
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDay = val;
                      });
                      _recomputeRows();
                    }
                  },
                ),
                SizedBox(height: 12.h),
                _buildDayMetrics(),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('لا توجد حصص مسجلة لهذا اليوم'))
                : _buildDayGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayMetrics() {
    int totalSlots = _rows.length * 7;
    int assigned = 0;
    int vacant = 0;

    for (final row in _rows) {
      for (final cell in row.cells) {
        if (cell.isVacant) {
          vacant++;
        } else {
          assigned++;
        }
      }
    }

    final double completion = totalSlots == 0 ? 0 : assigned / totalSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نسبة اكتمال الإسناد',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: LinearProgressIndicator(
                      value: completion,
                      minHeight: 8.h,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${(completion * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryChip(
                    label: 'عدد التعارضات',
                    value: '0',
                    color: Colors.orange.shade600,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryChip(
                    label: 'الحصص الشاغرة',
                    value: '$vacant',
                    color: Colors.red.shade400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayGrid() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final table = SingleChildScrollView(
      controller: _dayHorizontalController,
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const FixedColumnWidth(120),
            for (int i = 1; i <= 7; i++) i: const FixedColumnWidth(140),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.w),
                  child: const Text(
                    'الفصل',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (int p = 1; p <= 7; p++)
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Text(
                      'الحصة $p',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            ..._rows.map((row) {
              return TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Text(
                      _displayClassName(row.className),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ...row.cells.map(
                    (cell) => Padding(
                      padding: EdgeInsets.all(4.w),
                      child: _DayCellWidget(
                        data: cell,
                        onTap: () => _openDayCellDetails(cell),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Scrollbar(
        controller: _dayHorizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (_) => true,
        child: table,
      );
    }

    return table;
  }

  Future<void> _openDayCellDetails(_DayCellData cell) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تفاصيل الحصة',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text('اليوم: ${cell.day}'),
              Text('الحصة: ${cell.period}'),
              Text('الفصل: ${_displayClassName(cell.className)}'),
              Text('المادة: ${cell.subject}'),
              Text('المعلم: ${cell.teacherName}'),
              SizedBox(height: 16.h),
              if (!cell.isVacant && cell.teacherId.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    await _sendTeacherReminder(
                      cell.teacherId,
                      cell.teacherName,
                      _displayClassName(cell.className),
                      cell.subject,
                      cell.day,
                      cell.period,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('تنبيه حضور الحصة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendTeacherReminder(
    String teacherId,
    String teacherName,
    String className,
    String subject,
    String day,
    int period,
  ) async {
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن إرسال الإشعار لعدم وجود معلم مرتبط بهذه الحصة',
          ),
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (user == null || schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إرسال الإشعار بدون بيانات المدرسة'),
        ),
      );
      return;
    }

    try {
      final repo = ref.read(notificationRepositoryProvider);
      final notification = NotificationRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'تذكير بالحصة الدراسية',
        body:
            'أستاذ/أستاذة $teacherName\n\nنذكّرك بلطف بأن لديك حصة مادة $subject في فصل $className لليوم $day (الحصة $period).\nنشكر لك حرصك وتعاونك التربوي.',
        timestamp: DateTime.now(),
        isRead: false,
        schoolId: schoolId,
        userId: teacherId,
        targetRole: 'teacher',
        data: {
          'type': 'schedule_reminder',
          'day': day,
          'period': period.toString(),
          'className': className,
          'subject': subject,
          'senderId': user.id,
          'senderName': user.name,
        },
      );

      await repo.sendNotification(notification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال إشعار للمعلم بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الإشعار: $e')));
      }
    }
  }
}

class WeekViewTab extends ConsumerStatefulWidget {
  final Map<String, List<ScheduleSlot>>? previewSchedule;
  const WeekViewTab({this.previewSchedule});

  @override
  ConsumerState<WeekViewTab> createState() => _WeekViewTabState();
}

class _DayScheduleRow {
  final String className;
  final List<_DayCellData> cells;

  _DayScheduleRow({required this.className, required this.cells});
}

class _DayCellData {
  final int period;
  final String subject;
  final String teacherName;
  final String teacherId;
  final bool isVacant;
  final String className;
  final String day;

  _DayCellData({
    required this.period,
    required this.subject,
    required this.teacherName,
    required this.teacherId,
    required this.isVacant,
    required this.className,
    required this.day,
  });
}

String _localizeSubject(String subject) {
  final s = subject.trim().toLowerCase();
  if (s.isEmpty) return subject;

  if (s == 'general' || s == 'عام') return 'مجال عام';
  if (s == 'arabic') return 'اللغة العربية';
  if (s == 'math') return 'الرياضيات';
  if (s == 'science') return 'العلوم';
  if (s == 'islamic') return 'التربية الإسلامية';
  if (s == 'quran') return 'القرآن الكريم';
  if (s == 'english') return 'اللغة الإنجليزية';
  if (s == 'social') return 'الاجتماعيات';
  if (s == 'computer') return 'الحاسب الآلي';
  if (s == 'cs') return 'الحاسب الآلي';
  if (s == 'pe') return 'التربية البدنية';
  if (s == 'art') return 'التربية الفنية';

  return subject;
}

class _DayCellWidget extends StatelessWidget {
  final _DayCellData data;
  final VoidCallback onTap;

  const _DayCellWidget({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = data.isVacant ? Colors.grey.shade200 : Colors.white;
    final borderColor = data.isVacant
        ? Colors.red.shade200
        : Colors.grey.shade300;
    final icon = data.isVacant ? Icons.block : Icons.check_circle;
    final iconColor = data.isVacant
        ? Colors.red.shade400
        : Colors.green.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    data.subject,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              data.teacherName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummaryBar extends StatelessWidget {
  final int classesCount;
  final int teachersCount;
  final int vacantCount;
  final int conflictsCount;

  const _PeriodSummaryBar({
    required this.classesCount,
    required this.teachersCount,
    required this.vacantCount,
    required this.conflictsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            label: 'عدد الفصول',
            value: '$classesCount',
            color: Colors.blue.shade600,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _SummaryChip(
            label: 'عدد المعلمين',
            value: '$teachersCount',
            color: Colors.green.shade600,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _SummaryChip(
            label: 'الحصص الشاغرة',
            value: '$vacantCount',
            color: Colors.red.shade400,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _SummaryChip(
            label: 'التعارضات',
            value: '$conflictsCount',
            color: Colors.orange.shade600,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade800),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodClassEntry {
  final String schoolId;
  final String day;
  final int period;
  final String classId;
  final String className;
  final String subject;
  final String primaryTeacherId;
  final String primaryTeacherName;
  final String primaryTeacherPhone;
  final AttendanceStatus primaryStatus;
  final String standbyTeacherId;
  final String standbyTeacherName;
  final String standbyTeacherPhone;
  final AttendanceStatus standbyStatus;
  final String displayTeacherId;
  final String displayTeacherName;
  final String displayTeacherPhone;
  final AttendanceStatus displayStatus;
  final bool isVacant;

  const _PeriodClassEntry({
    required this.schoolId,
    required this.day,
    required this.period,
    required this.classId,
    required this.className,
    required this.subject,
    required this.primaryTeacherId,
    required this.primaryTeacherName,
    required this.primaryTeacherPhone,
    required this.primaryStatus,
    required this.standbyTeacherId,
    required this.standbyTeacherName,
    required this.standbyTeacherPhone,
    required this.standbyStatus,
    required this.displayTeacherId,
    required this.displayTeacherName,
    required this.displayTeacherPhone,
    required this.displayStatus,
    required this.isVacant,
  });
}

class _TeacherSlotInfo {
  final String teacherId;
  final String subject;

  const _TeacherSlotInfo({required this.teacherId, required this.subject});
}

class _PeriodBaseCache {
  final DateTime createdAt;
  final List<Classroom> classes;
  final Map<String, User> teacherById;
  final Map<String, Map<String, Map<int, _TeacherSlotInfo>>> baseByClassId;

  const _PeriodBaseCache({
    required this.createdAt,
    required this.classes,
    required this.teacherById,
    required this.baseByClassId,
  });
}

class _WaitingCandidate {
  final String teacherId;
  final String teacherName;
  final String teacherPhone;
  final int level;

  const _WaitingCandidate({
    required this.teacherId,
    required this.teacherName,
    required this.teacherPhone,
    required this.level,
  });
}

class _FieldTrackingClassCard extends StatelessWidget {
  final _PeriodClassEntry entry;
  final VoidCallback onWhatsApp;
  final VoidCallback onPresent;
  final VoidCallback onLate;
  final VoidCallback onAbsent;

  const _FieldTrackingClassCard({
    required this.entry,
    required this.onWhatsApp,
    required this.onPresent,
    required this.onLate,
    required this.onAbsent,
  });

  String _statusLabel(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.present => 'حاضر',
      AttendanceStatus.late => 'متأخر',
      AttendanceStatus.absent => 'غائب',
      _ => 'قيد المتابعة',
    };
  }

  Color _statusColor(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.present => const Color(0xFF16A34A),
      AttendanceStatus.late => const Color(0xFFF59E0B),
      AttendanceStatus.absent => const Color(0xFFDC2626),
      _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isStandbyView =
        entry.primaryStatus == AttendanceStatus.absent &&
        entry.standbyTeacherId.trim().isNotEmpty;

    final statusColor = _statusColor(entry.displayStatus);
    final borderColor = entry.isVacant ? const Color(0xFFFCA5A5) : statusColor;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.className,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _statusLabel(entry.displayStatus),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.subject,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D4ED8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              entry.isVacant ? 'غير مسند' : entry.displayTeacherName,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: entry.isVacant
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF111827),
              ),
            ),
            if (isStandbyView)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  'بديل عن: ${entry.primaryTeacherName}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (entry.primaryStatus == AttendanceStatus.absent &&
                entry.standbyTeacherId.trim().isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  'منتظر غير محدد بعد، اضغط غائب لتثبيت المنتظر تلقائياً',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(height: 10.h),
            Row(
              children: [
                InkWell(
                  onTap: entry.isVacant ? null : onWhatsApp,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: entry.isVacant
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF22C55E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: entry.isVacant
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF22C55E).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.chat,
                      color: entry.isVacant
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF16A34A),
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44.h,
                          child: ElevatedButton(
                            onPressed: entry.isVacant ? null : onPresent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'حاضر',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: SizedBox(
                          height: 44.h,
                          child: ElevatedButton(
                            onPressed: entry.isVacant ? null : onLate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'متأخر',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: SizedBox(
                          height: 44.h,
                          child: ElevatedButton(
                            onPressed: entry.isVacant ? null : onAbsent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'غائب',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodClassRowCard extends StatelessWidget {
  final String className;
  final String subject;
  final String teacherName;
  final String teacherId;
  final bool isVacant;
  final VoidCallback onNotify;

  const _PeriodClassRowCard({
    required this.className,
    required this.subject,
    required this.teacherName,
    required this.teacherId,
    required this.isVacant,
    required this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isVacant ? Colors.grey.shade100 : Colors.white;
    final borderColor = isVacant ? Colors.red.shade200 : Colors.grey.shade300;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 64.h,
            decoration: BoxDecoration(
              color: isVacant ? Colors.red.shade400 : Colors.green.shade500,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12.r),
                bottomRight: Radius.circular(12.r),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            subject,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVacant ? 'غير مسندة' : teacherName,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: isVacant
                                ? Colors.red.shade600
                                : Colors.grey.shade800,
                          ),
                        ),
                        if (isVacant)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                'غير مسندة',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'notify') {
                        onNotify();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'notify',
                        child: Text('تنبيه حضور الحصة'),
                      ),
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('عرض التفاصيل'),
                      ),
                      const PopupMenuItem(
                        value: 'history',
                        child: Text('سجل التعديلات'),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekViewTabState extends ConsumerState<WeekViewTab> {
  String? _selectedClassName; // null => all
  bool _combinedView = true;
  List<Classroom> _classes = [];
  bool _isLoadingClasses = true;
  bool _isLoadingSchedules = false;

  Map<String, List<ScheduleSlot>> _schedulesByClass = {};
  Map<String, String> _teacherNameById = {};
  Map<String, String> _subjectNameById = {};
  Map<String, String> _subjectIdByAlias = {};

  final List<String> _daysOrder = const [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  final ScrollController _weekHeaderHorizontalController = ScrollController();
  final ScrollController _weekHorizontalController = ScrollController();
  final ScrollController _weekVerticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadClasses();
  }

  @override
  void dispose() {
    _weekHeaderHorizontalController.dispose();
    _weekHorizontalController.dispose();
    _weekVerticalController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final repo = ref.read(firestoreClasses.classRepositoryProvider);
      final classes = await repo.getClasses(schoolId);
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoadingClasses = false;
        });
      }
      await _loadSchedules();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل الفصول: $e')));
      }
    }
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

  String _displaySubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;
    final id = _subjectIdByAlias[_normalizeKey(s)] ?? s;
    final name = _subjectNameById[id];
    if (name != null && name.trim().isNotEmpty) return name;
    return _localizeSubject(raw);
  }

  String _displayClassName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;
    if (s.startsWith('Class ')) {
      final id = s.substring(6).trim();
      if (id.isEmpty) return raw;
      for (final c in _classes) {
        if (c.id == id) return c.preferredLabel;
      }
      return id;
    }
    for (final c in _classes) {
      if (c.name == s || c.id == s) return c.preferredLabel;
    }
    return raw;
  }

  Future<void> _loadSubjects() async {
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;
      final nameById = <String, String>{};
      final aliasLookup = <String, String>{};
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .get();
      final data = doc.data();
      final subjects = data?['subjects'];
      if (subjects is Map<String, dynamic>) {
        for (final entry in subjects.entries) {
          final id = entry.key.trim();
          if (id.isEmpty) continue;
          aliasLookup[_normalizeKey(id)] = id;
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final name = (value['name'] ?? id).toString().trim();
            nameById[id] = name.isEmpty ? id : name;
            if (name.isNotEmpty) {
              aliasLookup[_normalizeKey(name)] = id;
            }
            final rawAliases = value['aliases'];
            if (rawAliases is List) {
              for (final a in rawAliases) {
                if (a == null) continue;
                final s = a.toString().trim();
                if (s.isEmpty) continue;
                aliasLookup[_normalizeKey(s)] = id;
              }
            }
          } else {
            nameById[id] = id;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _subjectNameById = nameById;
        _subjectIdByAlias = aliasLookup;
      });
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    // If we are in preview mode, we might not need schoolId check if we just want to show what's passed
    // But we need teachers list for names.

    if (schoolId.isEmpty && widget.previewSchedule == null) {
      if (mounted) {
        setState(() {
          _schedulesByClass = {};
          _teacherNameById = {};
        });
      }
      return;
    }

    try {
      final result = <String, List<ScheduleSlot>>{};

      final targetClasses = _selectedClassName == null
          ? _classes
          : _classes.where((c) => c.name == _selectedClassName).toList();

      if (widget.previewSchedule != null) {
        List<User> teachers;
        try {
          teachers = await ref.read(teachersProvider.future);
        } catch (_) {
          teachers = <User>[];
        }
        final teacherNameById = <String, String>{
          for (final t in teachers) t.id: t.name,
        };

        // Parse Preview Schedule
        // previewSchedule is Map<TeacherId, List<ScheduleSlot>>

        // Initialize empty lists for all target classes
        for (final cls in targetClasses) {
          result[cls.name] = [];
        }

        widget.previewSchedule!.forEach((teacherId, slots) {
          for (final slot in slots) {
            // slot.className might be "Class ID" or "Class Name"
            // We need to match it to targetClasses

            String? matchedClassName;
            if (slot.className.startsWith('Class ')) {
              final id = slot.className.substring(6);
              final cls = targetClasses.firstWhere(
                (c) => c.id == id,
                orElse: () =>
                    Classroom(id: '', name: '', gradeLevel: 0, studentIds: []),
              );
              if (cls.id.isNotEmpty) matchedClassName = cls.name;
            } else {
              // Try name match
              final cls = targetClasses.firstWhere(
                (c) => c.name == slot.className || c.id == slot.className,
                orElse: () =>
                    Classroom(id: '', name: '', gradeLevel: 0, studentIds: []),
              );
              if (cls.id.isNotEmpty) matchedClassName = cls.name;
            }

            if (matchedClassName != null) {
              result[matchedClassName]!.add(slot);
            }
          }
        });

        if (mounted) {
          setState(() {
            _teacherNameById = teacherNameById;
            _schedulesByClass = result;
            _isLoadingSchedules = false;
          });
        }
        return;
      } else {
        final cached = _PeriodViewTabState._baseCacheBySchoolId[schoolId];
        _PeriodBaseCache? base;
        if (cached != null &&
            DateTime.now().difference(cached.createdAt) <
                const Duration(hours: 6)) {
          base = cached;
        }

        if (base == null) {
          setState(() {
            _isLoadingSchedules = true;
          });
          base = await _buildWeekBaseCache(schoolId);
          _PeriodViewTabState._baseCacheBySchoolId[schoolId] = base;
        } else {
          if (mounted) {
            setState(() {
              _isLoadingSchedules = false;
            });
          }
        }

        final teacherNameById = <String, String>{
          for (final t in base.teacherById.values) t.id: t.name,
        };

        for (final classroom in targetClasses) {
          final slots = <ScheduleSlot>[];
          final byDay = base.baseByClassId[classroom.id];
          if (byDay != null) {
            byDay.forEach((day, perPeriods) {
              perPeriods.forEach((period, info) {
                slots.add(
                  ScheduleSlot(
                    day: day,
                    period: period,
                    className: 'Class ${classroom.id}',
                    subject: info.subject,
                    teacherId: info.teacherId,
                  ),
                );
              });
            });
          }
          result[classroom.name] = slots;
        }

        if (mounted) {
          setState(() {
            _teacherNameById = teacherNameById;
            _schedulesByClass = result;
            _isLoadingSchedules = false;
          });
        }
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSchedules = false;
        });
      }
    }
  }

  Future<_PeriodBaseCache> _buildWeekBaseCache(String schoolId) async {
    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);

    List<User> teachers;
    try {
      teachers = await teacherRepo.getTeachers(schoolId: schoolId);
    } catch (_) {
      final fallback = ref.read(mockTeacherRepositoryProvider);
      teachers = await fallback.getTeachers(schoolId: schoolId);
    }

    final teacherById = <String, User>{for (final t in teachers) t.id: t};
    final classIdByName = <String, String>{
      for (final c in _classes) c.name: c.id,
    };
    final classIds = _classes.map((c) => c.id).toSet();

    final teacherSchedules = await Future.wait(
      teachers.map((t) => scheduleRepo.getSchedule(schoolId, t.id)),
    );

    final baseByClassId = <String, Map<String, Map<int, _TeacherSlotInfo>>>{};
    for (int i = 0; i < teachers.length; i++) {
      final t = teachers[i];
      final slots = teacherSchedules[i];
      for (final s in slots) {
        if (s.subject.startsWith('منتظر')) continue;
        final classId = _resolveClassIdForWeek(
          s.className,
          classIdByName,
          classIds,
        );
        if (classId.isEmpty) continue;
        baseByClassId.putIfAbsent(classId, () => {});
        baseByClassId[classId]!.putIfAbsent(s.day, () => {});
        baseByClassId[classId]![s.day]![s.period] = _TeacherSlotInfo(
          teacherId: t.id,
          subject: _localizeSubject(s.subject),
        );
      }
    }

    return _PeriodBaseCache(
      createdAt: DateTime.now(),
      classes: _classes,
      teacherById: teacherById,
      baseByClassId: baseByClassId,
    );
  }

  String _resolveClassIdForWeek(
    String rawClassName,
    Map<String, String> classIdByName,
    Set<String> classIds,
  ) {
    final raw = rawClassName.trim();
    if (raw.startsWith('Class ')) {
      final id = raw.substring(6).trim();
      return classIds.contains(id) ? id : '';
    }
    if (classIds.contains(raw)) return raw;
    return classIdByName[raw] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      return const Center(child: Text('لا توجد فصول متاحة'));
    }

    final isMobile =
        MediaQuery.of(context).size.width < 600; // تخطيط خاص للجوال

    final weeklyModeCard = Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نمط العرض الأسبوعي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          RadioListTile<bool>(
            value: true,
            groupValue: _combinedView,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _combinedView = val;
                });
              }
            },
            title: const Text('عرض الجداول مدمجة (شبكة واحدة)'),
            dense: true,
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _combinedView,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _combinedView = val;
                });
              }
            },
            title: const Text('عرض الجداول مفصولة (بطاقة لكل فصل)'),
            dense: true,
          ),
        ],
      ),
    );

    final classDropdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الفصل', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: _selectedClassName,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('الكل')),
            ..._classes.map(
              (c) =>
                  DropdownMenuItem<String>(value: c.name, child: Text(c.name)),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedClassName = val;
            });
            _loadSchedules();
          },
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                weeklyModeCard,
                SizedBox(height: 12.h),
                classDropdown,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: weeklyModeCard),
                SizedBox(width: 16.w),
                Expanded(child: classDropdown),
              ],
            ),
          const Divider(),
          if (_isLoadingSchedules)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_schedulesByClass.isEmpty)
            const Expanded(child: Center(child: Text('لا توجد جداول معتمدة')))
          else
            Expanded(
              child: _combinedView
                  ? _buildCombinedWeeklyGrid()
                  : Builder(
                      builder: (context) {
                        final entries = _schedulesByClass.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        return ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: Divider(thickness: 2, color: Colors.black87),
                          ),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _buildWeeklyClassCard(
                              entry.key,
                              entry.value,
                            );
                          },
                        );
                      },
                    ),
            ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: OutlinedButton.icon(
              onPressed: _schedulesByClass.isEmpty ? null : _printSchedulesPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('طباعة الجداول PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedWeeklyGrid() {
    // Sort entries by class name
    final entries = _schedulesByClass.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final classColWidth = 80.w;
    final periodColWidth = 70.w;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scrollbar(
        controller: _weekHorizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: SingleChildScrollView(
            controller: _weekHorizontalController,
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row (Days)
                Row(
                  children: [
                    // Class Column Header
                    Container(
                      width: classColWidth,
                      height: 40.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        'الفصل',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Day Headers
                    for (final day in _daysOrder)
                      Container(
                        width: periodColWidth * 7, // Span 7 periods
                        height: 40.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                // 2. Sub-Header Row (Period Numbers)
                Row(
                  children: [
                    // Empty cell under 'Class'
                    Container(
                      width: classColWidth,
                      height: 30.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                      ),
                    ),
                    // Period Numbers 1-7 for each day
                    for (final _ in _daysOrder)
                      for (int p = 1; p <= 7; p++)
                        Container(
                          width: periodColWidth,
                          height: 30.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                  ],
                ),
                // 3. Data Rows (Classes)
                for (final entry in entries)
                  Row(
                    children: [
                      // Class Name Cell
                      Container(
                        width: classColWidth,
                        height: 50.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _displayClassName(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Schedule Data Cells
                      for (final day in _daysOrder)
                        for (int p = 1; p <= 7; p++)
                          _buildCombinedCell(
                            className: entry.key,
                            day: day,
                            period: p,
                            slots: entry.value,
                            width: periodColWidth,
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedHeaderCell(String text, double width, bool isMain) {
    return Container(
      width: width,
      height: 36.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isMain ? Colors.grey.shade300 : Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMain ? 13.sp : 12.sp,
          fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCombinedCell({
    required String className,
    required String day,
    required int period,
    required List<ScheduleSlot> slots,
    required double width,
  }) {
    // Find the slot for this specific day and period
    final slot = slots.firstWhere(
      (s) => s.day == day && s.period == period,
      orElse: () => ScheduleSlot(
        day: day,
        period: period,
        className: className,
        subject: '',
        teacherId: '',
      ),
    );

    final hasSubject = slot.subject.isNotEmpty;
    final subjectText = hasSubject ? _displaySubject(slot.subject) : 'شاغر';
    final teacherName = hasSubject
        ? (_teacherNameById[slot.teacherId] ?? 'غير محدد')
        : '';

    final cellColor = hasSubject ? Colors.white : Colors.grey.shade50;
    final textColor = hasSubject ? Colors.black87 : Colors.red.shade300;

    return Container(
      width: width,
      height: 50.h,
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            subjectText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: hasSubject ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          if (hasSubject)
            Text(
              teacherName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Future<void> _openCellFromCombined(_DayCellData cell) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        final teacherName = cell.teacherName;
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تفاصيل الحصة',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text('اليوم: ${cell.day}'),
              Text('الحصة: ${cell.period}'),
              Text('الفصل: ${_displayClassName(cell.className)}'),
              Text('المادة: ${cell.subject}'),
              Text('المعلم: $teacherName'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyClassCard(String className, List<ScheduleSlot> slots) {
    final displayClassName = _displayClassName(className);
    final byDay = <String, List<ScheduleSlot>>{};
    for (final day in _daysOrder) {
      byDay[day] = slots.where((s) => s.day == day).toList();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'جدول الفصل $displayClassName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            SizedBox(height: 12.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: const FixedColumnWidth(100),
                    for (int i = 1; i <= 7; i++) i: const FixedColumnWidth(140),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8.w),
                          child: const Text(
                            'اليوم',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (int p = 1; p <= 7; p++)
                          Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Text(
                              'الحصة $p',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    ..._daysOrder.map((day) {
                      final daySlots = byDay[day] ?? [];
                      return TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Text(day, textAlign: TextAlign.center),
                          ),
                          ...List.generate(7, (period) {
                            final slot = daySlots.firstWhere(
                              (s) => s.period == period + 1,
                              orElse: () => ScheduleSlot(
                                day: day,
                                period: period + 1,
                                className: className,
                                subject: '',
                              ),
                            );
                            final hasSubject = slot.subject.isNotEmpty;
                            final teacherName = hasSubject
                                ? (_teacherNameById[slot.teacherId] ??
                                      'غير محدد')
                                : 'غير مسند';
                            final cell = _DayCellData(
                              period: period + 1,
                              subject: hasSubject
                                  ? _displaySubject(slot.subject)
                                  : 'غير محددة',
                              teacherName: teacherName,
                              teacherId: hasSubject ? slot.teacherId : '',
                              isVacant: !hasSubject,
                              className: className,
                              day: day,
                            );
                            return Padding(
                              padding: EdgeInsets.all(4.w),
                              child: _DayCellWidget(
                                data: cell,
                                onTap: () {
                                  _openCellFromCombined(cell);
                                },
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSchedulesPdf() async {
    final baseFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document();

    // Always use landscape for the weekly view to fit all columns
    final pageFormat = PdfPageFormat.a4.landscape;

    final entries = _schedulesByClass.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (_combinedView) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(10), // Minimal margins
          build: (context) {
            return _buildCombinedWeeklyPdf(entries, baseFont, boldFont);
          },
        ),
      );
    } else {
      // Individual class view
      for (var i = 0; i < entries.length; i += 4) {
        final end = i + 4 < entries.length ? i + 4 : entries.length;
        final chunk = entries.sublist(i, end);
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
            textDirection: pw.TextDirection.rtl,
            margin: const pw.EdgeInsets.all(16),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < chunk.length; j++) ...[
                    _buildClassSchedulePdf(chunk[j].key, chunk[j].value),
                    if (j != chunk.length - 1) pw.SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  pw.Widget _buildCombinedWeeklyPdf(
    List<MapEntry<String, List<ScheduleSlot>>> entries,
    pw.Font font,
    pw.Font boldFont,
  ) {
    // 1. Define strict Flex ratios for the unified grid
    // Class Column: 2 units (Reduced from 3)
    // Period Column: 1 unit
    // Day Group: 7 units (1 * 7 periods)
    const int classFlex = 2;
    const int periodFlex = 1;
    const int dayFlex = 7 * periodFlex;

    // Helper to build a standard cell with consistent borders
    // We use a strategy of "Draw Left and Bottom borders on every cell"
    // For Period 1 (Start of Day), we add a Bold Right Border.
    pw.Widget buildCell({
      required String text,
      required int flex,
      required bool isHeader,
      required bool isBold,
      PdfColor? backgroundColor,
      double fontSize = 7,
      PdfColor textColor = PdfColors.black,
      double height = 20,
      bool isStartOfDay = false, // Flag to apply Bold Right Border
    }) {
      return pw.Expanded(
        flex: flex,
        child: pw.Container(
          height: height,
          decoration: pw.BoxDecoration(
            color:
                backgroundColor ??
                (isHeader ? PdfColors.grey200 : PdfColors.white),
            border: pw.Border(
              left: const pw.BorderSide(width: 0.5, color: PdfColors.grey600),
              bottom: const pw.BorderSide(width: 0.5, color: PdfColors.grey600),
              // Add Bold Right Border for Start of Day (Period 1)
              right: isStartOfDay
                  ? const pw.BorderSide(width: 1.5, color: PdfColors.black)
                  : pw.BorderSide.none,
            ),
          ),
          child: pw.Center(
            child: pw.Text(
              text,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: isBold ? boldFont : font,
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Build the Header Row (Complex Group)
    final headerRow = pw.Row(
      children: [
        // 2.1 Class Header (Full Height = 40)
        // This is the "Rightmost" column in RTL
        buildCell(
          text: 'الفصل',
          flex: classFlex,
          isHeader: true,
          isBold: true,
          backgroundColor: PdfColors.grey300,
          height: 40, // Spans 2 visual rows
          fontSize: 9,
          isStartOfDay: true, // Bold Right Border for the whole table start
        ),
        // 2.2 Day Groups (Day Name + Period Numbers)
        for (final day in _daysOrder)
          pw.Expanded(
            flex: dayFlex,
            child: pw.Column(
              crossAxisAlignment: pw
                  .CrossAxisAlignment
                  .stretch, // Ensure children fill the width
              children: [
                // Day Name (Top Half)
                pw.Container(
                  height: 20,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border(
                      left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                      bottom: pw.BorderSide(
                        width: 0.5,
                        color: PdfColors.grey600,
                      ),
                      // Bold Right Border for Day Start
                      right: pw.BorderSide(width: 1.5, color: PdfColors.black),
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    day,
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                // Period Numbers (Bottom Half)
                pw.Row(
                  children: List.generate(7, (index) {
                    final p = index + 1;
                    final isFirstPeriod = p == 1;
                    return buildCell(
                      text: p.toString(),
                      flex: periodFlex,
                      isHeader: true,
                      isBold: true,
                      backgroundColor: isFirstPeriod
                          ? PdfColors.grey300
                          : PdfColors.grey200,
                      height: 20,
                      isStartOfDay: isFirstPeriod,
                    );
                  }),
                ),
              ],
            ),
          ),
      ],
    );

    // 3. Build Data Rows
    final dataRows = <pw.Widget>[];
    for (final entry in entries) {
      final className = entry.key;
      final slots = entry.value;

      dataRows.add(
        pw.Row(
          children: [
            // 3.1 Class Name
            buildCell(
              text: className,
              flex: classFlex,
              isHeader: false,
              isBold: true,
              fontSize: 8,
              backgroundColor: PdfColors.white,
              isStartOfDay: true, // Bold Right Border for Class Column
            ),
            // 3.2 Day Data
            for (final day in _daysOrder)
              pw.Expanded(
                flex: dayFlex,
                child: pw.Row(
                  children: List.generate(7, (index) {
                    final p = index + 1;
                    final slot = slots.firstWhere(
                      (s) => s.day == day && s.period == p,
                      orElse: () => ScheduleSlot(
                        day: day,
                        period: p,
                        className: className,
                        subject: '',
                      ),
                    );

                    final hasSubject = slot.subject.isNotEmpty;
                    final displayText = hasSubject
                        ? _displaySubject(slot.subject)
                        : '';
                    final isFirstPeriod = p == 1;

                    // Background Logic:
                    // If Subject -> White (Standard)
                    // If First Period -> Grey100 (Faint Grey Marker)
                    // If Vacant -> FAFAFA (Very Light Grey)
                    PdfColor cellBgColor;
                    if (hasSubject) {
                      cellBgColor = PdfColors.white;
                    } else if (isFirstPeriod) {
                      cellBgColor = PdfColors.grey100;
                    } else {
                      cellBgColor = PdfColor.fromInt(0xFFFAFAFA);
                    }

                    return buildCell(
                      text: displayText,
                      flex: periodFlex,
                      isHeader: false,
                      isBold: false,
                      fontSize: 6,
                      textColor: hasSubject
                          ? PdfColors.black
                          : PdfColors.grey400,
                      backgroundColor: cellBgColor,
                      isStartOfDay: isFirstPeriod,
                    );
                  }),
                ),
              ),
          ],
        ),
      );
    }

    // 4. Wrap everything in a Container with Top and Right borders
    // to complete the grid (since cells only draw Left and Bottom).
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
          // Right border is handled by individual cells (isStartOfDay) to allow Bold lines
          // So we don't need a global right border here, or maybe just a standard one?
          // If we rely on cells, the Class Column (Rightmost) has isStartOfDay=true (Bold).
          // So we are covered.
        ),
      ),
      child: pw.Column(children: [headerRow, ...dataRows]),
    );
  }

  pw.Widget _buildClassSchedulePdf(String className, List<ScheduleSlot> slots) {
    final byDay = <String, List<ScheduleSlot>>{};
    for (final day in _daysOrder) {
      byDay[day] = slots.where((s) => s.day == day).toList();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'جدول الفصل $className',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1),
              7: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE0E0E0),
                ),
                children: [
                  _pdfHeaderCell('اليوم'),
                  for (int p = 1; p <= 7; p++) _pdfHeaderCell(p.toString()),
                ].reversed.toList(),
              ),
              for (final day in _daysOrder)
                pw.TableRow(
                  children: [
                    _pdfCell(day, isHeader: false, isBold: false),
                    for (int period = 1; period <= 7; period++)
                      () {
                        final daySlots = byDay[day] ?? [];
                        final slot = daySlots.firstWhere(
                          (s) => s.period == period,
                          orElse: () => ScheduleSlot(
                            day: day,
                            period: period,
                            className: className,
                            subject: '',
                          ),
                        );
                        return _pdfSlotCell(slot);
                      }(),
                  ].reversed.toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  pw.Widget _pdfCell(
    String text, {
    required bool isHeader,
    required bool isBold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: isHeader ? 8 : 7,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _pdfSlotCell(ScheduleSlot slot) {
    final hasSubject = slot.subject.isNotEmpty;
    final text = hasSubject ? _displaySubject(slot.subject) : 'شاغر';
    final color = hasSubject ? PdfColors.black : PdfColors.red;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 7, color: color),
          maxLines: 1,
        ),
      ),
    );
  }
}
