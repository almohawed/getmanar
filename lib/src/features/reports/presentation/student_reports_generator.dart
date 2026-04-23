import 'dart:typed_data';
import '../../reports/domain/ministry_pdf_template.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../behavior/domain/bathroom_pass.dart';

class StudentReportsGenerator {
  static List<String> _rtlHeaders(List<String> headers) =>
      headers.reversed.toList();

  static List<List<String>> _rtlRows(List<List<String>> rows) =>
      rows.map((r) => r.reversed.toList()).toList();
  
  // 1. Tardy Report
  static Future<Uint8List> generateTardyReport({
    required String schoolName,
    required List<StudentAttendance> attendanceList,
    required DateTime dateFrom,
    required DateTime dateTo,
    String region = 'الرياض',
  }) async {
    final headers = [
      'م',
      'اسم الطالب',
      'التاريخ',
      'وقت الحضور',
      'الحالة',
      'المسجل',
    ];
    final rows = attendanceList.asMap().entries.map<List<String>>((entry) {
      final index = entry.key + 1;
      final record = entry.value;
      return <String>[
        index.toString(),
        '${record.studentName}',
        '${record.date.toString().split(' ')[0]}',
        '${record.arrivalTime?.toString().split(' ')[1].substring(0, 5) ?? '--:--'}',
        'تأخر',
        '${record.recordedBy}',
      ];
    }).toList();

    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف التأخر الصباحي",
      subTitle: "Tardiness Report",
      schoolName: schoolName,
      adminRegion: region,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: _rtlHeaders(headers),
      tableData: _rtlRows(rows),
      footerText: "نظام منار - شؤون الطلاب",
    );
    return pdf.save();
  }

  // 2. Absence Report
  static Future<Uint8List> generateAbsenceReport({
    required String schoolName,
    required List<StudentAttendance> attendanceList,
    required DateTime dateFrom,
    required DateTime dateTo,
    String region = 'الرياض',
  }) async {
    final headers = [
      'م',
      'اسم الطالب',
      'التاريخ',
      'الصف',
      'الحالة',
      'المسجل',
    ];
    final rows = attendanceList.asMap().entries.map<List<String>>((entry) {
      final index = entry.key + 1;
      final record = entry.value;
      return <String>[
        index.toString(),
        '${record.studentName}',
        '${record.date.toString().split(' ')[0]}',
        '${record.classId}',
        '${record.status.name}',
        '${record.recordedBy}',
      ];
    }).toList();

    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الغياب",
      subTitle: "Absence Report",
      schoolName: schoolName,
      adminRegion: region,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: _rtlHeaders(headers),
      tableData: _rtlRows(rows),
      footerText: "نظام منار - شؤون الطلاب",
    );
    return pdf.save();
  }

  // 3. Behavior Violations Report
  // Using generic Map for flexibility as Violation model might vary or be BehaviorRecord
  static Future<Uint8List> generateBehaviorReport({
    required String schoolName,
    required List<Map<String, dynamic>> violations, // Map or Model
    required DateTime dateFrom,
    required DateTime dateTo,
    String region = 'الرياض',
  }) async {
    final headers = [
      'م',
      'اسم الطالب',
      'نوع المخالفة',
      'الوصف',
      'التاريخ',
      'الحالة',
      'الإجراء',
    ];
    final rows = violations.asMap().entries.map<List<String>>((entry) {
      final index = entry.key + 1;
      final v = entry.value;
      return <String>[
        index.toString(),
        '${v['studentName'] ?? v['studentId'] ?? ''}',
        '${v['type'] ?? ''}',
        '${v['description'] ?? ''}',
        '${v['timestamp']?.toString().split(' ')[0] ?? ''}',
        '${v['status'] ?? ''}',
        '${v['action'] ?? ''}',
      ];
    }).toList();

    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف المخالفات السلوكية",
      subTitle: "Behavioral Violations",
      schoolName: schoolName,
      adminRegion: region,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: _rtlHeaders(headers),
      tableData: _rtlRows(rows),
      footerText: "نظام منار - التوجيه الطلابي",
    );
    return pdf.save();
  }

  // 4. Bathroom Pass Report
  static Future<Uint8List> generateBathroomReport({
    required String schoolName,
    required List<BathroomPass> passes,
    required DateTime dateFrom,
    required DateTime dateTo,
    String region = 'الرياض',
  }) async {
    final headers = [
      'م',
      'اسم الطالب',
      'وقت الخروج',
      'وقت العودة',
      'المدة (د)',
      'الحالة',
    ];
    final rows = passes.asMap().entries.map<List<String>>((entry) {
      final index = entry.key + 1;
      final pass = entry.value;
      final durationMinutes = pass.endTime != null && pass.startTime != null
          ? pass.endTime!.difference(pass.startTime).inMinutes
          : null;

      return <String>[
        index.toString(),
        '${pass.studentId}',
        '${pass.startTime.toString().split(' ')[1].substring(0, 5)}',
        '${pass.endTime?.toString().split(' ')[1].substring(0, 5) ?? '--:--'}',
        '${durationMinutes ?? '--'}',
        '${pass.status.name}',
      ];
    }).toList();

    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف تصاريح الحمام",
      subTitle: "Bathroom Passes Log",
      schoolName: schoolName,
      adminRegion: region,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: _rtlHeaders(headers),
      tableData: _rtlRows(rows),
      footerText: "نظام منار - المتابعة اليومية",
    );
    return pdf.save();
  }
}
