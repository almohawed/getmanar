import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../school_intelligence_providers.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';

class SchoolHealthTab extends ConsumerStatefulWidget {
  const SchoolHealthTab({super.key});
  @override
  ConsumerState<SchoolHealthTab> createState() => _SchoolHealthTabState();
}

class _SchoolHealthTabState extends ConsumerState<SchoolHealthTab> {
  final _termCtrl = TextEditingController();

  @override
  void dispose() {
    _termCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termId = _termCtrl.text.trim().isEmpty ? 'current' : _termCtrl.text.trim();
    final snap = ref.watch(schoolIntelligenceSnapshotProvider(termId));
    return Column(
      children: [
        UnifiedToolbar(
          primaryAction: UnifiedAction(
            label: 'تحديث التحليل',
            icon: Icons.auto_awesome,
            onTap: () async {
              final t = _termCtrl.text.trim().isEmpty ? 'current' : _termCtrl.text.trim();
              await ref.read(computeIntelligenceProvider(ComputeIntelligenceParams(t)).future);
              ref.invalidate(schoolIntelligenceSnapshotProvider(t));
              ref.invalidate(riskPredictionsProvider);
              ref.invalidate(remedialPlansProvider(null));
            },
          ),
          extraActions: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _termCtrl,
                decoration: const InputDecoration(
                  labelText: 'الفصل الدراسي (اختياري)',
                  hintText: 'الحالي',
                ),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        Expanded(
          child: snap.when(
            data: (s) {
              if (s == null) {
                return const UnifiedEmptyState(
                  message: 'لا تتوفر بيانات لمؤشر صحة المدرسة حالياً. اضغط تحديث التحليل.',
                );
              }
              return ListView(
                children: [
                  ListTile(
                    title: const Text('مؤشر صحة المدرسة'),
                    trailing: Text('${s.schoolHealthScore.toStringAsFixed(1)} / 100',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(),
                  ListTile(title: const Text('فصول عالية المخاطر')),
                  ...s.riskClasses.map((c) => ListTile(leading: const Icon(Icons.warning), title: Text(c))),
                  const Divider(),
                  ListTile(title: const Text('مواد غير مستقرة')),
                  ...s.riskSubjects.map((c) => ListTile(leading: const Icon(Icons.troubleshoot), title: Text(c))),
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

class PredictionsTab extends ConsumerWidget {
  const PredictionsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preds = ref.watch(riskPredictionsProvider);
    return preds.when(
      data: (list) {
        if (list.isEmpty) return const UnifiedEmptyState(message: 'لا يوجد تنبؤات حالياً');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final color = p.riskLevel == 'RED'
                ? Colors.red
                : p.riskLevel == 'YELLOW'
                    ? Colors.orange
                    : Colors.green;
            return ListTile(
              leading: Icon(Icons.bolt, color: color),
              title: Text('${p.studentId} • ${p.subjectId}'),
              subtitle: Text('عوامل: ${p.riskFactors.join(", ")}'),
              trailing: Text(p.riskLevel),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => UnifiedEmptyState(message: 'خطأ: $e'),
    );
  }
}

class RemedialPlansTab extends ConsumerWidget {
  const RemedialPlansTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(remedialPlansProvider(null));
    return plans.when(
      data: (list) {
        if (list.isEmpty) return const UnifiedEmptyState(message: 'لا يوجد خطط علاجية');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final color = p.status == 'active' ? Colors.blue : p.status == 'done' ? Colors.green : Colors.orange;
            return ListTile(
              title: Text('${p.strategy} • ${p.causeType}'),
              subtitle: Text('طلاب: ${p.studentIds.join(", ")} • مسؤول: ${p.teacherId}'),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(p.status, style: TextStyle(color: color)),
                  Text('تحسن: ${p.improvementScore.toStringAsFixed(1)}'),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => UnifiedEmptyState(message: 'خطأ: $e'),
    );
  }
}
