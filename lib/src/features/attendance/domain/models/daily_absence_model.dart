import '../../../../core/domain/models/user.dart';

class DailyAbsenceModel {
  final String studentName;
  final String className;
  final String period;
  final String teacherName;
  final String parentPhone;
  final String status;
  bool smsSent;
  final User? student; // Full student object for further actions

  DailyAbsenceModel({
    required this.studentName,
    required this.className,
    required this.period,
    required this.teacherName,
    required this.parentPhone,
    required this.status,
    this.smsSent = false,
    this.student,
  });
}
