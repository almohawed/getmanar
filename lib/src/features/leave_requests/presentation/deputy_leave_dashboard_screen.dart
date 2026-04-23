import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import '../domain/leave_request.dart';
import '../data/leave_request_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class DeputyLeaveDashboardScreen extends ConsumerStatefulWidget {
  const DeputyLeaveDashboardScreen({super.key});

  @override
  ConsumerState<DeputyLeaveDashboardScreen> createState() =>
      _DeputyLeaveDashboardScreenState();
}

class _DeputyLeaveDashboardScreenState
    extends ConsumerState<DeputyLeaveDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterType = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reviewRequest(
    LeaveRequest req,
    LeaveStatus newStatus,
    String? note,
  ) async {
    final user = ref.read(authStateProvider).value;
    try {
      await ref.read(leaveRequestRepositoryProvider).updateStatus(
            schoolId: req.schoolId,
            requestId: req.id,
            status: newStatus,
            deputyNote: note,
            reviewedBy: user?.name ?? '',
          );

      // إشعار مباشر للمعلم في Firestore (بدون Cloud Function)
      if (req.teacherId.isNotEmpty) {
        try {
          final isApproved = newStatus == LeaveStatus.approved;
          final notifId = FirebaseFirestore.instance.collection('tmp').doc().id;
          await FirebaseFirestore.instance
              .collection('Schools')
              .doc(req.schoolId)
              .collection('Notifications')
              .doc(notifId)
              .set({
            'id': notifId,
            'userId': req.teacherId,
            'title': isApproved ? '✅ تم قبول طلب استئذانك' : '❌ تم رفض طلب استئذانك',
            'body': isApproved
                ? 'وافق الوكيل على طلب ${req.type.label} الخاص بك${note != null && note.isNotEmpty ? " - ملاحظة: $note" : ""}'
                : 'رفض الوكيل طلب ${req.type.label} الخاص بك${note != null && note.isNotEmpty ? " - السبب: $note" : ""}',
            'timestamp': DateTime.now().toIso8601String(),
            'isRead': false,
            'route': '/teacher-leave-request',
            'data': {'requestId': req.id, 'type': 'leave_response'},
            'schoolId': req.schoolId,
            'targetRole': null,
            'targetClassId': null,
          });
        } catch (_) {}
      }
      if (mounted) {
        final msg = newStatus == LeaveStatus.approved
            ? '✅ تم قبول الطلب'
            : '❌ تم رفض الطلب';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: newStatus == LeaveStatus.approved
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReviewDialog(LeaveRequest req) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس الحوار
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.rate_review, color: Colors.white, size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مراجعة الطلب',
                          style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          req.teacherName,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // تفاصيل الطلب
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogRow('النوع', '${req.type.icon} ${req.type.label}'),
                    _dialogRow(
                        'التاريخ',
                        intl.DateFormat('d MMM yyyy', 'ar')
                            .format(req.leaveDate)),
                    if (req.fromTime != null)
                      _dialogRow('الوقت', '${req.fromTime} - ${req.toTime}'),
                    _dialogRow('السبب', req.reason),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // ملاحظة الوكيل
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  hintText: 'أضف ملاحظة للمعلم...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              SizedBox(height: 16.h),

              // أزرار القرار
              Row(
                children: [
                  Expanded(
                    child: _buildDecisionButton(
                      label: 'رفض',
                      icon: Icons.close_rounded,
                      color: Colors.red.shade600,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _reviewRequest(
                            req, LeaveStatus.rejected, noteCtrl.text.trim());
                      },
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildDecisionButton(
                      label: 'قبول',
                      icon: Icons.check_rounded,
                      color: Colors.green.shade600,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _reviewRequest(
                            req, LeaveStatus.approved, noteCtrl.text.trim());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 6.w),
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 200.h,
            pinned: true,
            backgroundColor: const Color(0xFF4A148C),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(schoolId),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber.shade300,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
              tabs: const [
                Tab(icon: Icon(Icons.pending_actions), text: 'قيد المراجعة'),
                Tab(icon: Icon(Icons.check_circle_outline), text: 'المقبولة'),
                Tab(icon: Icon(Icons.cancel_outlined), text: 'المرفوضة'),
              ],
            ),
          ),
        ],
        body: schoolId.isEmpty
            ? const Center(child: Text('تعذّر تحميل البيانات'))
            : StreamBuilder<List<LeaveRequest>>(
                stream: ref
                    .watch(leaveRequestRepositoryProvider)
                    .streamAllRequests(schoolId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snapshot.data ?? [];
                  final pending = all
                      .where((r) => r.status == LeaveStatus.pending)
                      .toList();
                  final approved = all
                      .where((r) => r.status == LeaveStatus.approved)
                      .toList();
                  final rejected = all
                      .where((r) => r.status == LeaveStatus.rejected)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(pending, showActions: true),
                      _buildList(approved, showActions: false),
                      _buildList(rejected, showActions: false),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHeroHeader(String schoolId) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF7B1FA2)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // زخارف
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 180.w, height: 180.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 30, left: -20,
            child: Container(
              width: 120.w, height: 120.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // المحتوى
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 50.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.assignment_ind,
                          color: Colors.white, size: 28.sp),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة إدارة الاستئذانات',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'وكيل الشؤون التعليمية',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                // إحصائيات سريعة
                StreamBuilder<List<LeaveRequest>>(
                  stream: ref
                      .watch(leaveRequestRepositoryProvider)
                      .streamAllRequests(schoolId),
                  builder: (context, snap) {
                    final all = snap.data ?? [];
                    final pending =
                        all.where((r) => r.status == LeaveStatus.pending).length;
                    final approved =
                        all.where((r) => r.status == LeaveStatus.approved).length;
                    final rejected =
                        all.where((r) => r.status == LeaveStatus.rejected).length;
                    return Row(
                      children: [
                        _buildStatChip('⏳ $pending', 'انتظار', Colors.amber),
                        SizedBox(width: 8.w),
                        _buildStatChip('✅ $approved', 'مقبول', Colors.greenAccent),
                        SizedBox(width: 8.w),
                        _buildStatChip('❌ $rejected', 'مرفوض', Colors.redAccent),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
            color: color, fontSize: 11.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildList(List<LeaveRequest> requests, {required bool showActions}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64.sp, color: Colors.grey.shade300),
            SizedBox(height: 12.h),
            Text(
              'لا توجد طلبات',
              style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: requests.length,
      itemBuilder: (_, i) =>
          _buildDeputyCard(requests[i], showActions: showActions),
    );
  }

  Widget _buildDeputyCard(LeaveRequest req, {required bool showActions}) {
    final df = intl.DateFormat('d MMM yyyy', 'ar');
    final dfTime = intl.DateFormat('h:mm a', 'ar');

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة - معلومات المعلم
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A148C).withOpacity(0.08),
                  const Color(0xFF4A148C).withOpacity(0.02),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
              ),
            ),
            child: Row(
              children: [
                // أفاتار المعلم
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      req.teacherName.isNotEmpty
                          ? req.teacherName[0]
                          : '؟',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.teacherName,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'طُلب في: ${dfTime.format(req.requestDate)}',
                        style: TextStyle(
                            fontSize: 11.sp, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // شارة النوع
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${req.type.icon} ${req.type.label}',
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: const Color(0xFF4A148C),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // تفاصيل الطلب
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // التاريخ والوقت
                Row(
                  children: [
                    _infoChip(
                      Icons.calendar_today,
                      df.format(req.leaveDate),
                      Colors.blue.shade700,
                    ),
                    if (req.fromTime != null) ...[
                      SizedBox(width: 8.w),
                      _infoChip(
                        Icons.access_time,
                        '${req.fromTime} - ${req.toTime}',
                        Colors.teal.shade700,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 10.h),

                // السبب
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote,
                          color: Colors.grey.shade400, size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          req.reason,
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey.shade700,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // ملاحظة الوكيل إن وجدت
                if (req.deputyNote != null && req.deputyNote!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: req.status == LeaveStatus.approved
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: req.status == LeaveStatus.approved
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment,
                          size: 14.sp,
                          color: req.status == LeaveStatus.approved
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            req.deputyNote!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: req.status == LeaveStatus.approved
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // أزرار القرار
                if (showActions) ...[
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reviewRequest(
                              req, LeaveStatus.rejected, null),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.red),
                          label: const Text('رفض',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r)),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _showReviewDialog(req),
                          icon: const Icon(Icons.rate_review,
                              color: Colors.white),
                          label: const Text('مراجعة وقرار',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A148C),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 5.w),
          Text(text,
              style: TextStyle(
                  fontSize: 11.sp,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
