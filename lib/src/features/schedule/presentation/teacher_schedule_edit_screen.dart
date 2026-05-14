// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const _kDays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
const _kPeriods = [1, 2, 3, 4, 5, 6, 7];

const _kPrimary = Color(0xFF004D40);
const _kPrimaryMid = Color(0xFF00695C);
const _kPrimaryLight = Color(0xFF00796B);

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

final _teachersForEditProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final snap = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .orderBy('name')
      .get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

final _classesForEditProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final snap = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Classes')
      .orderBy('name')
      .get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

final _subjectsForEditProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final doc = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Config')
      .doc('Subjects')
      .get();
  final data = doc.data();
  final subjects = data?['subjects'];
  if (subjects is Map<String, dynamic>) {
    return subjects.entries.map((e) {
      final val = e.value;
      final name =
          val is Map ? (val['name'] ?? e.key).toString() : e.key;
      return {'id': e.key, 'name': name};
    }).toList()
      ..sort((a, b) =>
          a['name'].toString().compareTo(b['name'].toString()));
  }
  return [];
});

// ─────────────────────────────────────────────
// Schedule Notifier (plain ChangeNotifier, used locally)
// ─────────────────────────────────────────────

class _ScheduleEditNotifier extends ChangeNotifier {
  final String teacherId;
  String _schoolId = '';

  List<Map<String, dynamic>> schedule = [];
  bool isLoading = false;
  bool hasUnsavedChanges = false;
  String? error;

  _ScheduleEditNotifier(this.teacherId);

  Future<void> _load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      DocumentSnapshot? snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(_schoolId)
            .collection('TeacherSchedules')
            .doc(teacherId)
            .get();
      } catch (_) {}

      List<Map<String, dynamic>> loaded = [];
      if (snap != null && snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        final raw = data?['schedule'];
        if (raw is List) {
          loaded = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      schedule = loaded;
      isLoading = false;
      hasUnsavedChanges = false;
    } catch (e) {
      debugPrint('_ScheduleEditNotifier._load error: $e');
      error = e.toString();
      isLoading = false;
    }
    notifyListeners();
  }

  void setSchoolId(String id) {
    if (_schoolId != id) {
      _schoolId = id;
      _load();
    }
  }

  Map<String, dynamic>? getSlot(String day, int period) {
    try {
      return schedule.firstWhere(
        (s) => s['day'] == day && s['period'] == period,
      );
    } catch (_) {
      return null;
    }
  }

  void updateSlot(String day, int period, String className, String subject) {
    final updated = List<Map<String, dynamic>>.from(schedule);
    final idx = updated.indexWhere(
        (s) => s['day'] == day && s['period'] == period);
    final entry = {
      'day': day,
      'period': period,
      'className': className,
      'subject': subject,
    };
    if (idx >= 0) {
      updated[idx] = entry;
    } else {
      updated.add(entry);
    }
    schedule = updated;
    hasUnsavedChanges = true;
    notifyListeners();
  }

  void clearSlot(String day, int period) {
    schedule = List<Map<String, dynamic>>.from(schedule)
      ..removeWhere((s) => s['day'] == day && s['period'] == period);
    hasUnsavedChanges = true;
    notifyListeners();
  }

  Future<bool> save(String schoolId) async {
    isLoading = true;
    notifyListeners();
    try {
      final scheduleList = schedule;
      final batch = FirebaseFirestore.instance.batch();

      final teacherRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .doc(teacherId);

      final scheduleRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('TeacherSchedules')
          .doc(teacherId);

      batch.update(teacherRef, {'schedule': scheduleList});
      batch.set(
          scheduleRef, {'schedule': scheduleList}, SetOptions(merge: true));

      await batch.commit();
      isLoading = false;
      hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('_ScheduleEditNotifier.save error: $e');
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> reload() => _load();
}

// ─────────────────────────────────────────────
// Screen Widget
// ─────────────────────────────────────────────

class TeacherScheduleEditScreen extends ConsumerStatefulWidget {
  final String? teacherId;

  const TeacherScheduleEditScreen({super.key, this.teacherId});

  @override
  ConsumerState<TeacherScheduleEditScreen> createState() =>
      _TeacherScheduleEditScreenState();
}

class _TeacherScheduleEditScreenState
    extends ConsumerState<TeacherScheduleEditScreen> {
  String? _schoolId;
  String? _selectedTeacherId;
  bool _canEdit = false;
  late _ScheduleEditNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = _ScheduleEditNotifier(widget.teacherId ?? '');
    _notifier.addListener(() { if (mounted) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final editRoles = {
      UserRole.admin,
      UserRole.superAdmin,
      UserRole.deputy,
    };

    final teacherId = widget.teacherId ??
        (user.role == UserRole.teacher ? user.id : null);

    setState(() {
      _schoolId = user.schoolId;
      _canEdit = editRoles.contains(user.role);
      _selectedTeacherId = teacherId;
    });

    if (teacherId != null && user.schoolId != null) {
      // Recreate notifier with correct teacherId if needed
      if (_notifier.teacherId != teacherId) {
        _notifier.removeListener(() {});
        _notifier.dispose();
        _notifier = _ScheduleEditNotifier(teacherId);
        _notifier.addListener(() { if (mounted) setState(() {}); });
      }
      _notifier.setSchoolId(user.schoolId!);
    }
  }

  void _injectSchoolId(String teacherId) {
    if (_schoolId == null) return;
    // Recreate notifier for new teacher
    _notifier.removeListener(() {});
    _notifier.dispose();
    _notifier = _ScheduleEditNotifier(teacherId);
    _notifier.addListener(() { if (mounted) setState(() {}); });
    _notifier.setSchoolId(_schoolId!);
  }

  String get _effectiveTeacherId => _selectedTeacherId ?? '';

  bool get _hasValidTeacher =>
      _effectiveTeacherId.isNotEmpty && _schoolId != null;

  Future<bool> _onWillPop() async {
    if (!_hasValidTeacher) return true;
    if (!_notifier.hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'تغييرات غير محفوظة',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, color: _kPrimary),
          ),
          content: Text(
            'لديك تغييرات غير محفوظة. هل تريد المغادرة دون حفظ؟',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _kPrimaryMid)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('مغادرة',
                  style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _saveSchedule() async {
    if (!_hasValidTeacher) return;
    final success = await _notifier.save(_schoolId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✅ تم حفظ الجدول بنجاح' : '❌ فشل الحفظ، حاول مجدداً',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: success ? _kPrimary : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: _buildAppBar(),
          body: _buildBody(),
          floatingActionButton: _canEdit ? _buildFab() : null,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasUnsaved = _hasValidTeacher && _notifier.hasUnsavedChanges;

    return PreferredSize(
      preferredSize: Size.fromHeight(56.h),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimary, _kPrimaryLight],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعديل جدول المعلم',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
              if (hasUnsaved) ...[
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'غير محفوظ',
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontSize: 10.sp),
                  ),
                ),
              ],
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () async {
              if (await _onWillPop()) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (_hasValidTeacher)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'تحديث',
                onPressed: () => _notifier.reload(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_schoolId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_canEdit) _buildTeacherSelector(),
        if (_hasValidTeacher) Expanded(child: _buildScheduleTable()),
        if (!_hasValidTeacher && _canEdit)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search,
                      size: 64.r, color: Colors.grey.shade400),
                  SizedBox(height: 16.h),
                  Text(
                    'اختر معلماً لعرض جدوله',
                    style: GoogleFonts.cairo(
                        color: Colors.grey.shade500, fontSize: 16.sp),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherSelector() {
    final teachersAsync =
        ref.watch(_teachersForEditProvider(_schoolId!));

    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: teachersAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text('خطأ في تحميل المعلمين',
              style: GoogleFonts.cairo(color: Colors.red)),
        ),
        data: (teachers) => DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedTeacherId,
            hint: Text('اختر معلماً',
                style: GoogleFonts.cairo(color: Colors.grey)),
            icon: const Icon(Icons.keyboard_arrow_down, color: _kPrimaryMid),
            style: GoogleFonts.cairo(color: Colors.black87, fontSize: 15.sp),
            items: teachers.map((t) {
              return DropdownMenuItem<String>(
                value: t['id'] as String,
                child: Text(
                  t['name']?.toString() ?? t['id'].toString(),
                  style: GoogleFonts.cairo(),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _selectedTeacherId = val);
              _injectSchoolId(val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleTable() {
    if (_notifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifier.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.r, color: Colors.red),
            SizedBox(height: 12.h),
            Text(
              'حدث خطأ أثناء التحميل',
              style: GoogleFonts.cairo(color: Colors.red),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: _kPrimaryMid),
              onPressed: () => _notifier.reload(),
              child: Text('إعادة المحاولة',
                  style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // Determine today's day name
    final todayIndex = DateTime.now().weekday; // 1=Mon … 7=Sun
    // Map to Arabic day: Sunday=0, Mon=1, Tue=2, Wed=3, Thu=4
    const dayMap = {7: 0, 1: 1, 2: 2, 3: 3, 4: 4};
    final todayColIndex = dayMap[todayIndex];

    return SingleChildScrollView(
      padding: EdgeInsets.all(12.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildTable(todayColIndex),
      ),
    );
  }

  Widget _buildTable(int? todayColIndex) {
    final notifier = _notifier;

    // Header row
    final headerCells = <Widget>[
      _headerCell('الحصة \\ اليوم', isCorner: true),
      for (int d = 0; d < _kDays.length; d++)
        _headerCell(_kDays[d], isToday: d == todayColIndex),
    ];

    // Data rows
    final rows = <Widget>[];
    for (final period in _kPeriods) {
      final cells = <Widget>[
        _periodCell(period),
        for (int d = 0; d < _kDays.length; d++)
          _slotCell(
            day: _kDays[d],
            period: period,
            notifier: notifier,
            isToday: d == todayColIndex,
          ),
      ];
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: headerCells,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text,
      {bool isCorner = false, bool isToday = false}) {
    return Container(
      width: isCorner ? 70.w : 110.w,
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        gradient: isToday
            ? const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF004D40)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [_kPrimary, _kPrimaryMid],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isCorner ? 11.sp : 13.sp,
          ),
        ),
      ),
    );
  }

  Widget _periodCell(int period) {
    return Container(
      width: 70.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Center(
        child: Text(
          'ح $period',
          style: GoogleFonts.cairo(
            color: _kPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  Widget _slotCell({
    required String day,
    required int period,
    required _ScheduleEditNotifier notifier,
    bool isToday = false,
  }) {
    final slot = notifier.getSlot(day, period);
    final isEmpty = slot == null;

    return GestureDetector(
      onTap: _canEdit
          ? () => _showEditBottomSheet(
                day: day,
                period: period,
                currentSlot: slot,
                notifier: notifier,
              )
          : null,
      child: Container(
        width: 110.w,
        constraints: BoxConstraints(minHeight: 64.h),
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: isEmpty
              ? (isToday
                  ? _kPrimary.withOpacity(0.04)
                  : Colors.white)
              : (isToday
                  ? const Color(0xFF00695C)
                  : _kPrimaryLight),
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
            left: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: isEmpty
            ? _emptySlotContent(isToday)
            : _filledSlotContent(slot),
      ),
    );
  }

  Widget _emptySlotContent(bool isToday) {
    if (!_canEdit) {
      return Center(
        child: Text(
          '—',
          style: GoogleFonts.cairo(color: Colors.grey.shade400),
        ),
      );
    }
    return Center(
      child: DashedBorder(
        color: isToday ? _kPrimaryMid : Colors.grey.shade400,
        child: Icon(
          Icons.add,
          size: 20.r,
          color: isToday ? _kPrimaryMid : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _filledSlotContent(Map<String, dynamic> slot) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          slot['subject']?.toString() ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            slot['className']?.toString() ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 10.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    final isLoading = _notifier.isLoading;

    return FloatingActionButton.extended(
      onPressed: isLoading ? null : _saveSchedule,
      backgroundColor: _kPrimary,
      icon: isLoading
          ? SizedBox(
              width: 20.r,
              height: 20.r,
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.save_alt, color: Colors.white),
      label: Text(
        'حفظ الجدول كاملاً',
        style: GoogleFonts.cairo(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Edit Bottom Sheet
  // ─────────────────────────────────────────────

  void _showEditBottomSheet({
    required String day,
    required int period,
    required Map<String, dynamic>? currentSlot,
    required _ScheduleEditNotifier notifier,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: _EditSlotSheet(
          day: day,
          period: period,
          currentSlot: currentSlot,
          schoolId: _schoolId!,
          onSave: (className, subject) {
            notifier.updateSlot(day, period, className, subject);
          },
          onDelete: () {
            notifier.clearSlot(day, period);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Edit Slot Bottom Sheet
// ─────────────────────────────────────────────

class _EditSlotSheet extends ConsumerStatefulWidget {
  final String day;
  final int period;
  final Map<String, dynamic>? currentSlot;
  final String schoolId;
  final void Function(String className, String subject) onSave;
  final VoidCallback onDelete;

  const _EditSlotSheet({
    required this.day,
    required this.period,
    required this.currentSlot,
    required this.schoolId,
    required this.onSave,
    required this.onDelete,
  });

  @override
  ConsumerState<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends ConsumerState<_EditSlotSheet> {
  String? _selectedClassName;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _selectedClassName = widget.currentSlot?['className']?.toString();
    _selectedSubject = widget.currentSlot?['subject']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync =
        ref.watch(_classesForEditProvider(widget.schoolId));
    final subjectsAsync =
        ref.watch(_subjectsForEditProvider(widget.schoolId));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        top: 8.h,
        left: 20.w,
        right: 20.w,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Title
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, _kPrimaryLight],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              'تعديل الحصة ${widget.period} - ${widget.day}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Class dropdown
          Text(
            'الفصل الدراسي',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 6.h),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطأ في تحميل الفصول',
                style: GoogleFonts.cairo(color: Colors.red)),
            data: (classes) => _buildDropdown(
              hint: 'اختر الفصل',
              value: _selectedClassName,
              items: classes
                  .map((c) => c['name']?.toString() ?? c['id'].toString())
                  .toList(),
              onChanged: (val) => setState(() => _selectedClassName = val),
            ),
          ),
          SizedBox(height: 16.h),

          // Subject dropdown
          Text(
            'المادة الدراسية',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 6.h),
          subjectsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطأ في تحميل المواد',
                style: GoogleFonts.cairo(color: Colors.red)),
            data: (subjects) => _buildDropdown(
              hint: 'اختر المادة',
              value: _selectedSubject,
              items: subjects
                  .map((s) => s['name']?.toString() ?? s['id'].toString())
                  .toList(),
              onChanged: (val) => setState(() => _selectedSubject = val),
            ),
          ),
          SizedBox(height: 24.h),

          // Action buttons
          Row(
            children: [
              // Delete button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('حذف الحصة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(width: 12.w),
              // Save button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text('حفظ',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  onPressed: _canSave()
                      ? () {
                          widget.onSave(
                              _selectedClassName!, _selectedSubject!);
                          Navigator.pop(context);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave() =>
      _selectedClassName != null &&
      _selectedClassName!.isNotEmpty &&
      _selectedSubject != null &&
      _selectedSubject!.isNotEmpty;

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    // Ensure value is in items list; if not, reset to null
    final effectiveValue = (value != null && items.contains(value)) ? value : null;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10.r),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: effectiveValue,
          hint: Text(hint,
              style: GoogleFonts.cairo(color: Colors.grey.shade500)),
          icon: const Icon(Icons.keyboard_arrow_down, color: _kPrimaryMid),
          style: GoogleFonts.cairo(color: Colors.black87, fontSize: 14.sp),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: GoogleFonts.cairo()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dashed Border Helper Widget
// ─────────────────────────────────────────────

class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  const DashedBorder({
    super.key,
    required this.child,
    this.color = Colors.grey,
    this.strokeWidth = 1.5,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ));

    final dashPath = _dashPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dest.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace;
}
