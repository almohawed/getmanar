import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart'; // إضافة import للـ auth

/// شاشة إضافة متابعة - تصميم ذكي واحترافي
class AddFollowupScreen extends ConsumerStatefulWidget {
  const AddFollowupScreen({super.key});

  @override
  ConsumerState<AddFollowupScreen> createState() => _AddFollowupScreenState();
}

class _AddFollowupScreenState extends ConsumerState<AddFollowupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedType = 'أكاديمي';
  String _selectedPriority = 'متوسطة';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
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
                    _buildSmartSuggestions(),
                    SizedBox(height: 24.h),
                    _buildBasicInfoSection(),
                    SizedBox(height: 24.h),
                    _buildTypeAndPrioritySection(),
                    SizedBox(height: 24.h),
                    _buildDateSection(),
                    SizedBox(height: 24.h),
                    _buildNotesSection(),
                    SizedBox(height: 24.h),
                    _buildAIRecommendations(),
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
      expandedHeight: 180.h,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'إضافة متابعة جديدة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade700,
                Colors.teal.shade500,
                Colors.cyan.shade400,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartSuggestions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'اقتراحات ذكية',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildSuggestionChip('متابعة أكاديمية', Icons.school),
              _buildSuggestionChip('متابعة سلوكية', Icons.psychology),
              _buildSuggestionChip('متابعة صحية', Icons.health_and_safety),
              _buildSuggestionChip('متابعة اجتماعية', Icons.people),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, IconData icon) {
    return InkWell(
      onTap: () {
        _titleController.text = label;
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: Colors.blue.shade600),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
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
            'المعلومات الأساسية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'عنوان المتابعة',
              prefixIcon: Icon(Icons.title, color: Colors.teal.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال عنوان المتابعة';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'الوصف التفصيلي',
              prefixIcon: Icon(Icons.description, color: Colors.teal.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال الوصف';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeAndPrioritySection() {
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
            'النوع والأولوية',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نوع المتابعة',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...[
                      'أكاديمي',
                      'سلوكي',
                      'صحي',
                      'اجتماعي',
                    ].map((type) => _buildRadioOption(
                          type,
                          _selectedType,
                          (value) => setState(() => _selectedType = value!),
                          _getTypeColor(type),
                        )),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأولوية',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...[
                      'عالية',
                      'متوسطة',
                      'منخفضة',
                    ].map((priority) => _buildRadioOption(
                          priority,
                          _selectedPriority,
                          (value) => setState(() => _selectedPriority = value!),
                          _getPriorityColor(priority),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String value, String groupValue, Function(String?) onChanged, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: value == groupValue ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: value == groupValue ? color : Colors.grey.shade300,
          width: value == groupValue ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        title: Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: value == groupValue ? FontWeight.bold : FontWeight.normal,
            color: value == groupValue ? color : Colors.grey.shade700,
          ),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: color,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'أكاديمي':
        return Colors.blue;
      case 'سلوكي':
        return Colors.orange;
      case 'صحي':
        return Colors.green;
      case 'اجتماعي':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عالية':
        return Colors.red;
      case 'متوسطة':
        return Colors.orange;
      case 'منخفضة':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDateSection() {
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
            'تاريخ المتابعة',
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
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade50, Colors.cyan.shade50],
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.teal.shade300, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.teal.shade600],
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
                        'التاريخ المحدد',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
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

  Widget _buildNotesSection() {
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
            'ملاحظات إضافية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'أضف أي ملاحظات أو تفاصيل إضافية...',
              prefixIcon: Icon(Icons.note_add, color: Colors.teal.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.pink.shade50],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.psychology, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'توصيات الذكاء الاصطناعي',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildAIRecommendationItem(
            'يُنصح بجدولة متابعة خلال 3 أيام',
            Icons.schedule,
            Colors.blue,
          ),
          SizedBox(height: 8.h),
          _buildAIRecommendationItem(
            'تفعيل التنبيهات التلقائية للمتابعة',
            Icons.notifications_active,
            Colors.orange,
          ),
          SizedBox(height: 8.h),
          _buildAIRecommendationItem(
            'مشاركة التقرير مع ولي الأمر',
            Icons.share,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationItem(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade700,
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
        onPressed: _isLoading ? null : _submitFollowup,
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
          _isLoading ? 'جاري الحفظ...' : 'حفظ المتابعة',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 5,
        ),
      ),
    );
  }

  Future<void> _submitFollowup() async {
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

      await FirebaseFirestore.instance.collection('followups').add({
        'schoolId': schoolId, // إضافة schoolId
        'counselorId': user.id, // معرف المرشد
        'title': _titleController.text,
        'description': _descriptionController.text,
        'type': _selectedType,
        'priority': _selectedPriority,
        'date': Timestamp.fromDate(_selectedDate),
        'notes': _notesController.text,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المتابعة بنجاح'),
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
