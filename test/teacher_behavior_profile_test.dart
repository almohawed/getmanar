
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/src/features/teacher_intelligence/domain/models/teacher_behavior_profile.dart';

void main() {
  group('TeacherBehaviorProfile', () {
    test('parses from map correctly', () {
      final map = {
        'teacherId': 't123',
        'schoolId': 's1',
        'score': 95,
        'badge': 'التزام متميز',
        'badgeColor': 'Green',
        'trend': 'Stable',
        'patterns': ['Pattern 1'],
        'recommendations': ['Rec 1'],
        'scheduleHints': {
          'avoidPeriods': [1, 7],
          'preferStartPeriod': 2
        },
        'metrics': {
          'lateCount': 1,
          'skipP7Count': 2
        },
        'lastUpdatedAt': null // Test null date handling
      };

      final profile = TeacherBehaviorProfile.fromMap(map);

      expect(profile.teacherId, 't123');
      expect(profile.score, 95);
      expect(profile.scheduleHints.avoidPeriods, containsAll([1, 7]));
      expect(profile.scheduleHints.preferStartPeriod, 2);
      expect(profile.metrics.lateCount, 1);
      expect(profile.metrics.skipP7Count, 2);
    });

    test('handles missing fields gracefully', () {
      final map = {'teacherId': 't123', 'schoolId': 's1'};
      final profile = TeacherBehaviorProfile.fromMap(map);

      expect(profile.score, 100); // Default
      expect(profile.badgeColor, 'Green'); // Default
      expect(profile.scheduleHints.avoidPeriods, isEmpty);
    });
  });
}
