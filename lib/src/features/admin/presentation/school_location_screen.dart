import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/presentation/auth_controller.dart';

class SchoolLocationScreen extends ConsumerStatefulWidget {
  const SchoolLocationScreen({super.key});

  @override
  ConsumerState<SchoolLocationScreen> createState() =>
      _SchoolLocationScreenState();
}

class _SchoolLocationScreenState
    extends ConsumerState<SchoolLocationScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLocating = false;
  double? _savedLat;
  double? _savedLng;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .get();
      final data = doc.data();
      if (data == null) return;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();

      if (mounted) {
        setState(() {
          _savedLat = lat;
          _savedLng = lng;
          if (lat != null) _latCtrl.text = lat.toStringAsFixed(6);
          if (lng != null) _lngCtrl.text = lng.toStringAsFixed(6);
        });
      }
    } catch (e) {
      debugPrint('Error loading school location: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('تم رفض صلاحية الموقع. يرجى السماح للتطبيق بالوصول للموقع.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('صلاحية الموقع محظورة. افتح إعدادات الجهاز وامنح الصلاحية.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latCtrl.text = position.latitude.toStringAsFixed(6);
          _lngCtrl.text = position.longitude.toStringAsFixed(6);
          _statusMsg = '✅ تم تحديد موقعك الحالي — تأكد أنك داخل المدرسة';
        });
      }
    } catch (e) {
      _showError('تعذر تحديد الموقع: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    final latText = _latCtrl.text.trim();
    final lngText = _lngCtrl.text.trim();

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      _showError('يرجى إدخال إحداثيات صحيحة (أرقام عشرية)');
      return;
    }

    if (lat < -90 || lat > 90) {
      _showError('خط العرض يجب أن يكون بين -90 و 90');
      return;
    }
    if (lng < -180 || lng > 180) {
      _showError('خط الطول يجب أن يكون بين -180 و 180');
      return;
    }

    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      _showError('لا يوجد مدرسة مرتبطة بحسابك');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .update({'latitude': lat, 'longitude': lng});

      if (mounted) {
        setState(() {
          _savedLat = lat;
          _savedLng = lng;
          _statusMsg = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ موقع المدرسة بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = _savedLat != null && _savedLng != null;

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
            Text('موقع المدرسة',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('لتفعيل إشعار وصول ولي الأمر',
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
            // ─── حالة الموقع الحالي ───────────────────────────────────
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: hasSaved
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: hasSaved
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSaved ? Icons.location_on : Icons.location_off,
                    color: hasSaved ? Colors.green : Colors.orange,
                    size: 28.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSaved
                              ? 'موقع المدرسة مسجّل ✅'
                              : 'موقع المدرسة غير مسجّل ⚠️',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                        if (hasSaved) ...[
                          SizedBox(height: 4.h),
                          Text(
                            'خط العرض: ${_savedLat!.toStringAsFixed(6)}\nخط الطول: ${_savedLng!.toStringAsFixed(6)}',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11.sp),
                          ),
                        ] else
                          Text(
                            'يجب تسجيل الموقع لتفعيل إشعار وصول ولي الأمر',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11.sp),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // ─── زر استخدام الموقع الحالي ────────────────────────────
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.my_location,
                        color: Colors.blue.shade300, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('الطريقة الأولى: موقعك الحالي',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp)),
                  ]),
                  SizedBox(height: 8.h),
                  Text(
                    'تأكد أنك داخل المدرسة أو بالقرب منها، ثم اضغط الزر أدناه.',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 11.sp),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLocating ? null : _useCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                      ),
                      icon: _isLocating
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.gps_fixed, size: 18.sp),
                      label: Text(
                        _isLocating ? 'جاري تحديد الموقع...' : 'استخدم موقعي الحالي',
                        style: TextStyle(
                            fontSize: 13.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // ─── إدخال يدوي ──────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.edit_location_alt,
                        color: Colors.purple.shade300, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('الطريقة الثانية: إدخال يدوي',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp)),
                  ]),
                  SizedBox(height: 6.h),
                  Text(
                    'ابحث عن المدرسة في Google Maps → اضغط على الموقع → انسخ الإحداثيات.',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 11.sp),
                  ),
                  SizedBox(height: 14.h),
                  _buildCoordField(
                    controller: _latCtrl,
                    label: 'خط العرض (Latitude)',
                    hint: 'مثال: 24.688916',
                    icon: Icons.swap_vert,
                  ),
                  SizedBox(height: 10.h),
                  _buildCoordField(
                    controller: _lngCtrl,
                    label: 'خط الطول (Longitude)',
                    hint: 'مثال: 46.722513',
                    icon: Icons.swap_horiz,
                  ),
                ],
              ),
            ),

            if (_statusMsg != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Text(_statusMsg!,
                    style: TextStyle(
                        color: Colors.blue.shade200, fontSize: 12.sp)),
              ),
            ],

            SizedBox(height: 24.h),

            // ─── زر الحفظ ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                icon: _isSaving
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save, size: 20.sp),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ موقع المدرسة',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ─── تعليمات Google Maps ──────────────────────────────────
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.white38, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text('كيف تحصل على الإحداثيات من Google Maps؟',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 8.h),
                  _buildStep('1', 'افتح Google Maps على جهازك'),
                  _buildStep('2', 'ابحث عن اسم المدرسة'),
                  _buildStep('3', 'اضغط مطولاً على موقع المدرسة'),
                  _buildStep('4', 'ستظهر الإحداثيات في الأسفل مثل: 24.688916, 46.722513'),
                  _buildStep('5', 'الرقم الأول هو خط العرض، والثاني خط الطول'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18.sp),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            margin: EdgeInsets.only(top: 1.h, left: 6.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: Colors.white38, fontSize: 11.sp)),
          ),
        ],
      ),
    );
  }
}
