import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')

dart = """\
/// wait_management_screen.dart
/// جدول الانتظار الذكي — توزيع عادل حسب النصاب
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFFF8FAFF);
  static const surface  = Colors.white;
  static const primary  = Color(0xFF4F46E5);  // indigo
  static const accent   = Color(0xFF06B6D4);  // cyan
  static const emerald  = Color(0xFF10B981);
  static const amber    = Color(0xFFF59E0B);
  static const rose     = Color(0xFFF43F5E);
  static const violet   = Color(0xFF8B5CF6);
  static const border   = Color(0xFFE2E8F0);
  static const text     = Color(0xFF1E293B);
  static const muted    = Color(0xFF64748B);
  static const card     = Color(0xFFFFFFFF);
}

// ─── Model ───────────────────────────────────────────────────────────────────
class _WaitSlot {
  final String day;
  final int period;
  String teacherId;
  String teacherName;
  bool isManual;

  _WaitSlot({
    required this.day,
    required this.period,
    required this.teacherId,
    required this.teacherName,
    this.isManual = false,
  });

  Map<String, dynamic> toMap() => {
    'day': day, 'period': period,
    'teacherId': teacherId, 'teacherName': teacherName,
    'isManual': isManual,
  };
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class WaitManagementScreen extends ConsumerStatefulWidget {
  const WaitManagementScreen({super.key});
  @override
  ConsumerState<WaitManagementScreen> createState() => _WaitManagementScreenState();
}

class _WaitManagementScreenState extends ConsumerState<WaitManagementScreen>
    with SingleTickerProviderStateMixin {
  String? _schoolId;
  List<Map<String, dynamic>> _teachers = [];
  // schedule[day][period] = _WaitSlot
  Map<String, Map<int, _WaitSlot>> _schedule = {};
  bool _isLoading = false;
  bool _isSaving = false;
  String? _filterDay;
  int? _filterPeriod;
  late AnimationController _animCtrl;

  final List<String> _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final int _periodsPerDay = 7;

  // ألوان الأيام
  final List<Color> _dayColors = [
    const Color(0xFF4F46E5), // indigo
    const Color(0xFF06B6D4), // cyan
    const Color(0xFF10B981), // emerald
    const Color(0xFFF59E0B), // amber
    const Color(0xFF8B5CF6), // violet
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        setState(() => _schoolId = user.schoolId);
        _loadData();
      }
    });
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      // جلب المعلمين
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Teachers').get();
      _teachers = teachersSnap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? '').toString(),
          'maxWeeklyClasses': (data['maxWeeklyClasses'] ?? 24) as int,
          'subject': (data['primarySubjectId'] ?? '').toString(),
        };
      }).where((t) => (t['name'] as String).isNotEmpty).toList();

      // جلب الجدول المحفوظ
      final waitSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId)
          .collection('WaitSchedule').doc('current').get();

      if (waitSnap.exists) {
        final slots = (waitSnap.data()?['slots'] as List<dynamic>?) ?? [];
        _schedule = {};
        for (final s in slots) {
          final day = s['day'] as String;
          final period = s['period'] as int;
          _schedule.putIfAbsent(day, () => {});
          _schedule[day]![period] = _WaitSlot(
            day: day, period: period,
            teacherId: s['teacherId'] ?? '',
            teacherName: s['teacherName'] ?? '',
            isManual: s['isManual'] == true,
          );
        }
      } else {
        _generateSchedule();
      }
    } catch (e) {
      debugPrint('Error loading wait data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// خوارزمية التوزيع الذكي
  void _generateSchedule() {
    if (_teachers.isEmpty) return;

    // حساب عدد الحصص لكل معلم في الجدول الأساسي
    final teacherLoad = <String, int>{};
    for (final t in _teachers) {
      teacherLoad[t['id'] as String] = 0;
    }

    // إجمالي خانات الانتظار = 5 أيام × 7 حصص = 35
    final totalSlots = _days.length * _periodsPerDay;

    // توزيع المعلمين بالتساوي حسب نصابهم
    // المعلم ذو النصاب الأعلى يحصل على انتظارات أقل
    final sortedTeachers = List<Map<String, dynamic>>.from(_teachers)
      ..sort((a, b) {
        final aMax = a['maxWeeklyClasses'] as int;
        final bMax = b['maxWeeklyClasses'] as int;
        return bMax.compareTo(aMax); // الأعلى نصاباً أولاً
      });

    // توزيع دوري عادل
    _schedule = {};
    int teacherIndex = 0;
    final assignedCount = <String, int>{};
    for (final t in _teachers) assignedCount[t['id'] as String] = 0;

    for (final day in _days) {
      _schedule[day] = {};
      for (int period = 1; period <= _periodsPerDay; period++) {
        // اختر المعلم الأقل انتظاراً مع مراعاة عدم التكرار في نفس اليوم
        final usedToday = _schedule[day]!.values.map((s) => s.teacherId).toSet();

        // ابحث عن معلم لم يُستخدم اليوم بعد
        Map<String, dynamic>? chosen;
        int minCount = 999;

        for (final t in sortedTeachers) {
          final tid = t['id'] as String;
          if (usedToday.contains(tid)) continue;
          final count = assignedCount[tid] ?? 0;
          if (count < minCount) {
            minCount = count;
            chosen = t;
          }
        }

        // إذا كل المعلمين استُخدموا اليوم، اختر الأقل انتظاراً
        if (chosen == null) {
          for (final t in sortedTeachers) {
            final tid = t['id'] as String;
            final count = assignedCount[tid] ?? 0;
            if (count < minCount) {
              minCount = count;
              chosen = t;
            }
          }
        }

        if (chosen != null) {
          final tid = chosen['id'] as String;
          _schedule[day]![period] = _WaitSlot(
            day: day, period: period,
            teacherId: tid,
            teacherName: chosen['name'] as String,
          );
          assignedCount[tid] = (assignedCount[tid] ?? 0) + 1;
        }
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (_schoolId == null) return;
    setState(() => _isSaving = true);
    try {
      final slots = <Map<String, dynamic>>[];
      for (final day in _schedule.keys) {
        for (final slot in _schedule[day]!.values) {
          slots.add(slot.toMap());
        }
      }
      await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId)
          .collection('WaitSchedule').doc('current')
          .set({'slots': slots, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم حفظ جدول الانتظار'),
          backgroundColor: _C.emerald,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: _C.rose,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editSlot(String day, int period) {
    final slot = _schedule[day]?[period];
    String? selectedId = slot?.teacherId;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل: $day — الحصة $period',
            style: const TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 15)),
        content: StatefulBuilder(
          builder: (ctx, setS) => SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: InputDecoration(
                  labelText: 'اختر المعلم',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: _C.bg,
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('— فارغ —')),
                  ..._teachers.map((t) => DropdownMenuItem(
                    value: t['id'] as String,
                    child: Text(t['name'] as String),
                  )),
                ],
                onChanged: (v) => setS(() => selectedId = v),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: _C.muted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (selectedId == null) {
                  _schedule[day]?.remove(period);
                } else {
                  final teacher = _teachers.firstWhere((t) => t['id'] == selectedId);
                  _schedule.putIfAbsent(day, () => {});
                  _schedule[day]![period] = _WaitSlot(
                    day: day, period: period,
                    teacherId: selectedId!,
                    teacherName: teacher['name'] as String,
                    isManual: true,
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _buildTopBar(),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _C.primary)))
        else
          Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      decoration: BoxDecoration(
        color: _C.surface,
        border: const Border(bottom: BorderSide(color: _C.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.muted, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.primary, _C.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('جدول الانتظار', style: TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('توزيع ذكي حسب النصاب', style: TextStyle(color: _C.muted, fontSize: 11)),
        ])),
        // Stats
        _statBadge(_teachers.length.toString(), 'معلم', _C.primary),
        const SizedBox(width: 8),
        _statBadge((_days.length * _periodsPerDay).toString(), 'خانة', _C.accent),
        const SizedBox(width: 12),
        // Actions
        ElevatedButton.icon(
          onPressed: () { setState(() => _generateSchedule()); },
          icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
          label: const Text('توزيع تلقائي', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.bg, foregroundColor: _C.primary,
            side: const BorderSide(color: _C.primary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveSchedule,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 15),
          label: const Text('حفظ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.emerald, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
      ]),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildStatsRow(),
        const SizedBox(height: 20),
        _buildScheduleGrid(),
        const SizedBox(height: 20),
        _buildTeacherLoadSummary(),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildStatsRow() {
    // حساب إحصاءات التوزيع
    final teacherCount = <String, int>{};
    for (final day in _schedule.values) {
      for (final slot in day.values) {
        teacherCount[slot.teacherName] = (teacherCount[slot.teacherName] ?? 0) + 1;
      }
    }
    final maxLoad = teacherCount.values.isEmpty ? 0 : teacherCount.values.reduce((a, b) => a > b ? a : b);
    final minLoad = teacherCount.values.isEmpty ? 0 : teacherCount.values.reduce((a, b) => a < b ? a : b);
    final manualCount = _schedule.values.expand((d) => d.values).where((s) => s.isManual).length;

    return Row(children: [
      _infoCard('أقصى حمل', '$maxLoad حصة', _C.rose, Icons.trending_up_rounded),
      const SizedBox(width: 12),
      _infoCard('أدنى حمل', '$minLoad حصة', _C.emerald, Icons.trending_down_rounded),
      const SizedBox(width: 12),
      _infoCard('تعديلات يدوية', '$manualCount', _C.amber, Icons.edit_rounded),
      const SizedBox(width: 12),
      _infoCard('المعلمون', '${teacherCount.length}', _C.primary, Icons.people_rounded),
    ]);
  }

  Widget _infoCard(String label, String value, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: _C.muted, fontSize: 10)),
        ]),
      ]),
    ));
  }

  Widget _buildScheduleGrid() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_C.primary.withOpacity(0.06), _C.accent.withOpacity(0.04)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: const Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Container(width: 60, child: const Text('الحصة', style: TextStyle(color: _C.muted, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            ...List.generate(_days.length, (i) => Expanded(child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _dayColors[i].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_days[i], style: TextStyle(color: _dayColors[i], fontSize: 12, fontWeight: FontWeight.bold)),
            )))),
          ]),
        ),
        // Rows
        ...List.generate(_periodsPerDay, (periodIdx) {
          final period = periodIdx + 1;
          return Container(
            decoration: BoxDecoration(
              color: periodIdx % 2 == 0 ? Colors.white : const Color(0xFFFAFBFF),
              border: const Border(bottom: BorderSide(color: _C.border, width: 0.5)),
            ),
            child: Row(children: [
              // Period number
              Container(
                width: 60, height: 64,
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.06),
                  border: const Border(right: BorderSide(color: _C.border, width: 0.5)),
                ),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$period', style: const TextStyle(color: _C.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('حصة', style: TextStyle(color: _C.muted, fontSize: 9)),
                ])),
              ),
              // Day cells
              ...List.generate(_days.length, (dayIdx) {
                final day = _days[dayIdx];
                final slot = _schedule[day]?[period];
                final dayColor = _dayColors[dayIdx];
                return Expanded(child: GestureDetector(
                  onTap: () => _editSlot(day, period),
                  child: Container(
                    height: 64,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: slot != null
                          ? dayColor.withOpacity(slot.isManual ? 0.15 : 0.08)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: slot != null ? dayColor.withOpacity(0.3) : _C.border,
                        width: slot?.isManual == true ? 1.5 : 1,
                      ),
                    ),
                    child: slot != null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            if (slot.isManual)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: _C.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('يدوي', style: TextStyle(color: _C.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                _shortName(slot.teacherName),
                                style: TextStyle(color: dayColor, fontSize: 10, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ])
                        : Center(child: Icon(Icons.add_rounded, color: _C.border, size: 18)),
                  ),
                ));
              }),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildTeacherLoadSummary() {
    final teacherCount = <String, int>{};
    final teacherIds = <String, String>{};
    for (final day in _schedule.values) {
      for (final slot in day.values) {
        teacherCount[slot.teacherName] = (teacherCount[slot.teacherName] ?? 0) + 1;
        teacherIds[slot.teacherName] = slot.teacherId;
      }
    }
    if (teacherCount.isEmpty) return const SizedBox.shrink();

    final sorted = teacherCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.primary, _C.accent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('توزيع الحمل على المعلمين', style: TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        ...sorted.map((e) {
          final pct = e.value / maxVal;
          final color = pct > 0.8 ? _C.rose : pct > 0.5 ? _C.amber : _C.emerald;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 140, child: Text(e.key, style: const TextStyle(color: _C.text, fontSize: 12), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 10),
              Expanded(child: Stack(children: [
                Container(height: 8, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 8, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(4),
                  )),
                ),
              ])),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${e.value} حصة', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return name;
  }
}
"""

p.write_text(dart, encoding='utf-8')
print('Done - wait_management_screen.dart written')
