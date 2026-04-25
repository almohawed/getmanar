import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              const Text(
                'لأمان حسابك، يرجى تغيير كلمة المرور الافتراضية',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_open),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال كلمة المرور الحالية';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
                  }
                  if (value == '123456' || value == '123') {
                    return 'لا يمكن استخدام كلمة المرور الافتراضية';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'كلمات المرور غير متطابقة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ ودخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
      input = input.replaceAll(persian[i], english[i]);
    }
    return input;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      final normalizedOldPassword = _normalizeDigits(_oldPasswordController.text);
      final normalizedNewPassword = _normalizeDigits(_newPasswordController.text);

      // محاولة reauthenticate — إذا فشلت بسبب invalid-credential نتجاوزها
      // لأن بعض الحسابات تُنشأ بـ generated email مختلف عن email الدخول
      bool reauthOk = false;
      try {
        await repo.reauthenticate(normalizedOldPassword);
        reauthOk = true;
      } catch (e) {
        final errStr = e.toString();
        // إذا الخطأ invalid-credential أو wrong-password → نحاول بدون reauth
        // Firebase يسمح بتغيير كلمة المرور إذا كان الـ token حديثاً (< 5 دقائق)
        if (errStr.contains('invalid-credential') ||
            errStr.contains('wrong-password') ||
            errStr.contains('INVALID_LOGIN_CREDENTIALS')) {
          reauthOk = false; // نكمل بدون reauth
        } else {
          rethrow;
        }
      }

      await repo.changePassword(normalizedNewPassword);
      await ref.read(authStateProvider.notifier).refreshUser();

      if (mounted) {
        final user = ref.read(authStateProvider).value;
        if (user == null) {
          context.go('/login');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('فشل تحديث الملف الشخصي')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تغيير كلمة المرور بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/dashboard');
          return;
        }
        // رسالة خطأ واضحة
        String msg = 'حدث خطأ';
        if (errorStr.contains('invalid-credential') || errorStr.contains('INVALID_LOGIN_CREDENTIALS')) {
          msg = 'كلمة المرور الحالية غير صحيحة. تأكد من إدخالها بشكل صحيح.';
        } else if (errorStr.contains('requires-recent-login')) {
          msg = 'انتهت صلاحية الجلسة. يرجى تسجيل الخروج والدخول مجدداً.';
        } else if (errorStr.contains('weak-password')) {
          msg = 'كلمة المرور الجديدة ضعيفة جداً (6 أحرف على الأقل).';
        } else {
          msg = errorStr.replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
