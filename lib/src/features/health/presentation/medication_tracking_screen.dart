import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';

// ---------------------------------------------------------------------------
// Data Model
// ---------------------------------------------------------------------------

class MedicationRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String medicationName;
  final String dose;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String notes;
  final String status; // 'active' | 'completed'
  final DateTime createdAt;
  final String createdBy;

  const MedicationRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.medicationName,
    required this.dose,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  factory MedicationRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MedicationRecord(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      medicationName: d['medicationName'] ?? '',
      dose: d['dose'] ?? '',
      frequency: d['frequency'] ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      notes: d['notes'] ?? '',
      status: d['status'] ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'medicationName': medicationName,
    'dose': dose,
    'frequency': frequency,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'notes': notes,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  bool get isDueToday {
    final now = DateTime.now();
    if (status != 'active') return false;
    if (endDate != null && endDate!.isBefore(now)) return false;
    return true;
  }

  String get nextDoseLabel {
    switch (frequency) {
      case 'صباح':
        return 'الصباح';
      case 'مساء':
        return 'المساء';
      case 'ثلاث مرات':
        return 'كل 8 ساعات';
      case 'عند الحاجة':
        return 'عند الحاجة';
      default:
        return frequency;
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final medicationsStreamProvider =
    StreamProvider.autoDispose<List<MedicationRecord>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('StudentMedications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => MedicationRecord.fromFirestore(d)).toList(),
      );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MedicationTrackingScreen extends ConsumerStatefulWidget {
  const MedicationTrackingScreen({super.key});

  @override
  ConsumerState<MedicationTrackingScreen> createState() =>
      _MedicationTrackingScreenState();
}

class _MedicationTrackingScreenState
    extends ConsumerState<MedicationTrackingScreen> {
  static const _gradientStart = Color(0xFF00897B);
  static const _gradientEnd = Color(0xFF26A69A);

  String _filter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final medsAsync = ref.watch(medicationsStreamProvider);
    final filter = _filter;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
        body: medsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (all) {
            final filtered = _applyFilter(all, filter);
            final active = all.where((m) => m.status == 'active').length;
            final dueToday = all.where((m) => m.isDueToday).length;

            return CustomScrollView(
              slivers: [
                _buildHeader(all.length, active, dueToday),
                _buildFilterChips(),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
                  sliver: filtered.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmpty())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) =>
                                _MedicationCard(record: filtered[i]),
                            childCount: filtered.length,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  List<MedicationRecord> _applyFilter(List<MedicationRecord> all, String f) {
    if (f == 'نشط') return all.where((m) => m.status == 'active').toList();
    if (f == 'مكتمل') return all.where((m) => m.status == 'completed').toList();
    return all;
  }

  Widget _buildHeader(int total, int active, int dueToday) {
    return SliverAppBar(
      expandedHeight: 200.h,
      pinned: true,
      backgroundColor: _gradientStart,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [_gradientStart, _gradientEnd, Color(0xFF80CBC4)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: Colors.white,
                          size: 32.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'متابعة الأدوية',
                            style: GoogleFonts.cairo(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'إدارة أدوية الطلاب',
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      _StatChip(
                        label: 'الإجمالي',
                        value: '$total',
                        icon: Icons.list_alt_rounded,
                      ),
                      SizedBox(width: 10.w),
                      _StatChip(
                        label: 'نشط',
                        value: '$active',
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFFA5D6A7),
                      ),
                      SizedBox(width: 10.w),
                      _StatChip(
                        label: 'اليوم',
                        value: '$dueToday',
                        icon: Icons.today_rounded,
                        color: const Color(0xFFFFCC80),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
        title: Text(
          'متابعة الأدوية',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        titlePadding: EdgeInsets.only(right: 60.w, bottom: 16.h),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['الكل', 'نشط', 'مكتمل'];

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: filters.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: FilterChip(
                label: Text(
                  f,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : _gradientStart,
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: _gradientStart,
                backgroundColor: _gradientStart.withOpacity(0.08),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: selected ? _gradientStart : _gradientStart.withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.only(top: 80.h),
      child: Column(
        children: [
          Icon(
            Icons.medication_outlined,
            size: 72.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد سجلات أدوية',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showAddDialog,
      backgroundColor: _gradientStart,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        'إضافة دواء',
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevation: 6,
    );
  }

  void _showAddDialog({MedicationRecord? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _MedicationDialog(existing: existing),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Chip
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(width: 6.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    color: Colors.white70,
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

// ---------------------------------------------------------------------------
// Medication Card
// ---------------------------------------------------------------------------

class _MedicationCard extends ConsumerWidget {
  final MedicationRecord record;
  const _MedicationCard({required this.record});

  static const _activeGrad = [Color(0xFF00897B), Color(0xFF26A69A)];
  static const _completedGrad = [Color(0xFF78909C), Color(0xFF90A4AE)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = record.status == 'active';
    final grad = isActive ? _activeGrad : _completedGrad;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: grad.first.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Colored top bar
              Container(
                height: 5.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(context, ref, isActive, grad),
                    SizedBox(height: 12.h),
                    _buildInfoGrid(),
                    SizedBox(height: 12.h),
                    _buildBottomRow(isActive),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(
    BuildContext context,
    WidgetRef ref,
    bool isActive,
    List<Color> grad,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: grad.map((c) => c.withOpacity(0.15)).toList(),
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.medication_rounded,
            color: grad.first,
            size: 26.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.medicationName,
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E35),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 13.sp,
                    color: Colors.grey.shade500,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    record.studentName,
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _StatusBadge(isActive: isActive),
        SizedBox(width: 8.w),
        _ActionMenu(record: record),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9F8),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _InfoCell(
            icon: Icons.colorize_rounded,
            label: 'الجرعة',
            value: record.dose,
          ),
          _VertDivider(),
          _InfoCell(
            icon: Icons.repeat_rounded,
            label: 'التكرار',
            value: record.frequency,
          ),
          _VertDivider(),
          _InfoCell(
            icon: Icons.schedule_rounded,
            label: 'الجرعة التالية',
            value: record.nextDoseLabel,
            highlight: record.isDueToday,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow(bool isActive) {
    final start = _formatDate(record.startDate);
    final end = record.endDate != null ? _formatDate(record.endDate!) : '—';

    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 13.sp, color: Colors.grey.shade400),
        SizedBox(width: 4.w),
        Text(
          'من $start إلى $end',
          style: GoogleFonts.cairo(
            fontSize: 11.sp,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        if (record.notes.isNotEmpty)
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 13.sp, color: Colors.grey.shade400),
              SizedBox(width: 4.w),
              SizedBox(
                width: 100.w,
                child: Text(
                  record.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

// ---------------------------------------------------------------------------
// Supporting Widgets
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive
              ? const Color(0xFF66BB6A)
              : const Color(0xFF90A4AE),
          width: 1,
        ),
      ),
      child: Text(
        isActive ? 'نشط' : 'مكتمل',
        style: GoogleFonts.cairo(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: isActive
              ? const Color(0xFF2E7D32)
              : const Color(0xFF546E7A),
        ),
      ),
    );
  }
}

class _ActionMenu extends ConsumerWidget {
  final MedicationRecord record;
  const _ActionMenu({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      onSelected: (v) async {
        if (v == 'edit') {
          showDialog(
            context: context,
            builder: (_) => _MedicationDialog(existing: record),
          );
        } else if (v == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => _ConfirmDeleteDialog(),
          );
          if (confirm == true) {
            final user = ref.read(authStateProvider).value;
            final schoolId = user?.schoolId ?? '';
            if (schoolId.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('StudentMedications')
                  .doc(record.id)
                  .delete();
            }
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  color: const Color(0xFF00897B), size: 18.sp),
              SizedBox(width: 8.w),
              Text('تعديل', style: GoogleFonts.cairo(fontSize: 14.sp)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 18.sp),
              SizedBox(width: 8.w),
              Text('حذف',
                  style: GoogleFonts.cairo(
                      fontSize: 14.sp, color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: highlight
                ? const Color(0xFFFF8F00)
                : const Color(0xFF00897B),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? const Color(0xFFFF8F00)
                  : const Color(0xFF1A2E35),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40.h,
      color: Colors.grey.shade200,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('تأكيد الحذف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      content: Text('هل أنت متأكد من حذف هذا السجل؟',
          style: GoogleFonts.cairo()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text('حذف',
              style: GoogleFonts.cairo(color: Colors.white)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Dialog
// ---------------------------------------------------------------------------

class _MedicationDialog extends ConsumerStatefulWidget {
  final MedicationRecord? existing;
  const _MedicationDialog({this.existing});

  @override
  ConsumerState<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends ConsumerState<_MedicationDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _medNameCtrl;
  late TextEditingController _doseCtrl;
  late TextEditingController _notesCtrl;

  String _selectedStudentId = '';
  String _selectedStudentName = '';
  String _frequency = 'صباح';
  String _status = 'active';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _saving = false;

  static const _frequencies = ['صباح', 'مساء', 'ثلاث مرات', 'عند الحاجة'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _medNameCtrl = TextEditingController(text: e?.medicationName ?? '');
    _doseCtrl = TextEditingController(text: e?.dose ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _selectedStudentId = e.studentId;
      _selectedStudentName = e.studentName;
      _frequency = e.frequency;
      _status = e.status;
      _startDate = e.startDate;
      _endDate = e.endDate;
    }
  }

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _doseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final isEdit = widget.existing != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r)),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(Icons.medication_rounded,
                            color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        isEdit ? 'تعديل سجل الدواء' : 'إضافة دواء جديد',
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A2E35),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Student picker
                  _SectionLabel(label: 'الطالب'),
                  SizedBox(height: 6.h),
                  studentsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (students) => DropdownButtonFormField<String>(
                      value: _selectedStudentId.isEmpty
                          ? null
                          : _selectedStudentId,
                      decoration: _inputDecoration('اختر الطالب'),
                      items: students
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name,
                                  style: GoogleFonts.cairo(fontSize: 13.sp)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedStudentId = v;
                          _selectedStudentName = students
                              .firstWhere((s) => s.id == v)
                              .name;
                        });
                      },
                      validator: (v) =>
                          v == null ? 'يرجى اختيار الطالب' : null,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Medication name
                  _SectionLabel(label: 'اسم الدواء'),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _medNameCtrl,
                    decoration: _inputDecoration('مثال: بروفين 200mg'),
                    style: GoogleFonts.cairo(fontSize: 14.sp),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'مطلوب' : null,
                  ),
                  SizedBox(height: 12.h),

                  // Dose
                  _SectionLabel(label: 'الجرعة'),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _doseCtrl,
                    decoration: _inputDecoration('مثال: حبة واحدة'),
                    style: GoogleFonts.cairo(fontSize: 14.sp),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'مطلوب' : null,
                  ),
                  SizedBox(height: 12.h),

                  // Frequency
                  _SectionLabel(label: 'التكرار'),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 8.w,
                    children: _frequencies.map((f) {
                      final sel = _frequency == f;
                      return ChoiceChip(
                        label: Text(f,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: sel ? Colors.white : const Color(0xFF00897B),
                            )),
                        selected: sel,
                        selectedColor: const Color(0xFF00897B),
                        backgroundColor:
                            const Color(0xFF00897B).withOpacity(0.08),
                        onSelected: (_) =>
                            setState(() => _frequency = f),
                        side: BorderSide(
                          color: sel
                              ? const Color(0xFF00897B)
                              : const Color(0xFF00897B).withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r)),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12.h),

                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'تاريخ البدء'),
                            SizedBox(height: 6.h),
                            _DatePickerField(
                              date: _startDate,
                              onPick: (d) =>
                                  setState(() => _startDate = d),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'تاريخ الانتهاء'),
                            SizedBox(height: 6.h),
                            _DatePickerField(
                              date: _endDate,
                              hint: 'اختياري',
                              onPick: (d) =>
                                  setState(() => _endDate = d),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Status
                  _SectionLabel(label: 'الحالة'),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      _StatusToggle(
                        label: 'نشط',
                        selected: _status == 'active',
                        color: const Color(0xFF00897B),
                        onTap: () => setState(() => _status = 'active'),
                      ),
                      SizedBox(width: 10.w),
                      _StatusToggle(
                        label: 'مكتمل',
                        selected: _status == 'completed',
                        color: const Color(0xFF78909C),
                        onTap: () => setState(() => _status = 'completed'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Notes
                  _SectionLabel(label: 'ملاحظات'),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: _inputDecoration('ملاحظات إضافية (اختياري)'),
                    style: GoogleFonts.cairo(fontSize: 14.sp),
                    maxLines: 2,
                  ),
                  SizedBox(height: 20.h),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                        elevation: 4,
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : Text(
                              isEdit ? 'حفظ التعديلات' : 'إضافة السجل',
                              style: GoogleFonts.cairo(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(
            fontSize: 13.sp, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF5F9F8),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;

      final col = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentMedications');

      final data = MedicationRecord(
        id: widget.existing?.id ?? '',
        studentId: _selectedStudentId,
        studentName: _selectedStudentName,
        medicationName: _medNameCtrl.text.trim(),
        dose: _doseCtrl.text.trim(),
        frequency: _frequency,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesCtrl.text.trim(),
        status: _status,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        createdBy: user?.name ?? '',
      ).toMap();

      if (widget.existing != null) {
        await col.doc(widget.existing!.id).update(data);
      } else {
        await col.add(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e',
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Dialog helper widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.cairo(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF37474F),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final ValueChanged<DateTime> onPick;

  const _DatePickerField({
    required this.date,
    required this.onPick,
    this.hint = 'اختر تاريخ',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('ar'),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9F8),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15.sp, color: const Color(0xFF00897B)),
            SizedBox(width: 6.w),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : hint,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: date != null
                    ? const Color(0xFF1A2E35)
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
