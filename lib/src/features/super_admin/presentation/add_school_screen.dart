import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/text_utils.dart';
import '../data/super_admin_repository.dart';
import 'country_selector_widget.dart';

class AddSchoolScreen extends ConsumerStatefulWidget {
  const AddSchoolScreen({super.key});

  @override
  ConsumerState<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends ConsumerState<AddSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerIdentityController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _managerPasswordController = TextEditingController();

  String _selectedType = 'government';
  String _selectedStage = 'الابتدائية';
  String _selectedAdminRegion = 'الإدارة العامة للتعليم بمنطقة الرياض';
  String _selectedCountryCode = 'SA'; // الدولة الافتراضية: السعودية
  bool _showSubscriptionSection = true;
  bool _hasSpecialEducation = false;
  String _subscriptionDurationType = 'open';
  String _subscriptionPeriod = 'month';
  String _subscriptionPlanId = 'starter';
  bool _isLoading = false;
  bool _obscurePass = true;

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
      await ref.read(superAdminRepositoryProvider).addSchool(
            name: _schoolNameController.text,
            type: _selectedType,
            stage: _selectedStage,
            city: _cityController.text,
            adminRegion: _selectedAdminRegion,
            managerName: _managerNameController.text,
            managerIdentityNumber: _managerIdentityController.text.trim(),
            managerPhoneNumber: _managerPhoneController.text.trim(),
            managerEmail: _managerEmailController.text.trim(),
            managerPassword: TextUtils.normalizeDigits(
                _managerPasswordController.text),
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
            countryCode: _selectedCountryCode,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم إضافة المدرسة والمدير بنجاح ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().startsWith('Exception: ')
            ? e.toString().substring('Exception: '.length)
            : 'حدث خطأ: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إضافة مدرسة جديدة',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('تسجيل مدرسة في المنصة',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              // ─── School Data ──────────────────────────────────
              _buildSection(
                icon: Icons.school,
                title: 'بيانات المدرسة',
                color: const Color(0xFF00695C),
                children: [
                  _buildField(_schoolNameController, 'اسم المدرسة',
                      Icons.school,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  SizedBox(height: 10.h),
                  // Country Selector
                  CountrySelectorWidget(
                    selectedCode: _selectedCountryCode,
                    onChanged: (code) =>
                        setState(() => _selectedCountryCode = code),
                  ),
                  SizedBox(height: 8.h),
                  // Country info
                  CountryProfileInfoWidget(countryCode: _selectedCountryCode),
                  SizedBox(height: 10.h),
                  _buildDropdown<String>(
                    value: _selectedType,
                    label: 'نوع المدرسة',
                    icon: Icons.category,
                    items: const [
                      DropdownMenuItem(
                          value: 'government', child: Text('حكومي')),
                      DropdownMenuItem(
                          value: 'private', child: Text('أهلي')),
                      DropdownMenuItem(
                          value: 'international', child: Text('عالمي')),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  SizedBox(height: 10.h),
                  _buildDropdown<String>(
                    value: _selectedStage,
                    label: 'المرحلة الدراسية',
                    icon: Icons.stairs,
                    items: const [
                      DropdownMenuItem(
                          value: 'الابتدائية', child: Text('الابتدائية')),
                      DropdownMenuItem(
                          value: 'المتوسطة', child: Text('المتوسطة')),
                      DropdownMenuItem(
                          value: 'الثانوية', child: Text('الثانوية')),
                    ],
                    onChanged: (v) => setState(() => _selectedStage = v!),
                  ),
                  SizedBox(height: 10.h),
                  _buildDropdown<String>(
                    value: _selectedAdminRegion,
                    label: 'الإدارة العامة للتعليم',
                    icon: Icons.apartment,
                    items: _adminRegions
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAdminRegion = v!),
                  ),
                  SizedBox(height: 10.h),
                  _buildField(_cityController, 'المدينة', Icons.location_city,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                ],
              ),

              SizedBox(height: 16.h),

              // ─── Manager Data ─────────────────────────────────
              _buildSection(
                icon: Icons.person,
                title: 'بيانات مدير المدرسة',
                color: const Color(0xFF1565C0),
                children: [
                  _buildField(_managerNameController, 'اسم المدير',
                      Icons.person,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  SizedBox(height: 10.h),
                  _buildField(_managerIdentityController, 'رقم الهوية',
                      Icons.badge,
                      validator: (v) {
                    if (v == null || v.isEmpty) return 'مطلوب';
                    if (!RegExp(r'^[\d\u0660-\u0669\u06F0-\u06F9]+$')
                        .hasMatch(v)) return 'أرقام فقط';
                    return null;
                  }),
                  SizedBox(height: 10.h),
                  _buildField(_managerPhoneController, 'رقم الجوال',
                      Icons.phone,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  SizedBox(height: 10.h),
                  _buildField(_managerEmailController,
                      'البريد الإلكتروني (اختياري)', Icons.email),
                  SizedBox(height: 10.h),
                  _buildField(
                      _managerPasswordController, 'كلمة المرور', Icons.lock,
                      obscure: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePass
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white38,
                            size: 18.sp),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                ],
              ),

              SizedBox(height: 16.h),

              // ─── Settings ─────────────────────────────────────
              _buildSection(
                icon: Icons.settings,
                title: 'الإعدادات',
                color: const Color(0xFF6A1B9A),
                children: [
                  _buildToggle(
                    icon: Icons.visibility,
                    title: 'إظهار قسم الاشتراكات للمدير',
                    subtitle: 'يتيح للمدير رؤية خيارات الترقية',
                    value: _showSubscriptionSection,
                    onChanged: (v) =>
                        setState(() => _showSubscriptionSection = v),
                    color: const Color(0xFF26A69A),
                  ),
                  SizedBox(height: 10.h),
                  _buildToggle(
                    icon: Icons.accessibility_new,
                    title: 'دعم التربية الخاصة',
                    subtitle: 'تفعيل ميزات التربية الخاصة',
                    value: _hasSpecialEducation,
                    onChanged: (v) =>
                        setState(() => _hasSpecialEducation = v),
                    color: const Color(0xFF1565C0),
                  ),
                  SizedBox(height: 12.h),
                  // Subscription duration
                  Row(
                    children: [
                      _durationChip('open', 'مفتوح', Icons.all_inclusive,
                          Colors.amber),
                      SizedBox(width: 8.w),
                      _durationChip('limited', 'محدد', Icons.timer,
                          const Color(0xFF1565C0)),
                    ],
                  ),
                  if (_subscriptionDurationType == 'limited') ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        _periodChip('month', 'شهر', const Color(0xFF26A69A)),
                        SizedBox(width: 8.w),
                        _periodChip('year', 'سنة', const Color(0xFF6A1B9A)),
                      ],
                    ),
                  ],
                  SizedBox(height: 12.h),
                  // Plan selection
                  Text('خطة الاشتراك',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8.h),
                  ...['starter', 'smart', 'elite'].map((plan) {
                    final names = {
                      'starter': 'Starter - الأساس',
                      'smart': 'Professional - الذكية',
                      'elite': 'Elite - التميز',
                    };
                    final colors = {
                      'starter': const Color(0xFF26A69A),
                      'smart': const Color(0xFF1565C0),
                      'elite': const Color(0xFF6A1B9A),
                    };
                    final isSelected = _subscriptionPlanId == plan;
                    final color = colors[plan]!;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _subscriptionPlanId = plan),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: EdgeInsets.only(bottom: 6.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: isSelected
                                  ? color
                                  : Colors.white12,
                              width: isSelected ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle,
                                color: isSelected ? color : Colors.white24,
                                size: 10.sp),
                            SizedBox(width: 10.w),
                            Text(names[plan]!,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12.sp)),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check, color: color, size: 16.sp),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),

              SizedBox(height: 24.h),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                    elevation: 6,
                  ),
                  icon: _isLoading
                      ? SizedBox(
                          width: 18.w,
                          height: 18.h,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.add_business, size: 20.sp),
                  label: Text(
                    _isLoading ? 'جاري الإضافة...' : 'إضافة المدرسة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15.sp),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: color, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Text(title,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp)),
            ],
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide:
              const BorderSide(color: Color(0xFF3949AB), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF1B2A4A),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: value
            ? color.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: value ? color.withValues(alpha: 0.3) : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? color : Colors.white38, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white54, fontSize: 10.sp)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _durationChip(
      String type, String label, IconData icon, Color color) {
    final isSelected = _subscriptionDurationType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subscriptionDurationType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
                color: isSelected ? color : Colors.white12,
                width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : Colors.white38,
                  size: 18.sp),
              SizedBox(height: 4.h),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.white38,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChip(String period, String label, Color color) {
    final isSelected = _subscriptionPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subscriptionPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
                color: isSelected ? color : Colors.white12,
                width: isSelected ? 1.5 : 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? color : Colors.white38,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
