import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';

class TeacherDetailScreen extends StatefulWidget {
  final User teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  Map<String, String> _classNames = {};
  bool _loadingClassNames = true;
  List<String>? _currentAssignedClassIds;

  String _normalizeTeacherEmailForDisplay(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    var local = email.substring(0, at);
    final domain = email.substring(at + 1);

    while (local.toLowerCase().startsWith('tctc')) {
      local = local.substring(2);
    }

    if (local.toLowerCase().startsWith('tc') && local.length >= 2) {
      local = 'TC${local.substring(2)}';
    }

    return '$local@$domain';
  }

  @override
  void initState() {
    super.initState();
    _currentAssignedClassIds = widget.teacher.assignedClassIds;
    _loadClassNames();
  }

  Future<void> _loadClassNames() async {
    if (_currentAssignedClassIds == null || _currentAssignedClassIds!.isEmpty) {
      setState(() => _loadingClassNames = false);
      return;
    }

    try {
      final schoolId = widget.teacher.schoolId;
      if (schoolId == null || schoolId.isEmpty) {
        setState(() => _loadingClassNames = false);
        return;
      }

      final classesSnapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .get();

      final names = <String, String>{};
      for (final doc in classesSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? data['className'] ?? doc.id;
        names[doc.id] = name;
      }

      setState(() {
        _classNames = names;
        _loadingClassNames = false;
      });
    } catch (e) {
      setState(() => _loadingClassNames = false);
    }
  }

  Future<_TeacherStats> _fetchStats() async {
    try {
      // Behavior stats
      final behaviorSnapshot = await FirebaseFirestore.instance
          .collection('behavior_records')
          .where('teacherId', isEqualTo: widget.teacher.id)
          .get();

      int positivePoints = 0;
      int violationsRaised = 0;
      for (final doc in behaviorSnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] ?? 'positive') as String;
        final status = (data['status'] ?? 'approved') as String;
        if (status != 'rejected') {
          if (type == 'positive') {
            final pts = (data['points'] ?? 0);
            positivePoints += pts is int ? pts : int.tryParse('$pts') ?? 0;
          } else if (type == 'negative') {
            violationsRaised++;
          }
        }
      }

      // Attendance stats
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('teacherId', isEqualTo: widget.teacher.id)
          .get();

      int presentCount = 0;
      int totalAttendance = attendanceSnapshot.docs.length;
      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final statusIndex = data['status'];
        if (statusIndex == 0) {
          presentCount++;
        }
      }

      final attendancePercent =
          totalAttendance == 0 ? 0 : ((presentCount / totalAttendance) * 100).round();
      final completedClasses = presentCount;

      return _TeacherStats(
        attendancePercent: attendancePercent,
        positivePoints: positivePoints,
        completedClasses: completedClasses,
        violationsRaised: violationsRaised,
      );
    } catch (_) {
      return const _TeacherStats(
        attendancePercent: 0,
        positivePoints: 0,
        completedClasses: 0,
        violationsRaised: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailText = widget.teacher.email.trim().isEmpty
        ? 'غير مسجل'
        : _normalizeTeacherEmailForDisplay(widget.teacher.email.trim());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.teacher.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadingClassNames = true;
              });
              _loadClassNames();
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(Uri(
            path: '/teacher-schedule',
            queryParameters: {'teacherId': widget.teacher.id},
          ).toString());
        },
        label: const Text('عرض الجدول'),
        icon: const Icon(Icons.calendar_month),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50.r,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      widget.teacher.name[0],
                      style: TextStyle(
                        fontSize: 40.sp,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    widget.teacher.name,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.teacher.stage ?? 'معلم',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Achievements / Stats
            _buildSectionTitle('الإنجازات والأداء'),
            SizedBox(height: 16.h),
            FutureBuilder<_TeacherStats>(
              future: _fetchStats(),
              builder: (context, snapshot) {
                final stats = snapshot.data ??
                    const _TeacherStats(
                      attendancePercent: 0,
                      positivePoints: 0,
                      completedClasses: 0,
                      violationsRaised: 0,
                    );
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'نسبة الحضور',
                            '${stats.attendancePercent}%',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildStatCard(
                            'نقاط إيجابية',
                            '${stats.positivePoints}',
                            Icons.star,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'الحصص المنجزة',
                            '${stats.completedClasses}',
                            Icons.class_,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildStatCard(
                            'مخالفات مرفوعة',
                            '${stats.violationsRaised}',
                            Icons.warning,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 32.h),

            // Info Section
            _buildSectionTitle('البيانات الشخصية'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('البريد الإلكتروني'),
                    subtitle: Text(emailText),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('رقم الجوال'),
                    subtitle: Text(widget.teacher.phoneNumber ?? 'غير مسجل'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.class_outlined),
                    title: const Text('الفصول المسندة'),
                    subtitle: _loadingClassNames
                        ? const Text('جاري التحميل...')
                        : Text(
                            _getAssignedClassesText(),
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: _showAssignClassesDialog,
                        icon: const Icon(Icons.edit_note, size: 24),
                        label: const Text(
                          'تعديل الفصول المسندة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAssignedClassesText() {
    if (_currentAssignedClassIds == null || _currentAssignedClassIds!.isEmpty) {
      return 'لا يوجد';
    }

    final classNames = _currentAssignedClassIds!
        .map((id) => _classNames[id] ?? id)
        .join('، ');
    
    return classNames;
  }

  Future<void> _showAssignClassesDialog() async {
    final schoolId = widget.teacher.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تحديد المدرسة')),
      );
      return;
    }

    // جلب جميع الفصول
    List<Map<String, dynamic>> allClasses = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Classes')
          .get();
      
      allClasses = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? data['className'] ?? doc.id,
        };
      }).toList();
      
      allClasses.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب الفصول: $e')),
      );
      return;
    }

    if (!mounted) return;

    // الفصول المسندة حالياً
    final currentAssignedIds = Set<String>.from(
      _currentAssignedClassIds ?? [],
    );

    final selectedIds = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _AssignClassesDialog(
        allClasses: allClasses,
        initialSelectedIds: currentAssignedIds,
      ),
    );

    if (selectedIds == null || !mounted) return;

    // حفظ التغييرات
    try {
      final schoolId = widget.teacher.schoolId;
      
      // حفظ في GlobalUsers
      await FirebaseFirestore.instance
          .collection('GlobalUsers')
          .doc(widget.teacher.id)
          .update({
        'assignedClassIds': selectedIds.toList(),
      });
      
      // حفظ في Schools/Teachers أيضاً
      if (schoolId != null && schoolId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Teachers')
            .doc(widget.teacher.id)
            .update({
          'assignedClassIds': selectedIds.toList(),
        });
      }

      if (!mounted) return;
      
      // تحديث الحالة المحلية
      setState(() {
        _currentAssignedClassIds = selectedIds.toList();
      });
      
      // إعادة تحميل أسماء الفصول
      await _loadClassNames();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الإسنادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade900,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _TeacherStats {
  final int attendancePercent;
  final int positivePoints;
  final int completedClasses;
  final int violationsRaised;

  const _TeacherStats({
    required this.attendancePercent,
    required this.positivePoints,
    required this.completedClasses,
    required this.violationsRaised,
  });
}

class _AssignClassesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allClasses;
  final Set<String> initialSelectedIds;

  const _AssignClassesDialog({
    required this.allClasses,
    required this.initialSelectedIds,
  });

  @override
  State<_AssignClassesDialog> createState() => _AssignClassesDialogState();
}

class _AssignClassesDialogState extends State<_AssignClassesDialog> {
  late Set<String> _selectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
  }

  List<Map<String, dynamic>> get _filteredClasses {
    if (_searchQuery.isEmpty) return widget.allClasses;
    return widget.allClasses.where((c) {
      final name = (c['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.class_outlined, color: Colors.indigo, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إسناد الفصول',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن فصل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            
            // Selected count
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.indigo, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الفصول المحددة: ${_selectedIds.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      child: const Text('إلغاء الكل'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Classes list
            Expanded(
              child: _filteredClasses.isEmpty
                  ? const Center(child: Text('لا توجد فصول'))
                  : ListView.builder(
                      itemCount: _filteredClasses.length,
                      itemBuilder: (context, index) {
                        final classData = _filteredClasses[index];
                        final classId = classData['id'] as String;
                        final className = classData['name'] as String;
                        final isSelected = _selectedIds.contains(classId);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(classId);
                              } else {
                                _selectedIds.remove(classId);
                              }
                            });
                          },
                          title: Text(className),
                          activeColor: Colors.indigo,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selectedIds),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
