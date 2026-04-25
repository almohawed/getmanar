import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadSaved();
    return const Locale('ar', 'SA');
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_locale') ?? 'ar';
      state = lang == 'en' ? const Locale('en', 'US') : const Locale('ar', 'SA');
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', locale.languageCode);
    } catch (_) {}
  }

  bool get isArabic => state.languageCode == 'ar';

  void toggle() {
    setLocale(isArabic
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA'));
  }
}

// ─── Language Toggle Button ───────────────────────────────────────────────────
// ملاحظة: الزر يغيّر اتجاه الصفحة فقط حالياً
// الترجمة الكاملة ستُضاف لاحقاً
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isAr = locale.languageCode == 'ar';

    return GestureDetector(
      onTap: () {
        ref.read(localeProvider.notifier).toggle();
        // إشعار المستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr
                ? 'Switched to English (Layout direction changed)'
                : 'تم التحويل للعربية'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1565C0),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(
          isAr ? 'EN' : 'AR',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
