import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../admin/data/firestore_class_repository.dart';
import '../../academic/domain/classroom.dart';

/// شاشة ترحيل المعلمين - دمج المعلمين المكررين وعرض جميع المعلمين ونقل المعلمين بين الفصول
class TeacherMigrationScreen extends ConsumerStatefulWidget {
  const TeacherMigrationScreen({super.key});

  @override
  ConsumerState<TeacherMigrationScreen> createState() =>
      _TeacherMigrationScreenState();
}

class _TeacherMigrationScreenState extends ConsumerState<TeacherMigrationScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _allTeachers = [];
  List<_DuplicateGroup> _duplicates = [];
  List<Classroom> _allClasses = [];
  int _totalTeachers = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTeachers());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .get();

      final teachers = teachersSnap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      final classRepo = ref.read(classRepositoryProvider);
      final classes = await classRepo.getClasses(schoolId);

      _totalTeachers = teachers.length;

      // كشف المكررين: نفس الاسم المختصر أو نفس الاسم الكامل
      final Map<String, List<Map<String, dynamic>>> byShortName = {};
      for (final t in teachers) {
        final shortName = (t['shortName'] ?? '').toString().trim();
        final fullName = (t['name'] ?? '').toString().trim();
        final key = shortName.isNotEmpty ? shortName : fullName;
        if (key.isEmpty) continue;
        byShortName.putIfAbsent(key, () => []).add(t);
      }

      final duplicates = byShortName.entries
          .where((e) => e.value.length > 1)
          .map((e) => _DuplicateGroup(
                key: e.key,
                teachers: e.value,
              ))
          .toList();

      setState(() {
        _allTeachers = teachers;
        _duplicates = duplicates;
        _allClasses = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _mergeDuplicate(_DuplicateGroup group) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    // اختر المعلم الأصلي (الأول في القائمة)
    final original = group.teachers.first;
    final duplicatesToRemove = group.teachers.skip(1).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.merge_type, color: Colors.purple.shade700, size: 28.sp),
            SizedBox(width: 10.w),
            const Text('تأكيد الدمج'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم الاحتفاظ بـ:',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '✅ ${original['name'] ?? ''} (${original['shortName'] ?? ''})',
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, color: Colors.green.shade800),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'سيتم حذف:',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            ...duplicatesToRemove.map((t) => Container(
                  margin: EdgeInsets.only(bottom: 4.h),
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    '❌ ${t['name'] ?? ''} (${t['shortName'] ?? ''})',
                    style: GoogleFonts.cairo(
                        fontSize: 12.sp, color: Colors.red.shade800),
                  ),
                )),
            SizedBox(height: 8.h),
            Text(
              '⚠️ هذه العملية لا يمكن التراجع عنها',
              style: GoogleFonts.cairo(
                fontSize: 11.sp,
                color: Colors.orange.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('دمج', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final dup in duplicatesToRemove) {
        final ref = FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Teachers')
            .doc(dup['id'] as String);
        batch.delete(ref);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ تم دمج ${duplicatesToRemove.length} سجل مكرر بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadTeachers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _mergeAll() async {
    if (_duplicates.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.merge_type, color: Colors.red.shade700, size: 28.sp),
            SizedBox(width: 10.w),
            Text('دمج جميع المكررين', style: GoogleFonts.cairo()),
          ],
        ),
        content: Text(
          'سيتم دمج ${_duplicates.length} مجموعة مكررة تلقائياً.\n\n'
          'سيتم الاحتفاظ بأول سجل في كل مجموعة وحذف الباقي.\n\n'
          '⚠️ هذه العملية لا يمكن التراجع عنها!',
          style: GoogleFonts.cairo(fontSize: 13.sp, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('دمج الكل', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      int totalDeleted = 0;

      for (final group in _duplicates) {
        final duplicatesToRemove = group.teachers.skip(1).toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final dup in duplicatesToRemove) {
          final ref = FirebaseFirestore.instance
              .collection('Schools')
              .doc(schoolId)
              .collection('Teachers')
              .doc(dup['id'] as String);
          batch.delete(ref);
          totalDeleted++;
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حذف $totalDeleted سجل مكرر بنجاح',
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadTeachers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e', style: GoogleFonts.cairo()),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        title: Text(
          'ترحيل المعلمين',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 13.sp,
          ),
          unselectedLabelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            fontSize: 12.sp,
          ),
          tabs: const [
            Tab(text: 'المعلمين المكررين'),
            Tab(text: 'جميع المعلمين'),
            Tab(text: 'نقل المعلمين'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadTeachers,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isProcessing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: 16.h),
                      Text('جاري المعالجة...', style: GoogleFonts.cairo()),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDuplicatesTab(),
                    _buildAllTeachersTab(),
                    _buildTransferTab(),
                  ],
                ),
    );
  }

  Widget _buildDuplicatesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بطاقة الإحصائيات
          _buildStatsCard(),
          SizedBox(height: 16.h),

          // زر دمج الكل
          if (_duplicates.isNotEmpty) ...[
            _buildMergeAllButton(),
            SizedBox(height: 16.h),
          ],

          // قائمة المكررين
          if (_duplicates.isEmpty)
            _buildNoDuplicatesCard()
          else
            ..._duplicates.map((g) => _buildDuplicateCard(g)),
        ],
      ),
    );
  }

  Widget _buildAllTeachersTab() {
    if (_allTeachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 64.r,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16.h),
            Text(
              'لا يوجد معلمين مسجلين',
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200
            ? 4
            : MediaQuery.of(context).size.width > 900
                ? 3
                : MediaQuery.of(context).size.width > 600
                    ? 2
                    : 1,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 2.8,
      ),
      itemCount: _allTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _allTeachers[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.purple.shade700,
                    size: 28.r,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        teacher['name'] ?? 'غير معروف',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      if ((teacher['shortName'] ?? '').isNotEmpty)
                        Text(
                          'الاسم المختصر: ${teacher['shortName']}',
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'موجود',
                    style: GoogleFonts.cairo(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransferTab() {
    Map<String, dynamic>? selectedTeacher;
    Classroom? sourceClass;
    Classroom? targetClass;

    return StatefulBuilder(
      builder: (context, setTabState) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade900],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نقل المعلمين',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'نقل المعلمين بين الفصول والمراحل الدراسية',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // اختيار المعلم
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختيار المعلم',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedTeacher,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                      items: _allTeachers.map((teacher) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: teacher,
                          child: Text(
                            teacher['name'] ?? 'غير معروف',
                            style: GoogleFonts.cairo(),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setTabState(() {
                          selectedTeacher = value;
                        });
                      },
                      hint: Text(
                        'اختر المعلم الذي تريد نقله',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // اختيار الفصول
              if (selectedTeacher != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الفصل الحالي',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            DropdownButtonFormField<Classroom>(
                              value: sourceClass,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 12.h,
                                ),
                              ),
                              items: _allClasses.map((cls) {
                                return DropdownMenuItem<Classroom>(
                                  value: cls,
                                  child: Text(
                                    cls.preferredLabel,
                                    style: GoogleFonts.cairo(),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setTabState(() {
                                  sourceClass = value;
                                });
                              },
                              hint: Text(
                                'اختر الفصل الحالي',
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الفصل الجديد',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            DropdownButtonFormField<Classroom>(
                              value: targetClass,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 12.h,
                                ),
                              ),
                              items: _allClasses
                                  .where((c) => c.id != sourceClass?.id)
                                  .map((cls) {
                                return DropdownMenuItem<Classroom>(
                                  value: cls,
                                  child: Text(
                                    cls.preferredLabel,
                                    style: GoogleFonts.cairo(),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setTabState(() {
                                  targetClass = value;
                                });
                              },
                              hint: Text(
                                'اختر الفصل الجديد',
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // زر النقل
                if (sourceClass != null && targetClass != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final user = ref.read(authStateProvider).value;
                        final schoolId = user?.schoolId ?? '';
                        if (schoolId.isEmpty) return;
                        if (selectedTeacher == null) return;

                        setState(() => _isProcessing = true);

                        try {
                          final teacherId = selectedTeacher!['id'] as String;

                          // الحصول على المستند الخاص بالمعلم من مجموعة Teachers
                          final teacherDoc = await FirebaseFirestore.instance
                              .collection('Schools')
                              .doc(schoolId)
                              .collection('Teachers')
                              .doc(teacherId)
                              .get();

                          final data = teacherDoc.data();
                          if (data != null) {
                            // نقوم بتحديث assignedClassIds للمعلم
                            List<String> assignedClassIds = List<String>.from(
                                data['assignedClassIds'] ?? []);

                            // إزالة الفصل الحالي (اختياري)
                            if (assignedClassIds.contains(sourceClass!.id)) {
                              assignedClassIds.remove(sourceClass!.id);
                            }
                            // إضافة الفصل الجديد
                            if (!assignedClassIds.contains(targetClass!.id)) {
                              assignedClassIds.add(targetClass!.id);
                            }

                            await FirebaseFirestore.instance
                                .collection('Schools')
                                .doc(schoolId)
                                .collection('Teachers')
                                .doc(teacherId)
                                .update({
                              'assignedClassIds': assignedClassIds,
                            });
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white, size: 20.r),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        '✅ تم نقل المعلم بنجاح',
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                margin: EdgeInsets.symmetric(
                                    horizontal: 24.w, vertical: 24.h),
                              ),
                            );
                          }
                          await _loadTeachers();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.white, size: 20.r),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'خطأ: $e',
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 5),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                margin: EdgeInsets.symmetric(
                                    horizontal: 24.w, vertical: 24.h),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        'تنفيذ عملية النقل',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade900],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'إحصائيات المعلمين',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'إجمالي المعلمين',
                  '$_totalTeachers',
                  Icons.people,
                  Colors.white,
                ),
              ),
              Container(width: 1, height: 50.h, color: Colors.white30),
              Expanded(
                child: _buildStatItem(
                  'مجموعات مكررة',
                  '${_duplicates.length}',
                  Icons.copy,
                  _duplicates.isEmpty ? Colors.greenAccent : Colors.amber,
                ),
              ),
              Container(width: 1, height: 50.h, color: Colors.white30),
              Expanded(
                child: _buildStatItem(
                  'سجلات زائدة',
                  '${_duplicates.fold(0, (sum, g) => sum + g.teachers.length - 1)}',
                  Icons.delete_sweep,
                  _duplicates.isEmpty ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.white70,
            fontSize: 10.sp,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMergeAllButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade800],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _mergeAll,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.merge_type, color: Colors.white),
                SizedBox(width: 8.w),
                Text(
                  'دمج جميع المكررين (${_duplicates.length} مجموعة)',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDuplicatesCard() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 64.sp),
          SizedBox(height: 16.h),
          Text(
            '✅ لا توجد مكررات',
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'جميع المعلمين بأسماء فريدة',
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () {
              _tabController.animateTo(1);
            },
            icon: const Icon(Icons.calendar_view_week),
            label: Text('عرض جميع المعلمين', style: GoogleFonts.cairo()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateCard(_DuplicateGroup group) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.copy, color: Colors.red.shade700, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'مكرر: "${group.key}"',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${group.teachers.length} سجلات',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قائمة المعلمين
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: group.teachers.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final isOriginal = i == 0;
                return Container(
                  margin: EdgeInsets.only(bottom: 6.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color:
                        isOriginal ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isOriginal
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOriginal ? Icons.check_circle : Icons.cancel,
                        color: isOriginal
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? 'غير معروف',
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: isOriginal
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            if ((t['shortName'] ?? '').isNotEmpty)
                              Text(
                                'الاسم المختصر: ${t['shortName']}',
                                style: GoogleFonts.cairo(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: isOriginal
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          isOriginal ? 'يُحتفظ به' : 'يُحذف',
                          style: GoogleFonts.cairo(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: isOriginal
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // زر الدمج
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mergeDuplicate(group),
                icon: const Icon(Icons.merge_type),
                label: Text(
                  'دمج هذه المجموعة (حذف ${group.teachers.length - 1} مكرر)',
                  style: GoogleFonts.cairo(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroup {
  final String key;
  final List<Map<String, dynamic>> teachers;
  const _DuplicateGroup({required this.key, required this.teachers});
}
