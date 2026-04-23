import '../../../core/domain/models/user.dart';

class StaffProvisioningResult {
  final String uid;
  final String mnCode;
  final String password;

  const StaffProvisioningResult({
    required this.uid,
    required this.mnCode,
    required this.password,
  });
}

abstract class StaffRepository {
  Future<StaffProvisioningResult> addStaff(User user, String password);
  Future<List<User>> getStaffByRole(UserRole role);
  Future<List<User>> getAllStaff();
  Future<void> deleteStaff(List<String> ids);
  Future<void> updateStaff(User user);

  // New stream method
  Stream<List<User>> watchAllStaff(String schoolId);

  // Support Staff Methods
  Stream<List<User>> watchSupportStaff(String schoolId);
  Future<void> createSupportUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String schoolId,
  });
  Future<void> deleteSupportUser({
    required String uid,
    required String schoolId,
  });
}
