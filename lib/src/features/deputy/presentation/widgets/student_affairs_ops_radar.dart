import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../student_affairs_providers.dart';

class StudentAffairsOpsRadar extends ConsumerWidget {
  const StudentAffairsOpsRadar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Bathroom Stats
    final bathroomAsync = ref.watch(bathroomStatsProvider);
    // 2. Late Stats
    final lateAsync = ref.watch(lateStatsProvider);
    // 3. Behavior Stats
    final behaviorAsync = ref.watch(behaviorStatsProvider);
    // 4. SMS Stats
    final smsAsync = ref.watch(smsStatsProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرادار التشغيلي (Student Affairs Ops Radar)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Bathroom Card
                _buildRadarCard(
                  title: 'تصاريح الحمام',
                  icon: Icons.wc,
                  color: Colors.blue,
                  content: bathroomAsync.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نشط: ${data['active']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'أحمر: ${data['redCount']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        Text(
                          'قريب: ${data['nearRedCount']}',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ'),
                  ),
                  onTap: () {
                    // Navigate to Bathroom Passes (if route exists)
                  },
                ),
                const SizedBox(width: 8),

                // Late Card
                _buildRadarCard(
                  title: 'التأخر اليوم',
                  icon: Icons.timer_off,
                  color: Colors.orange,
                  content: lateAsync.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي: ${data['totalLateToday']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'غير بعذر: ${data['unexcusedLateToday']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ'),
                  ),
                  onTap: () {
                    // Navigate to Late Report
                  },
                ),
                const SizedBox(width: 8),

                // Behavior Card
                _buildRadarCard(
                  title: 'السلوك',
                  icon: Icons.gavel,
                  color: Colors.red,
                  content: behaviorAsync.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مفتوح: ${data['open']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'تصعيد: ${data['escalationDue']}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ'),
                  ),
                  onTap: () {
                    // Navigate to Behavior
                  },
                ),
                const SizedBox(width: 8),

                // SMS Card
                _buildRadarCard(
                  title: 'SMS اليوم',
                  icon: Icons.sms,
                  color: Colors.green,
                  content: smsAsync.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q: ${data['queued']} / S: ${data['sent']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'F: ${data['failed']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('خطأ'),
                  ),
                  onTap: () {
                    // Navigate to SMS Log
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              content,
            ],
          ),
        ),
      ),
    );
  }
}
