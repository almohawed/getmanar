import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SecurityReviewDialog extends StatelessWidget {
  final Map<String, dynamic> stats;

  const SecurityReviewDialog({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 800.w,
        height: 700.h,
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مراجعة الأمان الشاملة',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildSecurityScoreCard(),
            SizedBox(height: 24.h),
            Text('التوصيات الأمنية', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView(
                children: [
                  _buildRecommendationCard(
                    'تفعيل المصادقة الثنائية (2FA)',
                    'يوصى بتفعيل المصادقة الثنائية لجميع المستخدمين ذوي الصلاحيات الحساسة.',
                    'عالي',
                    Icons.security,
                  ),
                  _buildRecommendationCard(
                    'مراجعة الصلاحيات القديمة',
                    'يوصى بمراجعة الحسابات غير النشطة وتحديث صلاحياتها.',
                    'متوسط',
                    Icons.history,
                  ),
                  _buildRecommendationCard(
                    'تحديث كلمات المرور',
                    'يوصى بإلزام تحديث كلمات المرور وفق سياسة المدرسة.',
                    'منخفض',
                    Icons.password,
                  ),
                  _buildRecommendationCard(
                    'مراقبة الوصول المتعدد',
                    'تم رصد دخول متكرر من أجهزة مختلفة لبعض الحسابات الإدارية.',
                    'عالي',
                    Icons.devices,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityScoreCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade800, Colors.green.shade600]),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مستوى الأمان العام',
                style: TextStyle(fontSize: 18.sp, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                _securityScoreText(),
                style: TextStyle(fontSize: 32.sp, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                _lastCheckText(),
                style: TextStyle(fontSize: 12.sp, color: Colors.white70),
              ),
            ],
          ),
          Icon(Icons.shield, size: 80.sp, color: Colors.white.withOpacity(0.3)),
        ],
      ),
    );
  }

  String _securityScoreText() {
    final v = stats['securityScore'];
    if (v == null) return 'غير متاح';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return 'غير متاح';
    return '${n.toStringAsFixed(0)}%';
  }

  String _lastCheckText() {
    final v = stats['lastCheck'];
    if (v == null) return 'آخر فحص: غير متاح';
    return 'آخر فحص: ${v.toString()}';
  }

  Widget _buildRecommendationCard(String title, String description, String priority, IconData icon) {
    Color priorityColor;
    switch (priority) {
      case 'عالي': priorityColor = Colors.red; break;
      case 'متوسط': priorityColor = Colors.orange; break;
      default: priorityColor = Colors.green;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.1),
          child: Icon(icon, color: priorityColor),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Chip(
          label: Text(priority, style: TextStyle(color: Colors.white, fontSize: 10.sp)),
          backgroundColor: priorityColor,
        ),
      ),
    );
  }
}
