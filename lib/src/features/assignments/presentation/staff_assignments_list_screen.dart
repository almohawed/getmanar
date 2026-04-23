import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../domain/staff_assignment.dart';
import '../application/staff_assignment_service.dart';

final staffAssignmentsProvider = StreamProvider.family<List<StaffAssignment>, String>((ref, schoolId) {
  return StaffAssignmentService().getAssignmentsBySchool(schoolId);
});

class StaffAssignmentsListScreen extends ConsumerWidget {
  final String schoolId;

  const StaffAssignmentsListScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(staffAssignmentsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التكاليف'),
        backgroundColor: const Color(0xFF2D3494),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-staff-assignment', extra: schoolId),
          ),
        ],
      ),
      body: assignmentsAsync.when(
        data: (assignments) {
          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text('لا توجد تكاليف', style: TextStyle(fontSize: 18.sp, color: Colors.grey)),
                  SizedBox(height: 8.h),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-staff-assignment', extra: schoolId),
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء تكليف جديد'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3494)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return _buildAssignmentCard(context, ref, assignment);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('خطأ: $error')),
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context, WidgetRef ref, StaffAssignment assignment) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment_ind, color: Colors.blue, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.assignmentTitle,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        assignment.assignedUserName,
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'deactivate', child: Text('إلغاء التكليف')),
                  ],
                  onSelected: (value) async {
                    if (value == 'deactivate') {
                      await StaffAssignmentService().deactivateAssignment(schoolId, assignment.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إلغاء التكليف')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            if (assignment.description != null) ...[
              SizedBox(height: 12.h),
              Text(
                assignment.description!,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.person, size: 16.sp, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(
                  assignment.assignedUserRole,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 16.sp, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(
                  _formatDate(assignment.createdAt),
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
