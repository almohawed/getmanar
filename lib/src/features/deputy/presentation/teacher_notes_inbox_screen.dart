import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';

final _teacherNameByIdProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, teacherId) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (teacherId.trim().isEmpty || schoolId.isEmpty) return null;

      final firestore = FirebaseFirestore.instance;

      Future<String?> readName(String col) async {
        final doc = await firestore
            .collection('Schools')
            .doc(schoolId)
            .collection(col)
            .doc(teacherId)
            .get();
        final data = doc.data();
        if (data == null) return null;
        final name = (data['name'] ?? '').toString().trim();
        return name.isEmpty ? null : name;
      }

      try {
        return await readName('Teachers') ??
            await readName('Staff') ??
            await readName('Users');
      } catch (_) {
        return null;
      }
    });

final _studentNameByIdProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, studentId) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (studentId.trim().isEmpty || schoolId.isEmpty) return null;

      final firestore = FirebaseFirestore.instance;
      try {
        final doc = await firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .doc(studentId)
            .get();
        final data = doc.data();
        if (data == null) return null;
        final name = (data['name'] ?? '').toString().trim();
        return name.isEmpty ? null : name;
      } catch (_) {
        return null;
      }
    });

class TeacherNotesInboxScreen extends ConsumerWidget {
  const TeacherNotesInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(pendingTeacherNotesProvider);
    final inboxCount = inboxAsync.value?.length ?? 0;
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    return UnifiedPageScaffold(
      title: 'وارد المعلمين',
      subtitle: 'ملاحظات صفية واردة تحتاج اعتماد الوكيل',
      allowedRoles: const [UserRole.deputy],
      showAppBar: false,
      body: inboxAsync.when(
        data: (records) {
          final currentUser = ref.watch(authStateProvider).value;
          final schoolId = (currentUser?.schoolId ?? '').trim();

          Future<void> notifyTeacher({
            required BehaviorRecord r,
            required bool approved,
            String? reason,
          }) async {
            if (schoolId.isEmpty || r.teacherId.trim().isEmpty) return;
            final title = approved ? 'تم اعتماد ملاحظتك' : 'تم رفض ملاحظتك';
            final studentName = (r.studentName ?? '').toString().trim();
            final base = studentName.isEmpty ? 'الطالب' : 'الطالب $studentName';
            final body = approved
                ? 'تم اعتماد الملاحظة الخاصة بـ $base.'
                : [
                    'تم رفض الملاحظة الخاصة بـ $base.',
                    if ((reason ?? '').trim().isNotEmpty)
                      'السبب: ${reason!.trim()}',
                  ].join('\n');

            final notificationRepo = ref.read(notificationRepositoryProvider);
            await notificationRepo.sendNotification(
              NotificationRecord(
                id: const Uuid().v4(),
                userId: r.teacherId,
                schoolId: schoolId,
                title: title,
                body: body,
                timestamp: DateTime.now(),
                route: '/notifications',
                data: {
                  'recordId': r.id,
                  'status': approved ? 'approved' : 'rejected',
                  'studentId': r.studentId,
                  'studentName': r.studentName ?? '',
                },
              ),
            );
          }

          Future<void> approve(BehaviorRecord r) async {
            final repo = ref.read(behaviorRepositoryProvider);
            await repo.updateBehaviorRecord(
              r.copyWith(
                status: BehaviorStatus.approved,
                rejectionReason: null,
              ),
            );
            await notifyTeacher(r: r, approved: true);
          }

          Future<void> reject(BehaviorRecord r) async {
            final reasonCtrl = TextEditingController();
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text('رفض الملاحظة'),
                  content: TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'سبب الرفض (اختياري)',
                    ),
                    maxLines: 2,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('رفض'),
                    ),
                  ],
                );
              },
            );
            if (ok != true) return;
            final repo = ref.read(behaviorRepositoryProvider);
            final reason = reasonCtrl.text.trim();
            await repo.updateBehaviorRecord(
              r.copyWith(
                status: BehaviorStatus.rejected,
                rejectionReason: reason,
              ),
            );
            await notifyTeacher(r: r, approved: false, reason: reason);
          }

          final header = Container(
            margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.blue.shade600],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: const Icon(Icons.inbox, color: Colors.white),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وارد المعلمين',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'اليوم $todayKey • بانتظار الاعتماد: $inboxCount',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'العودة للوحة الوكيل',
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ],
            ),
          );

          if (records.isEmpty) {
            return SafeArea(
              child: Column(
                children: [
                  header,
                  const Expanded(
                    child: UnifiedEmptyState(
                      message: 'لا توجد ملاحظات واردة الآن',
                      icon: Icons.inbox,
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                header,
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {},
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                      itemCount: records.length.clamp(0, 200),
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final r = records[index];
                        final rawStudentName = (r.studentName ?? '')
                            .toString()
                            .trim();
                        final className = (r.className ?? '').toString().trim();
                        final dtStr = DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(r.timestamp);

                        final resolvedStudentName = rawStudentName.isNotEmpty
                            ? AsyncValue.data(rawStudentName)
                            : ref.watch(_studentNameByIdProvider(r.studentId));
                        final title =
                            (resolvedStudentName.value?.trim().isNotEmpty ??
                                false)
                            ? resolvedStudentName.value!.trim()
                            : 'طالب غير معروف';

                        final teacherName = (r.teacherName ?? '')
                            .toString()
                            .trim();
                        final teacherResolved = teacherName.isNotEmpty
                            ? AsyncValue.data(teacherName)
                            : ref.watch(_teacherNameByIdProvider(r.teacherId));
                        final teacherLabel =
                            teacherResolved.value?.trim().isNotEmpty ?? false
                            ? teacherResolved.value!.trim()
                            : 'غير معروف';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.indigo.withValues(
                                        alpha: 0.10,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.sp,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            [
                                              'المعلم: $teacherLabel',
                                              if (className.isNotEmpty)
                                                'الفصل: $className',
                                            ].join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                      ),
                                      child: Text(
                                        'قيد الاعتماد',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    r.description,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey.shade900,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        dtStr,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) {
                                            return AlertDialog(
                                              title: const Text(
                                                'تفاصيل الملاحظة',
                                              ),
                                              content: SizedBox(
                                                width: 460.w,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text('الطالب: $title'),
                                                    Text(
                                                      'المعلم: $teacherLabel',
                                                    ),
                                                    if (className.isNotEmpty)
                                                      Text('الفصل: $className'),
                                                    Text('التاريخ: $dtStr'),
                                                    SizedBox(height: 10.h),
                                                    Text(r.description),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('إغلاق'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(null),
                                                  child: const Text('رفض'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: const Text('اعتماد'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (ok == true) {
                                          await approve(r);
                                        } else if (ok == null) {
                                          await reject(r);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text('عرض'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await reject(r);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تم رفض الملاحظة',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          } catch (_) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تعذر رفض الملاحظة الآن',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.close),
                                        label: const Text('رفض'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await approve(r);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تم اعتماد الملاحظة',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          } catch (_) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تعذر اعتماد الملاحظة الآن',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.check),
                                        label: const Text('اعتماد'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'تعذر تحميل الوارد.\n$e',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 13.sp),
          ),
        ),
      ),
    );
  }
}
