import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SeedOmarSchoolScreen extends ConsumerStatefulWidget {
  const SeedOmarSchoolScreen({super.key});

  @override
  ConsumerState<SeedOmarSchoolScreen> createState() =>
      _SeedOmarSchoolScreenState();
}

class _SeedOmarSchoolScreenState extends ConsumerState<SeedOmarSchoolScreen> {
  bool _isRunning = false;
  bool _done = false;
  String? _schoolId;
  List<Map<String, dynamic>> _staff = [];
  String? _error;

  Future<void> _run() async {
    setState(() { _isRunning = true; _error = null; });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('seedOmarSchool',
              options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
          .call();
      final data = result.data as Map<String, dynamic>;
      final staffRaw = data['staff'] as List<dynamic>? ?? [];
      setState(() {
        _done = true;
        _schoolId = data['schoolId'] as String?;
        _staff = staffRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إنشاء مدرسة عمر بن أبي سلمة',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
            Text('35 معلم + 4 مرشدين + 21 فصل',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── معلومات المدرسة ──────────────────────────────────────
            _infoCard(),
            SizedBox(height: 20.h),

            // ─── زر التشغيل ───────────────────────────────────────────
            if (!_done) ...[
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                icon: _isRunning
                    ? SizedBox(width: 20.w, height: 20.w,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.rocket_launch, size: 22.sp),
                label: Text(
                  _isRunning ? 'جاري الإنشاء... (قد يستغرق دقيقة)' : '🚀 إنشاء المدرسة الآن',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Text('❌ $_error',
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12.sp)),
                ),
              ],
            ],

            // ─── النتائج ──────────────────────────────────────────────
            if (_done) ...[
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ تم إنشاء المدرسة بنجاح!',
                        style: TextStyle(color: Colors.green.shade300,
                            fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(height: 6.h),
                    Text('معرف المدرسة: ${_schoolId ?? '-'}',
                        style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                    Text('عدد الكادر: ${_staff.length} شخص',
                        style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _buildTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('🏫', 'الاسم', 'مدرسة عمر بن أبي سلمة المتوسطة'),
          _row('📍', 'الموقع', 'الرياض — المملكة العربية السعودية'),
          _row('🎓', 'المرحلة', 'المتوسطة (أول — ثاني — ثالث)'),
          _row('♿', 'التربية الخاصة', 'مفعّلة (فصول عوق)'),
          _row('👤', 'المدير', 'عمر عبدالله الأموي — 0555110822'),
          _row('📚', 'الفصول', '21 فصل (6 عادي + 1 عوق لكل مرحلة)'),
          _row('👨‍🏫', 'المعلمون', '36 معلم بمختلف التخصصات'),
          _row('🧭', 'المرشدون', '4 مرشدين طلابيين'),
          _row('⭐', 'الخطة', 'Elite — كامل الميزات'),
        ],
      ),
    );
  }

  Widget _row(String icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$icon ', style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 4.w),
          Text('$label: ', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
          Expanded(child: Text(value,
              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withValues(alpha: 0.6),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12.r),
                topLeft: Radius.circular(12.r),
              ),
            ),
            child: Row(children: [
              _th('#', 40),
              _th('الاسم', 160),
              _th('الدور', 120),
              _th('كود الدخول', 110),
              _th('كلمة المرور', 100),
            ]),
          ),
          // Rows
          ...List.generate(_staff.length, (i) {
            final s = _staff[i];
            final isEven = i % 2 == 0;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
              color: isEven
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.transparent,
              child: Row(children: [
                _td('${i + 1}', 40, Colors.white38),
                _td(s['name'] ?? '', 160, Colors.white),
                _td(s['role'] ?? '', 120, Colors.white70),
                _td(s['username'] ?? '', 110, Colors.blue.shade300, mono: true),
                _td(s['password'] ?? '', 100, Colors.amber.shade300, mono: true),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _th(String text, double width) {
    return SizedBox(
      width: width.w,
      child: Text(text,
          style: TextStyle(color: Colors.white70, fontSize: 11.sp,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _td(String text, double width, Color color, {bool mono = false}) {
    return SizedBox(
      width: width.w,
      child: Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: mono ? 12.sp : 11.sp,
            fontFamily: mono ? 'monospace' : null,
            fontWeight: mono ? FontWeight.bold : FontWeight.normal,
          )),
    );
  }
}
