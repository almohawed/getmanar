import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../admin/data/mock_teacher_repository.dart';

/// شاشة إدارة حدود رسائل المعلمين - للوكيل التعليمي
class TeacherSmsLimitsScreen extends ConsumerStatefulWidget {
  const TeacherSmsLimitsScreen({super.key});

  @override
  ConsumerState<TeacherSmsLimitsScreen> createState() => _TeacherSmsLimitsScreenState();
}

class _TeacherSmsLimitsScreenState extends ConsumerState<TeacherSmsLimitsScreen> {
  Map<String, int> _limits = {};
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final teachersAsync = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('حدود رسائل المعلمين', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط المعلومات
          Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'حدد عدد الرسائل اليومية المسموح بها لكل معلم. الحد الافتراضي 10 رسائل/يوم.',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // قائمة المعلمين
          Expanded(
            child: teachersAsync.when(
              data: (teachers) {
                if (teachers.isEmpty) {
                  return const Center(child: Text('لا يوجد معلمون مسجلون'));
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('Schools').doc(schoolId)
                      .collection('TeacherSmsLimits').doc('_all').get(),
                  builder: (context, _) {
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: teachers.length,
                      itemBuilder: (context, i) {
                        final teacher = teachers[i];
                        final currentLimit = _limits[teacher.id] ?? 10;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('Schools').doc(schoolId)
                              .collection('TeacherSmsLimits').doc(teacher.id).get(),
                          builder: (context, snap) {
                            if (snap.hasData && snap.data!.exists && !_limits.containsKey(teacher.id)) {
                              final savedLimit = (snap.data!.data() as Map?)?['dailyLimit'] ?? 10;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _limits[teacher.id] = savedLimit);
                              });
                            }

                            return Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20.r,
                                        backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                                        child: Text(
                                          teacher.name.isNotEmpty ? teacher.name[0] : '?',
                                          style: TextStyle(color: const Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 14.sp),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(teacher.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                                            Text(teacher.email, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1565C0).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10.r),
                                          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '$currentLimit رسالة/يوم',
                                          style: TextStyle(color: const Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 12.sp),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Text('0', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                                      Expanded(
                                        child: Slider(
                                          value: currentLimit.toDouble(),
                                          min: 0,
                                          max: 50,
                                          divisions: 50,
                                          activeColor: const Color(0xFF1565C0),
                                          inactiveColor: const Color(0xFF1565C0).withOpacity(0.2),
                                          onChanged: (v) => setState(() => _limits[teacher.id] = v.round()),
                                          onChangeEnd: (v) => _saveLimit(schoolId, teacher.id, v.round()),
                                        ),
                                      ),
                                      Text('50', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                  // أزرار سريعة
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [5, 10, 15, 20].map((n) => GestureDetector(
                                      onTap: () {
                                        setState(() => _limits[teacher.id] = n);
                                        _saveLimit(schoolId, teacher.id, n);
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(right: 6.w),
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: currentLimit == n ? const Color(0xFF1565C0) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text('$n', style: TextStyle(
                                          fontSize: 11.sp,
                                          color: currentLimit == n ? Colors.white : Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                        )),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLimit(String schoolId, String teacherId, int limit) async {
    if (schoolId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('TeacherSmsLimits').doc(teacherId)
          .set({'dailyLimit': limit, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
  }
}
