
class StudentStats {
  final int pledgesCount;
  final int absenceDays;
  final int homeworkCompleted;
  final int homeworkTotal;
  final int classEscapes;
  final List<String> upcomingRequirements;

  StudentStats({
    required this.pledgesCount,
    required this.absenceDays,
    required this.homeworkCompleted,
    required this.homeworkTotal,
    required this.classEscapes,
    required this.upcomingRequirements,
  });
}

// Mock stats for demo students
final Map<String, StudentStats> mockStudentStats = {
  's1': StudentStats(
    pledgesCount: 0,
    absenceDays: 2,
    homeworkCompleted: 15,
    homeworkTotal: 18,
    classEscapes: 0,
    upcomingRequirements: ['إحضار أدوات الهندسة غداً', 'توقيع إشعار الرحلة'],
  ),
  's2': StudentStats(
    pledgesCount: 1,
    absenceDays: 5,
    homeworkCompleted: 10,
    homeworkTotal: 18,
    classEscapes: 1,
    upcomingRequirements: ['مراجعة الوحدة الثالثة', 'إحضار ملف إنجاز'],
  ),
  's3': StudentStats(
    pledgesCount: 0,
    absenceDays: 0,
    homeworkCompleted: 18,
    homeworkTotal: 18,
    classEscapes: 0,
    upcomingRequirements: [],
  ),
  's4': StudentStats(
    pledgesCount: 3,
    absenceDays: 8,
    homeworkCompleted: 5,
    homeworkTotal: 18,
    classEscapes: 4,
    upcomingRequirements: ['استدعاء ولي أمر', 'شراء كراسة رسم'],
  ),
};

// Fallback for unknown students
final defaultStudentStats = StudentStats(
  pledgesCount: 0,
  absenceDays: 0,
  homeworkCompleted: 0,
  homeworkTotal: 0,
  classEscapes: 0,
  upcomingRequirements: [],
);
