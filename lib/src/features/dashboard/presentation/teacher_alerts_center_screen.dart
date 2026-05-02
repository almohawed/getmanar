import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../wait_management/data/mock_wait_repository.dart';
import '../../behavior/presentation/behavior_controller.dart';

// ─── Helper ───────────────────────────────────────────────────────────────────
String _todayArabicName() {
  final days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس', 'الجمعة', 'السبت'];
  return days[DateTime.now().weekday % 7];
}

String _normalizeD(String s) => s
    .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه').replaceAll('ى', 'ي').trim();

// ─── Provider: حصص انتظار المعلم — إشعار واحد فقط لليوم ─────────────────────
final teacherWaitsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) async {
  if (teacherId.isEmpty) return [];
  final user = ref.read(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return [];

  try {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay   = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    // نجلب إشعارات اليوم فقط — بحقل date أو بـ Timestamp
    QuerySnapshot snap;
    try {
      // محاولة البحث بحقل date (الإشعارات الجديدة)
      snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('Notifications')
          .where('userId', isEqualTo: teacherId)
          .where('date', isEqualTo: dateKey)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
    } catch (_) {
      snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('Notifications')
          .where('userId', isEqualTo: teacherId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
    }

    // نأخذ أحدث إشعار تكليف انتظار لليوم فقط
    DocumentSnapshot? latestDoc;
    for (final doc in snap.docs) {
      final data  = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString();
      if (!title.contains('تكليف انتظار')) continue;

      // تحقق التاريخ للإشعارات القديمة (بدون حقل date)
      final dateField = (data['date'] ?? '').toString();
      if (dateField.isEmpty) {
        final ts = data['timestamp'];
        if (ts is Timestamp) {
          if (ts.compareTo(startOfDay) < 0 || ts.compareTo(endOfDay) > 0) continue;
        } else if (ts is String) {
          final parsed = DateTime.tryParse(ts);
          if (parsed == null) continue;
          final d = '${parsed.year}-${parsed.month.toString().padLeft(2,'0')}-${parsed.day.toString().padLeft(2,'0')}';
          if (d != dateKey) continue;
        }
      } else if (dateField != dateKey) {
        continue;
      }

      latestDoc = doc;
      break; // أحدث إشعار فقط
    }

    if (latestDoc == null) return [];

    final data  = latestDoc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? '').toString();
    final body  = (data['body']  ?? '').toString();
    final dayInTitle = title.contains('—') ? title.split('—').last.trim() : _todayArabicName();

    // تحليل نص الإشعار لاستخراج الحصص
    final lines = body.split('\n').where((l) => l.trim().startsWith('الحصة')).toList();
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final periodMatch = RegExp(r'الحصة\s+(\d+)').firstMatch(line);
      // يدعم كلا الصيغتين: "| فصل 3/4" و " - 3/4"
      // يلتقط أي نص بعد الفاصل حتى قبل "(" أو "[" أو نهاية السطر
      final classMatch  = RegExp(r'(?:\|\s*فصل\s+|[-–]\s*)([\d/\w\s]+?)(?:\s*[\(\[]|$)').firstMatch(line);
      final subjMatch   = RegExp(r'\(([^)]+)\)').firstMatch(line);
      final absentMatch = RegExp(r'\[غياب:\s*([^\]]+)\]').firstMatch(line);

      result.add({
        'day':        dayInTitle,
        'period':     periodMatch?.group(1) ?? '?',
        'class':      classMatch?.group(1)?.trim() ?? '—',
        'subject':    subjMatch?.group(1) ?? '',
        'absentName': absentMatch?.group(1) ?? '',
        'waitLabel':  'منتظر',
        'notifId':    latestDoc.id,
        'lineIdx':    i,  // مؤشر فريد لكل حصة داخل الإشعار
        'uniqueKey':  '${latestDoc.id}_$i',
        'status':     'pending',
      });
    }

    result.sort((a, b) {
      final ap = int.tryParse('${a['period']}') ?? 0;
      final bp = int.tryParse('${b['period']}') ?? 0;
      return ap.compareTo(bp);
    });
    return result;
  } catch (_) {
    return [];
  }
});

final rejectedViolationsProvider = FutureProvider.family<List<BehaviorRecord>, String>((ref, teacherId) async {
  final repo = ref.watch(behaviorRepositoryProvider);
  return repo.getRejectedViolations(teacherId);
});

// قائمة حصص الانتظار المرفوضة — ValueNotifier مشترك
final _rejectedWaitsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

class TeacherAlertsCenterScreen extends ConsumerStatefulWidget {
  const TeacherAlertsCenterScreen({super.key});

  @override
  ConsumerState<TeacherAlertsCenterScreen> createState() =>
      _TeacherAlertsCenterScreenState();
}

class _TeacherAlertsCenterScreenState
    extends ConsumerState<TeacherAlertsCenterScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final teacherId = userAsync.value?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFD32F2F)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حصص الانتظار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('تكليفات الانتظار لليوم', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        Expanded(child: _WaitsTab(teacherId: teacherId)),
        _WaitAbsenceSection(teacherId: teacherId),
      ]),
    );
  }
}

// ─── قسم غياب الانتظار ───────────────────────────────────────────────────────
class _WaitAbsenceSection extends ConsumerWidget {
  final String teacherId;
  const _WaitAbsenceSection({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty || teacherId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('TeacherWaitAbsences')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('recordedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        return Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.assignment_late_rounded, color: const Color(0xFF7C3AED), size: 16.sp),
                SizedBox(width: 6.w),
                Text('سجل الغياب عن الانتظار',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: const Color(0xFF7C3AED))),
              ]),
              SizedBox(height: 10.h),
              ...docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6.sp, color: Colors.red.shade400),
                    SizedBox(width: 8.w),
                    Text('${d['day'] ?? ''} — ${d['date'] ?? ''}',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6.r), border: Border.all(color: Colors.red.shade200)),
                      child: Text('غائب عن الانتظار', style: TextStyle(color: Colors.red.shade700, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _WaitsTab extends ConsumerWidget {
  final String teacherId;
  const _WaitsTab({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitsAsync = ref.watch(teacherWaitsProvider(teacherId));
    return waitsAsync.when(
      data: (waits) {
        if (waits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), shape: BoxShape.circle),
                  child: Icon(Icons.access_time_rounded, size: 64.sp, color: Colors.orange.shade600),
                ),
                SizedBox(height: 16.h),
                Text('لا توجد حصص انتظار اليوم', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                SizedBox(height: 6.h),
                Text(_todayArabicName(), style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // عنوان اليوم
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.today_rounded, color: Colors.orange.shade700, size: 18.sp),
                SizedBox(width: 8.w),
                Text('حصص انتظار اليوم — ${_todayArabicName()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.orange.shade900)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10.r)),
                  child: Text('${waits.length}', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            ...waits.map((w) => _buildWaitCard(context, w)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildWaitCard(BuildContext context, Map<String, dynamic> w) {
    final period     = '${w['period']}';
    final klass      = (w['class'] as String).isNotEmpty ? w['class'] as String : '—';
    final day        = '${w['day']}';
    final label      = '${w['waitLabel']}';
    final subject    = (w['subject'] as String).isNotEmpty ? w['subject'] as String : '';
    final absentName = (w['absentName'] as String).isNotEmpty ? w['absentName'] as String : '';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10.r)),
            child: Icon(Icons.access_time_filled_rounded, color: Colors.orange.shade700, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('الحصة $period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.grey.shade900)),
                Text(' — ', style: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6.r), border: Border.all(color: Colors.blue.shade200)),
                  child: Text('فصل $klass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.blue.shade800)),
                ),
              ]),
              if (subject.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Row(children: [
                  Icon(Icons.book_outlined, size: 12.sp, color: Colors.purple.shade400),
                  SizedBox(width: 4.w),
                  Text(subject, style: TextStyle(fontSize: 11.sp, color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
                ]),
              ],
              if (absentName.isNotEmpty) ...[
                SizedBox(height: 3.h),
                Row(children: [
                  Icon(Icons.person_off_outlined, size: 12.sp, color: Colors.red.shade400),
                  SizedBox(width: 4.w),
                  Text('غياب: $absentName', style: TextStyle(fontSize: 11.sp, color: Colors.red.shade600)),
                ]),
              ],
              SizedBox(height: 4.h),
              Row(children: [
                Text(day, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6.r), border: Border.all(color: Colors.orange.shade200)),
                  child: Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}




