// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../../academic/data/mock_data.dart';
import '../../academic/domain/classroom.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_class_repository.dart';

// ─── نماذج البيانات ───────────────────────────────────────────────────────────

class _BehaviorItem {
  final String title;
  final int points;
  const _BehaviorItem(this.title, this.points);
}

// سلوكيات التميز (20% من الدرجة)
const _meritBehaviors = [
  _BehaviorItem('مساعدة زميل', 2),
  _BehaviorItem('مبادرة مميزة', 2),
  _BehaviorItem('تفوق في اختبار', 2),
  _BehaviorItem('نظافة ومواظبة', 3),
  _BehaviorItem('إجابة صحيحة في الحصة', 2),
  _BehaviorItem('المشاركة في أنشطة المهارات الرقمية', 4),
  _BehaviorItem('الالتحاق ببرنامج أو دورة تدريبية', 6),
  _BehaviorItem('المشاركة في مسابقات أو جوائز', 4),
  _BehaviorItem('عرض تجارب شخصية ناجحة أمام الزملاء', 6),
  _BehaviorItem('التعاون مع الزملاء والمعلمين والإدارة', 3),
  _BehaviorItem('المشاركة في الخدمة المجتمعية خارج المدرسة', 6),
  _BehaviorItem('كتابة رسالة شكر للوطن أو القيادة أو المعلم', 5),
  _BehaviorItem('تقديم فعالية حوارية', 6),
  _BehaviorItem('المشاركة في حملة توعوية', 6),
  _BehaviorItem('عرض تجارب شخصية ناجحة', 6),
  _BehaviorItem('العمل الجماعي', 4),
  _BehaviorItem('التعلم بالاقران', 4),
  _BehaviorItem('المشاركة في الإذاعة', 2),
];

// سلوكيات التعويض (استعادة الدرجات المحسومة من السلوك الإيجابي)
const _compensationBehaviors = [
  _BehaviorItem('القيام بتنظيم دخول الطلاب في الفصول', 3),
  _BehaviorItem(
      'المشاركة في الخدمة المجتمعية خارج المدرسة (إحضار مايثبت) 6 درجات', 5),
  _BehaviorItem('المشاركة في برامج إرشادية', 3),
  _BehaviorItem('تكليفات تربوية مناسبة', 2),
  _BehaviorItem('تنفيذ نشاط توعوي', 4),
  _BehaviorItem(
      'إعداد ملخص للدرس وتسليمه (في حال كانت المخالفة عدم تنفيذ الواجبات)', 2),
  _BehaviorItem('المشاركة في توعية المحافظة على الممتلكات', 5),
];

// ─── الشاشة الرئيسية ──────────────────────────────────────────────────────────

class StudentExcellenceCompensationScreen extends ConsumerStatefulWidget {
  final String initialTab;
  const StudentExcellenceCompensationScreen({
    super.key,
    this.initialTab = "excellence",
  });

  @override
  ConsumerState<StudentExcellenceCompensationScreen> createState() =>
      _StudentExcellenceCompensationScreenState();
}

class _StudentExcellenceCompensationScreenState
    extends ConsumerState<StudentExcellenceCompensationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedClassId;
  String _selectedStudentId = "";
  String _selectedStudentName = "";
  String _selectedClassLabel = "";
  String? _selectedBehavior;
  int _selectedPoints = 0;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == "compensation" ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _currentType =>
      _tabController.index == 0 ? "merit" : "compensation";

  Color get _primaryColor =>
      _tabController.index == 0 ? Colors.amber.shade700 : Colors.green.shade700;

  void _resetForm() {
    setState(() {
      _selectedClassId = null;
      _selectedClassLabel = "";
      _selectedStudentId = "";
      _selectedStudentName = "";
      _selectedBehavior = null;
      _selectedPoints = 0;
      _notesCtrl.clear();
    });
  }

  Future<void> _submit(User user) async {
    if (_selectedStudentId.isEmpty) {
      _showSnack("يرجى اختيار الطالب أولاً", Colors.red);
      return;
    }
    if (_selectedBehavior == null) {
      _showSnack("يرجى اختيار نوع السلوك", Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final schoolId = user.schoolId ?? "";
      final teacherId = user.id;
      final teacherName = user.name;

      // سجل السلوك
      final recordRef = FirebaseFirestore.instance
          .collection('Schools/$schoolId/BehaviorRecords')
          .doc();

      await recordRef.set({
        'studentId': _selectedStudentId,
        'studentName': _selectedStudentName,
        'className': _selectedClassLabel,
        'type': _currentType, // 'merit' or 'compensation'
        'behaviorTitle': _selectedBehavior!,
        'points': _selectedPoints,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
      });

      // إشعار لولي الأمر
      final notifRef = FirebaseFirestore.instance
          .collection('Schools/$schoolId/Notifications')
          .doc();

      final typeLabel = _currentType == 'merit' ? 'تميز' : 'تعويض';
      await notifRef.set({
        'title': 'سلوك $typeLabel - $_selectedBehavior',
        'body':
            'حصل $_selectedStudentName على $_selectedPoints نقطة $typeLabel بسبب: $_selectedBehavior',
        'studentId': _selectedStudentId,
        'studentName': _selectedStudentName,
        'type': 'behavior_$_currentType',
        'points': _selectedPoints,
        'teacherName': teacherName,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'schoolId': schoolId,
      });

      _showSnack(
        _currentType == "merit"
            ? "✅ تم تسجيل سلوك التميز بنجاح"
            : "✅ تم تسجيل السلوك التعويضي بنجاح",
        Colors.green,
      );
      _resetForm();
    } catch (e) {
      _showSnack("حدث خطأ: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: GoogleFonts.cairo()),
          backgroundColor: color,
          duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isTeacher = user.role == UserRole.teacher;
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('التميز والتعويض السلوكي', style: GoogleFonts.cairo()),
        backgroundColor: _primaryColor,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {
            _selectedBehavior = null;
            _selectedPoints = 0;
          }),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14.sp),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13.sp),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.star), text: "سلوك التميز"),
            Tab(icon: Icon(Icons.refresh), text: "السلوك التعويضي"),
          ],
        ),
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: Text('خطأ في تحميل الطلاب', style: GoogleFonts.cairo())),
        data: (allStudents) {
          return classesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
                child: Text('خطأ في تحميل الفصول', style: GoogleFonts.cairo())),
            data: (allClasses) {
              final classById = <String, Classroom>{
                for (final c in allClasses) c.id: c,
              };

              final filteredClasses = () {
                if (isTeacher && user != null) {
                  final teacherClassIds = user.assignedClassIds ?? [];
                  if (teacherClassIds.isEmpty) return <Classroom>[];
                  return allClasses
                      .where((c) => teacherClassIds.contains(c.id))
                      .toList();
                }
                return allClasses;
              }();

              // For teachers, only include students in their classes
              var availableStudents = allStudents;
              if (isTeacher && user != null) {
                final teacherClassIds = user.assignedClassIds ?? [];
                if (teacherClassIds.isNotEmpty) {
                  availableStudents = allStudents.where((s) {
                    final assigned = s.assignedClassIds ?? [];
                    return assigned.any((id) => teacherClassIds.contains(id));
                  }).toList();
                } else {
                  availableStudents = [];
                }
              }

              var displayStudents = availableStudents;

              // Filter by selected class — use allStudents and ONLY include students in selected _selectedClassId
              if (_selectedClassId != null) {
                final selectedClass = classById[_selectedClassId!];
                final classStudentIds =
                    selectedClass?.studentIds.toSet() ?? <String>{};

                displayStudents = allStudents.where((student) {
                  final isInClassStudentList =
                      classStudentIds.contains(student.id);
                  final hasAssignedClassId = (student.assignedClassIds ?? [])
                      .contains(_selectedClassId!);
                  return isInClassStudentList || hasAssignedClassId;
                }).toList();
              }

              displayStudents.sort((a, b) => a.name.compareTo(b.name));
              final behaviors = _tabController.index == 0
                  ? _meritBehaviors
                  : _compensationBehaviors;

              final teacherClassIds = user.assignedClassIds ?? [];
              final firstClassStudentIds = (filteredClasses.isNotEmpty &&
                      classById[filteredClasses.first.id] != null)
                  ? classById[filteredClasses.first.id]!.studentIds
                  : [];

              return SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── بطاقة الشرح ──────────────────────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border:
                            Border.all(color: _primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(
                            _tabController.index == 0
                                ? Icons.star_rounded
                                : Icons.refresh_rounded,
                            color: _primaryColor,
                            size: 26.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                            child: Text(
                          _tabController.index == 0
                              ? "رصد سلوك التميز — النقاط تُضاف لرصيد التميز (سقف 20 نقطة)."
                              : "رصد السلوك التعويضي — النقاط تُعاد لرصيد السلوك الإيجابي.",
                          style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: _primaryColor,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    SizedBox(height: 16.h),

                    // ── اختيار الفصل ─────────────────────────────────────────────────
                    _sectionTitle("اختيار الفصل", Icons.class_, _primaryColor),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String?>(
                      value: _selectedClassId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: "اختر الفصل...",
                        hintStyle: GoogleFonts.cairo(color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 12.h),
                      ),
                      style: GoogleFonts.cairo(
                          color: Colors.black87, fontSize: 14.sp),
                      items: [
                        DropdownMenuItem<String?>(
                            value: null,
                            child: Text("— اختر الفصل —",
                                style: GoogleFonts.cairo(color: Colors.grey))),
                        ...filteredClasses.map((c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.preferredLabel,
                                style: GoogleFonts.cairo()))),
                      ],
                      onChanged: (val) {
                        if (val == null) {
                          setState(() {
                            _selectedClassId = null;
                            _selectedClassLabel = "";
                            _selectedStudentId = "";
                            _selectedStudentName = "";
                          });
                          return;
                        }
                        setState(() {
                          _selectedClassId = val;
                          _selectedClassLabel = filteredClasses
                              .firstWhere((c) => c.id == val)
                              .preferredLabel;
                          _selectedStudentId = "";
                          _selectedStudentName = "";
                        });
                      },
                    ),
                    SizedBox(height: 16.h),

                    // ── اختيار الطالب ─────────────────────────────────────────────────
                    if (_selectedClassId != null) ...[
                      _sectionTitle(
                          "اختيار الطالب", Icons.person, _primaryColor),
                      SizedBox(height: 8.h),
                      if (displayStudents.isEmpty)
                        Text("لا يوجد طلاب في هذا الفصل",
                            style: GoogleFonts.cairo(
                                color: Colors.grey, fontSize: 13.sp))
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedStudentId.isEmpty
                              ? null
                              : _selectedStudentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: "اختر الطالب...",
                            hintStyle: GoogleFonts.cairo(color: Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 12.h),
                          ),
                          style: GoogleFonts.cairo(
                              color: Colors.black87, fontSize: 14.sp),
                          items: [
                            DropdownMenuItem<String>(
                                value: null,
                                child: Text("— اختر الطالب —",
                                    style:
                                        GoogleFonts.cairo(color: Colors.grey))),
                            ...displayStudents.map((s) =>
                                DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(s.name,
                                        style: GoogleFonts.cairo()))),
                          ],
                          onChanged: (val) {
                            if (val == null) {
                              setState(() {
                                _selectedStudentId = "";
                                _selectedStudentName = "";
                              });
                              return;
                            }
                            final s =
                                displayStudents.firstWhere((x) => x.id == val);
                            setState(() {
                              _selectedStudentId = val;
                              _selectedStudentName = s.name;
                            });
                          },
                        ),
                      if (_selectedStudentId.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r)),
                          child: Row(children: [
                            Icon(Icons.person_pin,
                                color: _primaryColor, size: 18.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                                child: Text(
                              "المحدد: $_selectedStudentName",
                              style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold),
                            )),
                          ]),
                        ),
                      ],
                      SizedBox(height: 16.h),
                    ],

                    // ── نوع السلوك ────────────────────────────────────────────────────
                    _sectionTitle(
                      _tabController.index == 0
                          ? "نوع سلوك التميز"
                          : "نوع السلوك التعويضي",
                      _tabController.index == 0 ? Icons.star : Icons.refresh,
                      _primaryColor,
                    ),
                    SizedBox(height: 4.h),
                    Text("(اختر واحداً)",
                        style: GoogleFonts.cairo(
                            fontSize: 12.sp, color: Colors.grey)),
                    SizedBox(height: 8.h),
                    _buildBehaviorGrid(behaviors, _primaryColor),
                    SizedBox(height: 16.h),

                    // ── ملاحظات ───────────────────────────────────────────────────────
                    _sectionTitle(
                        "ملاحظات (اختياري)", Icons.notes, _primaryColor),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "تفاصيل إضافية...",
                        hintStyle: GoogleFonts.cairo(color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                      style: GoogleFonts.cairo(),
                    ),
                    SizedBox(height: 24.h),

                    // ── زر التسجيل ────────────────────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _submit(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(
                              _tabController.index == 0
                                  ? Icons.star
                                  : Icons.refresh,
                              color: Colors.white),
                      label: Text(
                        _tabController.index == 0
                            ? "تسجيل سلوك التميز"
                            : "تسجيل السلوك التعويضي",
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp),
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 20.sp),
      SizedBox(width: 8.w),
      Text(title,
          style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E))),
    ]);
  }

  Widget _buildBehaviorGrid(List<_BehaviorItem> behaviors, Color color) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: behaviors.asMap().entries.map((entry) {
        final i = entry.key;
        final b = entry.value;
        final isSelected = _selectedBehavior == b.title;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedBehavior = b.title;
              _selectedPoints = b.points;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(b.title,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text("+${b.points} نقطة",
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
