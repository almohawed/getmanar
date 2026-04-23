import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/presentation/smart_section_scaffold.dart';

class DevelopmentPlansScreen extends ConsumerStatefulWidget {
  const DevelopmentPlansScreen({super.key});

  @override
  ConsumerState<DevelopmentPlansScreen> createState() =>
      _DevelopmentPlansScreenState();
}

class _DevelopmentPlansScreenState extends ConsumerState<DevelopmentPlansScreen> {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'غير محدد';
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _createPlan(BuildContext context, String schoolId) async {
    final titleController = TextEditingController();
    final ownerController = TextEditingController(
      text: ref.read(authStateProvider).value?.name ?? '',
    );
    DateTime? startDate;
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة خطة تطويرية', style: TextStyle(fontSize: 16.sp)),
        content: SizedBox(
          width: 420.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الخطة',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(
                  labelText: 'المسؤول',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: startDate ?? DateTime.now(),
                        );
                        if (picked == null) return;
                        setState(() => startDate = picked);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text('البداية: ${_formatDate(startDate)}'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: endDate ?? DateTime.now(),
                        );
                        if (picked == null) return;
                        setState(() => endDate = picked);
                      },
                      icon: const Icon(Icons.event),
                      label: Text('النهاية: ${_formatDate(endDate)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final owner = ownerController.text.trim();
              if (title.isEmpty) return;
              final doc = _firestore
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('DevelopmentPlans')
                  .doc();
              await doc.set({
                'title': title,
                'owner': owner,
                'status': 'active',
                'progress': 0.0,
                'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
                'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProgress(
    BuildContext context,
    String schoolId,
    String planId,
    double current,
  ) async {
    double v = current.clamp(0.0, 1.0);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحديث التقدم', style: TextStyle(fontSize: 16.sp)),
        content: StatefulBuilder(
          builder: (context, setLocal) => SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: v,
                  onChanged: (nv) => setLocal(() => v = nv),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('DevelopmentPlans')
                  .doc(planId)
                  .set(
                {
                  'progress': v,
                  'status': v >= 0.999 ? 'completed' : 'active',
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _closePlan(
    BuildContext context,
    String schoolId,
    String planId,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DevelopmentPlans')
        .doc(planId)
        .set(
      {
        'status': 'completed',
        'progress': 1.0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق الخطة بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    const themeColor = Color(0xFF0B6E4F);

    if (schoolId.isEmpty) {
      return SmartSectionScaffold(
        title: 'الخطط التطويرية',
        icon: Icons.trending_up,
        themeColor: themeColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final plansStream = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('DevelopmentPlans')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return SmartSectionScaffold(
      title: 'الخطط التطويرية',
      icon: Icons.trending_up,
      themeColor: themeColor,
      initialRecommendation: 'تابع مؤشرات التنفيذ أسبوعيًا، وثبّت خطة واحدة على الأقل ذات أثر مباشر على التحصيل والانضباط.',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        onPressed: () => _createPlan(context, schoolId),
        icon: const Icon(Icons.add),
        label: const Text('إضافة خطة'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: plansStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final now = DateTime.now();

          int active = 0;
          int completed = 0;
          int overdue = 0;
          double progressSum = 0.0;

          for (final d in docs) {
            final m = d.data();
            final status = (m['status'] ?? 'active').toString();
            final p = (m['progress'] is num) ? (m['progress'] as num).toDouble() : 0.0;
            progressSum += p.clamp(0.0, 1.0);
            if (status == 'completed') {
              completed += 1;
            } else {
              active += 1;
              final endTs = m['endDate'];
              final endDate = endTs is Timestamp ? endTs.toDate() : null;
              if (endDate != null && endDate.isBefore(DateTime(now.year, now.month, now.day))) {
                overdue += 1;
              }
            }
          }

          final avgProgress = docs.isEmpty ? 0.0 : (progressSum / docs.length);
          final recommendation = overdue > 0
              ? 'يوجد $overdue خطط متأخرة عن موعدها. راجع الخطة الأعلى أولوية وحدد إجراءات أسبوعية قصيرة.'
              : (active == 0
                  ? 'لا توجد خطط نشطة. ابدأ بخطة واحدة مرتبطة بمؤشر قابل للقياس.'
                  : 'الوتيرة جيدة. ركّز على رفع متوسط التقدم إلى ${(avgProgress * 100).round()}% خلال الفترة القادمة.');

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryStrip(
                  themeColor: themeColor,
                  active: active,
                  completed: completed,
                  overdue: overdue,
                  avgProgress: avgProgress,
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: themeColor.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.auto_awesome, color: themeColor, size: 22.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey.shade800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'قائمة الخطط',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                SizedBox(height: 10.h),
                if (docs.isEmpty)
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      'لا توجد خطط مسجلة بعد.',
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                    ),
                  )
                else
                  ...docs.map((d) {
                    final m = d.data();
                    final title = (m['title'] ?? 'خطة').toString();
                    final owner = (m['owner'] ?? '').toString();
                    final status = (m['status'] ?? 'active').toString();
                    final p = (m['progress'] is num) ? (m['progress'] as num).toDouble() : 0.0;
                    final startTs = m['startDate'];
                    final endTs = m['endDate'];
                    final start = startTs is Timestamp ? startTs.toDate() : null;
                    final end = endTs is Timestamp ? endTs.toDate() : null;

                    final badgeColor = status == 'completed' ? Colors.green : themeColor;
                    final badgeText = status == 'completed' ? 'مكتملة' : 'نشطة';

                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: badgeColor.withOpacity(0.35)),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (owner.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'المسؤول: $owner',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                            ),
                          ],
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'التقدم: ${(p.clamp(0.0, 1.0) * 100).round()}%',
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
                              ),
                              Text(
                                '${_formatDate(start)} → ${_formatDate(end)}',
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          LinearProgressIndicator(
                            value: p.clamp(0.0, 1.0),
                            minHeight: 7.h,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation(badgeColor),
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _updateProgress(context, schoolId, d.id, p),
                                  icon: const Icon(Icons.tune),
                                  label: const Text('تحديث التقدم'),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: status == 'completed'
                                      ? null
                                      : () => _closePlan(context, schoolId, d.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: badgeColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('إغلاق'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final Color themeColor;
  final int active;
  final int completed;
  final int overdue;
  final double avgProgress;

  const _SummaryStrip({
    required this.themeColor,
    required this.active,
    required this.completed,
    required this.overdue,
    required this.avgProgress,
  });

  @override
  Widget build(BuildContext context) {
    Widget card(String title, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 18.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card('نشطة', '$active', Icons.play_circle_fill, themeColor),
        SizedBox(width: 10.w),
        card('مكتملة', '$completed', Icons.task_alt, Colors.green),
        SizedBox(width: 10.w),
        card('متأخرة', '$overdue', Icons.warning_amber_rounded, Colors.red),
        SizedBox(width: 10.w),
        card(
          'متوسط التقدم',
          '${(avgProgress.clamp(0.0, 1.0) * 100).round()}%',
          Icons.trending_up,
          Colors.blue,
        ),
      ],
    );
  }
}
