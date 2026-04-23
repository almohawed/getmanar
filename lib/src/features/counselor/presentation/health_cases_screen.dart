import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../health/data/firestore_health_repository.dart';

class HealthCasesScreen extends ConsumerStatefulWidget {
  const HealthCasesScreen({super.key});

  @override
  ConsumerState<HealthCasesScreen> createState() => _HealthCasesScreenState();
}

class _HealthCasesScreenState extends ConsumerState<HealthCasesScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _filter = 'all';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final healthCasesAsync = ref.watch(healthCasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحالات الصحية'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'حالات الطلاب', icon: Icon(Icons.people, size: 18)),
            Tab(text: 'السجلات التفصيلية', icon: Icon(Icons.folder_open, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب 1: حالات الطلاب (care/bathroom)
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'بحث عن طالب',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    SizedBox(height: 16.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('الكل', 'all'),
                          SizedBox(width: 8.w),
                          _buildFilterChip('تحتاج رعاية', 'care', Colors.amber),
                          SizedBox(width: 8.w),
                          _buildFilterChip('تحتاج دورة مياة', 'bathroom', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: studentsAsync.when(
                  data: (students) {
                    final filtered = students.where((student) {
                      final matchesSearch =
                          student.name.contains(_searchQuery) ||
                          (student.identityNumber?.contains(_searchQuery) ?? false);
                      if (!matchesSearch) return false;
                      if (_filter == 'all') return true;
                      if (_filter == 'care') return student.healthStatus == 'care';
                      if (_filter == 'bathroom') return student.healthStatus == 'bathroom';
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('لا يوجد طلاب'));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildStudentItem(filtered[index]),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                ),
              ),
            ],
          ),

          // تبويب 2: السجلات التفصيلية من AddHealthCaseScreen
          healthCasesAsync.when(
            data: (cases) {
              if (cases.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد سجلات صحية تفصيلية'),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: cases.length,
                itemBuilder: (context, index) {
                  final c = cases[index];
                  Color typeColor = c.conditionType == 'طارئة'
                      ? Colors.red
                      : c.conditionType == 'مزمنة'
                          ? Colors.orange
                          : Colors.blue;
                  return Card(
                    margin: EdgeInsets.only(bottom: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: BorderSide(color: typeColor.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(12.w),
                      leading: CircleAvatar(
                        backgroundColor: typeColor.withOpacity(0.1),
                        child: Icon(Icons.medical_services, color: typeColor),
                      ),
                      title: Text(
                        c.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الحالة: ${c.conditionName}'),
                          Text('النوع: ${c.conditionType}',
                              style: TextStyle(color: typeColor, fontSize: 12.sp)),
                          if (c.medication.isNotEmpty)
                            Text('الأدوية: ${c.medication}',
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                        ],
                      ),
                      trailing: Text(
                        '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, [Color? color]) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.blue).withOpacity(0.2)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? (color ?? Colors.blue) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check, size: 14, color: color ?? Colors.blue),
            if (isSelected) SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? (color ?? Colors.blue) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentItem(User student) {
    final isCare = student.healthStatus == 'care';
    final isBathroom = student.healthStatus == 'bathroom';

    Color bgColor = Colors.white;
    Color nameColor = Colors.black;
    Color nameBgColor = Colors.transparent;

    if (isBathroom) {
      bgColor = Colors.red.shade50;
      nameColor = Colors.white;
      nameBgColor = Colors.red.shade600;
    } else if (isCare) {
      bgColor = Colors.amber.shade50;
      nameColor = Colors.black87;
      nameBgColor = Colors.amber.shade400;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      color: bgColor,
      elevation: isBathroom || isCare ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(
          color: isBathroom
              ? Colors.red.shade300
              : isCare
                  ? Colors.amber.shade400
                  : Colors.grey.shade200,
          width: isBathroom || isCare ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        leading: CircleAvatar(
          backgroundColor: isBathroom
              ? Colors.red.shade100
              : isCare
                  ? Colors.amber.shade100
                  : Colors.grey.shade200,
          child: Icon(
            Icons.person,
            color: isBathroom
                ? Colors.red.shade700
                : isCare
                    ? Colors.amber.shade700
                    : Colors.grey,
          ),
        ),
        title: Container(
          padding: EdgeInsets.symmetric(
            horizontal: nameBgColor != Colors.transparent ? 8.w : 0,
            vertical: nameBgColor != Colors.transparent ? 4.h : 0,
          ),
          decoration: BoxDecoration(
            color: nameBgColor,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            student.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: nameColor,
              fontSize: 14.sp,
            ),
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            student.identityNumber ?? '',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _updateStatus(student, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'healthy',
              child: Text('سليم (إزالة الحالة)'),
            ),
            const PopupMenuItem(
              value: 'care',
              child: Text('تحتاج رعاية (أصفر)'),
            ),
            const PopupMenuItem(
              value: 'bathroom',
              child: Text('تحتاج دورة مياة (أحمر)'),
            ),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusLabel(student.healthStatus),
                  style: TextStyle(fontSize: 12.sp),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'care':
        return 'تحتاج رعاية';
      case 'bathroom':
        return 'تحتاج دورة مياة';
      default:
        return 'سليم';
    }
  }

  Future<void> _updateStatus(User student, String status) async {
    User updatedStudent;
    if (status == 'healthy') {
      updatedStudent = User(
        id: student.id,
        name: student.name,
        email: student.email,
        role: student.role,
        profileImageUrl: student.profileImageUrl,
        stage: student.stage,
        assignedClassIds: student.assignedClassIds,
        scheduleNotes: student.scheduleNotes,
        identityNumber: student.identityNumber,
        phoneNumber: student.phoneNumber,
        dateOfBirth: student.dateOfBirth,
        specialization: student.specialization,
        maxWeeklyClasses: student.maxWeeklyClasses,
        schoolId: student.schoolId,
        deputyType: student.deputyType,
        isPasswordChangeRequired: student.isPasswordChangeRequired,
        healthStatus: null,
      );
    } else {
      updatedStudent = student.copyWith(healthStatus: status);
    }

    try {
      final user = ref.read(authStateProvider).value;
      if (user?.schoolId == null) return;

      // حفظ مباشر في Firestore بدون الاعتماد على repository
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(user!.schoolId!)
          .collection('Students')
          .doc(student.id)
          .update({'healthStatus': status == 'healthy' ? null : status});

      // إعادة تحميل قائمة الطلاب
      ref.invalidate(studentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الطالب'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحديث: $e')),
        );
      }
    }
  }
}
