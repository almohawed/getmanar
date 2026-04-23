import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_school_intelligence_repository.dart';

class IntelligenceConfig {
  final double attendanceThreshold;
  final double lowScoreThreshold;
  final int behaviorRecentDays;
  const IntelligenceConfig({
    this.attendanceThreshold = 0.9,
    this.lowScoreThreshold = 50.0,
    this.behaviorRecentDays = 30,
  });
}

class SchoolIntelligenceEngine {
  final FirebaseFirestore _firestore;
  final FirestoreSchoolIntelligenceRepository _repo;
  final IntelligenceConfig _cfg;
  SchoolIntelligenceEngine(this._firestore, this._repo, [this._cfg = const IntelligenceConfig()]);

  Future<void> computeNow(String schoolId, String termId) async {
    final studentsSnap = await _firestore.collection('Schools').doc(schoolId).collection('Students').get();
    final studentIds = studentsSnap.docs.map((d) => d.id).toList();
    final attendanceSnap = await _firestore.collection('Schools').doc(schoolId).collection('StudentAttendance').where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)))).get();
    final attendByStudent = <String, Map<String, int>>{};
    for (final d in attendanceSnap.docs) {
      final m = d.data();
      final sid = m['studentId'] ?? '';
      if (sid.isEmpty) continue;
      final st = m['status']?.toString() ?? 'present';
      final bucket = attendByStudent.putIfAbsent(sid, () => {'present': 0, 'absent': 0, 'late': 0, 'excused': 0});
      bucket[st] = (bucket[st] ?? 0) + 1;
    }
    final tracksSnap = await _firestore.collection('Schools').doc(schoolId).collection('ExamGradesTracking').where('termId', isEqualTo: termId).get();
    final entriesByStudentSubject = <String, List<double>>{};
    for (final t in tracksSnap.docs) {
      final subjectId = t.data()['subjectId'] ?? '';
      final entries = await t.reference.collection('Entries').where('termId', isEqualTo: termId).get();
      for (final e in entries.docs) {
        final m = e.data();
        final sid = m['studentId'] ?? e.id;
        final key = '$sid::$subjectId';
        final sc = (m['score'] ?? 0.0) is num ? (m['score'] as num).toDouble() : 0.0;
        entriesByStudentSubject.putIfAbsent(key, () => []).add(sc);
      }
    }
    final classPerf = <String, List<double>>{};
    for (final t in tracksSnap.docs) {
      final classId = t.data()['classId'] ?? '';
      final subjectId = t.data()['subjectId'] ?? '';
      final entries = await t.reference.collection('Entries').where('termId', isEqualTo: termId).get();
      if (entries.docs.isEmpty) continue;
      final scores = entries.docs.map((e) => ((e.data()['score'] ?? 0.0) as num).toDouble()).toList();
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      classPerf.putIfAbsent('$classId::$subjectId', () => []).add(avg);
    }
    final riskClasses = <String>[];
    final riskSubjects = <String>[];
    final riskTeachers = <String>[];
    classPerf.forEach((k, v) {
      if (v.length >= 2) {
        final last = v[v.length - 1];
        final prev = v[v.length - 2];
        if (last + 1e-6 < prev) {
          riskSubjects.add(k.split('::')[1]);
          riskClasses.add(k.split('::')[0]);
        }
      }
    });
    final predictions = <Map<String, dynamic>>[];
    for (final sid in studentIds) {
      final att = attendByStudent[sid] ?? {'present': 0, 'absent': 0, 'late': 0, 'excused': 0};
      final total = (att['present'] ?? 0) + (att['absent'] ?? 0) + (att['late'] ?? 0) + (att['excused'] ?? 0);
      final attendanceRate = total == 0 ? 1.0 : ((att['present'] ?? 0) + 0.5 * (att['late'] ?? 0)) / total;
      final subjects = entriesByStudentSubject.keys.where((k) => k.startsWith('$sid::')).map((k) => k.split('::')[1]).toSet();
      if (subjects.isEmpty) continue;
      for (final subj in subjects) {
        final key = '$sid::$subj';
        final scores = entriesByStudentSubject[key] ?? [];
        final avg = scores.isEmpty ? 100.0 : scores.reduce((a, b) => a + b) / scores.length;
        String risk = 'GREEN';
        final factors = <String>[];
        if (attendanceRate < _cfg.attendanceThreshold && avg < 70.0) {
          risk = 'RED';
          factors.add('attendance_issue');
          factors.add('low_scores');
        } else if (avg < _cfg.lowScoreThreshold) {
          risk = 'YELLOW';
          factors.add('low_scores');
        } else if (attendanceRate < _cfg.attendanceThreshold) {
          risk = 'YELLOW';
          factors.add('attendance_issue');
        }
        if (risk != 'GREEN') {
          predictions.add({
            'docId': '${sid}_$subj',
            'studentId': sid,
            'subjectId': subj,
            'riskLevel': risk,
            'riskFactors': factors,
            'generatedActions': risk == 'RED'
                ? ['create_remedial_plan', 'notify_agent', 'notify_teacher']
                : ['monitor'],
          });
        }
      }
    }
    double health = 100.0;
    final attRates = studentIds.map((s) {
      final a = attendByStudent[s] ?? {'present': 0, 'absent': 0, 'late': 0, 'excused': 0};
      final total = (a['present'] ?? 0) + (a['absent'] ?? 0) + (a['late'] ?? 0) + (a['excused'] ?? 0);
      return total == 0 ? 1.0 : ((a['present'] ?? 0) + 0.5 * (a['late'] ?? 0)) / total;
    }).toList();
    if (attRates.isNotEmpty) {
      final avgAtt = attRates.reduce((a, b) => a + b) / attRates.length;
      health = health * 0.6 * avgAtt;
    }
    if (classPerf.isNotEmpty) {
      final latestAvgs = classPerf.values.map((v) => v.isEmpty ? 100.0 : v.last).toList();
      final avgScore = latestAvgs.reduce((a, b) => a + b) / latestAvgs.length;
      health = health * 0.4 + avgScore * 0.6;
    }
    await _repo.writeSnapshot(schoolId, {
      'termId': termId,
      'schoolHealthScore': health.clamp(0.0, 100.0),
      'riskClasses': riskClasses.toSet().toList(),
      'riskSubjects': riskSubjects.toSet().toList(),
      'riskTeachers': riskTeachers,
    });
    for (final p in predictions) {
      await _repo.upsertPrediction(schoolId, p['docId'] as String, {
        'studentId': p['studentId'],
        'subjectId': p['subjectId'],
        'riskLevel': p['riskLevel'],
        'riskFactors': p['riskFactors'],
        'generatedActions': p['generatedActions'],
      });
      if (p['riskLevel'] == 'RED') {
        await _repo.createRemedialPlan(schoolId, {
          'studentIds': [p['studentId']],
          'causeType': (p['riskFactors'] as List).contains('attendance_issue')
              ? 'attendance_issue'
              : 'academic_weakness',
          'strategy': 'targeted_support_sessions',
          'teacherId': '',
          'baselineMetrics': {'avgScore': 0, 'attendanceRate': 0},
          'targetMetrics': {'avgScore': 70, 'attendanceRate': 0.9},
          'status': 'active',
        });
      }
    }
  }
}

final schoolIntelligenceEngineProvider = Provider<SchoolIntelligenceEngine>((ref) {
  final fs = FirebaseFirestore.instance;
  final repo = ref.read(schoolIntelligenceRepositoryProvider);
  return SchoolIntelligenceEngine(fs, repo);
});

