import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/student_case.dart';
import '../../auth/presentation/auth_controller.dart';

/// شاشة البحث في الحالات - تصميم احترافي مع بحث متقدم
class SearchCasesScreen extends ConsumerStatefulWidget {
  const SearchCasesScreen({super.key});

  @override
  ConsumerState<SearchCasesScreen> createState() => _SearchCasesScreenState();
}

class _SearchCasesScreenState extends ConsumerState<SearchCasesScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  List<StudentCase> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كلمة بحث')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';

      if (schoolId.isEmpty) {
        throw Exception('لم يتم العثور على معرف المدرسة');
      }

      var query = FirebaseFirestore.instance
          .collection('student_cases')
          .where('schoolId', isEqualTo: schoolId);

      // تطبيق فلتر الحالة
      if (_selectedStatus != 'all') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      // تطبيق فلتر الأولوية
      if (_selectedPriority != 'all') {
        query = query.where('priority', isEqualTo: _selectedPriority);
      }

      final snapshot = await query.limit(100).get();

      final searchTerm = _searchController.text.toLowerCase();
      final results = snapshot.docs
          .map((doc) => StudentCase.fromMap(doc.data(), doc.id))
          .where((c) =>
              c.studentName.toLowerCase().contains(searchTerm) ||
              c.title.toLowerCase().contains(searchTerm) ||
              c.description.toLowerCase().contains(searchTerm))
          .toList();

      // ترتيب النتائج
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'البحث في الحالات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط البحث
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن طالب، عنوان، أو وصف...',
                    prefixIcon: Icon(Icons.search, color: Colors.teal.shade700),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed: _isSearching ? null : _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isSearching
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.white),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // الفلاتر المتقدمة
          Text(
            'فلاتر البحث',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12.h),
          
          // فلتر الحالة
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip('الكل', 'all', _selectedStatus, Colors.grey, (value) {
                setState(() => _selectedStatus = value);
              }),
              _buildFilterChip('نشط', 'active', _selectedStatus, Colors.blue, (value) {
                setState(() => _selectedStatus = value);
              }),
              _buildFilterChip('مغلق', 'closed', _selectedStatus, Colors.green, (value) {
                setState(() => _selectedStatus = value);
              }),
            ],
          ),
          
          SizedBox(height: 12.h),
          
          // فلتر الأولوية
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip('كل الأولويات', 'all', _selectedPriority, Colors.grey, (value) {
                setState(() => _selectedPriority = value);
              }),
              _buildFilterChip('عاجل', 'urgent', _selectedPriority, Colors.red, (value) {
                setState(() => _selectedPriority = value);
              }),
              _buildFilterChip('عالي', 'high', _selectedPriority, Colors.orange, (value) {
                setState(() => _selectedPriority = value);
              }),
              _buildFilterChip('متوسط', 'medium', _selectedPriority, Colors.blue, (value) {
                setState(() => _selectedPriority = value);
              }),
              _buildFilterChip('منخفض', 'low', _selectedPriority, Colors.green, (value) {
                setState(() => _selectedPriority = value);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    MaterialColor color,
    Function(String) onSelected,
  ) {
    final isSelected = selectedValue == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => onSelected(value),
      backgroundColor: color.shade50,
      selectedColor: color.shade600,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color.shade200),
    );
  }

  Widget _buildResultsSection() {
    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'النتائج (${_searchResults.length})',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              return _buildCaseCard(_searchResults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCaseCard(StudentCase studentCase) {
    final statusColors = {
      CaseStatus.open: Colors.blue,
      CaseStatus.in_progress: Colors.orange,
      CaseStatus.resolved: Colors.green,
      CaseStatus.closed: Colors.green,
    };
    final statusLabels = {
      CaseStatus.open: 'مفتوح',
      CaseStatus.in_progress: 'قيد المعالجة',
      CaseStatus.resolved: 'محلول',
      CaseStatus.closed: 'مغلق',
    };
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

    final statusColor = statusColors[studentCase.status] ?? Colors.grey;
    final statusLabel = statusLabels[studentCase.status] ?? 'غير محدد';
    final priorityColor = priorityColors[studentCase.priority] ?? Colors.grey;
    final priorityLabel = priorityLabels[studentCase.priority] ?? 'غير محدد';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: statusColor.shade200, width: 2),
      ),
      child: InkWell(
        onTap: () => context.push('/student-case/${studentCase.id}'),
        borderRadius: BorderRadius.circular(12.r),
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
                      gradient: LinearGradient(
                        colors: [statusColor.shade400, statusColor.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      studentCase.status == CaseStatus.closed
                          ? Icons.check_circle
                          : Icons.folder_open,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: statusColor.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: statusColor.shade300),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor.shade700,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: priorityColor.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: priorityColor.shade300),
                        ),
                        child: Text(
                          priorityLabel,
                          style: TextStyle(
                            color: priorityColor.shade700,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
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
                  if (studentCase.evidenceCount > 0) ...[
                    SizedBox(width: 16.w),
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
                  Icon(Icons.arrow_forward_ios, size: 14.sp, color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 100.sp,
            color: Colors.teal.shade200,
          ),
          SizedBox(height: 24.h),
          Text(
            'ابحث في جميع الحالات',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'استخدم شريط البحث أعلاه للبحث عن الطلاب والحالات',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
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
            'جرب كلمات بحث مختلفة أو غير الفلاتر',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
