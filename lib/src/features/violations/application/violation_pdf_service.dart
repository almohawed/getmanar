import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/school.dart';
import '../domain/behavioral_violation.dart';

class ViolationPdfService {
  Future<Uint8List> generateViolationLetter({
    required BehavioralViolation violation,
    required User student,
    required School school,
    required User recorder, // Deputy
    String? principalName,
    String? className,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document();

    final header = await _buildHeader(school);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              header,
              pw.SizedBox(height: 40),
              _buildTitle(),
              pw.SizedBox(height: 30),
              _buildStudentInfo(student, violation, className),
              pw.SizedBox(height: 20),
              _buildBody(violation, student),
              pw.SizedBox(height: 40),
              _buildSignatures(recorder.name, principalName ?? 'مدير المدرسة'),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  Future<pw.Widget> _buildHeader(School school) async {
    pw.MemoryImage? logo;
    // Try loading logo (placeholder logic similar to PdfExportService)
    try {
      final data = await rootBundle.load('images/logokshuf.webp');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Fallback or no logo
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Right: Ministry Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'المملكة العربية السعودية',
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.Text('وزارة التعليم', style: pw.TextStyle(fontSize: 12)),
            pw.Text(
              'الإدارة العامة للتعليم بمنطقة .................',
              style: pw.TextStyle(fontSize: 10),
            ), // Placeholder
            pw.Text(
              'مدرسة: ${school.name}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        // Center: Logo
        if (logo != null)
          pw.Container(height: 70, width: 70, child: pw.Image(logo))
        else
          pw.SizedBox(height: 70, width: 70),

        // Left: Date/Number (Placeholder)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'التاريخ: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'الرقم: .................',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'المرفقات: .................',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTitle() {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text(
          'إشعار بمخالفة سلوكية',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  pw.Widget _buildStudentInfo(
    User student,
    BehavioralViolation violation,
    String? className,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'اسم الطالب: ${student.name}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('رقم الهوية: ${student.identityNumber ?? "---"}'),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('الصف/الفصل: ${className ?? "................"}'),
              pw.Text(
                'تاريخ المخالفة: ${intl.DateFormat('yyyy/MM/dd').format(violation.date)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBody(BehavioralViolation violation, User student) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'المكرم ولي أمر الطالب / ${student.name}    وفقه الله',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'السلام عليكم ورحمة الله وبركاته،،،',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 10),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              const pw.TextSpan(
                text:
                    'نفيدكم بأنه قد لوحظ على ابنكم ارتكاب مخالفة سلوكية من الدرجة ',
              ),
              pw.TextSpan(
                text: _getLevelText(violation.level),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              const pw.TextSpan(text: '، وهي: '),
              pw.TextSpan(
                text: '"${violation.violationTitle}"',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
              const pw.TextSpan(text: '.\n\n'),
              const pw.TextSpan(
                text:
                    'وحيث أن هذه المخالفة تتعارض مع الأنظمة واللوائح السلوكية للمدرسة وتؤثر سلباً على المسيرة التعليمية، نأمل منكم التعاون معنا في توجيه ابنكم والحرص على عدم تكرار ذلك مستقبلاً.\n',
              ),
            ],
            style: pw.TextStyle(fontSize: 12, lineSpacing: 5),
          ),
        ),
        pw.SizedBox(height: 15),
        if (violation.notes != null && violation.notes!.isNotEmpty)
          pw.Text(
            'ملاحظات: ${violation.notes}',
            style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
          ),

        pw.SizedBox(height: 20),
        pw.Text(
          'شاكرين تعاونكم وحرصكم على مصلحة الطالب.',
          style: pw.TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  String _getLevelText(ViolationLevel level) {
    switch (level) {
      case ViolationLevel.firstDegree:
        return 'الأولى';
      case ViolationLevel.secondDegree:
        return 'الثانية';
      case ViolationLevel.thirdDegree:
        return 'الثالثة';
      case ViolationLevel.fourthDegree:
        return 'الرابعة';
      case ViolationLevel.fifthDegree:
        return 'الخامسة';
    }
  }

  pw.Widget _buildSignatures(String deputyName, String principalName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Text(
              'وكيل شؤون الطلاب',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 30), // Space for signature
            pw.Text(deputyName),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'مدير المدرسة',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 30), // Space for signature
            pw.Text(principalName),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Text(
          'تم إصدار هذا الخطاب آلياً عبر نظام "منار" للإدارة المدرسية الذكية',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
