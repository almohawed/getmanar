import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/performance_stats.dart';
import '../../../core/domain/models/user.dart';

class LearningGapsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// حساب جميع إحصائيات الفجوات التعليمية
  Future<GapStats> calculateGapStats(String schoolId) async {
    try {
      // جلب جميع الطلاب في المدرسة
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .where('role', isEqualTo: 'student')
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        return GapStats.empty();
      }

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

      // جلب الفصول
      final classesSnapshot = await _firestore
          .collection('classrooms')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      // اكتشاف الفجوات
      final gaps = await _detectGaps(students, classesSnapshot.docs);

      // حساب الإحصائيات
      final totalGaps = gaps.length;
      final criticalGaps = gaps.where((g) => g.priority == 'حرجة').length;
      final resolvedGaps = 0; // يمكن تحسينه لاحقاً بإضافة حقل isResolved

      return GapStats(
        totalGaps: totalGaps,
        criticalGaps: criticalGaps,
        resolvedGaps: resolvedGaps,
        gaps: gaps,
      );
    } catch (e) {
      print('Error calculating gap stats: $e');
      return GapStats.empty();
    }
  }

  /// اكتشاف الفجوات التعليمية
  Future<List<LearningGapInfo>> _detectGaps(
    List<User> students,
    List<QueryDocumentSnapshot> classes,
  ) async {
    final List<LearningGapInfo> gaps = [];

    // المواد الأساسية للتحليل
    final subjects = [
      'الرياضيات',
      'اللغة العربية',
      'اللغة الإنجليزية',
      'العلوم',
    ];

    for (var classDoc in classes) {
      final className = classDoc.data() as Map<String, dynamic>;
      final classNameStr = className['name'] as String? ?? 'فصل غير معروف';
      final studentIds = List<String>.from(className['studentIds'] ?? []);

      if (studentIds.isEmpty) continue;

      final classStudents = students.where((s) => studentIds.contains(s.id)).toList();
      if (classStudents.isEmpty) continue;

      // تحليل كل مادة
      for (var subject in subjects) {
        final weakStudents = classStudents.where((s) => s.excellenceScore < 60).toList();
        
        if (weakStudents.isEmpty) continue;

        final weakPercentage = (weakStudents.length / classStudents.length) * 100;

        // تحديد الأولوية بناءً على النسبة
        String priority;
        String description;

        if (weakPercentage >= 30) {
          priority = 'حرجة';
          description = 'ضعف كبير في $subject - يحتاج تدخل فوري';
        } else if (weakPercentage >= 15) {
          priority = 'متوسطة';
          description = 'ضعف ملحوظ في $subject - يحتاج متابعة';
        } else {
          priority = 'منخفضة';
          description = 'ضعف طفيف في $subject - يحتاج دعم';
        }

        gaps.add(LearningGapInfo(
          subject: subject,
          className: classNameStr,
          description: description,
          affectedStudents: weakStudents.length,
          priority: priority,
        ));
      }
    }

    // ترتيب الفجوات حسب الأولوية
    gaps.sort((a, b) {
      final priorityOrder = {'حرجة': 0, 'متوسطة': 1, 'منخفضة': 2};
      final aPriority = priorityOrder[a.priority] ?? 3;
      final bPriority = priorityOrder[b.priority] ?? 3;
      return aPriority.compareTo(bPriority);
    });

    return gaps.take(10).toList(); // أخذ أول 10 فجوات فقط
  }
}
