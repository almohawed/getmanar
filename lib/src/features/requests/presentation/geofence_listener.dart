import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/permission_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';

class GeofenceListener extends ConsumerWidget {
  final Widget child;
  const GeofenceListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(requestsProvider, (previous, next) {
      if (previous == null) return;

      // Check for newly arrived parents
      for (final req in next) {
        final prevReq = previous.firstWhere(
          (r) => r.id == req.id,
          orElse: () => req,
        );

        // If 'isParentNear' changed from false to true
        if (!prevReq.isParentNear && req.isParentNear) {
          final user = ref.read(authStateProvider).value;

          if (user != null &&
              user.role != UserRole.parent &&
              user.role != UserRole.student) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.green.shade50,
                  title: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('تنبيه وصول ولي أمر'),
                    ],
                  ),
                  content: Text(
                    'وصل ولي أمر الطالب (${req.studentName}) إلى محيط المدرسة.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              );
            });
          }
        }
      }
    });

    return child;
  }
}
