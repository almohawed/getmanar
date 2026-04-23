import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/domain/models/user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../academic/presentation/students_provider.dart';
import '../../../admin/data/mock_class_repository.dart';
import '../../../academic/domain/classroom.dart';
import '../../../behavior/presentation/behavior_controller.dart';

class ClassroomBehaviorIndicatorsScreen extends ConsumerStatefulWidget {
  const ClassroomBehaviorIndicatorsScreen({super.key});

  @override
  ConsumerState<ClassroomBehaviorIndicatorsScreen> createState() =>
      _ClassroomBehaviorIndicatorsScreenState();
}

class _ClassroomBehaviorIndicatorsScreenState
    extends ConsumerState<ClassroomBehaviorIndicatorsScreen> {
  final _notes = const <_BehaviorNote>[
    _BehaviorNote(
      keyId: 'book_missing',
      label: 'ملاحظة: لم يحضر الكتاب',
      icon: Icons.menu_book,
      color: Color(0xFF0E7490),
    ),
    _BehaviorNote(
      keyId: 'distracted',
      label: 'ملاحظة: تشتت أثناء الحصة',
      icon: Icons.center_focus_strong,
      color: Color(0xFF2563EB),
    ),
    _BehaviorNote(
      keyId: 'homework_missing',
      label: 'ملاحظة: عدم إنجاز الواجب',
      icon: Icons.assignment_late,
      color: Color(0xFF7C3AED),
    ),
    _BehaviorNote(
      keyId: 'side_talk',
      label: 'ملاحظة: كثرة الحديث الجانبي',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF0891B2),
    ),
    _BehaviorNote(
      keyId: 'bullying_peer',
      label: 'ملاحظة: سلوك تنمري تجاه زميل',
      icon: Icons.report_outlined,
      color: Color(0xFFB45309),
    ),
    _BehaviorNote(
      keyId: 'disrespect_teacher',
      label: 'ملاحظة: عدم احترام التعليمات الصفية',
      icon: Icons.record_voice_over_outlined,
      color: Color(0xFF0F766E),
    ),
    _BehaviorNote(
      keyId: 'tools_misuse',
      label: 'ملاحظة: استخدام غير مناسب للأدوات',
      icon: Icons.build_outlined,
      color: Color(0xFF0F766E),
    ),
    _BehaviorNote(
      keyId: 'phone_use',
      label: 'ملاحظة: استخدام الجوال داخل الحصة',
      icon: Icons.phone_android,
      color: Color(0xFF334155),
    ),
    _BehaviorNote(
      keyId: 'no_participation',
      label: 'ملاحظة: مشاركة منخفضة خلال الحصة',
      icon: Icons.pan_tool_alt_outlined,
      color: Color(0xFF0369A1),
    ),
    _BehaviorNote(
      keyId: 'late_return',
      label: 'ملاحظة: تأخر في العودة للحصة',
      icon: Icons.schedule,
      color: Color(0xFF334155),
    ),
    _BehaviorNote(
      keyId: 'leaves_seat',
      label: 'ملاحظة: كثرة الحركة وترك المقعد',
      icon: Icons.directions_walk,
      color: Color(0xFF7C2D12),
    ),
    _BehaviorNote(
      keyId: 'unprepared_tools',
      label: 'ملاحظة: عدم إحضار الأدوات التعليمية',
      icon: Icons.backpack_outlined,
      color: Color(0xFF1D4ED8),
    ),
    _BehaviorNote(
      keyId: 'cheating_attempt',
      label: 'ملاحظة: محاولة غير مناسبة أثناء التقييم',
      icon: Icons.rule_outlined,
      color: Color(0xFF6D28D9),
    ),
    _BehaviorNote(
      keyId: 'not_following_instructions',
      label: 'ملاحظة: عدم الالتزام بتوجيهات المعلم',
      icon: Icons.playlist_remove,
      color: Color(0xFF0E7490),
    ),
    _BehaviorNote(
      keyId: 'classroom_damage',
      label: 'ملاحظة: عبث بممتلكات الصف',
      icon: Icons.handyman_outlined,
      color: Color(0xFF9A3412),
    ),
    _BehaviorNote(
      keyId: 'lesson_disruption',
      label: 'ملاحظة: سلوك مؤثر على سير الدرس',
      icon: Icons.insights,
      color: Color(0xFF4F46E5),
    ),
    _BehaviorNote(
      keyId: 'safety_concern',
      label: 'ملاحظة: سلوك يحتاج متابعة حفاظاً على السلامة',
      icon: Icons.health_and_safety_outlined,
      color: Color(0xFF0F766E),
    ),
  ];

  String? _highlightKey;
  DateTime? _cooldownUntil;
  DateTime? _lastContextHintAt;
  String? _contextHintText;
  Timer? _contextHintTimer;
  Timer? _highlightTimer;
  bool _isDialogOpen = false;
  String? _selectedClassId;
  bool _didAutoSelectClass = false;

  @override
  void dispose() {
    _contextHintTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  bool get _isCoolingDown {
    final until = _cooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Color _accentColor(Color base) {
    return Color.lerp(base, Colors.black, 0.25) ?? base;
  }

  Widget _buildNoteCard({
    required _BehaviorNote note,
    required bool isActive,
    required VoidCallback? onTap,
    double? width,
  }) {
    final accent = _accentColor(note.color);
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: note.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isActive
                ? note.color.withValues(alpha: 0.70)
                : note.color.withValues(alpha: 0.22),
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: note.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(note.icon, color: accent),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                note.label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) Icon(Icons.check_circle, color: accent, size: 18.sp),
          ],
        ),
      ),
    );

    if (width == null) return content;
    return SizedBox(width: width, child: content);
  }

  Future<_BehaviorDialogResult?> _showBehaviorDialog({
    required _BehaviorNote note,
    required List<User> students,
  }) async {
    final sorted = students.toList()..sort((a, b) => a.name.compareTo(b.name));

    return showDialog<_BehaviorDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        String query = '';
        String? selectedId;
        String selectedName() {
          final id = selectedId;
          if (id == null) return '';
          final s = sorted.where((x) => x.id == id).toList();
          return s.isEmpty ? '' : s.first.name;
        }

        List<User> visible() {
          final q = query.trim();
          if (q.isEmpty) return sorted.take(18).toList();
          return sorted
              .where((s) {
                final name = s.name;
                final idn = (s.identityNumber ?? '').toString();
                return name.contains(q) || idn.contains(q);
              })
              .take(30)
              .toList();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final items = visible();
            final hasStudents = sorted.isNotEmpty;
            final name = selectedName();
            final canSubmit = selectedId != null && name.trim().isNotEmpty;

            return AlertDialog(
              title: const Text('تسجيل ملاحظة سلوكية'),
              content: SizedBox(
                width: 520.w,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        note.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'تم رصد ملاحظة تعليمية خلال الحصة الحالية.\nيرجى تحديد الطالب ثم اختيار الإجراء المناسب.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        onChanged: (v) => setLocal(() => query = v),
                        decoration: const InputDecoration(
                          labelText: 'بحث عن الطالب',
                          hintText: 'الاسم أو رقم الهوية',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      if (hasStudents)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 260.h),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: items.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                              itemBuilder: (context, index) {
                                final s = items[index];
                                final isSelected = selectedId == s.id;
                                return ListTile(
                                  title: Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      (s.identityNumber ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : Text(
                                          (s.identityNumber ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle)
                                      : const Icon(Icons.circle_outlined),
                                  onTap: () {
                                    setLocal(() {
                                      selectedId = s.id;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            'لا توجد قائمة طلاب متاحة الآن لهذا الفصل.',
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(ctx).pop(
                          _BehaviorDialogResult(
                            action: _BehaviorAction.internal,
                            studentId: selectedId!,
                            studentName: name,
                          ),
                        )
                      : null,
                  child: const Text('تسجيل داخلي'),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(ctx).pop(
                          _BehaviorDialogResult(
                            action: _BehaviorAction.notify,
                            studentId: selectedId!,
                            studentName: name,
                          ),
                        )
                      : null,
                  child: const Text('إشعار الإدارة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onTapNote(
    _BehaviorNote note, {
    required String? selectedClassId,
    required Map<String, Classroom> classById,
  }) async {
    if (_isCoolingDown || _isDialogOpen) return;
    _isDialogOpen = true;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) {
      _isDialogOpen = false;
      return;
    }

    final allStudents = ref.read(studentsProvider).value ?? const <User>[];
    final Classroom? selectedClass = (selectedClassId != null)
        ? classById[selectedClassId]
        : null;

    final students = selectedClass == null
        ? const <User>[]
        : allStudents.where((s) {
            final ids = selectedClass.studentIds.toSet();
            final assigned = s.assignedClassIds ?? const <String>[];
            return ids.contains(s.id) || assigned.contains(selectedClass.id);
          }).toList();

    final result = await _showBehaviorDialog(note: note, students: students);

    _isDialogOpen = false;
    if (!mounted) return;
    if (result == null) return;

    final isNotify = result.action == _BehaviorAction.notify;
    String actionMsg;
    try {
      actionMsg = await ref
          .read(behaviorControllerProvider.notifier)
          .addClassroomNote(
            studentId: result.studentId,
            studentName: result.studentName,
            teacherId: currentUser.id,
            description: note.label,
            notifyDeputy: isNotify,
            classId: selectedClass?.id,
            className: selectedClass?.preferredLabel,
          );
    } catch (_) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ الملاحظة الآن. يرجى المحاولة مرة أخرى.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _highlightKey = note.keyId;
      _cooldownUntil = DateTime.now().add(const Duration(seconds: 3));
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _highlightKey = null);
    });

    final studentLabel = 'الطالب: ${result.studentName}';

    final msg = '$actionMsg\n$studentLabel';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    _showContextHint(
      actionLabel: isNotify ? 'إشعار الإدارة' : 'تسجيل داخلي',
      studentLabel: 'الطالب (${result.studentName})',
      periodLabel: 'الحصة (—)',
      subjectLabel: 'مادة (—)',
    );
  }

  void _showContextHint({
    required String actionLabel,
    required String studentLabel,
    required String periodLabel,
    required String subjectLabel,
  }) {
    final now = DateTime.now();
    _lastContextHintAt = now;
    setState(() {
      _contextHintText =
          'آخر إجراء تم: $actionLabel – $studentLabel – $periodLabel – $subjectLabel';
    });

    _contextHintTimer?.cancel();
    _contextHintTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _contextHintText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final teacherClassIds = currentUser?.assignedClassIds ?? const <String>[];
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.value ?? const <Classroom>[];
    final classById = <String, Classroom>{for (final c in classes) c.id: c};
    final teacherClasses =
        classes.where((c) => teacherClassIds.contains(c.id)).toList()
          ..sort((a, b) => a.preferredLabel.compareTo(b.preferredLabel));

    if (!_didAutoSelectClass &&
        _selectedClassId == null &&
        teacherClasses.isNotEmpty) {
      _didAutoSelectClass = true;
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _selectedClassId = teacherClasses.first.id);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('مؤشرات السلوك الصفي')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (teacherClasses.isEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'لا توجد فصول مسندة لهذا المعلم حالياً. سيتم تفعيل اختيار الطلاب حسب الفصول فور إسناد الفصول للمعلم.',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0F766E,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: const Icon(
                            Icons.groups,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedClassId,
                            items: teacherClasses
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(c.preferredLabel),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedClassId = v),
                            decoration: const InputDecoration(
                              labelText: 'اختر الفصل',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 12.h),
              if (_contextHintText != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          _contextHintText!,
                          style: TextStyle(
                            color: const Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 12.h),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات سلوكية جاهزة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'اختر الملاحظة بنقرة واحدة ثم حدد الإجراء المناسب بصياغة تربوية داعمة.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              LayoutBuilder(
                builder: (context, constraints) {
                  var cols = 2;
                  if (constraints.maxWidth > 1100) cols = 4;
                  if (constraints.maxWidth > 700 &&
                      constraints.maxWidth <= 1100) {
                    cols = 3;
                  }
                  final isMobile = constraints.maxWidth < 520;
                  if (isMobile) {
                    final fullWidth = constraints.maxWidth;
                    final children = <Widget>[];
                    for (final note in _notes) {
                      children.add(
                        _buildNoteCard(
                          note: note,
                          isActive: _highlightKey == note.keyId,
                          onTap: _isCoolingDown
                              ? null
                              : () => _onTapNote(
                                  note,
                                  selectedClassId: _selectedClassId,
                                  classById: classById,
                                ),
                          width: fullWidth,
                        ),
                      );
                      children.add(SizedBox(height: 12.h));
                    }
                    if (children.isNotEmpty) children.removeLast();
                    return Column(children: children);
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio: cols >= 4 ? 2.8 : 2.6,
                    ),
                    itemCount: _notes.length,
                    itemBuilder: (context, i) {
                      final note = _notes[i];
                      return _buildNoteCard(
                        note: note,
                        isActive: _highlightKey == note.keyId,
                        onTap: _isCoolingDown
                            ? null
                            : () => _onTapNote(
                                note,
                                selectedClassId: _selectedClassId,
                                classById: classById,
                              ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BehaviorNote {
  final String keyId;
  final String label;
  final IconData icon;
  final Color color;

  const _BehaviorNote({
    required this.keyId,
    required this.label,
    required this.icon,
    required this.color,
  });
}

enum _BehaviorAction { notify, internal }

class _BehaviorDialogResult {
  final _BehaviorAction action;
  final String studentId;
  final String studentName;

  const _BehaviorDialogResult({
    required this.action,
    required this.studentId,
    required this.studentName,
  });
}
