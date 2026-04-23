import '../../../core/domain/models/user.dart';
import '../domain/classroom.dart';

// --- مدرسة التميز النموذجية (بيانات وهمية للتجربة) ---

const String mockSchoolId = 'school_excellence';

// 1. القيادة المدرسية
final User mockPrincipal = User(
  id: 'principal_1',
  name: 'أ. محمد العتيبي (مدير المدرسة)',
  email: 'mg12345678@getmanar.com',
  role: UserRole.admin,
  schoolId: mockSchoolId,
  identityNumber: '1234567890',
);

final List<User> mockDeputies = [
  User(
    id: 'deputy_school',
    name: 'أ. خالد الشهري (وكيل الشؤون المدرسية)',
    email: 'ds12345678@getmanar.com',
    role: UserRole.deputy,
    deputyType: 'school',
    schoolId: mockSchoolId,
    identityNumber: '2234567890',
  ),
  User(
    id: 'deputy_academic',
    name: 'أ. فهد المطيري (وكيل الشؤون التعليمية)',
    email: 'da12345678@getmanar.com',
    role: UserRole.deputy,
    deputyType: 'academic',
    schoolId: mockSchoolId,
    identityNumber: '3234567890',
  ),
  User(
    id: 'deputy_student',
    name: 'أ. سلطان القحطاني (وكيل شؤون الطلاب)',
    email: 'dst12345678@getmanar.com',
    role: UserRole.deputy,
    deputyType: 'student',
    schoolId: mockSchoolId,
    identityNumber: '4234567890',
  ),
];

// 2. التوجيه والإدارة
final List<User> mockCounselors = [
  User(
    id: 'counselor_1',
    name: 'أ. علي الزهراني (المرشد الطلابي)',
    email: 'cn12345678@getmanar.com',
    role: UserRole.counselor,
    schoolId: mockSchoolId,
    identityNumber: '5234567890',
  ),
];

final List<User> mockAdmins = [
  User(
    id: 'admin_1',
    name: 'أ. صالح الحربي (إداري)',
    email: 'ad12345678@getmanar.com',
    role: UserRole.administrative,
    schoolId: mockSchoolId,
    identityNumber: '6234567890',
  ),
];

// 3. المعلمون (32 معلم)
final List<User> mockTeachers = List.generate(32, (index) {
  final id = index + 1;
  return User(
    id: 'teacher_$id',
    name: 'معلم $id',
    email: 't${10000000 + id}@getmanar.com',
    role: UserRole.teacher,
    schoolId: mockSchoolId,
    identityNumber: '${7000000000 + id}',
  );
});

// 4. الفصول (12 فصل)
final List<Classroom> mockClasses = [
  // أول متوسط
  ...List.generate(
    4,
    (i) => Classroom(
      id: 'class_7_${i + 1}',
      name: 'أول متوسط/${i + 1}',
      gradeLevel: 7,
      studentIds: List.generate(10, (s) => 'std_7_${i + 1}_${s + 1}'),
    ),
  ),
  // ثاني متوسط
  ...List.generate(
    4,
    (i) => Classroom(
      id: 'class_8_${i + 1}',
      name: 'ثاني متوسط/${i + 1}',
      gradeLevel: 8,
      studentIds: List.generate(10, (s) => 'std_8_${i + 1}_${s + 1}'),
    ),
  ),
  // ثالث متوسط
  ...List.generate(
    4,
    (i) => Classroom(
      id: 'class_9_${i + 1}',
      name: 'ثالث متوسط/${i + 1}',
      gradeLevel: 9,
      studentIds: List.generate(10, (s) => 'std_9_${i + 1}_${s + 1}'),
    ),
  ),
];

// 5. الطلاب (120 طالب)
final List<User> mockStudents = [
  // توليد الطلاب لكل فصل
  ...mockClasses.expand(
    (cls) => List.generate(10, (sIndex) {
      final grade = cls.gradeLevel;
      final classId = cls.id.split('_').last;
      final studentNum = sIndex + 1;
      final uniqueId = 'std_${grade}_${classId}_$studentNum';

      // ربط الطلاب بأولياء الأمور حسب طلب المستخدم
      String? parentId;
      String? parentName;

      if (grade == 7 && classId == '1' && studentNum == 1) {
        parentId = 'parent_ibrahim';
        parentName = 'أ. إبراهيم';
      } else if ((grade == 7 && classId == '1' && studentNum == 2) ||
          (grade == 9 && classId == '1' && studentNum == 1)) {
        parentId = 'parent_hassan';
        parentName = 'أ. حسن';
      }

      return User(
        id: uniqueId,
        name: 'الطالب/ ${_getStudentName(grade, classId, studentNum)}',
        email: '$uniqueId@getmanar.com',
        role: UserRole.student,
        schoolId: mockSchoolId,
        stage: 'Middle',
        excellenceScore: 100,
        identityNumber:
            '110000${grade}${classId}${studentNum.toString().padLeft(2, '0')}',
        studentCode:
            'STU-${grade}${classId}${studentNum.toString().padLeft(2, '0')}',
        parentId: parentId,
      );
    }),
  ),
];

String _getStudentName(int grade, String classId, int studentNum) {
  final gradeName = grade == 7 ? 'أول' : (grade == 8 ? 'ثاني' : 'ثالث');
  return 'محمد $gradeName $classId-$studentNum';
}

// 6. أولياء الأمور (2 أساسيين + عام)
final List<User> mockParents = [
  User(
    id: 'parent_ibrahim',
    name: 'أ. إبراهيم (ولي أمر طالب واحد)',
    email: 'ibrahim@getmanar.com',
    role: UserRole.parent,
    schoolId: mockSchoolId,
    identityNumber: '8000000001',
  ),
  User(
    id: 'parent_hassan',
    name: 'أ. حسن (ولي أمر طالبين)',
    email: 'hassan@getmanar.com',
    role: UserRole.parent,
    schoolId: mockSchoolId,
    identityNumber: '8000000002',
  ),
  User(
    id: 'parent_generic',
    name: 'ولي أمر (تجريبي)',
    email: 'parent@getmanar.com',
    role: UserRole.parent,
    schoolId: mockSchoolId,
  ),
];

// 7. المالك (Super Admin)
final User mockSuperAdmin = User(
  id: 'owner_dev',
  name: 'المالك (Super Owner)',
  email: 'Mohawed32',
  role: UserRole.superAdmin,
  schoolId: mockSchoolId,
);
