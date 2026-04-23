import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import '../domain/leave_request.dart';
import '../data/leave_request_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class TeacherLeaveRequestScreen extends ConsumerStatefulWidget {
  const TeacherLeaveRequestScreen({super.key});

  @override
  ConsumerState<TeacherLeaveRequestScreen> createState() =>
      _TeacherLeaveRequestScreenState();
}

class _TeacherLeaveRequestScreenState
    extends ConsumerState<TeacherLeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form fields
  LeaveType _selectedType = LeaveType.duringPeriod;
  DateTime _leaveDate = DateTime.now();
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _leaveDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFF1565C0),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _leaveDate = picked);
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom
          ? (_fromTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_toTime ?? const TimeOfDay(hour: 10, minute: 0)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFF1565C0),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _fromTime = picked;
        else _toTime = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      _showSnack('يرجى كتابة سبب الاستئذان', Colors.orange);
      return;
    }
    final needsTime = _selectedType != LeaveType.fullDay;
    if (needsTime && (_fromTime == null || _toTime == null)) {
      _showSnack('يرجى تحديد وقت البداية والنهاية', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      final id = FirebaseFirestore.instance.collection('tmp').doc().id;

      final req = LeaveRequest(
        id: id,
        schoolId: schoolId,
        teacherId: user?.id ?? '',
        teacherName: user?.name ?? '',
        type: _selectedType,
        status: LeaveStatus.pending,
        requestDate: DateTime.now(),
        leaveDate: _leaveDate,
        fromTime: _fromTime != null ? _formatTime(_fromTime!) : null,
        toTime: _toTime != null ? _formatTime(_toTime!) : null,
        reason: _reasonCtrl.text.trim(),
      );

      await ref.read(leaveRequestRepositoryProvider).addRequest(req);

      // إشعار مباشر للوكيل في Firestore (بدون Cloud Function)
      try {
        final notifId = FirebaseFirestore.instance.collection('tmp').doc().id;
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Notifications')
            .doc(notifId)
            .set({
          'id': notifId,
          'userId': null,
          'title': '📋 طلب استئذان جديد',
          'body': 'المعلم ${req.teacherName} يطلب ${req.type.label}',
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
          'route': '/deputy-leave-dashboard',
          'data': {'requestId': req.id, 'type': 'leave_request'},
          'schoolId': schoolId,
          'targetRole': 'deputy',
          'targetClassId': null,
        });
      } catch (_) {}

      if (mounted) {
        _showSnack('✅ تم إرسال طلب الاستئذان بنجاح', Colors.green.shade700);
        _reasonCtrl.clear();
        setState(() {
          _fromTime = null;
          _toTime = null;
          _leaveDate = DateTime.now();
          _selectedType = LeaveType.duringPeriod;
        });
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) _showSnack('خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ));
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
            expandedHeight: 180.h,
            pinned: true,
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(user?.name ?? ''),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber.shade300,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              tabs: const [
                Tab(icon: Icon(Icons.add_circle_outline), text: 'طلب جديد'),
                Tab(icon: Icon(Icons.history), text: 'طلباتي'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildNewRequestTab(),
            _buildMyRequestsTab(schoolId, user?.id ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // دوائر زخرفية
          Positioned(
            top: -30, left: -30,
            child: Container(
              width: 150.w, height: 150.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20, right: -20,
            child: Container(
              width: 100.w, height: 100.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // المحتوى
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 50.h, 20.w, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(Icons.assignment_ind, color: Colors.white, size: 32.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'نظام الاستئذانات الرقمي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'أ. $name',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: Text(
                          '📋 طلباتك تصل للوكيل فوراً',
                          style: TextStyle(color: Colors.amber.shade200, fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    final needsTime = _selectedType != LeaveType.fullDay;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),

          // نوع الاستئذان
          _buildCard(
            title: 'نوع الاستئذان',
            icon: Icons.category_outlined,
            color: const Color(0xFF1565C0),
            child: Column(
              children: LeaveType.values.map((type) {
                final selected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1565C0).withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1565C0)
                            : Colors.grey.shade200,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(type.icon, style: TextStyle(fontSize: 20.sp)),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected
                                  ? const Color(0xFF1565C0)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle,
                              color: const Color(0xFF1565C0), size: 20.sp),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: 12.h),

          // التاريخ والوقت
          _buildCard(
            title: 'التاريخ والوقت',
            icon: Icons.calendar_today,
            color: const Color(0xFF00695C),
            child: Column(
              children: [
                // التاريخ
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: const Color(0xFF00695C).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: const Color(0xFF00695C), size: 22.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تاريخ الاستئذان',
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade600)),
                              SizedBox(height: 2.h),
                              Text(
                                intl.DateFormat('EEEE، d MMMM yyyy', 'ar')
                                    .format(_leaveDate),
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00695C)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: const Color(0xFF00695C)),
                      ],
                    ),
                  ),
                ),

                if (needsTime) ...[
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          label: 'من الساعة',
                          time: _fromTime,
                          onTap: () => _pickTime(true),
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'إلى الساعة',
                          time: _toTime,
                          onTap: () => _pickTime(false),
                          color: const Color(0xFF6A1B9A),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // السبب
          _buildCard(
            title: 'سبب الاستئذان',
            icon: Icons.edit_note,
            color: const Color(0xFF6A1B9A),
            child: TextField(
              controller: _reasonCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الاستئذان بوضوح...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                counterStyle: TextStyle(fontSize: 10.sp),
              ),
            ),
          ),

          SizedBox(height: 24.h),

          // زر الإرسال
          _buildSubmitButton(),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.access_time, color: color, size: 18.sp),
                SizedBox(width: 6.w),
                Text(
                  time != null ? _formatTime(time) : '--:--',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: time != null ? color : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _isSubmitting ? null : _submit,
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_rounded, color: Colors.white),
                      SizedBox(width: 10.w),
                      Text(
                        'إرسال طلب الاستئذان',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsTab(String schoolId, String teacherId) {
    if (schoolId.isEmpty || teacherId.isEmpty) {
      return const Center(child: Text('تعذّر تحميل البيانات'));
    }

    final stream = ref
        .watch(leaveRequestRepositoryProvider)
        .streamTeacherRequests(schoolId, teacherId);

    return StreamBuilder<List<LeaveRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: requests.length,
          itemBuilder: (_, i) => _buildRequestCard(requests[i]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72.sp, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text(
            'لا توجد طلبات بعد',
            style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          Text(
            'أرسل طلب استئذانك من تبويب "طلب جديد"',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest req) {
    final statusConfig = _statusConfig(req.status);
    final df = intl.DateFormat('d MMM yyyy', 'ar');

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusConfig['borderColor'] as Color),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: (statusConfig['bgColor'] as Color).withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: [
                Text(req.type.icon, style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.type.label,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        df.format(req.leaveDate),
                        style: TextStyle(
                            fontSize: 11.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(req.status),
              ],
            ),
          ),
          // تفاصيل
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (req.fromTime != null && req.toTime != null)
                  _buildDetailRow(
                      Icons.access_time, '${req.fromTime} - ${req.toTime}'),
                _buildDetailRow(Icons.notes, req.reason),
                if (req.deputyNote != null && req.deputyNote!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: (statusConfig['bgColor'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                          color: (statusConfig['bgColor'] as Color)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.comment,
                            size: 14.sp,
                            color: statusConfig['bgColor'] as Color),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'ملاحظة الوكيل: ${req.deputyNote}',
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: statusConfig['bgColor'] as Color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: Colors.grey.shade500),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LeaveStatus status) {
    final cfg = _statusConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: (cfg['bgColor'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: (cfg['bgColor'] as Color).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg['icon'] as IconData,
              size: 12.sp, color: cfg['bgColor'] as Color),
          SizedBox(width: 4.w),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: cfg['bgColor'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusConfig(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return {
          'bgColor': Colors.orange.shade600,
          'borderColor': Colors.orange.shade200,
          'icon': Icons.hourglass_top,
        };
      case LeaveStatus.approved:
        return {
          'bgColor': Colors.green.shade600,
          'borderColor': Colors.green.shade200,
          'icon': Icons.check_circle,
        };
      case LeaveStatus.rejected:
        return {
          'bgColor': Colors.red.shade600,
          'borderColor': Colors.red.shade200,
          'icon': Icons.cancel,
        };
    }
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16.sp),
                ),
                SizedBox(width: 10.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: child,
          ),
        ],
      ),
    );
  }
}
