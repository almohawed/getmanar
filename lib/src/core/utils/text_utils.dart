
import 'dart:math';

class TextUtils {
  static String normalizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
      input = input.replaceAll(persian[i], english[i]);
    }
    return input;
  }
  
  static String generateGlobalEntryCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Base32 compliant, avoid 0/O, 1/I
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  static bool isValidGlobalCode(String code) {
    return RegExp(r'^[A-Z2-9]{6,7}$').hasMatch(code.toUpperCase());
  }

  static bool isValidIdentityNumber(String input) {
    return RegExp(r'^\d{10}$').hasMatch(input);
  }

  static String generateRandomDigits(int length) {
    final random = Random();
    String result = '';
    for (int i = 0; i < length; i++) {
      result += random.nextInt(10).toString();
    }
    return result;
  }
}
