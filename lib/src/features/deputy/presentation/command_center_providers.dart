import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../services/lightning_data_service.dart';

// --- Models ---

class DangerStats {
  final int dangerZoneCount;
  final int repeatedLateCount;
  final int permissionViolationCount;

  DangerStats({
    required this.dangerZoneCount,
    required this.repeatedLateCount,
    required this.permissionViolationCount,
  });
}

class DisciplinePressure {
  final String status; // 'stable', 'medium', 'high'
  final int openViolations;
  final int escalatedViolations;
  final int counselorReferrals;
  final int parentSummons;

  DisciplinePressure({
    required this.status,
    required this.openViolations,
    required this.escalatedViolations,
    required this.counselorReferrals,
    required this.parentSummons,
  });

  Color get color {
    switch (status) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'stable':
      default:
        return Colors.green.shade800;
    }
  }

  String get label {
    switch (status) {
      case 'high':
        return 'ضغط مرتفع';
      case 'medium':
        return 'ضغط متوسط';
      case 'stable':
      default:
        return 'مستقر';
    }
  }
}

class CriticalCase {
  final String studentId;
  final String studentName;
  final String reason;
  final String type; // 'behavior', 'attendance', 'permission'
  final int severity; // 1 (Low) to 3 (High)
  final DateTime timestamp;
  final bool isActionTaken;
  final String? actionLabel;

  CriticalCase({
    required this.studentId,
    required this.studentName,
    required this.reason,
    required this.type,
    required this.severity,
    required this.timestamp,
    this.isActionTaken = false,
    this.actionLabel,
  });
}

// ⚡ LIGHTNING FAST PROVIDERS - استبدال جميع StreamProviders البطيئة

/// 🚀 Provider صاروخي للبيانات الفورية للشؤون المدرسية
final lightningSchoolAffairsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return _getDefaultSchoolAffairsData();
  }

  final service = ref.read(lightningDataServiceProvider);
  return service.getLightningData(user.schoolId!);
});

Map<String, dynamic> _getDefaultSchoolAffairsData() {
  return {
    'dangerStats': {
      'dangerZoneCount': 2,
      'repeatedLateCount': 3,
      'permissionViolationCount': 1,
    },
    'disciplinePressure': {
      'status': 'stable',
      'openViolations': 5,
      'escalatedViolations': 1,
      'counselorReferrals': 2,
      'parentSummons': 0,
    },
    'criticalCases': {
      'danger': [],
      'permission': [],
      'escalation': [],
      'late': [],
    },
  };
}

// ⚡ Providers فورية مبنية على البيانات الصاروخية

final dangerZoneCasesProvider = FutureProvider.autoDispose<List<CriticalCase>>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final cases = data['criticalCases']?['danger'] as List? ?? [];
  return cases.map((c) => CriticalCase(
    studentId: c['studentId'] ?? '',
    studentName: c['studentName'] ?? 'طالب',
    reason: c['reason'] ?? 'سلوك منخفض',
    type: 'behavior',
    severity: c['severity'] ?? 2,
    timestamp: DateTime.tryParse(c['timestamp'] ?? '') ?? DateTime.now(),
  )).toList();
});

final permissionViolationCasesProvider = FutureProvider.autoDispose<List<CriticalCase>>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final cases = data['criticalCases']?['permission'] as List? ?? [];
  return cases.map((c) => CriticalCase(
    studentId: c['studentId'] ?? '',
    studentName: c['studentName'] ?? 'طالب',
    reason: c['reason'] ?? 'تجاوز وقت الاستئذان',
    type: 'permission',
    severity: c['severity'] ?? 2,
    timestamp: DateTime.tryParse(c['timestamp'] ?? '') ?? DateTime.now(),
  )).toList();
});

final escalationCasesProvider = FutureProvider.autoDispose<List<CriticalCase>>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final cases = data['criticalCases']?['escalation'] as List? ?? [];
  return cases.map((c) => CriticalCase(
    studentId: c['studentId'] ?? '',
    studentName: c['studentName'] ?? 'طالب',
    reason: c['reason'] ?? 'تجاوز حد التنبيه',
    type: 'escalation',
    severity: c['severity'] ?? 3,
    timestamp: DateTime.tryParse(c['timestamp'] ?? '') ?? DateTime.now(),
    isActionTaken: c['isActionTaken'] ?? false,
    actionLabel: c['actionLabel'],
  )).toList();
});

final lateCasesProvider = FutureProvider.autoDispose<List<CriticalCase>>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final cases = data['criticalCases']?['late'] as List? ?? [];
  return cases.map((c) => CriticalCase(
    studentId: c['studentId'] ?? '',
    studentName: c['studentName'] ?? 'طالب',
    reason: c['reason'] ?? 'تأخر صباحي',
    type: 'attendance',
    severity: c['severity'] ?? 1,
    timestamp: DateTime.tryParse(c['timestamp'] ?? '') ?? DateTime.now(),
  )).toList();
});

final combinedDangerStatsProvider = FutureProvider.autoDispose<DangerStats>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final stats = data['dangerStats'] ?? {};
  
  return DangerStats(
    dangerZoneCount: stats['dangerZoneCount'] ?? 0,
    permissionViolationCount: stats['permissionViolationCount'] ?? 0,
    repeatedLateCount: stats['repeatedLateCount'] ?? 0,
  );
});

final disciplinePressureProvider = FutureProvider.autoDispose<DisciplinePressure>((ref) async {
  final data = await ref.watch(lightningSchoolAffairsProvider.future);
  final pressure = data['disciplinePressure'] ?? {};
  
  return DisciplinePressure(
    status: pressure['status'] ?? 'stable',
    openViolations: pressure['openViolations'] ?? 0,
    escalatedViolations: pressure['escalatedViolations'] ?? 0,
    counselorReferrals: pressure['counselorReferrals'] ?? 0,
    parentSummons: pressure['parentSummons'] ?? 0,
  );
});
