import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

final workloadLearningServiceProvider = Provider<WorkloadLearningService>((ref) {
  return WorkloadLearningService();
});

// 🧠 نظام التعلم الذكي - يتعلم من البيانات التاريخية
class WorkloadLearningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔍 تحليل الأنماط التاريخية
  Future<LearningInsights> analyzeHistoricalPatterns(String schoolId) async {
    debugPrint('🧠 [Learning] Analyzing historical patterns for school: $schoolId');

    try {
      // 1. جلب آخر 10 جداول
      final schedulesSnapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Schedules')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (schedulesSnapshot.docs.isEmpty) {
        throw Exception('No historical data found');
      }

      debugPrint('✅ Found ${schedulesSnapshot.docs.length} historical schedules');

      // 2. تحليل الأنماط
      final patterns = await _discoverPatterns(schoolId, schedulesSnapshot.docs);
      
      // 3. اكتشاف التفضيلات
      final preferences = await _discoverPreferences(schoolId, schedulesSnapshot.docs);
      
      // 4. تحليل الاتجاهات
      final trends = await _analyzeTrends(schedulesSnapshot.docs);
      
      // 5. توليد توصيات ذكية
      final smartRecommendations = await _generateSmartRecommendations(
        patterns,
        preferences,
        trends,
      );

      // 6. حفظ الرؤى
      await _saveInsights(schoolId, patterns, preferences, trends);

      return LearningInsights(
        schoolId: schoolId,
        analyzedAt: DateTime.now(),
        totalSchedulesAnalyzed: schedulesSnapshot.docs.length,
        patterns: patterns,
        preferences: preferences,
        trends: trends,
        smartRecommendations: smartRecommendations,
      );

    } catch (e, stack) {
      debugPrint('❌ [Learning] Error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  // 🔎 اكتشاف الأنماط
  Future<List<DiscoveredPattern>> _discoverPatterns(
    String schoolId,
    List<QueryDocumentSnapshot> schedules,
  ) async {
    final patterns = <DiscoveredPattern>[];

    // نمط 1: الأيام المفضلة لكل مادة
    final subjectDayPreferences = <String, Map<String, int>>{};
    
    for (final schedule in schedules) {
      final data = schedule.data() as Map<String, dynamic>;
      if (data['teacherSchedules'] != null) {
        final teacherSchedules = data['teacherSchedules'] as Map<String, dynamic>;
        
        teacherSchedules.forEach((teacherId, slots) {
          for (final slot in slots as List<dynamic>) {
            final slotData = slot as Map<String, dynamic>;
            final subject = slotData['subject'] as String? ?? '';
            final day = slotData['day'] as String? ?? '';
            
            if (subject.isNotEmpty && day.isNotEmpty && !subject.contains('منتظر')) {
              subjectDayPreferences.putIfAbsent(subject, () => {});
              subjectDayPreferences[subject]![day] = 
                (subjectDayPreferences[subject]![day] ?? 0) + 1;
            }
          }
        });
      }
    }

    // تحويل إلى أنماط
    subjectDayPreferences.forEach((subject, dayCount) {
      final sortedDays = dayCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      if (sortedDays.isNotEmpty) {
        final mostPreferredDay = sortedDays.first.key;
        final confidence = (sortedDays.first.value / schedules.length * 100).clamp(0.0, 100.0);
        
        if (confidence > 30) {
          patterns.add(DiscoveredPattern(
            id: 'subject_day_${subject}_$mostPreferredDay',
            type: PatternType.subjectDayPreference,
            description: 'مادة $subject تُدرّس غالباً يوم $mostPreferredDay',
            confidence: confidence,
            occurrences: sortedDays.first.value,
            details: {
              'subject': subject,
              'preferredDay': mostPreferredDay,
              'distribution': Map.fromEntries(sortedDays.take(3)),
            },
          ));
        }
      }
    });

    // نمط 2: الحصص المفضلة لكل مادة
    final subjectPeriodPreferences = <String, Map<int, int>>{};
    
    for (final schedule in schedules) {
      final data = schedule.data() as Map<String, dynamic>;
      if (data['teacherSchedules'] != null) {
        final teacherSchedules = data['teacherSchedules'] as Map<String, dynamic>;
        
        teacherSchedules.forEach((teacherId, slots) {
          for (final slot in slots as List<dynamic>) {
            final slotData = slot as Map<String, dynamic>;
            final subject = slotData['subject'] as String? ?? '';
            final period = slotData['period'] as int? ?? 0;
            
            if (subject.isNotEmpty && period > 0 && !subject.contains('منتظر')) {
              subjectPeriodPreferences.putIfAbsent(subject, () => {});
              subjectPeriodPreferences[subject]![period] = 
                (subjectPeriodPreferences[subject]![period] ?? 0) + 1;
            }
          }
        });
      }
    }

    subjectPeriodPreferences.forEach((subject, periodCount) {
      final sortedPeriods = periodCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      if (sortedPeriods.isNotEmpty) {
        final mostPreferredPeriod = sortedPeriods.first.key;
        final confidence = (sortedPeriods.first.value / schedules.length * 100).clamp(0.0, 100.0);
        
        if (confidence > 30) {
          final timeLabel = _getPeriodLabel(mostPreferredPeriod);
          patterns.add(DiscoveredPattern(
            id: 'subject_period_${subject}_$mostPreferredPeriod',
            type: PatternType.subjectPeriodPreference,
            description: 'مادة $subject تُدرّس غالباً في $timeLabel',
            confidence: confidence,
            occurrences: sortedPeriods.first.value,
            details: {
              'subject': subject,
              'preferredPeriod': mostPreferredPeriod,
              'timeLabel': timeLabel,
            },
          ));
        }
      }
    });

    // نمط 3: المعلمون الذين يفضلون الحصص المبكرة/المتأخرة
    final teacherTimePreferences = <String, Map<String, int>>{};
    
    for (final schedule in schedules) {
      final data = schedule.data() as Map<String, dynamic>;
      if (data['teacherSchedules'] != null) {
        final teacherSchedules = data['teacherSchedules'] as Map<String, dynamic>;
        
        teacherSchedules.forEach((teacherId, slots) {
          teacherTimePreferences.putIfAbsent(teacherId, () => {'early': 0, 'late': 0});
          
          for (final slot in slots as List<dynamic>) {
            final slotData = slot as Map<String, dynamic>;
            final period = slotData['period'] as int? ?? 0;
            final subject = slotData['subject'] as String? ?? '';
            
            if (period > 0 && subject.isNotEmpty && !subject.contains('منتظر')) {
              if (period <= 3) {
                teacherTimePreferences[teacherId]!['early'] = 
                  teacherTimePreferences[teacherId]!['early']! + 1;
              } else if (period >= 5) {
                teacherTimePreferences[teacherId]!['late'] = 
                  teacherTimePreferences[teacherId]!['late']! + 1;
              }
            }
          }
        });
      }
    }

    debugPrint('🔍 Discovered ${patterns.length} patterns');
    return patterns;
  }

  // 💡 اكتشاف التفضيلات
  Future<List<TeacherPreference>> _discoverPreferences(
    String schoolId,
    List<QueryDocumentSnapshot> schedules,
  ) async {
    final preferences = <TeacherPreference>[];

    // جلب بيانات المعلمين
    final teachersSnapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .get();

    final teachersMap = <String, Map<String, dynamic>>{};
    for (final doc in teachersSnapshot.docs) {
      teachersMap[doc.id] = {...doc.data(), 'id': doc.id};
    }

    // تحليل تفضيلات كل معلم
    for (final teacherId in teachersMap.keys) {
      final teacherData = teachersMap[teacherId]!;
      final teacherName = teacherData['name'] as String? ?? 'معلم';
      
      // حساب متوسط الحصص في كل يوم
      final dailyAverages = <String, double>{};
      final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
      
      for (final day in days) {
        int totalSlots = 0;
        int scheduleCount = 0;
        
        for (final schedule in schedules) {
          final data = schedule.data() as Map<String, dynamic>;
          if (data['teacherSchedules'] != null) {
            final teacherSchedules = data['teacherSchedules'] as Map<String, dynamic>;
            if (teacherSchedules.containsKey(teacherId)) {
              final slots = teacherSchedules[teacherId] as List<dynamic>;
              final daySlots = slots.where((s) {
                final slotData = s as Map<String, dynamic>;
                return slotData['day'] == day && 
                       !(slotData['subject'] as String).contains('منتظر');
              }).length;
              
              totalSlots += daySlots;
              scheduleCount++;
            }
          }
        }
        
        if (scheduleCount > 0) {
          dailyAverages[day] = totalSlots / scheduleCount;
        }
      }

      // اكتشاف اليوم المفضل
      if (dailyAverages.isNotEmpty) {
        final sortedDays = dailyAverages.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        final preferredDay = sortedDays.first.key;
        final avgSlots = sortedDays.first.value;
        
        if (avgSlots > 3) {
          preferences.add(TeacherPreference(
            teacherId: teacherId,
            teacherName: teacherName,
            preferenceType: PreferenceType.preferredDay,
            description: '$teacherName يفضل يوم $preferredDay (متوسط ${avgSlots.toStringAsFixed(1)} حصص)',
            confidence: min(avgSlots * 15, 100),
            details: {
              'preferredDay': preferredDay,
              'averageSlots': avgSlots,
              'allDays': dailyAverages,
            },
          ));
        }
      }
    }

    debugPrint('💡 Discovered ${preferences.length} preferences');
    return preferences;
  }

  // 📈 تحليل الاتجاهات
  Future<List<Trend>> _analyzeTrends(List<QueryDocumentSnapshot> schedules) async {
    final trends = <Trend>[];

    // اتجاه 1: تغير متوسط الحصص
    final avgLoads = <double>[];
    for (final schedule in schedules) {
      final data = schedule.data() as Map<String, dynamic>;
      if (data['teacherSchedules'] != null) {
        final teacherSchedules = data['teacherSchedules'] as Map<String, dynamic>;
        int totalSlots = 0;
        int teacherCount = 0;
        
        teacherSchedules.forEach((teacherId, slots) {
          final teachingSlots = (slots as List<dynamic>).where((s) {
            final slotData = s as Map<String, dynamic>;
            return !(slotData['subject'] as String).contains('منتظر');
          }).length;
          
          totalSlots += teachingSlots;
          teacherCount++;
        });
        
        if (teacherCount > 0) {
          avgLoads.add(totalSlots / teacherCount);
        }
      }
    }

    if (avgLoads.length >= 3) {
      final recentAvg = avgLoads.take(3).reduce((a, b) => a + b) / 3;
      final oldAvg = avgLoads.skip(max(0, avgLoads.length - 3)).reduce((a, b) => a + b) / 
                     min(3, avgLoads.length - max(0, avgLoads.length - 3));
      final change = ((recentAvg - oldAvg) / oldAvg * 100);
      
      if (change.abs() > 5) {
        trends.add(Trend(
          id: 'avg_load_trend',
          type: TrendType.workloadChange,
          description: change > 0 
            ? 'متوسط الحصص في ازدياد (${change.toStringAsFixed(1)}%)'
            : 'متوسط الحصص في انخفاض (${change.abs().toStringAsFixed(1)}%)',
          direction: change > 0 ? TrendDirection.increasing : TrendDirection.decreasing,
          magnitude: change.abs(),
          details: {
            'recentAverage': recentAvg,
            'oldAverage': oldAvg,
            'change': change,
          },
        ));
      }
    }

    debugPrint('📈 Discovered ${trends.length} trends');
    return trends;
  }

  // 🎯 توليد توصيات ذكية من التعلم
  Future<List<SmartLearningRecommendation>> _generateSmartRecommendations(
    List<DiscoveredPattern> patterns,
    List<TeacherPreference> preferences,
    List<Trend> trends,
  ) async {
    final recommendations = <SmartLearningRecommendation>[];

    // توصيات من الأنماط
    for (final pattern in patterns) {
      if (pattern.confidence > 50) {
        recommendations.add(SmartLearningRecommendation(
          id: 'pattern_${pattern.id}',
          title: 'استخدم النمط المكتشف',
          description: pattern.description,
          impact: pattern.confidence,
          source: 'تحليل الأنماط',
          actionable: true,
          details: pattern.details,
        ));
      }
    }

    // توصيات من التفضيلات
    for (final pref in preferences) {
      if (pref.confidence > 60) {
        recommendations.add(SmartLearningRecommendation(
          id: 'pref_${pref.teacherId}',
          title: 'راعِ تفضيلات المعلم',
          description: pref.description,
          impact: pref.confidence,
          source: 'تحليل التفضيلات',
          actionable: true,
          details: pref.details,
        ));
      }
    }

    // ترتيب حسب التأثير
    recommendations.sort((a, b) => b.impact.compareTo(a.impact));

    return recommendations.take(10).toList();
  }

  // 💾 حفظ الرؤى
  Future<void> _saveInsights(
    String schoolId,
    List<DiscoveredPattern> patterns,
    List<TeacherPreference> preferences,
    List<Trend> trends,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('WorkloadInsights')
        .doc('latest')
        .set({
      'analyzedAt': FieldValue.serverTimestamp(),
      'patterns': patterns.map((p) => p.toMap()).toList(),
      'preferences': preferences.map((p) => p.toMap()).toList(),
      'trends': trends.map((t) => t.toMap()).toList(),
    });

    debugPrint('💾 Saved insights to Firestore');
  }

  String _getPeriodLabel(int period) {
    if (period <= 2) return 'الحصص المبكرة';
    if (period <= 4) return 'الحصص الوسطى';
    return 'الحصص المتأخرة';
  }
}

// 🧠 رؤى التعلم
class LearningInsights {
  final String schoolId;
  final DateTime analyzedAt;
  final int totalSchedulesAnalyzed;
  final List<DiscoveredPattern> patterns;
  final List<TeacherPreference> preferences;
  final List<Trend> trends;
  final List<SmartLearningRecommendation> smartRecommendations;

  LearningInsights({
    required this.schoolId,
    required this.analyzedAt,
    required this.totalSchedulesAnalyzed,
    required this.patterns,
    required this.preferences,
    required this.trends,
    required this.smartRecommendations,
  });
}

// 🔍 نمط مكتشف
class DiscoveredPattern {
  final String id;
  final PatternType type;
  final String description;
  final double confidence; // 0-100%
  final int occurrences;
  final Map<String, dynamic> details;

  DiscoveredPattern({
    required this.id,
    required this.type,
    required this.description,
    required this.confidence,
    required this.occurrences,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'confidence': confidence,
      'occurrences': occurrences,
      'details': details,
    };
  }
}

enum PatternType {
  subjectDayPreference,
  subjectPeriodPreference,
  teacherTimePreference,
  consecutivePattern,
}

// 💡 تفضيل معلم
class TeacherPreference {
  final String teacherId;
  final String teacherName;
  final PreferenceType preferenceType;
  final String description;
  final double confidence;
  final Map<String, dynamic> details;

  TeacherPreference({
    required this.teacherId,
    required this.teacherName,
    required this.preferenceType,
    required this.description,
    required this.confidence,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'preferenceType': preferenceType.name,
      'description': description,
      'confidence': confidence,
      'details': details,
    };
  }
}

enum PreferenceType {
  preferredDay,
  preferredPeriod,
  avoidedDay,
  avoidedPeriod,
}

// 📈 اتجاه
class Trend {
  final String id;
  final TrendType type;
  final String description;
  final TrendDirection direction;
  final double magnitude;
  final Map<String, dynamic> details;

  Trend({
    required this.id,
    required this.type,
    required this.description,
    required this.direction,
    required this.magnitude,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'direction': direction.name,
      'magnitude': magnitude,
      'details': details,
    };
  }
}

enum TrendType {
  workloadChange,
  fairnessChange,
  distributionChange,
}

enum TrendDirection {
  increasing,
  decreasing,
  stable,
}

// 🎯 توصية ذكية من التعلم
class SmartLearningRecommendation {
  final String id;
  final String title;
  final String description;
  final double impact;
  final String source;
  final bool actionable;
  final Map<String, dynamic> details;

  SmartLearningRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.impact,
    required this.source,
    required this.actionable,
    required this.details,
  });
}
