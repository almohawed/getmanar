import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/student_case.dart';
import '../../auth/presentation/auth_controller.dart';

/// Provider للحالات المغلقة
final closedCasesProvider = StreamProvider.autoDispose<List<StudentCase>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  
  if (user == null || schoolId == null || schoolId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('student_cases')
      .where('schoolId', isEqualTo: schoolId)
      .where('status', isEqualTo: 'closed')
      .orderBy('closedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return StudentCase.fromMap(doc.data(), doc.id);
    }).toList();
  });
});

/// شاشة الحالات المغلقة - تصميم احترافي مع بيانات حقيقية
class ClosedCasesScreen extends ConsumerStatefulWidget {
  const ClosedCasesScreen({super.key});

  @override
  ConsumerState<ClosedCasesScreen> createState() => _ClosedCasesScreenState();
}

class _ClosedCasesScreenState extends ConsumerState<ClosedCasesScreen> {
  String _selectedPeriod = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(closedCasesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'الحالات المغلقة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
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
                  final matchesPeriod = _filterByPeriod(c);
                  final matchesSearch = _searchQuery.isEmpty ||
                      c.studentName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      c.title.toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesPeriod && matchesSearch;
                }).toList();

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

  bool _filterByPeriod(StudentCase studentCase) {
    if (_selectedPeriod == 'all') return true;
    
    final closedAt = studentCase.closedAt ?? studentCase.updatedAt ?? studentCase.createdAt;
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'today':
        return closedAt.year == now.year &&
            closedAt.month == now.month &&
            closedAt.day == now.day;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return closedAt.isAfter(weekAgo);
      case 'month':
        return closedAt.year == now.year && closedAt.month == now.month;
      default:
        return true;
    }
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
              prefixIcon: Icon(Icons.search, color: Colors.indigo.shade700),
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
          
          // فلاتر الفترة الزمنية
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all', Colors.grey),
                SizedBox(width: 8.w),
                _buildFilterChip('اليوم', 'today', Colors.blue),
                SizedBox(width: 8.w),
                _buildFilterChip('هذا الأسبوع', 'week', Colors.green),
                SizedBox(width: 8.w),
                _buildFilterChip('هذا الشهر', 'month', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, MaterialColor color) {
    final isSelected = _selectedPeriod == value;
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
        setState(() => _selectedPeriod = value);
      },
      backgroundColor: color.shade50,
      selectedColor: color.shade600,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color.shade200),
    );
  }

  Widget _buildCaseCard(StudentCase studentCase) {
    final closedAt = studentCase.closedAt ?? studentCase.updatedAt ?? studentCase.createdAt;
    final duration = closedAt.difference(studentCase.createdAt);
    final durationText = duration.inDays > 0
        ? '${duration.inDays} يوم'
        : '${duration.inHours} ساعة';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      child: InkWell(
        onTap: () {
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
                  // أيقونة الحالة المغلقة
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.check_circle,
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
                  
                  // شارة مغلق
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'مغلق',
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
              
              // معلومات الإغلاق
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16.sp, color: Colors.green.shade700),
                    SizedBox(width: 6.w),
                    Text(
                      'مدة المعالجة: $durationText',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.calendar_today, size: 14.sp, color: Colors.green.shade600),
                    SizedBox(width: 4.w),
                    Text(
                      DateFormat('yyyy/MM/dd').format(closedAt),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
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
            Icons.check_circle_outline,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد حالات مغلقة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'الحالات المغلقة ستظهر هنا',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
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
            onPressed: () => ref.refresh(closedCasesProvider),
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
