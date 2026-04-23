import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masar_app/src/features/behavior/presentation/sent_violations_provider.dart';
import 'package:masar_app/src/features/behavior/domain/models/violation.dart';

void main() {
  test('SentViolationsNotifier adds violation', () {
    final container = ProviderContainer();
    final notifier = container.read(sentViolationsProvider.notifier);

    final violation = Violation(
      id: '1',
      studentId: 's1',
      teacherId: 't1',
      type: ViolationType.minor,
      description: 'test',
      timestamp: DateTime.now(),
      pointsDeducted: 1,
    );

    notifier.addViolation(violation);

    expect(container.read(sentViolationsProvider).length, 1);
  });
}
