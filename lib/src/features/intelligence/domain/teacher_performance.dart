class TeacherPerformance {
  final String teacherId;
  final String teacherName;
  final double classStabilityScore; // 0-100 (Higher is better)
  final double violationRatio; // Violations per class per week (Lower is better)
  final double attendanceCommitment; // 0-100 (Higher is better)
  final int positiveInteractions; // Number of positive behaviors recorded
  
  TeacherPerformance({
    required this.teacherId,
    required this.teacherName,
    required this.classStabilityScore,
    required this.violationRatio,
    required this.attendanceCommitment,
    required this.positiveInteractions,
  });
  
  String get performanceLabel {
    if (classStabilityScore >= 90) return 'متميز جداً 🌟';
    if (classStabilityScore >= 80) return 'متميز ⭐';
    if (classStabilityScore >= 70) return 'جيد جداً 👍';
    if (classStabilityScore >= 60) return 'جيد';
    return 'يحتاج دعم 🤝';
  }

  // Returns a motivational message based on performance
  String get motivationalMessage {
    if (classStabilityScore >= 95 && attendanceCommitment >= 95 && violationRatio < 0.2) {
      return 'أداء قيادي متميز يا أستاذ $teacherName؛ انضباط عالٍ، حضور منتظم، وبيئة صفية مستقرة تستحق الإشادة.';
    }
    if (classStabilityScore >= 90) {
      return 'أداء استثنائي يا أستاذ $teacherName؛ طلابك يستفيدون من استقرار الفصل وتنظيمك العالي.';
    }
    if (attendanceCommitment >= 90 && violationRatio < 0.4) {
      return 'التزامك بالحضور في الوقت وتأثيرك في استقرار الفصل واضح جداً. استمرارك بهذا النهج يعزز ثقة الطلاب وإدارة المدرسة بك.';
    }
    if (positiveInteractions >= 15) {
      return 'تعزيزك الإيجابي المتكرر للطلاب يصنع بيئة مشجعة وآمنة للتعلم. شكراً لحرصك على الكلمات الطيبة والسلوك المحفز.';
    }
    if (violationRatio < 0.3) {
      return 'معدل المخالفات منخفض، وهذا يعكس وضوحك في إدارة الفصل وحزمك الهادئ مع الطلاب. استمر على هذا التوازن الطيب.';
    }
    if (classStabilityScore >= 70) {
      return 'أداؤك جيد يا أستاذ $teacherName، ومع بعض المتابعة على الطلاب الأكثر حاجة ستنتقل بمؤشر الاستقرار إلى مستوى أعلى بإذن الله.';
    }
    return 'جهودك مقدَّرة يا أستاذ $teacherName، والبيانات تشير إلى أن بعض الفصول تحتاج مزيداً من الدعم؛ الإدارة هنا لمساندتك في وضع خطط بسيطة تعزز الهدوء والتحفيز داخل الصف.';
  }
}
