import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class PlanDetailsScreen extends StatelessWidget {
  final String planId;

  const PlanDetailsScreen({
    required this.planId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الخطة'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('education_plans')
            .doc(planId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('لم يتم العثور على الخطة'),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final planName = data['planName'] ?? data['title'] ?? 'خطة';
          final studentName = data['studentName'] ?? 'طالب';
          final status = data['status'] ?? 'active';
          final goals = List<String>.from(data['goals'] ?? []);
          final interventions = data['interventions'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان الخطة
                Text(
                  planName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الطالب: $studentName',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(status == 'active' ? 'نشطة' : 'مكتملة'),
                  backgroundColor: status == 'active' ? Colors.green : Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),

                // الأهداف
                if (goals.isNotEmpty) ...[
                  const Text(
                    'الأهداف',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...goals.map((goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $goal'),
                  )),
                  const SizedBox(height: 24),
                ],

                // التدخلات
                if (interventions.isNotEmpty) ...[
                  const Text(
                    'التدخلات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(interventions),
                  const SizedBox(height: 24),
                ],

                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/plan-edit/$planId'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('تعديل', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _deleteConfirm(context, planId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('حذف', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _deleteConfirm(BuildContext context, String planId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الخطة'),
        content: const Text('هل تريد حذف هذه الخطة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('education_plans')
                  .doc(planId)
                  .delete();
              if (context.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
