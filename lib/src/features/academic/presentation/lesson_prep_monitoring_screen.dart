import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../common/services/audit_service.dart';

class LessonPrepMonitoringScreen extends ConsumerStatefulWidget {
  const LessonPrepMonitoringScreen({super.key});

  @override
  ConsumerState<LessonPrepMonitoringScreen> createState() => _LessonPrepMonitoringScreenState();
}

class _LessonPrepMonitoringScreenState extends ConsumerState<LessonPrepMonitoringScreen> {
  String _filter = 'all'; // all, late, missing

  @override
  void initState() {
    super.initState();
    // Log view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(auditServiceProvider).logAction(
        action: 'view_lesson_prep',
        description: 'Academic Deputy viewed lesson preparation report',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة تحضير الدروس'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'late', child: Text('متأخر')),
              const PopupMenuItem(value: 'missing', child: Text('لم يحضر')),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: teachersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
        data: (teachers) {
          // Mock data augmentation for demo purposes
          // In real app, this would come from a LessonPlanRepository
          final stats = [
            {'status': 'completed', 'count': 15, 'label': 'مكتمل'},
            {'status': 'late', 'count': 3, 'label': 'متأخر'},
            {'status': 'missing', 'count': 2, 'label': 'غير محضر'},
          ];

          return Column(
            children: [
              _buildStatsHeader(stats),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = teachers[index];
                    // Mock status per teacher
                    String status = index % 3 == 0 ? 'completed' : (index % 3 == 1 ? 'late' : 'missing');
                    
                    if (_filter == 'late' && status != 'late') return const SizedBox.shrink();
                    if (_filter == 'missing' && status != 'missing') return const SizedBox.shrink();

                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(teacher.name[0]),
                        ),
                        title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(teacher.email),
                        trailing: _buildStatusChip(status),
                        onTap: () {
                          // Show detail dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(teacher.name),
                              content: const Text('تفاصيل التحضير للأسبوع الحالي...'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(List<Map<String, dynamic>> stats) {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats.map((stat) {
          Color color = Colors.green;
          if (stat['status'] == 'late') color = Colors.orange;
          if (stat['status'] == 'missing') color = Colors.red;

          return Column(
            children: [
              Text(
                stat['count'].toString(),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                stat['label'],
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.green;
    String text = 'تم التحضير';
    IconData icon = Icons.check_circle;

    if (status == 'late') {
      color = Colors.orange;
      text = 'متأخر';
      icon = Icons.access_time;
    } else if (status == 'missing') {
      color = Colors.red;
      text = 'لم يحضر';
      icon = Icons.warning;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}
