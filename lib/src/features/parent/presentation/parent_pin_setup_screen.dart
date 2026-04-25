import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

/// شاشة إعداد الرقم السري لولي الأمر — تظهر مرة واحدة بعد أول دخول
class ParentPinSetupScreen extends ConsumerStatefulWidget {
  const ParentPinSetupScreen({super.key});

  @override
  ConsumerState<ParentPinSetupScreen> createState() => _ParentPinSetupScreenState();
}

class _ParentPinSetupScreenState extends ConsumerState<ParentPinSetupScreen> {
  final List<String> _pin = [];
  final List<String> _confirmPin = [];
  bool _isConfirming = false;
  bool _isSaving = false;
  String? _error;

  void _onDigit(String digit) {
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_pin.length < 4) _pin.add(digit);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin.add(digit);
        if (_confirmPin.length == 4) _savePin();
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) _confirmPin.removeLast();
      } else {
        if (_pin.isNotEmpty) _pin.removeLast();
      }
    });
  }

  Future<void> _savePin() async {
    final pin = _pin.join();
    final confirm = _confirmPin.join();
    if (pin != confirm) {
      setState(() {
        _error = 'الرقمان غير متطابقان. حاول مجدداً.';
        _confirmPin.clear();
        _isConfirming = false;
        _pin.clear();
      });
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setParentPin')
          .call({'pin': pin});
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ. حاول مجدداً.';
        _isSaving = false;
        _pin.clear();
        _confirmPin.clear();
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _isConfirming ? _confirmPin : _pin;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF00695C), size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'أكّد الرقم السري' : 'أنشئ رقمك السري',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'أعد إدخال الرقم السري للتأكيد'
                    : 'سيُستخدم للدخول السريع في المرات القادمة',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current.length
                        ? const Color(0xFF00695C)
                        : Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: i < current.length
                          ? const Color(0xFF00695C)
                          : Colors.white38,
                      width: 2,
                    ),
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 48),
              // Keypad
              _buildKeypad(),
              const Spacer(),
              // Skip
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('تخطي الآن (يمكن الإعداد لاحقاً)',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _keyRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _keyRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _keyRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            const SizedBox(width: 16),
            _keyButton('0'),
            const SizedBox(width: 16),
            _deleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _keyRow(List<String> digits) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: digits.map((d) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _keyButton(d),
    )).toList(),
  );

  Widget _keyButton(String digit) => GestureDetector(
    onTap: () => _onDigit(digit),
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Text(digit,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
      ),
    ),
  );

  Widget _deleteButton() => GestureDetector(
    onTap: _onDelete,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.backspace_outlined, color: Colors.white54, size: 24),
      ),
    ),
  );
}
