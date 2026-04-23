import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/school_reports_sheet.dart';
import '../../auth/domain/school_request.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/email_generator.dart';
import '../../subscription/domain/subscription_logic.dart';

class SchoolRequestsListScreen extends ConsumerWidget {
  const SchoolRequestsListScreen({super.key});

  String _normalizeToE164(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+966')) return cleaned;
    if (cleaned.startsWith('00966')) return '+966${cleaned.substring(5)}';
    if (cleaned.startsWith('966')) return '+$cleaned';
    if (cleaned.startsWith('05')) return '+966${cleaned.substring(1)}';
    if (cleaned.startsWith('5') && cleaned.length == 9) return '+966$cleaned';
    if (!cleaned.startsWith('+')) return '+$cleaned';
    return cleaned;
  }

  Future<void> _launchWhatsApp(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final e164 = _normalizeToE164(phone);
    final encoded = Uri.encodeComponent(message);
    final uriScheme = Uri.parse('whatsapp://send?phone=$e164&text=$encoded');
    final uriWeb = Uri.parse(
      'https://wa.me/${e164.replaceAll('+', '')}?text=$encoded',
    );

    try {
      if (await canLaunchUrl(uriScheme)) {
        await launchUrl(uriScheme, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ عند الفتح: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات تفعيل المدارس'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _showReportsBottomSheet(context),
            tooltip: 'التقارير',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('SchoolRequests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات حالياً'));
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final request = SchoolRequest.fromMap(data, docs[index].id);
              return _buildRequestCard(context, request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, SchoolRequest request) {
    final isPending = request.status == 'pending';
    final color = isPending
        ? Colors.orange
        : (request.status == 'approved' ? Colors.green : Colors.red);

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.schoolName,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isPending
                        ? 'بانتظار الموافقة'
                        : (request.status == 'approved'
                              ? 'تمت الموافقة'
                              : 'مرفوض'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildInfoRow(Icons.person, 'المدير: ${request.principalName}'),
            _buildInfoRow(Icons.phone, 'الجوال: ${request.mobile}'),
            _buildInfoRow(Icons.email, 'البريد: ${request.email}'),
            _buildInfoRow(Icons.location_city, 'المدينة: ${request.city}'),
            _buildInfoRow(
              Icons.school,
              'النوع: ${_getSchoolTypeArabic(request.schoolType)} - الطلاب: ${request.studentCount}',
            ),
            SizedBox(height: 8.h),
            Text(
              'تاريخ الطلب: ${DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt)}',
              style: TextStyle(color: Colors.grey, fontSize: 12.sp),
            ),

            if (isPending) ...[
              Divider(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _updateStatus(context, request, 'rejected'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'رفض',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton.icon(
                    onPressed: () => _approveRequest(context, request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('موافقة وتفعيل'),
                  ),
                ],
              ),
            ] else if (request.status == 'rejected' ||
                request.status == 'approved') ...[
              Divider(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _deleteRequest(context, request.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text('حذف الطلب'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey.shade600),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  String _getSchoolTypeArabic(String type) {
    final t = type.trim().toLowerCase();
    switch (t) {
      case 'government':
        return 'حكومي';
      case 'private':
        return 'أهلي';
      case 'international':
        return 'عالمي';
      default:
        return type;
    }
  }

  Future<void> _deleteRequest(BuildContext context, String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الطلب نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Use Cloud Function instead of direct Firestore write to avoid permission issues
      await FirebaseFunctions.instance
          .httpsCallable('deleteSchoolRequest')
          .call({'requestId': requestId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
      }
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    SchoolRequest request,
    String status,
  ) async {
    try {
      // Use Cloud Function instead of direct Firestore write
      await FirebaseFunctions.instance
          .httpsCallable('updateSchoolRequestStatus')
          .call({'requestId': request.id, 'status': status});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  Future<void> _approveRequest(
    BuildContext context,
    SchoolRequest request,
  ) async {
    // Step 1: Show subscription plan selection dialog
    final subscriptionConfig = await showDialog<_SubscriptionConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SubscriptionConfigDialog(schoolName: request.schoolName),
    );

    if (subscriptionConfig == null) return; // User cancelled

    try {
      final schoolId = request.id;
      String userId = request.ownerUserId;

      final loginEmail = EmailGenerator.generateEmail(
        UserRole.admin,
        identityNumber: request.identityNumber,
        phoneNumber: request.mobile,
      );

      final provisionResult = await FirebaseFunctions.instance
          .httpsCallable('createSchoolAdminProvision')
          .call({
            'uid': userId.isEmpty ? null : userId,
            'email': loginEmail,
            'contactEmail': request.email,
            'identityNumber': request.identityNumber,
            'mobile': request.mobile,
            'password': null,
            'name': request.principalName,
            'schoolId': schoolId,
            'role': 'manager',
            'schoolName': request.schoolName,
            'schoolType': request.schoolType,
            'schoolStage': request.schoolStage,
            'city': request.city,
            'requestId': request.id,
            // Subscription fields
            'subscriptionPlan': subscriptionConfig.plan,
            'showSubscriptionSection': subscriptionConfig.showSubscriptionSection,
            'isLifetimeAccess': subscriptionConfig.isLifetimeAccess,
            'subscriptionEndsAt': subscriptionConfig.subscriptionEndsAt?.toIso8601String(),
            'trialEndsAt': subscriptionConfig.trialEndsAt?.toIso8601String(),
          });

      if (provisionResult.data['success'] != true) {
        throw Exception('فشلت عملية تهيئة حساب المدير');
      }

      // Update school subscription fields in Firestore directly
      final schoolRef = FirebaseFirestore.instance.collection('Schools').doc(schoolId);
      final schoolDoc = await schoolRef.get();
      if (schoolDoc.exists) {
        await schoolRef.update({
          'subscriptionPlan': subscriptionConfig.plan,
          'showSubscriptionSection': subscriptionConfig.showSubscriptionSection,
          'isLifetimeAccess': subscriptionConfig.isLifetimeAccess,
          if (subscriptionConfig.subscriptionEndsAt != null)
            'subscriptionEndsAt': subscriptionConfig.subscriptionEndsAt!.toIso8601String(),
          if (subscriptionConfig.trialEndsAt != null)
            'trialEndsAt': subscriptionConfig.trialEndsAt!.toIso8601String(),
        });
      }

      if (context.mounted) {
        final mnCode = provisionResult.data['mnCode'] as String?;
        final generatedPassword = provisionResult.data['password'] as String? ?? 'Error';
        showDialog(
          context: context,
          builder: (context) => _ApprovalSuccessDialog(
            request: request,
            mnCode: mnCode,
            generatedPassword: generatedPassword,
            subscriptionConfig: subscriptionConfig,
            onWhatsApp: (text) => _launchWhatsApp(context, phone: request.mobile, message: text),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReportsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SchoolReportsSheet(),
    );
  }
}

// ─────────────────────────────────────────────
// Data class for subscription configuration
// ─────────────────────────────────────────────
class _SubscriptionConfig {
  final String plan;
  final bool showSubscriptionSection;
  final bool isLifetimeAccess;
  final DateTime? subscriptionEndsAt;
  final DateTime? trialEndsAt;

  _SubscriptionConfig({
    required this.plan,
    required this.showSubscriptionSection,
    required this.isLifetimeAccess,
    this.subscriptionEndsAt,
    this.trialEndsAt,
  });
}

// ─────────────────────────────────────────────
// Subscription Config Dialog
// ─────────────────────────────────────────────
class _SubscriptionConfigDialog extends StatefulWidget {
  final String schoolName;
  const _SubscriptionConfigDialog({required this.schoolName});

  @override
  State<_SubscriptionConfigDialog> createState() => _SubscriptionConfigDialogState();
}

class _SubscriptionConfigDialogState extends State<_SubscriptionConfigDialog> {
  String _selectedPlan = 'starter';
  String _durationType = 'trial'; // 'trial', 'monthly', 'yearly', 'lifetime'
  int _durationMonths = 1;
  bool _showSubscriptionSection = true;

  static const _planColors = {
    'starter': Color(0xFF26A69A),
    'smart': Color(0xFF1565C0),
    'elite': Color(0xFF6A1B9A),
  };

  static const _planIcons = {
    'starter': Icons.rocket_launch,
    'smart': Icons.auto_awesome,
    'elite': Icons.workspace_premium,
  };

  static const _planNames = {
    'starter': 'Starter - الأساس',
    'smart': 'Professional - الذكية',
    'elite': 'Elite - التميز',
  };

  static const _planDescriptions = {
    'starter': 'سجلات الطلاب، السلوك الأساسي، التقارير',
    'smart': 'كل Starter + الاستئذان، الاحتياط، التنبيهات',
    'elite': 'كل Professional + الجدول الذكي، QR، أولياء الأمور',
  };

  DateTime? _getSubscriptionEndsAt() {
    if (_durationType == 'lifetime') return null;
    if (_durationType == 'trial') return DateTime.now().add(const Duration(days: 30));
    final months = _durationMonths;
    final now = DateTime.now();
    return DateTime(now.year, now.month + months, now.day);
  }

  DateTime? _getTrialEndsAt() {
    if (_durationType == 'trial') return DateTime.now().add(const Duration(days: 30));
    return null;
  }

  String _getDurationLabel() {
    switch (_durationType) {
      case 'trial': return 'تجريبي 30 يوم';
      case 'monthly': return '$_durationMonths شهر';
      case 'yearly': return '${_durationMonths ~/ 12} سنة';
      case 'lifetime': return 'مدى الحياة ♾️';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 520.w, maxHeight: 680.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.verified_user, color: Colors.white, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تفعيل اشتراك المدرسة',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                        Text(widget.schoolName,
                            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Selection
                    Text('اختر الباقة', style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 10.h),
                    ...['starter', 'smart', 'elite'].map((plan) => _buildPlanTile(plan)),

                    SizedBox(height: 20.h),

                    // Duration Selection
                    Text('مدة الاشتراك', style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 10.h),
                    _buildDurationSelector(),

                    SizedBox(height: 20.h),

                    // Show Subscription Section Toggle
                    _buildToggleTile(
                      icon: Icons.visibility,
                      title: 'إظهار قسم الاشتراك لمدير المدرسة',
                      subtitle: 'يتيح للمدير رؤية خيارات الترقية والاشتراك',
                      value: _showSubscriptionSection,
                      onChanged: (v) => setState(() => _showSubscriptionSection = v),
                      activeColor: const Color(0xFF26A69A),
                    ),

                    SizedBox(height: 16.h),

                    // Summary Card
                    _buildSummaryCard(),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, _SubscriptionConfig(
                          plan: _selectedPlan,
                          showSubscriptionSection: _showSubscriptionSection,
                          isLifetimeAccess: _durationType == 'lifetime',
                          subscriptionEndsAt: _getSubscriptionEndsAt(),
                          trialEndsAt: _getTrialEndsAt(),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('تفعيل وقبول الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTile(String plan) {
    final isSelected = _selectedPlan == plan;
    final color = _planColors[plan]!;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_planIcons[plan], color: color, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_planNames[plan]!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                  Text(_planDescriptions[plan]!, style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      children: [
        Row(
          children: [
            _durationChip('trial', 'تجريبي', Icons.hourglass_top, const Color(0xFFFF8F00)),
            SizedBox(width: 8.w),
            _durationChip('monthly', 'شهري', Icons.calendar_month, const Color(0xFF1565C0)),
            SizedBox(width: 8.w),
            _durationChip('yearly', 'سنوي', Icons.calendar_today, const Color(0xFF2E7D32)),
            SizedBox(width: 8.w),
            _durationChip('lifetime', 'مدى الحياة', Icons.all_inclusive, const Color(0xFF6A1B9A)),
          ],
        ),
        if (_durationType == 'monthly' || _durationType == 'yearly') ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              Text('عدد الأشهر:', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(width: 12.w),
              _counterButton(Icons.remove, () {
                if (_durationMonths > 1) setState(() => _durationMonths--);
              }),
              SizedBox(width: 12.w),
              Text('$_durationMonths', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              SizedBox(width: 12.w),
              _counterButton(Icons.add, () {
                setState(() => _durationMonths++);
              }),
              SizedBox(width: 12.w),
              Text(
                _durationType == 'yearly' ? '(${_durationMonths ~/ 12} سنة)' : '',
                style: TextStyle(color: Colors.white54, fontSize: 11.sp),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _durationChip(String type, String label, IconData icon, Color color) {
    final isSelected = _durationType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _durationType = type;
          if (type == 'yearly') _durationMonths = 12;
          if (type == 'monthly') _durationMonths = 1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white38, size: 18.sp),
              SizedBox(height: 4.h),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 16.sp),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? activeColor : Colors.white38, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final planColor = _planColors[_selectedPlan]!;
    final endsAt = _getSubscriptionEndsAt();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [planColor.withValues(alpha: 0.2), planColor.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: planColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: planColor, size: 16.sp),
              SizedBox(width: 8.w),
              Text('ملخص الاشتراك', style: TextStyle(color: planColor, fontWeight: FontWeight.bold, fontSize: 13.sp)),
            ],
          ),
          SizedBox(height: 10.h),
          _summaryRow('الباقة', _planNames[_selectedPlan]!, planColor),
          _summaryRow('المدة', _getDurationLabel(), Colors.white70),
          if (endsAt != null)
            _summaryRow('تنتهي في', DateFormat('yyyy/MM/dd').format(endsAt), Colors.white70),
          if (_durationType == 'lifetime')
            _summaryRow('الصلاحية', 'مدى الحياة - بدون انتهاء', Colors.amber),
          _summaryRow('قسم الاشتراك', _showSubscriptionSection ? 'ظاهر للمدير' : 'مخفي', Colors.white70),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 11.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Approval Success Dialog
// ─────────────────────────────────────────────
class _ApprovalSuccessDialog extends StatelessWidget {
  final SchoolRequest request;
  final String? mnCode;
  final String generatedPassword;
  final _SubscriptionConfig subscriptionConfig;
  final Future<void> Function(String text) onWhatsApp;

  const _ApprovalSuccessDialog({
    required this.request,
    required this.mnCode,
    required this.generatedPassword,
    required this.subscriptionConfig,
    required this.onWhatsApp,
  });

  String _getPlanName(String plan) {
    switch (plan) {
      case 'starter': return 'Starter - الأساس';
      case 'smart': return 'Professional - الذكية';
      case 'elite': return 'Elite - التميز';
      default: return plan;
    }
  }

  String _getDurationText() {
    if (subscriptionConfig.isLifetimeAccess) return 'مدى الحياة';
    if (subscriptionConfig.trialEndsAt != null) return 'تجريبي 30 يوم';
    if (subscriptionConfig.subscriptionEndsAt != null) {
      return 'حتى ${DateFormat('yyyy/MM/dd').format(subscriptionConfig.subscriptionEndsAt!)}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 420.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: Colors.white, size: 36.sp),
                  ),
                  SizedBox(height: 8.h),
                  Text('تم تفعيل المدرسة بنجاح!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                  Text(request.schoolName,
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Credentials Card
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        _credRow(Icons.qr_code, 'كود المدرسة (MN-Code)', mnCode ?? 'غير متوفر', Colors.amber),
                        Divider(color: Colors.white12, height: 16.h),
                        _credRow(Icons.lock, 'كلمة المرور المؤقتة', generatedPassword, Colors.lightBlueAccent),
                      ],
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Subscription Summary
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.subscriptions, color: const Color(0xFF42A5F5), size: 16.sp),
                            SizedBox(width: 8.w),
                            Text('تفاصيل الاشتراك',
                                style: TextStyle(color: const Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        _subRow('الباقة', _getPlanName(subscriptionConfig.plan)),
                        _subRow('المدة', _getDurationText()),
                        _subRow('قسم الاشتراك', subscriptionConfig.showSubscriptionSection ? 'ظاهر' : 'مخفي'),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white24),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('إغلاق'),
                        ),
                      ),
                      if (mnCode != null) ...[
                        SizedBox(width: 10.w),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final text =
                                  'مرحباً بك أ. ${request.principalName}،\n'
                                  'تم تفعيل اشتراك مدرستكم (${request.schoolName}) بنجاح في منصة منار.\n\n'
                                  'بيانات الدخول:\n'
                                  '👤 كود المدرسة: $mnCode\n'
                                  '🔑 كلمة المرور: $generatedPassword\n\n'
                                  '📦 الباقة: ${_getPlanName(subscriptionConfig.plan)}\n'
                                  '📅 المدة: ${_getDurationText()}\n\n'
                                  'يمكنك الدخول الآن عبر التطبيق وتغيير كلمة المرور.\n'
                                  'نتمنى لكم تجربة مميزة! 🎉';
                              await onWhatsApp(text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text('إرسال واتساب', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, color: valueColor, size: 18.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
              Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 18.sp, letterSpacing: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
