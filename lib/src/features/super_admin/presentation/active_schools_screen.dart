/// active_schools_screen.dart
/// المدارس المفعّلة مع التحكم في إظهار/إخفاء قسم الاشتراك
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ActiveSchoolsScreen extends StatefulWidget {
  const ActiveSchoolsScreen({super.key});
  @override
  State<ActiveSchoolsScreen> createState() => _ActiveSchoolsScreenState();
}

class _ActiveSchoolsScreenState extends State<ActiveSchoolsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('المدارس المفعّلة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث باسم المدرسة...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Schools')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          var docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            // فقط المدارس المفعّلة (لها subscriptionPlan أو isLifetimeAccess)
            final plan = (data['subscriptionPlan'] ?? '').toString();
            final lifetime = data['isLifetimeAccess'] == true;
            final hasName = (data['name'] ?? '').toString().isNotEmpty;
            return hasName && (plan.isNotEmpty || lifetime);
          }).toList();

          if (_search.isNotEmpty) {
            docs = docs.where((d) {
              final name = ((d.data() as Map)['name'] ?? '').toString();
              return name.contains(_search);
            }).toList();
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_outlined, size: 64.sp, color: Colors.white24),
                SizedBox(height: 12.h),
                Text('لا توجد مدارس مفعّلة',
                    style: TextStyle(color: Colors.white38, fontSize: 16.sp)),
              ]),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: docs.length,
            itemBuilder: (context, i) => _SchoolCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _SchoolCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'مدرسة').toString();
    final plan = (data['subscriptionPlan'] ?? 'غير محدد').toString();
    final lifetime = data['isLifetimeAccess'] == true;
    final showSub = data['showSubscriptionSection'] != false; // افتراضي: ظاهر
    final city = (data['city'] ?? '').toString();
    final stage = (data['stage'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        leading: Container(
          width: 48.w, height: 48.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: lifetime
                  ? [const Color(0xFF00695C), const Color(0xFF00897B)]
                  : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.school_rounded, color: Colors.white, size: 22.sp),
        ),
        title: Text(name,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Row(children: [
              if (city.isNotEmpty) ...[
                Icon(Icons.location_on, size: 11.sp, color: Colors.white38),
                SizedBox(width: 3.w),
                Text(city, style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                SizedBox(width: 8.w),
              ],
              if (stage.isNotEmpty)
                Text(stage, style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
            ]),
            SizedBox(height: 4.h),
            Row(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: lifetime
                      ? Colors.teal.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  lifetime ? 'مدى الحياة' : plan,
                  style: TextStyle(
                    color: lifetime ? Colors.tealAccent : Colors.lightBlueAccent,
                    fontSize: 10.sp, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: 8.w),
              // حالة قسم الاشتراك
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: showSub
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(showSub ? Icons.visibility : Icons.visibility_off,
                      size: 10.sp,
                      color: showSub ? Colors.greenAccent : Colors.redAccent),
                  SizedBox(width: 3.w),
                  Text(
                    showSub ? 'قسم الاشتراك ظاهر' : 'قسم الاشتراك مخفي',
                    style: TextStyle(
                      color: showSub ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10.sp),
                  ),
                ]),
              ),
            ]),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.settings_rounded, color: Colors.white54, size: 20.sp),
          tooltip: 'إعدادات المدرسة',
          onPressed: () => _showSchoolSettings(context, doc.id, name, showSub),
        ),
        onTap: () => _showSchoolSettings(context, doc.id, name, showSub),
      ),
    );
  }

  void _showSchoolSettings(
      BuildContext context, String schoolId, String schoolName, bool currentShowSub) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _SchoolSettingsSheet(
        schoolId: schoolId,
        schoolName: schoolName,
        showSubscriptionSection: currentShowSub,
      ),
    );
  }
}

class _SchoolSettingsSheet extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final bool showSubscriptionSection;
  const _SchoolSettingsSheet({
    required this.schoolId,
    required this.schoolName,
    required this.showSubscriptionSection,
  });
  @override
  State<_SchoolSettingsSheet> createState() => _SchoolSettingsSheetState();
}

class _SchoolSettingsSheetState extends State<_SchoolSettingsSheet> {
  late bool _showSub;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _showSub = widget.showSubscriptionSection;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .update({'showSubscriptionSection': _showSub});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_showSub
              ? '✅ تم إظهار قسم الاشتراك للمدير'
              : '✅ تم إخفاء قسم الاشتراك من لوحة المدير'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40.w, height: 4.h,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(height: 20.h),
        // Title
        Row(children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.school_rounded, color: Colors.tealAccent, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.schoolName,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('إعدادات المدرسة',
                style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
          ])),
        ]),
        SizedBox(height: 24.h),
        // Toggle card
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: _showSub
                  ? Colors.teal.withOpacity(0.4)
                  : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: _showSub
                    ? Colors.teal.withOpacity(0.15)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                _showSub ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: _showSub ? Colors.tealAccent : Colors.redAccent,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'قسم الاشتراك في لوحة المدير',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.sp),
              ),
              SizedBox(height: 3.h),
              Text(
                _showSub
                    ? 'ظاهر حالياً — المدير يرى خيارات الترقية'
                    : 'مخفي حالياً — لا يظهر في لوحة المدير',
                style: TextStyle(
                  color: _showSub ? Colors.tealAccent : Colors.redAccent,
                  fontSize: 11.sp,
                ),
              ),
            ])),
            Switch(
              value: _showSub,
              onChanged: (v) => setState(() => _showSub = v),
              activeColor: Colors.tealAccent,
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
          ]),
        ),
        SizedBox(height: 8.h),
        // Info
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 14.sp),
            SizedBox(width: 8.w),
            Expanded(child: Text(
              'عند الإخفاء، لن يرى مدير المدرسة قسم الاشتراك في لوحته.',
              style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11.sp),
            )),
          ]),
        ),
        SizedBox(height: 20.h),
        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(width: 16.w, height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'جاري الحفظ...' : 'حفظ التغييرات',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ),
      ]),
    );
  }
}
