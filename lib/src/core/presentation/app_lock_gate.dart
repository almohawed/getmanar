import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:local_auth/local_auth.dart';
import '../services/app_lock_service.dart';
import '../../features/auth/presentation/auth_controller.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return const AppLockService(FlutterSecureStorage());
});

final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, bool>(AppLockController.new);

class AppLockController extends AsyncNotifier<bool> {
  late final _localAuth = LocalAuthentication();

  @override
  Future<bool> build() async {
    if (kIsWeb) return true;
    final user = ref.watch(authStateProvider).value;
    if (user == null) return true;
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isEnabled(user.id);
    if (!enabled) return true;
    return false;
  }

  Future<void> lock() async {
    if (kIsWeb) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isEnabled(user.id);
    if (!enabled) return;
    state = const AsyncValue.data(false);
  }

  Future<bool> unlockWithBiometrics() async {
    if (kIsWeb) return false;
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;
    final service = ref.read(appLockServiceProvider);
    final biometricEnabled = await service.isBiometricEnabled(user.id);
    if (!biometricEnabled) return false;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck || !supported) return false;
      final ok = await _localAuth.authenticate(
        localizedReason: 'الرجاء تأكيد هويتك لفتح التطبيق',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        state = const AsyncValue.data(true);
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;
    final service = ref.read(appLockServiceProvider);
    final ok = await service.verifyPin(user.id, pin);
    if (ok) {
      state = const AsyncValue.data(true);
    }
    return ok;
  }

  Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;
    final service = ref.read(appLockServiceProvider);
    return service.isEnabled(user.id);
  }

  Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;
    final service = ref.read(appLockServiceProvider);
    return service.isBiometricEnabled(user.id);
  }

  Future<void> setEnabled(bool enabled) async {
    if (kIsWeb) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final service = ref.read(appLockServiceProvider);
    await service.setEnabled(user.id, enabled);
    state = const AsyncValue.data(true);
  }
}

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  AppLifecycleState? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prev = _last;
    _last = state;
    if (state == AppLifecycleState.resumed &&
        (prev == AppLifecycleState.paused ||
            prev == AppLifecycleState.inactive ||
            prev == AppLifecycleState.detached)) {
      ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedAsync = ref.watch(appLockControllerProvider);
    final unlocked = unlockedAsync.value ?? true;
    if (unlocked) return widget.child;
    return Stack(
      children: [
        widget.child,
        const ModalBarrier(dismissible: false, color: Color(0xCCFFFFFF)),
        const _AppLockScreen(),
      ],
    );
  }
}

class _AppLockScreen extends ConsumerStatefulWidget {
  const _AppLockScreen();

  @override
  ConsumerState<_AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<_AppLockScreen> {
  final _pinController = TextEditingController();
  bool _isUnlocking = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPin() async {
    if (_isUnlocking) return;
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _errorText = 'أدخل رمزاً صحيحاً');
      return;
    }
    setState(() {
      _isUnlocking = true;
      _errorText = null;
    });
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPin(pin);
    if (!mounted) return;
    setState(() {
      _isUnlocking = false;
      _errorText = ok ? null : 'رمز غير صحيح';
    });
  }

  Future<void> _unlockWithBiometric() async {
    if (_isUnlocking) return;
    setState(() {
      _isUnlocking = true;
      _errorText = null;
    });
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _isUnlocking = false;
      _errorText = ok ? null : 'تعذر استخدام البصمة على هذا الجهاز';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420.w),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تأمين الدخول',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: Colors.indigo.shade900,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'افتح التطبيق بالبصمة أو برمز PIN',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUnlocking ? null : _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('فتح بالبصمة'),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    border: const OutlineInputBorder(),
                    errorText: _errorText,
                  ),
                  onSubmitted: (_) => _unlockWithPin(),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUnlocking ? null : _unlockWithPin,
                    child: _isUnlocking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('فتح'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
