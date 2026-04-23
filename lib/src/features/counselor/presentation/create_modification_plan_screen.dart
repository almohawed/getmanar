import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart'; // إضافة import للـ auth

/// شاشة إنشاء خطة تعديل - تصميم شامل وذكي
class CreateModificationPlanScreen extends ConsumerStatefulWidget {
  const CreateModificationPlanScreen({super.key});

  @override
  ConsumerState<CreateModificationPlanScreen> createState() => _CreateModificationPlanScreenState();
}

class _CreateModificationPlanScreenState extends ConsumerState<CreateModificationPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _interventionsController = TextEditingController();
  
  String _selectedStudent = '';
  int _totalSessions = 10;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _objectivesController.dispose();
    _interventionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanInfoSection(),
                    SizedBox(height: 24.h),
                    _buildObjectivesSection(),
                    SizedBox(height: 24.h),
                    _buildInterventionsSection(),
                    SizedBox(height: 24.h),
                    _buildSessionsSection(),
                    SizedBox(height: 24.h),
                    _buildTargetDateSection(),
                    SizedBox(height: 32.h),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.h,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'إنشاء خطة تعديل',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade700,
                Colors.indigo.shade500,
                Colors.blue.shade400,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanInfoSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
            'معلومات الخطة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'عنوان الخطة',
              prefixIcon: Icon(Icons.title, color: Colors.indigo.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال عنوان الخطة';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'وصف الخطة',
              prefixIcon: Icon(Icons.description, color: Colors.indigo.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال وصف الخطة';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObjectivesSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.flag, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'أهداف الخطة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _objectivesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'أدخل الأهداف (كل هدف في سطر منفصل)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.green.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال الأهداف';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionsSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.build, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'التدخلات والإجراءات',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _interventionsController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'أدخل التدخلات (كل تدخل في سطر منفصل)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال التدخلات';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
            'عدد الجلسات المطلوبة',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _totalSessions.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 25,
                  label: '$_totalSessions جلسة',
                  activeColor: Colors.indigo.shade600,
                  onChanged: (value) {
                    setState(() => _totalSessions = value.toInt());
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$_totalSessions',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetDateSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
            'التاريخ المستهدف',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _targetDate = date);
              }
            },
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade50, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.indigo.shade300, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.calendar_today, color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تاريخ الإنجاز المتوقع',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitPlan,
        icon: _isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.check_circle, size: 24.sp),
        label: Text(
          _isLoading ? 'جاري الحفظ...' : 'إنشاء الخطة',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 5,
        ),
      ),
    );
  }

  Future<void> _submitPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // الحصول على معلومات المستخدم الحالي
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final schoolId = user.schoolId ?? '';
      if (schoolId.isEmpty) {
        throw Exception('لم يتم العثور على معرف المدرسة');
      }

      final objectives = _objectivesController.text.split('\n').where((s) => s.isNotEmpty).toList();
      final interventions = _interventionsController.text.split('\n').where((s) => s.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('education_plans').add({
        'schoolId': schoolId, // إضافة schoolId
        'studentId': 'student-${DateTime.now().millisecondsSinceEpoch}', // معرف مؤقت للطالب
        'studentName': 'طالب', // اسم مؤقت - يمكن تحسينه لاحقاً
        'counselorId': user.id, // معرف المرشد
        'planTitle': _titleController.text,
        'description': _descriptionController.text,
        'objectives': objectives,
        'interventions': interventions,
        'totalSessions': _totalSessions,
        'sessionsCompleted': 0,
        'targetDate': Timestamp.fromDate(_targetDate),
        'createdAt': Timestamp.now(),
        'status': 'active',
        'progressPercentage': 0.0,
        'improvementRate': 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الخطة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
