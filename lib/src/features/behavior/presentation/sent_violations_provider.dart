import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/violation.dart';

class SentViolationsNotifier extends Notifier<List<Violation>> {
  @override
  List<Violation> build() {
    return [];
  }

  void addViolation(Violation violation) {
    state = [...state, violation];
  }
}

final sentViolationsProvider =
    NotifierProvider<SentViolationsNotifier, List<Violation>>(() {
  return SentViolationsNotifier();
});
