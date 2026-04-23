import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import 'students_provider.dart';
import '../../admin/data/mock_teacher_repository.dart';

class LinkStudentTeacherScreen extends ConsumerStatefulWidget {
  const LinkStudentTeacherScreen({super.key});

  @override
  ConsumerState<LinkStudentTeacherScreen> createState() => _LinkStudentTeacherScreenState();
}

class _LinkStudentTeacherScreenState extends ConsumerState<LinkStudentTeacherScreen> {
  String? _selectedStudent;
  String? _selectedTeacher;
  String? _selectedPlan;
  final TextEditingController _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    
    final studentsAsync = ref.watch(studentsProvider);
    final teachersAsync = ref.watch(teachersProvider);
    
    // جلب الخطط النشطة
    final plansStream = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .where('status', isEqualTo: 'active')
        .snapshots();
    
    // حساب الإحصائيات
    final linkedStream = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('StudentTeacherLinks')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('ربط الطالب بالمعلم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo.shade700,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 بطاقة الإحصائيات
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
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
                        child: Icon(Icons.link, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'إحصائيات الربط',
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
                        child: _buildStatItem(
                          'الطلاب',
                          '${studentsAsync.value?.length ?? 0}',
                          Icons.school,
                          Colors.white,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem(
                          'المعلمين',
                          '${teachersAsync.value?.length ?? 0}',
                          Icons.person,
                          Colors.white,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: linkedStream,
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _buildStatItem('مرتبطين', '$count', Icons.link, Colors.green);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 💡 بطاقة التوصيات الذكية
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'نصائح الربط الفعال',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildRecommendation('اختر معلم متخصص في المادة التي يحتاج الطالب تحسينها'),
                  _buildRecommendation('تأكد من توفر وقت كافٍ لدى المعلم للمتابعة'),
                  _buildRecommendation('حدد أهداف واضحة وقابلة للقياس'),
                  _buildRecommendation('راجع التقدم بشكل دوري كل أسبوعين'),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📝 نموذج الربط
            Container(
              padding: EdgeInsets.all(24.w),
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
                  Text(
                    'بيانات الربط',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  
                  // اختيار الخطة
                  StreamBuilder<QuerySnapshot>(
                    stream: plansStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final plans = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'الخطة العلاجية',
                          prefixIcon: Icon(Icons.medical_services, color: Colors.indigo.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: plans.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('${data['planType']} - ${data['className']}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPlan = val),
                      );
                    },
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // اختيار الطالب
                  studentsAsync.when(
                    data: (students) {
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'الطالب',
                          prefixIcon: Icon(Icons.school, color: Colors.indigo.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: students.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedStudent = val),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ في تحميل الطلاب'),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // اختيار المعلم
                  teachersAsync.when(
                    data: (teachers) {
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'المعلم المسؤول',
                          prefixIcon: Icon(Icons.person, color: Colors.indigo.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: teachers.map((t) {
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedTeacher = val),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ في تحميل المعلمين'),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // ملاحظات
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات إضافية',
                      hintText: 'أي ملاحظات أو تعليمات خاصة',
                      prefixIcon: Icon(Icons.note, color: Colors.indigo.shade700),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 3,
                  ),
                  
                  SizedBox(height: 32.h),
                  
                  // زر الربط
                  ElevatedButton(
                    onPressed: () async {
                      if (_selectedStudent == null || _selectedTeacher == null || _selectedPlan == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ يرجى ملء جميع الحقول'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      try {
                        await FirebaseFirestore.instance
                            .collection('Schools')
                            .doc(schoolId)
                            .collection('StudentTeacherLinks')
                            .add({
                          'studentId': _selectedStudent,
                          'teacherId': _selectedTeacher,
                          'planId': _selectedPlan,
                          'notes': _notesController.text,
                          'status': 'active',
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': user?.id,
                        });
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ تم ربط الطالب بالمعلم بنجاح'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          context.pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ خطأ: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      padding: EdgeInsets.symmetric(vertical: 18.h),
                      minimumSize: Size(double.infinity, 56.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link, color: Colors.white, size: 24.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'ربط الطالب بالمعلم',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
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
          Icon(Icons.check_circle, color: Colors.blue.shade700, size: 18.sp),
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
