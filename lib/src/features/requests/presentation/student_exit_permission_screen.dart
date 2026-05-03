// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import '../../auth/presentation/auth_controller.dart';
import '../../../core/utils/web_utils.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class StudentInfo {
  final String id;
  final String name;
  final String className;
  final String? studentCode;
  final String? photoUrl;

  const StudentInfo({
    required this.id,
    required this.name,
    required this.className,
    this.studentCode,
    this.photoUrl,
  });

  factory StudentInfo.fromFirestore(Map<String, dynamic> data, String docId) {
    return StudentInfo(
      id: docId,
      name: data['name'] ?? data['fullName'] ?? '',
      className: data['className'] ?? data['class'] ?? data['grade'] ?? '',
      studentCode: data['studentCode'] ?? data['identityNumber'],
      photoUrl: data['profileImageUrl'],
    );
  }
}

class ExitPermission {
  final String? id;
  final String studentId;
  final String studentName;
  final String className;
  final String reason;
  final String customReason;
  final String issuedBy;
  final DateTime issuedAt;
  final String schoolId;
  final int permissionNumber;

  const ExitPermission({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.reason,
    required this.customReason,
    required this.issuedBy,
    required this.issuedAt,
    required this.schoolId,
    required this.permissionNumber,
  });

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'reason': reason,
        'customReason': customReason,
        'issuedBy': issuedBy,
        'issuedAt': Timestamp.fromDate(issuedAt),
        'schoolId': schoolId,
        'permissionNumber': permissionNumber,
      };

  factory ExitPermission.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return ExitPermission(
      id: docId,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      reason: data['reason'] ?? '',
      customReason: data['customReason'] ?? '',
      issuedBy: data['issuedBy'] ?? '',
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schoolId: data['schoolId'] ?? '',
      permissionNumber: data['permissionNumber'] ?? 0,
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final _schoolNameProvider =
    FutureProvider.family<String, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return 'المدرسة';
  final doc = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .get();
  return doc.data()?['name'] ?? 'المدرسة';
});

final _todayCountProvider =
    StreamProvider.family<int, String>((ref, schoolId) {
  if (schoolId.isEmpty) return Stream.value(0);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('ExitPermissions')
      .where('issuedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('issuedAt', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((s) => s.docs.length);
});

final _monthCountProvider =
    StreamProvider.family<int, String>((ref, schoolId) {
  if (schoolId.isEmpty) return Stream.value(0);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('ExitPermissions')
      .where('issuedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .snapshots()
      .map((s) => s.docs.length);
});

final _recentPermissionsProvider =
    StreamProvider.family<List<ExitPermission>, String>((ref, schoolId) {
  if (schoolId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('ExitPermissions')
      .orderBy('issuedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ExitPermission.fromFirestore(d.data(), d.id))
          .toList());
});


// ─── Main Screen ─────────────────────────────────────────────────────────────

class StudentExitPermissionScreen extends ConsumerStatefulWidget {
  const StudentExitPermissionScreen({super.key});

  @override
  ConsumerState<StudentExitPermissionScreen> createState() =>
      _StudentExitPermissionScreenState();
}

class _StudentExitPermissionScreenState
    extends ConsumerState<StudentExitPermissionScreen> {
  // Controllers
  final _searchController = TextEditingController();
  final _customReasonController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // State
  StudentInfo? _selectedStudent;
  List<StudentInfo> _searchResults = [];
  bool _isSearching = false;
  bool _isIssuing = false;
  String _selectedReason = 'مراجعة طبية';
  bool _showCustomReason = false;
  String? _errorMessage;
  String? _successMessage;

  static const List<String> _reasons = [
    'مراجعة طبية',
    'ظروف عائلية',
    'طارئ',
    'أخرى',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _customReasonController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _schoolId {
    final user = ref.read(authStateProvider).value;
    return user?.schoolId ?? '';
  }

  String get _issuerName {
    final user = ref.read(authStateProvider).value;
    return user?.name ?? 'مستخدم';
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final schoolId = _schoolId;
      if (schoolId.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }

      final q = query.trim();
      final col = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Students');

      // Search by name prefix
      final nameSnap = await col
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(10)
          .get();

      // Search by studentCode
      final codeSnap = await col
          .where('studentCode', isGreaterThanOrEqualTo: q.toUpperCase())
          .where('studentCode',
              isLessThanOrEqualTo: '${q.toUpperCase()}\uf8ff')
          .limit(5)
          .get();

      final seen = <String>{};
      final results = <StudentInfo>[];

      for (final doc in [...nameSnap.docs, ...codeSnap.docs]) {
        if (seen.add(doc.id)) {
          final info = StudentInfo.fromFirestore(doc.data(), doc.id);
          if (info.name.isNotEmpty) results.add(info);
        }
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectStudent(StudentInfo student) {
    setState(() {
      _selectedStudent = student;
      _searchResults = [];
      _searchController.text = student.name;
      _errorMessage = null;
      _successMessage = null;
    });
    _searchFocusNode.unfocus();
  }

  // ── Issue Permission ─────────────────────────────────────────────────────────

  Future<void> _issuePermission() async {
    if (_selectedStudent == null) {
      setState(() => _errorMessage = 'يرجى اختيار طالب أولاً');
      return;
    }
    if (_showCustomReason && _customReasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة سبب الخروج');
      return;
    }

    setState(() {
      _isIssuing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final schoolId = _schoolId;
      final issuerName = _issuerName;
      final now = DateTime.now();

      // Count today's permissions for sequential number
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final countSnap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('ExitPermissions')
          .where('issuedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('issuedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();

      final permissionNumber = (countSnap.count ?? 0) + 1;

      final finalReason = _showCustomReason
          ? _customReasonController.text.trim()
          : _selectedReason;

      final permission = ExitPermission(
        studentId: _selectedStudent!.id,
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        reason: _selectedReason,
        customReason: _showCustomReason ? _customReasonController.text.trim() : '',
        issuedBy: issuerName,
        issuedAt: now,
        schoolId: schoolId,
        permissionNumber: permissionNumber,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('ExitPermissions')
          .add(permission.toMap());

      // Fetch school name for print
      final schoolDoc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .get();
      final schoolName = schoolDoc.data()?['name'] ?? 'المدرسة';

      setState(() {
        _isIssuing = false;
        _successMessage = 'تم إصدار إذن الخروج رقم ${permissionNumber.toString().padLeft(5, '0')} بنجاح';
      });

      // Print
      _printPermission(
        permissionNumber: permissionNumber,
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        reason: finalReason,
        issuedBy: issuerName,
        issuedAt: now,
        schoolName: schoolName,
        docId: docRef.id,
      );

      // Reset form after short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _selectedStudent = null;
          _searchController.clear();
          _customReasonController.clear();
          _selectedReason = 'مراجعة طبية';
          _showCustomReason = false;
        });
      }
    } catch (e) {
      setState(() {
        _isIssuing = false;
        _errorMessage = 'حدث خطأ أثناء الحفظ: ${e.toString()}';
      });
    }
  }

  // ── Print ────────────────────────────────────────────────────────────────────

  void _printPermission({
    required int permissionNumber,
    required String studentName,
    required String className,
    required String reason,
    required String issuedBy,
    required DateTime issuedAt,
    required String schoolName,
    required String docId,
  }) {
    final dateStr = intl.DateFormat('yyyy/MM/dd').format(issuedAt);
    final timeStr = intl.DateFormat('hh:mm a').format(issuedAt);
    final numStr  = permissionNumber.toString().padLeft(5, '0');

    // شعار الوزارة من web folder
    const logoUrl = '/logokshuf.webp';

    final css = '''
<style>
  @page{size:A4 portrait;margin:15mm 25mm}
  @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&display=swap');
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:'Cairo',Arial,sans-serif;background:#e8edf2;display:flex;justify-content:center;align-items:flex-start;min-height:100vh;padding:20px 15px}
  .slip{background:#fff;width:140mm;max-width:100%;border-radius:4px;overflow:hidden;border:2.5px solid #000;box-shadow:0 4px 20px rgba(0,0,0,.15)}

  /* ── الهيدر ── */
  .header{background:#fff;color:#000;padding:14px 22px;display:flex;align-items:center;gap:12px;border-bottom:2.5px solid #000}
  .header-logo{width:52px;height:52px;object-fit:contain;flex-shrink:0}
  .header-center{flex:1;text-align:center}
  .header-center .ministry{font-size:8.5px;color:#1a3a5c;letter-spacing:.4px;margin-bottom:2px;font-weight:600}
  .header-center .school-name{font-size:15px;font-weight:900;color:#000}
  .header-center .sub{font-size:8.5px;color:#1a3a5c;margin-top:2px;font-weight:600}
  .header-num{text-align:left;min-width:70px}
  .header-num .lbl{font-size:8px;color:#555;display:block;margin-bottom:1px;font-weight:600}
  .header-num .num-val{font-size:17px;font-weight:900;color:#1a3a5c;display:block;letter-spacing:1px}

  /* ── شريط العنوان ── */
  .title-bar{background:linear-gradient(90deg,#d97706,#f59e0b,#d97706);padding:10px 22px;text-align:center;border-bottom:2.5px solid #000}
  .title-bar h1{color:#000;font-size:18px;font-weight:900;letter-spacing:1px}

  /* ── الجسم ── */
  .body{padding:18px 22px}
  .intro{font-size:11px;color:#222;margin-bottom:16px;line-height:1.9;border-right:4px solid #000;padding:8px 12px 8px 8px;background:#f9f9f9;border-radius:0 5px 5px 0}
  .fields-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}
  .field{background:#fff;border:1.5px solid #000;border-radius:5px;padding:9px 12px}
  .field.full{grid-column:1/-1}
  .field-label{font-size:8px;color:#555;font-weight:700;margin-bottom:4px;text-transform:uppercase;letter-spacing:.6px}
  .field-value{font-size:13px;font-weight:800;color:#000;line-height:1.3}

  /* ── الفوتر ── */
  .footer{background:#fff;border-top:2.5px solid #000;padding:9px 22px;display:flex;justify-content:space-between;align-items:center;font-size:9px;color:#000;font-weight:600}
  .validity-badge{background:linear-gradient(90deg,#f59e0b,#fbbf24);border:1.5px solid #000;border-radius:20px;padding:3px 12px;font-size:10px;color:#000;font-weight:800}

  @media print{
    body{background:#fff;padding:0;justify-content:center}
    .slip{box-shadow:none;border-radius:0;width:140mm;max-width:140mm}
    .header,.title-bar,.footer,.field{-webkit-print-color-adjust:exact;print-color-adjust:exact}
  }
</style>''';

    final html = '<!DOCTYPE html><html dir="rtl" lang="ar"><head>'
        '<meta charset="UTF-8"><title>إذن خروج - $numStr</title>'
        '$css'
        '</head><body><div class="slip">'
        // Header
        '<div class="header">'
          '<img class="header-logo" src="$logoUrl" alt="شعار الوزارة" onerror="this.style.display=\'none\'">'
          '<div class="header-center">'
            '<div class="ministry">وزارة التعليم — المملكة العربية السعودية</div>'
            '<div class="school-name">$schoolName</div>'
            '<div class="sub">إدارة شؤون الطلاب</div>'
          '</div>'
          '<div class="header-num"><span class="lbl">رقم الإذن</span><span class="num-val">#$numStr</span></div>'
        '</div>'
        // Title
        '<div class="title-bar"><h1>إذن خروج من المدرسة</h1></div>'
        // Body
        '<div class="body">'
          '<div class="intro">يُشهد بموجب هذا الإذن أنه قد سُمح للطالب المذكور أدناه بمغادرة المدرسة في التاريخ والوقت المحددين، وذلك للسبب الوارد ذكره.</div>'
          '<div class="fields-grid">'
            '<div class="field"><div class="field-label">اسم الطالب</div><div class="field-value">$studentName</div></div>'
            '<div class="field"><div class="field-label">الفصل الدراسي</div><div class="field-value">$className</div></div>'
            '<div class="field"><div class="field-label">تاريخ الخروج</div><div class="field-value">$dateStr</div></div>'
            '<div class="field"><div class="field-label">وقت الخروج</div><div class="field-value">$timeStr</div></div>'
            '<div class="field full"><div class="field-label">سبب الخروج</div><div class="field-value">$reason</div></div>'
            '<div class="field full"><div class="field-label">اسم المسؤول المُصدِر</div><div class="field-value">$issuedBy</div></div>'
          '</div>'
        '</div>'
        // Footer
        '<div class="footer">'
          '<span>رقم المرجع: #$numStr</span>'
          '<span class="validity-badge">صالح ليوم واحد فقط</span>'
          '<span>$dateStr</span>'
        '</div>'
        '</div></body></html>';

    // تحويل HTML لـ JS string آمن
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');

    js_print_web(escaped);
  }

  // ignore: non_constant_identifier_names
  void js_print_web(String escaped) {
    if (!kIsWeb) return;
    evalJavaScript(
      "(function(){"
      "var win=window.open('','_blank','width=900,height=700');"
      "if(!win){alert('يرجى السماح بالنوافذ المنبثقة لطباعة الإذن');return;}"
      "win.document.open();"
      "win.document.write('$escaped');"
      "win.document.close();"
      "win.focus();"
      "setTimeout(function(){win.print();},600);"
      "})();"
    );
  }
  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final schoolId = authState.value?.schoolId ?? '';
    final issuerName = authState.value?.name ?? 'مستخدم';
    final isWide = MediaQuery.of(context).size.width >= 900;

    final todayCount = ref.watch(_todayCountProvider(schoolId));
    final monthCount = ref.watch(_monthCountProvider(schoolId));
    final schoolNameAsync = ref.watch(_schoolNameProvider(schoolId));
    final recentPermissions = ref.watch(_recentPermissionsProvider(schoolId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: _buildAppBar(schoolNameAsync),
        body: Column(
          children: [
            _buildStatsBar(todayCount, monthCount),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildFormPanel(issuerName),
                        ),
                        Container(width: 1, color: const Color(0xFF1E3A5F)),
                        Expanded(
                          flex: 4,
                          child: _buildRecentList(recentPermissions),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildFormPanel(issuerName),
                          _buildRecentList(recentPermissions),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AsyncValue<String> schoolNameAsync) {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إذن خروج الطلاب',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          schoolNameAsync.when(
            data: (name) => Text(
              name,
              style: TextStyle(color: Colors.amber.shade300, fontSize: 11.sp),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(left: 12.w, top: 8.h, bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.amber, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                'إذن خروج',
                style: TextStyle(color: Colors.amber, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(AsyncValue<int> todayCount, AsyncValue<int> monthCount) {
    return Container(
      color: const Color(0xFF0F2236),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.today,
            label: 'اليوم',
            value: todayCount.when(data: (v) => v.toString(), loading: () => '...', error: (_, __) => '0'),
            color: Colors.amber,
          ),
          SizedBox(width: 16.w),
          _buildStatChip(
            icon: Icons.calendar_month,
            label: 'هذا الشهر',
            value: monthCount.when(data: (v) => v.toString(), loading: () => '...', error: (_, __) => '0'),
            color: Colors.lightBlueAccent,
          ),
          const Spacer(),
          Icon(Icons.info_outline, color: Colors.white30, size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            'يتم الحفظ تلقائياً في Firestore',
            style: TextStyle(color: Colors.white30, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(color: Colors.white60, fontSize: 11.sp)),
          SizedBox(width: 6.w),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(String issuerName) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.search, 'البحث عن طالب'),
          SizedBox(height: 12.h),
          _buildSearchField(),
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          if (_selectedStudent != null) ...[
            SizedBox(height: 16.h),
            _buildStudentCard(),
          ],
          SizedBox(height: 20.h),
          _buildSectionHeader(Icons.assignment_outlined, 'سبب الخروج'),
          SizedBox(height: 12.h),
          _buildReasonDropdown(),
          if (_showCustomReason) ...[
            SizedBox(height: 12.h),
            _buildCustomReasonField(),
          ],
          SizedBox(height: 20.h),
          _buildSectionHeader(Icons.person_outline, 'المسؤول المُصدِر'),
          SizedBox(height: 12.h),
          _buildIssuerField(issuerName),
          SizedBox(height: 24.h),
          if (_errorMessage != null) _buildMessage(_errorMessage!, isError: true),
          if (_successMessage != null) _buildMessage(_successMessage!, isError: false),
          SizedBox(height: 8.h),
          _buildIssueButton(),
          SizedBox(height: 10.h),
          // زر تصفير النموذج
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedStudent = null;
                  _searchController.clear();
                  _searchResults = [];
                  _customReasonController.clear();
                  _selectedReason = 'مراجعة طبية';
                  _showCustomReason = false;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
              icon: Icon(Icons.refresh_rounded, size: 18.sp, color: Colors.white54),
              label: Text(
                'تصفير النموذج',
                style: TextStyle(fontSize: 13.sp, color: Colors.white54),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(icon, color: Colors.amber, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A5080)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث باسم الطالب أو رمزه...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
          prefixIcon: _isSearching
              ? Padding(
                  padding: EdgeInsets.all(12.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  ),
                )
              : Icon(Icons.search, color: Colors.white38, size: 20.sp),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white38, size: 18.sp),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _selectedStudent = null;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
        onChanged: (v) {
          if (_selectedStudent != null && v != _selectedStudent!.name) {
            setState(() => _selectedStudent = null);
          }
          _searchStudents(v);
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3050),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A5080)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _searchResults.map((student) {
          return InkWell(
            onTap: () => _selectStudent(student),
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: Text(
                      student.name.isNotEmpty ? student.name[0] : '؟',
                      style: TextStyle(color: Colors.amber, fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        if (student.className.isNotEmpty)
                          Text(
                            student.className,
                            style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                          ),
                      ],
                    ),
                  ),
                  if (student.studentCode != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        student.studentCode!,
                        style: TextStyle(color: Colors.white54, fontSize: 10.sp),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentCard() {
    final student = _selectedStudent!;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.amber.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: Colors.amber.withOpacity(0.2),
            backgroundImage: student.photoUrl != null
                ? NetworkImage(student.photoUrl!)
                : null,
            child: student.photoUrl == null
                ? Text(
                    student.name.isNotEmpty ? student.name[0] : '؟',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.class_outlined, color: Colors.amber, size: 13.sp),
                    SizedBox(width: 4.w),
                    Text(
                      student.className.isNotEmpty ? student.className : 'غير محدد',
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 12.sp),
                    ),
                    if (student.studentCode != null) ...[
                      SizedBox(width: 12.w),
                      Icon(Icons.badge_outlined, color: Colors.white38, size: 13.sp),
                      SizedBox(width: 4.w),
                      Text(
                        student.studentCode!,
                        style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.green, size: 16.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A5080)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReason,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A3050),
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20.sp),
          items: _reasons.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Text(r, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _selectedReason = v;
                _showCustomReason = v == 'أخرى';
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomReasonField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: TextField(
        controller: _customReasonController,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        textDirection: TextDirection.rtl,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'اكتب سبب الخروج...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14.w),
        ),
      ),
    );
  }

  Widget _buildIssuerField(String issuerName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A5080)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.white38, size: 18.sp),
          SizedBox(width: 10.w),
          Text(
            issuerName,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              'تلقائي',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isError
              ? Colors.red.withOpacity(0.4)
              : Colors.green.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 18.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade300 : Colors.green.shade300,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton.icon(
        onPressed: _isIssuing ? null : _issuePermission,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.amber.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 4,
        ),
        icon: _isIssuing
            ? SizedBox(
                width: 18.w,
                height: 18.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black54,
                ),
              )
            : Icon(Icons.print, size: 20.sp),
        label: Text(
          _isIssuing ? 'جاري الإصدار...' : 'إصدار الإذن وطباعته',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── حذف جميع الأذونات ────────────────────────────────────────────────────────
  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A3050),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade300, size: 22.sp),
          SizedBox(width: 8.w),
          Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'هل تريد حذف جميع الأذونات السابقة؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: Colors.white70, fontSize: 13.sp, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(Icons.delete_forever, size: 16.sp),
            label: Text('حذف الكل', style: TextStyle(fontSize: 13.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final sid = _schoolId;
      if (sid.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection('Schools').doc(sid)
          .collection('ExitPermissions').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم حذف ${snap.docs.length} إذن بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildRecentList(AsyncValue<List<ExitPermission>> recentPermissions) {
    return Container(
      color: const Color(0xFF0F2236),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(Icons.history, color: Colors.lightBlueAccent, size: 16.sp),
                ),
                SizedBox(width: 8.w),
                Text(
                  'آخر الأذونات الصادرة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // زر حذف جميع الأذونات
                GestureDetector(
                  onTap: () => _confirmDeleteAll(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.red.shade300, size: 14.sp),
                        SizedBox(width: 5.w),
                        Text(
                          'حذف الكل',
                          style: TextStyle(color: Colors.red.shade300, fontSize: 11.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          recentPermissions.when(
            data: (permissions) {
              if (permissions.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, color: Colors.white24, size: 40.sp),
                        SizedBox(height: 12.h),
                        Text(
                          'لا توجد أذونات بعد',
                          style: TextStyle(color: Colors.white38, fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: permissions.length,
                separatorBuilder: (_, __) => Divider(
                  color: Colors.white10,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final p = permissions[index];
                  return _buildPermissionTile(p);
                },
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.all(40.w),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
            error: (e, _) => Padding(
              padding: EdgeInsets.all(20.w),
              child: Text(
                'خطأ في تحميل البيانات',
                style: TextStyle(color: Colors.red.shade300, fontSize: 12.sp),
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(ExitPermission p) {
    final timeStr = intl.DateFormat('hh:mm a', 'ar').format(p.issuedAt);
    final dateStr = intl.DateFormat('dd/MM', 'ar').format(p.issuedAt);
    final numStr = p.permissionNumber.toString().padLeft(5, '0');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                '#',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.studentName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      p.className,
                      style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(color: Colors.white24, fontSize: 11.sp),
                    ),
                    Text(
                      p.reason,
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 11.sp),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(color: Colors.white70, fontSize: 11.sp),
              ),
              Text(
                dateStr,
                style: TextStyle(color: Colors.white38, fontSize: 10.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
