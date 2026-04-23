import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/domain/models/school.dart';

class SmsService {
  final SmsConfig config;

  SmsService(this.config);

  /// Sends a bulk SMS message to a list of phone numbers.
  ///
  /// [numbers] should be a string of comma-separated numbers or a single number.
  /// [message] is the text content of the SMS.
  ///
  /// Returns a boolean indicating if the request was successfully sent (status 200).
  /// Throws an exception if the request fails with details.
  Future<bool> sendBulkSms(String numbers, String message) async {
    if (!config.isEnabled) {
      throw Exception('خدمة الرسائل غير مفعلة من قبل مدير المدرسة');
    }
    if (config.apiKey.isEmpty || config.apiUrl.isEmpty) {
      throw Exception('لم يتم إعداد خدمة الرسائل بشكل صحيح');
    }

    final url = Uri.parse(config.apiUrl);

    // Note: 'send-bulk' vs 'send' depends on the specific API version.
    // Usually standard is POST /send with multiple numbers.
    // We will stick to the previous assumption but ensure headers are correct.

    final body = json.encode({
      'sender': config.senderName.isNotEmpty ? config.senderName : 'School1',
      'number': _sanitizeNumbers(numbers),
      'message': message,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        throw Exception(
          'بيانات غير صحيحة (422): ${errorData['message'] ?? 'خطأ في الأرقام أو الرسالة'}',
        );
      } else {
        throw Exception(
          'فشل الإرسال: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sanitizes phone numbers to match the required format (9665XXXXXXXX).
  /// Removes spaces, dashes, and ensures 966 prefix if missing but 05 is present.
  String _sanitizeNumbers(String rawNumbers) {
    // Split by comma if multiple
    final list = rawNumbers.split(',');
    final sanitizedList = <String>[];

    for (var num in list) {
      var n = num.trim().replaceAll(RegExp(r'\D'), ''); // Remove non-digits

      if (n.startsWith('05')) {
        n = '966${n.substring(1)}';
      } else if (n.startsWith('5') && n.length == 9) {
        n = '966$n';
      }

      // Basic validation for Saudi mobile numbers
      if (n.startsWith('9665') && n.length == 12) {
        sanitizedList.add(n);
      }
    }

    return sanitizedList.join(',');
  }
}
