import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/models/student_case.dart';
import 'counselor_providers.dart';

/// شاشة الحالات النشطة - تصميم احترافي مع بيانات حقيقية
class ActiveCasesScreen extends ConsumerStatefulWidget {
  const ActiveCasesScreen({super.key});

  @override
  ConsumerState<ActiveCasesScreen> createState() => _ActiveCasesScreenState();
}

class _ActiveCasesScreenState extends ConsumerState<ActiveCasesScreen> {
  CasePriority? _selectedPriority;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(activeCasesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'الحالات النشطة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-student-case'),
            tooltip: 'إضافة حالة جديدة',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: casesAsync.when(
              data: (cases) {
                if (cases.isEmpty) {
                  return _buildEmptyState();
                }

                // تطبيق الفلاتر
                var filteredCases = cases.where((c) {
                  final matchesPriority = _selectedPriority == null ||
                      c.priority == _selectedPriority;
                  final matchesSearch = _searchQuery.isEmpty ||
                      c.studentName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      c.title.toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesPriority && matchesSearch;
                }).toList();

                // ترتيب حسب الأولوية والتاريخ
                filteredCases.sort((a, b) {
                  if (a.priority != b.priority) {
                    return b.priority.index.compareTo(a.priority.index);
                  }
                  return b.createdAt.compareTo(a.createdAt);
                });

                if (filteredCases.isEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filteredCases.length,
                  itemBuilder: (context, index) {
                    return _buildCaseCard(filteredCases[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'البحث عن طالب أو حالة...',
              prefixIcon: Icon(Icons.search, color: Colors.purple.shade700),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
          ),
          SizedBox(height: 12.h),
          
          // فلاتر الأولوية
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', null, Colors.grey),
                SizedBox(width: 8.w),
                _buildFilterChip('عاجل', CasePriority.urgent, Colors.red),
                SizedBox(width: 8.w),
                _buildFilterChip('عالي', CasePriority.high, Colors.orange),
                SizedBox(width: 8.w),
                _buildFilterChip('متوسط', CasePriority.medium, Colors.blue),
                SizedBox(width: 8.w),
                _buildFilterChip('منخفض', CasePriority.low, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CasePriority? value, MaterialColor color) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPriority = value);
      },
      backgroundColor: color.shade50,
      selectedColor: color.shade600,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color.shade200),
    );
  }

  Widget _buildCaseCard(StudentCase studentCase) {
    final priorityColors = {
      CasePriority.urgent: Colors.red,
      CasePriority.high: Colors.orange,
      CasePriority.medium: Colors.blue,
      CasePriority.low: Colors.green,
    };
    final priorityLabels = {
      CasePriority.urgent: 'عاجل',
      CasePriority.high: 'عالي',
      CasePriority.medium: 'متوسط',
      CasePriority.low: 'منخفض',
    };
    
    final color = priorityColors[studentCase.priority] ?? Colors.grey;
    final priorityLabel = priorityLabels[studentCase.priority] ?? 'غير محدد';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: color.shade200, width: 2),
      ),
      child: InkWell(
        onTap: () {
          // فتح تفاصيل الحالة
          context.push('/student-case/${studentCase.id}');
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // أيقونة الحالة
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade400, color.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.folder_open,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  
                  // معلومات الطالب
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentCase.studentName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          studentCase.title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // شارة الأولوية
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade400, color.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      priorityLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12.h),
              
              // الوصف
              Text(
                studentCase.description,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 12.h),
              
              // معلومات إضافية
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey.shade500),
                  SizedBox(width: 4.w),
                  Text(
                    DateFormat('yyyy/MM/dd').format(studentCase.createdAt),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  if (studentCase.evidenceCount > 0) ...[
                    Icon(Icons.attach_file, size: 14.sp, color: Colors.grey.shade500),
                    SizedBox(width: 4.w),
                    Text(
                      '${studentCase.evidenceCount} مرفق',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14.sp, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد حالات نشطة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابدأ بإضافة حالة جديدة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/add-student-case'),
            icon: const Icon(Icons.add),
            label: const Text('إضافة حالة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'جرب تغيير الفلاتر أو البحث',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.sp,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(activeCasesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
