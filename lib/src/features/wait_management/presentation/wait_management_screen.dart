library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../auth/presentation/auth_controller.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;




const _wColors = [Color(0xFF4F46E5),Color(0xFF059669),Color(0xFFD97706),Color(0xFFDC2626)];


// ─── حذف إشعارات حصص الانتظار ───────────────────────────────────────────────
Future<void> _deleteWaitNotifications(BuildContext context, String schoolId) async {
  if (schoolId.isEmpty) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.notifications_off_rounded, color: Colors.red, size: 22),
        SizedBox(width: 8),
        Text('حذف إشعارات الانتظار'),
      ]),
      content: const Text(
        'سيتم حذف جميع إشعارات "تكليف انتظار" التي أُرسلت للمعلمين.\n\nهذا الإجراء لا يمكن التراجع عنه.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('حذف', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  try {
    // حذف مباشر من Firestore بدون Cloud Function
    final snap = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications')
        .where('title', isGreaterThanOrEqualTo: '📋 تكليف انتظار')
        .where('title', isLessThanOrEqualTo: '📋 تكليف انتظار\uf8ff')
        .get();

    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد إشعارات انتظار لحذفها'), backgroundColor: Colors.orange));
      return;
    }

    // حذف دفعي
    int deleted = 0;
    for (int i = 0; i < snap.docs.length; i += 500) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = snap.docs.skip(i).take(500);
      for (final doc in chunk) { batch.delete(doc.reference); }
      await batch.commit();
      deleted += chunk.length;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم حذف $deleted إشعار انتظار بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
  }
}


// ─── تسجيل غياب عن حصة انتظار ──────────────────────────────────────────────
// يختار الوكيل المعلم المنتظر الذي لم يحضر → يُحفظ في Firestore
Future<void> _recordWaitAbsence(
    BuildContext context,
    String schoolId,
    String schoolName,
    List<Map<String, dynamic>> teachers,
    List<String> days) async {

  String? absentTeacherId;
  String? selectedDay;
  final todayIdx = DateTime.now().weekday % 7;
  if (todayIdx < days.length) selectedDay = days[todayIdx];

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.assignment_late_rounded, color: Color(0xFF7C3AED), size: 20)),
          const SizedBox(width: 10),
          const Expanded(child: Text('تسجيل غياب عن الانتظار',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('اختر المعلم الذي لم يحضر حصة الانتظار',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDay,
              decoration: InputDecoration(
                labelText: 'اليوم',
                labelStyle: const TextStyle(color: Color(0xFF059669)),
                prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF059669), size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                filled: true, fillColor: const Color(0xFFF8FAFF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => selectedDay = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: absentTeacherId,
              decoration: InputDecoration(
                labelText: 'المعلم الغائب عن الانتظار',
                labelStyle: const TextStyle(color: Color(0xFF7C3AED)),
                prefixIcon: const Icon(Icons.person_off_rounded, color: Color(0xFF7C3AED), size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                filled: true, fillColor: const Color(0xFFF8FAFF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: teachers.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name'] as String, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => absentTeacherId = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            onPressed: absentTeacherId != null && selectedDay != null ? () => Navigator.pop(ctx2, true) : null,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('تسجيل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        ],
      ),
    ),
  );

  if (confirmed != true || absentTeacherId == null || selectedDay == null) return;

  try {
    final teacherName = teachers.firstWhere((t) => t['id'] == absentTeacherId, orElse: () => {'name': ''})['name'] as String;
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

    // حفظ في TeacherWaitAbsences
    await FirebaseFirestore.instance
        .collection('Schools').doc(schoolId)
        .collection('TeacherWaitAbsences')
        .add({
      'teacherId':   absentTeacherId,
      'teacherName': teacherName,
      'day':         selectedDay,
      'date':        dateKey,
      'recordedAt':  FieldValue.serverTimestamp(),
      'recordedBy':  'وكيل',
      'schoolId':    schoolId,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم تسجيل غياب $teacherName عن حصة الانتظار'),
        backgroundColor: const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
    }
  }
}

// ─── طباعة غياب اليوم — دعم غائبين متعددين ─────────────────────────────────
Future<void> _printAbsenceReport(
    BuildContext context,
    String schoolId,
    String schoolName,
    List<Map<String, dynamic>> teachers,
    List<String> days) async {

  final absentList = <Map<String, String?>>[];
  String? selectedDay;
  final todayIdx = DateTime.now().weekday % 7;
  if (todayIdx < days.length) selectedDay = days[todayIdx];

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) {
        if (absentList.isEmpty) absentList.add({'id': null, 'name': null});
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 20)),
            const SizedBox(width: 10),
            const Expanded(child: Text('طباعة غياب اليوم',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
          ]),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                // اختيار اليوم
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: InputDecoration(
                    labelText: 'اليوم',
                    labelStyle: const TextStyle(color: Color(0xFF059669)),
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF059669), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    filled: true, fillColor: const Color(0xFFF8FAFF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: days.map((d) => DropdownMenuItem(
                    value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setS(() => selectedDay = v),
                ),
                const SizedBox(height: 14),
                // عنوان + زر إضافة
                Row(children: [
                  const Icon(Icons.people_outline, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 6),
                  const Text('المعلمون الغائبون',
                      style: TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setS(() => absentList.add({'id': null, 'name': null})),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded, color: Color(0xFF4F46E5), size: 14),
                        SizedBox(width: 4),
                        Text('إضافة غائب', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // صفوف الغائبين
                ...List.generate(absentList.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3))),
                      child: Center(child: Text('${i + 1}',
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('absent_${i}_${absentList.length}'),
                        value: absentList[i]['id'],
                        decoration: InputDecoration(
                          hintText: 'اختر المعلم الغائب',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          filled: true, fillColor: const Color(0xFFFFF5F5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                        items: teachers
                            .where((t) => !absentList.asMap().entries
                                .any((e) => e.key != i && e.value['id'] == t['id']))
                            .map((t) => DropdownMenuItem(
                              value: t['id'] as String,
                              child: Text(t['name'] as String,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setS(() {
                          absentList[i]['id'] = v;
                          absentList[i]['name'] = teachers.firstWhere(
                              (t) => t['id'] == v, orElse: () => {'name': ''})['name'] as String;
                        }),
                      ),
                    ),
                    if (absentList.length > 1) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setS(() => absentList.removeAt(i)),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded, color: Colors.red, size: 16)),
                      ),
                    ],
                  ]),
                )),
              ]),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton.icon(
              onPressed: absentList.any((a) => a['id'] != null) && selectedDay != null
                  ? () => Navigator.pop(ctx2, true)
                  : null,
              icon: const Icon(Icons.print_rounded, size: 16),
              label: Text('طباعة (${absentList.where((a) => a['id'] != null).length} غائب)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        );
      },
    ),
  );

  if (confirmed != true || selectedDay == null) return;
  final validAbsent = absentList.where((a) => a['id'] != null).toList();
  if (validAbsent.isEmpty) return;

  // ── جلب البيانات من Firestore ──
  try {
    final db = FirebaseFirestore.instance.collection('Schools').doc(schoolId);

    // جلب بيانات المدرسة — مع try/catch لتجنب permission error
    String fetchedSchoolName = schoolName.isNotEmpty ? schoolName : '................';
    String educationDept = '';
    try {
      final schoolDoc = await db.get();
      if (schoolDoc.exists) {
        final d = schoolDoc.data()!;
        final sName = (d['name'] ?? d['schoolName'] ?? '').toString().trim();
        if (sName.isNotEmpty) fetchedSchoolName = sName;
        educationDept = (d['adminRegion'] ?? d['educationDepartment'] ?? d['region'] ?? '').toString().trim();
      // إذا كان adminRegion فارغاً نبني النص من city
      if (educationDept.isEmpty) {
        final city = (d['city'] ?? '').toString().trim();
        if (city.isNotEmpty) educationDept = 'إدارة التعليم بمنطقة $city';
      }
      }
    } catch (e) {
      // إذا فشل جلب المدرسة نكمل بالاسم المُمرَّر
      debugPrint('School fetch error (non-critical): $e');
    }

    // جدول الانتظار المحفوظ
    final waitDoc = await db.collection('WaitSchedule').doc('current').get();
    final waitSlots = ((waitDoc.data()?['slots'] as List?) ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map)).toList();

    // أسماء المعلمين
    final tSnap = await db.collection('Teachers').get();
    final nameById = <String, String>{};
    for (final d in tSnap.docs) {
      final n = (d.data()['name'] ?? d.data()['displayName'] ?? '').toString();
      if (n.isNotEmpty) nameById[d.id] = n;
    }

    final normalDay = _normalizeDay(selectedDay!);
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final sections = <String>[];

    // أسماء الغائبين لنص المخاطبة
    final absentNamesForAddress = validAbsent
        .map((a) => a['name'] ?? nameById[a['id']!] ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    // ── بناء خريطة المنتظرين: period → List<String> (أسماء) ──
    final waitersByPeriod   = <int, List<String>>{};
    final waiterIdsByPeriod = <int, List<String>>{}; // للإشعارات
    for (final ws in waitSlots) {
      final wDay = _normalizeDay((ws['day'] ?? '').toString());
      if (wDay != normalDay) continue;
      final wPer = (ws['period'] as num?)?.toInt() ?? 0;
      if (wPer == 0) continue;
      final ids = (ws['teacherIds']   as List?)?.cast<String>() ?? [];
      final nms = (ws['teacherNames'] as List?)?.cast<String>() ?? [];
      final names = <String>[];
      for (int i = 0; i < ids.length; i++) {
        final n = i < nms.length && nms[i].isNotEmpty ? nms[i] : (nameById[ids[i]] ?? '');
        if (n.isNotEmpty) names.add(n);
      }
      waitersByPeriod[wPer]   = names;
      waiterIdsByPeriod[wPer] = ids;
    }

    // ── تتبع عداد التوزيع: period → كم غائب أخذ منتظراً حتى الآن ──
    final assignedCountByPeriod = <int, int>{};

    // قائمة جميع التكليفات لإرسال الإشعارات
    final allAssignmentsForNotify = <Map<String, dynamic>>[];

    for (final absent in validAbsent) {
      final absentId   = absent['id']!;
      final absentName = absent['name'] ?? nameById[absentId] ?? '';

      final absentDoc = await db.collection('TeacherSchedules').doc(absentId).get();
      final absentSlots = ((absentDoc.data()?['slots'] as List?) ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .where((s) {
            final d = _normalizeDay((s['day'] ?? s['dayName'] ?? '').toString());
            return d == normalDay;
          })
          .where((s) {
            final subj = (s['subject'] ?? '').toString();
            return !subj.contains('منتظر') && !subj.contains('انتظار') && !subj.contains('نوبة');
          })
          .toList();

      if (absentSlots.isEmpty) {
        sections.add('<div class="absent-block">'
          '<div class="absent-block-title">'
            '<span>اسم المعلم: $absentName</span>'
            '<span class="count" style="color:#fca5a5">⚠️ لا توجد حصص في يوم $selectedDay</span>'
          '</div>'
          '</div>');
        continue;
      }

      final assignments = <Map<String, dynamic>>[];
      for (final slot in absentSlots) {
        final period    = (slot['period'] as num?)?.toInt() ?? 0;
        final className = (slot['className'] ?? slot['class'] ?? '').toString();
        final subject   = (slot['subject'] ?? '').toString();

        // ── التوزيع الذكي: كل غائب يأخذ المنتظر التالي في الترتيب ──
        final allWaiters = waitersByPeriod[period] ?? [];
        final takenIdx   = assignedCountByPeriod[period] ?? 0;

        String assignedWaiter = '';
        String assignedWaiterId = '';
        int    assignedIdx    = -1;
        if (takenIdx < allWaiters.length) {
          assignedWaiter   = allWaiters[takenIdx];
          assignedIdx      = takenIdx;
          final wIds = waiterIdsByPeriod[period] ?? [];
          if (takenIdx < wIds.length) assignedWaiterId = wIds[takenIdx];
        }

        // تحديث العداد لهذه الحصة
        assignedCountByPeriod[period] = takenIdx + 1;

        assignments.add({
          'period':        period,
          'class':         className,
          'subject':       subject,
          'waiter':        assignedWaiter,
          'waiterId':      assignedWaiterId,
          'waiterIdx':     assignedIdx,
          'totalWaiters':  allWaiters.length,
          'absentName':    absentName,
        });
      }
      assignments.sort((a, b) => (a['period'] as int).compareTo(b['period'] as int));
      allAssignmentsForNotify.addAll(assignments);

      final trs = assignments.map((a) {
        final waiter     = (a['waiter'] as String);
        final waiterIdx  = (a['waiterIdx'] as int);
        final lbls       = ['الأول', 'الثاني', 'الثالث', 'الرابع'];
        final lbl        = waiterIdx >= 0 && waiterIdx < lbls.length ? lbls[waiterIdx] : '${waiterIdx + 1}';
        final waiterHtml = waiter.isNotEmpty
            ? '<span class="waiter-tag">منتظر $lbl</span>$waiter'
            : '<span class="no-waiter">لم يُحدد</span>';
        return '<tr>'
          '<td class="period-num">${a["period"]}</td>'
          '<td>${(a["class"] as String).isNotEmpty ? a["class"] : "—"}</td>'
          '<td>${(a["subject"] as String).isNotEmpty ? a["subject"] : "—"}</td>'
          '<td>$waiterHtml</td>'
          '<td class="sign-col"></td>'
          '<td class="notes-col"></td>'
          '</tr>';
      }).join();

      sections.add(
        '<div class="absent-block">'
          '<div class="absent-block-title">'
            '<span>اسم المعلم: $absentName</span>'
            '<span class="count">عدد الحصص: ${assignments.length}</span>'
          '</div>'
          '<table>'
            '<thead><tr>'
              '<th style="width:42px">الحصة</th>'
              '<th style="width:65px">الفصل</th>'
              '<th>المادة</th>'
              '<th>المعلم المنتظر</th>'
              '<th class="sign-col">التوقيع</th>'
              '<th class="notes-col">ملاحظات</th>'
            '</tr></thead>'
            '<tbody>$trs</tbody>'
          '</table>'
        '</div>');
    }

    // ── بناء HTML رسمي — نموذج تعويض غياب معلم ──
    // نص المخاطبة — مرة واحدة فقط
    final absentNamesJoined = absentNamesForAddress.join(' و ');
    final absentCount = absentNamesForAddress.length;
    // الشرط اللغوي الصحيح
    final absentWord = absentCount == 1
        ? 'الزميل'
        : absentCount == 2
            ? 'الزميلين'
            : 'الزملاء';
    final placeWord = absentCount == 1 ? 'مكانه' : 'مكانهم';
    final addressHtml = '<div class="address-text">'
      'زملائي المعلمين الكرام،،،<br>'
      'نظراً لغياب $absentWord: '
      '<span class="absent-name-inline">$absentNamesJoined</span> '
      'آمل تسديد $placeWord حسب الجدول الموضح والتوقيع بالعلم.. ولكم جزيل الشكر'
      '</div>';

    final deptLine = educationDept.isNotEmpty
        ? educationDept  // يُعرض كما هو من Firestore
        : 'إدارة التعليم';

    final html = '''<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<title>نموذج تعويض غياب معلم — $selectedDay</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  @page { size: A4 portrait; margin: 2cm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: 'Cairo', Arial, sans-serif;
    direction: rtl;
    background: #fff;
    color: #1a1a2e;
    font-size: 12px;
    line-height: 1.6;
  }
  .page-wrapper { width: 80%; margin: 0 auto; }

  /* ══ الهيدر ══ */
  .header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding-bottom: 12px;
    border-bottom: 2.5px solid #1a237e;
    margin-bottom: 14px;
  }
  .header-right { text-align: right; line-height: 2; }
  .header-right .country { font-size: 13px; font-weight: 700; color: #1a237e; }
  .header-right .region { font-size: 11px; font-weight: 700; color: #374151; }
  .header-right .school { font-size: 11px; color: #374151; }
  .header-right .ministry, .header-right .dept { font-size: 11px; color: #374151; }

  .header-center { flex: 1; text-align: center; padding: 0 16px; }
  .header-center img { width: 80px; height: 80px; object-fit: contain; }

  /* اليسار: التاريخ */
  .header-left {
    text-align: left;
    min-width: 120px;
    font-size: 11px;
    color: #374151;
    line-height: 2;
  }
  .header-left .lbl { font-weight: 700; color: #1a237e; }

  /* ══ عنوان النموذج ══ */
  .doc-title-box { text-align: center; margin-bottom: 14px; }
  .doc-title-box .title {
    display: inline-block;
    font-size: 15px; font-weight: 700; color: #1a237e;
    background: #eef2ff; border: 1.5px solid #c7d2fe;
    border-radius: 6px; padding: 6px 28px;
  }

  /* ══ معلومات التاريخ (وسط) ══ */
  .meta-row {
    display: flex;
    justify-content: center;
    gap: 20px;
    margin-bottom: 18px;
    font-size: 11px;
    color: #374151;
  }
  .meta-item { display: flex; align-items: center; gap: 5px; }
  .meta-label { font-weight: 700; color: #1a237e; }
  .meta-val {
    background: #f1f5f9; border: 1px solid #e2e8f0;
    border-radius: 4px; padding: 2px 8px;
  }

  /* ══ نص المخاطبة ══ */
  .address-text {
    font-size: 12px;
    color: #1a1a2e;
    margin-bottom: 14px;
    line-height: 1.9;
    padding: 10px 14px;
    background: #f8faff;
    border-right: 3px solid #1a237e;
    border-radius: 0 6px 6px 0;
  }
  .address-text .absent-name-inline {
    font-weight: 700;
    color: #1a237e;
    text-decoration: underline;
  }

  /* ══ قسم كل معلم غائب ══ */
  .absent-block { margin-bottom: 20px; }
  .absent-block-title {
    display: flex; justify-content: space-between; align-items: center;
    background: #1a237e; color: #fff;
    padding: 7px 14px; border-radius: 5px 5px 0 0;
    font-size: 12px; font-weight: 700;
  }
  .absent-block-title .count {
    font-size: 10px; font-weight: 400; opacity: 0.85;
    background: rgba(255,255,255,0.15);
    padding: 2px 8px; border-radius: 10px;
  }
  table {
    width: 100%; border-collapse: collapse;
    border: 1px solid #c7d2fe; border-top: none;
  }
  thead tr { background: #eef2ff; }
  th {
    padding: 7px 6px; font-size: 10px; font-weight: 700;
    color: #1a237e; border: 1px solid #c7d2fe; text-align: center;
  }
  td {
    padding: 8px 6px; font-size: 11px;
    border: 1px solid #e2e8f0; text-align: center;
    vertical-align: middle; color: #374151;
  }
  tbody tr:nth-child(even) td { background: #f8faff; }
  .period-num { font-weight: 700; color: #1a237e; font-size: 13px; }
  .waiter-tag {
    display: inline-block; background: #dbeafe; color: #1d4ed8;
    font-size: 9px; font-weight: 700;
    padding: 1px 6px; border-radius: 10px; margin-left: 4px;
  }
  .no-waiter { color: #dc2626; font-size: 10px; }
  .sign-col { width: 75px; }
  .notes-col { width: 85px; }

  /* ══ الفوتر ══ */
  .footer {
    margin-top: 28px; padding-top: 14px;
    border-top: 2px solid #1a237e;
    display: flex; justify-content: space-around; align-items: flex-end;
  }
  .sig-block { text-align: center; min-width: 110px; }
  .sig-block .sig-label {
    font-size: 11px; font-weight: 700; color: #1a237e; margin-bottom: 26px;
  }
  .sig-block .sig-line {
    border-bottom: 1.5px solid #374151; width: 100px; margin: 0 auto;
  }
  /* خانة فارغة في الكليشة */
  .header-right .sig-space {
    margin-top: 8px;
    border-bottom: 1px solid #374151;
    width: 100px;
    display: inline-block;
  }

  @media print {
    .header-center img, thead tr, .absent-block-title, .doc-title-box .title, .address-text {
      -webkit-print-color-adjust: exact; print-color-adjust: exact;
    }
  }
</style>
</head>
<body>
<div class="page-wrapper">

  <!-- ══ الهيدر ══ -->
  <div class="header">
    <!-- يمين: بيانات الجهة -->
    <div class="header-right">
      <div class="country" style="padding-right:2.5em">المملكة العربية السعودية</div>
      <div class="ministry" style="padding-right:5em">وزارة التعليم</div>
      <div class="dept" style="padding-right:2.5em">$deptLine</div>
      <div class="region">$fetchedSchoolName</div>
    </div>
    <!-- وسط: الشعار -->
    <div class="header-center">
      <img src="/logokshuf.webp" alt="الشعار" onerror="this.style.display='none'">
    </div>
    <!-- يسار: التاريخ -->
    <div class="header-left">
      <div><span class="lbl">التاريخ: </span>$dateStr</div>
      <div><span class="lbl">اليوم: </span>$selectedDay</div>
      <div><span class="lbl">الرقم: </span>___________</div>
    </div>
  </div>

  <!-- ══ عنوان النموذج ══ -->
  <div class="doc-title-box">
    <span class="title">نموذج تعويض غياب معلم</span>
  </div>

  <!-- ══ معلومات (وسط) ══ -->
  <div class="meta-row">
    <div class="meta-item">
      <span class="meta-label">التاريخ:</span>
      <span class="meta-val">$dateStr</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">اليوم:</span>
      <span class="meta-val">$selectedDay</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">عدد الغائبين:</span>
      <span class="meta-val">${validAbsent.length}</span>
    </div>
  </div>

  <!-- ══ نص المخاطبة (مرة واحدة) ══ -->
  $addressHtml

  <!-- ══ جداول الغائبين ══ -->
${sections.join('\n')}

  <!-- ══ الفوتر ══ -->
  <div class="footer">
    <div class="sig-block">
      <div class="sig-label">توقيع وكيل الشؤون التعليمية</div>
      <div class="sig-line"></div>
    </div>
    <div class="sig-block">
      <div class="sig-label">&nbsp;</div>
      <div class="sig-line" style="border:none"></div>
    </div>
    <div class="sig-block">
      <div class="sig-label">توقيع مدير المدرسة</div>
      <div class="sig-line"></div>
    </div>
  </div>

</div>
</body>
</html>''';

    _openPrintPage(html);

    // ── إرسال إشعارات للمعلمين المنتظرين ──
    _sendWaitNotifications(
      schoolId: schoolId,
      selectedDay: selectedDay!,
      allAssignments: allAssignmentsForNotify,
      nameById: nameById,
    );

  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(

        content: Text('خطأ: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
    }
  }
}

// ─── إرسال إشعارات للمعلمين المنتظرين ──────────────────────────────────────
// يحفظ الإشعار في Firestore مباشرة (يعمل حتى لو المعلم لم يفتح التطبيق بعد)
// يحفظ الإشعار في Firestore مباشرة — مرة واحدة فقط بدون تكرار
Future<void> _sendWaitNotifications({
  required String schoolId,
  required String selectedDay,
  required List<Map<String, dynamic>> allAssignments,
  required Map<String, String> nameById,
}) async {
  if (schoolId.isEmpty || allAssignments.isEmpty) return;

  // تجميع الحصص لكل معلم منتظر: waiterId → list of assignments
  final byWaiter = <String, List<Map<String, dynamic>>>{};
  for (final a in allAssignments) {
    final wId = (a['waiterId'] as String?) ?? '';
    if (wId.isEmpty) continue;
    byWaiter.putIfAbsent(wId, () => []);
    byWaiter[wId]!.add(a);
  }

  if (byWaiter.isEmpty) return;

  final db  = FirebaseFirestore.instance
      .collection('Schools').doc(schoolId).collection('Notifications');
  final now = DateTime.now();
  // تاريخ اليوم بصيغة yyyy-MM-dd للبحث لاحقاً
  final dateKey = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

  for (final entry in byWaiter.entries) {
    final waiterId = entry.key;
    final slots    = entry.value;

    final periodsText = slots.map((s) {
      final period  = s['period'];
      final cls     = (s['class'] as String).isNotEmpty ? s['class'] : '';
      final subject = (s['subject'] as String).isNotEmpty ? s['subject'] : '';
      final absent  = (s['absentName'] as String?) ?? '';
      return 'الحصة $period${cls.isNotEmpty ? " | فصل $cls" : ""}${subject.isNotEmpty ? " ($subject)" : ""}${absent.isNotEmpty ? " [غياب: $absent]" : ""}';
    }).join('\n');

    final body = 'يوم $selectedDay:\n$periodsText';

    try {
      // حفظ واحد فقط في Firestore — بدون FCM لتجنب التكرار
      final docRef = db.doc();
      await docRef.set({
        'id':         docRef.id,
        'userId':     waiterId,
        'title':      '📋 تكليف انتظار — $selectedDay',
        'body':       body,
        'timestamp':  now.toIso8601String(),
        'date':       dateKey,          // للبحث بتاريخ اليوم
        'isRead':     false,
        'schoolId':   schoolId,
        'route':      '/teacher/alerts',
        'targetRole': null,
      });
    } catch (e) {
      debugPrint('Notification save error for $waiterId: $e');
    }
  }
}

// ─── طباعة الجدول الكامل (جميع المعلمين المنتظرين) ─────────────────────────
Future<void> _printFullWaitSchedule(
    Map<String, Map<int, _Slot>> schedule,
    List<String> days,
    String schoolName,
    String schoolId) async {

  final nameById = <String, String>{};
  try {
    final tSnap = await FirebaseFirestore.instance
        .collection('Schools').doc(schoolId).collection('Teachers').get();
    for (final d in tSnap.docs) {
      final n = (d.data()['name'] ?? d.data()['displayName'] ?? '').toString();
      if (n.isNotEmpty) nameById[d.id] = n;
    }
  } catch (_) {}

  // تجميع حسب المعلم المنتظر
  final byTeacher = <String, List<Map<String, dynamic>>>{};
  final dayOrder = ['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];

  for (final day in days) {
    final daySlots = schedule[day] ?? {};
    for (final entry in daySlots.entries) {
      final p = entry.key;
      final slot = entry.value;
      for (int i = 0; i < slot.teacherIds.length; i++) {
        final name = i < slot.teacherNames.length ? slot.teacherNames[i] : '';
        if (name.isEmpty) continue;
        final waitLabel = i == 0 ? 'منتظر أول' : i == 1 ? 'منتظر ثاني' : i == 2 ? 'منتظر ثالث' : 'منتظر رابع';
        byTeacher.putIfAbsent(name, () => []);
        byTeacher[name]!.add({'day': day, 'period': p, 'waitLabel': waitLabel});
      }
    }
  }

  if (byTeacher.isEmpty) return;

  final now = DateTime.now();
  final dateStr = '${now.day}/${now.month}/${now.year}';

  final sections = byTeacher.entries.map((entry) {
    final teacher = entry.key;
    final slots = entry.value
      ..sort((a, b) {
        final dc = dayOrder.indexOf(a['day']).compareTo(dayOrder.indexOf(b['day']));
        return dc != 0 ? dc : (a['period'] as int).compareTo(b['period'] as int);
      });
    final trs = slots.map((s) =>
      '<tr><td>${s["period"]}</td><td>${s["day"]}</td>'
      '<td>${s["waitLabel"]}</td><td></td><td></td></tr>').join();
    return '<div class="tb">'
      '<h3>المعلم المنتظر: $teacher</h3>'
      '<table><tr><th>الحصة</th><th>اليوم</th><th>نوع الانتظار</th><th>التوقيع</th><th>ملاحظات</th></tr>'
      '$trs</table>'
      '<p class="sig">توقيع المدير: _______________</p>'
      '</div>';
  }).join();

  final html = '<!DOCTYPE html><html dir="rtl"><head><meta charset="UTF-8">'
    '<title>جدول الانتظار الكامل</title><style>'
    'body{font-family:Arial,sans-serif;margin:20px;direction:rtl;font-size:13px;}'
    'h1{text-align:center;color:#1a237e;border-bottom:3px solid #1a237e;padding-bottom:10px;font-size:20px;}'
    '.meta{text-align:center;color:#666;margin-bottom:24px;font-size:12px;}'
    '.tb{page-break-after:always;margin-bottom:40px;}'
    'h3{color:#1a237e;background:linear-gradient(135deg,#e8eaf6,#c5cae9);padding:10px 16px;'
      'border-radius:8px;margin-bottom:8px;font-size:15px;border-right:4px solid #1a237e;}'
    'table{width:100%;border-collapse:collapse;margin-top:8px;}'
    'th{background:#1a237e;color:white;padding:9px 6px;border:1px solid #3949ab;font-size:12px;}'
    'td{padding:8px 6px;border:1px solid #ddd;text-align:center;font-size:12px;}'
    'tr:nth-child(even) td{background:#f3f4ff;}'
    '.sig{margin-top:16px;text-align:left;color:#555;font-size:12px;}'
    '@media print{.tb{page-break-after:always;}'
      'h3,th{-webkit-print-color-adjust:exact;print-color-adjust:exact;}}'
    '</style></head><body>'
    '<h1>📋 جدول الانتظار الكامل — $schoolName</h1>'
    '<p class="meta">تاريخ الطباعة: $dateStr</p>'
    '$sections</body></html>';

  _openPrintPage(html);
}

Future<void> _openPrintPage(String htmlContent) async {
  // استخدام JavaScript مباشرة لفتح نافذة طباعة
  js.context.callMethod('eval', ['''
    (function() {
      var win = window.open('', '_blank');
      if (!win) { alert('يرجى السماح بالنوافذ المنبثقة'); return; }
      win.document.open();
      win.document.write(${_jsString(htmlContent)});
      win.document.close();
      win.focus();
      setTimeout(function(){ win.print(); }, 500);
    })();
  ''']);
}

String _jsString(String s) {
  // تحويل النص إلى JSON string آمن لـ JavaScript
  final escaped = s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
  return "'$escaped'";
}







String _normalizeDay(String s) {
  return s
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه').replaceAll('ى', 'ي').trim();
}

class _Slot {
  final String day; final int period;
  List<String> teacherIds; List<String> teacherNames; bool isManual;
  _Slot({required this.day,required this.period,required this.teacherIds,required this.teacherNames,this.isManual=false});
  Map<String,dynamic> toMap()=>{'day':day,'period':period,'teacherIds':teacherIds,'teacherNames':teacherNames,'isManual':isManual};
}

class WaitManagementScreen extends ConsumerStatefulWidget {
  final String? schoolId;
  const WaitManagementScreen({super.key, this.schoolId});
  @override ConsumerState<WaitManagementScreen> createState()=>_State();
}

class _State extends ConsumerState<WaitManagementScreen> {
  Map<String,Map<int,_Slot>> _schedule={};
  String _schoolName='';
  bool _isSaving=false; int _waitCount=2;
  final _days=['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];
  final _periods=7;

  String? get _sid {
    if (widget.schoolId != null && widget.schoolId!.isNotEmpty) return widget.schoolId;
    return ref.read(authStateProvider).value?.schoolId;
  }

  void _generate(List<Map<String,dynamic>> teachers) {
    if(teachers.isEmpty){
      // جلب المعلمين مباشرة إذا كانت القائمة فارغة
      final authSid = ref.read(authStateProvider).value?.schoolId ?? '';
      final sid2 = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;
      if (sid2.isNotEmpty) {
        FirebaseFirestore.instance.collection('Schools').doc(sid2).collection('Teachers').get().then((snap) {
          final t = snap.docs.map((d) {
            final data = d.data();
            return <String,dynamic>{'id': d.id, 'name': (data['name'] ?? data['displayName'] ?? '').toString(), 'max': (data['maxWeeklyClasses'] ?? 24) as int};
          }).where((t) => (t['name'] as String).isNotEmpty).toList();
          if (t.isNotEmpty) _generate(t);
        });
      }
      return;
    }
    _schedule={};
    final cnt=<String,int>{};
    for(final t in teachers)cnt[t['id'] as String]=0;
    final sorted=List<Map<String,dynamic>>.from(teachers)
      ..sort((a,b)=>(b['max'] as int).compareTo(a['max'] as int));
    for(final day in _days){
      _schedule[day]={};
      for(int p=1;p<=_periods;p++){
        final used=<String>{};
        for(final s in _schedule[day]!.values)used.addAll(s.teacherIds);
        final ids=<String>[]; final names=<String>[];
        for(int pos=0;pos<_waitCount;pos++){
          Map<String,dynamic>? ch; int mn=9999;
          for(final t in sorted){
            final id=t['id'] as String;
            if(ids.contains(id))continue;
            if(pos==0&&used.contains(id))continue;
            final c2=cnt[id]??0;
            if(c2<mn){mn=c2;ch=t;}
          }
          if(ch==null){for(final t in sorted){final id=t['id'] as String;if(ids.contains(id))continue;final c2=cnt[id]??0;if(c2<mn){mn=c2;ch=t;}}}
          if(ch!=null){final id=ch['id'] as String;ids.add(id);names.add(ch['name'] as String);cnt[id]=(cnt[id]??0)+1;}
        }
        if(ids.isNotEmpty)_schedule[day]![p]=_Slot(day:day,period:p,teacherIds:ids,teacherNames:names);
      }
    }
    setState((){});
  }

  Future<void> _importFromSchedule(List<Map<String,dynamic>> teachersParam) async {
    final authSid = ref.read(authStateProvider).value?.schoolId ?? '';
    final sid = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;
    if(sid.isEmpty) return;
    try{
      // جلب أسماء المعلمين مباشرة من Teachers collection
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(sid).collection('Teachers').get();
      final nameById = <String,String>{};
      for (final t in teachersSnap.docs) {
        final data = t.data();
        final name = (data['name'] ?? data['displayName'] ?? '').toString();
        if (name.isNotEmpty) nameById[t.id] = name;
      }
      final snap=await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('TeacherSchedules').get();
      final wm=<String,Map<int,Map<int,Map<String,String>>>>{};
      for(final doc in snap.docs){
        final tid=doc.id; final tname=nameById[tid]??'';
        final slots=(doc.data()['slots'] as List?)??[];
        for(final slot in slots){
          if(slot is! Map)continue;
          final subj=(slot['subject']??'').toString();
          final rawDay=(slot['day']??slot['dayName']??'').toString();
          final day=_normalizeDay(rawDay);
          final per=(slot['period'] as num?)?.toInt()??0;
          if(!subj.contains('منتظر')&&!subj.contains('انتظار')&&!subj.contains('نوبة'))continue;
          if(day.isEmpty||per==0)continue;
          int wn=1; final nm=RegExp(r'(\d+)').firstMatch(subj);
          if(nm!=null)wn=int.tryParse(nm.group(1)!)??1;
          wm.putIfAbsent(day,()=>{});
          wm[day]!.putIfAbsent(per,()=>{});
          wm[day]![per]![wn]={'id':tid,'name':tname};
        }
      }
      if(wm.isEmpty){_generate([]);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد حصص انتظار - تم التوليد التلقائي'),backgroundColor:Color(0xFFD97706),behavior:SnackBarBehavior.floating));return;}
      _schedule={};
      for(final day in wm.keys){
        _schedule[day]={};
        for(final per in wm[day]!.keys){
          final byN=wm[day]![per]!;
          final ids=<String>[]; final names=<String>[];
          for(int i=1;i<=_waitCount;i++){if(byN.containsKey(i)){ids.add(byN[i]!['id']!);names.add(byN[i]!['name']!);}}
          if(ids.isNotEmpty)_schedule[day]![per]=_Slot(day:day,period:per,teacherIds:ids,teacherNames:names);
        }
      }
      if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم استيراد جدول الانتظار'),backgroundColor:const Color(0xFF059669),behavior:SnackBarBehavior.floating));}
    }catch(e){_generate([]);}
  }

  Future<void> _save() async {
    final sid=_sid; if(sid==null)return;
    setState(()=>_isSaving=true);
    try{
      final slots=<Map<String,dynamic>>[];
      for(final d in _schedule.keys)for(final s in _schedule[d]!.values)slots.add(s.toMap());
      await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('WaitSchedule').doc('current')
          .set({'slots':slots,'waitCount':_waitCount,'updatedAt':FieldValue.serverTimestamp()});
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم الحفظ'),backgroundColor:Color(0xFF059669),behavior:SnackBarBehavior.floating));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطأ: $e'),backgroundColor:Colors.red));}
    finally{if(mounted)setState(()=>_isSaving=false);}
  }

  void _edit(String day, int period) {
    final authSid = ref.read(authStateProvider).value?.schoolId ?? '';
    final sid2 = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;
    if (sid2.isEmpty) return;

    final slot = _schedule[day]?[period];
    final sel = List<String?>.filled(_waitCount, null);
    if (slot != null) {
      for (int i = 0; i < slot.teacherIds.length && i < _waitCount; i++) {
        sel[i] = slot.teacherIds[i];
      }
    }

    showDialog(
      context: context,
      builder: (_) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('Schools').doc(sid2).collection('Teachers').get(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const AlertDialog(
              content: SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))),
            );
          }
          final teachers = snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return <String, dynamic>{
              'id': d.id,
              'name': (data['name'] ?? data['displayName'] ?? '').toString(),
            };
          }).where((t) => (t['name'] as String).isNotEmpty).toList();

          return StatefulBuilder(
            builder: (ctx2, setS) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تعديل: $day - الحصة $period (${teachers.length} معلم)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              content: SizedBox(
                width: 340,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ...List.generate(_waitCount, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('drop_${i}_${teachers.length}'),
                      value: sel[i],
                      decoration: InputDecoration(
                        labelText: 'منتظر ${i + 1}',
                        labelStyle: TextStyle(color: _wColors[i % _wColors.length]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _wColors[i % _wColors.length].withOpacity(0.4))),
                        filled: true,
                        fillColor: _wColors[i % _wColors.length].withOpacity(0.04),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('-- فارغ --')),
                        ...teachers.map((t) => DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(t['name'] as String, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setS(() => sel[i] = v),
                    ),
                  )),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx2);
                    setState(() {
                      final ids = sel.where((s) => s != null).cast<String>().toList();
                      final names = ids.map((id) {
                        final t = teachers.firstWhere((t) => t['id'] == id, orElse: () => {'name': ''});
                        return t['name'] as String;
                      }).toList();
                      if (ids.isEmpty) {
                        _schedule[day]?.remove(period);
                      } else {
                        _schedule.putIfAbsent(day, () => {});
                        _schedule[day]![period] = _Slot(
                          day: day, period: period,
                          teacherIds: ids, teacherNames: names, isManual: true);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context){
    // Watch auth state - will rebuild when user loads
    final authAsync = ref.watch(authStateProvider);
    final authSid = authAsync.value?.schoolId ?? '';
    final sid = (widget.schoolId != null && widget.schoolId!.isNotEmpty)
        ? widget.schoolId!
        : authSid;

    // Show loading while auth is loading
    if (authAsync.isLoading && sid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFF),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    return Scaffold(
      backgroundColor:const Color(0xFFF8FAFF),
      body:sid.isEmpty?const Center(child:CircularProgressIndicator(color:Color(0xFF4F46E5))):StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots(),
        builder:(ctx,snap){
          // جلب اسم المدرسة والإدارة التعليمية
          if (_schoolName.isEmpty && sid.isNotEmpty) {
            FirebaseFirestore.instance.collection('Schools').doc(sid).get().then((d) {
              if (d.exists && mounted) {
                final data = d.data() ?? {};
                setState(() {
                  _schoolName = (data['name'] ?? data['schoolName'] ?? '').toString();
                });
              }
            });
          }
          final teachers=snap.hasData?snap.data!.docs.map((d){final data=d.data() as Map<String,dynamic>;return <String,dynamic>{'id':d.id,'name':(data['name']??'').toString(),'max':(data['maxWeeklyClasses']??24) as int};}).where((t)=>(t['name'] as String).isNotEmpty).toList():<Map<String,dynamic>>[];
          return Column(children:[
            _topBar(teachers),
            Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(children:[_legend(),const SizedBox(height:12),_grid(teachers),const SizedBox(height:40)]))),
          ]);
        },
      ),
    );
  }

  Widget _topBar(List<Map<String,dynamic>> teachers){
    return Container(
      padding:const EdgeInsets.fromLTRB(16,48,16,12),
      decoration:BoxDecoration(color:Colors.white,border:const Border(bottom:BorderSide(color:Color(0xFFE2E8F0))),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8,offset:const Offset(0,2))]),
      child:Column(children:[
        Row(children:[
          GestureDetector(onTap:()=>Navigator.of(context).pop(),child:Container(width:36,height:36,decoration:BoxDecoration(color:const Color(0xFFF8FAFF),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE2E8F0))),child:const Icon(Icons.arrow_back_ios_new_rounded,color:Color(0xFF64748B),size:15))),
          const SizedBox(width:12),
          Container(width:40,height:40,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF4F46E5),Color(0xFF06B6D4)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(12),boxShadow:[BoxShadow(color:const Color(0xFF4F46E5).withOpacity(0.3),blurRadius:10,offset:const Offset(0,4))]),child:const Icon(Icons.hourglass_top_rounded,color:Colors.white,size:20)),
          const SizedBox(width:10),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('جدول الانتظار',style:TextStyle(color:Color(0xFF1E293B),fontSize:16,fontWeight:FontWeight.bold)),
            Text('توزيع ذكي حسب النصاب',style:TextStyle(color:Color(0xFF64748B),fontSize:11)),
          ])),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFF8FAFF),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE2E8F0))),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              const Text('منتظرين:',style:TextStyle(color:Color(0xFF64748B),fontSize:11)),const SizedBox(width:6),
              ...List.generate(4,(i)=>GestureDetector(onTap:()=>setState((){_waitCount=i+1;_generate(teachers);}),child:Container(width:28,height:28,margin:const EdgeInsets.only(left:4),decoration:BoxDecoration(color:_waitCount==i+1?_wColors[i]:_wColors[i].withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:_wColors[i].withOpacity(0.4))),child:Center(child:Text('${i+1}',style:TextStyle(color:_waitCount==i+1?Colors.white:_wColors[i],fontSize:12,fontWeight:FontWeight.bold)))))),
            ])),
        ]),
        const SizedBox(height:10),
        Row(children:[
          OutlinedButton.icon(onPressed:()=>_importFromSchedule(teachers),icon:const Icon(Icons.download_rounded,size:14,color:Color(0xFF4F46E5)),label:const Text('استيراد من الجدول',style:TextStyle(fontSize:12,color:Color(0xFF4F46E5))),style:OutlinedButton.styleFrom(side:const BorderSide(color:Color(0xFF4F46E5),),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
          const SizedBox(width:8),
          OutlinedButton.icon(onPressed:()=>setState(()=>_generate(teachers)),icon:const Icon(Icons.auto_fix_high_rounded,size:14,color:Color(0xFF059669)),label:const Text('توزيع تلقائي',style:TextStyle(fontSize:12,color:Color(0xFF059669))),style:OutlinedButton.styleFrom(side:const BorderSide(color:Color(0xFF059669)),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
          const Spacer(),
          ElevatedButton.icon(onPressed:_isSaving?null:_save,icon:_isSaving?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded,size:15),label:const Text('حفظ',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF059669),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),
          const SizedBox(width:8),
          // زر طباعة غياب اليوم
          ElevatedButton.icon(
            onPressed:()=>_printAbsenceReport(context,_sid??'',_schoolName,teachers,_days),
            icon:const Icon(Icons.person_off_rounded,size:15),
            label:const Text('غياب اليوم',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
            style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFFDC2626),foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),
          const SizedBox(width:8),
          // زر تسجيل غياب عن الانتظار
          ElevatedButton.icon(
            onPressed:()=>_recordWaitAbsence(context,_sid??'',_schoolName,teachers,_days),
            icon:const Icon(Icons.assignment_late_rounded,size:15),
            label:const Text('غياب انتظار',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
            style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF7C3AED),foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),
          const SizedBox(width:8),
          // زر طباعة الجدول الكامل
          ElevatedButton.icon(
            onPressed:()=>_printFullWaitSchedule(_schedule,_days,_schoolName,_sid??''),
            icon:const Icon(Icons.print_rounded,size:15),
            label:const Text('الجدول الكامل',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
            style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF4F46E5),foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),
          const SizedBox(width:8),
          // زر حذف إشعارات الانتظار
          ElevatedButton.icon(
            onPressed: () => _deleteWaitNotifications(context, _sid ?? ''),
            icon: const Icon(Icons.notifications_off_rounded, size: 15),
            label: const Text('حذف الإشعارات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)),
        ]),
      ]),
    );
  }

  Widget _legend(){
    return Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFE2E8F0))),
      child:Row(children:[const Text('دليل الألوان:',style:TextStyle(color:Color(0xFF64748B),fontSize:12,fontWeight:FontWeight.bold)),const SizedBox(width:12),
        ...List.generate(_waitCount,(i)=>Container(margin:const EdgeInsets.only(left:10),padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:_wColors[i%_wColors.length].withOpacity(0.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:_wColors[i%_wColors.length].withOpacity(0.3))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:8,height:8,decoration:BoxDecoration(color:_wColors[i%_wColors.length],shape:BoxShape.circle)),const SizedBox(width:5),Text('منتظر ${i+1}',style:TextStyle(color:_wColors[i%_wColors.length],fontSize:11,fontWeight:FontWeight.w600))]))),
      ]));
  }

  Widget _grid(List<Map<String,dynamic>> teachers){
    final dc=[const Color(0xFF4F46E5),const Color(0xFF059669),const Color(0xFFD97706),const Color(0xFFDC2626),const Color(0xFF7C3AED)];
    return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE2E8F0)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:12)]),
      child:Column(children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:10),decoration:const BoxDecoration(color:Color(0xFFF8FAFF),borderRadius:BorderRadius.vertical(top:Radius.circular(16)),border:Border(bottom:BorderSide(color:Color(0xFFE2E8F0)))),
          child:Row(children:[const SizedBox(width:52,child:Text('الحصة',style:TextStyle(color:Color(0xFF64748B),fontSize:11,fontWeight:FontWeight.bold),textAlign:TextAlign.center)),
            ...List.generate(_days.length,(i)=>Expanded(child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),decoration:BoxDecoration(color:dc[i].withOpacity(0.1),borderRadius:BorderRadius.circular(8)),child:Text(_days[i],style:TextStyle(color:dc[i],fontSize:11,fontWeight:FontWeight.bold)))))),
          ])),
        ...List.generate(_periods,(pi){
          final p=pi+1;
          return Container(decoration:BoxDecoration(color:pi%2==0?Colors.white:const Color(0xFFFAFBFF),border:const Border(bottom:BorderSide(color:Color(0xFFE2E8F0),width:0.5))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:52,padding:const EdgeInsets.symmetric(vertical:8),decoration:const BoxDecoration(color:Color(0xFFF1F5F9),border:Border(right:BorderSide(color:Color(0xFFE2E8F0),width:0.5))),
                child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('$p',style:const TextStyle(color:Color(0xFF4F46E5),fontSize:16,fontWeight:FontWeight.bold)),const Text('حصة',style:TextStyle(color:Color(0xFF94A3B8),fontSize:9))]))),
              ...List.generate(_days.length,(di){
                final day=_days[di]; final slot=_schedule[day]?[p];
                return Expanded(child:GestureDetector(onTap:()=>_edit(day,p),child:Container(margin:const EdgeInsets.all(3),padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:slot!=null?const Color(0xFFF8FAFF):const Color(0xFFF1F5F9),borderRadius:BorderRadius.circular(8),border:Border.all(color:slot!=null?const Color(0xFFCBD5E1):const Color(0xFFE2E8F0))),
                  child:slot!=null?Column(mainAxisSize:MainAxisSize.min,children:[
                    if(slot.isManual)Container(margin:const EdgeInsets.only(bottom:2),padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),decoration:BoxDecoration(color:const Color(0xFFFEF3C7),borderRadius:BorderRadius.circular(4)),child:const Text('يدوي',style:TextStyle(color:Color(0xFFD97706),fontSize:8,fontWeight:FontWeight.bold))),
                    ...List.generate(slot.teacherNames.length,(wi)=>Container(margin:const EdgeInsets.only(bottom:2),padding:const EdgeInsets.symmetric(horizontal:5,vertical:3),decoration:BoxDecoration(color:_wColors[wi%_wColors.length].withOpacity(0.1),borderRadius:BorderRadius.circular(5),border:Border.all(color:_wColors[wi%_wColors.length].withOpacity(0.3))),
                      child:Text(_sn(slot.teacherNames[wi]),style:TextStyle(color:_wColors[wi%_wColors.length],fontSize:9,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis))),
                  ]):const Center(child:Icon(Icons.add_rounded,color:Color(0xFFCBD5E1),size:16)))));
              }),
            ]));
        }),
      ]));
  }

  String _sn(String n){final p=n.trim().split(' ');return p.length>=2?'${p[0]} ${p[1]}':n;}
}
