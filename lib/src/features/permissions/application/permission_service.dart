import 'package:uuid/uuid.dart';
import '../domain/permission_model.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  List<PermissionUser> _users = [];
  List<PermissionLog> _logs = [];

  List<PermissionUser> getUsers() {
    return _users;
  }

  List<PermissionLog> getLogs() {
    return _logs;
  }

  void addUser(PermissionUser user) {
    _users.add(user);
    _logs.insert(0, PermissionLog(
      id: const Uuid().v4(),
      action: 'تم إضافة مستخدم جديد',
      targetUser: user.name,
      performedBy: 'مدير النظام', // Simulated
      timestamp: DateTime.now(),
    ));
  }

  Map<String, dynamic> getStatistics() {
    final total = _users.length;
    final admins = _users.where((u) => u.role == UserRole.admin).length;
    final managers = _users.where((u) => u.role == UserRole.manager).length;
    final teachers = _users.where((u) => u.role == UserRole.teacher).length;
    final custodians = _users.where((u) => u.role == UserRole.custodian).length;
    
    return {
      'totalUsers': total,
      'admins': admins,
      'managers': managers,
      'teachers': teachers,
      'custodians': custodians,
      'highPrivilege': _users
          .where((u) => u.permissionLevel == PermissionLevel.full)
          .length,
      'newUsers': 0,
      'failedLogins': 0,
      'stability': 0,
    };
  }
}
