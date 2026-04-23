import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/text_utils.dart';
import '../data/super_admin_repository.dart';

class AddSchoolScreen extends ConsumerStatefulWidget {
  const AddSchoolScreen({super.key});

  @override
  ConsumerState<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends ConsumerState<AddSchoolScreen> {
  final _formKey = GlobalKey<FormState>();

  // School Data
  final _schoolNameController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedType = 'government';
  String _selectedStage = 'الابتدائية';
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

  // Manager Data
  final _managerNameController = TextEditingController();
  final _managerIdentityController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _managerPasswordController = TextEditingController();

  // Settings
  bool _showSubscriptionSection = true;
  bool _hasSpecialEducation = false;
  String _subscriptionDurationType = 'open';
  String _subscriptionPeriod = 'month';
  String _subscriptionPlanId = 'starter';

  bool _isLoading = false;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _cityController.dispose();
    _managerNameController.dispose();
    _managerIdentityController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    _managerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(superAdminRepositoryProvider)
          .addSchool(
            name: _schoolNameController.text,
            type: _selectedType,
            stage: _selectedStage,
            city: _cityController.text,
            adminRegion: _selectedAdminRegion,
            managerName: _managerNameController.text,
            managerIdentityNumber: _managerIdentityController.text.trim(),
            managerPhoneNumber: _managerPhoneController.text.trim(),
            managerEmail: _managerEmailController.text.trim(),
            // Normalize password digits to ensure consistency (Arabic -> English)
            managerPassword: TextUtils.normalizeDigits(
              _managerPasswordController.text,
            ),
            showSubscriptionSection: _showSubscriptionSection,
            isLifetimeAccess: _subscriptionDurationType == 'open',
            subscriptionPlan: _subscriptionPlanId,
            trialEndsAt: _subscriptionDurationType == 'open'
                ? null
                : DateTime.now().add(
                    _subscriptionPeriod == 'month'
                        ? const Duration(days: 30)
                        : const Duration(days: 365),
                  ),
            hasSpecialEducation: _hasSpecialEducation,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة المدرسة والمدير بنجاح')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ: $e';
        
        // Extract the actual error message if it's wrapped in Exception
        if (e.toString().startsWith('Exception: ')) {
          errorMessage = e.toString().substring('Exception: '.length);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة مدرسة جديدة'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('بيانات المدرسة'),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المدرسة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10.h),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع المدرسة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'government', child: Text('حكومي')),
                  DropdownMenuItem(value: 'private', child: Text('أهلي')),
                  DropdownMenuItem(
                    value: 'international',
                    child: Text('عالمي'),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              SizedBox(height: 10.h),
              DropdownButtonFormField<String>(
                value: _selectedStage,
                decoration: const InputDecoration(
                  labelText: 'المرحلة الدراسية',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stairs),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'الابتدائية',
                    child: Text('الابتدائية'),
                  ),
                  DropdownMenuItem(value: 'المتوسطة', child: Text('المتوسطة')),
                  DropdownMenuItem(value: 'الثانوية', child: Text('الثانوية')),
                ],
                onChanged: (val) => setState(() => _selectedStage = val!),
              ),
              SizedBox(height: 10.h),
              DropdownButtonFormField<String>(
                value: _selectedAdminRegion,
                decoration: const InputDecoration(
                  labelText: 'الإدارة العامة للتعليم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
                items: _adminRegions
                    .map(
                      (region) =>
                          DropdownMenuItem(value: region, child: Text(region)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedAdminRegion = val);
                  }
                },
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),

              SizedBox(height: 30.h),
              _buildSectionTitle('بيانات مدير المدرسة'),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _managerNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المدير',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _managerIdentityController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهوية',
                  hintText: 'سيتم استخدامه كاسم مستخدم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'مطلوب';
                  // Allow English, Arabic, and Persian digits
                  if (!RegExp(
                    r'^[\d\u0660-\u0669\u06F0-\u06F9]+$',
                  ).hasMatch(value)) {
                    return 'يجب إدخال أرقام فقط';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _managerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _managerEmailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  hintText: 'للتواصل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _managerPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),

              SizedBox(height: 30.h),
              _buildSectionTitle('الإعدادات'),
              SwitchListTile(
                title: const Text('إظهار قسم الاشتراكات في حساب المدير'),
                subtitle: const Text(
                  'عند التعطيل، سيختفي قسم الاشتراكات من لوحة تحكم مدير المدرسة',
                ),
                value: _showSubscriptionSection,
                onChanged: (val) =>
                    setState(() => _showSubscriptionSection = val),
                activeColor: Colors.indigo,
              ),
              ListTile(
                title: const Text('نوع مدة الاشتراك'),
                subtitle: const Text('اختر ما إذا كان الاشتراك مفتوحاً أو محدداً بمدة'),
                trailing: DropdownButton<String>(
                  value: _subscriptionDurationType,
                  items: const [
                    DropdownMenuItem(
                      value: 'open',
                      child: Text('مدة مفتوحة'),
                    ),
                    DropdownMenuItem(
                      value: 'limited',
                      child: Text('مدة محددة'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _subscriptionDurationType = value;
                    });
                  },
                ),
              ),
              if (_subscriptionDurationType == 'limited')
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: DropdownButtonFormField<String>(
                    value: _subscriptionPeriod,
                    decoration: const InputDecoration(
                      labelText: 'مدة الاشتراك',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('شهر واحد'),
                      ),
                      DropdownMenuItem(
                        value: 'year',
                        child: Text('سنة كاملة'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _subscriptionPeriod = value;
                      });
                    },
                  ),
                ),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: DropdownButtonFormField<String>(
                  value: _subscriptionPlanId,
                  decoration: const InputDecoration(
                    labelText: 'خطة الاشتراك',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'starter',
                      child: Text('مدرسة تشغيل (Starter)'),
                    ),
                    DropdownMenuItem(
                      value: 'smart',
                      child: Text('مدرسة منضبطة (Professional)'),
                    ),
                    DropdownMenuItem(
                      value: 'elite',
                      child: Text('مدرسة قيادية (Elite)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _subscriptionPlanId = value;
                    });
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('دعم برامج التربية الخاصة'),
                subtitle: const Text(
                  'تفعيل هذا الخيار يتيح ميزات التربية الخاصة في المدرسة',
                ),
                value: _hasSpecialEducation,
                onChanged: (val) => setState(() => _hasSpecialEducation = val),
                activeColor: Colors.indigo,
              ),

              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'إضافة المدرسة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
        const Divider(),
      ],
    );
  }
}
