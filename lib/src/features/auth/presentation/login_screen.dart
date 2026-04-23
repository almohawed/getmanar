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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneOtpCooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    var email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) return;

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

  void _handlePostLogin([User? user]) {
    final currentUser = user ?? ref.read(authStateProvider).value;
    if (currentUser != null) {
      if (currentUser.isPasswordChangeRequired) {
        context.go('/change-password');
      } else {
        // After successful login (OTP or Password), go to PIN setup to bind device
        context.go('/pin-setup');
      }
    } else {
      debugPrint('Warning: Post Login called but user is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل الانتقال: المستخدم غير موجود'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<bool> _showTwoFactorDialog(BuildContext context, User user) async {
    final codeController = TextEditingController();
    bool isVerified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.indigo),
            SizedBox(width: 8.w),
            const Text('التحقق الثنائي (2FA)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أهلاً بك يا ${user.name}،',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            const Text(
              'لحماية حسابك الإداري، يرجى إدخال رمز التحقق المرسل إلى جوالك أو بريدك الرسمي.',
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رمز التحقق (OTP)',
                hintText: 'أدخل 6 أرقام',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_clock),
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
            onPressed: () {
              // For demo purposes, any 6-digit code starting with '123' works
              if (codeController.text.length == 6 &&
                  codeController.text.startsWith('123')) {
                isVerified = true;
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'رمز التحقق غير صحيح، يرجى المحاولة مرة أخرى',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('تحقق'),
          ),
        ],
      ),
    );

    return isVerified;
  }

  Future<void> _showRecoveryDialog(BuildContext context) async {
    final searchController = TextEditingController();
    final otpController = TextEditingController();
    bool isSearching = false;
    bool otpSent = false;
    int countdown = 0;
    Timer? timer;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void startTimer() {
            countdown = 60;
            timer?.cancel();
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 0) {
                setState(() => countdown--);
              } else {
                t.cancel();
              }
            });
          }

          return AlertDialog(
            title: Text(otpSent ? 'تحقق من هويتك' : 'استعادة كود الدخول'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!otpSent) ...[
                  const Text(
                    'أدخل رقم الجوال أو البريد الإلكتروني المسجل لإرسال رمز التحقق.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجوال / البريد',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'تم إرسال رمز التحقق إلى بياناتك المسجلة. يرجى إدخال الرمز المكون من 6 أرقام.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رمز التحقق (OTP)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_clock),
                    ),
                  ),
                  if (countdown > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Text(
                        'يمكنك إعادة الإرسال بعد $countdown ثانية',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSearching || (otpSent && countdown > 0)
                    ? null
                    : () async {
                        final input = searchController.text.trim();
                        if (input.isEmpty) return;

                        if (!otpSent) {
                          setState(() => isSearching = true);
                          try {
                            final functions = FirebaseFunctions.instance;
                            final callable = functions.httpsCallable(
                              'lookupCodeByInfo',
                            );

                            // Get or create a device identifier
                            final storage = ref.read(offlineStorageProvider);
                            await storage.init();
                            String? deviceId = await storage.getString(
                              'device_fingerprint',
                            );
                            if (deviceId == null) {
                              deviceId = const Uuid().v4();
                              await storage.saveString(
                                'device_fingerprint',
                                deviceId,
                              );
                            }

                            await callable.call({
                              'searchInput': input,
                              'deviceId': deviceId,
                            });

                            setState(() {
                              otpSent = true;
                              isSearching = false;
                            });
                            startTimer();
                          } catch (e) {
                            setState(() => isSearching = false);
                            String errorMsg = 'لم يتم العثور على بيانات مسجلة.';
                            if (e is FirebaseFunctionsException) {
                              errorMsg = e.message ?? errorMsg;
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } else {
                          // Verify logic...
                          final otp = otpController.text.trim();
                          if (otp.length != 6) return;
                          setState(() => isSearching = true);
                          await Future.delayed(const Duration(seconds: 1));
                          if (context.mounted) {
                            timer?.cancel();
                            Navigator.pop(context);
                            _showResultDialog(
                              context,
                              "مستخدم منار",
                              "سيصلك كود جديد عبر SMS",
                            );
                          }
                        }
                      },
                child: isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(otpSent ? 'تحقق' : 'إرسال الرمز'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResultDialog(BuildContext context, String name, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم العثور على الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('أهلاً بك يا $name،'),
            SizedBox(height: 16.h),
            const Text('كود دخولك الجديد للمنصة هو:'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.indigo.shade900,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            const Text(
              'يرجى حفظ هذا الكود جيداً، فهو وسيلتك الوحيدة للدخول مستقبلاً.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) async {
      debugPrint(
        'AuthState Changed: isLoading=${next.isLoading}, hasError=${next.hasError}, hasValue=${next.hasValue}, value=${next.value}',
      );

      if (next.isLoading) return;

      if (next.hasError) {
        final errorMsg = next.error.toString().replaceAll('Exception: ', '');
        debugPrint('Login Error: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      } else if (next.hasValue) {
        final user = next.value;
        if (user != null) {
          debugPrint('Login Success: ${user.email}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تسجيل الدخول بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          // Force navigation after a short delay to ensure UI updates
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _handlePostLogin(user);
          });
        } else {
          // AsyncData(null) case - should be treated as error or ignore
          debugPrint('Login Warning: State has value but user is null');
        }
      }
    });

    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 140.w,
                  height: 140.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Image.asset(
                      'images/mylogo.png',
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.school,
                          size: 60.w,
                          color: Colors.indigo,
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              Text(
                'منار',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'منصة تنظيم السلوك والتعليم',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              ),
              SizedBox(height: 48.h),

              // Form
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.text,
                onChanged: (value) {
                  // If user enters 10 digits, show a warning
                  if (value.length == 10 &&
                      RegExp(r'^\d+$').hasMatch(value) &&
                      !value.startsWith('05')) {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  labelText: 'كود الدخول أو البريد الإلكتروني',
                  helperText:
                      _emailController.text.length == 10 &&
                          RegExp(r'^\d+$').hasMatch(_emailController.text) &&
                          !_emailController.text.startsWith('05')
                      ? 'تنبيه: تسجيل الدخول عبر رقم الهوية غير متاح وفق سياسات حماية البيانات.'
                      : 'أدخل كود الدخول أو البريد الإلكتروني المسجل',
                  helperStyle: TextStyle(
                    color:
                        _emailController.text.length == 10 &&
                            RegExp(r'^\d+$').hasMatch(_emailController.text) &&
                            !_emailController.text.startsWith('05')
                        ? Colors.red
                        : Colors.grey.shade600,
                    fontSize: 11.sp,
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Security Policy Note
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16.sp,
                      color: Colors.blueGrey.shade700,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'يتم تسجيل الدخول وفق سياسات حماية البيانات المعتمدة.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.blueGrey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Forgot Password or Code
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _showRecoveryDialog(context),
                    child: Text(
                      'نسيت كود الدخول؟',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(
                      'استعادة كلمة المرور',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              if (kDebugMode) // Only show in debug mode
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Text(
                    'Debug State: ${authState.toString()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                  ),
                ),

              ElevatedButton(
                onPressed: isLoading || _isSendingPhoneOtp ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (_phoneOtpCooldownSeconds > 0) ...[
                SizedBox(height: 10.h),
                Text(
                  'يمكنك إعادة طلب رمز التحقق بعد $_phoneOtpCooldownSeconds ثانية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              SizedBox(height: 32.h),

              // School Activation Request (Web Only)
              if (kIsWeb)
                Center(
                  child: Column(
                    children: [
                      Text(
                        'هل تمثل إدارة مدرسة؟',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13.sp,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/school-request'),
                        child: Text(
                          'طلب تفعيل مدرسة جديدة',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 24.h),

              // Terms and Privacy
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.push('/terms-of-use'),
                    child: Text(
                      'شروط الاستخدام',
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    ),
                  ),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => context.push('/privacy-policy'),
                    child: Text(
                      'سياسة الخصوصية',
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
