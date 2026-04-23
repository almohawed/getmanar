import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/teacher_performance.dart';
import '../domain/school_health_index.dart'; // Import SchoolHealthIndex
import '../data/firestore_intelligence_repository.dart';

class ManarIntelligenceEngine {
  final Ref ref;

  ManarIntelligenceEngine(this.ref);

  // 🧠 Core Intelligence: Get Health Index
  Future<SchoolHealthIndex?> getHealthIndex() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return null;
    }
    final intelRepo = ref.read(firestoreIntelligenceRepositoryProvider);
    try {
      return await intelRepo.getSchoolHealthIndex(user.schoolId!);
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching health index: $e');
      return null;
    }
  }

  Future<List<String>> analyzePatterns() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return ['⚠️ يرجى تسجيل الدخول لعرض التحليلات.'];
    }

    final intelRepo = ref.read(firestoreIntelligenceRepositoryProvider);
    try {
      final healthIndex = await intelRepo.getSchoolHealthIndex(user.schoolId!);
      final List<String> insights = [];

      insights.addAll(healthIndex.criticalAlerts);

      final overall = healthIndex.overallScore;
      final behavior = healthIndex.behaviorScore;
      final attendance = healthIndex.attendanceScore;
      final stability = healthIndex.stabilityScore;
      final family = healthIndex.familyEngagementScore;

      if (overall >= 90) {
        insights.add(
          '🟢 المؤشر العام لصحة المدرسة مرتفع (${overall.toStringAsFixed(1)}٪)، مما يعكس أداءً مستقراً ومشجعاً.',
        );
      } else if (overall < 70) {
        insights.add(
          '🔴 المؤشر العام لصحة المدرسة منخفض نسبياً (${overall.toStringAsFixed(1)}٪)، يُنصح بمراجعة خطط الانضباط والمواظبة.',
        );
      }

      if (behavior < 70) {
        insights.add(
          '📌 مؤشر السلوك والانضباط منخفض (${behavior.toStringAsFixed(1)}٪)، مما يشير إلى حاجة لتفعيل خطط سلوك داعمة وتكثيف المتابعة الصفية.',
        );
      } else if (behavior >= 85) {
        insights.add(
          '✅ سلوك الطلاب منضبط بصورة جيدة (${behavior.toStringAsFixed(1)}٪)، مما يوفر بيئة تعليمية هادئة.',
        );
      }

      if (attendance < 75) {
        insights.add(
          '📌 مؤشر الحضور والمواظبة يحتاج اهتماماً (${attendance.toStringAsFixed(1)}٪)، من المناسب مراجعة التواصل مع أولياء الأمور وخطط الحد من الغياب.',
        );
      } else if (attendance >= 90) {
        insights.add(
          '✅ مواظبة الطلاب على الحضور مرتفعة (${attendance.toStringAsFixed(1)}٪)، وهذا داعم قوي لنتائج المدرسة.',
        );
      }

      if (stability < 70) {
        insights.add(
          '📌 مؤشر الاستقرار العام في المدرسة منخفض نسبياً (${stability.toStringAsFixed(1)}٪)، مما قد يعكس تذبذباً في السلوك أو الغياب في بعض الفصول.',
        );
      } else if (stability >= 85) {
        insights.add(
          '🟢 مستوى الاستقرار العام في المدرسة جيد (${stability.toStringAsFixed(1)}٪)، مما يسهل تنفيذ المبادرات الأكاديمية والتربوية.',
        );
      }

      if (family < 65) {
        insights.add(
          '📌 مستوى تفاعل الأسرة مع المدرسة محدود (${family.toStringAsFixed(1)}٪)، يُستحسن زيادة قنوات التواصل واللقاءات الدورية مع أولياء الأمور.',
        );
      } else if (family >= 85) {
        insights.add(
          '🤝 تفاعل أولياء الأمور مع المدرسة مرتفع (${family.toStringAsFixed(1)}٪)، وهذا عنصر قوة ينبغي استثماره في دعم الطلاب.',
        );
      }

      if (insights.isEmpty) {
        return ['✅ لا توجد تنبيهات حرجة حالياً، والمؤشرات في مستويات مستقرة.'];
      }
      return insights;
    } catch (e) {
      return ['⚠️ تعذر تحميل التحليلات حالياً. يرجى المحاولة لاحقاً.'];
    }
  }

  Future<TeacherPerformance> evaluateTeacher(String teacherId) async {
    final behaviorRepo = ref.read(behaviorRepositoryProvider);
    final records = await behaviorRepo.getTeacherRecords(teacherId);

    final totalRecords = records.length;
    final negativeRecords = records
        .where((r) => r.type == BehaviorType.negative)
        .length;
    final positiveRecords = records
        .where((r) => r.type == BehaviorType.positive)
        .length;

    double violationRatio = 0.0;
    if (totalRecords > 0) {
      violationRatio = negativeRecords / totalRecords;
    }

    double classStabilityScore = 100.0 - (violationRatio * 100);
    if (classStabilityScore < 0) classStabilityScore = 0;

    double attendanceCommitment = 95.0;

    return TeacherPerformance(
      teacherId: teacherId,
      teacherName: 'المعلم', // Ideally fetch name from User repo
      classStabilityScore: classStabilityScore,
      violationRatio: violationRatio,
      attendanceCommitment: attendanceCommitment,
      positiveInteractions: positiveRecords,
    );
  }

  Future<String?> generateTeacherMotivation(String teacherId) async {
    try {
      final performance = await evaluateTeacher(teacherId);
      return performance.motivationalMessage;
    } catch (e) {
      return 'أستاذنا الفاضل، شكراً لالتزامك وجهودك المستمرة. تعذر حالياً تحليل بياناتك التفصيلية، لكن إدارة المدرسة تقدر عطائك وتأثيرك الإيجابي على الطلاب.';
    }
  }

  // 📊 Predict Escalation
  Future<List<String>> predictStudentEscalation() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return [];
    }

    final behaviorRepo = ref.read(behaviorRepositoryProvider);
    // Fetch pending violations for this school
    final pending = await behaviorRepo.getPendingViolations(
      schoolId: user.schoolId,
    );

    // Simple heuristic: Students with multiple pending violations
    final studentCounts = <String, int>{};
    for (var p in pending) {
      studentCounts[p.studentId] = (studentCounts[p.studentId] ?? 0) + 1;
    }

    final riskyStudents = studentCounts.entries
        .where((e) => e.value >= 2)
        .toList();

    List<String> insights = [];
    for (var entry in riskyStudents) {
      // In real app, fetch student name
      insights.add(
        '⚠️ الطالب (${entry.key.substring(0, 5)}...): مؤشر الخطر مرتفع (${entry.value} مخالفات معلقة).',
      );
    }

    if (insights.isEmpty) {
      insights.add('✅ لا توجد مؤشرات خطر عالية حالياً.');
    }

    return insights;
  }
}

final manarIntelligenceEngineProvider = Provider(
  (ref) => ManarIntelligenceEngine(ref),
);
