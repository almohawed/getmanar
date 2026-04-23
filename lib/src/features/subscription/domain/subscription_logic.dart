import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/school.dart';
export '../../../core/domain/models/app_feature.dart';
import '../../../core/domain/models/app_feature.dart';

enum SubscriptionPlanType {
  starter, // باقة الأساس
  smart, // الإدارة الذكية
  elite, // التميز المدرسي
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<AppFeature> features;
  final bool isPopular;
  final String targetAudience;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.isPopular = false,
    required this.targetAudience,
  });

  bool hasFeature(AppFeature feature) => features.contains(feature);

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? description,
    double? monthlyPrice,
    double? yearlyPrice,
    List<AppFeature>? features,
    bool? isPopular,
    String? targetAudience,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      targetAudience: targetAudience ?? this.targetAudience,
    );
  }
}

final plans = [
  const SubscriptionPlan(
    id: 'starter',
    name: 'تشغيل مدرستك رقمياً (Starter)',
    description: 'ابدأ تشغيل مدرستك رقمياً خلال أسبوع واحد بدون تعقيد.',
    monthlyPrice: 49,
    yearlyPrice: 490,
    features: [
      AppFeature.basicBehavior,
      AppFeature.studentRecords,
      AppFeature.teacherAccounts,
      AppFeature.basicReports,
    ],
    targetAudience: 'مناسب للمدارس التي تبدأ التحول الرقمي',
  ),
  const SubscriptionPlan(
    id: 'smart',
    name: 'مدرسة منضبطة (Professional)',
    description: 'سيطرة كاملة على الحضور والسلوك وتقليل المشاكل اليومية بشكل واضح.',
    monthlyPrice: 99,
    yearlyPrice: 990,
    features: [
      AppFeature.basicBehavior,
      AppFeature.studentRecords,
      AppFeature.teacherAccounts,
      AppFeature.basicReports,
      AppFeature.adminHierarchy,
      AppFeature.smartSubstitution,
      AppFeature.digitalPermission,
      AppFeature.excelImport,
      AppFeature.advancedRoles,
      AppFeature.advancedReports,
      AppFeature.smartAlerts,
    ],
    isPopular: true,
    targetAudience: 'مناسب للمدارس التي تعاني من الغياب أو السلوك',
  ),
  const SubscriptionPlan(
    id: 'elite',
    name: 'مدرسة قيادية ذكية (Elite)',
    description: 'قيادة المدرسة بالبيانات والتنبؤ بالمشاكل قبل حدوثها.',
    monthlyPrice: 199,
    yearlyPrice: 1990,
    features: [
      // Elite Exclusive Features (Top Priority)
      AppFeature.smartSchedule,
      AppFeature.studentCardsQR,
      AppFeature.parentAccess,
      AppFeature.homeDashboard,
      AppFeature.geofenceArrival,
      AppFeature.apiAccess, // Rebranded as Advanced Smart Notifications
      AppFeature.vipSupport,
      // Included from previous plans
      AppFeature.adminHierarchy,
      AppFeature.smartSubstitution,
      AppFeature.digitalPermission,
      AppFeature.excelImport,
      AppFeature.advancedRoles,
      AppFeature.advancedReports,
      AppFeature.smartAlerts,
      AppFeature.basicBehavior,
      AppFeature.studentRecords,
      AppFeature.teacherAccounts,
      AppFeature.basicReports,
    ],
    targetAudience: 'مناسب للمدارس القيادية والمتميزة',
  ),
];

// Provider to manage current plan state
final currentPlanProvider =
    NotifierProvider<CurrentPlanNotifier, SubscriptionPlanType>(
      CurrentPlanNotifier.new,
    );

class CurrentPlanNotifier extends Notifier<SubscriptionPlanType> {
  @override
  SubscriptionPlanType build() => SubscriptionPlanType.starter;

  void setPlan(SubscriptionPlanType plan) {
    state = plan;
  }
}

// Helper to check feature access
final featureAccessProvider = Provider.family<bool, AppFeature>((ref, feature) {
  final currentPlanType = ref.watch(currentPlanProvider);
  String planId = 'starter'; // Default value
  switch (currentPlanType) {
    case SubscriptionPlanType.starter:
      planId = 'starter';
      break;
    case SubscriptionPlanType.smart:
      planId = 'smart';
      break;
    case SubscriptionPlanType.elite:
      planId = 'elite';
      break;
  }
  final plan = plans.firstWhere(
    (p) => p.id == planId,
    orElse: () => plans.first,
  );
  return plan.hasFeature(feature);
});

extension SchoolSubscriptionExt on School {
  bool hasAccess(AppFeature feature) {
    if (isLifetimeAccess) return true;

    // Check trial
    // if (trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now())) {
    //   return true; // Trial has full access
    // }

    // Check plan
    final plan = plans.firstWhere(
      (p) => p.id == subscriptionPlan,
      orElse: () => plans.first, // Default to starter if plan not found
    );

    return plan.hasFeature(feature);
  }

  SubscriptionPlan getPlan() {
    return plans.firstWhere(
      (p) => p.id == subscriptionPlan,
      orElse: () => plans.first,
    );
  }
}
