import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/domain/models/school.dart';

class SchoolSubscriptionDialog extends StatefulWidget {
  final School school;
  const SchoolSubscriptionDialog({super.key, required this.school});

  @override
  State<SchoolSubscriptionDialog> createState() => _SchoolSubscriptionDialogState();
}

class _SchoolSubscriptionDialogState extends State<SchoolSubscriptionDialog> {
  late String _selectedPlan;
  late bool _showSubscriptionSection;
  String _durationType = 'keep';
  int _durationMonths = 1;
  bool _isSaving = false;

  static const _planColors = {
    'free': Color(0xFF757575),
    'starter': Color(0xFF26A69A),
    'smart': Color(0xFF1565C0),
    'elite': Color(0xFF6A1B9A),
  };

  static const _planNames = {
    'free': 'مجاني',
    'starter': 'Starter - الأساس',
    'smart': 'Professional - الذكية',
    'elite': 'Elite - التميز',
  };

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.school.subscriptionPlan;
    _showSubscriptionSection = widget.school.showSubscriptionSection;
    if (widget.school.isLifetimeAccess) _durationType = 'lifetime';
  }

  String _getStatusText() {
    if (widget.school.isLifetimeAccess) return 'مدى الحياة ♾️';
    final now = DateTime.now();
    if (widget.school.trialEndsAt != null) {
      if (widget.school.trialEndsAt!.isAfter(now)) {
        final days = widget.school.trialEndsAt!.difference(now).inDays;
        return 'تجريبي - متبقي $days يوم';
      }
      return 'انتهت التجربة';
    }
    if (widget.school.subscriptionEndsAt != null) {
      if (widget.school.subscriptionEndsAt!.isAfter(now)) {
        return 'نشط حتى ${DateFormat('yyyy/MM/dd').format(widget.school.subscriptionEndsAt!)}';
      }
      return 'منتهي الصلاحية';
    }
    return 'غير محدد';
  }

  Color _getStatusColor() {
    if (widget.school.isLifetimeAccess) return Colors.amber;
    final now = DateTime.now();
    if (widget.school.trialEndsAt?.isAfter(now) == true) return Colors.orange;
    if (widget.school.subscriptionEndsAt?.isAfter(now) == true) return Colors.green;
    return Colors.red;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> updates = {
        'subscriptionPlan': _selectedPlan,
        'showSubscriptionSection': _showSubscriptionSection,
        'isLifetimeAccess': _durationType == 'lifetime',
      };

      if (_durationType == 'trial') {
        updates['trialEndsAt'] = DateTime.now().add(const Duration(days: 30)).toIso8601String();
        updates['subscriptionEndsAt'] = null;
        updates['isLifetimeAccess'] = false;
      } else if (_durationType == 'monthly' || _durationType == 'yearly') {
        final now = DateTime.now();
        updates['subscriptionEndsAt'] = DateTime(now.year, now.month + _durationMonths, now.day).toIso8601String();
        updates['trialEndsAt'] = null;
        updates['isLifetimeAccess'] = false;
      } else if (_durationType == 'lifetime') {
        updates['isLifetimeAccess'] = true;
        updates['subscriptionEndsAt'] = null;
        updates['trialEndsAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.school.id)
          .update(updates);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الاشتراك بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 520.w, maxHeight: 680.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2A4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentInfo(),
                    SizedBox(height: 16.h),
                    _buildSectionLabel('تغيير الباقة'),
                    SizedBox(height: 8.h),
                    ...['free', 'starter', 'smart', 'elite'].map(_buildPlanTile),
                    SizedBox(height: 16.h),
                    _buildSectionLabel('تحديث المدة'),
                    SizedBox(height: 8.h),
                    _buildDurationSelector(),
                    SizedBox(height: 16.h),
                    _buildToggleTile(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.subscriptions, color: Colors.white, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة الاشتراك',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                Text(widget.school.name,
                    style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor().withValues(alpha: 0.5)),
            ),
            child: Text(_getStatusText(),
                style: TextStyle(color: _getStatusColor(), fontSize: 10.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentInfo() {
    final planColor = _planColors[widget.school.subscriptionPlan] ?? Colors.grey;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: planColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: planColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: planColor, size: 16.sp),
          SizedBox(width: 8.w),
          Text(
            'الباقة الحالية: ${_planNames[widget.school.subscriptionPlan] ?? widget.school.subscriptionPlan}',
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600));
  }

  Widget _buildPlanTile(String plan) {
    final isSelected = _selectedPlan == plan;
    final color = _planColors[plan] ?? Colors.grey;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: isSelected ? color : Colors.white24, size: 12.sp),
            SizedBox(width: 10.w),
            Text(_planNames[plan] ?? plan,
                style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 13.sp)),
            const Spacer(),
            if (isSelected) Icon(Icons.check, color: color, size: 16.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      children: [
        Row(
          children: [
            _chip('keep', 'إبقاء', Icons.lock_clock, Colors.grey),
            SizedBox(width: 6.w),
            _chip('trial', 'تجريبي', Icons.hourglass_top, const Color(0xFFFF8F00)),
            SizedBox(width: 6.w),
            _chip('monthly', 'شهري', Icons.calendar_month, const Color(0xFF1565C0)),
            SizedBox(width: 6.w),
            _chip('yearly', 'سنوي', Icons.calendar_today, const Color(0xFF2E7D32)),
            SizedBox(width: 6.w),
            _chip('lifetime', '♾️', Icons.all_inclusive, const Color(0xFF6A1B9A)),
          ],
        ),
        if (_durationType == 'monthly' || _durationType == 'yearly') ...[
          SizedBox(height: 10.h),
          Row(
            children: [
              Text('الأشهر:', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(width: 10.w),
              _counterBtn(Icons.remove, () {
                if (_durationMonths > 1) setState(() => _durationMonths--);
              }),
              SizedBox(width: 10.w),
              Text('$_durationMonths',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
              SizedBox(width: 10.w),
              _counterBtn(Icons.add, () => setState(() => _durationMonths++)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(String type, String label, IconData icon, Color color) {
    final isSelected = _durationType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _durationType = type;
          if (type == 'yearly') _durationMonths = 12;
          if (type == 'monthly') _durationMonths = 1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white38, size: 16.sp),
              SizedBox(height: 2.h),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.white38,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 14.sp),
      ),
    );
  }

  Widget _buildToggleTile() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility,
              color: _showSubscriptionSection ? const Color(0xFF26A69A) : Colors.white38,
              size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text('إظهار قسم الاشتراك للمدير',
                style: TextStyle(color: Colors.white, fontSize: 12.sp)),
          ),
          Switch(
            value: _showSubscriptionSection,
            onChanged: (v) => setState(() => _showSubscriptionSection = v),
            activeColor: const Color(0xFF26A69A),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إلغاء'),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
