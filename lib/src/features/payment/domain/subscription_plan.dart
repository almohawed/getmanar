import '../../../core/domain/models/app_feature.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency; // SAR
  final int durationMonths;
  final List<AppFeature> features;
  final int maxStudents;
  final int maxTeachers;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'SAR',
    required this.durationMonths,
    required this.features,
    required this.maxStudents,
    required this.maxTeachers,
  });

  // Predefined Plans
  static const List<SubscriptionPlan> availablePlans = [
    SubscriptionPlan(
      id: 'basic',
      name: 'الباقة الأساسية',
      description: 'مناسبة للمدارس الصغيرة والمبتدئة',
      price: 0,
      durationMonths: 12,
      features: [
        AppFeature.basicBehavior,
        AppFeature.studentRecords,
        AppFeature.basicReports,
      ],
      maxStudents: 100,
      maxTeachers: 10,
    ),
    SubscriptionPlan(
      id: 'standard',
      name: 'الباقة المتقدمة',
      description: 'للمدارس المتوسطة التي تحتاج إلى إدارة متكاملة',
      price: 1999,
      durationMonths: 12,
      features: [
        AppFeature.basicBehavior,
        AppFeature.studentRecords,
        AppFeature.basicReports,
        AppFeature.digitalPermission,
        AppFeature.excelImport,
        AppFeature.smartAlerts,
        AppFeature.teacherAccounts,
      ],
      maxStudents: 500,
      maxTeachers: 50,
    ),
    SubscriptionPlan(
      id: 'premium',
      name: 'الباقة الشاملة',
      description: 'حلول ذكية متكاملة للمدارس الكبيرة',
      price: 3999,
      durationMonths: 12,
      features: [
        AppFeature.basicBehavior,
        AppFeature.studentRecords,
        AppFeature.basicReports,
        AppFeature.digitalPermission,
        AppFeature.excelImport,
        AppFeature.smartAlerts,
        AppFeature.teacherAccounts,
        AppFeature.smartSchedule,
        AppFeature.adminHierarchy,
        AppFeature.advancedReports,
        AppFeature.studentCardsQR,
        AppFeature.parentAccess,
        AppFeature.vipSupport,
      ],
      maxStudents: 2000,
      maxTeachers: 200,
    ),
  ];
}
