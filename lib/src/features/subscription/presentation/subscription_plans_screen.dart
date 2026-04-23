import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../domain/subscription_logic.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../data/subscription_repository.dart';
import '../../../core/domain/models/school.dart';
import 'subscription_invoice_screen.dart';

class SubscriptionPlansScreen extends ConsumerStatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  ConsumerState<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState
    extends ConsumerState<SubscriptionPlansScreen> {
  bool _isYearly = true;
  int? _selectedPlanIndex;
  bool _isLoading = false;

  void _activateSubscription(SubscriptionPlan plan) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لم يتم العثور على بيانات المدرسة')),
      );
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final billingCycle = _isYearly ? 'yearly' : 'monthly';
      final checkout = await repo.createSubscriptionCheckout(
        schoolId: user.schoolId!,
        planId: plan.id,
        billingCycle: billingCycle,
      );
      if (!mounted) {
        return;
      }
      final transactionId = checkout['transactionId'] as String?;
      if (transactionId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إنشاء طلب الدفع')));
        return;
      }
      await _showPaymentStatusDialog(
        plan: plan,
        billingCycle: billingCycle,
        transactionId: transactionId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إنشاء طلب الدفع: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPaymentStatusDialog({
    required SubscriptionPlan plan,
    required String billingCycle,
    required String transactionId,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return;
    }

    String status = 'pending';
    bool confirming = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'متابعة الدفع',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المبلغ:', style: TextStyle(fontSize: 13.sp)),
                      Text(
                        '${billingCycle == 'yearly' ? plan.yearlyPrice.toInt() : plan.monthlyPrice.toInt()} ريال',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('دورة الفوترة:', style: TextStyle(fontSize: 13.sp)),
                      Text(
                        billingCycle == 'yearly' ? 'سنوي' : 'شهري',
                        style: TextStyle(fontSize: 13.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: status == 'verified'
                              ? Colors.green
                              : status == 'failed' || status == 'cancelled'
                              ? Colors.red
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        status == 'verified'
                            ? 'الحالة: تم التحقق من الاشتراك'
                            : status == 'failed'
                            ? 'الحالة: فشل التحقق من الاشتراك'
                            : status == 'cancelled'
                            ? 'الحالة: تم إلغاء عملية الدفع'
                            : 'الحالة: جار التحقق من عملية الدفع',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'بعد إتمام عملية الدفع، اضغط على زر "تأكيد الدفع" ليتم التحقق من الاشتراك من السيرفر وتفعيل الباقة.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: confirming
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('إغلاق'),
                ),
                ElevatedButton(
                  onPressed: confirming
                      ? null
                      : () async {
                          setState(() {
                            confirming = true;
                          });
                          try {
                            final repo = ref.read(
                              subscriptionRepositoryProvider,
                            );
                            final result = await repo
                                .confirmSubscriptionPayment(
                                  schoolId: user.schoolId!,
                                  transactionId: transactionId,
                                );
                            final rawStatus =
                                result['status'] as String? ?? 'verified';
                            final resultStatus =
                                rawStatus == 'paid' || rawStatus == 'activated'
                                ? 'verified'
                                : rawStatus;
                            setState(() {
                              status = resultStatus;
                              confirming = false;
                            });
                            if (resultStatus == 'verified') {
                              final subscriptionEndsAtStr =
                                  result['subscriptionEndsAt'] as String?;
                              DateTime? subscriptionEndsAt;
                              if (subscriptionEndsAtStr != null) {
                                subscriptionEndsAt = DateTime.tryParse(
                                  subscriptionEndsAtStr,
                                );
                              }
                              final purchaseDate = DateTime.now();
                              final amount = billingCycle == 'yearly'
                                  ? plan.yearlyPrice.toInt()
                                  : plan.monthlyPrice.toInt();

                              ref.invalidate(schoolProvider(user.schoolId!));
                              ref.invalidate(
                                schoolSubscriptionProvider(user.schoolId!),
                              );
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم تفعيل باقة ${plan.name} بنجاح.',
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                context.go(
                                  '/subscription-invoice',
                                  extra: SubscriptionInvoiceArgs(
                                    transactionId: transactionId,
                                    planId: plan.id,
                                    planName: plan.name,
                                    billingCycle: billingCycle,
                                    amount: amount,
                                    currency: 'SAR',
                                    purchaseDate: purchaseDate,
                                    subscriptionEndsAt: subscriptionEndsAt,
                                  ),
                                );
                              }
                            } else if (resultStatus == 'failed') {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تعذر التحقق من الاشتراك، يرجى المحاولة مرة أخرى.',
                                    ),
                                  ),
                                );
                              }
                            } else if (resultStatus == 'cancelled') {
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم إلغاء عملية الدفع قبل إتمامها.',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() {
                              status = 'failed';
                              confirming = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'حدث خطأ أثناء تأكيد الدفع: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: confirming
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('تأكيد الدفع'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(subscriptionPricesProvider);
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC), // Light professional background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'باقات منار',
          style: TextStyle(
            color: const Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => context.go('/dashboard'), // Or login
        ),
      ),
      body: pricesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading prices: $e')),
        data: (prices) {
          final school = schoolId != null
              ? ref.watch(schoolProvider(schoolId)).value
              : null;
          final subscription = schoolId != null
              ? ref.watch(schoolSubscriptionProvider(schoolId)).value
              : null;
          final displayPlans = plans.map((p) {
            final pPrices = prices[p.id];
            if (pPrices != null) {
              return p.copyWith(
                monthlyPrice: pPrices['monthly'],
                yearlyPrice: pPrices['yearly'],
              );
            }
            return p;
          }).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeroHeader(school, subscription),
                SizedBox(height: 24.h),

                _buildAdaptiveEngineCard(),

                SizedBox(height: 32.h),

                _buildBillingToggle(),

                SizedBox(height: 24.h),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayPlans.length,
                  separatorBuilder: (c, i) => SizedBox(height: 20.h),
                  itemBuilder: (context, index) {
                    final plan = displayPlans[index];
                    return _buildPlanCard(plan, index, subscription);
                  },
                ),

                SizedBox(height: 32.h),

                _buildWhyManarSection(),
                SizedBox(height: 16.h),
                _buildSecurityAssuranceSection(),
                SizedBox(height: 16.h),
                _buildFinalPitch(),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdaptiveEngineCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF283593), Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧠 المحرك الذكي لمنار',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'مشمول في جميع الباقات',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'يفهم وضع مدرستك يوميًا ويقترح إجراءات مباشرة لتحسين الانضباط وتقليل المشاكل قبل حدوثها.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(School? school, Map<String, dynamic>? subscription) {
    final stageLabel = _getStageLabelForSchool(school);
    final statusLabel = _getStatusLabel(school);
    final statusColor = _getStatusColor(school);
    final expiryDate = school?.subscriptionEndsAt;
    final expiryText = school?.isLifetimeAccess == true
        ? 'مدى الحياة'
        : _formatDate(expiryDate);
    final statusBannerText = statusLabel == 'غير مفعّل'
        ? '🚀 مدرستك حالياً: غير مفعّلة — ابدأ الآن لتفعيل النظام خلال دقائق'
        : statusLabel == 'نشط'
        ? '✅ مدرستك حالياً: مفعّلة — يمكنك الترقية لأي باقة في أي وقت'
        : statusLabel == 'منتهي'
        ? '⚠️ مدرستك حالياً: منتهية — فعّل باقة الآن لاستعادة التشغيل'
        : statusLabel == 'فترة تجريبية'
        ? '🧪 مدرستك حالياً: في فترة تجريبية — فعّل باقة لاستمرار الخدمة'
        : '🚀 مدرستك حالياً: $statusLabel';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حوّل مدرستك إلى مدرسة منضبطة وذكية خلال أيام',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A237E),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'نظام متكامل يساعدك على ضبط الحضور والسلوك واتخاذ القرار بثقة.',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusBannerText,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A237E),
                height: 1.4,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroInfoTile(
                  'المرحلة الحالية',
                  stageLabel,
                  Icons.school_outlined,
                  const Color(0xFF1A237E),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildHeroInfoTile(
                  'حالة الاشتراك',
                  statusLabel,
                  Icons.verified_outlined,
                  statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildHeroInfoTile(
            'تاريخ الانتهاء',
            expiryText,
            Icons.event_outlined,
            const Color(0xFF455A64),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroInfoTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStageLabelForSchool(School? school) {
    if (school == null) {
      return 'لم يتم اختيار مرحلة بعد';
    }
    final base = _getStageNameFromPlanId(school.subscriptionPlan);
    if (school.isLifetimeAccess) {
      return '$base (وصول مدى الحياة)';
    }
    return base;
  }

  String _getStageNameFromPlanId(String planId) {
    switch (planId) {
      case 'starter':
        return 'مرحلة تشغيل';
      case 'smart':
        return 'مرحلة إدارة ذكية';
      case 'elite':
        return 'مرحلة قيادة ذكية';
      default:
        return 'مرحلة تشغيل';
    }
  }

  String _getStatusLabel(School? school) {
    final now = DateTime.now();
    if (school == null) {
      return 'غير مفعّل';
    }
    if (school.isLifetimeAccess) {
      return 'وصول مدى الحياة';
    }
    if (school.subscriptionEndsAt != null) {
      if (school.subscriptionEndsAt!.isAfter(now)) {
        return 'نشط';
      } else {
        return 'منتهي';
      }
    }
    if (school.trialEndsAt != null && school.trialEndsAt!.isAfter(now)) {
      return 'فترة تجريبية';
    }
    return 'غير مفعّل';
  }

  Color _getStatusColor(School? school) {
    final now = DateTime.now();
    if (school == null) {
      return Colors.grey;
    }
    if (school.isLifetimeAccess) {
      return const Color(0xFF283593);
    }
    if (school.subscriptionEndsAt != null) {
      if (school.subscriptionEndsAt!.isAfter(now)) {
        return Colors.green;
      } else {
        return Colors.red;
      }
    }
    if (school.trialEndsAt != null && school.trialEndsAt!.isAfter(now)) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'غير محدد';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$year/$month/$day';
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('شهري', !_isYearly),
          _buildToggleOption('سنوي ⭐ موفّر', _isYearly),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _isYearly = text.contains('سنوي')),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1A237E) : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    int index,
    Map<String, dynamic>? subscription,
  ) {
    final isSelected = _selectedPlanIndex == index;
    final isPopular = plan.isPopular;
    final currentPlanId = subscription?['planId'] as String?;
    final isCurrentPlan = currentPlanId == plan.id;

    Color planColor;
    if (plan.id == 'starter') {
      planColor = Colors.teal;
    } else if (plan.id == 'smart') {
      planColor = const Color(0xFFEF6C00);
    } else {
      planColor = const Color(0xFF6A1B9A);
    }

    final isElite = plan.id == 'elite';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Transform.scale(
        scale: isPopular ? 1.04 : (isElite ? 1.02 : 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? planColor : Colors.grey.shade200,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isElite
                          ? Colors.amber.withValues(alpha: 0.3)
                          : planColor.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: planColor,
                            size: 24.sp,
                          ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      plan.description,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: planColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16.sp,
                            color: planColor,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _getPlanOutcomeText(plan.id),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: planColor,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_isYearly ? plan.yearlyPrice.toInt() : plan.monthlyPrice.toInt()}',
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'ريال / ${_isYearly ? "سنة" : "شهر"}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    Divider(color: Colors.grey[200]),
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: planColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, size: 16.sp, color: planColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'لمن هذه الباقة: ${plan.targetAudience}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: planColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ..._buildKeyBullets(plan.id),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showPlanDetails(plan),
                        child: Text(
                          'عرض التفاصيل',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (!isSelected) {
                                  setState(() => _selectedPlanIndex = index);
                                }
                                _activateSubscription(plan);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? planColor
                              : Colors.white,
                          foregroundColor: isSelected
                              ? Colors.white
                              : planColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: planColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: isSelected ? 4 : 0,
                        ),
                        child: _isLoading && isSelected
                            ? SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isSelected
                                    ? 'متابعة الدفع'
                                    : _getPlanButtonLabel(plan.id),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentPlan)
                Positioned(
                  top: -12,
                  right: 24,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'خطة مدرستك الحالية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (isPopular)
                Positioned(
                  top: -12,
                  left: 24,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 12.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'الأكثر طلباً',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeatureHighlights(SubscriptionPlan plan) {
    return [
      ..._getPlanFeatureTexts(plan).map(
        (feature) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18.sp,
                color: Colors.green,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  feature,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<String> _getPlanFeatureTexts(SubscriptionPlan plan) {
    const starterFeatures = [
      'تسجيل دخول موحّد لكل الأدوار (مدير/وكيل/مرشد/معلم/طالب/ولي أمر).',
      'سجلات الطلاب والفصول: قائمة الطلاب + تفاصيل الطالب الأساسية.',
      'الحضور والغياب للطلاب: تسجيل حضور/غياب + عرض سجل الطالب.',
      'لوحة المعلم الأساسية: عرض الطلاب + أدوات المتابعة اليومية.',
      'لوحة ولي الأمر والطالب: عرض الحضور + السلوك + الواجبات + الإشعارات.',
      'السلوك الأساسي: تسجيل ملاحظات/مخالفات صفية من المعلم.',
      'سجل المخالفات: عرض المخالفات مع الفلاتر (حسب الفصل/الطالب).',
      'إشعارات داخل التطبيق: ظهور التنبيهات داخل NotificationsScreen.',
      'تقارير PDF أساسية: طباعة كشوفات مختصرة (حضور/سلوك/قوائم).',
      'إدارة بيانات المدرسة الأساسية: إعدادات المدرسة + الصفوف + الكوادر (أساسي).',
    ];

    const smartFeatures = [
      'إدارة الكوادر بشكل كامل: إضافة/إدارة المعلمين والموظفين وربطهم بالفصول.',
      'إدارة الصلاحيات والتفويض: Delegated Permissions حسب الدور.',
      'الاختبارات والدرجات: جدول الاختبارات + متابعة الدرجات + اللجان/الغياب.',
      'الواجبات والمهام الصفية: إنشاء واجبات + متابعة تسليم + ربط بالمادة/الفصل.',
      'اعتماد/رفض مخالفات السلوك: شاشة الوكيل لاعتماد/رفض وتوجيه الإجراء.',
      'الاستئذان الرقمي (Bathroom Pass): خروج/عودة + احتساب الوقت + مؤشرات انضباط.',
      'سلوك بدون اتصال (Offline): حفظ الملاحظات محليًا ثم مزامنة عند توفر الإنترنت.',
      'الإعلانات والإشعارات الإدارية: إرسال إعلان/تنبيه عام من الإدارة داخل التطبيق.',
      'تصدير Excel: تصدير قوائم وبيانات (طلاب/حضور/سلوك).',
      'المهام الإدارية (AdminTasks): إنشاء مهام + متابعة الحالة + مرفقات/أدلة.',
      'لوحات متابعة أوسع: تبويبات متابعة الأداء الأكاديمي والسلوكي بشكل أكبر.',
      'مؤشرات تشغيل المدرسة: ملخصات الانضباط والحضور على مستوى المدرسة.',
    ];

    const eliteFeatures = [
      'مؤشر السلوك الطلابي (Behavior Index): تحليل أسبوعي + مؤشرات + اتجاهات + أسباب رئيسية.',
      'تحليل سلوك الطالب زمنيًا: أنماط اليوم/الحصص + تكرار السلوك + محفزات.',
      '“أول إجراء هذا الأسبوع” للقيادة: خطة متابعة أسبوعية + توصيات مرتبطة بالبيانات.',
      'تتبع فعالية التدخلات: InterventionEffectiveness (هل الإجراء فعّال؟ وما الأفضل لنفس النمط؟).',
      'تحليل تأثير الأصدقاء (Friends Influence): ربط شبكة الأصدقاء بتغير السلوك/التحصيل.',
      'تصنيف المخاطر والتوقعات: توقع احتمالات التصعيد + مستوى الخطر + إشارات مبكرة.',
      'تنبيهات ذكية صامتة للقيادة: إشعار عند تغيّر أولوية المتابعة أسبوعيًا (بدون تكرار).',
      'محرك تحليلات المدرسة: مؤشرات عامة للانضباط والحضور والأثر التعليمي (Executive KPIs).',
      'تحليل ضغط الفصول: كشف الفصول التي ترفع المشاكل عبر أكثر من معلم/حصة.',
      'ملف سلوكي أسبوعي للطالب: StudentWeeklyBehaviorProfiles بصلاحيات دقيقة (طالب يرى ملخصه).',
      'تقارير قيادية PDF متقدمة: تقارير أعمق جاهزة للطباعة (سلوك/حضور/مقارنات).',
      'لوحات قيادة متقدمة: بطاقات KPI + دوائر تقدم + اتجاهات + ألوان مخاطر.',
    ];

    switch (plan.id) {
      case 'starter':
        return starterFeatures;
      case 'smart':
        return smartFeatures;
      case 'elite':
        return eliteFeatures;
      default:
        return [];
    }
  }

  String _getPlanButtonLabel(String planId) {
    switch (planId) {
      case 'starter':
        return 'ابدأ تشغيل مدرستي الآن';
      case 'smart':
        return 'أريد ضبط الانضباط';
      case 'elite':
        return 'فعّل القيادة الذكية';
      default:
        return 'اختيار الباقة';
    }
  }

  String _getPlanOutcomeText(String planId) {
    switch (planId) {
      case 'starter':
        return 'تشغيل المدرسة رقمياً خلال أسبوع واحد';
      case 'smart':
        return 'ضبط الانضباط وتقليل المشاكل اليومية بشكل ملحوظ';
      case 'elite':
        return 'قيادة المدرسة بالبيانات واتخاذ قرارات ذكية';
      default:
        return 'تحسين تشغيل المدرسة بشكل ملحوظ';
    }
  }

  List<Widget> _buildKeyBullets(String planId) {
    final bullets = _getPlanKeyBullets(planId);
    return bullets
        .map(
          (t) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18.sp,
                  color: Colors.green,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    t,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  List<String> _getPlanKeyBullets(String planId) {
    switch (planId) {
      case 'starter':
        return const [
          'تسجيل حضور وغياب الطلاب بسهولة.',
          'متابعة الطالب يوميًا للمعلم وولي الأمر.',
          'تقارير أساسية جاهزة للطباعة.',
        ];
      case 'smart':
        return const [
          'متابعة دقيقة للغياب والسلوك.',
          'صلاحيات ذكية للإدارة والوكلاء.',
          'تقارير تحليلية تساعدك على اتخاذ القرار.',
        ];
      case 'elite':
        return const [
          'تحليل سلوك الطلاب والتنبؤ بالمشاكل.',
          'توصيات ذكية للإدارة بشكل يومي.',
          'مؤشرات أداء متقدمة (KPIs).',
        ];
      default:
        return const [];
    }
  }

  Future<void> _showPlanDetails(SubscriptionPlan plan) async {
    final features = _getPlanFeatureTexts(plan);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A237E),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  plan.description,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  textAlign: TextAlign.right,
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: features.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final t = features[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check, size: 18.sp, color: Colors.green),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[800],
                                height: 1.35,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhyManarSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لماذا منار؟',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A237E),
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 12.h),
          _whyRow(
            Icons.verified_user_outlined,
            'متوافق مع أنظمة وزارة التعليم',
          ),
          SizedBox(height: 10.h),
          _whyRow(
            Icons.school_outlined,
            'مناسب للمدارس ويعمل في بيئات تعليمية حقيقية',
          ),
          SizedBox(height: 10.h),
          _whyRow(Icons.work_outline, 'يقلل العبء الإداري على المعلمين'),
          SizedBox(height: 10.h),
          _whyRow(Icons.insights_outlined, 'يساعد المدير على اتخاذ قرارات أدق'),
        ],
      ),
    );
  }

  Widget _whyRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A237E), size: 20.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityAssuranceSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1A237E).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظام موثوق وآمن',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A237E),
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 12.h),
          _whyRow(Icons.shield_outlined, 'حماية عالية للبيانات'),
          SizedBox(height: 10.h),
          _whyRow(Icons.cloud_done_outlined, 'نسخ احتياطي مستمر'),
          SizedBox(height: 10.h),
          _whyRow(Icons.support_agent_outlined, 'دعم فني مباشر'),
        ],
      ),
    );
  }

  Widget _buildFinalPitch() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '🚀 ابدأ الآن وشاهد الفرق خلال أول أسبوع.\nلن تحتاج تدريب معقد — النظام مصمم ليعمل فورًا.',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: Colors.grey[800],
          height: 1.5,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}
