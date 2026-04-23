import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final broadcastMembersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday % 7));
  final weekEnd = weekStart.add(const Duration(days: 6));

  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('BroadcastMembers')
      .where('weekStart',
          isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(weekStart))
      .where('weekStart',
          isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(weekEnd))
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'docId': d.id}).toList());
});

final schoolStudentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Students')
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  static const _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  String get _currentWeekLabel {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 4));
    return '${DateFormat('dd/MM').format(weekStart)} - ${DateFormat('dd/MM').format(weekEnd)}';
  }

  String get _currentWeekStart {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    return DateFormat('yyyy-MM-dd').format(weekStart);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    // Set tab to current day
    final today = DateTime.now().weekday; // 1=Mon ... 7=Sun
    final dayIndex = today == 7 ? 0 : today; // Sun=0
    if (dayIndex < _days.length) {
      _tabController.index = dayIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإذاعة المدرسية',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('أسبوع: $_currentWeekLabel',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'إضافة طالب',
            onPressed: () => _showAddStudentDialog(context, schoolId, user),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(schoolId),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'بحث باسم الطالب...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _days
                  .map((day) => _buildDayTab(schoolId, day))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(String schoolId) {
    final membersAsync = ref.watch(broadcastMembersProvider(schoolId));
    return membersAsync.when(
      data: (members) {
        final total = members.length;
        final Map<String, int> dayCounts = {};
        for (final m in members) {
          final day = m['day'] as String? ?? '';
          dayCounts[day] = (dayCounts[day] ?? 0) + 1;
        }
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          color: const Color(0xFF1A237E).withValues(alpha: 0.05),
          child: Row(
            children: [
              Icon(Icons.groups, color: const Color(0xFF1A237E), size: 18.sp),
              SizedBox(width: 8.w),
              Text('إجمالي هذا الأسبوع: $total طالب',
                  style: TextStyle(
                      color: const Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDayTab(String schoolId, String day) {
    final membersAsync = ref.watch(broadcastMembersProvider(schoolId));
    return membersAsync.when(
      data: (allMembers) {
        final dayMembers = allMembers
            .where((m) => m['day'] == day)
            .where((m) => _searchQuery.isEmpty ||
                (m['studentName'] as String? ?? '')
                    .contains(_searchQuery))
            .toList();

        if (dayMembers.isEmpty) {
          return _buildEmptyDay(day, schoolId);
        }

        return ListView.builder(
          padding: EdgeInsets.all(12.w),
          itemCount: dayMembers.length,
          itemBuilder: (ctx, i) =>
              _buildMemberCard(dayMembers[i], schoolId),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildEmptyDay(String day, String schoolId) {
    final user = ref.watch(authStateProvider).value;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 56.sp, color: Colors.grey.shade300),
          SizedBox(height: 12.h),
          Text('لا يوجد طلاب ليوم $day',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () =>
                _showAddStudentDialog(context, schoolId, user, defaultDay: day),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r)),
            ),
            icon: const Icon(Icons.add),
            label: Text('إضافة طالب ليوم $day'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, String schoolId) {
    final role = member['role'] as String? ?? 'عضو';
    final roleColor = _getRoleColor(role);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (member['studentName'] as String? ?? '?')
                      .characters
                      .first,
                  style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member['studentName'] as String? ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                              color: roleColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(role,
                            style: TextStyle(
                                color: roleColor,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(width: 8.w),
                      Text(member['className'] as String? ?? '',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11.sp)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade300, size: 20.sp),
              onPressed: () =>
                  _removeMember(member['docId'] as String, schoolId,
                      member['studentId'] as String? ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'مقدم':
        return const Color(0xFF1565C0);
      case 'تلاوة':
        return const Color(0xFF2E7D32);
      case 'كلمة':
        return const Color(0xFF6A1B9A);
      case 'نشيد':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF37474F);
    }
  }

  Future<void> _showAddStudentDialog(
    BuildContext context,
    String schoolId,
    User? user, {
    String? defaultDay,
  }) async {
    // Load students directly from Firestore
    List<Map<String, dynamic>> students = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .orderBy('name')
          .get();
      students = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      students = [];
    }

    String? selectedStudentId;
    String? selectedStudentName;
    String? selectedClassName;
    String selectedDay = defaultDay ?? _days[_tabController.index];
    String selectedRole = 'عضو';
    String notes = '';

    final roles = ['مقدم', 'تلاوة', 'كلمة', 'نشيد', 'عضو'];
    String searchText = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = students
              .where((s) => searchText.isEmpty ||
                  (s['name'] as String? ?? '')
                      .contains(searchText))
              .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r)),
            insetPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: Container(
              constraints: BoxConstraints(maxWidth: 480.w, maxHeight: 620.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_add,
                            color: Colors.white, size: 22.sp),
                        SizedBox(width: 10.w),
                        Text('إضافة طالب للإذاعة',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day selector
                          Text('اليوم',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp)),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            children: _days
                                .map((d) => ChoiceChip(
                                      label: Text(d),
                                      selected: selectedDay == d,
                                      onSelected: (_) => setDialogState(
                                          () => selectedDay = d),
                                      selectedColor: const Color(0xFF1A237E),
                                      labelStyle: TextStyle(
                                          color: selectedDay == d
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 11.sp),
                                    ))
                                .toList(),
                          ),
                          SizedBox(height: 14.h),

                          // Role selector
                          Text('الدور',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp)),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            children: roles
                                .map((r) => ChoiceChip(
                                      label: Text(r),
                                      selected: selectedRole == r,
                                      onSelected: (_) => setDialogState(
                                          () => selectedRole = r),
                                      selectedColor:
                                          _getRoleColor(r),
                                      labelStyle: TextStyle(
                                          color: selectedRole == r
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 11.sp),
                                    ))
                                .toList(),
                          ),
                          SizedBox(height: 14.h),

                          // Student search
                          Text('اختر الطالب',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp)),
                          SizedBox(height: 8.h),
                          TextField(
                            onChanged: (v) =>
                                setDialogState(() => searchText = v),
                            decoration: InputDecoration(
                              hintText: 'بحث...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10.r)),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8.h),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            height: 180.h,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final s = filtered[i];
                                final sid = s['id'] as String;
                                final sname =
                                    s['name'] as String? ?? '';
                                final sclass =
                                    s['className'] as String? ?? '';
                                final isSelected =
                                    selectedStudentId == sid;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: const Color(
                                          0xFF1A237E)
                                      .withValues(alpha: 0.08),
                                  leading: CircleAvatar(
                                    radius: 16.r,
                                    backgroundColor: isSelected
                                        ? const Color(0xFF1A237E)
                                        : Colors.grey.shade200,
                                    child: Text(
                                      sname.characters.first,
                                      style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black54,
                                          fontSize: 12.sp),
                                    ),
                                  ),
                                  title: Text(sname,
                                      style:
                                          TextStyle(fontSize: 13.sp)),
                                  subtitle: Text(sclass,
                                      style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey)),
                                  onTap: () => setDialogState(() {
                                    selectedStudentId = sid;
                                    selectedStudentName = sname;
                                    selectedClassName = sclass;
                                  }),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Notes
                          TextField(
                            onChanged: (v) => notes = v,
                            decoration: InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10.r)),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: selectedStudentId == null
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await _addMember(
                                      schoolId: schoolId,
                                      studentId: selectedStudentId!,
                                      studentName: selectedStudentName!,
                                      className: selectedClassName ?? '',
                                      day: selectedDay,
                                      role: selectedRole,
                                      notes: notes,
                                      addedBy: user?.name ?? '',
                                      addedById: user?.id ?? '',
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10.r)),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addMember({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String day,
    required String role,
    required String notes,
    required String addedBy,
    required String addedById,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add to BroadcastMembers
      final memberRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('BroadcastMembers')
          .doc();

      batch.set(memberRef, {
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'day': day,
        'role': role,
        'notes': notes,
        'weekStart': _currentWeekStart,
        'addedBy': addedBy,
        'addedById': addedById,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Add notification to student
      final notifRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .doc(studentId)
          .collection('Notifications')
          .doc();

      batch.set(notifRef, {
        'title': '📢 أنت في الإذاعة المدرسية!',
        'body':
            'تم اختيارك للمشاركة في الإذاعة المدرسية يوم $day بدور: $role',
        'type': 'broadcast',
        'day': day,
        'role': role,
        'weekStart': _currentWeekStart,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة $studentName ليوم $day ✅'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeMember(
      String docId, String schoolId, String studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف من الإذاعة'),
        content: const Text('هل تريد إزالة هذا الطالب من الإذاعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('BroadcastMembers')
        .doc(docId)
        .delete();
  }
}
