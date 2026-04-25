import 'dart:async';
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/offline_storage_service.dart';
import '../../../core/utils/text_utils.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/domain/models/user.dart';
import 'auth_controller.dart';
import 'otp_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _lastPhoneVerificationId;
  String? _lastPhoneE164;
  int _phoneOtpCooldownSeconds = 0;
  Timer? _phoneOtpCooldownTimer;
  bool _isSendingPhoneOtp = false;
  bool _isLoginInProgress = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneOtpCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) async {
      if (next.isLoading) return;
      if (next.hasError) {
        final errorMsg = next.error.toString().replaceAll('Exception: ', '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        }
      } else if (next.hasValue && next.value != null) {
        final user = next.value!;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل الدخول بنجاح'),
                backgroundColor: Colors.green));
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _handlePostLogin(user);
          });
        }
      }
    });

    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading && _isLoginInProgress;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // زر تغيير اللغة محذوف مؤقتاً — سيُضاف بعد اكتمال الترجمات
          Center(
            child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 120.w, height: 120.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.indigo.withValues(alpha: 0.2),
                        blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Image.asset('images/mylogo.png',
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.school, size: 50.w, color: Colors.indigo)),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text('منار', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                SizedBox(height: 6.h),
                Text('منصة تنظيم السلوك والتعليم', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
                SizedBox(height: 36.h),

                // ─── قسم 1: دخول المدرسة ──────────────────────────────────
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade100, width: 1.5),
                    boxShadow: [BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.school, color: Colors.indigo.shade700, size: 18),
                        SizedBox(width: 8.w),
                        Text('دخول المدرسة', style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      ]),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.text,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'كود الدخول أو البريد الإلكتروني',
                          helperText: 'أدخل كود الدخول أو البريد الإلكتروني المسجل',
                          helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11.sp),
                          prefixIcon: const Icon(Icons.vpn_key),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h)),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h)),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => _showRecoveryDialog(context),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            child: Text('نسيت كود الدخول؟',
                                style: TextStyle(color: Colors.indigo.shade600, fontSize: 12.sp))),
                          TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            child: Text('استعادة كلمة المرور',
                                style: TextStyle(color: Colors.indigo.shade600, fontSize: 12.sp))),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading || _isSendingPhoneOtp ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: isLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('تسجيل الدخول',
                                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // ─── فاصل ─────────────────────────────────────────────────
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text('أو', style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp))),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),

                SizedBox(height: 16.h),

                // ─── قسم 2: ولي الأمر ─────────────────────────────────────
                GestureDetector(
                  onTap: () => _showParentLoginSheet(context),
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: const Color(0x5900695C),
                        blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: Row(children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.family_restroom, color: Colors.white, size: 28)),
                      SizedBox(width: 16.w),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('أنا ولي أمر',
                              style: TextStyle(color: Colors.white, fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          const Text('الدخول السريع برقم الجوال',
                              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                        ],
                      )),
                      const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 16),
                    ]),
                  ),
                ),

                if (_phoneOtpCooldownSeconds > 0) ...[
                  SizedBox(height: 10.h),
                  Text('يمكنك إعادة طلب رمز التحقق بعد $_phoneOtpCooldownSeconds ثانية',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
                ],

                SizedBox(height: 24.h),

                if (kIsWeb)
                  Center(child: Column(children: [
                    Text('هل تمثل إدارة مدرسة؟',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp)),
                    TextButton(
                      onPressed: () => context.push('/school-request'),
                      child: const Text('طلب تفعيل مدرسة جديدة',
                          style: TextStyle(color: Colors.indigo,
                              fontWeight: FontWeight.bold, fontSize: 14))),
                  ])),

                SizedBox(height: 16.h),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                    onPressed: () => context.push('/terms-of-use'),
                    child: Text('شروط الاستخدام',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => context.push('/privacy-policy'),
                    child: Text('سياسة الخصوصية',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
                ]),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    var email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isLoginInProgress = true);
    final password = _passwordController.text.trim();

    final normalizedInput = TextUtils.normalizeDigits(email);
    final looksLikePhone =
        RegExp(r'^05\d{8}$').hasMatch(normalizedInput) ||
        RegExp(r'^5\d{8}$').hasMatch(normalizedInput) ||
        RegExp(r'^\+9665\d{8}$').hasMatch(normalizedInput) ||
        RegExp(r'^9665\d{8}$').hasMatch(normalizedInput);

    if (looksLikePhone) {
      await _startFirebasePhoneAuth(context, normalizedInput);
      return;
    }
    final isMNCode =
        normalizedInput.length >= 3 &&
        normalizedInput.length <= 20 &&
        !normalizedInput.contains('@');
    final normalizedCodeCandidate = normalizedInput
        .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '')
        .trim()
        .toUpperCase();
    final looksLikeNewMnCode = RegExp(
      r'^[A-Z]{2}\d{6}$',
    ).hasMatch(normalizedCodeCandidate);
    final looksLikeLegacyMnCode =
        normalizedCodeCandidate.length == 6 &&
        RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalizedCodeCandidate) &&
        RegExp(r'[A-Z]').hasMatch(normalizedCodeCandidate) &&
        RegExp(r'\d').hasMatch(normalizedCodeCandidate);

    if (isMNCode && password.isEmpty) {
      // Step 1: Lookup MN-Code for Phone Auth
      try {
        final lookupData = await ref
            .read(authStateProvider.notifier)
            .lookupCode(normalizedInput);

        if (lookupData != null) {
          final maskedPhone = lookupData['maskedPhone'] as String?;

          if (maskedPhone != null) {
            if (mounted) {
              await _showPhoneConfirmationFlow(
                context,
                normalizedInput,
                maskedPhone,
              );
              return;
            }
          } else {
            // No phone linked to this code
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'عذراً، هذا الكود غير مرتبط برقم جوال للتحقق. يرجى إدخال كلمة المرور.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            // Allow fallthrough to password check if they want to try password
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('كود الدخول غير صحيح')),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطأ: ${e.toString().replaceAll('Exception:', '')}',
              ),
            ),
          );
        }
        return;
      }
    }

    if (password.isEmpty) {
      // If it was an MN code but we reached here, it means maskedPhone was null
      // The snackbar above already showed a more specific message if it was an MN code.
      // But for normal emails, we still need this:
      if (!isMNCode) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('يرجى إدخال كلمة المرور')));
      }
      return;
    }

    // Sanitize email (remove invisible chars)
    email = email.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');
    email = TextUtils.normalizeDigits(email);
    final normalizedPassword = TextUtils.normalizeDigits(password);

    if (isMNCode && (looksLikeNewMnCode || looksLikeLegacyMnCode)) {
      await ref
          .read(authStateProvider.notifier)
          .loginWithUserCodeAndPassword(
            normalizedCodeCandidate,
            normalizedPassword,
          );
      return;
    }

    if (RegExp(r'[\u0600-\u06FF]').hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'عذراً، يجب استخدام اسم المستخدم باللغة الإنجليزية أو البريد الإلكتروني',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!email.contains('@')) {
      final isNumeric = RegExp(r'^\d+$').hasMatch(email);
      final lower = email.toLowerCase();
      if (lower == 'mohwed32' || lower == 'mohawed32') {
        email = 'mohawed32@getmanar.com';
        await ref
            .read(authStateProvider.notifier)
            .loginWithSmartFallback(email, normalizedPassword);
        return;
      } else if (email.length >= 6 && email.length <= 7 && !isNumeric) {
        await ref
            .read(authStateProvider.notifier)
            .loginWithSmartFallback(email, normalizedPassword);
        return;
      } else {
        await ref
            .read(authStateProvider.notifier)
            .loginWithSmartFallback(email, normalizedPassword);
        return;
      }
    }

    // Direct Login for full email
    await ref
        .read(authStateProvider.notifier)
        .loginWithSmartFallback(email, normalizedPassword);
  }

  Future<void> _showPhoneConfirmationFlow(
    BuildContext context,
    String code,
    String maskedPhone,
  ) async {
    final phoneController = TextEditingController();
    bool isVerifyingMatch = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تأكيد رقم الجوال'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'لحماية حسابك، يرجى إدخال رقم الجوال المسجل المرتبط بالكود ($code).\nتلميح: $maskedPhone',
                style: const TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال الكامل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isVerifyingMatch
                  ? null
                  : () async {
                      final inputPhone = phoneController.text.trim();
                      if (inputPhone.isEmpty) return;

                      setState(() => isVerifyingMatch = true);
                      try {
                        final matched = await ref
                            .read(authStateProvider.notifier)
                            .verifyPhoneMatch(code, inputPhone);
                        if (matched && context.mounted) {
                          Navigator.pop(context);
                          _startFirebasePhoneAuth(context, inputPhone);
                        }
                      } catch (e) {
                        setState(() => isVerifyingMatch = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e
                                    .toString()
                                    .replaceAll('Exception:', '')
                                    .trim(),
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isVerifyingMatch
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال رمز التحقق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startFirebasePhoneAuth(
    BuildContext context,
    String phoneNumber,
  ) async {
    if (_isSendingPhoneOtp) return;

    String e164Phone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('0')) {
        e164Phone = '+966${phoneNumber.substring(1)}';
      } else if (phoneNumber.startsWith('5')) {
        e164Phone = '+966$phoneNumber';
      }
    }

    if (_phoneOtpCooldownSeconds > 0 &&
        _lastPhoneE164 == e164Phone &&
        _lastPhoneVerificationId != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          verificationId: _lastPhoneVerificationId!,
          phoneNumber: phoneNumber,
        ),
      ).then((verified) {
        if (verified == true) {
          _handlePostLogin();
        }
      });
      return;
    }

    setState(() => _isSendingPhoneOtp = true);

    try {
      await ref
          .read(authStateProvider.notifier)
          .startPhoneVerification(
            phoneNumber: e164Phone,
            onCodeSent: (verificationId) {
              _phoneOtpCooldownTimer?.cancel();
              setState(() {
                _isSendingPhoneOtp = false;
                _lastPhoneVerificationId = verificationId;
                _lastPhoneE164 = e164Phone;
                _phoneOtpCooldownSeconds = 60;
              });
              _phoneOtpCooldownTimer = Timer.periodic(
                const Duration(seconds: 1),
                (t) {
                  if (!mounted) return;
                  if (_phoneOtpCooldownSeconds <= 1) {
                    t.cancel();
                    setState(() => _phoneOtpCooldownSeconds = 0);
                  } else {
                    setState(() => _phoneOtpCooldownSeconds -= 1);
                  }
                },
              );
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => OTPVerificationDialog(
                  verificationId: verificationId,
                  phoneNumber: phoneNumber,
                ),
              ).then((verified) {
                if (verified == true) {
                  _handlePostLogin();
                }
              });
            },
            onError: (message) {
              if (!mounted) return;
              setState(() => _isSendingPhoneOtp = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red),
              );
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingPhoneOtp = false);
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'تعذر إرسال رمز التحقق.' : msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── ولي الأمر: دخول بالجوال ──────────────────────────────────────────────
  Widget _buildParentLoginButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showParentLoginSheet(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00695C),
        side: const BorderSide(color: Color(0xFF00695C), width: 1.5),
        padding: EdgeInsets.symmetric(vertical: 14.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF00695C).withValues(alpha: 0.05),
      ),
      icon: const Icon(Icons.family_restroom, size: 20),
      label: Text(
        'دخول ولي الأمر برقم الجوال',
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showParentLoginSheet(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    bool isChecking = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.family_restroom, color: Color(0xFF00695C), size: 24)),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('أنا ولي أمر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('أدخل رقم جوالك للمتابعة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 24),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'رقم الجوال',
                  hintText: '05xxxxxxxx',
                  prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF00695C)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00695C), width: 2))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: StatefulBuilder(builder: (_, setSB) => ElevatedButton.icon(
                  onPressed: isChecking ? null : () async {
                    final phone = phoneCtrl.text.trim();
                    if (phone.isEmpty) return;
                    setSB(() => isChecking = true);
                    try {
                      final result = await FirebaseFunctions.instance
                          .httpsCallable('checkParentHasPin')
                          .call({'phoneNumber': phone});
                      final hasPin = result.data['hasPin'] == true;
                      final exists = result.data['exists'] == true;
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!exists) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('لم يتم العثور على حساب بهذا الرقم'),
                              backgroundColor: Colors.red));
                        return;
                      }
                      if (hasPin) {
                        await _showParentPinLogin(context, phone);
                      } else {
                        await _showParentOtpFlow(context, phone);
                      }
                    } catch (e) {
                      setSB(() => isChecking = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(e is FirebaseFunctionsException
                            ? (e.message ?? 'حدث خطأ') : 'حدث خطأ'),
                        backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: isChecking
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward),
                  label: Text(isChecking ? 'جاري التحقق...' : 'متابعة',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                )),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showParentPinLogin(BuildContext context, String phone) async {
    final List<String> pin = [];
    bool isVerifying = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Icon(Icons.lock_outline, color: Color(0xFF00695C), size: 40),
              const SizedBox(height: 12),
              const Text('أدخل رقمك السري',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(phone, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pin.length ? const Color(0xFF00695C) : Colors.white24,
                    border: Border.all(
                      color: i < pin.length ? const Color(0xFF00695C) : Colors.white38,
                      width: 2)),
                )),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              for (final row in [['1','2','3'],['4','5','6'],['7','8','9']]) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () async {
                        if (pin.length >= 4 || isVerifying) return;
                        setS(() { pin.add(d); error = null; });
                        if (pin.length == 4) {
                          setS(() => isVerifying = true);
                          try {
                            final result = await FirebaseFunctions.instance
                                .httpsCallable('loginParentWithPin')
                                .call({'phoneNumber': phone, 'pin': pin.join()});
                            final email = result.data['email'] as String;
                            final tempPwd = result.data['tempPassword'] as String;
                            if (ctx.mounted) Navigator.pop(ctx);
                            await ref.read(authRepositoryProvider).login(email, tempPwd);
                            await ref.read(authStateProvider.notifier).refreshUser();
                            if (mounted) _handlePostLogin();
                          } catch (e) {
                            setS(() { isVerifying = false; pin.clear();
                              error = e is FirebaseFunctionsException
                                  ? (e.message ?? 'الرقم السري غير صحيح') : 'الرقم السري غير صحيح'; });
                          }
                        }
                      },
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                        child: Center(child: Text(d,
                            style: const TextStyle(color: Colors.white, fontSize: 24,
                                fontWeight: FontWeight.w500))),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 88),
                  GestureDetector(
                    onTap: () async {
                      if (pin.length >= 4 || isVerifying) return;
                      setS(() { pin.add('0'); error = null; });
                      if (pin.length == 4) {
                        setS(() => isVerifying = true);
                        try {
                          final result = await FirebaseFunctions.instance
                              .httpsCallable('loginParentWithPin')
                              .call({'phoneNumber': phone, 'pin': pin.join()});
                          final email = result.data['email'] as String;
                          final tempPwd = result.data['tempPassword'] as String;
                          if (ctx.mounted) Navigator.pop(ctx);
                          await ref.read(authRepositoryProvider).login(email, tempPwd);
                          await ref.read(authStateProvider.notifier).refreshUser();
                          if (mounted) _handlePostLogin();
                        } catch (e) {
                          setS(() { isVerifying = false; pin.clear(); error = 'الرقم السري غير صحيح'; });
                        }
                      }
                    },
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                      child: const Center(child: Text('0',
                          style: TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.w500))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => setS(() { if (pin.isNotEmpty) pin.removeLast(); error = null; }),
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle),
                      child: const Center(child: Icon(Icons.backspace_outlined,
                          color: Colors.white54, size: 24)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () { Navigator.pop(ctx); _showParentOtpFlow(context, phone); },
                child: const Text('دخول برمز SMS بدلاً من ذلك',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showParentOtpFlow(BuildContext context, String phone) async {
    // على الموبايل: استخدم Firebase Phone Auth مباشرة
    if (!kIsWeb) {
      await _startFirebasePhoneAuth(context, phone);
      return;
    }
    // على الويب: استخدم OTP عبر Cloud Function
    final otpCtrl = TextEditingController();
    bool isSending = false;
    bool otpSent = false;
    bool isVerifying = false;
    String maskedPhone = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.sms, color: Color(0xFF00695C), size: 24)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('التحقق برمز SMS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(otpSent ? 'أدخل الرمز المرسل إلى $maskedPhone' : phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 24),
              if (!otpSent) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSending ? null : () async {
                      setS(() => isSending = true);
                      try {
                        final result = await FirebaseFunctions.instance
                            .httpsCallable('sendParentOtp')
                            .call({'phoneNumber': phone});
                        final testOtp = result.data['otp'] as String?;
                        setS(() { isSending = false; otpSent = true;
                          maskedPhone = result.data['maskedPhone'] ?? phone; });
                        if (testOtp != null && ctx.mounted) {
                          showDialog(context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('رمز التحقق (اختبار)'),
                              content: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Text('استخدم هذا الرمز:'),
                                const SizedBox(height: 12),
                                Container(padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange)),
                                  child: Text(testOtp, style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold,
                                    letterSpacing: 8, color: Colors.orange))),
                              ]),
                              actions: [TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('حسناً'))],
                            ));
                        }
                      } catch (e) {
                        setS(() => isSending = false);
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(e is FirebaseFunctionsException
                              ? (e.message ?? 'حدث خطأ') : 'حدث خطأ'),
                          backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: isSending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(isSending ? 'جاري الإرسال...' : 'إرسال رمز التحقق',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: 'رمز التحقق',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_clock, color: Color(0xFF00695C)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00695C), width: 2))),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isVerifying ? null : () async {
                      final otp = otpCtrl.text.trim();
                      if (otp.length != 6) return;
                      setS(() => isVerifying = true);
                      try {
                        final result = await FirebaseFunctions.instance
                            .httpsCallable('verifyParentOtp')
                            .call({'phoneNumber': phone, 'otp': otp});
                        final email = result.data['email'] as String;
                        final tempPwd = result.data['tempPassword'] as String;
                        if (ctx.mounted) Navigator.pop(ctx);
                        await ref.read(authRepositoryProvider).login(email, tempPwd);
                        await ref.read(authStateProvider.notifier).refreshUser();
                        if (mounted) _handlePostLogin();
                      } catch (e) {
                        setS(() => isVerifying = false);
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(e is FirebaseFunctionsException
                              ? (e.message ?? 'الرمز غير صحيح') : 'الرمز غير صحيح'),
                          backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: isVerifying
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                    label: Text(isVerifying ? 'جاري التحقق...' : 'تأكيد الرمز',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: () => setS(() { otpSent = false; otpCtrl.clear(); }),
                  child: const Text('إعادة الإرسال',
                      style: TextStyle(color: Color(0xFF00695C))),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showRecoveryDialog(BuildContext context) async {
    final searchController = TextEditingController();
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('استعادة كود الدخول'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل رقم الجوال أو البريد الإلكتروني المسجل.',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال / البريد',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSearching ? null : () async {
                final input = searchController.text.trim();
                if (input.isEmpty) return;
                setState(() => isSearching = true);
                try {
                  await FirebaseFunctions.instance
                      .httpsCallable('lookupCodeByInfo')
                      .call({'searchInput': input, 'deviceId': 'web'});
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال كود الدخول إلى بياناتك المسجلة'),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setState(() => isSearching = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(e is FirebaseFunctionsException
                          ? (e.message ?? 'لم يتم العثور على بيانات')
                          : 'لم يتم العثور على بيانات مسجلة'),
                      backgroundColor: Colors.red));
                  }
                }
              },
              child: isSearching
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إرسال الرمز')),
          ],
        ),
      ),
    );
  }

  void _handlePostLogin([User? user]) {
    final currentUser = user ?? ref.read(authStateProvider).value;
    if (currentUser != null) {
      final isParent = currentUser.role == UserRole.parent;
      if (!isParent && currentUser.isPasswordChangeRequired) {
        context.go('/change-password');
      } else if (isParent) {
        // ولي الأمر: تحقق من Firestore هل لديه PIN
        _navigateParent(currentUser.id);
      } else {
        context.go('/pin-setup');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل الانتقال: المستخدم غير موجود'),
            backgroundColor: Colors.orange));
    }
  }

  Future<void> _navigateParent(String uid) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('checkParentHasPinByUid')
          .call({'uid': uid});
      final hasPin = result.data['hasPin'] == true;
      if (mounted) {
        if (hasPin) {
          context.go('/dashboard'); // لديه PIN — ادخل مباشرة
        } else {
          context.go('/parent-pin-setup'); // أول مرة — أنشئ PIN
        }
      }
    } catch (_) {
      // في حالة خطأ — ادخل للوحة مباشرة
      if (mounted) context.go('/dashboard');
    }
  }
}
