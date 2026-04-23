import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';

// Provider
final behaviorAnalysisServiceProvider = Provider<BehaviorAnalysisService>((
  ref,
) {
  return BehaviorAnalysisService();
});

class BehaviorAnalysisResult {
  final List<String> patterns;
  final List<String> suggestions;
  final String trend; // 'improving', 'declining', 'stable'
  final int positiveCount;
  final int negativeCount;

  BehaviorAnalysisResult({
    required this.patterns,
    required this.suggestions,
    required this.trend,
    required this.positiveCount,
    required this.negativeCount,
  });
}

class BathroomAnalysisResult {
  final bool isMedicalCase;
  final double weeklyAverage;
  final double avgDurationMinutes;
  final int lateReturnCount; // Red/Yellow cases
  final List<String> insights;
  final List<String> recommendations;
  final String disciplineIndicator; // 'High', 'Medium', 'Low'
  final String stabilityIndicator; // 'Stable', 'Volatile'
  final String trend; // 'Improving', 'Declining', 'Stable'

  BathroomAnalysisResult({
    required this.isMedicalCase,
    required this.weeklyAverage,
    required this.avgDurationMinutes,
    required this.lateReturnCount,
    required this.insights,
    required this.recommendations,
    required this.disciplineIndicator,
    required this.stabilityIndicator,
    required this.trend,
  });

  factory BathroomAnalysisResult.medical() {
    return BathroomAnalysisResult(
      isMedicalCase: true,
      weeklyAverage: 0,
      avgDurationMinutes: 0,
      lateReturnCount: 0,
      insights: [],
      recommendations: [
        'الطالب لديه حالة صحية خاصة — الاستئذان لا يدخل في التقييم السلوكي'
      ],
      disciplineIndicator: 'N/A',
      stabilityIndicator: 'N/A',
      trend: 'N/A',
    );
  }

  factory BathroomAnalysisResult.empty() {
    return BathroomAnalysisResult(
      isMedicalCase: false,
      weeklyAverage: 0,
      avgDurationMinutes: 0,
      lateReturnCount: 0,
      insights: ['لا توجد بيانات كافية للتحليل'],
      recommendations: [],
      disciplineIndicator: 'High',
      stabilityIndicator: 'Stable',
      trend: 'Stable',
    );
  }
}

class BehaviorAnalysisService {
  BehaviorAnalysisResult analyzeBehavior(List<BehaviorRecord> records) {
    if (records.isEmpty) {
      return BehaviorAnalysisResult(
        patterns: ['لا توجد بيانات كافية للتحليل'],
        suggestions: ['ابدأ بتسجيل ملاحظات سلوكية لتفعيل التحليل'],
        trend: 'stable',
        positiveCount: 0,
        negativeCount: 0,
      );
    }

    // Sort by date (newest first)
    final sortedRecords = List<BehaviorRecord>.from(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final positiveCount = sortedRecords
        .where((r) => r.type == BehaviorType.positive)
        .length;
    final negativeCount = sortedRecords
        .where((r) => r.type == BehaviorType.negative)
        .length;

    // 1. Analyze Patterns
    final patterns = <String>[];

    // Time of Day Analysis
    final morningIncidents = sortedRecords
        .where((r) => r.timestamp.hour < 10 && r.type == BehaviorType.negative)
        .length;
    final noonIncidents = sortedRecords
        .where(
          (r) =>
              r.timestamp.hour >= 10 &&
              r.timestamp.hour < 12 &&
              r.type == BehaviorType.negative,
        )
        .length;
    final afternoonIncidents = sortedRecords
        .where((r) => r.timestamp.hour >= 12 && r.type == BehaviorType.negative)
        .length;

    if (morningIncidents > 2 &&
        morningIncidents > noonIncidents &&
        morningIncidents > afternoonIncidents) {
      patterns.add(
        '💡 نمط زمني: تتركز التحديات السلوكية في الفترة الصباحية (بداية اليوم)',
      );
    } else if (afternoonIncidents > 2 &&
        afternoonIncidents > morningIncidents) {
      patterns.add(
        '💡 نمط زمني: يزداد التوتر السلوكي في الحصص الأخيرة (إرهاق نهاية اليوم)',
      );
    }

    // Activity Level
    if (records.length > 10) {
      patterns.add('يظهر الطالب نشاطاً سلوكياً ملحوظاً (تفاعل مرتفع)');
    }

    // Specific Behaviors (Keywords)
    final descriptions = sortedRecords
        .map((r) => r.description.toLowerCase())
        .toList();

    int talkingCount = descriptions
        .where(
          (d) =>
              d.contains('كلام') || d.contains('حديث') || d.contains('talking'),
        )
        .length;
    if (talkingCount > 2) {
      patterns.add('يظهر الطالب رغبة في التواصل الاجتماعي أثناء الحصة');
    }

    // 2. Suggestions
    final suggestions = <String>[];
    if (negativeCount > positiveCount) {
      suggestions.add(
        'يحتاج الطالب لتعزيز إيجابي فوري عند ظهور أي سلوك جيد لإعادة التوازن',
      );
    }
    if (patterns.any((p) => p.contains('الصباحية'))) {
      suggestions.add(
        'ينصح باستقبال الطالب بترحيب خاص صباحاً لكسر حاجز التوتر',
      );
    }

    // 3. Trend
    String trend = 'stable';
    if (records.length >= 5) {
      final recent = sortedRecords.take(5);
      final recentNegative = recent
          .where((r) => r.type == BehaviorType.negative)
          .length;
      final older = sortedRecords.skip(5).take(5);
      final olderNegative = older
          .where((r) => r.type == BehaviorType.negative)
          .length;

      if (recentNegative < olderNegative) {
        trend = 'improving';
      } else if (recentNegative > olderNegative) {
        trend = 'declining';
      }
    }

    return BehaviorAnalysisResult(
      patterns: patterns,
      suggestions: suggestions,
      trend: trend,
      positiveCount: positiveCount,
      negativeCount: negativeCount,
    );
  }

  BathroomAnalysisResult analyzeBathroomBehavior(
    User student,
    List<BehaviorRecord> records,
  ) {
    // 1. Medical Exception Rule
    if (student.healthStatus != null &&
        (student.healthStatus == 'bathroom' ||
            student.healthStatus == 'care' ||
            student.healthStatus!.isNotEmpty)) {
      return BathroomAnalysisResult.medical();
    }

    final bathroomRecords = records
        .where((r) => r.type == BehaviorType.bathroom)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    if (bathroomRecords.isEmpty) {
      return BathroomAnalysisResult.empty();
    }

    // 2. Calculate Stats
    // Weekly Average
    final firstDate = bathroomRecords.last.timestamp;
    final lastDate = bathroomRecords.first.timestamp;
    final daysDiff = lastDate.difference(firstDate).inDays + 1;
    final weeks = (daysDiff / 7).ceil();
    final weeklyAverage = bathroomRecords.length / (weeks == 0 ? 1 : weeks);

    // Duration Stats
    double totalDuration = 0;
    int countWithReturn = 0;
    int lateReturns = 0;

    for (var r in bathroomRecords) {
      if (r.bathroomExitTime != null && r.bathroomReturnTime != null) {
        final duration = r.bathroomReturnTime!
            .difference(r.bathroomExitTime!)
            .inMinutes;
        totalDuration += duration;
        countWithReturn++;
        if (duration > 5) lateReturns++; // Assuming > 5 min is late/yellow
      }
    }

    final avgDuration = countWithReturn > 0 ? totalDuration / countWithReturn : 0.0;

    // 3. Pattern Detection & Insights
    final insights = <String>[];
    final recommendations = <String>[];

    // Time Patterns
    final lateDayCount = bathroomRecords
        .where((r) => r.timestamp.hour >= 12)
        .length;
    if (lateDayCount > bathroomRecords.length * 0.6) {
      insights.add('✅ يميل الطالب لطلب الاستئذان في الحصص الأخيرة');
    }

    // Duration Patterns
    if (avgDuration < 3 && countWithReturn > 0) {
      insights.add('✅ يظهر تحسن في العودة السريعة');
    } else if (avgDuration > 7) {
      insights.add('⚠️ يحتاج الطالب دعمًا في إدارة الوقت (مدة طويلة)');
    }

    // 4. Indicators
    // Discipline Indicator
    String discipline = 'High';
    if (lateReturns > bathroomRecords.length * 0.3) {
      discipline = 'Low';
      recommendations.add('تذكير الطالب بالوقت قبل الخروج');
    } else if (lateReturns > 0) {
      discipline = 'Medium';
      recommendations.add('تعزيز الالتزام عند العودة في الوقت المحدد');
    }

    // Stability Indicator
    String stability = 'Stable';
    if (weeklyAverage > 4) {
      stability = 'Volatile';
      recommendations.add('إشراك المرشد الطلابي لدراسة حالة التكرار');
    }

    // Trend
    String trend = 'Stable';
    if (bathroomRecords.length >= 4) {
      final recent = bathroomRecords.take(2);
      final older = bathroomRecords.skip(2).take(2);
      
      double recentDuration = 0;
      for (var r in recent) {
         if (r.bathroomExitTime != null && r.bathroomReturnTime != null) {
           recentDuration += r.bathroomReturnTime!.difference(r.bathroomExitTime!).inMinutes;
         }
      }
      double olderDuration = 0;
      for (var r in older) {
         if (r.bathroomExitTime != null && r.bathroomReturnTime != null) {
           olderDuration += r.bathroomReturnTime!.difference(r.bathroomExitTime!).inMinutes;
         }
      }
      
      if (recentDuration < olderDuration && olderDuration > 0) {
        trend = 'Improving';
      } else if (recentDuration > olderDuration) {
        trend = 'Declining';
      }
    }

    return BathroomAnalysisResult(
      isMedicalCase: false,
      weeklyAverage: weeklyAverage,
      avgDurationMinutes: avgDuration,
      lateReturnCount: lateReturns,
      insights: insights,
      recommendations: recommendations,
      disciplineIndicator: discipline,
      stabilityIndicator: stability,
      trend: trend,
    );
  }
}
