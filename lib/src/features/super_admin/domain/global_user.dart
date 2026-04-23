
class GlobalUser {
  final String id;
  final String? email;
  final String? role;
  final String? schoolId;
  final String? name;

  GlobalUser({
    required this.id,
    this.email,
    this.role,
    this.schoolId,
    this.name,
  });

  factory GlobalUser.fromMap(Map<String, dynamic> map, String id) {
    return GlobalUser(
      id: id,
      email: map['email'] as String?,
      role: map['role'] as String?,
      schoolId: map['schoolId'] as String?,
      name: map['name'] as String?,
    );
  }
}
