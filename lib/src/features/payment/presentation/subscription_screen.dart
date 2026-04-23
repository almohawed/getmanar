import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/app_feature.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/subscription_plan.dart';
import '../domain/payment_transaction.dart';
import '../application/payment_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) return;

    // Simulate Google Pay Sheet
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _GooglePaySheet(plan: plan),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(paymentServiceProvider).processPayment(
              schoolId: user.schoolId!,
              userId: user.id,
              plan: plan,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الاشتراك بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh user/school data if needed
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشلت عملية الدفع: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need to fetch current school info to show current plan
    // Assuming authStateProvider gives user, we might need to fetch School separately or user has it
    // For now, we just list plans

    return Scaffold(
      appBar: AppBar(title: const Text('باقات الاشتراك')),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(16.r),
            children: [
              Text(
                'اختر الباقة المناسبة لمدرستك',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              ...SubscriptionPlan.availablePlans.map(
                (plan) =>
                    _PlanCard(plan: plan, onSubscribe: () => _subscribe(plan)),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onSubscribe;

  const _PlanCard({required this.plan, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${plan.price} ${plan.currency} / سنوياً',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              plan.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            Divider(height: 30.h),
            ...plan.features
                .take(4)
                .map(
                  (f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(_getFeatureName(f)),
                        ), // Need a helper for feature names
                      ],
                    ),
                  ),
                ),
            if (plan.features.length > 4)
              Text(
                '+ ${plan.features.length - 4} مميزات أخرى',
                style: const TextStyle(color: Colors.grey),
              ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSubscribe,
                icon: const Icon(Icons.payment),
                label: const Text('اشترك الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeatureName(AppFeature feature) {
    switch (feature) {
      case AppFeature.basicBehavior:
        return 'رصد السلوك الأساسي';
      case AppFeature.studentRecords:
        return 'سجلات الطلاب';
      case AppFeature.teacherAccounts:
        return 'حسابات المعلمين';
      case AppFeature.basicReports:
        return 'تقارير أساسية';
      case AppFeature.adminHierarchy:
        return 'الهيكل الإداري';
      case AppFeature.smartSubstitution:
        return 'توزيع الاحتياط الذكي';
      case AppFeature.digitalPermission:
        return 'الاستئذان الرقمي';
      case AppFeature.excelImport:
        return 'استيراد إكسل';
      case AppFeature.advancedRoles:
        return 'صلاحيات متقدمة';
      case AppFeature.advancedReports:
        return 'تقارير إحصائية';
      case AppFeature.smartAlerts:
        return 'التنبيهات الذكية';
      case AppFeature.smartSchedule:
        return 'الجدول المدرسي الذكي';
      case AppFeature.studentCardsQR:
        return 'بطاقات الطالب QR';
      case AppFeature.parentAccess:
        return 'تفعيل حسابات أولياء الأمور';
      case AppFeature.homeDashboard:
        return 'لوحة المنزل';
      case AppFeature.vipSupport:
        return 'دعم VIP';
      case AppFeature.apiAccess:
        return 'ربط API';
      case AppFeature.geofenceArrival:
        return 'التتبع الجغرافي للوصول';
      case AppFeature.advancedBehaviorAnalysis:
        return 'تحليل السلوك المتقدم';
    }
  }
}

class _GooglePaySheet extends StatelessWidget {
  final SubscriptionPlan plan;

  const _GooglePaySheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GoogleSans', // Assuming font or fallback
                  ),
                ),
                Text(
                  ' Pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'تأكيد الدفع عبر Google Pay',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          Divider(height: 30.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(plan.name), Text('${plan.price} ${plan.currency}')],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('Tax'), Text('0.00 ${plan.currency}')],
          ),
          Divider(height: 30.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${plan.price} ${plan.currency}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 30.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pay with ', style: TextStyle(fontSize: 18.sp)),
                  Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue, // G color
                    ),
                  ),
                  Text(
                    'Pay',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
