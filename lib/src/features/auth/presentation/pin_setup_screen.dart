import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/domain/models/user.dart';
import '../data/mock_auth_repository.dart';
import '../data/pin_service.dart';
import 'auth_controller.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<String> _pin = [];
  final List<String> _confirmPin = [];
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _error;

  int get _pinLength {
    return 4;
  }

  void _onNumberPressed(String number) {
    if (_isLoading) return;

    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_pin.length < _pinLength) {
          _pin.add(number);
          if (_pin.length == _pinLength) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < _pinLength) {
          _confirmPin.add(number);
          if (_confirmPin.length == _pinLength) {
            _verifyAndSave();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    if (_isLoading) return;

    setState(() {
      _error = null;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin.removeLast();
        } else {
          _isConfirming = false;
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin.removeLast();
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    final pinStr = _pin.join();
    final confirmPinStr = _confirmPin.join();

    if (pinStr == confirmPinStr) {
      setState(() {
        _error = null;
        _isLoading = true;
      });
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        try {
          final pinService = PinService();
          final deviceId = await _getDeviceId();

          // 1. Setup local PIN and session
          await pinService.setupPin(
            user.id,
            user.role.name,
            pinStr,
            'MOCK_SESSION_TOKEN_${user.id}',
          );

          // 2. Bind device ID to server
          final bindingCode = user.mnCode ?? user.identityNumber;
          final repo = ref.read(authRepositoryProvider);
          final isMockMode = repo is MockAuthRepository;

          if (!isMockMode) {
            final functions = FirebaseFunctions.instance;

            if (bindingCode != null) {
              // A. If user has a code (MN-Code or ID), bind via the Code Registry
              try {
                final callable = functions.httpsCallable('manageUserCode');
                await callable.call({
                  'action': 'bind',
                  'code': bindingCode.toUpperCase(),
                  'email': user.email,
                  'schoolId': user.schoolId ?? '',
                  'role': user.role.name,
                  'name': user.name,
                  'deviceId': deviceId,
                });
              } catch (e) {
                debugPrint(
                  'Code-based binding failed, falling back to account-based: $e',
                );
                // Fallback to account-based binding if registry binding fails
                await functions.httpsCallable('bindAccountDevice').call({
                  'deviceId': deviceId,
                });
              }
            } else {
              // B. ROOT CAUSE FIX: For accounts without codes (like the Owner),
              // bind directly to the GlobalUsers account record.
              await functions.httpsCallable('bindAccountDevice').call({
                'deviceId': deviceId,
              });
            }
          } else {
            debugPrint('Mock Mode: Skipping server device binding');
          }

          if (mounted) {
            context.go('/dashboard');
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _error = 'حدث خطأ أثناء حفظ البيانات: $e';
          });
        }
      }
    } else {
      setState(() {
        _error = 'الأرقام غير متطابقة، يرجى المحاولة مرة أخرى';
        _confirmPin.clear();
      });
    }
  }

  Future<String> _getDeviceId() async {
    if (kIsWeb) {
      return 'web_${DateTime.now().millisecondsSinceEpoch}';
    }
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_unknown';
    } else {
      return 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final indigoColor = const Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 80.h),
            // Title
            Text(
              _isConfirming ? 'تأكيد الرمز السري' : 'إعداد الرمز السري',
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: indigoColor,
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Text(
                'سيتم استخدام هذا الرمز للدخول السريع من هذا الجهاز مستقبلاً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey),
              ),
            ),
            SizedBox(height: 40.h),

            // PIN Indicators
            _buildPinDisplay(),

            SizedBox(height: 20.h),

            // Error/Status Message
            if (_isLoading)
              const CircularProgressIndicator()
            else
              AnimatedOpacity(
                opacity: _error != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _error ?? '',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const Spacer(),

            // Keyboard
            _buildKeyboard(),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    final currentList = _isConfirming ? _confirmPin : _pin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < currentList.length;

        Color borderColor;
        if (_error != null) {
          borderColor = Colors.red;
        } else if (isFilled) {
          borderColor = const Color(0xFF1A237E);
        } else {
          borderColor = Colors.grey.shade300;
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          width: 55.w,
          height: 55.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: borderColor.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isFilled
                ? Text(
                    '*',
                    style: TextStyle(
                      fontSize: 30.sp,
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKey('1'),
                SizedBox(width: 30.w),
                _buildKey('2'),
                SizedBox(width: 30.w),
                _buildKey('3'),
              ],
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKey('4'),
                SizedBox(width: 30.w),
                _buildKey('5'),
                SizedBox(width: 30.w),
                _buildKey('6'),
              ],
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKey('7'),
                SizedBox(width: 30.w),
                _buildKey('8'),
                SizedBox(width: 30.w),
                _buildKey('9'),
              ],
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 70, height: 70),
                _buildKey('0'),
                SizedBox(width: 30.w),
                _buildKey('delete', icon: Icons.arrow_back),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String value, {IconData? icon}) {
    return InkWell(
      onTap: () =>
          value == 'delete' ? _onDeletePressed() : _onNumberPressed(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70.w,
        height: 70.w,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF1A237E),
                  size: value == 'delete' ? 24.sp : 32.sp,
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A237E),
                  ),
                ),
        ),
      ),
    );
  }
}
