import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfExportService {
  static final _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  static pw.Font? _arabicFont;

  /// Load Arabic font
  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    
    try {
      // Load Cairo font from assets
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
      print('✅ تم تحميل خط Cairo بنجاح');
    } catch (e) {
      print('⚠️ فشل تحميل خط Cairo: $e');
      try {
        // Fallback to Google Fonts
        _arabicFont = await PdfGoogleFonts.cairoRegular();
        print('✅ تم تحميل خط Cairo من Google Fonts');
      } catch (e2) {
        print('❌ فشل تحميل الخط العربي: $e2');
        // Last fallback
        _arabicFont = await PdfGoogleFonts.notoSansRegular();
      }
    }
  }

  /// Export all class schedules to PDF
  static Future<void> exportClassSchedules(String schoolId) async {
    try {
      // Load Arabic font first
      await _loadArabicFont();
      
      // Fetch all schedules
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Schedules')
          .get();

      if (schedulesSnapshot.docs.isEmpty) {
        throw Exception('لا توجد جداول لتصديرها');
      }

      final pdf = pw.Document();

      // Add a page for each class
      for (var doc in schedulesSnapshot.docs) {
        try {
          final data = doc.data();
          final className = data['className'] ?? doc.id;
          final scheduleData = data['schedule'];
          
          if (scheduleData == null) continue;
          
          // Convert schedule to proper format
          final schedule = <String, dynamic>{};
          if (scheduleData is Map) {
            scheduleData.forEach((key, value) {
              if (value is List) {
                schedule[key.toString()] = value;
              }
            });
          }

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              textDirection: pw.TextDirection.ltr,
              theme: pw.ThemeData.withFont(
                base: _arabicFont,
                bold: _arabicFont,
              ),
              build: (context) => _buildSchedulePage(className, schedule),
            ),
          );
        } catch (e) {
          print('Error processing class ${doc.id}: $e');
          continue;
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw Exception('لا توجد جداول صالحة للتصدير');
      }

      // Save and share
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'جداول_الفصول.pdf',
      );
    } catch (e) {
      throw Exception('خطأ في التصدير: $e');
    }
  }

  /// Export teacher schedules to PDF
  static Future<void> exportTeacherSchedules(String schoolId) async {
    try {
      // Load Arabic font first
      await _loadArabicFont();
      
      // Fetch all schedules
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Schedules')
          .get();

      if (schedulesSnapshot.docs.isEmpty) {
        throw Exception('لا توجد جداول لتصديرها');
      }

      // Fetch all teachers
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Teachers')
          .get();

      // Build teacher schedules
      final teacherSchedules = <String, Map<String, dynamic>>{};
      
      for (var teacher in teachersSnapshot.docs) {
        final teacherId = teacher.id;
        final teacherName = teacher.data()['name'] ?? 'معلم';
        
        teacherSchedules[teacherId] = {
          'name': teacherName,
          'schedule': _buildTeacherSchedule(teacherId, schedulesSnapshot.docs),
        };
      }

      final pdf = pw.Document();

      // Add a page for each teacher
      for (var entry in teacherSchedules.entries) {
        final teacherName = entry.value['name'];
        final schedule = entry.value['schedule'] as Map<String, dynamic>;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            textDirection: pw.TextDirection.ltr,
            theme: pw.ThemeData.withFont(
              base: _arabicFont,
              bold: _arabicFont,
            ),
            build: (context) => _buildSchedulePage(
              'جدول المعلم: $teacherName',
              schedule,
            ),
          ),
        );
      }

      // Save and share
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'جداول_المعلمين.pdf',
      );
    } catch (e) {
      throw Exception('خطأ في التصدير: $e');
    }
  }

  /// Export master schedule (all classes in one page)
  static Future<void> exportMasterSchedule(String schoolId) async {
    try {
      // Load Arabic font first
      await _loadArabicFont();
      
      // Fetch all schedules
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Schedules')
          .get();

      if (schedulesSnapshot.docs.isEmpty) {
        throw Exception('لا توجد جداول لتصديرها');
      }

      final pdf = pw.Document();

      // Collect all class schedules
      final allSchedules = <Map<String, dynamic>>[];
      for (var doc in schedulesSnapshot.docs) {
        final data = doc.data();
        final className = data['className'] ?? doc.id;
        final scheduleData = data['schedule'];
        
        if (scheduleData != null) {
          allSchedules.add({
            'className': className,
            'schedule': scheduleData,
          });
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a3.landscape,
          textDirection: pw.TextDirection.ltr,
          theme: pw.ThemeData.withFont(
            base: _arabicFont,
            bold: _arabicFont,
          ),
          build: (context) => _buildMasterSchedulePage(allSchedules),
        ),
      );

      // Save and share
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'الجدول_العام.pdf',
      );
    } catch (e) {
      throw Exception('خطأ في التصدير: $e');
    }
  }

  /// Build teacher schedule from all class schedules
  static Map<String, dynamic> _buildTeacherSchedule(
    String teacherId,
    List<QueryDocumentSnapshot> classSchedules,
  ) {
    final teacherSchedule = <String, List<Map<String, dynamic>>>{};

    // Initialize days
    for (var day in _days) {
      teacherSchedule[day] = List.generate(7, (_) => <String, dynamic>{});
    }

    print('Building schedule for teacher: $teacherId');
    print('Processing ${classSchedules.length} classes');

    // Collect teacher's lessons from all classes
    for (var classDoc in classSchedules) {
      try {
        final data = classDoc.data();
        if (data is! Map<String, dynamic>) continue;
        
        final className = data['className'] ?? classDoc.id;
        final scheduleData = data['schedule'];
        
        print('Processing class: $className');
        
        if (scheduleData == null) {
          print('  No schedule data for $className');
          continue;
        }
        
        Map<String, dynamic> schedule;
        if (scheduleData is Map<String, dynamic>) {
          schedule = scheduleData;
        } else if (scheduleData is Map) {
          schedule = Map<String, dynamic>.from(scheduleData);
        } else {
          print('  Invalid schedule format for $className');
          continue;
        }

        schedule.forEach((day, lessons) {
          if (lessons == null || !_days.contains(day)) return;
          
          List<dynamic> lessonsList;
          if (lessons is List) {
            lessonsList = lessons;
          } else {
            return;
          }
          
          for (int period = 0; period < lessonsList.length && period < 7; period++) {
            final lesson = lessonsList[period];
            if (lesson == null) continue;
            
            Map<String, dynamic> lessonMap;
            if (lesson is Map<String, dynamic>) {
              lessonMap = lesson;
            } else if (lesson is Map) {
              lessonMap = Map<String, dynamic>.from(lesson);
            } else {
              continue;
            }
            
            final lessonTeacherId = lessonMap['teacherId']?.toString() ?? '';
            final subjectName = lessonMap['subjectName']?.toString() ?? '';
            
            if (lessonTeacherId == teacherId) {
              print('  Found lesson: $subjectName in $className on $day period $period');
              
              // تحقق من وجود تعارض (حصة موجودة مسبقاً)
              final existingLesson = teacherSchedule[day]![period];
              if (existingLesson.isNotEmpty) {
                print('  ⚠️ CONFLICT: Teacher already has ${existingLesson['subjectName']} in ${existingLesson['className']} at this time!');
                // لا تستبدل - احتفظ بالحصة الأولى فقط
                continue;
              }
              
              teacherSchedule[day]![period] = {
                'subjectName': subjectName,
                'className': className,
                'teacherId': teacherId,
              };
            }
          }
        });
      } catch (e) {
        print('Error processing class ${classDoc.id}: $e');
        continue;
      }
    }

    // Print summary
    int totalLessons = 0;
    int conflicts = 0;
    teacherSchedule.forEach((day, lessons) {
      final dayLessons = lessons.where((l) => l.isNotEmpty).length;
      if (dayLessons > 0) {
        print('$day: $dayLessons lessons');
        totalLessons += dayLessons;
      }
    });
    print('Total lessons for teacher $teacherId: $totalLessons');
    if (conflicts > 0) {
      print('⚠️ WARNING: $conflicts conflicts detected!');
    }

    // Convert to Map<String, dynamic> for PDF
    final result = <String, dynamic>{};
    teacherSchedule.forEach((day, lessons) {
      result[day] = lessons;
    });

    return result;
  }

  /// Build master schedule page with all classes
  static pw.Widget _buildMasterSchedulePage(List<Map<String, dynamic>> allSchedules) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'الجدول العام - جميع الفصول',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 12),
        
        // Master table
        pw.Expanded(
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: pw.FixedColumnWidth(40),
              1: pw.FixedColumnWidth(40),
              2: pw.FixedColumnWidth(60),
              ...Map.fromIterable(
                List.generate(7, (i) => i + 3),
                key: (i) => i,
                value: (_) => pw.FlexColumnWidth(),
              ),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.indigo100),
                children: [
                  _buildCompactCell('7', isHeader: true),
                  _buildCompactCell('6', isHeader: true),
                  _buildCompactCell('5', isHeader: true),
                  _buildCompactCell('4', isHeader: true),
                  _buildCompactCell('3', isHeader: true),
                  _buildCompactCell('2', isHeader: true),
                  _buildCompactCell('1', isHeader: true),
                  _buildCompactCell('الفصل', isHeader: true),
                  _buildCompactCell('اليوم', isHeader: true),
                ],
              ),
              
              // Data rows - for each day and each class
              ..._days.expand((day) {
                return allSchedules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final classData = entry.value;
                  final className = classData['className'];
                  final scheduleData = classData['schedule'];
                  
                  Map<String, dynamic> schedule;
                  if (scheduleData is Map<String, dynamic>) {
                    schedule = scheduleData;
                  } else if (scheduleData is Map) {
                    schedule = Map<String, dynamic>.from(scheduleData);
                  } else {
                    schedule = {};
                  }
                  
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      // Periods 7 to 1 (reversed)
                      ...List.generate(7, (i) {
                        final period = 6 - i;
                        try {
                          final daySchedule = schedule[day];
                          if (daySchedule == null) return _buildCompactCell('-');
                          
                          List<dynamic> lessons;
                          if (daySchedule is List) {
                            lessons = daySchedule;
                          } else {
                            return _buildCompactCell('-');
                          }
                          
                          if (period >= lessons.length) return _buildCompactCell('-');
                          
                          final lesson = lessons[period];
                          if (lesson == null) return _buildCompactCell('-');
                          
                          Map<String, dynamic> lessonMap;
                          if (lesson is Map<String, dynamic>) {
                            lessonMap = lesson;
                          } else if (lesson is Map) {
                            lessonMap = Map<String, dynamic>.from(lesson);
                          } else {
                            return _buildCompactCell('-');
                          }
                          
                          if (lessonMap.isEmpty) return _buildCompactCell('-');
                          
                          final subjectName = lessonMap['subjectName']?.toString() ?? '';
                          if (subjectName.isEmpty) return _buildCompactCell('-');
                          
                          return _buildCompactCell(subjectName);
                        } catch (e) {
                          return _buildCompactCell('-');
                        }
                      }),
                      // Class name
                      _buildCompactCell(className, isHeader: true),
                      // Day name (only for first class of each day)
                      index == 0 
                          ? _buildCompactCell(day, isHeader: true, rowSpan: allSchedules.length)
                          : _buildCompactCell(''),
                    ],
                  );
                });
              }),
            ],
          ),
        ),
        
        // Footer
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'تم التوليد: ${DateTime.now().toString().split('.')[0]}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'نظام إتصاك للإدارة المدرسية',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      ],
    );
  }

  /// Build a compact table cell for master schedule
  static pw.Widget _buildCompactCell(String text, {bool isHeader = false, int? rowSpan}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.indigo900 : PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Build a schedule page
  static pw.Widget _buildSchedulePage(
    String title,
    Map<String, dynamic> schedule,
  ) {
    // Calculate teacher load summary if this is a teacher schedule
    final teacherLoadSummary = _calculateTeacherLoadSummary(schedule);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 16),
        
        // Teacher Load Summary (if available)
        if (teacherLoadSummary != null)
          pw.Column(
            children: [
              _buildTeacherLoadSummaryPdf(teacherLoadSummary),
              pw.SizedBox(height: 16),
            ],
          ),
        
        // Table - Days as rows (Ahad to Khamis), periods as columns
        pw.Expanded(
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: pw.FlexColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.FlexColumnWidth(),
              3: pw.FlexColumnWidth(),
              4: pw.FlexColumnWidth(),
              5: pw.FlexColumnWidth(),
              6: pw.FlexColumnWidth(),
              7: pw.FixedColumnWidth(80),
            },
            children: [
              // Header row - periods from 7 to 1, then day column
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.indigo100),
                children: [
                  _buildTableCell('7', isHeader: true),
                  _buildTableCell('6', isHeader: true),
                  _buildTableCell('5', isHeader: true),
                  _buildTableCell('4', isHeader: true),
                  _buildTableCell('3', isHeader: true),
                  _buildTableCell('2', isHeader: true),
                  _buildTableCell('1', isHeader: true),
                  _buildTableCell('اليوم', isHeader: true),
                ],
              ),
              
              // Data rows - one row per day (Ahad first, Khamis last)
              ..._days.map((day) {
                return pw.TableRow(
                  children: [
                    // Periods from 7 to 1 (reversed)
                    ...List.generate(7, (index) {
                      final period = 6 - index; // 6, 5, 4, 3, 2, 1, 0
                      try {
                        final daySchedule = schedule[day];
                        if (daySchedule == null) {
                          return _buildTableCell('-');
                        }
                        
                        List<dynamic> lessons;
                        if (daySchedule is List) {
                          lessons = daySchedule;
                        } else {
                          return _buildTableCell('-');
                        }
                        
                        if (period >= lessons.length) {
                          return _buildTableCell('-');
                        }
                        
                        final lesson = lessons[period];
                        if (lesson == null) {
                          return _buildTableCell('-');
                        }
                        
                        Map<String, dynamic> lessonMap;
                        if (lesson is Map<String, dynamic>) {
                          lessonMap = lesson;
                        } else if (lesson is Map) {
                          lessonMap = Map<String, dynamic>.from(lesson);
                        } else {
                          return _buildTableCell('-');
                        }
                        
                        if (lessonMap.isEmpty) {
                          return _buildTableCell('-');
                        }
                        
                        final subjectName = lessonMap['subjectName']?.toString() ?? '';
                        final className = lessonMap['className']?.toString() ?? '';
                        final teacherName = lessonMap['teacherName']?.toString() ?? '';
                        
                        if (subjectName.isEmpty) {
                          return _buildTableCell('-');
                        }
                        
                        return _buildTableCell(
                          className.isNotEmpty
                              ? '$subjectName\n$className'
                              : teacherName.isNotEmpty
                                  ? '$subjectName\n$teacherName'
                                  : subjectName,
                        );
                      } catch (e) {
                        print('Error processing cell: $e');
                        return _buildTableCell('-');
                      }
                    }),
                    // Day column at the end (right side)
                    _buildTableCell(day, isHeader: true),
                  ],
                );
              }),
            ],
          ),
        ),
        
        // Footer
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'تم التوليد: ${DateTime.now().toString().split('.')[0]}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'نظام إتصاك للإدارة المدرسية',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      ],
    );
  }

  /// Build a table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.indigo900 : PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// Calculate teacher load summary from schedule
  static Map<String, dynamic>? _calculateTeacherLoadSummary(
    Map<String, dynamic> schedule,
  ) {
    int totalLessons = 0;
    int totalPeriods = 0;

    // Count lessons and periods
    for (var day in _days) {
      final daySchedule = schedule[day];
      if (daySchedule == null) continue;

      List<dynamic> lessons;
      if (daySchedule is List) {
        lessons = daySchedule;
      } else {
        continue;
      }

      for (int i = 0; i < lessons.length; i++) {
        totalPeriods++;
        final lesson = lessons[i];
        if (lesson != null) {
          Map<String, dynamic> lessonMap;
          if (lesson is Map<String, dynamic>) {
            lessonMap = lesson;
          } else if (lesson is Map) {
            lessonMap = Map<String, dynamic>.from(lesson);
          } else {
            continue;
          }

          if (lessonMap.isNotEmpty) {
            totalLessons++;
          }
        }
      }
    }

    if (totalLessons == 0) return null;

    final freePeriods = totalPeriods - totalLessons;

    return {
      'totalLessons': totalLessons,
      'freePeriods': freePeriods,
      'totalPeriods': totalPeriods,
      'completionPercentage': totalPeriods > 0
          ? ((totalLessons / totalPeriods) * 100).toStringAsFixed(1)
          : '0',
    };
  }

  /// Build teacher load summary widget for PDF
  static pw.Widget _buildTeacherLoadSummaryPdf(
    Map<String, dynamic> summary,
  ) {
    final totalLessons = summary['totalLessons'] as int;
    final freePeriods = summary['freePeriods'] as int;
    final totalPeriods = summary['totalPeriods'] as int;
    final completionPercentage = summary['completionPercentage'] as String;

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green300, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title
          pw.Text(
            'ملخص حمل المعلم',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 8),

          // Stats Row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfStatBox(
                'الحصص المجدولة',
                totalLessons.toString(),
                PdfColors.blue,
              ),
              _buildPdfStatBox(
                'الفترات الحرة',
                freePeriods.toString(),
                PdfColors.grey,
              ),
              _buildPdfStatBox(
                'إجمالي الفترات',
                totalPeriods.toString(),
                PdfColors.indigo,
              ),
              _buildPdfStatBox(
                'نسبة الإشغال',
                '$completionPercentage%',
                PdfColors.green,
              ),
            ],
          ),

          pw.SizedBox(height: 8),

          // Status message
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'تم تجديول جميع الحصص المطلوبة بنجاح. الفترات الحرة هي أوقات لا يدرّس فيها المعلم.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.green900,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a stat box for PDF
  static pw.Widget _buildPdfStatBox(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
