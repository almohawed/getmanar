// 📊 تحليل نصاب المعلمين - نظام حقيقي
class WorkloadAnalysis {
  final String schoolId;
  final DateTime analyzedAt;
  final int totalTeachers;
  final int totalSlots;
  final double averageWorkload;
  final double fairnessScore; // 0-100%
  final List<TeacherWorkload> teachers;
  final List<SmartRecommendation> recommendations;
  final Map<String, dynamic> statistics;

  WorkloadAnalysis({
    required this.schoolId,
    required this.analyzedAt,
    required this.totalTeachers,
    required this.totalSlots,
    required this.averageWorkload,
    required this.fairnessScore,
    required this.teachers,
    required this.recommendations,
    required this.statistics,
  });

  // حساب العدالة من البيانات الفعلية
  static double calculateFairness(List<TeacherWorkload> teachers) {
    if (teachers.isEmpty) return 100.0;

    final loads = teachers.map((t) => t.currentLoad).toList();
    final mean = loads.reduce((a, b) => a + b) / loads.length;
    
    // حساب الانحراف المعياري
    final variance = loads
        .map((load) => (load - mean) * (load - mean))
        .reduce((a, b) => a + b) / loads.length;
    final stdDev = variance > 0 ? variance : 0.0;

    // تحويل إلى نسبة عدالة (كلما قل الانحراف، زادت العدالة)
    final fairness = 100.0 - (stdDev * 2).clamp(0.0, 100.0);
    return fairness;
  }
}

// 👤 نصاب معلم واحد
class TeacherWorkload {
  final String teacherId;
  final String teacherName;
  final String subject;
  final int currentLoad; // الحصص الفعلية
  final int idealLoad; // النصاب المثالي
  final int waitingSlots; // حصص الانتظار
  final WorkloadStatus status;
  final Map<String, int> dailyDistribution; // توزيع الحصص على الأيام
  final List<String> issues; // المشاكل المكتشفة
  final Map<String, dynamic> details;

  TeacherWorkload({
    required this.teacherId,
    required this.teacherName,
    required this.subject,
    required this.currentLoad,
    required this.idealLoad,
    required this.waitingSlots,
    required this.status,
    required this.dailyDistribution,
    required this.issues,
    required this.details,
  });

  int get difference => currentLoad - idealLoad;
  int get totalLoad => currentLoad + waitingSlots;
  bool get isBalanced => status == WorkloadStatus.balanced;
  bool get isOverloaded => status == WorkloadStatus.overloaded;
  bool get isUnderloaded => status == WorkloadStatus.underloaded;

  // تحديد الحالة من البيانات الفعلية
  static WorkloadStatus determineStatus(int current, int ideal) {
    final diff = current - ideal;
    if (diff.abs() <= 2) return WorkloadStatus.balanced;
    if (diff > 2) return WorkloadStatus.overloaded;
    return WorkloadStatus.underloaded;
  }
}

enum WorkloadStatus {
  balanced,    // عادل (±2 حصص)
  overloaded,  // محمّل (+3 حصص أو أكثر)
  underloaded, // أقل من المطلوب (-3 حصص أو أكثر)
}

// 💡 توصية ذكية قابلة للتطبيق
class SmartRecommendation {
  final String id;
  final RecommendationType type;
  final String description;
  final double impactScore; // التأثير على العدالة (0-100%)
  final List<String> affectedTeachers;
  final Map<String, dynamic> details;
  final bool autoApplicable; // هل يمكن تطبيقها تلقائياً؟
  final int priority; // الأولوية (1-5)

  SmartRecommendation({
    required this.id,
    required this.type,
    required this.description,
    required this.impactScore,
    required this.affectedTeachers,
    required this.details,
    required this.autoApplicable,
    required this.priority,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'impactScore': impactScore,
      'affectedTeachers': affectedTeachers,
      'details': details,
      'autoApplicable': autoApplicable,
      'priority': priority,
    };
  }
}

enum RecommendationType {
  transferClass,      // نقل حصة من معلم لآخر
  addWaitingPeriod,   // إضافة حصة انتظار
  redistributeSubject, // إعادة توزيع مادة
  swapClasses,        // تبديل حصص بين معلمين
  balanceDaily,       // توازن الحصص اليومية
}

// 📈 إحصائيات تفصيلية
class WorkloadStatistics {
  final int balancedTeachers;
  final int overloadedTeachers;
  final int underloadedTeachers;
  final double averageLoad;
  final int minLoad;
  final int maxLoad;
  final double standardDeviation;
  final Map<String, int> loadDistribution;

  WorkloadStatistics({
    required this.balancedTeachers,
    required this.overloadedTeachers,
    required this.underloadedTeachers,
    required this.averageLoad,
    required this.minLoad,
    required this.maxLoad,
    required this.standardDeviation,
    required this.loadDistribution,
  });
}
