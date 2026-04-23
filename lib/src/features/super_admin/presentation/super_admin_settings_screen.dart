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

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Price controllers map
  final Map<String, TextEditingController> _monthlyControllers = {};
  final Map<String, TextEditingController> _yearlyControllers = {};

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _monthlyControllers.values) {
      c.dispose();
    }
    for (var c in _yearlyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Note: We might need to re-authenticate first in a real app,
      // but AuthRepository.changePassword handles the update directly.
      // If re-auth is needed, Firebase throws an error which we can catch.
      await ref
          .read(authRepositoryProvider)
          .changePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تغيير كلمة المرور: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrices() async {
    if (!_pricesFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);

      // Update for each plan
      for (final planId in ['starter', 'smart', 'elite']) {
        final monthly =
            double.tryParse(_monthlyControllers[planId]?.text ?? '') ?? 0;
        final yearly =
            double.tryParse(_yearlyControllers[planId]?.text ?? '') ?? 0;

        await repo.updateSubscriptionPrices(
          planId: planId,
          monthly: monthly,
          yearly: yearly,
        );
      }

      // Refresh provider
      ref.invalidate(subscriptionPricesProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث الأسعار بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحديث الأسعار: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(subscriptionPricesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPasswordSection(),
                  SizedBox(height: 24.h),
                  const Divider(),
                  SizedBox(height: 24.h),
                  pricesAsync.when(
                    data: (prices) => _buildPricesSection(prices),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPasswordSection() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تغيير كلمة المرور',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _newPasswordController,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) =>
                (v?.length ?? 0) < 6 ? 'كلمة المرور قصيرة جداً' : null,
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.check),
            ),
            obscureText: true,
            validator: (v) => v != _newPasswordController.text
                ? 'كلمات المرور غير متطابقة'
                : null,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12.h),
            ),
            child: const Center(child: Text('حفظ كلمة المرور')),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesSection(Map<String, Map<String, double>> prices) {
    final plans = [
      {'id': 'starter', 'name': 'الباقة الأساسية (Starter)'},
      {'id': 'smart', 'name': 'الباقة الذكية (Smart)'},
      {'id': 'elite', 'name': 'باقة النخبة (Elite)'},
    ];

    return Form(
      key: _pricesFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تغيير أسعار الباقات',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          ...plans.map((plan) {
            final id = plan['id'] as String;
            final name = plan['name'] as String;

            // Initialize controllers if empty
            if (!_monthlyControllers.containsKey(id)) {
              _monthlyControllers[id] = TextEditingController(
                text: prices[id]?['monthly']?.toString() ?? '0',
              );
              _yearlyControllers[id] = TextEditingController(
                text: prices[id]?['yearly']?.toString() ?? '0',
              );
            }

            return Card(
              margin: EdgeInsets.only(bottom: 16.h),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _monthlyControllers[id],
                            decoration: const InputDecoration(
                              labelText: 'شهري (ر.س)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: TextFormField(
                            controller: _yearlyControllers[id],
                            decoration: const InputDecoration(
                              labelText: 'سنوي (ر.س)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _updatePrices,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12.h),
            ),
            child: const Center(child: Text('تحديث الأسعار')),
          ),
        ],
      ),
    );
  }
}
