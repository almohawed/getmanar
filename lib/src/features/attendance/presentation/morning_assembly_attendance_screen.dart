// ignore_for_file: use_build_context_synchronously

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kDark = Color(0xFF0D47A1);
const _kGreen = Color(0xFF2E7D32);
const _kOrange = Color(0xFFE65100);
const _kRed = Color(0xFFC62828);

// ─────────────────────────────────────────────
// Attendance Status
// ─────────────────────────────────────────────
enum _AttendanceStatus { present, absentAssembly, absentSchool }

extension _AttendanceStatusExt on _AttendanceStatus {
  String get firestoreValue {
    switch (this) {
      case _AttendanceStatus.present:
        return 'present';
      case _AttendanceStatus.absentAssembly:
        return 'absent_assembly';
      case _AttendanceStatus.absentSchool:
        return 'absent_school';
    }
  }

  static _AttendanceStatus fromString(String? s) {
    switch (s) {
      case 'present':
        return _AttendanceStatus.present;
      case 'absent_assembly':
        return _AttendanceStatus.absentAssembly;
      case 'absent_school':
        return _AttendanceStatus.absentSchool;
      default:
        return _AttendanceStatus.present;
    }
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────
final _teachersListProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final _assemblyReportProvider =
    StreamProvider.family<List<Map<String, dynamic>>, _ReportQuery>(
        (ref, query) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(query.schoolId)
      .collection('MorningAssembly')
      .where('date', isGreaterThanOrEqualTo: query.startDate)
      .where('date', isLessThanOrEqualTo: query.endDate)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => {'docId': d.id, ...d.data()}).toList());
});

// ─────────────────────────────────────────────
// Report Query Model (for provider family key)
// ─────────────────────────────────────────────
class _ReportQuery {
  final String schoolId;
  final String startDate;
  final String endDate;

  const _ReportQuery({
    required this.schoolId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      other is _ReportQuery &&
      other.schoolId == schoolId &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(schoolId, startDate, endDate);
}

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class MorningAssemblyAttendanceScreen extends ConsumerStatefulWidget {
  const MorningAssemblyAttendanceScreen({super.key});

  @override
  ConsumerState<MorningAssemblyAttendanceScreen> createState() =>
      _MorningAssemblyAttendanceScreenState();
}

class _MorningAssemblyAttendanceScreenState
    extends ConsumerState<MorningAssemblyAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _activeTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  User? get _currentUser => ref.read(authStateProvider).value;
  String get _schoolId => _currentUser?.schoolId ?? '';

  bool get _canEdit {
    final user = _currentUser;
    if (user == null) return false;
    return user.role == UserRole.admin ||
        user.role == UserRole.superAdmin ||
        user.role == UserRole.deputy;
  }

  bool get _isTeacher => _currentUser?.role == UserRole.teacher;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildTabButtons(),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _AttendanceTab(
                    schoolId: _schoolId,
                    canEdit: _canEdit,
                    isTeacher: _isTeacher,
                    currentUser: _currentUser,
                  ),
                  _ReportTab(schoolId: _schoolId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(56.h),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimary, _kDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20.r),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    'حضور الطابور الصباحي',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 40.w),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'رصد حضور الطابور',
              icon: Icons.how_to_reg_rounded,
              isActive: _activeTab == 0,
              onTap: () {
                _tabController.animateTo(0);
                setState(() => _activeTab = 0);
              },
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _TabButton(
              label: 'تقرير المعلمين',
              icon: Icons.bar_chart_rounded,
              isActive: _activeTab == 1,
              onTap: () {
                _tabController.animateTo(1);
                setState(() => _activeTab = 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab Button Widget
// ─────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive ? _kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? Colors.white : Colors.grey.shade600,
                size: 18.r),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontSize: 13.sp,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Attendance Tab
// ─────────────────────────────────────────────
class _AttendanceTab extends ConsumerStatefulWidget {
  final String schoolId;
  final bool canEdit;
  final bool isTeacher;
  final User? currentUser;

  const _AttendanceTab({
    required this.schoolId,
    required this.canEdit,
    required this.isTeacher,
    required this.currentUser,
  });

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();
  bool _listOpened = false;
  bool _saving = false;

  // teacherId -> status
  final Map<String, _AttendanceStatus> _statusMap = {};

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String get _arabicDate {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final d = _selectedDate;
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _loadExistingRecord(List<Map<String, dynamic>> teachers) async {
    if (widget.schoolId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('MorningAssembly')
          .doc(_dateKey)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final list = (data['teachers'] as List<dynamic>? ?? []);
        final newMap = <String, _AttendanceStatus>{};
        for (final item in list) {
          if (item is Map) {
            final id = item['teacherId']?.toString() ?? '';
            final status =
                _AttendanceStatusExt.fromString(item['status']?.toString());
            if (id.isNotEmpty) newMap[id] = status;
          }
        }
        if (mounted)
          setState(() => _statusMap
            ..clear()
            ..addAll(newMap));
      } else {
        // Initialize all teachers as present
        final newMap = <String, _AttendanceStatus>{};
        for (final t in teachers) {
          final id = (t['id'] ?? '').toString();
          if (id.isNotEmpty) newMap[id] = _AttendanceStatus.present;
        }
        if (mounted)
          setState(() => _statusMap
            ..clear()
            ..addAll(newMap));
      }
    } catch (e) {
      debugPrint('Error loading assembly record: $e');
    }
  }

  Future<void> _saveAttendance(List<Map<String, dynamic>> teachers) async {
    if (widget.schoolId.isEmpty || !widget.canEdit) return;
    setState(() => _saving = true);
    try {
      final user = widget.currentUser;
      final teachersList = teachers.map((t) {
        final id = (t['id'] ?? '').toString();
        final name = (t['name'] ?? '').toString();
        final status = _statusMap[id] ?? _AttendanceStatus.present;
        return {
          'teacherId': id,
          'teacherName': name,
          'status': status.firestoreValue,
        };
      }).toList();

      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('MorningAssembly')
          .doc(_dateKey)
          .set({
        'date': _dateKey,
        'schoolId': widget.schoolId,
        'recordedBy': user?.id ?? '',
        'recordedByName': user?.name ?? '',
        'teachers': teachersList,
        'savedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ حضور الطابور بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving assembly attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e', style: GoogleFonts.cairo()),
            backgroundColor: _kRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPrintDialog(List<Map<String, dynamic>> teachers) {
    showDialog(
      context: context,
      builder: (_) => _PrintDialog(
        date: _arabicDate,
        teachers: teachers,
        statusMap: Map.from(_statusMap),
      ),
    );
  }

  int get _presentCount =>
      _statusMap.values.where((s) => s == _AttendanceStatus.present).length;
  int get _absentAssemblyCount => _statusMap.values
      .where((s) => s == _AttendanceStatus.absentAssembly)
      .length;
  int get _absentSchoolCount => _statusMap.values
      .where((s) => s == _AttendanceStatus.absentSchool)
      .length;

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(_teachersListProvider(widget.schoolId));

    return Stack(
      children: [
        Column(
          children: [
            _buildDateSelector(),
            teachersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (teachers) => _buildStatsRow(teachers.length),
            ),
            if (!_listOpened) _buildOpenListButton(teachersAsync.value ?? []),
            if (_listOpened)
              Expanded(
                child: teachersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (teachers) => _buildTeacherGrid(teachers),
                ),
              ),
            if (_listOpened)
              teachersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (teachers) => _buildBottomBar(teachers),
              ),
          ],
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: _kPrimary, size: 20.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _arabicDate,
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          if (widget.canEdit)
            IconButton(
              icon: Icon(Icons.edit_calendar_rounded,
                  color: _kPrimary, size: 20.r),
              onPressed: _pickDate,
              tooltip: 'تغيير التاريخ',
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ar'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _listOpened = false;
        _statusMap.clear();
      });
    }
  }

  Widget _buildStatsRow(int total) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          _StatCard(
            label: 'حضر الطابور',
            count: _presentCount,
            color: _kGreen,
            icon: Icons.check_circle_rounded,
          ),
          SizedBox(width: 6.w),
          _StatCard(
            label: 'تغيب عن الطابور',
            count: _absentAssemblyCount,
            color: _kOrange,
            icon: Icons.warning_rounded,
          ),
          SizedBox(width: 6.w),
          _StatCard(
            label: 'غائب عن المدرسة',
            count: _absentSchoolCount,
            color: _kRed,
            icon: Icons.cancel_rounded,
          ),
          SizedBox(width: 6.w),
          _StatCard(
            label: 'إجمالي المعلمين',
            count: total,
            color: _kPrimary,
            icon: Icons.people_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOpenListButton(List<Map<String, dynamic>> teachers) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            setState(() => _listOpened = true);
            await _loadExistingRecord(teachers);
          },
          icon: Icon(Icons.list_alt_rounded, size: 20.r),
          label: Text(
            'فتح قائمة الطابور',
            style:
                GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
            elevation: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherGrid(List<Map<String, dynamic>> teachers) {
    if (teachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64.r, color: Colors.grey.shade300),
            SizedBox(height: 12.h),
            Text(
              'لا يوجد معلمون مسجلون',
              style: GoogleFonts.cairo(
                  color: Colors.grey.shade500, fontSize: 15.sp),
            ),
          ],
        ),
      );
    }

    final displayTeachers = widget.isTeacher
        ? teachers
            .where((t) => (t['id'] ?? '') == (widget.currentUser?.id ?? ''))
            .toList()
        : teachers;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth > 1100) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 550) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.8,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
          ),
          itemCount: displayTeachers.length,
          itemBuilder: (context, index) {
            final teacher = displayTeachers[index];
            final id = (teacher['id'] ?? '').toString();
            final name = (teacher['name'] ?? 'معلم').toString();
            final status = _statusMap[id] ?? _AttendanceStatus.present;
            return _TeacherCard(
              teacherId: id,
              teacherName: name,
              status: status,
              canEdit: widget.canEdit,
              onStatusChanged: (newStatus) {
                setState(() => _statusMap[id] = newStatus);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(List<Map<String, dynamic>> teachers) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showPrintDialog(teachers),
              icon: Icon(Icons.print_rounded, size: 18.r),
              label: Text('طباعة', style: GoogleFonts.cairo(fontSize: 13.sp)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          if (widget.canEdit) ...[
            SizedBox(width: 10.w),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _saveAttendance(teachers),
                icon: Icon(Icons.save_rounded, size: 18.r),
                label: Text('حفظ الحضور',
                    style: GoogleFonts.cairo(
                        fontSize: 13.sp, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stat Card Widget
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20.r),
            SizedBox(height: 4.h),
            Text(
              '$count',
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: color.withOpacity(0.85),
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Teacher Card Widget
// ─────────────────────────────────────────────
class _TeacherCard extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final _AttendanceStatus status;
  final bool canEdit;
  final ValueChanged<_AttendanceStatus> onStatusChanged;

  const _TeacherCard({
    required this.teacherId,
    required this.teacherName,
    required this.status,
    required this.canEdit,
    required this.onStatusChanged,
  });

  Color get _cardBorderColor {
    switch (status) {
      case _AttendanceStatus.present:
        return _kGreen;
      case _AttendanceStatus.absentAssembly:
        return _kOrange;
      case _AttendanceStatus.absentSchool:
        return _kRed;
    }
  }

  Color get _cardBgColor {
    switch (status) {
      case _AttendanceStatus.present:
        return _kGreen.withOpacity(0.08);
      case _AttendanceStatus.absentAssembly:
        return _kOrange.withOpacity(0.05);
      case _AttendanceStatus.absentSchool:
        return _kRed.withOpacity(0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: canEdit ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _cardBgColor,
          borderRadius: BorderRadius.circular(12.r),
          border:
              Border.all(color: _cardBorderColor.withOpacity(0.6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          child: InkWell(
            onTap: canEdit
                ? () {
                    final newStatus = status == _AttendanceStatus.present
                        ? _AttendanceStatus.absentAssembly
                        : status == _AttendanceStatus.absentAssembly
                            ? _AttendanceStatus.absentSchool
                            : _AttendanceStatus.present;
                    onStatusChanged(newStatus);
                  }
                : null,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: _cardBorderColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == _AttendanceStatus.present
                          ? Icons.check_circle
                          : status == _AttendanceStatus.absentAssembly
                              ? Icons.warning_rounded
                              : Icons.cancel_rounded,
                      color: _cardBorderColor,
                      size: 24.r,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Teacher Name
                  Text(
                    teacherName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  // Status Label
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: _cardBorderColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      status == _AttendanceStatus.present
                          ? 'حضر'
                          : status == _AttendanceStatus.absentAssembly
                              ? 'تغيب عن الطابور'
                              : 'غائب',
                      style: GoogleFonts.cairo(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: _cardBorderColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Status Button Widget
// ─────────────────────────────────────────────
class _StatusButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatusButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 0.5.w, vertical: 0.5.h),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(1.r),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 6.r,
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isSelected ? Colors.white : color,
                fontSize: 4.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Print Dialog
// ─────────────────────────────────────────────
class _PrintDialog extends StatelessWidget {
  final String date;
  final List<Map<String, dynamic>> teachers;
  final Map<String, _AttendanceStatus> statusMap;

  const _PrintDialog({
    required this.date,
    required this.teachers,
    required this.statusMap,
  });

  String _statusLabel(_AttendanceStatus s) {
    switch (s) {
      case _AttendanceStatus.present:
        return 'حضر';
      case _AttendanceStatus.absentAssembly:
        return 'تغيب عن الطابور';
      case _AttendanceStatus.absentSchool:
        return 'غائب عن المدرسة';
    }
  }

  Color _statusColor(_AttendanceStatus s) {
    switch (s) {
      case _AttendanceStatus.present:
        return _kGreen;
      case _AttendanceStatus.absentAssembly:
        return _kOrange;
      case _AttendanceStatus.absentSchool:
        return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentList = teachers
        .where((t) =>
            statusMap[(t['id'] ?? '').toString()] == _AttendanceStatus.present)
        .toList();
    final absentAssemblyList = teachers
        .where((t) =>
            statusMap[(t['id'] ?? '').toString()] ==
            _AttendanceStatus.absentAssembly)
        .toList();
    final absentSchoolList = teachers
        .where((t) =>
            statusMap[(t['id'] ?? '').toString()] ==
            _AttendanceStatus.absentSchool)
        .toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print_rounded, color: _kPrimary, size: 22.r),
            SizedBox(width: 8.w),
            Text(
              'طباعة كشف الطابور',
              style: GoogleFonts.cairo(
                  fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 340.w,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _kPrimary, size: 16.r),
                      SizedBox(width: 8.w),
                      Text(
                        date,
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PrintStat(
                        label: 'حضر',
                        count: presentList.length,
                        color: _kGreen),
                    _PrintStat(
                        label: 'تغيب طابور',
                        count: absentAssemblyList.length,
                        color: _kOrange),
                    _PrintStat(
                        label: 'غائب مدرسة',
                        count: absentSchoolList.length,
                        color: _kRed),
                  ],
                ),
                SizedBox(height: 14.h),
                // Full list
                ...teachers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final id = (t['id'] ?? '').toString();
                  final name = (t['name'] ?? '').toString();
                  final status = statusMap[id] ?? _AttendanceStatus.present;
                  return Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.grey.shade50 : Colors.white,
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade200, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24.w,
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.cairo(
                                fontSize: 12.sp, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: GoogleFonts.cairo(
                              fontSize: 10.sp,
                              color: _statusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري إرسال الكشف للطباعة...',
                      style: GoogleFonts.cairo()),
                  backgroundColor: _kPrimary,
                ),
              );
            },
            icon: Icon(Icons.print_rounded, size: 16.r),
            label: Text('طباعة', style: GoogleFonts.cairo()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PrintStat(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.cairo(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style:
              GoogleFonts.cairo(fontSize: 10.sp, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Report Tab
// ─────────────────────────────────────────────
class _ReportTab extends ConsumerStatefulWidget {
  final String schoolId;

  const _ReportTab({required this.schoolId});

  @override
  ConsumerState<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends ConsumerState<_ReportTab> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  String get _startDate => DateFormat('yyyy-MM-dd')
      .format(DateTime(_selectedYear, _selectedMonth, 1));

  String get _endDate {
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0);
    return DateFormat('yyyy-MM-dd').format(lastDay);
  }

  String get _monthLabel {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${months[_selectedMonth - 1]} $_selectedYear';
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (_) => _MonthYearPickerDialog(
        initialMonth: _selectedMonth,
        initialYear: _selectedYear,
        onConfirm: (month, year) {
          setState(() {
            _selectedMonth = month;
            _selectedYear = year;
          });
        },
      ),
    );
  }

  /// Build per-teacher summary from raw Firestore docs
  List<_TeacherReportRow> _buildReport(List<Map<String, dynamic>> docs) {
    final Map<String, _TeacherReportRow> map = {};

    for (final doc in docs) {
      final teachers = (doc['teachers'] as List<dynamic>? ?? []);
      for (final item in teachers) {
        if (item is! Map) continue;
        final id = (item['teacherId'] ?? '').toString();
        final name = (item['teacherName'] ?? '').toString();
        if (id.isEmpty) continue;

        final status =
            _AttendanceStatusExt.fromString(item['status']?.toString());

        final row = map.putIfAbsent(
          id,
          () => _TeacherReportRow(id: id, name: name),
        );

        switch (status) {
          case _AttendanceStatus.present:
            row.present++;
            break;
          case _AttendanceStatus.absentAssembly:
            row.absentAssembly++;
            break;
          case _AttendanceStatus.absentSchool:
            row.absentSchool++;
            break;
        }
        row.totalDays++;
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));
    return list;
  }

  void _showPrintReport(List<_TeacherReportRow> rows) {
    showDialog(
      context: context,
      builder: (_) => _ReportPrintDialog(
        monthLabel: _monthLabel,
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _ReportQuery(
      schoolId: widget.schoolId,
      startDate: _startDate,
      endDate: _endDate,
    );
    final reportAsync = ref.watch(_assemblyReportProvider(query));

    return Column(
      children: [
        _buildReportHeader(reportAsync.value ?? []),
        Expanded(
          child: reportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child:
                  Text('خطأ في تحميل التقرير: $e', style: GoogleFonts.cairo()),
            ),
            data: (docs) {
              final rows = _buildReport(docs);
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          size: 64.r, color: Colors.grey.shade300),
                      SizedBox(height: 12.h),
                      Text(
                        'لا توجد بيانات لهذا الشهر',
                        style: GoogleFonts.cairo(
                            color: Colors.grey.shade500, fontSize: 15.sp),
                      ),
                    ],
                  ),
                );
              }
              return _buildReportTable(rows);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportHeader(List<Map<String, dynamic>> docs) {
    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, color: _kPrimary, size: 20.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _monthLabel,
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _showMonthPicker,
            icon: Icon(Icons.tune_rounded, size: 16.r),
            label: Text('تغيير', style: GoogleFonts.cairo(fontSize: 12.sp)),
            style: TextButton.styleFrom(foregroundColor: _kPrimary),
          ),
          SizedBox(width: 4.w),
          OutlinedButton.icon(
            onPressed: () {
              final rows = _buildReport(docs);
              _showPrintReport(rows);
            },
            icon: Icon(Icons.print_rounded, size: 16.r),
            label: Text('طباعة', style: GoogleFonts.cairo(fontSize: 12.sp)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<_TeacherReportRow> rows) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        children: [
          // Table header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(10.r),
                topLeft: Radius.circular(10.r),
              ),
            ),
            child: Row(
              children: [
                _HeaderCell('#', flex: 1),
                _HeaderCell('اسم المعلم', flex: 3),
                _HeaderCell('حضر', flex: 1),
                _HeaderCell('تغيب طابور', flex: 2),
                _HeaderCell('غائب مدرسة', flex: 2),
                _HeaderCell('الأيام', flex: 1),
                _HeaderCell('نسبة الحضور', flex: 3),
              ],
            ),
          ),
          // Table rows
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return _ReportTableRow(
              index: i + 1,
              row: row,
              isEven: i.isEven,
            );
          }),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Teacher Report Row Model
// ─────────────────────────────────────────────
class _TeacherReportRow {
  final String id;
  final String name;
  int present = 0;
  int absentAssembly = 0;
  int absentSchool = 0;
  int totalDays = 0;

  _TeacherReportRow({required this.id, required this.name});

  double get attendanceRate => totalDays == 0 ? 0 : (present / totalDays) * 100;
}

// ─────────────────────────────────────────────
// Report Table Widgets
// ─────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ReportTableRow extends StatelessWidget {
  final int index;
  final _TeacherReportRow row;
  final bool isEven;

  const _ReportTableRow({
    required this.index,
    required this.row,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final rate = row.attendanceRate;
    final rateColor = rate >= 90
        ? _kGreen
        : rate >= 70
            ? _kOrange
            : _kRed;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          right: BorderSide(color: Colors.grey.shade200, width: 0.5),
          left: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // #
          Expanded(
            flex: 1,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: Colors.grey.shade500),
            ),
          ),
          // Name
          Expanded(
            flex: 3,
            child: Text(
              row.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Present
          Expanded(
            flex: 1,
            child: Text(
              '${row.present}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: _kGreen, fontWeight: FontWeight.bold),
            ),
          ),
          // Absent assembly
          Expanded(
            flex: 2,
            child: Text(
              '${row.absentAssembly}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp,
                  color: _kOrange,
                  fontWeight: FontWeight.bold),
            ),
          ),
          // Absent school
          Expanded(
            flex: 2,
            child: Text(
              '${row.absentSchool}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: _kRed, fontWeight: FontWeight.bold),
            ),
          ),
          // Total days
          Expanded(
            flex: 1,
            child: Text(
              '${row.totalDays}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: Colors.grey.shade700),
            ),
          ),
          // Attendance rate with progress bar
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: rateColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: rateColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                    minHeight: 5.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Month/Year Picker Dialog
// ─────────────────────────────────────────────
class _MonthYearPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final void Function(int month, int year) onConfirm;

  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.initialYear,
    required this.onConfirm,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _month;
  late int _year;

  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          'اختر الشهر والسنة',
          style:
              GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _year--),
                ),
                Text(
                  '$_year',
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _year < DateTime.now().year
                      ? () => setState(() => _year++)
                      : null,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Month grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.6,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final isSelected = _month == i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _month = i + 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? _kPrimary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _months[i],
                      style: GoogleFonts.cairo(
                        fontSize: 10.sp,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onConfirm(_month, _year);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: Text('تأكيد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Report Print Dialog
// ─────────────────────────────────────────────
class _ReportPrintDialog extends StatelessWidget {
  final String monthLabel;
  final List<_TeacherReportRow> rows;

  const _ReportPrintDialog({
    required this.monthLabel,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print_rounded, color: _kPrimary, size: 22.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'طباعة تقرير $monthLabel',
                style: GoogleFonts.cairo(
                    fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360.w,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary stats
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PrintStat(
                        label: 'إجمالي المعلمين',
                        count: rows.length,
                        color: _kPrimary,
                      ),
                      _PrintStat(
                        label: 'متوسط الحضور',
                        count: rows.isEmpty
                            ? 0
                            : (rows
                                        .map((r) => r.attendanceRate)
                                        .reduce((a, b) => a + b) /
                                    rows.length)
                                .round(),
                        color: _kGreen,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                // Table
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  final rate = row.attendanceRate;
                  final rateColor = rate >= 90
                      ? _kGreen
                      : rate >= 70
                          ? _kOrange
                          : _kRed;
                  return Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.grey.shade50 : Colors.white,
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade200, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22.w,
                          child: Text('${i + 1}',
                              style: GoogleFonts.cairo(
                                  fontSize: 10.sp,
                                  color: Colors.grey.shade400)),
                        ),
                        Expanded(
                          child: Text(
                            row.name,
                            style: GoogleFonts.cairo(
                                fontSize: 11.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${row.present}✓ ${row.absentAssembly}⚠ ${row.absentSchool}✗',
                          style: GoogleFonts.cairo(
                              fontSize: 10.sp, color: Colors.grey.shade600),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(
                            fontSize: 11.sp,
                            color: rateColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري إرسال التقرير للطباعة...',
                      style: GoogleFonts.cairo()),
                  backgroundColor: _kPrimary,
                ),
              );
            },
            icon: Icon(Icons.print_rounded, size: 16.r),
            label: Text('طباعة', style: GoogleFonts.cairo()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
