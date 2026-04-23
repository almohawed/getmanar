import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/services.dart' show rootBundle;
import '../../intelligence/domain/school_health_index.dart';

class SchoolReportGenerator {
  static Future<pw.Document> generateReport({
    required String schoolName,
    required SchoolHealthIndex healthIndex,
    required double teacherPlanAdherence,
    required double remedialExecutionRate,
    required double examAdherence,
    required List<String> risks,
    String? adminRegion,
  }) async {
    final pdf = pw.Document();

    final ttf = await PdfGoogleFonts.cairoRegular();
    final boldTtf = await PdfGoogleFonts.cairoBold();
    final logo = await _loadLogo();

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) =>
            _buildHeader(context, schoolName, adminRegion, ttf, boldTtf, logo),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          _buildReportTitle(boldTtf),
          pw.SizedBox(height: 20),
          _buildScorecard(healthIndex, boldTtf, ttf),
          pw.SizedBox(height: 20),
          _buildGovernanceSection(
            teacherPlanAdherence,
            remedialExecutionRate,
            examAdherence,
            healthIndex.attendanceScore / 100.0,
            boldTtf,
            ttf,
          ),
          pw.SizedBox(height: 20),
          _buildRisksSection(risks, boldTtf, ttf),
          pw.SizedBox(height: 20),
          _buildExecutiveSummary(healthIndex, risks, boldTtf, ttf),
          pw.SizedBox(height: 40),
          _buildSignatures(ttf, boldTtf),
        ],
      ),
    );

    return pdf;
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('images/logokshuf.webp');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final fallback = await rootBundle.load('images/mylogo.png');
        return pw.MemoryImage(fallback.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  static pw.Widget _buildHeader(
    pw.Context context,
    String schoolName,
    String? adminRegion,
    pw.Font font,
    pw.Font boldFont,
    pw.MemoryImage? logo,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Right side: ministry info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "المملكة العربية السعودية",
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                ),
                pw.Text(
                  "وزارة التعليم",
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                ),
                pw.Text(
                  (adminRegion != null && adminRegion.isNotEmpty)
                      ? adminRegion
                      : "إدارة التعليم العام",
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.Text(
                  schoolName,
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
              ],
            ),
            // Center: Logo
            if (logo != null)
              pw.Container(width: 60, height: 60, child: pw.Image(logo))
            else
              pw.SizedBox(width: 60, height: 60),
            // Left side: Date info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "التاريخ: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}",
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.Text(
                  "المرفقات: تقرير تفصيلي",
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildReportTitle(pw.Font boldFont) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            "تقرير الأداء المؤسسي الشامل",
            style: pw.TextStyle(font: boldFont, fontSize: 18),
          ),
          pw.Text(
            "Institutional Performance Report",
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScorecard(
    SchoolHealthIndex index,
    pw.Font boldFont,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem("الصحة العامة", index.overallScore, boldFont, font),
          _buildScoreItem("السلوك", index.behaviorScore, boldFont, font),
          _buildScoreItem("المواظبة", index.attendanceScore, boldFont, font),
          _buildScoreItem("الاستقرار", index.stabilityScore, boldFont, font),
        ],
      ),
    );
  }

  static pw.Widget _buildScoreItem(
    String label,
    double score,
    pw.Font boldFont,
    pw.Font font,
  ) {
    PdfColor color = PdfColors.green700;
    if (score < 70)
      color = PdfColors.red700;
    else if (score < 85)
      color = PdfColors.orange700;

    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text(
          "${score.toStringAsFixed(1)}%",
          style: pw.TextStyle(font: boldFont, fontSize: 14, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildGovernanceSection(
    double teacherPlan,
    double remedialPlan,
    double examCompliance,
    double attendance,
    pw.Font boldFont,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "مؤشرات الحوكمة والالتزام",
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell("المؤشر", boldFont, isHeader: true),
                _buildTableCell("النسبة", boldFont, isHeader: true),
                _buildTableCell("التقييم", boldFont, isHeader: true),
              ],
            ),
            _buildGovernanceRow("التزام المعلمين بالخطة", teacherPlan, font),
            _buildGovernanceRow("تنفيذ الخطط العلاجية", remedialPlan, font),
            _buildGovernanceRow("انضباط الاختبارات", examCompliance, font),
            _buildGovernanceRow("انتظام الحضور العام", attendance, font),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _buildGovernanceRow(
    String label,
    double value,
    pw.Font font,
  ) {
    String rating = "متميز";
    PdfColor color = PdfColors.green;
    if (value < 0.80) {
      rating = "منخفض";
      color = PdfColors.red;
    } else if (value < 0.90) {
      rating = "جيد";
      color = PdfColors.orange;
    }

    return pw.TableRow(
      children: [
        _buildTableCell(label, font),
        _buildTableCell("${(value * 100).toStringAsFixed(1)}%", font),
        _buildTableCell(rating, font, color: color),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildRisksSection(
    List<String> risks,
    pw.Font boldFont,
    pw.Font font,
  ) {
    if (risks.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "المخاطر والتنبيهات الحرجة",
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: PdfColors.red900,
          ),
        ),
        pw.SizedBox(height: 10),
        ...risks.map(
          (risk) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "• ",
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
                pw.Expanded(
                  child: pw.Text(
                    risk,
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildExecutiveSummary(
    SchoolHealthIndex index,
    List<String> risks,
    pw.Font boldFont,
    pw.Font font,
  ) {
    String summary =
        "بناءً على تحليل البيانات المؤسسية، تظهر المدرسة مستوى ${(index.overallScore >= 90) ? 'متميز' : 'جيد'} من الاستقرار الإداري والأكاديمي. ";
    if (risks.isNotEmpty) {
      summary +=
          "ومع ذلك، توجد بعض مؤشرات الخطر التي تتطلب تدخلاً فورياً، خاصة فيما يتعلق بـ ${risks.length} تنبيهات مرصودة. ";
    } else {
      summary += "ولا توجد مؤشرات خطر حرجة حالياً. ";
    }
    summary += "يوصى بالاستمرار في متابعة مؤشرات الحوكمة لضمان استدامة الأداء.";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "الملخص التنفيذي",
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            summary,
            style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatures(pw.Font font, pw.Font boldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Text(
              "وكيل الشؤون التعليمية",
              style: pw.TextStyle(font: boldFont),
            ),
            pw.SizedBox(height: 40),
            pw.Text("....................", style: pw.TextStyle(font: font)),
          ],
        ),
        pw.Column(
          children: [
            pw.Text("مدير المدرسة", style: pw.TextStyle(font: boldFont)),
            pw.SizedBox(height: 40),
            pw.Text("....................", style: pw.TextStyle(font: font)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Center(
      child: pw.Text(
        "نظام منار - تقرير رسمي معتمد - ${intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}
