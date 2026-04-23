import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import 'package:intl/intl.dart';

class PlanFollowupScreen extends ConsumerStatefulWidget {
  const PlanFollowupScreen({super.key});

  @override
  ConsumerState<PlanFollowupScreen> createState() => _PlanFollowupScreenState();
}

class _PlanFollowupScreenState extends ConsumerState<PlanFollowupScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    
    // التحقق من وجود schoolId
    if (schoolId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('متابعة تنفيذ الخطط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.orange.shade700,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text('لا يوجد معرف مدرسة', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('يرجى تسجيل الدخول مرة أخرى', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // جلب الخطط النشطة مع ترتيب حسب تاريخ الإنشاء
    final plansStream = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
    
    // جلب الروابط النشطة
    final linksStream = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('StudentTeacherLinks')
        .where('status', isEqualTo: 'active')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('متابعة تنفيذ الخطط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 بطاقة الإحصائيات
            StreamBuilder<QuerySnapshot>(
              stream: plansStream,
              builder: (context, plansSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: linksStream,
                  builder: (context, linksSnapshot) {
                    final plansCount = plansSnapshot.data?.docs.length ?? 0;
                    final linksCount = linksSnapshot.data?.docs.length ?? 0;
                    final completionRate = plansCount > 0 ? ((linksCount / plansCount) * 100).toInt() : 0;
                    
                    return Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade600, Colors.orange.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(Icons.track_changes, color: Colors.white, size: 28.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'إحصائيات المتابعة',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem('خطط نشطة', '$plansCount', Icons.medical_services, Colors.white),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildStatItem('طلاب مرتبطين', '$linksCount', Icons.link, Colors.white),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildStatItem('نسبة التنفيذ', '$completionRate%', Icons.pie_chart, Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            
            SizedBox(height: 24.h),
            
            // 💡 بطاقة التوصيات الذكية
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'توصيات المتابعة',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildRecommendation('راجع تقدم كل خطة كل أسبوعين على الأقل'),
                  _buildRecommendation('تواصل مع المعلمين للحصول على تحديثات دورية'),
                  _buildRecommendation('سجل الملاحظات والتحديات التي تواجه التنفيذ'),
                  _buildRecommendation('احتفل بالإنجازات الصغيرة لتحفيز الطلاب'),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📋 قائمة الخطط النشطة
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.orange.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'الخطط النشطة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: plansStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.w),
                            child: Column(
                              children: [
                                Icon(Icons.inbox, size: 64.sp, color: Colors.grey.shade300),
                                SizedBox(height: 16.h),
                                Text(
                                  'لا توجد خطط نشطة حالياً',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'ابدأ بإنشاء خطة علاجية جديدة',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/create-remedial-plan'),
                                  icon: Icon(Icons.add, color: Colors.white),
                                  label: Text('إنشاء خطة علاجية', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          final daysSinceCreation = createdAt != null 
                              ? DateTime.now().difference(createdAt).inDays 
                              : 0;
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: InkWell(
                              onTap: () => _showPlanDetails(context, doc.id, data),
                              borderRadius: BorderRadius.circular(16.r),
                              child: Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(10.w),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Icon(
                                            Icons.medical_services,
                                            color: Colors.orange.shade700,
                                            size: 24.sp,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['planType'] ?? 'خطة علاجية',
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                'الفصل: ${data['className'] ?? 'غير محدد'}',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                          decoration: BoxDecoration(
                                            color: daysSinceCreation < 7 
                                                ? Colors.green.shade100 
                                                : daysSinceCreation < 14 
                                                    ? Colors.orange.shade100 
                                                    : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(20.r),
                                          ),
                                          child: Text(
                                            '$daysSinceCreation يوم',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.bold,
                                              color: daysSinceCreation < 7 
                                                  ? Colors.green.shade700 
                                                  : daysSinceCreation < 14 
                                                      ? Colors.orange.shade700 
                                                      : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'الأهداف: ${data['goals'] ?? 'غير محدد'}',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey.shade500),
                                        SizedBox(width: 4.w),
                                        Text(
                                          createdAt != null 
                                              ? DateFormat('yyyy-MM-dd').format(createdAt)
                                              : 'غير محدد',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPlanDetails(BuildContext context, String planId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'تفاصيل الخطة',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 20.h),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('نوع الخطة', data['planType'] ?? 'غير محدد'),
                    _buildDetailRow('الفصل', data['className'] ?? 'غير محدد'),
                    _buildDetailRow('الأهداف', data['goals'] ?? 'غير محدد'),
                    _buildDetailRow('الإجراءات', data['procedures'] ?? 'غير محدد'),
                    _buildDetailRow('الحالة', data['status'] ?? 'غير محدد'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                minimumSize: Size(double.infinity, 50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendation(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.orange.shade700, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
