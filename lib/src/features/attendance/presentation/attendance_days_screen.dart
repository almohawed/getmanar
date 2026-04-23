import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AttendanceDaysScreen extends StatelessWidget {
  const AttendanceDaysScreen({super.key});

  final List<String> _days = const [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحضير المعلمين - اختيار اليوم')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _days.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final day = _days[index];
          return Card(
            elevation: 2,
            child: ListTile(
              title: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                context.push('/attendance-periods', extra: day);
              },
            ),
          );
        },
      ),
    );
  }
}
