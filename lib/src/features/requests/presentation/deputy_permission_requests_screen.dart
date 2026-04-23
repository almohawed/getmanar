import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../data/permission_repository.dart';
import '../domain/permission_request.dart';

final permissionRecordsProvider = FutureProvider<List<BehaviorRecord>>((
  ref,
) async {
  final repo = ref.watch(behaviorRepositoryProvider);
  return repo.getRecordsByType(BehaviorType.permission);
});

class DeputyPermissionRequestsScreen extends ConsumerWidget {
  const DeputyPermissionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الاستئذان'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'الطلبات المعلقة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildPendingRequests(context, ref),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'الواصلون',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildArrivalsList(context, ref),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'سجل الاستئذان',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildPermissionLog(context, ref),
        ],
      ),
    );
  }

  Widget _buildArrivalsList(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final arrivedRequests = requests
        .where(
          (r) => r.status == PermissionRequestStatus.approved && r.isParentNear,
        )
        .toList();

    if (arrivedRequests.isEmpty) {
      return const Center(child: Text('لا يوجد أولياء أمور في المحيط حالياً'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: arrivedRequests.length,
      itemBuilder: (context, index) {
        final request = arrivedRequests[index];
        return Card(
          color: Colors.green.shade50,
          margin: EdgeInsets.only(bottom: 12.h),
          child: ListTile(
            leading: Icon(
              Icons.location_on,
              color: Colors.green.shade700,
              size: 32.sp,
            ),
            title: Text(
              'ولي أمر الطالب: ${request.studentName}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'وصل إلى نطاق المدرسة: ${request.parentArrivedAt != null ? DateFormat('HH:mm').format(request.parentArrivedAt!) : 'الآن'}',
            ),
            trailing: Chip(
              label: const Text('وصل'),
              backgroundColor: Colors.green,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingRequests(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final pendingRequests = requests
        .where((r) => r.status == PermissionRequestStatus.pending)
        .toList();

    if (pendingRequests.isEmpty) {
      return const Center(child: Text('لا توجد طلبات استئذان معلقة'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: pendingRequests.length,
      itemBuilder: (context, index) {
        final request = pendingRequests[index];
        return _buildRequestCard(context, ref, request);
      },
    );
  }

  Widget _buildPermissionLog(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(permissionRecordsProvider);

    return recordsAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const Center(child: Text('سجل الاستئذان فارغ'));
        }
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.blueGrey),
                title: Text(
                  'الطالب: ${record.studentId}',
                ), // Ideally resolve name
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.description),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(record.timestamp),
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    WidgetRef ref,
    PermissionRequest request,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.person, color: Colors.orange.shade800),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.studentName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'وقت الطلب: ${DateFormat('yyyy-MM-dd HH:mm').format(request.createdAt)}',
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              'السبب:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
            Text(request.reason, style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveRequest(context, ref, request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('موافق'),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(context, ref, request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    WidgetRef ref,
    PermissionRequest request,
  ) async {
    // 1. Approve the request
    await ref.read(requestsProvider.notifier).approveRequest(request.id);

    // 2. Create Behavior Record (Permission/Dismissal)
    final currentUser = ref.read(authStateProvider).value;
    final teacherId = currentUser?.id ?? 'DEPUTY';

    final behaviorRecord = BehaviorRecord(
      id: const Uuid().v4(),
      studentId: request.studentId,
      teacherId: teacherId,
      type: BehaviorType.permission,
      description: 'استئذان: ${request.reason}',
      points: 0,
      timestamp: DateTime.now(),
      status: BehaviorStatus.approved,
    );

    // 3. Save to Behavior Repository
    await ref
        .read(behaviorRepositoryProvider)
        .addBehaviorRecord(behaviorRecord);

    // 4. Refresh Log (Notifications handled in RequestsNotifier)
    ref.invalidate(permissionRecordsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت الموافقة على الطلب وتسجيله في سجل الاستئذان وإشعار الإدارة',
          ),
        ),
      );
    }
  }

  void _rejectRequest(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: 'اكتب سبب الرفض'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(requestsProvider.notifier)
                    .rejectRequest(requestId, reasonController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
              },
              child: const Text('تأكيد الرفض'),
            ),
          ],
        );
      },
    );
  }
}
