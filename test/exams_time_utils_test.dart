import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/src/features/exams/domain/time_utils.dart';

void main() {
  test('parseHm parses hours and minutes', () {
    expect(ExamsTimeUtils.parseHm('08:30'), 510);
    expect(ExamsTimeUtils.parseHm('00:00'), 0);
    expect(ExamsTimeUtils.parseHm('23:59'), 1439);
  });

  test('overlaps detects overlapping intervals', () {
    expect(ExamsTimeUtils.overlaps('08:00', '09:00', '08:30', '09:30'), true);
    expect(ExamsTimeUtils.overlaps('08:00', '09:00', '09:00', '10:00'), false);
    expect(ExamsTimeUtils.overlaps('08:00', '09:00', '07:00', '08:00'), false);
    expect(ExamsTimeUtils.overlaps('08:00', '09:00', '07:30', '08:30'), true);
  });
}

