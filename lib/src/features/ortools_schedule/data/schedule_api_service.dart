import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/schedule_models.dart';
import '../../schedule/services/schedule_config.dart';

class ScheduleApiService {
  // استخدام Backend V2 المنشور على Cloud Run
  static String get baseUrl => ScheduleConfig.ORTOOLS_BACKEND_URL;
  
  Future<ScheduleResponse> generateSchedule(ScheduleRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScheduleResponse.fromJson(data);
      } else {
        throw Exception('فشل في توليد الجدول: ${response.body}');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بالسيرفر: $e');
    }
  }
  
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
