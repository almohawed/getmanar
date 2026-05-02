import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/data/offline_storage_service.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/services/app_lock_service.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isSavingLoginMethods = false;
  bool _isActivatingPhone = false;
  bool _isConfiguringLock = false;
  bool _appLockEnabled = false;
  bool _appLockBiometric = true;
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadProfileSettings();
    _loadAppLockSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Ensure box is open (usually done in main, but safe to check)
    if (!Hive.isBoxOpen(kSettingsBox)) {
      await Hive.openBox(kSettingsBox);
    }
    final box = Hive.box(kSettingsBox);
    if (mounted) {
      setState(() {
        _notificationsEnabled = box.get(
          'notifications_enabled',
          defaultValue: true,
        );
      });
    }
  }

  Future<void> _loadProfileSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('GlobalUsers')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      if (!mounted) return;
      setState(() {
        _phoneController.text = (data['phoneNumber'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _loadAppLockSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final service = AppLockService(const FlutterSecureStorage());
    final enabled = await service.isEnabled(uid);
    final bio = await service.isBiometricEnabled(uid);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _appLockBiometric = bio;
    });
  }

  Future<void> _configureAppLock() async {
    if (_isConfiguringLock) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final auth = LocalAuthentication();
    var canBio = false;
    try {
      canBio = await auth.canCheckBiometrics && await auth.isDeviceSupported();
    } catch (_) {}

    final pinController = TextEditingController();
    bool bioEnabled = canBio;
    final ok =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            String? errorText;
            return StatefulBuilder(
              builder: (ctx, setLocal) {
                return AlertDialog(
                  title: const Text('تأمين الدخول بالبصمة / PIN'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'PIN (4 أرقام أو أكثر)',
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (canBio)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('استخدام البصمة'),
                          value: bioEnabled,
                          onChanged: (v) => setLocal(() => bioEnabled = v),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final pin = pinController.text.trim();
                        if (pin.length < 4) {
                          setLocal(() => errorText = 'PIN غير صحيح');
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    final pin = pinController.text.trim();
    pinController.dispose();
    if (!mounted || !ok) return;

    setState(() => _isConfiguringLock = true);
    try {
      final service = AppLockService(const FlutterSecureStorage());
      await service.setPin(uid, pin);
      await service.setBiometricEnabled(uid, bioEnabled);
      await service.setEnabled(uid, true);
      if (!mounted) return;
      setState(() {
        _appLockEnabled = true;
        _appLockBiometric = bioEnabled;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل تأمين الدخول بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ إعدادات التأمين الآن'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfiguringLock = false);
    }
  }

  Future<void> _disableAppLock() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isConfiguringLock = true);
    try {
      final service = AppLockService(const FlutterSecureStorage());
      await service.clear(uid);
      if (!mounted) return;
      setState(() {
        _appLockEnabled = false;
        _appLockBiometric = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إيقاف تأمين الدخول'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديث الإعداد الآن'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfiguringLock = false);
    }
  }

  String _collectionNameForRole(UserRole role) {
    if (role == UserRole.teacher) return 'Teachers';
    if (role == UserRole.student) return 'Students';
    if (role == UserRole.parent) return 'Parents';
    if (role == UserRole.deputy ||
        role == UserRole.administrative ||
        role == UserRole.counselor ||
        role == UserRole.admin ||
        role == UserRole.superAdmin ||
        role == UserRole.technicalSupport ||
        role == UserRole.supportAdmin) {
      return 'Staff';
    }
    return 'Users';
  }

  Future<void> _saveLoginMethods() async {
    final current = ref.read(authStateProvider).value;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (current == null || uid == null) return;

    final rawPhone = TextUtils.normalizeDigits(
      _phoneController.text.trim(),
    ).replaceAll(RegExp(r'\s+'), '');

    final primaryCode =
        (current.identityNumber ?? current.mnCode ?? current.studentCode ?? uid)
            .trim();

    String phoneLookup = '';
    if (rawPhone.isNotEmpty) {
      var p = rawPhone;
      if (p.startsWith('+')) p = p.substring(1);
      if (p.startsWith('0') && p.length == 10) {
        p = '966${p.substring(1)}';
      } else if (p.startsWith('5') && p.length == 9) {
        p = '966$p';
      }
      phoneLookup = p;
    }

    final aliases = <String>{
      current.email.trim().toLowerCase(),
      primaryCode.toLowerCase(),
      if (rawPhone.isNotEmpty) rawPhone,
      if (phoneLookup.isNotEmpty) phoneLookup,
    }.toList();

    setState(() => _isSavingLoginMethods = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final schoolId = (current.schoolId ?? '').trim();
      final updates = <String, dynamic>{
        'authEmail': current.email.trim().toLowerCase(),
        'primaryLoginCode': primaryCode,
        'loginAliases': aliases,
        'phoneNumber': rawPhone,
        'phoneLookup': phoneLookup,
      }..removeWhere((k, v) => v == null);

      await firestore
          .collection('GlobalUsers')
          .doc(uid)
          .set(updates, SetOptions(merge: true));

      if (schoolId.isNotEmpty) {
        final col = _collectionNameForRole(current.role);
        await firestore
            .collection('Schools')
            .doc(schoolId)
            .collection(col)
            .doc(uid)
            .set(updates, SetOptions(merge: true));
      }

      try {
        final functions = FirebaseFunctions.instance;
        await functions.httpsCallable('upsertLoginAliases').call({
          'phoneNumber': rawPhone,
          'primaryLoginCode': primaryCode,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل الدخول برقم الجوال بنجاح'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        String msg = e.toString().replaceAll('Exception:', '').trim();
        if (e is FirebaseFunctionsException) {
          msg = e.message ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ البيانات، لكن تعذر تفعيل الدخول برقم الجوال الآن.\n$msg',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }

      ref.invalidate(authStateProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ بيانات الحساب بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ التغييرات الآن. حاول لاحقًا.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingLoginMethods = false);
    }
  }

  String _toE164(String rawPhone) {
    var p = TextUtils.normalizeDigits(rawPhone).replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0') && p.length == 10) {
      return '+966${p.substring(1)}';
    }
    if (p.startsWith('5') && p.length == 9) {
      return '+966$p';
    }
    if (p.startsWith('966') && p.length >= 12) {
      return '+$p';
    }
    return p;
  }

  Future<void> _activatePhoneLogin() async {
    if (_isActivatingPhone) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الجوال أولاً'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final e164 = _toE164(rawPhone);
    setState(() => _isActivatingPhone = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.currentUser?.linkWithCredential(
              credential,
            );
            if (!mounted) return;
            await _saveLoginMethods();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تفعيل الدخول برقم الجوال بنجاح'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (_) {}
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isActivatingPhone = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر إرسال رمز التحقق: ${e.message ?? ''}'.trim()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        codeSent: (verificationId, _) async {
          if (!mounted) return;
          final codeController = TextEditingController();
          final ok =
              await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  bool isVerifying = false;
                  String? errorText;
                  return StatefulBuilder(
                    builder: (ctx, setLocal) {
                      return AlertDialog(
                        title: const Text('تفعيل الدخول برقم الجوال'),
                        content: TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'رمز التحقق (6 أرقام)',
                            errorText: errorText,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: isVerifying
                                ? null
                                : () => Navigator.of(ctx).pop(false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: isVerifying
                                ? null
                                : () async {
                                    final sms = codeController.text.trim();
                                    if (sms.length != 6) {
                                      setLocal(() {
                                        errorText = 'أدخل رمزًا صحيحًا';
                                      });
                                      return;
                                    }
                                    setLocal(() {
                                      isVerifying = true;
                                      errorText = null;
                                    });
                                    try {
                                      final credential =
                                          PhoneAuthProvider.credential(
                                            verificationId: verificationId,
                                            smsCode: sms,
                                          );
                                      await FirebaseAuth.instance.currentUser
                                          ?.linkWithCredential(credential);
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop(true);
                                      }
                                    } catch (e) {
                                      setLocal(() {
                                        isVerifying = false;
                                        errorText = e
                                            .toString()
                                            .replaceAll('Exception:', '')
                                            .trim();
                                      });
                                    }
                                  },
                            child: isVerifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تفعيل'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ) ??
              false;

          codeController.dispose();

          if (!mounted) return;
          if (ok) {
            await _saveLoginMethods();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تفعيل الدخول برقم الجوال بنجاح'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isActivatingPhone = false);
        },
        codeAutoRetrievalTimeout: (_) {
          if (!mounted) return;
          setState(() => _isActivatingPhone = false);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isActivatingPhone = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تفعيل رقم الجوال الآن. حاول لاحقاً.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Enable notifications
      final box = Hive.box(kSettingsBox);
      await box.put('notifications_enabled', true);
      setState(() => _notificationsEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تفعيل الإشعارات')));
      }
    } else {
      // Disable notifications - Require Password
      final confirmed = await _showPasswordDialog();
      if (confirmed) {
        final box = Hive.box(kSettingsBox);
        await box.put('notifications_enabled', false);
        setState(() => _notificationsEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم إيقاف الإشعارات')));
        }
      } else {
        // Revert switch visually if cancelled
        setState(() {});
      }
    }
  }

  Future<bool> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('تأكيد الهوية'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'لإيقاف الإشعارات، يرجى إدخال كلمة المرور لتأكيد هويتك.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final password = passwordController.text;
                            if (password.isEmpty) return;

                            setState(() {
                              isLoading = true;
                              errorText = null;
                            });

                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: password,
                                );
                                // Attempt re-auth
                                await user.reauthenticateWithCredential(
                                  credential,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } else {
                                setState(
                                  () => errorText = 'تعذر التحقق من المستخدم',
                                );
                              }
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                errorText = 'كلمة المرور غير صحيحة';
                              });
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تأكيد'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF263238), Color(0xFF37474F), Color(0xFF455A64)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإعدادات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('إدارة الحساب والتفضيلات', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة الدخول برقم الجوال
          _buildSettingsCard(
            title: 'الدخول برقم الجوال',
            icon: Icons.phone_android_rounded,
            color: const Color(0xFF1565C0),
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الجوال للدخول (اختياري)',
                    prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF1565C0)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: _isActivatingPhone ? 'جارٍ الإرسال...' : 'تفعيل الدخول برقم الجوال',
                  icon: _isActivatingPhone ? null : Icons.verified_rounded,
                  color: const Color(0xFF1565C0),
                  isLoading: _isActivatingPhone,
                  onTap: _isActivatingPhone ? null : _activatePhoneLogin,
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  label: _isConfiguringLock ? 'جارٍ التهيئة...' : (_appLockEnabled ? 'تعديل البصمة / PIN' : 'تفعيل البصمة / PIN'),
                  icon: _isConfiguringLock ? null : Icons.fingerprint_rounded,
                  color: const Color(0xFF6A1B9A),
                  isLoading: _isConfiguringLock,
                  onTap: _isConfiguringLock ? null : _configureAppLock,
                ),
                if (_appLockEnabled) ...[
                  const SizedBox(height: 8),
                  _buildActionButton(
                    label: 'إيقاف تأمين الدخول',
                    icon: Icons.lock_open_rounded,
                    color: Colors.red.shade700,
                    onTap: _isConfiguringLock ? null : _disableAppLock,
                  ),
                ],
                const SizedBox(height: 12),
                _buildActionButton(
                  label: _isSavingLoginMethods ? 'جارٍ الحفظ...' : 'حفظ الإعدادات',
                  icon: _isSavingLoginMethods ? null : Icons.save_rounded,
                  color: const Color(0xFF2E7D32),
                  isLoading: _isSavingLoginMethods,
                  onTap: _isSavingLoginMethods ? null : _saveLoginMethods,
                  filled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // بطاقة الإشعارات
          _buildSettingsCard(
            title: 'الإشعارات',
            icon: Icons.notifications_rounded,
            color: const Color(0xFFE65100),
            child: Container(
              decoration: BoxDecoration(
                color: _notificationsEnabled ? const Color(0xFFE65100).withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _notificationsEnabled ? const Color(0xFFE65100).withOpacity(0.2) : Colors.grey.shade200),
              ),
              child: SwitchListTile(
                secondary: Icon(
                  _notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  color: _notificationsEnabled ? const Color(0xFFE65100) : Colors.grey,
                ),
                title: Text('تلقي الإشعارات', style: TextStyle(fontWeight: FontWeight.w600, color: _notificationsEnabled ? const Color(0xFFE65100) : Colors.grey.shade700)),
                subtitle: const Text('تفعيل أو إيقاف استلام التنبيهات على هذا الجهاز'),
                value: _notificationsEnabled,
                activeColor: const Color(0xFFE65100),
                onChanged: _toggleNotifications,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // بطاقة الأمان
          _buildSettingsCard(
            title: 'الأمان',
            icon: Icons.security_rounded,
            color: const Color(0xFF880E4F),
            child: InkWell(
              onTap: () => context.push('/change-password'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF880E4F).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF880E4F).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF880E4F).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFF880E4F), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('تحديث كلمة المرور الخاصة بحسابك', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── حول التطبيق ──────────────────────────────────────────────
          _buildSettingsCard(
            title: 'حول التطبيق',
            icon: Icons.info_rounded,
            color: const Color(0xFF1565C0),
            child: InkWell(
              onTap: () => context.push('/about'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.info_rounded, color: Color(0xFF1565C0), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حول منار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('الإصدار، المطوّر، سياسة الخصوصية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, IconData? icon, required Color color, VoidCallback? onTap, bool isLoading = false, bool filled = false}) {
    return Material(
      color: filled ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: filled ? null : BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : color))
              else if (icon != null)
                Icon(icon, size: 16, color: filled ? Colors.white : color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: filled ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}
