import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../domain/school_request.dart';

class SchoolRequestScreen extends ConsumerStatefulWidget {
  const SchoolRequestScreen({super.key});

  @override
  ConsumerState<SchoolRequestScreen> createState() =>
      _SchoolRequestScreenState();
}

class _SchoolRequestScreenState extends ConsumerState<SchoolRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _adminNameController = TextEditingController(); // Updated
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentCountController = TextEditingController();

  String _selectedSchoolType = 'government'; // Default
  String _selectedSchoolStage = 'الابتدائية'; // Default
  bool _hasSpecialEducation = false;
  String _selectedCountryCode = 'SA'; // Default: السعودية
  String _selectedAdminRegion =
      'الإدارة العامة للتعليم بمنطقة الرياض'; // Default
  String _customRegion = ''; // للدول الأخرى

  // الدول المدعومة
  static const List<Map<String, String>> _countries = [
    {'code': 'SA', 'nameAr': 'المملكة العربية السعودية', 'flag': '🇸🇦'},
    {'code': 'AE', 'nameAr': 'الإمارات العربية المتحدة', 'flag': '🇦🇪'},
    {'code': 'QA', 'nameAr': 'قطر', 'flag': '🇶🇦'},
    {'code': 'KW', 'nameAr': 'الكويت', 'flag': '🇰🇼'},
    {'code': 'BH', 'nameAr': 'البحرين', 'flag': '🇧🇭'},
    {'code': 'OM', 'nameAr': 'سلطنة عُمان', 'flag': '🇴🇲'},
    {'code': 'US', 'nameAr': 'الولايات المتحدة', 'flag': '🇺🇸'},
    {'code': 'GB', 'nameAr': 'المملكة المتحدة', 'flag': '🇬🇧'},
    {'code': 'FR', 'nameAr': 'فرنسا', 'flag': '🇫🇷'},
    {'code': 'ES', 'nameAr': 'إسبانيا', 'flag': '🇪🇸'},
    {'code': 'OTHER', 'nameAr': 'دولة أخرى', 'flag': '🌍'},
  ];

  static const List<String> _adminRegions = [
    'الإدارة العامة للتعليم بمنطقة الرياض',
    'الإدارة العامة للتعليم بمنطقة مكة المكرمة',
    'الإدارة العامة للتعليم بمنطقة المدينة المنورة',
    'الإدارة العامة للتعليم بالمنطقة الشرقية',
    'الإدارة العامة للتعليم بمنطقة القصيم',
    'الإدارة العامة للتعليم بمنطقة عسير',
    'الإدارة العامة للتعليم بمنطقة تبوك',
    'الإدارة العامة للتعليم بمنطقة حائل',
    'الإدارة العامة للتعليم بمنطقة الجوف',
    'الإدارة العامة للتعليم بمنطقة الحدود الشمالية',
    'الإدارة العامة للتعليم بمنطقة جازان',
    'الإدارة العامة للتعليم بمنطقة نجران',
    'الإدارة العامة للتعليم بمنطقة الباحة',
    'الإدارة العامة للتعليم بمنطقة القريات',
    'الإدارة العامة للتعليم بمنطقة الأحساء',
    'الإدارة العامة للتعليم بمنطقة الطائف',
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _cityController.dispose();
    _adminNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _studentCountController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // حفظ مباشر في Firestore بدون Cloud Function
      final db = FirebaseFirestore.instance;
      final requestRef = db.collection('SchoolRequests').doc();
      final requestId = requestRef.id;

      await requestRef.set({
        'id': requestId,
        'schoolName': _schoolNameController.text.trim(),
        'schoolType': _selectedSchoolType,
        'schoolStage': _selectedSchoolStage,
        'adminRegion': _selectedCountryCode == 'SA'
            ? _selectedAdminRegion
            : _customRegion.trim(),
        'city': _cityController.text.trim(),
        'countryCode': _selectedCountryCode == 'OTHER' ? 'OTHER' : _selectedCountryCode,
        'principalName': _adminNameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'studentCount': int.tryParse(_studentCountController.text.trim()) ?? 0,
        'hasSpecialEducation': _hasSpecialEducation,
        'status': 'pending',
        'ownerUserId': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/school-request-success');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب تفعيل حساب مدرسة'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'يرجى تعبئة البيانات التالية لطلب تفعيل حساب المدرسة.\nيتم إرسال رمز تحقق إلى رقم الجوال المسجل لاستكمال إجراءات التفعيل.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),

              // School Info
              Text(
                '🏫 أولاً: بيانات المدرسة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _schoolNameController,
                decoration: _inputDecoration('اسم المدرسة'),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                value: _selectedSchoolType,
                decoration: _inputDecoration('نوع المدرسة'),
                items: const [
                  DropdownMenuItem(value: 'government', child: Text('حكومي')),
                  DropdownMenuItem(value: 'private', child: Text('أهلي')),
                  DropdownMenuItem(
                    value: 'international',
                    child: Text('عالمي'),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSchoolType = val!),
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                value: _selectedSchoolStage,
                decoration: _inputDecoration('المرحلة الدراسية'),
                items: const [
                  DropdownMenuItem(
                    value: 'الابتدائية',
                    child: Text('الابتدائية'),
                  ),
                  DropdownMenuItem(value: 'المتوسطة', child: Text('المتوسطة')),
                  DropdownMenuItem(value: 'الثانوية', child: Text('الثانوية')),
                  DropdownMenuItem(
                    value: 'مجمّع تعليمي',
                    child: Text('مجمّع تعليمي'),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSchoolStage = val!),
              ),
              SizedBox(height: 16.h),

              // ─── اختيار الدولة ────────────────────────────────────────
              _buildCountrySelector(),
              SizedBox(height: 16.h),

              // ─── الإدارة التعليمية (للسعودية فقط) ────────────────────
              if (_selectedCountryCode == 'SA') ...[
                DropdownButtonFormField<String>(
                  value: _selectedAdminRegion,
                  decoration: _inputDecoration('الإدارة التعليمية'),
                  items: _adminRegions
                      .map(
                        (region) =>
                            DropdownMenuItem(value: region, child: Text(region)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedAdminRegion = value!),
                ),
                SizedBox(height: 16.h),
              ] else ...[
                // للدول الأخرى: حقل نصي للمنطقة/المحافظة
                TextFormField(
                  decoration: _inputDecoration('المنطقة / المحافظة (اختياري)'),
                  onChanged: (v) => setState(() => _customRegion = v),
                ),
                SizedBox(height: 16.h),
              ],

              TextFormField(
                controller: _cityController,
                decoration: _inputDecoration('المدينة'),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _studentCountController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('عدد الطلاب التقريبي'),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              CheckboxListTile(
                title: const Text(
                  'هل تحتوي المدرسة على برامج دمج / تربية خاصة؟',
                ),
                value: _hasSpecialEducation,
                onChanged: (val) =>
                    setState(() => _hasSpecialEducation = val ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.indigo,
              ),
              SizedBox(height: 32.h),

              // Admin Info
              Text(
                '👤 ثانياً: بيانات مسؤول الحساب الإداري',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _adminNameController,
                decoration: _inputDecoration('الاسم الكامل'),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('رقم الجوال'),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),

              // Security Note
              Padding(
                padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14.sp,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        'يستخدم رقم الجوال لإرسال رمز التحقق فقط، ولا يتم استخدامه كوسيلة دخول دائمة.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  'البريد الإلكتروني (اختياري للتواصل فقط)',
                ),
              ),

              SizedBox(height: 40.h),

              Column(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 48.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'إرسال طلب التفعيل',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'يخضع الطلب لمراجعة واعتماد الإدارة قبل التفعيل.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.blueGrey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 48.h),

              // Policy Footer Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _footerLink('سياسة الخصوصية'),
                  _footerDivider(),
                  _footerLink('شروط الاستخدام'),
                  _footerDivider(),
                  _footerLink('سياسة حماية البيانات'),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerLink(String label) {
    return InkWell(
      onTap: () {}, // Fixed: Use onTap for InkWell
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: Colors.grey.shade600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _footerDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text('|', style: TextStyle(color: Colors.grey.shade300)),
    );
  }

  Widget _buildCountrySelector() {
    final selected = _countries.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => _countries.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(children: [
            Icon(Icons.public, color: Colors.indigo.shade700, size: 16.sp),
            SizedBox(width: 6.w),
            Text('الدولة',
                style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp)),
          ]),
        ),
        // Country Grid
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: _countries.map((c) {
            final isSelected = _selectedCountryCode == c['code'];
            return GestureDetector(
              onTap: () => setState(() {
                _selectedCountryCode = c['code']!;
                // Reset region when country changes
                if (c['code'] != 'SA') _customRegion = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.indigo.shade700
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected
                        ? Colors.indigo.shade700
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: Colors.indigo.withValues(alpha: 0.3),
                          blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c['flag']!, style: TextStyle(fontSize: 16.sp)),
                  SizedBox(width: 6.w),
                  Text(c['nameAr']!,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade800,
                          fontSize: 11.sp,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]),
              ),
            );
          }).toList(),
        ),
        // Info badge للدولة المختارة
        if (_selectedCountryCode != 'SA' && _selectedCountryCode != 'OTHER') ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'سيتم تطبيق نظام ${selected['nameAr']} التعليمي تلقائياً عند تفعيل المدرسة',
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11.sp),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    );
  }
}
