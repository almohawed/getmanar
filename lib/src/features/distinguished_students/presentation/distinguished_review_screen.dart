import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/distinguished_service.dart';
import '../data/distinguished_repository.dart';
import '../domain/distinguished_cycle.dart';
import '../domain/distinguished_nomination.dart';

class DistinguishedReviewScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const DistinguishedReviewScreen({super.key, required this.schoolId});

  @override
  ConsumerState<DistinguishedReviewScreen> createState() =>
      _DistinguishedReviewScreenState();
}

class _DistinguishedReviewScreenState
    extends ConsumerState<DistinguishedReviewScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Trigger check for cycle logic on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(distinguishedStudentServiceProvider)
          .checkAndRunCycle(widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(distinguishedRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الطلاب المتميزين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(distinguishedStudentServiceProvider)
                  .checkAndRunCycle(widget.schoolId);
              setState(() {});
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<DistinguishedCycle?>(
            future: repo.getCurrentCycle(widget.schoolId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(
                  child: Text('لا توجد دورة ترشيح نشطة حالياً.'),
                );
              }

              final cycle = snapshot.data!;

              // Show different UI based on status
              if (cycle.status == CycleStatus.active) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      const Text(
                        'دورة الترشيح جارية...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('تنتهي في: ${_formatDate(cycle.endDate)}'),
                      const SizedBox(height: 24),
                      const Text('يقوم النظام بجمع البيانات حالياً.'),
                    ],
                  ),
                );
              }

              return _buildNominationsList(cycle);
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildNominationsList(DistinguishedCycle cycle) {
    final repo = ref.watch(distinguishedRepositoryProvider);

    return FutureBuilder<List<DistinguishedNomination>>(
      future: repo.getNominations(widget.schoolId, cycle.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لم يتم العثور على ترشيحات.'));
        }

        final nominations = snapshot.data!;
        // Group by Grade
        final byGrade = <String, List<DistinguishedNomination>>{};
        for (var nom in nominations) {
          byGrade.putIfAbsent(nom.gradeLevel, () => []).add(nom);
        }

        return Column(
          children: [
            if (cycle.status == CycleStatus.pendingDeputy)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.group),
                        label: const Text('تقييم المعلمين'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () => _startTeacherVoting(cycle),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.publish),
                        label: const Text('اعتماد ونشر'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () => _publishResults(cycle),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: byGrade.keys.length,
                itemBuilder: (context, index) {
                  final grade = byGrade.keys.elementAt(index);
                  final gradeNoms = byGrade[grade]!;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ExpansionTile(
                      title: Text('الصف: $grade (${gradeNoms.length})'),
                      initiallyExpanded: true,
                      children: gradeNoms
                          .map((nom) => _buildNominationTile(nom))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNominationTile(DistinguishedNomination nom) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getScoreColor(nom.score),
        foregroundColor: Colors.white,
        child: Text(nom.score.toInt().toString()),
      ),
      title: Text(nom.studentName),
      subtitle: Text(
        'نقاط السلوك: ${nom.behaviorScore.toInt()} | المعلمين: ${nom.approvedByTeacherIds.length} موافقة',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!nom.isFinal) // Allow rejection if not final
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _rejectNomination(nom),
              tooltip: 'رفض واستبدال',
            ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _rejectNomination(DistinguishedNomination nom) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطالب'),
        content: Text(
          'هل أنت متأكد من رفض الطالب ${nom.studentName}؟ سيتم استبداله تلقائياً بالطالب التالي في الترتيب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(distinguishedStudentServiceProvider)
            .rejectNominationAndReplace(widget.schoolId, nom.id);
        if (mounted) setState(() {}); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startTeacherVoting(DistinguishedCycle cycle) async {
    // Update cycle status to pending_teachers
    final updated = DistinguishedCycle(
      id: cycle.id,
      schoolId: cycle.schoolId,
      startDate: cycle.startDate,
      endDate: cycle.endDate,
      status: CycleStatus.pendingTeachers,
    );
    await ref
        .read(distinguishedRepositoryProvider)
        .updateCycle(widget.schoolId, updated);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم فتح باب التصويت للمعلمين')),
      );
    }
  }

  Future<void> _publishResults(DistinguishedCycle cycle) async {
    // Finalize cycle
    final updated = DistinguishedCycle(
      id: cycle.id,
      schoolId: cycle.schoolId,
      startDate: cycle.startDate,
      endDate: cycle.endDate,
      status: CycleStatus.published,
      publishedAt: DateTime.now(),
    );
    await ref
        .read(distinguishedRepositoryProvider)
        .updateCycle(widget.schoolId, updated);

    // Mark all current nominees as final?
    // Or filtering logic in service.
    // For MVP, assume current list is final.
    // Note: Nominations are considered final once published.
    // Future improvement: Explicitly update isFinal flag in database.

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر قائمة الطلاب المتميزين')),
      );
    }
  }
}
