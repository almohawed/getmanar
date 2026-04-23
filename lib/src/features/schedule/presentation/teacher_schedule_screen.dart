import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule_slot.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../admin/data/mock_class_repository.dart';

class TeacherScheduleScreen extends ConsumerStatefulWidget {
  final String? teacherId;

  const TeacherScheduleScreen({super.key, this.teacherId});

  @override
  ConsumerState<TeacherScheduleScreen> createState() =>
      _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends ConsumerState<TeacherScheduleScreen> {
  final ScrollController _horizontalController = ScrollController();
  Map<String, String> _subjectNameById = {};
  Map<String, String> _subjectIdByAlias = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) return;
      final data = await _loadSubjectCatalog(schoolId);
      if (!mounted) return;
      setState(() {
        _subjectNameById = data.$1;
        _subjectIdByAlias = data.$2;
      });
    });
  }

  String _normalizeKey(String s) {
    var v = s.trim().toLowerCase();
    v = v
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
    return v;
  }

  Future<(Map<String, String>, Map<String, String>)> _loadSubjectCatalog(
    String schoolId,
  ) async {
    final nameById = <String, String>{};
    final aliasLookup = <String, String>{};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Config')
          .doc('Subjects')
          .get();
      final data = doc.data();
      final subjects = data?['subjects'];
      if (subjects is Map<String, dynamic>) {
        for (final entry in subjects.entries) {
          final id = entry.key.trim();
          if (id.isEmpty) continue;
          aliasLookup[_normalizeKey(id)] = id;
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final name = (value['name'] ?? id).toString().trim();
            nameById[id] = name.isEmpty ? id : name;
            if (name.isNotEmpty) {
              aliasLookup[_normalizeKey(name)] = id;
            }
            final rawAliases = value['aliases'];
            if (rawAliases is List) {
              for (final a in rawAliases) {
                if (a == null) continue;
                final s = a.toString().trim();
                if (s.isEmpty) continue;
                aliasLookup[_normalizeKey(s)] = id;
              }
            }
          } else {
            nameById[id] = id;
          }
        }
      }
    } catch (_) {}
    return (nameById, aliasLookup);
  }

  String _subjectLabel(String subject) {
    final s = subject.trim();
    if (s.isEmpty) return subject;
    final id = _subjectIdByAlias[_normalizeKey(s)] ?? s;
    final name = _subjectNameById[id];
    if (name != null && name.trim().isNotEmpty) return name;
    final lower = s.toLowerCase();
    if (lower == 'arabic') return 'اللغة العربية';
    if (lower == 'math') return 'الرياضيات';
    if (lower == 'science') return 'العلوم';
    if (lower == 'islamic') return 'التربية الإسلامية';
    if (lower == 'quran') return 'القرآن الكريم';
    if (lower == 'english') return 'اللغة الإنجليزية';
    if (lower == 'social') return 'الاجتماعيات';
    if (lower == 'computer' || lower == 'cs') return 'الحاسب الآلي';
    if (lower == 'pe') return 'التربية البدنية';
    if (lower == 'art') return 'التربية الفنية';
    return subject;
  }

  String _classLabel(ScheduleSlot? slot) {
    if (slot == null) return 'لا فصل';
    final raw = slot.className.trim();
    if (raw.isEmpty) return 'لا فصل';
    return 'الفصل ${slot.className}';
  }

  String _todayArabic() {
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[DateTime.now().weekday - 1];
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final currentUserId = userAsync.value?.id;
    final classesAsync = ref.watch(classesProvider);

    final targetId = widget.teacherId ?? currentUserId;

    if (targetId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final scheduleAsync = ref.watch(teacherScheduleProvider(targetId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00796B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.teacherId != null ? 'جدول المعلم' : 'جدولي الدراسي',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            Text('الجدول الأسبوعي للحصص', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: scheduleAsync.when(
        data: (slots) {
          if (slots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF004D40).withOpacity(0.08), const Color(0xFF00796B).withOpacity(0.04)]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.calendar_today_outlined, size: 64.sp, color: const Color(0xFF00695C)),
                  ),
                  SizedBox(height: 20.h),
                  Text('لا يوجد جدول معتمد', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  SizedBox(height: 8.h),
                  Text('سيظهر الجدول هنا بعد اعتماده من الإدارة', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          final Map<String, List<ScheduleSlot>> grouped = {};
          final daysOrder = [
            'الأحد',
            'الاثنين',
            'الثلاثاء',
            'الأربعاء',
            'الخميس',
          ];

          final classesList = classesAsync.value ?? const [];
          final classNameById = <String, String>{
            for (final c in classesList) c.id: c.name,
          };

          for (var day in daysOrder) {
            grouped[day] = slots.where((s) => s.day == day).toList()
              ..sort((a, b) => a.period.compareTo(b.period));
          }

          final table = SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {
                0: const FixedColumnWidth(100),
                for (int i = 1; i <= 7; i++) i: const FixedColumnWidth(140),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF004D40), Color(0xFF00796B)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(10.w),
                      child: Text('اليوم', textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.sp)),
                    ),
                    for (int p = 1; p <= 7; p++)
                      Padding(
                        padding: EdgeInsets.all(10.w),
                        child: Text('الحصة $p', textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.sp)),
                      ),
                  ],
                ),
                ...daysOrder.map((day) {
                  final daySlots = grouped[day] ?? [];
                  final isToday = day == _todayArabic();
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isToday ? const Color(0xFF004D40).withOpacity(0.04) : Colors.white,
                    ),
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: isToday ? const Color(0xFF00695C) : Colors.grey.shade200, width: isToday ? 3 : 1)),
                        ),
                        child: Text(day, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.sp, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? const Color(0xFF004D40) : Colors.grey.shade700)),
                      ),
                      ...List.generate(7, (index) {
                        final period = index + 1;
                        final slot = daySlots.firstWhere(
                          (s) => s.period == period,
                          orElse: () => ScheduleSlot(
                            day: day,
                            period: period,
                            className: '',
                            subject: '',
                          ),
                        );
                        final hasSubject = slot.subject.trim().isNotEmpty;
                        final subjectText = hasSubject
                            ? _subjectLabel(slot.subject)
                            : 'لا حصة';
                        String classValue = slot.className.trim();
                        if (classValue.startsWith('Class ')) {
                          final id = classValue.substring(6);
                          final name = classNameById[id];
                          if (name != null && name.isNotEmpty) {
                            classValue = name;
                          } else {
                            classValue = '';
                          }
                        }
                        final classText = classValue.isEmpty
                            ? 'لا فصل'
                            : 'الفصل $classValue';
                        final isVacant = !hasSubject;

                        return Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Container(
                            height: 72.h,
                            decoration: BoxDecoration(
                              color: isVacant ? Colors.grey.shade50 : const Color(0xFF004D40).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: isVacant ? Colors.grey.shade200 : const Color(0xFF00695C).withOpacity(0.3),
                                width: isVacant ? 1 : 1.5,
                              ),
                            ),
                            padding: EdgeInsets.all(6.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isVacant ? Icons.remove_circle_outline : Icons.menu_book_rounded,
                                      size: 14.sp,
                                      color: isVacant ? Colors.grey.shade400 : const Color(0xFF004D40),
                                    ),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        subjectText,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isVacant ? Colors.grey.shade400 : Colors.grey.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isVacant) ...[
                                  SizedBox(height: 4.h),
                                  Text(
                                    classText,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.sp, color: const Color(0xFF00695C), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          );

          final tableWithScrollbar = RawScrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (_) => true,
            thickness: 8,
            radius: const Radius.circular(8),
            thumbColor: Colors.indigo,
            crossAxisMargin: 0,
            mainAxisMargin: 0,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: table,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [BoxShadow(color: const Color(0xFF004D40).withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00796B)], begin: Alignment.centerRight, end: Alignment.centerLeft),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16.r), topRight: Radius.circular(16.r)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_week_rounded, color: Colors.white, size: 20.sp),
                        SizedBox(width: 10.w),
                        Text(
                          widget.teacherId != null ? 'جدول المعلم' : 'جدولي الدراسي',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.w),
                    child: tableWithScrollbar,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('حدث خطأ: $err')),
      ),
    );
  }
}
