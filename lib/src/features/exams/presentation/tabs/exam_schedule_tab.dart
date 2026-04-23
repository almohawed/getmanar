import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exams_providers.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';

class ExamScheduleTab extends ConsumerStatefulWidget {
  const ExamScheduleTab({super.key});
  @override
  ConsumerState<ExamScheduleTab> createState() => _ExamScheduleTabState();
}

class _ExamScheduleTabState extends ConsumerState<ExamScheduleTab> {
  String? _termId;
  String? _classId;
  String? _subjectId;
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(
      examSchedulesProvider(
        ExamScheduleFilters(
          termId: _termId,
          classId: _classId,
          subjectId: _subjectId,
          date: _date,
        ),
      ),
    );
    return Column(
      children: [
        UnifiedToolbar(
          onFilter: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _ScheduleFiltersSheet(
                termId: _termId,
                classId: _classId,
                subjectId: _subjectId,
                onApply: (t, c, s, d) => setState(() {
                  _termId = t;
                  _classId = c;
                  _subjectId = s;
                  _date = d;
                }),
              ),
            );
          },
          primaryAction: UnifiedAction(
            label: 'إنشاء اختبار',
            icon: Icons.add,
            onTap: () => _openCreateDialog(context),
          ),
        ),
        Expanded(
          child: schedules.when(
            data: (list) {
              final records = (list as List<dynamic>);
              if (records.isEmpty) {
                return UnifiedEmptyState(
                  message: 'لا توجد اختبارات مجدولة بعد.',
                  action: UnifiedAction(
                    label: 'إنشاء اختبار جديد',
                    icon: Icons.add,
                    onTap: () => _openCreateDialog(context),
                  ),
                );
              }

              final total = records.length;
              final published =
                  records.where((e) => e.status == 'published').length;
              final drafts =
                  records.where((e) => e.status == 'draft').length;
              final today = records
                  .where(
                    (e) =>
                        e.date.year == DateTime.now().year &&
                        e.date.month == DateTime.now().month &&
                        e.date.day == DateTime.now().day,
                  )
                  .length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'إجمالي الاختبارات',
                            value: '$total',
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'منشور',
                            value: '$published',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'مسودة',
                            value: '$drafts',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (today > 0)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: _ExamMetricCard(
                        title: 'اختبارات اليوم',
                        value: '$today',
                        color: Colors.indigo,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = records[i];
                        final draft = e.status == 'draft';
                        final dateLabel =
                            e.date.toString().split(' ').first;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                draft ? Colors.orange.shade50 : Colors.teal.shade50,
                            child: Icon(
                              draft ? Icons.pending_actions : Icons.event_available,
                              color: draft ? Colors.orange : Colors.teal,
                            ),
                          ),
                          title: Text(
                            '${e.subjectId} • ${e.examType}',
                          ),
                          subtitle: Text(
                            '$dateLabel • ${e.startTime}-${e.endTime} • فصل ${e.classId} • قاعة ${e.roomId}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (draft)
                                IconButton(
                                  tooltip: 'نشر الجدول',
                                  icon: const Icon(Icons.publish),
                                  onPressed: () async {
                                    await ref.read(
                                      publishScheduleProvider(e.id).future,
                                    );
                                  },
                                ),
                              IconButton(
                                tooltip: 'تعديل',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _openAmendDialog(context, e.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => UnifiedEmptyState(message: 'خطأ: $e'),
          ),
        ),
      ],
    );
  }

  void _openCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateScheduleDialog(
        defaultTerm: _termId,
        defaultClass: _classId,
        defaultSubject: _subjectId,
      ),
    );
  }

  void _openAmendDialog(BuildContext context, String scheduleId) {
    showDialog(
      context: context,
      builder: (_) => _AmendScheduleDialog(scheduleId: scheduleId),
    );
  }
}

class _ScheduleFiltersSheet extends StatefulWidget {
  final String? termId;
  final String? classId;
  final String? subjectId;
  final void Function(String?, String?, String?, DateTime?) onApply;
  const _ScheduleFiltersSheet({
    required this.termId,
    required this.classId,
    required this.subjectId,
    required this.onApply,
  });
  @override
  State<_ScheduleFiltersSheet> createState() => _ScheduleFiltersSheetState();
}

class _ScheduleFiltersSheetState extends State<_ScheduleFiltersSheet> {
  late TextEditingController _termCtrl;
  late TextEditingController _classCtrl;
  late TextEditingController _subjectCtrl;
  DateTime? _date;
  @override
  void initState() {
    super.initState();
    _termCtrl = TextEditingController(text: widget.termId ?? '');
    _classCtrl = TextEditingController(text: widget.classId ?? '');
    _subjectCtrl = TextEditingController(text: widget.subjectId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'termId'),
            controller: _termCtrl,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'classId'),
            controller: _classCtrl,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'subjectId'),
            controller: _subjectCtrl,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now();
              _date = DateTime(now.year, now.month, now.day);
              setState(() {});
            },
            child: Text(
              _date == null ? 'تحديد تاريخ' : _date.toString().split(' ').first,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              widget.onApply(
                _termCtrl.text.isEmpty ? null : _termCtrl.text,
                _classCtrl.text.isEmpty ? null : _classCtrl.text,
                _subjectCtrl.text.isEmpty ? null : _subjectCtrl.text,
                _date,
              );
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _CreateScheduleDialog extends ConsumerStatefulWidget {
  final String? defaultTerm;
  final String? defaultClass;
  final String? defaultSubject;
  const _CreateScheduleDialog({
    this.defaultTerm,
    this.defaultClass,
    this.defaultSubject,
  });
  @override
  ConsumerState<_CreateScheduleDialog> createState() =>
      _CreateScheduleDialogState();
}

class _CreateScheduleDialogState extends ConsumerState<_CreateScheduleDialog> {
  final _term = TextEditingController();
  final _stage = TextEditingController();
  final _grade = TextEditingController();
  final _class = TextEditingController();
  final _subject = TextEditingController();
  final _teacher = TextEditingController();
  final _type = TextEditingController(text: 'final');
  final _room = TextEditingController();
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '09:00');
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _term.text = widget.defaultTerm ?? '';
    _class.text = widget.defaultClass ?? '';
    _subject.text = widget.defaultSubject ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء اختبار'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'termId'),
              controller: _term,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'stage'),
              controller: _stage,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'grade'),
              controller: _grade,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'classId'),
              controller: _class,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'subjectId'),
              controller: _subject,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'teacherId'),
              controller: _teacher,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'examType'),
              controller: _type,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'roomId'),
              controller: _room,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'startTime HH:mm'),
              controller: _start,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'endTime HH:mm'),
              controller: _end,
            ),
            const SizedBox(height: 8),
            Text('تاريخ: ${_date.toString().split(' ').first}'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
            try {
              final id = await ref.read(
                createScheduleProvider(
                  CreateScheduleParams(
                    termId: _term.text,
                    stage: _stage.text,
                    grade: _grade.text,
                    classId: _class.text,
                    subjectId: _subject.text,
                    teacherId: _teacher.text,
                    examType: _type.text,
                    date: _date,
                    startTime: _start.text,
                    endTime: _end.text,
                    roomId: _room.text,
                  ),
                ).future,
              );
              if (mounted) Navigator.pop(context, id);
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ExamMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ExamMetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmendScheduleDialog extends ConsumerStatefulWidget {
  final String scheduleId;
  const _AmendScheduleDialog({required this.scheduleId});
  @override
  ConsumerState<_AmendScheduleDialog> createState() =>
      _AmendScheduleDialogState();
}

class _AmendScheduleDialogState extends ConsumerState<_AmendScheduleDialog> {
  final _reason = TextEditingController();
  final _room = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String? _error;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل جدول منشور'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'سبب التعديل'),
            controller: _reason,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'قاعة جديدة (اختياري)',
            ),
            controller: _room,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'بداية جديدة HH:mm'),
            controller: _start,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'نهاية جديدة HH:mm'),
            controller: _end,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final changes = <String, dynamic>{};
              if (_room.text.isNotEmpty) changes['roomId'] = _room.text;
              if (_start.text.isNotEmpty) changes['startTime'] = _start.text;
              if (_end.text.isNotEmpty) changes['endTime'] = _end.text;
              await ref.read(
                amendScheduleProvider(
                  AmendScheduleParams(
                    scheduleId: widget.scheduleId,
                    changes: changes,
                    reason: _reason.text,
                  ),
                ).future,
              );
              if (mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: const Text('تسجيل تعديل'),
        ),
      ],
    );
  }
}
