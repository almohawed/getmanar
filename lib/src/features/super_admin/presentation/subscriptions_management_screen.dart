import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/school.dart';
import 'schools_list_screen.dart';
import '../../subscription/domain/subscription_logic.dart';
import 'widgets/school_subscription_dialog.dart';

class SubscriptionsManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionsManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionsManagementScreen> createState() =>
      _SubscriptionsManagementScreenState();
}

class _SubscriptionsManagementScreenState
    extends ConsumerState<SubscriptionsManagementScreen> {
  String _filterPlan = 'all';
  String _filterStatus = 'all';
  String _searchQuery = '';

  static const _planColors = {
    'free': Color(0xFF757575),
    'starter': Color(0xFF26A69A),
    'smart': Color(0xFF1565C0),
    'elite': Color(0xFF6A1B9A),
  };

  static const _planNames = {
    'free': 'مجاني',
    'starter': 'Starter',
    'smart': 'Professional',
    'elite': 'Elite',
  };

  String _getStatus(School school) {
    if (school.isLifetimeAccess) return 'lifetime';
    final now = DateTime.now();
    if (school.trialEndsAt != null) {
      return school.trialEndsAt!.isAfter(now) ? 'trial' : 'expired';
    }
    if (school.subscriptionEndsAt != null) {
      return school.subscriptionEndsAt!.isAfter(now) ? 'active' : 'expired';
    }
    return 'none';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'lifetime': return 'مدى الحياة';
      case 'trial': return 'تجريبي';
      case 'active': return 'نشط';
      case 'expired': return 'منتهي';
      case 'none': return 'غير محدد';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'lifetime': return Colors.amber;
      case 'trial': return Colors.orange;
      case 'active': return Colors.green;
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }

  List<School> _filterSchools(List<School> schools) {
    return schools.where((s) {
      final matchPlan = _filterPlan == 'all' || s.subscriptionPlan == _filterPlan;
      final status = _getStatus(s);
      final matchStatus = _filterStatus == 'all' || status == _filterStatus;
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchPlan && matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(schoolsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة الاشتراكات',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
            Text('التحكم في باقات المدارس',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: schoolsAsync.when(
        data: (schools) {
          final filtered = _filterSchools(schools);
          return Column(
            children: [
              _buildStatsBar(schools),
              _buildFilters(),
              _buildSearchBar(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: EdgeInsets.all(12.w),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildSchoolCard(filtered[i]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildStatsBar(List<School> schools) {
    final now = DateTime.now();
    final active = schools.where((s) =>
        s.isLifetimeAccess ||
        (s.subscriptionEndsAt?.isAfter(now) == true) ||
        (s.trialEndsAt?.isAfter(now) == true)).length;
    final expired = schools.where((s) =>
        !s.isLifetimeAccess &&
        (s.subscriptionEndsAt?.isBefore(now) == true ||
         s.trialEndsAt?.isBefore(now) == true)).length;
    final elite = schools.where((s) => s.subscriptionPlan == 'elite').length;
    final smart = schools.where((s) => s.subscriptionPlan == 'smart').length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B2A4A)],
        ),
      ),
      child: Row(
        children: [
          _statChip('الكل', schools.length.toString(), Colors.white54),
          SizedBox(width: 8.w),
          _statChip('نشط', active.toString(), Colors.green),
          SizedBox(width: 8.w),
          _statChip('منتهي', expired.toString(), Colors.red),
          SizedBox(width: 8.w),
          _statChip('Elite', elite.toString(), const Color(0xFF6A1B9A)),
          SizedBox(width: 8.w),
          _statChip('Pro', smart.toString(), const Color(0xFF1565C0)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16.sp)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          _filterChip('all', 'الكل', Colors.white54, isPlan: false),
          SizedBox(width: 6.w),
          _filterChip('active', 'نشط', Colors.green, isPlan: false),
          SizedBox(width: 6.w),
          _filterChip('trial', 'تجريبي', Colors.orange, isPlan: false),
          SizedBox(width: 6.w),
          _filterChip('expired', 'منتهي', Colors.red, isPlan: false),
          SizedBox(width: 6.w),
          _filterChip('lifetime', 'مدى الحياة', Colors.amber, isPlan: false),
          SizedBox(width: 16.w),
          _filterChip('all', 'كل الباقات', Colors.white54, isPlan: true),
          SizedBox(width: 6.w),
          _filterChip('free', 'مجاني', Colors.grey, isPlan: true),
          SizedBox(width: 6.w),
          _filterChip('starter', 'Starter', const Color(0xFF26A69A), isPlan: true),
          SizedBox(width: 6.w),
          _filterChip('smart', 'Pro', const Color(0xFF1565C0), isPlan: true),
          SizedBox(width: 6.w),
          _filterChip('elite', 'Elite', const Color(0xFF6A1B9A), isPlan: true),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, Color color, {required bool isPlan}) {
    final current = isPlan ? _filterPlan : _filterStatus;
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => setState(() {
        if (isPlan) _filterPlan = value;
        else _filterStatus = value;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white38, fontSize: 11.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'بحث باسم المدرسة أو المدينة...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }

  Widget _buildSchoolCard(School school) {
    final status = _getStatus(school);
    final statusColor = _getStatusColor(status);
    final planColor = _planColors[school.subscriptionPlan] ?? Colors.grey;
    final endsAt = school.subscriptionEndsAt ?? school.trialEndsAt;
    final now = DateTime.now();
    final daysLeft = endsAt != null ? endsAt.difference(now).inDays : null;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: planColor, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(school.name,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                          overflow: TextOverflow.ellipsis),
                      Text('${school.city} • ${school.stage}',
                          style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                    ],
                  ),
                ),
                // Plan badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: planColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(_planNames[school.subscriptionPlan] ?? school.subscriptionPlan,
                      style: TextStyle(color: planColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 6.w),
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(_getStatusLabel(status),
                      style: TextStyle(color: statusColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            if (endsAt != null || school.isLifetimeAccess) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.white38, size: 13.sp),
                  SizedBox(width: 4.w),
                  if (school.isLifetimeAccess)
                    Text('مدى الحياة - بدون انتهاء', style: TextStyle(color: Colors.amber, fontSize: 11.sp))
                  else if (endsAt != null) ...[
                    Text(
                      status == 'trial' ? 'التجربة تنتهي: ' : 'الاشتراك ينتهي: ',
                      style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                    ),
                    Text(
                      DateFormat('yyyy/MM/dd').format(endsAt),
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                    if (daysLeft != null && daysLeft >= 0) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: (daysLeft < 7 ? Colors.red : daysLeft < 30 ? Colors.orange : Colors.green).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$daysLeft يوم',
                          style: TextStyle(
                            color: daysLeft < 7 ? Colors.red : daysLeft < 30 ? Colors.orange : Colors.green,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],

            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => SchoolSubscriptionDialog(school: school),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                    ),
                  ),
                  icon: Icon(Icons.edit, size: 14.sp),
                  label: Text('تعديل الاشتراك', style: TextStyle(fontSize: 12.sp)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.white24, size: 48.sp),
          SizedBox(height: 12.h),
          Text('لا توجد مدارس مطابقة', style: TextStyle(color: Colors.white38, fontSize: 14.sp)),
        ],
      ),
    );
  }
}
