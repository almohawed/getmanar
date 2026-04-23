import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/schedule_models_v2.dart';
import '../../schedule/services/schedule_config.dart';

class ScheduleApiV2 {
  // استخدام Backend V2 المنشور على Cloud Run
  static String get baseUrl => ScheduleConfig.ORTOOLS_BACKEND_URL;
  
  Future<PrecheckReportV2> precheck(ScheduleRequestV2 request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/precheck'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return PrecheckReportV2.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Precheck failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بالخادم: $e');
    }
  }
  
  Future<ScheduleResponseV2> generateSchedule(ScheduleRequestV2 request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(Duration(seconds: 120));

      if (response.statusCode == 200) {
        return ScheduleResponseV2.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Generation failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بالخادم: $e');
    }
  }
}
