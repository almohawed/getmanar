import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../domain/models/delegated_permissions.dart';
import '../../auth/presentation/auth_controller.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref);
});

class PermissionService {
  final Ref _ref;

  PermissionService(this._ref);

  bool can(AdminSection section, AdminPermission permission) {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return false;

    // Admin (School Manager) has full access
    if (user.role == UserRole.admin) return true;

    // Any Deputy with delegated permissions
    if (user.role == UserRole.deputy) {
      if (user.delegatedPermissions == null) return false;

      final delegated = DelegatedPermissions.fromMap(user.delegatedPermissions!);
      return delegated.hasPermission(section, permission);
    }

    return false;
  }

  // Check if user has ANY permission for a section (to show/hide the menu item)
  bool canViewSection(AdminSection section) {
    // If user has ANY permission for this section, they can view the entry point
    final user = _ref.read(authStateProvider).value;
    if (user == null) return false;

    if (user.role == UserRole.admin) return true;

    if (user.role == UserRole.deputy) {
      if (user.delegatedPermissions == null) return false;
      final delegated = DelegatedPermissions.fromMap(user.delegatedPermissions!);
      final key = section.name;
      // Allow view if the list is not empty (has any permission)
      return delegated.permissions[key]?.isNotEmpty ?? false;
    }
    return false;
  }
}
