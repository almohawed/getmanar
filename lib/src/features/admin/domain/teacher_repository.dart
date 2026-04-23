import '../../../core/domain/models/user.dart';

class TeacherProvisioningResult {
  final String uid;
  final String mnCode;
  final String password;

  const TeacherProvisioningResult({
    required this.uid,
    required this.mnCode,
    required this.password,
  });
}

abstract class TeacherRepository {
  Future<TeacherProvisioningResult> addTeacher(User teacher, String password);
  Future<void> updateTeacher(User teacher);
  Future<List<User>> getTeachers({String? schoolId});
  Future<void> deleteTeacher(String teacherId);
  Future<void> deleteTeachers(List<String> teacherIds);
}
