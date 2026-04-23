import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/models/maintenance_report.dart';

final maintenanceEmailServiceProvider = Provider<MaintenanceEmailService>((ref) {
  return MaintenanceEmailService();
});

class MaintenanceEmailService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// إرسال إيميل بلاغ الصيانة إلى فريق الصيانة
  Future<void> sendMaintenanceReportEmail({
    required MaintenanceReport report,
    required String schoolName,
    required String reporterName,
  }) async {
    if (report.maintenanceEmail == null || report.maintenanceEmail!.isEmpty) {
      throw Exception('إيميل فريق الصيانة غير محدد');
    }

    try {
      final callable = _functions.httpsCallable('sendMaintenanceEmail');
      
      await callable.call({
        'to': report.maintenanceEmail,
        'subject': 'بلاغ صيانة جديد - ${report.title}',
        'reportData': {
          'id': report.id,
          'title': report.title,
          'description': report.description,
          'location': report.location,
          'priority': _getPriorityText(report.priority),
          'priorityColor': _getPriorityColor(report.priority),
          'createdAt': report.createdAt.toIso8601String(),
          'schoolName': schoolName,
          'reporterName': reporterName,
        },
      });
    } catch (e) {
      print('خطأ في إرسال إيميل الصيانة: $e');
      rethrow;
    }
  }

  String _getPriorityText(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.low:
        return 'منخفضة';
      case MaintenancePriority.medium:
        return 'متوسطة';
      case MaintenancePriority.high:
        return 'عالية';
      case MaintenancePriority.critical:
        return 'حرجة جداً';
    }
  }

  String _getPriorityColor(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.low:
        return '#4CAF50'; // أخضر
      case MaintenancePriority.medium:
        return '#FF9800'; // برتقالي
      case MaintenancePriority.high:
        return '#F44336'; // أحمر
      case MaintenancePriority.critical:
        return '#9C27B0'; // بنفسجي
    }
  }
}