import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exams_providers.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';

class ExamCommitteesTab extends ConsumerStatefulWidget {
  const ExamCommitteesTab({super.key});
  @override
  ConsumerState<ExamCommitteesTab> createState() => _ExamCommitteesTabState();
}

class _ExamCommitteesTabState extends ConsumerState<ExamCommitteesTab> {
  String? _termId;
  @override
  Widget build(BuildContext context) {
    final committees = ref.watch(committeesProvider(_termId));
    return Column(
      children: [
        UnifiedToolbar(
          onFilter: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _CommitteeFilterSheet(
                initialTerm: _termId,
                onApply: (t) => setState(() => _termId = t),
              ),
            );
          },
          primaryAction: UnifiedAction(
            label: 'إنشاء لجنة',
            icon: Icons.add,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const _CreateCommitteeDialog(),
            ),
          ),
        ),
        Expanded(
          child: committees.when(
            data: (list) {
              final records = (list as List<dynamic>);
              if (records.isEmpty) {
                return UnifiedEmptyState(
                  message: 'لا توجد لجان اختبارات مسجلة بعد.',
                  action: UnifiedAction(
                    label: 'إنشاء لجنة جديدة',
                    icon: Icons.add,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const _CreateCommitteeDialog(),
                    ),
                  ),
                );
              }

              final total = records.length;
              final complete =
                  records.where((c) => c.status == 'complete').length;
              final incomplete =
                  records.where((c) => c.status == 'incomplete').length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'إجمالي اللجان',
                            value: '$total',
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'مكتملة الجاهزية',
                            value: '$complete',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExamMetricCard(
                            title: 'بحاجة إكمال',
                            value: '$incomplete',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = records[i];
                        final isIncomplete = c.status == 'incomplete';
                        final dateLabel =
                            c.date.toString().split(' ').first;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncomplete
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            child: Icon(
                              Icons.group,
                              color: isIncomplete
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          title: Text(
                            '$dateLabel • ${c.startTime}-${c.endTime} • قاعة ${c.roomId}',
                          ),
                          subtitle: Text(
                            'مشرف: ${c.supervisorId} • فصول: ${c.assignedClassIds.join(', ')}',
                          ),
                          trailing: Icon(
                            isIncomplete
                                ? Icons.error_outline
                                : Icons.check_circle,
                            color:
                                isIncomplete ? Colors.orange : Colors.green,
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
}

class _CommitteeFilterSheet extends StatefulWidget {
  final String? initialTerm;
  final void Function(String?) onApply;
  const _CommitteeFilterSheet({this.initialTerm, required this.onApply});
  @override
  State<_CommitteeFilterSheet> createState() => _CommitteeFilterSheetState();
}

class _CommitteeFilterSheetState extends State<_CommitteeFilterSheet> {
  late TextEditingController _termCtrl;
  @override
  void initState() {
    super.initState();
    _termCtrl = TextEditingController(text: widget.initialTerm ?? '');
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
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              widget.onApply(_termCtrl.text.isEmpty ? null : _termCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _CreateCommitteeDialog extends ConsumerStatefulWidget {
  const _CreateCommitteeDialog();
  @override
  ConsumerState<_CreateCommitteeDialog> createState() =>
      _CreateCommitteeDialogState();
}

class _CreateCommitteeDialogState
    extends ConsumerState<_CreateCommitteeDialog> {
  final _term = TextEditingController();
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '09:00');
  final _room = TextEditingController();
  final _supervisor = TextEditingController();
  final _backup = TextEditingController();
  final _classes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء لجنة'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'termId'),
              controller: _term,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'startTime HH:mm'),
              controller: _start,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'endTime HH:mm'),
              controller: _end,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'roomId'),
              controller: _room,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'supervisorId'),
              controller: _supervisor,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'backupSupervisorId',
              ),
              controller: _backup,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'classIds (comma separated)',
              ),
              controller: _classes,
            ),
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
              await ref.read(
                createCommitteeProvider(
                  CreateCommitteeParams(
                    termId: _term.text,
                    date: _date,
                    startTime: _start.text,
                    endTime: _end.text,
                    roomId: _room.text,
                    supervisorId: _supervisor.text,
                    backupSupervisorId: _backup.text.isEmpty
                        ? null
                        : _backup.text,
                    assignedClassIds: _classes.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ).future,
              );
              if (mounted) Navigator.pop(context);
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
