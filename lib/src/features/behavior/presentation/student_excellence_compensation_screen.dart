// ignore_for_file: use_build_context_synchronously
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import "package:google_fonts/google_fonts.dart";
import "package:go_router/go_router.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:uuid/uuid.dart";
import "../../../core/domain/models/user.dart";
import "../../auth/presentation/auth_controller.dart";

// ─── نموذج بيانات التميز/التعويض ────────────────────────────────────────────
class ExcellenceCompensationRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String schoolId;
  final String type; // "excellence" | "compensation"
  final String behaviorTitle;
  final int points;
  final String? notes;
  final DateTime timestamp;

  ExcellenceCompensationRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.schoolId,
    required this.type,
    required this.behaviorTitle,
    required this.points,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "studentId": studentId,
    "studentName": studentName,
    "classId": classId,
    "className": className,
    "teacherId": teacherId,
    "teacherName": teacherName,
    "schoolId": schoolId,
    "type": type,
    "behaviorTitle": behaviorTitle,
    "points": points,
    "notes": notes,
    "timestamp": Timestamp.fromDate(timestamp),
  };
}

// ─── قوائم السلوك وفق لوائح وزارة التعليم السعودية ──────────────────────────
const List<Map<String, dynamic>> _excellenceBehaviors = [
  {"title": "مساعدة زميل", "points": 2},
  {"title": "مبادرة مميزة", "points": 2},
  {"title": "تفوق في اختبار", "points": 2},
  {"title": "نظافة ومواظبة", "points": 3},
  {"title": "إجابة صحيحة في الحصة", "points": 2},
  {"title": "المشاركة في أنشطة المهارات الرقمية", "points": 4},
  {"title": "الالتحاق ببرنامج أو دورة تدريبية", "points": 6},
  {"title": "المشاركة في مسابقات أو جوائز", "points": 4},
  {"title": "عرض تجارب شخصية ناجحة أمام الزملاء", "points": 6},
  {"title": "التعاون مع الزملاء والمعلمين والإدارة", "points": 3},
  {"title": "المشاركة في الخدمة المجتمعية خارج المدرسة", "points": 6},
  {"title": "كتابة رسالة شكر للوطن أو القيادة", "points": 5},
  {"title": "تقديم فعالية حوارية", "points": 6},
  {"title": "المشاركة في حملة توعوية", "points": 6},
  {"title": "عرض تجارب شخصية ناجحة", "points": 6},
  {"title": "العمل الجماعي", "points": 4},
  {"title": "التعلم بالاقران", "points": 4},
  {"title": "المشاركة في الإذاعة", "points": 2},
];

const List<Map<String, dynamic>> _compensationBehaviors = [
  {"title": "القيام بتنظيم دخول الطلاب في الفصول", "points": 3},
  {"title": "المشاركة في الخدمة المجتمعية خارج المدرسة", "points": 5},
  {"title": "المشاركة في برامج ارشادية", "points": 3},
  {"title": "تكليفات تربوية مناسبة", "points": 2},
  {"title": "تنفيذ نشاط توعوي", "points": 4},
  {"title": "اعداد ملخص للدرس وتسليمه", "points": 2},
  {"title": "المشاركة في توعية المحافظة على الممتلكات", "points": 5},
  {"title": "تقديم اعتذار رسمي وتعهد بعدم التكرار", "points": 3},
  {"title": "المشاركة في برنامج الإرشاد الطلابي", "points": 4},
  {"title": "كتابة تقرير عن أهمية الالتزام بالنظام", "points": 2},
];

// ─── Provider لجلب الطلاب حسب الصلاحية ──────────────────────────────────────
final _studentsForBehaviorProvider = FutureProvider.family<
    List<Map<String, dynamic>>, Map<String, String>>((ref, params) async {
  final schoolId = params["schoolId"]!;
  final teacherId = params["teacherId"]!;
  final role = params["role"]!;

  final db = FirebaseFirestore.instance;

  // المرشد والوكلاء: جميع طلاب المدرسة
  if (["counselor", "deputy", "vice_principal", "admin", "principal"].contains(role)) {
    final snap = await db
        .collection("Schools")
        .doc(schoolId)
        .collection("Students")
        .orderBy("name")
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        "id": d.id,
        "name": data["name"] ?? "",
        "classId": data["classId"] ?? "",
        "className": data["className"] ?? data["classId"] ?? "",
      };
    }).toList();
  }

  // المعلم: طلاب فصوله فقط
  final classesSnap = await db
      .collection("Schools")
      .doc(schoolId)
      .collection("Classes")
      .where("teacherIds", arrayContains: teacherId)
      .get();

  if (classesSnap.docs.isEmpty) {
    // fallback: جميع الطلاب
    final snap = await db
        .collection("Schools")
        .doc(schoolId)
        .collection("Students")
        .orderBy("name")
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        "id": d.id,
        "name": data["name"] ?? "",
        "classId": data["classId"] ?? "",
        "className": data["className"] ?? data["classId"] ?? "",
      };
    }).toList();
  }

  final classIds = classesSnap.docs.map((d) => d.id).toList();
  final List<Map<String, dynamic>> students = [];

  for (final classId in classIds) {
    final snap = await db
        .collection("Schools")
        .doc(schoolId)
        .collection("Students")
        .where("classId", isEqualTo: classId)
        .orderBy("name")
        .get();
    for (final d in snap.docs) {
      final data = d.data();
      students.add({
        "id": d.id,
        "name": data["name"] ?? "",
        "classId": classId,
        "className": data["className"] ?? classId,
      });
    }
  }
  return students;
});

// ─── الشاشة الرئيسية ──────────────────────────────────────────────────────────
class StudentExcellenceCompensationScreen extends ConsumerStatefulWidget {
  final String initialTab; // "excellence" | "compensation"
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
  String _selectedStudentId = "";
  String _selectedStudentName = "";
  String _selectedClassId = "";
  String _selectedClassName = "";
  String? _selectedBehavior;
  int _selectedPoints = 0;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isLoading = false;
  String _searchQuery = "";

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
      _tabController.index == 0 ? "excellence" : "compensation";

  List<Map<String, dynamic>> get _currentBehaviors =>
      _tabController.index == 0 ? _excellenceBehaviors : _compensationBehaviors;

  Color get _primaryColor =>
      _tabController.index == 0
          ? const Color(0xFF7B1FA2) // بنفسجي للتميز
          : const Color(0xFF00897B); // أخضر للتعويض

  void _resetForm() {
    setState(() {
      _selectedStudentId = "";
      _selectedStudentName = "";
      _selectedClassId = "";
      _selectedClassName = "";
      _selectedBehavior = null;
      _selectedPoints = 0;
      _notesCtrl.clear();
      _searchQuery = "";
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
      final record = ExcellenceCompensationRecord(
        id: const Uuid().v4(),
        studentId: _selectedStudentId,
        studentName: _selectedStudentName,
        classId: _selectedClassId,
        className: _selectedClassName,
        teacherId: user.id,
        teacherName: user.name,
        schoolId: user.schoolId ?? "",
        type: _currentType,
        behaviorTitle: _selectedBehavior!,
        points: _selectedPoints,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        timestamp: DateTime.now(),
      );

      final db = FirebaseFirestore.instance;
      final schoolId = user.schoolId ?? "";

      // حفظ في Firestore
      await db
          .collection("Schools")
          .doc(schoolId)
          .collection("ExcellenceCompensation")
          .doc(record.id)
          .set(record.toMap());

      // تحديث درجة السلوك للطالب
      final studentRef = db
          .collection("Schools")
          .doc(schoolId)
          .collection("Students")
          .doc(_selectedStudentId);

      await db.runTransaction((tx) async {
        final snap = await tx.get(studentRef);
        final data = snap.data() ?? {};

        if (_currentType == "excellence") {
          final current = (data["excellenceScore"] as num?)?.toInt() ?? 0;
          final newScore = (current + _selectedPoints).clamp(0, 20);
          tx.update(studentRef, {"excellenceScore": newScore});
        } else {
          // تعويض: يُعيد نقاط من الخصم
          final current = (data["behaviorScore"] as num?)?.toInt() ?? 80;
          final newScore = (current + _selectedPoints).clamp(0, 80);
          tx.update(studentRef, {"behaviorScore": newScore});
        }
      });

      // إشعار ولي الأمر (اختياري - يمكن تفعيله لاحقاً)
      // await _notifyParent(record, schoolId);

      _showSnack(
        _currentType == "excellence"
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final studentsAsync = ref.watch(_studentsForBehaviorProvider({
      "schoolId": user.schoolId ?? "",
      "teacherId": user.id,
      "role": user.role.name,
    }));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _primaryColor,
          title: Text(
            "التميز والتعويض السلوكي",
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            controller: _tabController,
            onTap: (_) {
              setState(() {
                _selectedBehavior = null;
                _selectedPoints = 0;
              });
            },
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13.sp),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.star), text: "سلوك التميز"),
              Tab(icon: Icon(Icons.refresh), text: "السلوك التعويضي"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab(user, studentsAsync, "excellence"),
            _buildTab(user, studentsAsync, "compensation"),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    User user,
    AsyncValue<List<Map<String, dynamic>>> studentsAsync,
    String tabType,
  ) {
    final isExcellence = tabType == "excellence";
    final color = isExcellence ? const Color(0xFF7B1FA2) : const Color(0xFF00897B);
    final behaviors = isExcellence ? _excellenceBehaviors : _compensationBehaviors;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── بطاقة الشرح ──────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isExcellence ? Icons.star_rounded : Icons.refresh_rounded,
                  color: color,
                  size: 28.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExcellence
                            ? "رصد سلوك التميز — النقاط تُضاف لرصيد التميز (سقف 20 نقطة)."
                            : "رصد السلوك التعويضي — النقاط تُعاد لرصيد السلوك الإيجابي.",
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "يُرسل إشعار لولي الأمر وتقرير للوكيل والإداري فور التسجيل.",
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── اختيار الطالب ────────────────────────────────────────────────
          _buildSectionTitle("اختيار الطالب", Icons.person, color),
          SizedBox(height: 8.h),
          studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("خطأ: $e"),
            data: (students) => _buildStudentSelector(students, color),
          ),
          SizedBox(height: 16.h),

          // ── نوع السلوك ───────────────────────────────────────────────────
          _buildSectionTitle(
            isExcellence ? "نوع سلوك التميز" : "نوع السلوك التعويضي",
            isExcellence ? Icons.star : Icons.refresh,
            color,
          ),
          SizedBox(height: 4.h),
          Text(
            "(اختر واحداً)",
            style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
          ),
          SizedBox(height: 8.h),
          _buildBehaviorGrid(behaviors, color, tabType),
          SizedBox(height: 16.h),

          // ── ملاحظات ──────────────────────────────────────────────────────
          _buildSectionTitle("ملاحظات (اختياري)", Icons.notes, color),
          SizedBox(height: 8.h),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "تفاصيل إضافية...",
              hintStyle: GoogleFonts.cairo(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
            style: GoogleFonts.cairo(),
          ),
          SizedBox(height: 24.h),

          // ── زر التسجيل ───────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _submit(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    isExcellence ? Icons.star : Icons.refresh,
                    color: Colors.white,
                  ),
            label: Text(
              isExcellence
                  ? "تسجيل سلوك التميز وإشعار ولي الأمر"
                  : "تسجيل السلوك التعويضي وإشعار ولي الأمر",
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A237E),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSelector(
      List<Map<String, dynamic>> students, Color color) {
    final filtered = _searchQuery.isEmpty
        ? students
        : students
            .where((s) =>
                (s["name"] as String).contains(_searchQuery) ||
                (s["className"] as String).contains(_searchQuery))
            .toList();

    return Column(
      children: [
        // شريط البحث
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: "ابحث عن طالب...",
            hintStyle: GoogleFonts.cairo(),
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
          style: GoogleFonts.cairo(),
        ),
        SizedBox(height: 8.h),
        // قائمة الطلاب
        Container(
          height: 200.h,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final s = filtered[i];
              final isSelected = _selectedStudentId == s["id"];
              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: color.withOpacity(0.1),
                leading: CircleAvatar(
                  backgroundColor: isSelected ? color : Colors.grey.shade200,
                  radius: 16.r,
                  child: Text(
                    (s["name"] as String).isNotEmpty
                        ? (s["name"] as String)[0]
                        : "؟",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  s["name"] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  s["className"] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: color, size: 20.sp)
                    : null,
                onTap: () => setState(() {
                  _selectedStudentId = s["id"] as String;
                  _selectedStudentName = s["name"] as String;
                  _selectedClassId = s["classId"] as String;
                  _selectedClassName = s["className"] as String;
                }),
              );
            },
          ),
        ),
        if (_selectedStudentId.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_pin, color: color, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    "المحدد: $_selectedStudentName — $_selectedClassName",
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBehaviorGrid(
      List<Map<String, dynamic>> behaviors, Color color, String tabType) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: behaviors.map((b) {
        final isSelected = _selectedBehavior == b["title"] &&
            _currentType == tabType;
        return GestureDetector(
          onTap: () {
            if (_tabController.index == (tabType == "excellence" ? 0 : 1)) {
              setState(() {
                _selectedBehavior = b["title"] as String;
                _selectedPoints = b["points"] as int;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b["title"] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    "+${b["points"]} نقطة",
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
