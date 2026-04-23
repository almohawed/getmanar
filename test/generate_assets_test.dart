import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

// ignore_for_file: avoid_print

void main() {
  test('Generate Excel Templates', () {
    final templateDir = p.join(Directory.current.path, 'assets', 'templet');
    
    // Ensure directory exists
    Directory(templateDir).createSync(recursive: true);

    print('Generating templates in: $templateDir');

    _generateTeacherTemplate(p.join(templateDir, 'tetchar.xlsx'));
    _generateScheduleTemplate(p.join(templateDir, 'schedule_template.xlsx'));
  });
}

void _generateTeacherTemplate(String path) {
  var excel = Excel.createExcel();
  
  // Rename default sheet
  String defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, 'Teachers');
  
  Sheet sheet = excel['Teachers'];
  
  // Headers: Name, Specialization, Nisab, Classes
  List<String> headers = ['Name', 'Specialization', 'Nisab', 'Classes'];
  
  // Add headers
  for (var i = 0; i < headers.length; i++) {
    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = TextCellValue(headers[i]);
    cell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#CCCCCC'),
    );
  }

  // Add sample data
  List<String> sample = ['أحمد محمد', 'رياضيات', '20', '3/1, 3/2'];
  for (var i = 0; i < sample.length; i++) {
    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
    cell.value = TextCellValue(sample[i]);
  }

  // Save
  var fileBytes = excel.save();
  if (fileBytes != null) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    print('Created: $path');
  }
}

void _generateScheduleTemplate(String path) {
  var excel = Excel.createExcel();
  
  // Rename default sheet
  String defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, 'Schedule');
  
  Sheet sheet = excel['Schedule'];
  
  // Headers: Day, Period, Class, Subject, Teacher
  List<String> headers = ['اليوم', 'الحصة', 'الفصل', 'المادة', 'المعلم'];
  
  // Add headers
  for (var i = 0; i < headers.length; i++) {
    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = TextCellValue(headers[i]);
    cell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#CCCCCC'),
    );
  }
  
  // Add sample
  List<String> sample = ['الأحد', '1', '3/1', 'رياضيات', 'أحمد محمد'];
  for (var i = 0; i < sample.length; i++) {
    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
    cell.value = TextCellValue(sample[i]);
  }

  // Save
  var fileBytes = excel.save();
  if (fileBytes != null) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    print('Created: $path');
  }
}
