import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  String _selectedAdminRegion =
      'الإدارة العامة للتعليم بمنطقة الرياض'; // Default

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
      final result = await FirebaseFunctions.instance
          .httpsCallable('registerNewSchool')
          .call({
            'schoolName': _schoolNameController.text.trim(),
            'schoolType': _selectedSchoolType,
            'schoolStage': _selectedSchoolStage,
            'adminRegion': _selectedAdminRegion,
            'city': _cityController.text.trim(),
            'principalName': _adminNameController.text.trim(), // Admin Name
            'mobile': _mobileController.text.trim(),
            'email': _emailController.text.trim(), // Optional Email
            'studentCount': _studentCountController.text.trim(),
            'hasSpecialEducation': _hasSpecialEducation,
            // Password and Identity are no longer sent initially
          });

      if (result.data['success'] == true) {
        if (mounted) {
          context.go('/school-request-success');
        }
      } else {
        throw Exception('فشلت عملية إرسال الطلب');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: ${e.toString().replaceAll('FirebaseFunctionsException:', '')}',
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    );
  }
}
