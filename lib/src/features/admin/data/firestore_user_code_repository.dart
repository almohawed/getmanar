import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class UserCodeRepository {
  Stream<List<Map<String, dynamic>>> watchUserCodes(String schoolId);
}

class FunctionsUserCodeRepository implements UserCodeRepository {
  final FirebaseFunctions _functions;

  FunctionsUserCodeRepository(this._functions);

  Future<List<Map<String, dynamic>>> _fetchUserCodes(String schoolId) async {
    final callable = _functions.httpsCallable('listUserCodesForSchool');
    final result = await callable.call({'schoolId': schoolId, 'limit': 2000});
    final data = result.data;
    final map = data is Map ? data : null;
    final items = map?['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  @override
  Stream<List<Map<String, dynamic>>> watchUserCodes(String schoolId) {
    final sid = schoolId.trim();
    if (sid.isEmpty) return Stream.value(const <Map<String, dynamic>>[]);
    return (() async* {
      yield await _fetchUserCodes(sid);
      await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
        yield await _fetchUserCodes(sid);
      }
    })();
  }
}

final userCodeRepositoryProvider = Provider<UserCodeRepository>((ref) {
  return FunctionsUserCodeRepository(FirebaseFunctions.instance);
});
