import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import 'students_provider.dart';
import '../../admin/data/mock_class_repository.dart';

class CreateRemedialPlanScreen extends ConsumerStatefulWidget {
  const CreateRemedialPlanScreen({super.key});

  @override
  ConsumerState<CreateRemedialPlanScreen> createState() => _CreateRemedialPlanScreenState();
}

class _CreateRemedialPlanScreenState extends ConsumerState<CreateRemedialPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedClass;
  String _planType = 'تحسين تحصيل';
  final TextEditingController _goalsController = TextEditingController();
  final TextEditingController _proceduresController = TextEditingController();

  final List<String> _types = ['تحسين تحصيل', 'تعديل سلوك', 'تعزيز انضباط', 'رفع المستوى الأكاديمي'];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);
    
    final studentsCount = studentsAsync.value?.length ?? 0;
    final classesCount = classesAsync.value?.length ?? 0;
    
    // حساب عدد الخطط النشطة (من Firestore)
    final activePlansStream = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('RemedialPlans')
        .where('status', isEqualTo: 'active')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('إنشاء خطة علاجية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal.shade700,
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
                  colors: [Colors.teal.shade600, Colors.teal.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
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
                        child: Icon(Icons.analytics, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'إحصائيات الخطط العلاجية',
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
                        child: _buildStatItem('الطلاب', '$studentsCount', Icons.school, Colors.white),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem('الفصول', '$classesCount', Icons.class_, Colors.white),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: activePlansStream,
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _buildStatItem('خطط نشطة', '$count', Icons.medical_services, Colors.amber);
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'توصيات ذكية',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildRecommendation('ركز على الطلاب منخفضي التحصيل في المواد الأساسية'),
                  _buildRecommendation('حدد أهداف قابلة للقياس والتحقق'),
                  _buildRecommendation('اربط الخطة بمعلم متخصص لمتابعة التنفيذ'),
                  _buildRecommendation('راجع التقدم كل أسبوعين لضمان الفعالية'),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📝 نموذج الإدخال
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الخطة العلاجية',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    
                    // الفصل المستهدف
                    classesAsync.when(
                      data: (classes) {
                        final classNames = classes.map((c) => c.name).toList();
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'الفصل / المجموعة المستهدفة',
                            prefixIcon: Icon(Icons.class_, color: Colors.teal.shade700),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: classNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setState(() => _selectedClass = val),
                          validator: (val) => val == null ? 'يرجى اختيار الفصل' : null,
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('خطأ في تحميل الفصول'),
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // نوع الخطة
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'نوع الخطة',
                        prefixIcon: Icon(Icons.category, color: Colors.teal.shade700),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      value: _planType,
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _planType = val!),
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // أهداف الخطة
                    TextFormField(
                      controller: _goalsController,
                      decoration: InputDecoration(
                        labelText: 'أهداف الخطة',
                        hintText: 'مثال: رفع مستوى الطلاب في مادة الرياضيات بنسبة 20%',
                        prefixIcon: Icon(Icons.flag, color: Colors.teal.shade700),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                      validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الأهداف' : null,
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // الإجراءات والأنشطة
                    TextFormField(
                      controller: _proceduresController,
                      decoration: InputDecoration(
                        labelText: 'الإجراءات والأنشطة',
                        hintText: 'مثال: حصص تقوية، واجبات إضافية، متابعة يومية',
                        prefixIcon: Icon(Icons.list_alt, color: Colors.teal.shade700),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 5,
                      validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الإجراءات' : null,
                    ),
                    
                    SizedBox(height: 32.h),
                    
                    // زر الاعتماد
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            // حفظ الخطة في Firestore
                            await FirebaseFirestore.instance
                                .collection('Schools')
                                .doc(schoolId)
                                .collection('RemedialPlans')
                                .add({
                              'className': _selectedClass,
                              'planType': _planType,
                              'goals': _goalsController.text,
                              'procedures': _proceduresController.text,
                              'status': 'active',
                              'createdAt': FieldValue.serverTimestamp(),
                              'createdBy': user?.id,
                              'studentIds': [],
                            });
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text('✅ تم اعتماد الخطة العلاجية بنجاح\nيمكنك متابعتها من قسم "متابعة التنفيذ"'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'متابعة',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      context.go('/plan-followup');
                                    },
                                  ),
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
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
                          Icon(Icons.check_circle, color: Colors.white, size: 24.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'اعتماد الخطة',
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
          Icon(Icons.check_circle, color: Colors.amber.shade700, size: 18.sp),
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
