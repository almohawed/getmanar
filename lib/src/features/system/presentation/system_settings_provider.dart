import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/system_repository.dart';
import '../domain/system_settings.dart';

final systemSettingsProvider = StreamProvider<SystemSettings>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user?.schoolId == null) return Stream.value(const SystemSettings());

  final repository = ref.watch(systemRepositoryProvider);
  return repository.watchSystemSettings(user!.schoolId!);
});
