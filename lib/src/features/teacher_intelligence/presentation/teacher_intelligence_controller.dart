
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/teacher_intelligence_repository.dart';
import '../domain/models/teacher_behavior_profile.dart';

final teacherProfilesProvider = StreamProvider<List<TeacherBehaviorProfile>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || user.schoolId == null) return Stream.value([]);
      final repo = ref.watch(teacherIntelligenceRepositoryProvider);
      return repo.watchSchoolProfiles(user.schoolId!);
    },
    loading: () => Stream.value([]),
    error: (e, st) => Stream.value([]),
  );
});

final teacherIntelligenceStatsProvider = Provider<TeacherStats>((ref) {
  final profilesAsync = ref.watch(teacherProfilesProvider);
  
  return profilesAsync.when(
    data: (profiles) {
      if (profiles.isEmpty) return TeacherStats.empty();
      
      int totalTeachers = profiles.length;
      double totalScore = 0;
      int criticalCount = 0;
      int excellentCount = 0;
      int goodCount = 0;
      int supportCount = 0;
      for (var p in profiles) {
        totalScore += p.score;
        if (p.badgeColor == 'Red') criticalCount++;
        if (p.score >= 90) excellentCount++;
        else if (p.score >= 80) goodCount++;
        else if (p.score >= 60) supportCount++;
      }

      return TeacherStats(
        totalTeachers: totalTeachers,
        averageScore: totalScore / totalTeachers,
        criticalCount: criticalCount,
        excellentCount: excellentCount,
        goodCount: goodCount,
        supportCount: supportCount,
        followUpCount: profiles.where((p) => p.score >= 30 && p.score < 60).length,
      );
    },
    loading: () => TeacherStats.empty(),
    error: (_, __) => TeacherStats.empty(),
  );
});

class TeacherStats {
  final int totalTeachers;
  final double averageScore;
  final int criticalCount;
  final int excellentCount;
  final int goodCount;
  final int supportCount;
  final int followUpCount;

  TeacherStats({
    required this.totalTeachers,
    required this.averageScore,
    required this.criticalCount,
    required this.excellentCount,
    required this.goodCount,
    required this.supportCount,
    required this.followUpCount,
  });

  factory TeacherStats.empty() {
    return TeacherStats(
      totalTeachers: 0,
      averageScore: 0,
      criticalCount: 0,
      excellentCount: 0,
      goodCount: 0,
      supportCount: 0,
      followUpCount: 0,
    );
  }
}
