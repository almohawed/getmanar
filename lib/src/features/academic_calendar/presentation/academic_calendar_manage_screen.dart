import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class AcademicEvent {
  final String id;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String type; // 'termStart' | 'termEnd' | 'holiday' | 'exam' | 'other'
  final String? description;
  final String createdBy;

  AcademicEvent({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    required this.type,
    this.description,
    required this.createdBy,
  });

  factory AcademicEvent.fromMap(Map<String, dynamic> m, String id) => AcademicEvent(
        id: id,
        title: m['title'] ?? '',
        date: (m['date'] as Timestamp).toDate(),
        endDate: m['endDate'] != null ? (m['endDate'] as Timestamp).toDate() : null,
        type: m['type'] ?? 'other',
        description: m['description'],
        createdBy: m['createdBy'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'type': type,
        'description': description,
        'createdBy': createdBy,
      };

  Color get color {
    switch (type) {
      case 'termStart': return const Color(0xFF4CAF50);
      case 'termEnd':   return const Color(0xFFFF9800);
      case 'holiday':   return const Color(0xFFF44336);
      case 'exam':      return const Color(0xFF9C27B0);
      default:          return const Color(0xFF2196F3);
    }
  }

  IconData get icon {
    switch (type) {
      case 'termStart': return Icons.school;
      case 'termEnd':   return Icons.done_all;
      case 'holiday':   return Icons.celebration;
      case 'exam':      return Icons.quiz;
      default:          return Icons.event;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'termStart': return 'بداية فصل';
      case 'termEnd':   return 'نهاية فصل';
      case 'holiday':   return 'إجازة';
      case 'exam':      return 'اختبارات';
      default:          return 'حدث';
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final academicCalendarProvider =
    StreamProvider.family<List<AcademicEvent>, String>((ref, schoolId) {
  if (schoolId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('AcademicCalendar')
      .orderBy('date')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AcademicEvent.fromMap(d.data(), d.id))
          .toList());
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class AcademicCalendarManageScreen extends ConsumerStatefulWidget {
  const AcademicCalendarManageScreen({super.key});

  @override
  ConsumerState<AcademicCalendarManageScreen> createState() =>
      _AcademicCalendarManageScreenState();
}

class _AcademicCalendarManageScreenState
    extends ConsumerState<AcademicCalendarManageScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final eventsAsync = ref.watch(academicCalendarProvider(schoolId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('التقويم الدراسي',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => _showAddEventDialog(context, schoolId, user?.name ?? ''),
            tooltip: 'إضافة حدث',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Bar ──────────────────────────────────────────────
          _buildFilterBar(),

          // ─── Events List ─────────────────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final filtered = _filter == 'all'
                    ? events
                    : events.where((e) => e.type == _filter).toList();

                if (filtered.isEmpty) {
                  return _buildEmpty();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildEventCard(
                      context, filtered[i], schoolId),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white38)),
              error: (e, _) => Center(
                  child: Text('خطأ: $e',
                      style: const TextStyle(color: Colors.white38))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context, schoolId, user?.name ?? ''),
        backgroundColor: const Color(0xFF00695C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة حدث',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'key': 'all',       'label': 'الكل',       'color': Colors.white54},
      {'key': 'termStart', 'label': 'بداية فصل',  'color': const Color(0xFF4CAF50)},
      {'key': 'termEnd',   'label': 'نهاية فصل',  'color': const Color(0xFFFF9800)},
      {'key': 'holiday',   'label': 'إجازات',      'color': const Color(0xFFF44336)},
      {'key': 'exam',      'label': 'اختبارات',    'color': const Color(0xFF9C27B0)},
      {'key': 'other',     'label': 'أخرى',        'color': const Color(0xFF2196F3)},
    ];

    return Container(
      height: 44.h,
      color: const Color(0xFF0D1B2A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          final color = f['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _filter = f['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(left: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? color : Colors.white12,
                    width: isSelected ? 1.5 : 1),
              ),
              child: Text(f['label'] as String,
                  style: TextStyle(
                      color: isSelected ? color : Colors.white38,
                      fontSize: 12.sp,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, AcademicEvent event, String schoolId) {
    final isPast = event.date.isBefore(DateTime.now());
    final dateStr = intl.DateFormat('EEEE، d MMMM yyyy', 'ar').format(event.date);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isPast
            ? Colors.white.withValues(alpha: 0.03)
            : event.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isPast ? Colors.white12 : event.color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        leading: Container(
          width: 44.w, height: 44.w,
          decoration: BoxDecoration(
            color: (isPast ? Colors.white24 : event.color).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(event.icon,
              color: isPast ? Colors.white24 : event.color, size: 22.sp)),
        title: Text(event.title,
            style: TextStyle(
                color: isPast ? Colors.white38 : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                decoration: isPast ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white24)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr,
                style: TextStyle(
                    color: isPast ? Colors.white24 : Colors.white54,
                    fontSize: 11.sp)),
            if (event.endDate != null)
              Text('حتى: ${intl.DateFormat('d MMMM', 'ar').format(event.endDate!)}',
                  style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
            if (event.description != null && event.description!.isNotEmpty)
              Text(event.description!,
                  style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPast)
              Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 18.sp),
            SizedBox(width: 4.w),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white38, size: 18.sp),
              color: const Color(0xFF1B2A4A),
              onSelected: (v) {
                if (v == 'edit') _showEditEventDialog(context, event, schoolId);
                if (v == 'delete') _deleteEvent(context, event, schoolId);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Text('تعديل', style: TextStyle(color: Colors.white70)),
                    ])),
                const PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ])),
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
          Icon(Icons.calendar_month_outlined, color: Colors.white12, size: 64.sp),
          SizedBox(height: 16.h),
          Text('لا توجد أحداث بعد',
              style: TextStyle(color: Colors.white38, fontSize: 16.sp)),
          SizedBox(height: 8.h),
          Text('اضغط + لإضافة حدث جديد',
              style: TextStyle(color: Colors.white24, fontSize: 12.sp)),
        ],
      ),
    );
  }

  // ─── Add/Edit Dialog ──────────────────────────────────────────────────────
  Future<void> _showAddEventDialog(BuildContext context, String schoolId, String createdBy) async {
    await _showEventDialog(context, schoolId, createdBy, null);
  }

  Future<void> _showEditEventDialog(BuildContext context, AcademicEvent event, String schoolId) async {
    await _showEventDialog(context, schoolId, event.createdBy, event);
  }

  Future<void> _showEventDialog(BuildContext context, String schoolId,
      String createdBy, AcademicEvent? existing) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl  = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();
    DateTime? selectedEndDate = existing?.endDate;
    String selectedType = existing?.type ?? 'other';
    bool isSaving = false;

    final types = [
      {'key': 'termStart', 'label': 'بداية فصل دراسي', 'color': const Color(0xFF4CAF50)},
      {'key': 'termEnd',   'label': 'نهاية فصل دراسي',  'color': const Color(0xFFFF9800)},
      {'key': 'holiday',   'label': 'إجازة',              'color': const Color(0xFFF44336)},
      {'key': 'exam',      'label': 'اختبارات',           'color': const Color(0xFF9C27B0)},
      {'key': 'other',     'label': 'حدث آخر',            'color': const Color(0xFF2196F3)},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
                SizedBox(height: 16.h),
                Text(existing == null ? 'إضافة حدث جديد' : 'تعديل الحدث',
                    style: TextStyle(color: Colors.white, fontSize: 18.sp,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 20.h),

                // Title
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'عنوان الحدث',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 12.h),

                // Type
                Text('نوع الحدث', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w, runSpacing: 8.h,
                  children: types.map((t) {
                    final isSelected = selectedType == t['key'];
                    final color = t['color'] as Color;
                    return GestureDetector(
                      onTap: () => setS(() => selectedType = t['key'] as String),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? color : Colors.white12,
                              width: isSelected ? 1.5 : 1)),
                        child: Text(t['label'] as String,
                            style: TextStyle(
                                color: isSelected ? color : Colors.white38,
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12.h),

                // Date
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setS(() => selectedDate = d);
                  },
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                      SizedBox(width: 10.w),
                      Text(intl.DateFormat('yyyy/MM/dd').format(selectedDate),
                          style: const TextStyle(color: Colors.white)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.white38),
                    ]),
                  ),
                ),
                SizedBox(height: 8.h),

                // End Date (optional)
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedEndDate ?? selectedDate,
                      firstDate: selectedDate,
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setS(() => selectedEndDate = d);
                  },
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12)),
                    child: Row(children: [
                      const Icon(Icons.event_available, color: Colors.white38, size: 18),
                      SizedBox(width: 10.w),
                      Text(
                        selectedEndDate != null
                            ? 'تاريخ الانتهاء: ${intl.DateFormat('yyyy/MM/dd').format(selectedEndDate!)}'
                            : 'تاريخ الانتهاء (اختياري)',
                        style: TextStyle(
                            color: selectedEndDate != null ? Colors.white : Colors.white38,
                            fontSize: 13.sp)),
                      const Spacer(),
                      if (selectedEndDate != null)
                        GestureDetector(
                          onTap: () => setS(() => selectedEndDate = null),
                          child: const Icon(Icons.close, color: Colors.white38, size: 16)),
                    ]),
                  ),
                ),
                SizedBox(height: 12.h),

                // Description
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 20.h),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      setS(() => isSaving = true);
                      try {
                        final event = AcademicEvent(
                          id: existing?.id ?? '',
                          title: titleCtrl.text.trim(),
                          date: selectedDate,
                          endDate: selectedEndDate,
                          type: selectedType,
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          createdBy: createdBy,
                        );
                        final col = FirebaseFirestore.instance
                            .collection('Schools').doc(schoolId)
                            .collection('AcademicCalendar');
                        if (existing == null) {
                          await col.add(event.toMap());
                        } else {
                          await col.doc(existing.id).update(event.toMap());
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(existing == null ? 'تم إضافة الحدث ✅' : 'تم تحديث الحدث ✅'),
                            backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setS(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('حدث خطأ: $e'),
                            backgroundColor: Colors.red));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: isSaving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الحدث',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context, AcademicEvent event, String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        title: const Text('حذف الحدث', style: TextStyle(color: Colors.white)),
        content: Text('هل تريد حذف "${event.title}"؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('Schools').doc(schoolId)
        .collection('AcademicCalendar').doc(event.id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحدث'), backgroundColor: Colors.orange));
    }
  }
}
