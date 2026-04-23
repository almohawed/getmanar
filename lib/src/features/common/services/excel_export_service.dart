import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:typed_data'; // For Uint8List
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/behavior_record.dart';

class ExcelExportService {
  Future<void> exportStudentLog({
    required BuildContext context,
    required String className,
    required List<User> students,
    required List<BehaviorRecord> records,
    required bool filled,
  }) async {
    try {
      var excel = Excel.createExcel();
      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      Sheet sheet = excel['سجل المتابعة'];

      // --- Headers ---
      // Apply basic styling (Excel package has limited styling in free version but we do what we can)
      List<String> headers = [
        'م', // Index
        'اسم الطالب',
        'الرقم الأكاديمي',
        'السلوكيات الإيجابية',
        'السلوكيات السلبية',
        'الواجبات (لم يحل)',
        'الاختبارات (لم يحل)',
        'ملاحظات',
      ];

      // Add Headers Row
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        // Note: Styling is limited in some versions, but let's try basic if needed.
        // For now, just data.
      }

      // --- Data (if filled) ---
      if (filled) {
        for (var i = 0; i < students.length; i++) {
          final student = students[i];
          final studentRecords = records
              .where((r) => r.studentId == student.id)
              .toList();

          final positiveCount = studentRecords
              .where((r) => r.type == BehaviorType.positive)
              .length;
          final negativeCount = studentRecords
              .where((r) => r.type == BehaviorType.negative)
              .length;
          // Assuming we distinguish homework/tests by description or type (currently generic negative/positive)
          // For now, let's just count them based on generic logic or placeholder
          // If we had specific types for Homework/Test, we'd filter by that.
          // Based on user prompt: "violations, missed tests, missed homework"
          // We'll assume these are negative behaviors with specific descriptions or notes.

          // Let's count "Test" and "Homework" strings in description for now as a heuristic
          final homeworkCount = studentRecords
              .where(
                (r) =>
                    r.description.contains('واجب') ||
                    r.description.contains('Homework'),
              )
              .length;
          final testCount = studentRecords
              .where(
                (r) =>
                    r.description.contains('اختبار') ||
                    r.description.contains('Test'),
              )
              .length;

          // Row index starts at 1 (0 is header)
          int rowIndex = i + 1;

          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            i + 1,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            student.name,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            student.identityNumber ?? '-',
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            positiveCount,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            negativeCount,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            homeworkCount,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            testCount,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            '',
          ); // Notes empty for manual filling
        }
      } else {
        // If empty, maybe add empty rows for students?
        // User said "Empty Template". Usually means just headers, or headers + student names.
        // "Empty" implies "Ready to be filled".
        // If I put student names, it's helpful. If I put nothing, it's a generic template.
        // Given "Teacher Log", it usually implies "My Class Log".
        // I will list the students but leave the counts empty.
        for (var i = 0; i < students.length; i++) {
          final student = students[i];
          int rowIndex = i + 1;
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            i + 1,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            student.name,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            student.identityNumber ?? '-',
          );
          // Leave other columns empty
        }
      }

      // --- Save & Share ---
      // final directory = await getApplicationDocumentsDirectory();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      final statusStr = filled ? 'Filled' : 'Empty';
      final fileName = 'StudentLog_${className}_${statusStr}_$dateStr.xlsx';
      // final path = '${directory.path}/$fileName';

      final fileData = excel.save();
      if (fileData != null) {
        // Use XFile.fromData for Web/Mobile compatibility
        final xFile = XFile.fromData(
          Uint8List.fromList(fileData),
          name: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        final shareParams = ShareParams(
          files: [xFile],
          text: 'سجل متابعة الطلاب - $className ($statusStr)',
        );
        await SharePlus.instance.share(shareParams);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')));
      }
    }
  }

  Future<void> exportTeacherLog({
    required BuildContext context,
    required List<User> teachers,
    required Map<String, Map<String, dynamic>> data,
    required bool filled,
  }) async {
    try {
      var excel = Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      Sheet sheet = excel['سجل المعلمين'];

      List<String> headers = [
        'م',
        'اسم المعلم',
        'التخصص',
        'الغياب (أيام)',
        'التأخر (دقيقة)',
        'ملاحظات',
      ];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
      }

      for (var i = 0; i < teachers.length; i++) {
        final teacher = teachers[i];
        int rowIndex = i + 1;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          i + 1,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          teacher.name,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          teacher.specialization ?? '-',
        );

        if (filled) {
          final teacherData = data[teacher.id] ?? {};
          final absence = teacherData['absence'] ?? 0;
          final lateness = teacherData['lateness'] ?? 0;

          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            absence,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            lateness,
          );
        }
        // Notes left empty
      }

      // final directory = await getApplicationDocumentsDirectory();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      final statusStr = filled ? 'Filled' : 'Empty';
      final fileName = 'TeacherLog_${statusStr}_$dateStr.xlsx';
      // final path = '${directory.path}/$fileName';

      // final file = File(path);
      var fileBytes = excel.save();
      if (fileBytes != null) {
        // await file.writeAsBytes(fileBytes);

        if (context.mounted) {
          final xFile = XFile.fromData(
            Uint8List.fromList(fileBytes),
            name: fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );

          final shareParams = ShareParams(
            files: [xFile],
            text: 'سجل المعلمين ($statusStr)',
          );
          await SharePlus.instance.share(shareParams);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
      }
    }
  }
}
