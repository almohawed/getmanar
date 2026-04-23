import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';

final _teachersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
});

class AssignBroadcastSupervisorScreen extends ConsumerStatefulWidget {
  const AssignBroadcastSupervisorScreen({super.key});

  @override
  ConsumerState<AssignBroadcastSupervisorScreen> createState() =>
      _AssignBroadcastSupervisorScreenState();
}

class _AssignBroadcastSupervisorScreenState
    extends ConsumerState<AssignBroadcastSupervisorScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final teachersAsync = ref.watch(_teachersProvider(schoolId));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: teachersAsync.when(
        data: (teachers) {
          final current = teachers.firstWhere(
            (t) =>
                (t['delegatedPermissions'] as Map? ?? {})['isBroadcastSupervisor'] ==
                true,
            orElse: () => {},
          );
          final hasCurrent = current.isNotEmpty;

          final filtered = teachers
              .where((t) => _search.isEmpty ||
                  (t['name'] as String? ?? '')
                      .contains(_search))
              .toList();

          return CustomScrollView(
            slivers: [
              // ─── AppBar ───────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 160.h,
                pinned: true,
                backgroundColor: const Color(0xFF0D1B2A),
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 40.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(Icons.mic, color: Colors.white, size: 26.sp),
                                ),
                                SizedBox(width: 14.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('مسؤول الإذاعة المدرسية',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18.sp)),
                                    Text('تعيين المعلم المكلف بالإذاعة',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.sp)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Current Supervisor Card ──────────────────
                      if (hasCurrent) ...[
                        _buildCurrentSupervisorCard(current, schoolId, teachers),
                        SizedBox(height: 20.h),
                      ] else ...[
                        _buildNoSupervisorBanner(),
                        SizedBox(height: 20.h),
                      ],

                      // ─── Search ───────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'بحث باسم المعلم...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Text('قائمة المعلمين',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),

              // ─── Teachers List ────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final t = filtered[i];
                      final perms = t['delegatedPermissions'] as Map? ?? {};
                      final isSupervisor = perms['isBroadcastSupervisor'] == true;
                      return _buildTeacherCard(
                          t, isSupervisor, schoolId, teachers);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 40.h)),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) =>
            Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildCurrentSupervisorCard(
      Map t, String schoolId, List<Map<String, dynamic>> teachers) {
    final name = t['name'] as String? ?? '';
    final spec = t['specialization'] as String? ?? '';
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.verified_user, color: Colors.amber, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Text('المسؤول الحالي',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              CircleAvatar(
                radius: 26.r,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  name.characters.first,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp)),
                    if (spec.isNotEmpty)
                      Text(spec,
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12.sp)),
                  ],
                ),
              ),
              // Remove button
              TextButton.icon(
                onPressed: () => _removeSupervisor(
                    t['id'] as String, name, schoolId),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                ),
                icon: Icon(Icons.person_remove, size: 16.sp),
                label: Text('إزالة', style: TextStyle(fontSize: 12.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoSupervisorBanner() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لم يتم تعيين مسؤول بعد',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp)),
                Text('اختر معلماً من القائمة أدناه لتعيينه مسؤولاً للإذاعة',
                    style: TextStyle(color: Colors.orange.shade200, fontSize: 11.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map t, bool isSupervisor, String schoolId,
      List<Map<String, dynamic>> teachers) {
    final name = t['name'] as String? ?? '';
    final spec = t['specialization'] as String? ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isSupervisor
            ? const Color(0xFF1A237E).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isSupervisor
              ? const Color(0xFF3949AB)
              : Colors.white.withValues(alpha: 0.08),
          width: isSupervisor ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22.r,
              backgroundColor: isSupervisor
                  ? const Color(0xFF3949AB)
                  : Colors.white.withValues(alpha: 0.1),
              child: Text(
                name.characters.first,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp),
              ),
            ),
            SizedBox(width: 12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp)),
                  if (spec.isNotEmpty)
                    Text(spec,
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11.sp)),
                ],
              ),
            ),
            // Badge or Assign button
            if (isSupervisor)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF3949AB),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.white, size: 13.sp),
                    SizedBox(width: 4.w),
                    Text('مكلّف',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () => _assignSupervisor(
                    t['id'] as String, name, schoolId, teachers),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('تعيين', style: TextStyle(fontSize: 12.sp)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignSupervisor(String teacherId, String teacherName,
      String schoolId, List<Map<String, dynamic>> teachers) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.mic, color: Colors.amber, size: 22.sp),
            SizedBox(width: 8.w),
            const Text('تعيين مسؤول الإذاعة',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد تعيين "$teacherName" مسؤولاً للإذاعة المدرسية؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white),
            child: const Text('تعيين'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Remove from current
      for (final t in teachers) {
        final perms = t['delegatedPermissions'] as Map? ?? {};
        if (perms['isBroadcastSupervisor'] == true) {
          _updateTeacherPerm(batch, schoolId, t['id'] as String, false);
        }
      }

      // Assign new
      _updateTeacherPerm(batch, schoolId, teacherId, true);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم تعيين $teacherName مسؤولاً للإذاعة ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _removeSupervisor(
      String teacherId, String teacherName, String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('إزالة المسؤول',
            style: TextStyle(color: Colors.white)),
        content: Text('هل تريد إزالة "$teacherName" من مسؤولية الإذاعة؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      _updateTeacherPerm(batch, schoolId, teacherId, false);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم إزالة المسؤول'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _updateTeacherPerm(
      WriteBatch batch, String schoolId, String teacherId, bool value) {
    final teacherRef = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Teachers')
        .doc(teacherId);
    batch.update(teacherRef, {
      'delegatedPermissions.isBroadcastSupervisor': value,
    });

    final globalRef = FirebaseFirestore.instance
        .collection('GlobalUsers')
        .doc(teacherId);
    batch.update(globalRef, {
      'delegatedPermissions.isBroadcastSupervisor': value,
    });
  }
}
