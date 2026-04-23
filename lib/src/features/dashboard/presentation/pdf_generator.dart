import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
// To get students/classes

class PdfGenerator {
  static Future<Uint8List> generateReport({
    required String reportType, // 'daily', 'weekly', 'monthly'
    required bool isFilled,
    required String className,
    required List<dynamic> students, // List of students in the class
  }) async {
    final pdf = pw.Document();

    // Load Arabic font
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('images/logokshuf.webp');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      try {
        final logoData = await rootBundle.load('images/mylogo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (e2) {
        // Ignore if logo fails
      }
    }

    // Create a page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            _buildOfficialHeader(reportType, className, logoImage),
            pw.SizedBox(height: 20),
            _buildTable(students, isFilled, reportType),
            pw.SizedBox(height: 40),
            _buildOfficialFooter(),
          ];
        },
        footer: (context) => _buildPageFooter(context),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildOfficialHeader(
    String reportType,
    String className,
    pw.MemoryImage? logo,
  ) {
    String title = _getReportTitle(reportType);

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Right Side: Ministry Info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'المملكة العربية السعودية',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text('وزارة التعليم', style: pw.TextStyle(fontSize: 10)),
                pw.Text('إدارة التعليم', style: pw.TextStyle(fontSize: 10)),
                pw.Text(
                  'منصة منار',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Center: Logo & Title
            pw.Column(
              children: [
                // Logo
                pw.Container(
                  width: 60,
                  height: 60,
                  child: logo != null
                      ? pw.Image(logo)
                      : pw.Container(
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(
                              color: PdfColors.black,
                              width: 1,
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'شعار',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ],
            ),

            // Left Side: Date & Info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'التاريخ: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'العام الدراسي: 1445 هـ',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'الفصل الدراسي: الثالث',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'الفصل: $className',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2),
      ],
    );
  }

  static pw.Widget _buildOfficialFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildSignatureBlock('معلم المادة'),
        _buildSignatureBlock('وكيل شؤون الطلاب'),
        _buildSignatureBlock('مدير المدرسة', withStamp: true),
      ],
    );
  }

  static pw.Widget _buildSignatureBlock(
    String title, {
    bool withStamp = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 40),
        pw.Text('....................'),
        if (withStamp) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColors.blue900, width: 2),
            ),
            child: pw.Center(
              child: pw.Text(
                'الختم\nالرسمي',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.blue900,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'صفحة ${context.pageNumber} من ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static String _getReportTitle(String reportType) {
    switch (reportType) {
      // Teacher
      case 'daily_attendance':
        return 'كشف متابعة يومي';
      case 'weekly_followup':
        return 'كشف متابعة أسبوعي';
      case 'monthly_followup':
        return 'كشف متابعة شهري';
      case 'assignments_followup':
        return 'كشف متابعة الواجبات';
      case 'tests_followup':
        return 'كشف متابعة الاختبارات';
      case 'participation_behavior':
        return 'كشف متابعة المشاركة والسلوك';
      case 'comprehensive_teacher':
        return 'الكشف الشامل (معلم)';

      // Deputy
      case 'deputy_referrals':
        return 'كشف المخالفات المحالة للوكيل';
      case 'student_repeated_violations':
        return 'كشف المخالفات المتكررة للطلاب';
      case 'students_need_intervention':
        return 'كشف الطلاب الذين يحتاجون تدخل إداري';
      case 'violations_by_class':
        return 'كشف المخالفات حسب الصفوف';
      case 'comprehensive_deputy':
        return 'الكشف الشامل (وكيل)';

      // Counselor
      case 'counselor_referrals':
        return 'كشف المخالفات المحالة للمرشد';
      case 'students_repeated_behaviors':
        return 'كشف متابعة الطلاب ذوي السلوكيات المتكررة';
      case 'support_plan':
        return 'كشف خطة الدعم والإرشاد لكل طالب';
      case 'monthly_behavior_stats':
        return 'كشف الإحصائيات الشهرية للسلوكيات';
      case 'comprehensive_counselor':
        return 'الكشف الشامل (مرشد)';

      // Admin
      case 'admin_daily_violations':
        return 'كشف المخالفات اليومية';
      case 'admin_weekly_violations':
        return 'كشف المخالفات الأسبوعية';
      case 'admin_monthly_stats':
        return 'كشف المخالفات الشهرية والإحصائيات';
      case 'admin_repeated_violations':
        return 'كشف الطلاب ذوي المخالفات المتكررة';
      case 'violations_by_teacher':
        return 'كشف المخالفات حسب المعلم';
      case 'violations_by_type':
        return 'كشف المخالفات حسب النوع';
      case 'comprehensive_admin':
        return 'الكشف الشامل (مدير)';

      // Default
      case 'daily':
        return 'كشف غياب يومي';
      case 'weekly':
        return 'كشف متابعة أسبوعي';
      case 'monthly':
        return 'كشف متابعة شهري';
      default:
        return 'تقرير';
    }
  }

  static pw.Widget _buildTable(
    List<dynamic> students,
    bool isFilled,
    String reportType,
  ) {
    // Define headers based on report type
    List<String> headers = ['م', 'اسم الطالب'];
    List<String> dynamicHeaders = [];

    // Determine columns based on type
    if (reportType.contains('referrals') || reportType.contains('violations')) {
      dynamicHeaders = ['نوع المخالفة', 'التاريخ', 'الإجراء المتخذ', 'ملاحظات'];
    } else if (reportType.contains('assignments') ||
        reportType.contains('tests')) {
      dynamicHeaders = ['الموضوع', 'الدرجة/التقييم', 'ملاحظات'];
    } else if (reportType.contains('participation') ||
        reportType.contains('behavior') ||
        reportType.contains('stats')) {
      dynamicHeaders = ['المشاركة', 'السلوك', 'ملاحظات'];
    } else if (reportType.contains('plan') ||
        reportType.contains('intervention')) {
      dynamicHeaders = ['المشكلة', 'خطة التدخل', 'النتائج'];
    } else if (reportType.contains('comprehensive')) {
      dynamicHeaders = ['الحضور', 'السلوك', 'المستوى الأكاديمي', 'ملاحظات'];
    } else if (reportType.contains('daily') ||
        reportType == 'daily_attendance') {
      dynamicHeaders = ['الحالة', 'ملاحظات'];
    } else if (reportType.contains('weekly') ||
        reportType == 'weekly_followup') {
      dynamicHeaders = [
        'الأحد',
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'ملاحظات',
      ];
    } else if (reportType.contains('monthly') ||
        reportType == 'monthly_followup') {
      dynamicHeaders = [
        'الأسبوع 1',
        'الأسبوع 2',
        'الأسبوع 3',
        'الأسبوع 4',
        'ملاحظات',
      ];
    } else {
      dynamicHeaders = ['ملاحظات'];
    }

    headers.addAll(dynamicHeaders);

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: List<List<String>>.generate(students.length, (index) {
        final student = students[index];
        List<String> row = ['${index + 1}', student.name];

        for (var header in dynamicHeaders) {
          row.add('');
        }
        return row;
      }),
      border: pw.TableBorder.all(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerRight, // Name alignment
      },
    );
  }

  // Removed _buildFooter as it is replaced by _buildOfficialFooter and _buildPageFooter
}
