import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/pin_service.dart';
import 'package:intl/intl.dart' as intl;

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final List<String> _pin = [];
  String? _error;
  bool _isLoading = false;
  bool _isSuccess = false;
  final int _pinLength = 4;

  void _onNumberPressed(String number) {
    if (_isLoading || _isSuccess) return;
    setState(() {
      _error = null;
      if (_pin.length < _pinLength) {
        _pin.add(number);
      }
      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    });
  }

  void _onDeletePressed() {
    if (_isLoading || _isSuccess) return;
    setState(() {
      if (_pin.isNotEmpty) _pin.removeLast();
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    final pinStr = _pin.join();
    final pinService = PinService();

    final isValid = await pinService.verifyPin(pinStr);
    if (isValid) {
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

      // Artificial delay to show green state
      await Future.delayed(const Duration(milliseconds: 500));

      final userId = await pinService.getStoredUserId();
      if (userId != null) {
        if (mounted) {
          context.go('/dashboard');
        }
      }
    } else {
      final isLocked = await pinService.isLockedOut();
      final lockoutTime = await pinService.getLockoutTime();
      setState(() {
        _pin.clear();
        _isLoading = false;
        if (isLocked && lockoutTime != null) {
          final formattedTime = intl.DateFormat('HH:mm').format(lockoutTime);
          _error = 'الجهاز مغلق حتى $formattedTime';
        } else {
          _error = 'عذراً! الرمز السري غير صحيح';
        }
      });
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
              'أدخل الرمز السري',
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: indigoColor,
              ),
            ),
            SizedBox(height: 40.h),

            // PIN Indicators
            _buildPinDisplay(),

            SizedBox(height: 20.h),

            // Error Message
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

            SizedBox(height: 30.h),

            // Forgot PIN
            TextButton(
              onPressed: () {
                PinService().clearAll();
                context.go('/login');
              },
              child: Text(
                'نسيت الرمز السري؟',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14.sp,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < _pin.length;

        Color borderColor;
        if (_isSuccess) {
          borderColor = Colors.green;
        } else if (_error != null) {
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
            child: isFilled || _isSuccess
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['1', '2', '3'].map((n) => _buildKey(n)).toList(),
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['4', '5', '6'].map((n) => _buildKey(n)).toList(),
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['7', '8', '9'].map((n) => _buildKey(n)).toList(),
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildKey('bio', icon: Icons.fingerprint),
                _buildKey('0'),
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
      onTap: () {
        if (value == 'delete') {
          _onDeletePressed();
        } else if (value == 'bio') {
          // Biometric logic
        } else {
          _onNumberPressed(value);
        }
      },
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
