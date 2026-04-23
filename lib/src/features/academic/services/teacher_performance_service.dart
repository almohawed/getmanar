import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/performance_stats.dart';
import '../../../core/domain/models/user.dart';
import '../../schedule/data/schedule_repository.dart';

class TeacherPerformanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// حساب إحصائيات جميع المعلمين في المدرسة
  Future<List<TeacherStats>> calculateAllTeachersStats(
    String schoolId,
    ScheduleRepository scheduleRepo,
  ) async {
    try {
      // جلب جميع المعلمين
      final teachersSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .where('role', isEqualTo: 'teacher')
          .get();

      if (teachersSnapshot.docs.isEmpty) {
        return [];
      }

      final teachers = teachersSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return User(
              id: doc.id,
              email: data['email'] ?? '',
              name: data['name'] ?? '',
              role: UserRole.values.firstWhere(
                (e) => e.toString() == 'UserRole.${data['role']}',
                orElse: () => UserRole.teacher,
              ),
              schoolId: data['schoolId'],
              excellenceScore: data['excellenceScore'] ?? 0,
              maxWeeklyClasses: data['maxWeeklyClasses'],
              assignedClassIds: data['assignedClassIds'] != null 
                  ? List<String>.from(data['assignedClassIds']) 
                  : null,
            );
          })
          .toList();

      // جلب جميع الطلاب
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .where('role', isEqualTo: 'student')
          .get();

      final students = studentsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return User(
              id: doc.id,
              email: data['email'] ?? '',
              name: data['name'] ?? '',
              role: UserRole.values.firstWhere(
                (e) => e.toString() == 'UserRole.${data['role']}',
                orElse: () => UserRole.student,
              ),
              schoolId: data['schoolId'],
              excellenceScore: data['excellenceScore'] ?? 0,
            );
          })
          .toList();

      // جلب جميع الفصول
      final classesSnapshot = await _firestore
          .collection('classrooms')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final List<TeacherStats> stats = [];

      for (var teacher in teachers) {
        // حساب عدد الحصص
        final currentLoad = await scheduleRepo.getTeacherLoad(schoolId, teacher.id);
        final maxLoad = teacher.maxWeeklyClasses ?? 24;

        // حساب متوسط تميز الطلاب
        final avgExcellence = await _calculateTeacherExcellence(
          teacher,
          students,
          classesSnapshot.docs,
        );

        stats.add(TeacherStats(
          teacherId: teacher.id,
          teacherName: teacher.name,
          teacherEmail: teacher.email,
          avgExcellence: avgExcellence,
          currentLoad: currentLoad,
          maxLoad: maxLoad,
        ));
      }

      // ترتيب المعلمين حسب متوسط التميز
      stats.sort((a, b) => b.avgExcellence.compareTo(a.avgExcellence));

      return stats;
    } catch (e) {
      print('Error calculating teachers stats: $e');
      return [];
    }
  }

  /// حساب متوسط تميز طلاب المعلم
  Future<double> _calculateTeacherExcellence(
    User teacher,
    List<User> allStudents,
    List<QueryDocumentSnapshot> classes,
  ) async {
    try {
      final teacherClassIds = teacher.assignedClassIds ?? [];
      if (teacherClassIds.isEmpty) {
        return 0.0;
      }

      // جمع جميع طلاب المعلم
      final Set<String> studentIds = {};
      for (var classDoc in classes) {
        final classData = classDoc.data() as Map<String, dynamic>;
        if (teacherClassIds.contains(classDoc.id)) {
          final classStudentIds = List<String>.from(classData['studentIds'] ?? []);
          studentIds.addAll(classStudentIds);
        }
      }

      if (studentIds.isEmpty) {
        return 0.0;
      }

      // حساب متوسط درجات الطلاب
      final teacherStudents = allStudents.where((s) => studentIds.contains(s.id)).toList();
      if (teacherStudents.isEmpty) {
        return 0.0;
      }

      final totalScore = teacherStudents.fold<int>(
        0,
        (sum, student) => sum + student.excellenceScore,
      );

      return totalScore / teacherStudents.length;
    } catch (e) {
      print('Error calculating teacher excellence: $e');
      return 0.0;
    }
  }
}
