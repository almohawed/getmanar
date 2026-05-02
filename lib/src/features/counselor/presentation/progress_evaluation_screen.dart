import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'counselor_providers.dart';

class ProgressEvaluationScreen extends ConsumerWidget {
  const ProgressEvaluationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCasesAsync = ref.watch(activeCasesProvider);
    final activePlansAsync = ref.watch(activePlansProvider);
    final todaySessionsAsync = ref.watch(todaySessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم التقدم'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _showPrintPreview(context, ref),
            tooltip: 'طباعة التقرير',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCasesProvider);
          ref.invalidate(activePlansProvider);
          ref.invalidate(todaySessionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStatisticsSection(
                activeCasesAsync,
                activePlansAsync,
                todaySessionsAsync,
              ),
              const SizedBox(height: 24),
              _buildDetailsSection(
                activeCasesAsync,
                activePlansAsync,
                todaySessionsAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final formatter = intl.DateFormat('EEEE، d MMMM yyyy', 'ar_SA');
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقرير تقييم التقدم',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatter.format(now),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(
    AsyncValue activeCasesAsync,
    AsyncValue activePlansAsync,
    AsyncValue todaySessionsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الإحصائيات الحالية',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'الحالات النشطة',
                asyncValue: activeCasesAsync,
                icon: Icons.folder_open,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'الخطط النشطة',
                asyncValue: activePlansAsync,
                icon: Icons.assignment,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          title: 'جلسات اليوم',
          asyncValue: todaySessionsAsync,
          icon: Icons.event,
          color: Colors.green,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required AsyncValue asyncValue,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            asyncValue.when(
              data: (data) {
                final count = (data as List).length;
                return Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, stack) => Text(
                'خطأ',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(
    AsyncValue activeCasesAsync,
    AsyncValue activePlansAsync,
    AsyncValue todaySessionsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التفاصيل',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          title: 'الحالات النشطة',
          asyncValue: activeCasesAsync,
          icon: Icons.folder_open,
          color: Colors.blue,
          emptyMessage: 'لا توجد حالات نشطة حالياً',
          itemBuilder: (item) {
            final studentCase = item as dynamic;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(studentCase.studentName ?? 'طالب'),
              subtitle: Text(studentCase.title ?? ''),
              trailing: Chip(
                label: Text(
                  _getCaseStatusText(studentCase.status.name),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getCaseStatusColor(studentCase.status.name),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          title: 'الخطط النشطة',
          asyncValue: activePlansAsync,
          icon: Icons.assignment,
          color: Colors.orange,
          emptyMessage: 'لا توجد خطط نشطة حالياً',
          itemBuilder: (item) {
            final plan = item as dynamic;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(Icons.assignment, color: Colors.orange),
              ),
              title: Text(plan.studentName ?? 'طالب'),
              subtitle: Text(plan.title ?? ''),
              trailing: Text(
                '${plan.goals?.length ?? 0} أهداف',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          title: 'جلسات اليوم',
          asyncValue: todaySessionsAsync,
          icon: Icons.event,
          color: Colors.green,
          emptyMessage: 'لا توجد جلسات مجدولة اليوم',
          itemBuilder: (item) {
            final session = item as dynamic;
            final time = intl.DateFormat('HH:mm', 'ar_SA').format(
              session.scheduledAt ?? DateTime.now(),
            );
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: Icon(
                  session.isConfidential ? Icons.lock : Icons.event,
                  color: Colors.green,
                ),
              ),
              title: Text(session.title ?? 'جلسة'),
              subtitle: Text('الوقت: $time'),
              trailing: Chip(
                label: Text(
                  _getSessionStatusText(session.status.name),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getSessionStatusColor(session.status.name),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required String title,
    required AsyncValue asyncValue,
    required IconData icon,
    required Color color,
    required String emptyMessage,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            asyncValue.when(
              data: (data) {
                final items = data as List;
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        emptyMessage,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.map((item) => itemBuilder(item)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'حدث خطأ في تحميل البيانات',
                    style: TextStyle(color: Colors.red[300]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCaseStatusText(String status) {
    switch (status) {
      case 'open':
        return 'مفتوحة';
      case 'in_progress':
        return 'قيد المعالجة';
      case 'resolved':
        return 'محلولة';
      case 'closed':
        return 'مغلقة';
      default:
        return status;
    }
  }

  Color _getCaseStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange.withOpacity(0.2);
      case 'in_progress':
        return Colors.blue.withOpacity(0.2);
      case 'resolved':
        return Colors.green.withOpacity(0.2);
      case 'closed':
        return Colors.grey.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  String _getSessionStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'مجدولة';
      case 'in_progress':
        return 'جارية';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  Color _getSessionStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.withOpacity(0.2);
      case 'in_progress':
        return Colors.orange.withOpacity(0.2);
      case 'completed':
        return Colors.green.withOpacity(0.2);
      case 'cancelled':
        return Colors.red.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  void _showPrintPreview(BuildContext context, WidgetRef ref) {
    final activeCasesAsync = ref.read(activeCasesProvider);
    final activePlansAsync = ref.read(activePlansProvider);
    final todaySessionsAsync = ref.read(todaySessionsProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة الطباعة'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تقرير تقييم التقدم',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'التاريخ: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  style: const TextStyle(fontSize: 14),
                ),
                const Divider(height: 24),
                _buildPrintStat('الحالات النشطة', activeCasesAsync),
                _buildPrintStat('الخطط النشطة', activePlansAsync),
                _buildPrintStat('جلسات اليوم', todaySessionsAsync),
                const SizedBox(height: 16),
                const Text(
                  'ملاحظة: هذه معاينة بسيطة. للحصول على تقرير PDF كامل، يمكن إضافة مكتبة الطباعة.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم إضافة وظيفة الطباعة قريباً'),
                ),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintStat(String label, AsyncValue asyncValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          asyncValue.when(
            data: (data) => Text('${(data as List).length}'),
            loading: () => const Text('...'),
            error: (_, __) => const Text('خطأ'),
          ),
        ],
      ),
    );
  }
}
