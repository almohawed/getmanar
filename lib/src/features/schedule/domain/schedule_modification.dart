import 'package:cloud_firestore/cloud_firestore.dart';

// 📝 تعديل على الجدول
class ScheduleModification {
  final String id;
  final String schoolId;
  final String scheduleId;
  final DateTime timestamp;
  final String modifiedBy; // userId
  final String modifierName;
  final ModificationType type;
  final String description;
  final Map<String, dynamic> before; // البيانات قبل التعديل
  final Map<String, dynamic> after; // البيانات بعد التعديل
  final List<String> affectedTeachers;
  final List<String> affectedClasses;
  final String? reason; // سبب التعديل (اختياري)
  final Map<String, dynamic> metadata;

  ScheduleModification({
    required this.id,
    required this.schoolId,
    required this.scheduleId,
    required this.timestamp,
    required this.modifiedBy,
    required this.modifierName,
    required this.type,
    required this.description,
    required this.before,
    required this.after,
    required this.affectedTeachers,
    required this.affectedClasses,
    this.reason,
    required this.metadata,
  });

  factory ScheduleModification.fromMap(Map<String, dynamic> map) {
    return ScheduleModification(
      id: map['id'] as String,
      schoolId: map['schoolId'] as String,
      scheduleId: map['scheduleId'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      modifiedBy: map['modifiedBy'] as String,
      modifierName: map['modifierName'] as String,
      type: ModificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ModificationType.other,
      ),
      description: map['description'] as String,
      before: Map<String, dynamic>.from(map['before'] as Map),
      after: Map<String, dynamic>.from(map['after'] as Map),
      affectedTeachers: List<String>.from(map['affectedTeachers'] as List),
      affectedClasses: List<String>.from(map['affectedClasses'] as List),
      reason: map['reason'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'scheduleId': scheduleId,
      'timestamp': Timestamp.fromDate(timestamp),
      'modifiedBy': modifiedBy,
      'modifierName': modifierName,
      'type': type.name,
      'description': description,
      'before': before,
      'after': after,
      'affectedTeachers': affectedTeachers,
      'affectedClasses': affectedClasses,
      'reason': reason,
      'metadata': metadata,
    };
  }

  // حساب التأثير
  int get impactScore {
    return (affectedTeachers.length * 2) + affectedClasses.length;
  }

  // هل التعديل كبير؟
  bool get isMajor {
    return impactScore > 5 || type == ModificationType.scheduleReplacement;
  }
}

enum ModificationType {
  slotSwap,              // تبديل حصتين
  slotMove,              // نقل حصة
  teacherChange,         // تغيير معلم
  classChange,           // تغيير صف
  subjectChange,         // تغيير مادة
  periodChange,          // تغيير وقت الحصة
  dayChange,             // تغيير يوم
  slotAdd,               // إضافة حصة
  slotRemove,            // حذف حصة
  scheduleReplacement,   // استبدال الجدول كاملاً
  bulkEdit,              // تعديل جماعي
  other,                 // أخرى
}

// 📊 إحصائيات التعديلات
class ModificationStatistics {
  final int totalModifications;
  final Map<ModificationType, int> byType;
  final Map<String, int> byModifier;
  final Map<String, int> byDay;
  final Map<String, int> byHour;
  final int majorModifications;
  final int minorModifications;
  final double averageImpact;
  final List<String> mostAffectedTeachers;
  final List<String> mostAffectedClasses;

  ModificationStatistics({
    required this.totalModifications,
    required this.byType,
    required this.byModifier,
    required this.byDay,
    required this.byHour,
    required this.majorModifications,
    required this.minorModifications,
    required this.averageImpact,
    required this.mostAffectedTeachers,
    required this.mostAffectedClasses,
  });
}

// 📈 اتجاه التعديلات
class ModificationTrend {
  final DateTime period;
  final int count;
  final double averageImpact;
  final Map<ModificationType, int> typeDistribution;

  ModificationTrend({
    required this.period,
    required this.count,
    required this.averageImpact,
    required this.typeDistribution,
  });
}

// 🔍 مقارنة بين جدولين
class ScheduleComparison {
  final String scheduleId1;
  final String scheduleId2;
  final DateTime comparedAt;
  final int totalDifferences;
  final List<ScheduleDifference> differences;
  final double similarityScore; // 0-100%

  ScheduleComparison({
    required this.scheduleId1,
    required this.scheduleId2,
    required this.comparedAt,
    required this.totalDifferences,
    required this.differences,
    required this.similarityScore,
  });
}

class ScheduleDifference {
  final String type;
  final String description;
  final Map<String, dynamic> schedule1Data;
  final Map<String, dynamic> schedule2Data;

  ScheduleDifference({
    required this.type,
    required this.description,
    required this.schedule1Data,
    required this.schedule2Data,
  });
}
