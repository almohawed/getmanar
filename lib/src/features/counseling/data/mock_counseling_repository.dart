import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/counseling_session.dart';

abstract class CounselingRepository {
  Future<List<CounselingSession>> getSessionsForStudent(String studentId);
  Future<void> addSession(CounselingSession session);
}

class MockCounselingRepository implements CounselingRepository {
  final List<CounselingSession> _sessions = [];

  @override
  Future<List<CounselingSession>> getSessionsForStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _sessions.where((s) => s.studentId == studentId).toList();
  }

  @override
  Future<void> addSession(CounselingSession session) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _sessions.add(session);
  }
}

final counselingRepositoryProvider = Provider<CounselingRepository>((ref) {
  return MockCounselingRepository();
});
