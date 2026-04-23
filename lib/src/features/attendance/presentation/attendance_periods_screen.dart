import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AttendancePeriodsScreen extends StatelessWidget {
  final String day;
  const AttendancePeriodsScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تحضير $day - اختيار الحصة'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 7,
        itemBuilder: (context, index) {
          final period = index + 1;
          return Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                context.push(
                  '/teacher-attendance',
                  extra: {'day': day, 'period': period},
                );
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time, size: 32, color: Colors.indigo),
                    const SizedBox(height: 8),
                    Text(
                      'الحصة $period',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
