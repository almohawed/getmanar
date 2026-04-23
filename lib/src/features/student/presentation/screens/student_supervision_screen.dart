import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../../deputy/presentation/student_affairs_providers.dart';
import '../../../auth/presentation/auth_controller.dart';

// ==============================================================================
// Student Supervision Module - الإشراف اليومي
// ==============================================================================
class StudentSupervisionModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const StudentSupervisionModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    
    // 🔥 الحل الجذري: استخدام when() مع StreamProvider
    return ref.watch(studentSupervisionStreamProvider).when(
      data: (all) => _buildSupervisionScreen(context, ref, user, schoolId, all),
      loading: () => UnifiedPageScaffold(
        requiredDeputyType: 'student',
        showAppBar: false,
        title: 'الإشراف اليومي',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => UnifiedPageScaffold(
        requiredDeputyType: 'student',
        showAppBar: false,
        title: 'الإشراف اليومي',
        body: Center(
          child: Text('خطأ: $error'),
        ),
      ),
    );
  }

  Widget _buildSupervisionScreen(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    String schoolId,
    List<Map<String, dynamic>> all,
  ) {
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    String type;
    String title;
    String description;
    IconData icon;
    switch (initialIndex) {
      case 1:
        type = 'recess';
        title = 'متابعة الفسحة';
        description =
            'رصد سلوك الطلاب أثناء الفسحة وتنظيم المناوبات اليومية للمعلمين.';
        icon = Icons.fastfood;
        break;
      case 2:
        type = 'prayer';
        title = 'متابعة الصلاة';
        description =
            'متابعة التزام الطلاب بأداء الصلاة وتنظيم الأدوار في المصلى.';
        icon = Icons.mosque;
        break;
      case 3:
        type = 'dismissal';
        title = 'متابعة الانصراف';
        description =
            'متابعة تنظيم خروج الطلاب وضمان سلامة حافلات النقل المدرسي.';
        icon = Icons.exit_to_app;
        break;
      case 4:
        type = 'immediate';
        title = 'بلاغ فوري';
        description =
            'إرسال بلاغات فورية عن الحالات الطارئة داخل المدرسة ومحيطها.';
        icon = Icons.report_problem;
        break;
      case 0:
      default:
        type = 'assembly';
        title = 'متابعة الاصطفاف';
        description =
            'متابعة انتظام الطابور الصباحي وتوثيق الملاحظات على الفصول.';
        icon = Icons.groups;
        break;
    }

    final list = all
        .where((r) => (r['type'] ?? '').toString() == type)
        .toList();
    final todayList = list
        .where((r) => (r['dateKey'] ?? '').toString() == todayKey)
        .toList();
    final openToday = todayList.where((r) {
      return (r['status'] ?? '').toString().toLowerCase() != 'closed';
    }).length;
    final pointsToday = todayList.length;
    final coverage = pointsToday > 0 ? 'مغطي' : 'غير مغطي';

    return UnifiedPageScaffold(
      requiredDeputyType: 'student',
      showAppBar: false,
      title: title,
      floatingActionButton: schoolId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await _showSupervisionDialog(context, schoolId, user, type);
              },
              icon: const Icon(Icons.add),
              label: Text(type == 'immediate' ? 'بلاغ' : 'تسجيل'),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudentModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: Colors.blue,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _StudentMetricCard(
                      label: 'نقاط الإشراف اليوم',
                      value: pointsToday.toString(),
                      icon: Icons.star_rate,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _StudentMetricCard(
                      label: 'بلاغات مسجلة',
                      value: openToday.toString(),
                      icon: Icons.report,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _StudentMetricCard(
                      label: 'مناوبات مفعلة',
                      value: coverage,
                      icon: Icons.schedule,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _buildSupervisionList(context, schoolId, list, type, icon, user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupervisionList(
    BuildContext context,
    String schoolId,
    List<Map<String, dynamic>> list,
    String type,
    IconData icon,
    dynamic user,
  ) {
    if (schoolId.isEmpty) {
      return Center(
        child: Text(
          'لا يمكن عرض البيانات بدون مدرسة مرتبطة بالحساب.',
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Text(
          'لا توجد سجلات إشراف لهذا القسم.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13.sp,
          ),
        ),
      );
    }

    list.sort((a, b) {
      final aDt = (a['date'] is Timestamp)
          ? (a['date'] as Timestamp).toDate()
          : ((a['createdAt'] is Timestamp)
                ? (a['createdAt'] as Timestamp).toDate()
                : null);
      final bDt = (b['date'] is Timestamp)
          ? (b['date'] as Timestamp).toDate()
          : ((b['createdAt'] is Timestamp)
                ? (b['createdAt'] as Timestamp).toDate()
                : null);
      if (aDt == null || bDt == null) return 0;
      return bDt.compareTo(aDt);
    });

    return ListView.separated(
      itemCount: list.length.clamp(0, 250),
      separatorBuilder: (_, __) =>
          Divider(height: 12.h, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final r = list[index];
        final id = (r['id'] ?? '').toString().trim();
        final status = (r['status'] ?? '').toString().toLowerCase();
        final isClosed = status == 'closed';
        final dt = (r['date'] is Timestamp)
            ? (r['date'] as Timestamp).toDate()
            : null;
        final dateStr = dt == null
            ? '—'
            : DateFormat('yyyy-MM-dd').format(dt);
        final sev = (r['severity'] ?? '').toString().toLowerCase();
        final sevColor = (sev == 'urgent' || sev == 'high')
            ? Colors.red
            : sev == 'medium'
            ? Colors.orange
            : Colors.blueGrey;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: sevColor.withValues(alpha: 0.12),
            child: Icon(
              type == 'immediate' ? Icons.report : icon,
              color: sevColor,
            ),
          ),
          title: Text(
            (r['title'] ?? '').toString().trim().isEmpty
                ? '—'
                : (r['title'] ?? '').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              dateStr,
              (r['location'] ?? '').toString().trim(),
              isClosed ? 'مغلق' : 'مفتوح',
            ].where((s) => s.isNotEmpty).join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isClosed
              ? Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'مغلق',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => _closeSupervisionItem(context, schoolId, id, user),
                  child: const Text('إغلاق'),
                ),
        );
      },
    );
  }

  Future<void> _showSupervisionDialog(
    BuildContext context,
    String schoolId,
    dynamic user,
    String type,
  ) async {
    DateTime date = DateTime.now();
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String severity = type == 'immediate' ? 'high' : 'low';
    String status = 'open';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                type == 'immediate' ? 'بلاغ فوري' : 'تسجيل إشراف',
              ),
              content: SizedBox(
                width: 460.w,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('التاريخ'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(date),
                        ),
                        trailing: const Icon(Icons.date_range),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => date = picked);
                          }
                        },
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: type == 'immediate'
                              ? 'عنوان البلاغ'
                              : 'الملاحظة',
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الموقع (اختياري)',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        value: severity,
                        items: const [
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('منخفضة'),
                          ),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('متوسطة'),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('عالية'),
                          ),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('عاجلة'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          severity = v ?? 'low';
                        }),
                        decoration: const InputDecoration(
                          labelText: 'الخطورة',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('مفتوح'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('مغلق'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          status = v ?? 'open';
                        }),
                        decoration: const InputDecoration(
                          labelText: 'الحالة',
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'تفاصيل/إجراء (اختياري)',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    final mainTitle = titleCtrl.text.trim();
    if (mainTitle.isEmpty) return;
    
    final id = const Uuid().v4();
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentSupervision')
          .doc(id)
          .set({
            'type': type,
            'date': Timestamp.fromDate(date),
            'dateKey': dateKey,
            'title': mainTitle,
            'location': locationCtrl.text.trim(),
            'severity': severity,
            'status': status,
            'notes': notesCtrl.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'createdById': user?.id,
            'createdByName': user?.name,
          });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _closeSupervisionItem(
    BuildContext context,
    String schoolId,
    String id,
    dynamic user,
  ) async {
    if (id.isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentSupervision')
          .doc(id)
          .set({
            'status': 'closed',
            'closedAt': FieldValue.serverTimestamp(),
            'closedById': user?.id,
            'closedByName': user?.name,
          }, SetOptions(merge: true));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إغلاق البلاغ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في الإغلاق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Helper Widgets
class _StudentModuleHeader extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _StudentModuleHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? suffix;

  const _StudentMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  if (suffix != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      suffix!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}