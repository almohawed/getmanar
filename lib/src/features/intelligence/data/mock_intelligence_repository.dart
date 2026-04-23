import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/audit_log.dart';
import '../domain/school_health_index.dart';

class MockIntelligenceRepository {
  final List<AuditLog> _logs = [];
  
  // Mock data for health index
  SchoolHealthIndex getLatestHealthIndex() {
    return SchoolHealthIndex(
      overallScore: 85.5,
      behaviorScore: 78.0,
      attendanceScore: 92.0,
      stabilityScore: 88.0,
      familyEngagementScore: 65.0,
      criticalAlerts: [
        'الفصل 3/2 يعاني من تزايد المخالفات السلوكية',
        'انخفاض نسبة تفاعل أولياء الأمور في الصف الأول',
      ],
      weekStart: DateTime.now().subtract(const Duration(days: 7)),
    );
  }

  Future<void> logAction(AuditLog log) async {
    _logs.add(log);
    // In real app, save to Firestore
  }

  Future<List<AuditLog>> getLogs({int limit = 50}) async {
    return _logs.reversed.take(limit).toList();
  }
}

final intelligenceRepositoryProvider = Provider((ref) => MockIntelligenceRepository());
