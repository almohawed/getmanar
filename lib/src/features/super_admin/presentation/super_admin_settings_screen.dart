import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../subscription/data/subscription_repository.dart';

class SuperAdminSettingsScreen extends ConsumerStatefulWidget {
  const SuperAdminSettingsScreen({super.key});

  @override
  ConsumerState<SuperAdminSettingsScreen> createState() =>
      _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState
    extends ConsumerState<SuperAdminSettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _pricesFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final Map<String, TextEditingController> _monthlyControllers = {};
  final Map<String, TextEditingController> _yearlyControllers = {};
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _monthlyControllers.values) c.dispose();
    for (var c in _yearlyControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(_newPasswordController.text);
      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showSnack('تم تغيير كلمة المرور بنجاح ✅', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('فشل تغيير كلمة المرور: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrices() async {
    if (!_pricesFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      for (final planId in ['starter', 'smart', 'elite']) {
        final monthly =
            double.tryParse(_monthlyControllers[planId]?.text ?? '') ?? 0;
        final yearly =
            double.tryParse(_yearlyControllers[planId]?.text ?? '') ?? 0;
        await repo.updateSubscriptionPrices(
            planId: planId, monthly: monthly, yearly: yearly);
      }
      ref.invalidate(subscriptionPricesProvider);
      if (mounted) _showSnack('تم تحديث الأسعار بنجاح ✅', Colors.green);
    } catch (e) {
      if (mounted) _showSnack('فشل تحديث الأسعار: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(subscriptionPricesProvider);

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
            Text('الإعدادات',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('إعدادات النظام والأسعار',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _buildPasswordSection(),
                  SizedBox(height: 20.h),
                  pricesAsync.when(
                    data: (prices) => _buildPricesSection(prices),
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white)),
                    error: (e, s) => Text('خطأ: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPasswordSection() {
    return _buildCard(
      icon: Icons.lock_outline,
      title: 'تغيير كلمة المرور',
      color: const Color(0xFF1565C0),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          children: [
            _buildField(
              controller: _newPasswordController,
              label: 'كلمة المرور الجديدة',
              icon: Icons.lock,
              obscure: _obscureNew,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureNew ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white38,
                    size: 18.sp),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
              validator: (v) =>
                  (v?.length ?? 0) < 6 ? 'كلمة المرور قصيرة جداً' : null,
            ),
            SizedBox(height: 12.h),
            _buildField(
              controller: _confirmPasswordController,
              label: 'تأكيد كلمة المرور',
              icon: Icons.check_circle_outline,
              obscure: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white38,
                    size: 18.sp),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) => v != _newPasswordController.text
                  ? 'كلمات المرور غير متطابقة'
                  : null,
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                icon: Icon(Icons.save, size: 18.sp),
                label: const Text('حفظ كلمة المرور',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricesSection(Map<String, Map<String, double>> prices) {
    final plans = [
      {
        'id': 'starter',
        'name': 'Starter - الأساس',
        'color': const Color(0xFF26A69A)
      },
      {
        'id': 'smart',
        'name': 'Professional - الذكية',
        'color': const Color(0xFF1565C0)
      },
      {
        'id': 'elite',
        'name': 'Elite - التميز',
        'color': const Color(0xFF6A1B9A)
      },
    ];

    return _buildCard(
      icon: Icons.price_change,
      title: 'أسعار الباقات',
      color: const Color(0xFF2E7D32),
      child: Form(
        key: _pricesFormKey,
        child: Column(
          children: [
            ...plans.map((plan) {
              final id = plan['id'] as String;
              final name = plan['name'] as String;
              final color = plan['color'] as Color;

              if (!_monthlyControllers.containsKey(id)) {
                _monthlyControllers[id] = TextEditingController(
                    text: prices[id]?['monthly']?.toString() ?? '0');
                _yearlyControllers[id] = TextEditingController(
                    text: prices[id]?['yearly']?.toString() ?? '0');
              }

              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 8.w),
                        Text(name,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp)),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _monthlyControllers[id]!,
                            label: 'شهري (ر.س)',
                            icon: Icons.calendar_month,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _buildField(
                            controller: _yearlyControllers[id]!,
                            label: 'سنوي (ر.س)',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updatePrices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                icon: Icon(Icons.update, size: 18.sp),
                label: const Text('تحديث الأسعار',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
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
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
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
}
