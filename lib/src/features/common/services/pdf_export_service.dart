import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../violations/domain/behavioral_violation.dart';

class PdfExportService {
  final String schoolName;
  final String teacherName;
  final String principalName;
  final bool defaultShowClassInfo;
  final String signerTitle;
  final bool managerOnlyFooter;

  PdfExportService({
    this.schoolName = '',
    this.teacherName = '________________',
    this.principalName = '________________',
    this.defaultShowClassInfo = true,
    this.signerTitle = 'المعلم',
    this.managerOnlyFooter = false,
  });

  // -----------------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------------

  Future<pw.Widget> _buildOfficialHeader(
    String title,
    String className,
    String semester,
    String grade,
    String schoolName, {
    bool showClassInfo = true,
  }) async {
    // Load logo
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('images/logokshuf.webp');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      try {
        final data = await rootBundle.load('images/mylogo.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (e2) {
        print('⚠️ تعذر تحميل الشعار: $e2');
      }
    }

    // Load Arabic font for header
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2.5, color: PdfColors.black),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        children: [
          // Top Row: Ministry Info + Logo + Class Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Right: Ministry Info (RTL -> First item is Right)
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'المملكة العربية السعودية',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'وزارة التعليم',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    if (schoolName.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        schoolName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          font: arabicFont,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'العام الدراسي: 1447هـ',
                      style: pw.TextStyle(
                        fontSize: 10,
                        font: arabicFont,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ),

              // Center: Logo
              pw.Expanded(
                flex: 2,
                child: pw.Center(
                  child: logo != null
                      ? pw.Container(
                          height: 80,
                          width: 80,
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        )
                      : pw.Container(
                          height: 80,
                          width: 80,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'الشعار',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                                font: arabicFont,
                              ),
                              textDirection: pw.TextDirection.rtl,
                            ),
                          ),
                        ),
                ),
              ),

              // Left: Class Info OR Administrative Info (RTL -> Last item is Left)
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (showClassInfo) ...[
                      pw.Text(
                        'الفصل الدراسي: $semester',
                        style: pw.TextStyle(fontSize: 10, font: arabicFont),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'الصف: $grade',
                        style: pw.TextStyle(fontSize: 10, font: arabicFont),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'الشعبة: $className',
                        style: pw.TextStyle(fontSize: 10, font: arabicFont),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ] else ...[
                      pw.Text(
                        'الرقم: ........................',
                        style: pw.TextStyle(fontSize: 10, font: arabicFont),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'التاريخ: ........................',
                        style: pw.TextStyle(fontSize: 10, font: arabicFont),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Divider
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: PdfColors.black),
          pw.SizedBox(height: 8),

          // Title
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Widget> _buildOfficialFooter(
    String teacherName,
    String principalName,
  ) async {
    // Load Arabic font for footer
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

    if (managerOnlyFooter) {
      return pw.Column(
        children: [
          pw.Divider(thickness: 2, color: PdfColors.black),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'مدير المدرسة',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      font: arabicFont,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    width: 150,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                    ),
                    child: pw.Text(
                      principalName,
                      style: pw.TextStyle(fontSize: 11, font: arabicFont),
                      textAlign: pw.TextAlign.center,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'التوقيع: ........................',
                    style: pw.TextStyle(fontSize: 9, font: arabicFont),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return pw.Column(
      children: [
        pw.Divider(thickness: 2, color: PdfColors.black),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left: Teacher/Signer
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    signerTitle,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      font: arabicFont,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    width: 150,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                    ),
                    child: pw.Text(
                      teacherName,
                      style: pw.TextStyle(fontSize: 11, font: arabicFont),
                      textAlign: pw.TextAlign.center,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'التوقيع: ........................',
                    style: pw.TextStyle(fontSize: 9, font: arabicFont),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ),

            // Right: Principal
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'مدير المدرسة',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      font: arabicFont,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    width: 150,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                    ),
                    child: pw.Text(
                      principalName,
                      style: pw.TextStyle(fontSize: 11, font: arabicFont),
                      textAlign: pw.TextAlign.center,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'التوقيع: ........................',
                    style: pw.TextStyle(fontSize: 9, font: arabicFont),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _printGenericReport({
    required String title,
    required List<String> columns,
    required String filenameSuffix,
    List<List<String>>? data,
    String className = '________________',
    String semester = 'الثاني 1447',
    String grade = '________________',
    String? schoolName,
    String? teacherName,
    String? principalName,
    Map<int, pw.Alignment>? cellAlignments,
    Map<int, double>? columnWidths,
    bool landscape = false,
    bool? showClassInfo,
  }) async {
    try {
      print('🔄 بدء تصدير PDF: $title');
      
      // Load Arabic font from assets
      print('🔄 جاري تحميل الخط العربي...');
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final font = pw.Font.ttf(fontData);
      final fontBold = font; // Use same font for bold (Cairo doesn't have separate bold in assets)
      print('✅ تم تحميل الخط بنجاح');
      
      final doc = pw.Document();

    final header = await _buildOfficialHeader(
      title,
      className,
      semester,
      grade,
      schoolName ?? this.schoolName,
      showClassInfo: showClassInfo ?? defaultShowClassInfo,
    );
    final footer = await _buildOfficialFooter(
      teacherName ?? this.teacherName,
      principalName ?? this.principalName,
    );

    // Convert double widths to FixedColumnWidth
    // Handle RTL Table Reversal (Force columns to reverse order for RTL display)
    // This addresses the issue where the table direction appears LTR even with RTL Directionality
    final int colCount = columns.length;
    final List<String> effectiveColumns = columns.reversed.toList();
    final List<List<String>> effectiveData =
        (data ?? List.generate(20, (index) => List.filled(columns.length, '')))
            .map((row) => row.reversed.toList())
            .toList();

    final Map<int, pw.TableColumnWidth>? tableColumnWidths =
        columnWidths != null ? {} : null;
    columnWidths?.forEach((k, v) {
      if (tableColumnWidths != null) {
        tableColumnWidths[colCount - 1 - k] = pw.FixedColumnWidth(v);
      }
    });

    final Map<int, pw.Alignment>? effectiveCellAlignments =
        cellAlignments != null ? {} : null;
    cellAlignments?.forEach((k, v) {
      if (effectiveCellAlignments != null) {
        effectiveCellAlignments[colCount - 1 - k] = v;
      }
    });

    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            header,
            pw.SizedBox(height: 10),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                context: context,
                headers: effectiveColumns,
                data: effectiveData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  font: fontBold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black, // Professional black header
                ),
                cellStyle: pw.TextStyle(fontSize: 10, font: font),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  ),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                cellAlignment: pw.Alignment.center,
                cellAlignments: effectiveCellAlignments,
                columnWidths: tableColumnWidths,
                cellHeight: 25, // Fixed height for professional look
              ),
            ),
            pw.Spacer(), // Push footer to bottom if needed, or just SizedBox
            pw.SizedBox(height: 30),
            footer,
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${filenameSuffix}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    
    print('✅ تم تصدير PDF بنجاح: $title');
  } catch (e, stackTrace) {
    print('❌ خطأ في تصدير PDF: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

  // -----------------------------------------------------------------------------
  // 1. Student Reports
  // -----------------------------------------------------------------------------

  Future<void> printStudentNamesLog(
    List<User> students,
    String className,
  ) async {
    final data = students
        .asMap()
        .entries
        .map(
          (e) => [
            (e.key + 1).toString(),
            e.value.name,
            e.value.identityNumber ?? '',
            '', // Seat No
            '', // Grade
            className,
          ],
        )
        .toList();

    await _printGenericReport(
      title: 'كشف أسماء الطلاب في الشعبة',
      columns: [
        'م',
        'اسم الطالب',
        'رقم الهوية',
        'رقم الجلوس',
        'الصف',
        'الشعبة',
      ],
      filenameSuffix: 'StudentNames',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printStudentsBasicLog(List<User> students) async {
    final data = students
        .asMap()
        .entries
        .map(
          (e) => [
            (e.key + 1).toString(),
            e.value.name,
            e.value.identityNumber ?? '',
            e.value.phoneNumber ?? '',
            e.value.role.name,
          ],
        )
        .toList();

    await _printGenericReport(
      title: 'كشف بيانات الطلاب الأساسية',
      columns: ['م', 'اسم الطالب', 'رقم الهوية', 'الجوال', 'الدور'],
      filenameSuffix: 'StudentsBasic',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printStaffRoster(List<User> staff) async {
    String roleLabel(UserRole role) {
      switch (role) {
        case UserRole.administrative:
          return 'إداري';
        case UserRole.deputy:
          return 'وكيل';
        case UserRole.counselor:
          return 'مرشد طلابي';
        case UserRole.admin:
          return 'مدير';
        case UserRole.technicalSupport:
          return 'دعم فني';
        case UserRole.supportAdmin:
          return 'إدارة دعم';
        default:
          return role.name;
      }
    }

    final data = staff
        .asMap()
        .entries
        .map(
          (e) => [
            (e.key + 1).toString(),
            e.value.name,
            roleLabel(e.value.role),
            e.value.phoneNumber ?? '',
            e.value.nationalId ?? e.value.identityNumber ?? '',
          ],
        )
        .toList();

    await _printGenericReport(
      title: 'كشف الكادر الإداري',
      columns: ['م', 'الاسم', 'الوظيفة', 'الجوال', 'رقم الهوية'],
      filenameSuffix: 'StaffRoster',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
      landscape: true,
    );
  }

  Future<void> printMorningLatenessLog({
    List<StudentAttendance>? records,
    Map<String, String>? classNames,
    String? schoolStartTime,
  }) async {
    List<List<String>> data;
    if (records != null && records.isNotEmpty) {
      final lateRecords = records
          .where(
            (r) =>
                r.status == StudentAttendanceStatus.late &&
                r.arrivalTime != null,
          )
          .toList();
      final startHm = schoolStartTime ?? '06:30';
      final parts = startHm.split(':');
      final startHour = int.tryParse(parts[0]) ?? 6;
      final startMinute =
          int.tryParse(parts.length > 1 ? parts[1] : '30') ?? 30;
      data = lateRecords.asMap().entries.map((e) {
        final index = e.key + 1;
        final r = e.value;
        final arrival = r.arrivalTime!;
        final arrivalLabel = intl.DateFormat.Hm().format(arrival);
        final start = DateTime(
          arrival.year,
          arrival.month,
          arrival.day,
          startHour,
          startMinute,
        );
        final delayMinutes = arrival.isAfter(start)
            ? arrival.difference(start).inMinutes
            : 0;
        final classLabel = classNames != null
            ? (classNames[r.classId] ?? r.classId)
            : r.classId;
        return [
          index.toString(),
          r.studentName,
          classLabel,
          arrivalLabel,
          delayMinutes > 0 ? delayMinutes.toString() : '',
          '',
          '',
        ];
      }).toList();
      if (data.isEmpty) {
        data = List.generate(
          20,
          (i) => [(i + 1).toString(), '', '', '', '', '', ''],
        );
      }
    } else {
      data = List.generate(
        20,
        (i) => [(i + 1).toString(), '', '', '', '', '', ''],
      );
    }
    await _printGenericReport(
      title: 'كشف التأخر الصباحي للطلاب',
      columns: [
        'م',
        'اسم الطالب',
        'الصف',
        'وقت الحضور',
        'مدة التأخير',
        'الإجراء',
        'ملاحظات',
      ],
      filenameSuffix: 'MorningLateness',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printDailySupervisionLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'جدول الإشراف اليومي',
      columns: [
        'اليوم',
        'الموقع',
        'المشرف الأول',
        'المشرف الثاني',
        'وقت الإشراف',
        'ملاحظات',
      ],
      filenameSuffix: 'DailySupervision',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printMorningAssemblyLog() async {
    final data = List.generate(
      15,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'سجل متابعة الطابور الصباحي',
      columns: [
        'م',
        'اليوم / التاريخ',
        'الإذاعة المدرسية',
        'التمارين الصباحية',
        'انتظام الطلاب',
        'ملاحظات',
      ],
      filenameSuffix: 'MorningAssembly',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printExamCommitteesLog({List<List<String>>? rows}) async {
    final data =
        rows ??
        List.generate(20, (i) => [(i + 1).toString(), '', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف توزيع لجان الاختبارات',
      columns: [
        'م',
        'اسم اللجنة',
        'المقر',
        'الملاحظ الأول',
        'الملاحظ الثاني',
        'الصف المختبر',
      ],
      filenameSuffix: 'ExamCommittees',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printExamAbsenceLog({List<List<String>>? rows}) async {
    final data =
        rows ??
        List.generate(20, (i) => [(i + 1).toString(), '', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف الغياب في الاختبارات',
      columns: [
        'م',
        'اسم الطالب',
        'الصف',
        'المادة',
        'يوم الاختبار',
        'سبب الغياب',
      ],
      filenameSuffix: 'ExamAbsence',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printAdministrativeMeetingsLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'محضر اجتماع إداري',
      columns: [
        'م',
        'الموضوع',
        'القرارات / التوصيات',
        'المسؤول عن التنفيذ',
        'وقت التنفيذ',
        'حالة الإنجاز',
      ],
      filenameSuffix: 'AdministrativeMeetings',
      data: data,
      landscape: true,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printComplaintsLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'سجل الشكاوى والمقترحات',
      columns: [
        'م',
        'مقدم الشكوى',
        'صفته',
        'موضوع الشكوى',
        'تاريخ الاستلام',
        'الإجراء المتخذ',
        'النتيجة',
      ],
      filenameSuffix: 'Complaints',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printDailyAttendanceLog(
    List<User> students,
    String className, {
    List<StudentAttendance>? attendanceRecords,
  }) async {
    final recordsByStudent = <String, StudentAttendance>{};
    if (attendanceRecords != null) {
      for (final r in attendanceRecords) {
        recordsByStudent[r.studentId] = r;
      }
    }

    final data = students.asMap().entries.map((e) {
      final index = e.key + 1;
      final student = e.value;
      final rec = recordsByStudent[student.id];

      String present = '';
      String absentExcused = '';
      String absentUnexcused = '';
      String late = '';

      if (rec != null) {
        switch (rec.status) {
          case StudentAttendanceStatus.present:
            present = '✓';
            break;
          case StudentAttendanceStatus.excused:
            absentExcused = '✓';
            break;
          case StudentAttendanceStatus.absent:
            absentUnexcused = '✓';
            break;
          case StudentAttendanceStatus.late:
            late = '✓';
            break;
        }
      }

      return [
        index.toString(),
        student.name,
        present,
        absentExcused,
        absentUnexcused,
        late,
        '',
      ];
    }).toList();

    await _printGenericReport(
      title: 'كشف الحضور والغياب اليومي',
      columns: [
        'م',
        'اسم الطالب',
        'حضور',
        'غياب (بعذر)',
        'غياب (بدون)',
        'تأخير',
        'ملاحظات',
      ],
      filenameSuffix: 'DailyAttendance',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
      columnWidths: {0: 30, 1: 150, 2: 40, 3: 50, 4: 50, 5: 40, 6: 80},
    );
  }

  Future<void> printBehaviorLog(
    List<User> students,
    String className, {
    List<BehaviorRecord>? records,
    bool filled = false,
  }) async {
    // If filled and records provided, list records. Else list empty rows or students?
    // User requested: Name, Type, Description, Action, Date, Notes.
    // This implies a transaction log.

    List<List<String>> data;
    if (filled && records != null && records.isNotEmpty) {
      data = records.asMap().entries.map((e) {
        final r = e.value;
        final studentName = students
            .firstWhere(
              (s) => s.id == r.studentId,
              orElse: () => User(
                id: '',
                name: 'Unknown',
                email: '',
                role: UserRole.student,
              ),
            )
            .name;
        return <String>[
          (e.key + 1).toString(),
          studentName,
          r.type == BehaviorType.positive ? 'إيجابي' : 'سلبي',
          r.description,
          '', // Action
          intl.DateFormat('yyyy-MM-dd').format(r.timestamp),
          '', // Notes
        ];
      }).toList();
    } else {
      // Empty template
      data = List.generate(
        15,
        (i) => [(i + 1).toString(), '', '', '', '', '', ''],
      );
    }

    await _printGenericReport(
      title: 'كشف السلوك والملاحظات التربوية',
      columns: [
        'م',
        'اسم الطالب',
        'نوع السلوك',
        'وصف السلوك',
        'الإجراء المتخذ',
        'تاريخ',
        'ملاحظات',
      ],
      filenameSuffix: 'BehaviorLog',
      data: data,
      className: className,
      cellAlignments: {
        1: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: {0: 30, 1: 120, 2: 50, 3: 100, 4: 80, 5: 60, 6: 80},
    );
  }

  Future<void> printAcademicDelayLog(
    List<User> students,
    String className,
  ) async {
    final data = List.generate(
      15,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف الطلاب المتأخرين دراسياً',
      columns: [
        'م',
        'اسم الطالب',
        'المادة',
        'مستوى الأداء',
        'سبب التأخر',
        'نوع الدعم',
        'متابعة',
      ],
      filenameSuffix: 'AcademicDelay',
      data: data,
      className: className,
    );
  }

  Future<void> printStudentFollowupLog(
    List<User> students,
    String className, {
    required List<BehaviorRecord> records,
    bool filled = false,
    Map<String, int>? absenceDays,
    Map<String, int>? tardinessCount,
    Map<String, int>? excellenceScores,
  }) async {
    List<List<String>> data;
    if (filled) {
      data = students.asMap().entries.map((e) {
        final index = e.key + 1;
        final student = e.value;
        final studentRecords = records
            .where((r) => r.studentId == student.id)
            .toList();
        final positiveCount = studentRecords
            .where((r) => r.type == BehaviorType.positive)
            .length;
        final negativeCount = studentRecords
            .where((r) => r.type == BehaviorType.negative)
            .length;
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
        final abs = absenceDays != null ? absenceDays[student.id] : null;
        final late = tardinessCount != null ? tardinessCount[student.id] : null;
        final sei = excellenceScores != null
            ? excellenceScores[student.id]
            : null;
        return <String>[
          index.toString(),
          student.name,
          student.identityNumber ?? '-',
          positiveCount.toString(),
          negativeCount.toString(),
          homeworkCount.toString(),
          testCount.toString(),
          abs?.toString() ?? '',
          late?.toString() ?? '',
          sei?.toString() ?? '',
          '',
        ];
      }).toList();
    } else {
      data = students.asMap().entries.map((e) {
        final index = e.key + 1;
        final student = e.value;
        return <String>[
          index.toString(),
          student.name,
          student.identityNumber ?? '-',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ];
      }).toList();
    }

    await _printGenericReport(
      title: 'سجل متابعة الطلاب',
      columns: [
        'م',
        'اسم الطالب',
        'الرقم الأكاديمي',
        'السلوكيات الإيجابية',
        'السلوكيات السلبية',
        'الواجبات (لم يحل)',
        'الاختبارات (لم يحل)',
        'أيام الغياب',
        'مرات التأخر',
        'مؤشر التميز (0-100)',
        'ملاحظات',
      ],
      filenameSuffix: 'StudentFollowup',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  // -----------------------------------------------------------------------------
  // 2. Evaluation & Grades
  // -----------------------------------------------------------------------------

  Future<void> printQuarterlyGradesLog(
    List<User> students,
    String className,
  ) async {
    final data = students
        .asMap()
        .entries
        .map((e) => [(e.key + 1).toString(), e.value.name, '', '', '', ''])
        .toList();

    await _printGenericReport(
      title: 'كشف درجات الأعمال الفصلية',
      columns: [
        'م',
        'اسم الطالب',
        'الواجبات',
        'المشاركات',
        'الاختبارات القصيرة',
        'المجموع',
      ],
      filenameSuffix: 'QuarterlyGrades',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printMonthlyTestsLog(
    List<User> students,
    String className, {
    Map<String, double>? month1Scores,
    Map<String, double>? month2Scores,
  }) async {
    final data = students.asMap().entries.map((e) {
      final index = e.key + 1;
      final s = e.value;
      final m1 = month1Scores != null ? month1Scores[s.id] : null;
      final m2 = month2Scores != null ? month2Scores[s.id] : null;
      final total = (m1 ?? 0) + (m2 ?? 0);
      return [
        index.toString(),
        s.name,
        m1 != null ? m1.toStringAsFixed(1) : '',
        m2 != null ? m2.toStringAsFixed(1) : '',
        (m1 != null || m2 != null) ? total.toStringAsFixed(1) : '',
      ];
    }).toList();

    await _printGenericReport(
      title: 'كشف درجات الاختبارات الشهرية',
      columns: [
        'م',
        'اسم الطالب',
        'اختبار الشهر الأول',
        'اختبار الشهر الثاني',
        'المجموع',
      ],
      filenameSuffix: 'MonthlyTests',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printMidtermGradesLog(
    List<User> students,
    String className,
  ) async {
    final data = students
        .asMap()
        .entries
        .map((e) => [(e.key + 1).toString(), e.value.name, '', ''])
        .toList();

    await _printGenericReport(
      title: 'كشف درجات منتصف الفصل',
      columns: ['م', 'اسم الطالب', 'درجة الاختبار', 'التقدير'],
      filenameSuffix: 'MidtermGrades',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printFinalGradesLog(
    List<User> students,
    String className,
  ) async {
    final data = students
        .asMap()
        .entries
        .map((e) => [(e.key + 1).toString(), e.value.name, '', ''])
        .toList();

    await _printGenericReport(
      title: 'كشف درجات نهاية الفصل',
      columns: ['م', 'اسم الطالب', 'درجة الاختبار النهائي', 'التقدير'],
      filenameSuffix: 'FinalGrades',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printFinalRecordLog(
    List<User> students,
    String className,
  ) async {
    final data = students
        .asMap()
        .entries
        .map((e) => [(e.key + 1).toString(), e.value.name, '', '', '', ''])
        .toList();

    await _printGenericReport(
      title: 'كشف الرصد النهائي',
      columns: [
        'م',
        'اسم الطالب',
        'أعمال السنة',
        'اختبار نهائي',
        'المجموع',
        'التقدير',
      ],
      filenameSuffix: 'FinalRecord',
      data: data,
      className: className,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  Future<void> printStrugglingStudentsLog(
    List<User> students,
    String className,
  ) async {
    final data = List.generate(
      15,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف الطلاب المتعثرين دراسياً',
      columns: [
        'م',
        'اسم الطالب',
        'المادة',
        'مستوى التعثر',
        'خطة العلاج',
        'متابعة',
      ],
      filenameSuffix: 'StrugglingStudents',
      data: data,
      className: className,
    );
  }

  // -----------------------------------------------------------------------------
  // 3. Planning & Follow-up
  // -----------------------------------------------------------------------------

  Future<void> printPreparationLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف التحضير اليومي / الأسبوعي',
      columns: ['اليوم', 'الحصة', 'الدرس', 'الأهداف', 'الوسائل', 'التقويم'],
      filenameSuffix: 'Preparation',
      data: data,
      landscape: true,
    );
  }

  Future<void> printCurriculumDistributionLog() async {
    final data = List.generate(18, (i) => [(i + 1).toString(), '', '', '']);
    await _printGenericReport(
      title: 'خطة توزيع المنهج',
      columns: ['الأسبوع', 'الدرس', 'عدد الحصص', 'ملاحظات'],
      filenameSuffix: 'Curriculum',
      data: data,
    );
  }

  Future<void> printLessonExecutionLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف تنفيذ الدروس',
      columns: ['التاريخ', 'الدرس', 'تم التنفيذ', 'سبب عدم التنفيذ', 'ملاحظات'],
      filenameSuffix: 'LessonExecution',
      data: data,
    );
  }

  Future<void> printClassActivitiesLog() async {
    final data = List.generate(15, (i) => ['', '', '', '']);
    await _printGenericReport(
      title: 'كشف الأنشطة الصفية',
      columns: ['التاريخ', 'اسم النشاط', 'عدد الطلاب', 'ملاحظات'],
      filenameSuffix: 'ClassActivities',
      data: data,
    );
  }

  Future<void> printExtracurricularActivitiesLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف الأنشطة اللاصفية',
      columns: ['التاريخ', 'النشاط', 'المكان', 'المشرف', 'ملاحظات'],
      filenameSuffix: 'Extracurricular',
      data: data,
    );
  }

  Future<void> printWaitingClassesLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف حصص الانتظار',
      columns: ['التاريخ', 'الحصة', 'الصف', 'سبب الانتظار', 'اسم المعلم'],
      filenameSuffix: 'WaitingClasses',
      data: data,
    );
  }

  // -----------------------------------------------------------------------------
  // 4. Communication & Guidance
  // -----------------------------------------------------------------------------

  Future<void> printParentCommunicationLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف التواصل مع أولياء الأمور',
      columns: [
        'التاريخ',
        'اسم الطالب',
        'اسم ولي الأمر',
        'وسيلة التواصل',
        'سبب التواصل',
        'النتيجة',
      ],
      filenameSuffix: 'ParentCommunication',
      data: data,
      landscape: true,
    );
  }

  Future<void> printParentMeetingsLog() async {
    final data = List.generate(15, (i) => ['', '', '', '']);
    await _printGenericReport(
      title: 'كشف الاجتماعات مع ولي الأمر',
      columns: ['التاريخ', 'اسم الطالب', 'سبب الاجتماع', 'التوصيات'],
      filenameSuffix: 'ParentMeetings',
      data: data,
    );
  }

  Future<void> printSpecialCasesLog() async {
    final data = List.generate(15, (i) => ['', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف الحالات الخاصة',
      columns: ['اسم الطالب', 'نوع الحالة', 'الوصف', 'الإجراء', 'المتابعة'],
      filenameSuffix: 'SpecialCases',
      data: data,
    );
  }

  // -----------------------------------------------------------------------------
  // 5. Deputy Reports (Official)
  // -----------------------------------------------------------------------------

  Future<void> printTeacherAttendanceDepartureLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف حضور وانصراف المعلمين',
      columns: [
        'م',
        'اسم المعلم',
        'التخصص',
        'وقت الحضور',
        'وقت الانصراف',
        'تأخير (نعم / لا)',
        'ملاحظات',
      ],
      filenameSuffix: 'TeacherAttendanceDeparture',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printScheduleLog() async {
    final data = List.generate(20, (i) => ['', '', '', '', '', '']);
    await _printGenericReport(
      title: 'كشف جدول الحصص',
      columns: ['اليوم', 'الحصة', 'اسم المعلم', 'المادة', 'الصف', 'الفصل'],
      filenameSuffix: 'ScheduleLog',
      data: data,
      showClassInfo: false,
    );
  }

  Future<void> printGeneralDailyAbsenceLog({
    List<StudentAttendance>? attendanceRecords,
    Map<String, String>? classNames,
  }) async {
    List<List<String>> data;
    if (attendanceRecords != null && attendanceRecords.isNotEmpty) {
      final absents = attendanceRecords
          .where(
            (r) =>
                r.status == StudentAttendanceStatus.absent ||
                r.status == StudentAttendanceStatus.excused,
          )
          .toList();
      data = absents.asMap().entries.map((e) {
        final index = e.key + 1;
        final record = e.value;
        final classLabel = classNames != null
            ? (classNames[record.classId] ?? record.classId)
            : record.classId;
        return [index.toString(), record.studentName, classLabel, '', '', ''];
      }).toList();
      if (data.isEmpty) {
        data = List.generate(
          20,
          (i) => [(i + 1).toString(), '', '', '', '', ''],
        );
      }
    } else {
      data = List.generate(20, (i) => [(i + 1).toString(), '', '', '', '', '']);
    }
    await _printGenericReport(
      title: 'كشف الغياب اليومي العام للطلاب',
      columns: [
        'م',
        'اسم الطالب',
        'الصف',
        'سبب الغياب',
        'هل تم التواصل؟',
        'ملاحظات',
      ],
      filenameSuffix: 'GeneralDailyAbsence',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printTeacherLateArrivalLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف تأخر المعلمين',
      columns: [
        'م',
        'اسم المعلم',
        'التاريخ',
        'وقت الحضور',
        'مدة التأخير',
        'العذر',
        'الإجراء',
      ],
      filenameSuffix: 'TeacherLateArrival',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printTeacherEarlyDepartureLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف الاستئذان والانصراف المبكر',
      columns: [
        'م',
        'اسم المعلم',
        'التاريخ',
        'وقت الخروج',
        'سبب الخروج',
        'وقت العودة',
        'ملاحظات',
      ],
      filenameSuffix: 'TeacherEarlyDeparture',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printWaitingDistributionLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف توزيع حصص الانتظار',
      columns: [
        'م',
        'المعلم الغائب',
        'الحصة',
        'الصف',
        'المعلم البديل',
        'توقيع البديل',
      ],
      filenameSuffix: 'WaitingDistribution',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printViolationsSummaryLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف ملخص المخالفات السلوكية',
      columns: [
        'م',
        'اسم الطالب',
        'الصف',
        'نوع المخالفة',
        'تكرار المخالفة',
        'الإجراء المتخذ',
        'ملاحظات',
      ],
      filenameSuffix: 'ViolationsSummary',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printMaintenanceRequestsLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'كشف طلبات الصيانة',
      columns: [
        'م',
        'الموقع / الغرفة',
        'نوع العطل',
        'تاريخ الإبلاغ',
        'حالة الطلب',
        'ملاحظات',
      ],
      filenameSuffix: 'MaintenanceRequests',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printSchoolActivityPlanLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'خطة النشاط المدرسي',
      columns: [
        'م',
        'اسم النشاط',
        'الهدف',
        'الفئة المستهدفة',
        'وقت التنفيذ',
        'المسؤول',
      ],
      filenameSuffix: 'SchoolActivityPlan',
      data: data,
      landscape: true,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printVisitorLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'سجل الزيارات الرسمية',
      columns: [
        'م',
        'اسم الزائر',
        'الجهة',
        'صفته',
        'تاريخ الزيارة',
        'الهدف من الزيارة',
        'ملاحظات',
      ],
      filenameSuffix: 'VisitorLog',
      data: data,
      landscape: true,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printAdministrativeDecisionsLog() async {
    final data = List.generate(
      20,
      (i) => [(i + 1).toString(), '', '', '', '', ''],
    );
    await _printGenericReport(
      title: 'سجل القرارات الإدارية',
      columns: [
        'م',
        'رقم القرار',
        'تاريخ القرار',
        'موضوع القرار',
        'الجهة المعنية',
        'التوقيع',
      ],
      filenameSuffix: 'AdministrativeDecisions',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
      showClassInfo: false,
    );
  }

  Future<void> printBehavioralViolationsLog({
    List<BehavioralViolation>? violations,
  }) async {
    List<List<String>> data;
    if (violations != null && violations.isNotEmpty) {
      String _levelLabel(ViolationLevel level) {
        switch (level) {
          case ViolationLevel.firstDegree:
            return 'الدرجة الأولى';
          case ViolationLevel.secondDegree:
            return 'الدرجة الثانية';
          case ViolationLevel.thirdDegree:
            return 'الدرجة الثالثة';
          case ViolationLevel.fourthDegree:
            return 'الدرجة الرابعة';
          case ViolationLevel.fifthDegree:
            return 'الدرجة الخامسة';
        }
      }

      data = violations.asMap().entries.map((e) {
        final index = e.key + 1;
        final v = e.value;
        return [
          index.toString(),
          v.studentName,
          '',
          v.violationTitle,
          _levelLabel(v.level),
          v.actionTaken ?? '',
          v.notes ?? '',
        ];
      }).toList();
    } else {
      data = List.generate(
        15,
        (i) => [(i + 1).toString(), '', '', '', '', '', ''],
      );
    }
    await _printGenericReport(
      title: 'كشف المخالفات السلوكية',
      columns: [
        'م',
        'اسم الطالب',
        'الصف',
        'نوع المخالفة',
        'درجة المخالفة',
        'الإجراء الإداري',
        'ملاحظات',
      ],
      filenameSuffix: 'BehavioralViolations',
      data: data,
    );
  }

  // -----------------------------------------------------------------------------
  // Legacy / Wrappers
  // -----------------------------------------------------------------------------

  // Kept for backward compatibility with ClassDetailsScreen
  Future<void> printStudentLog({
    required String className,
    required List<User> students,
    required List<BehaviorRecord> records,
    required bool filled,
  }) async {
    await printBehaviorLog(
      students,
      className,
      records: records,
      filled: filled,
    );
  }

  // Kept for backward compatibility with ReportsScreen (Deputy)
  Future<void> printTeacherAttendanceLog({
    required List<User> teachers,
    required Map<String, Map<String, dynamic>> attendanceData,
    required bool filled,
  }) async {
    final data = teachers.asMap().entries.map((e) {
      final t = e.value;
      String abs = '';
      String lat = '';
      if (filled) {
        final d = attendanceData[t.id] ?? {};
        if (d['absence'] != null && d['absence'] > 0) {
          abs = d['absence'].toString();
        }
        if (d['lateness'] != null && d['lateness'] > 0) {
          lat = d['lateness'].toString();
        }
      }
      return [
        (e.key + 1).toString(),
        t.name,
        '', // Present
        abs, // Absent
        lat, // Late
        '', // Notes
      ];
    }).toList();

    await _printGenericReport(
      title: 'كشف متابعة غياب وتأخر المعلمين',
      columns: ['م', 'اسم المعلم', 'حضور', 'غياب', 'تأخير (دقيقة)', 'ملاحظات'],
      filenameSuffix: 'TeacherAttendance',
      data: data,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }
}
