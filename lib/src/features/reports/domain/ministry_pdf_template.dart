import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // For PdfGoogleFonts
import 'package:intl/intl.dart' as intl;

class MinistryPdfTemplate {
  static Future<pw.Document> generateReport({
    required String title,
    required String schoolName,
    required String subTitle,
    required List<String> tableHeaders,
    required List<List<String>> tableData,
    required String footerText,
    String? dateFrom,
    String? dateTo,
    String? adminRegion,
    PdfPageFormat? pageFormat,
    List<pw.Widget>? contentWidgets,
    bool includeSignatures = true,
  }) async {
    final pdf = pw.Document();

    final ttf = await PdfGoogleFonts.cairoRegular();
    final boldTtf = await PdfGoogleFonts.cairoBold();
    final logo = await _loadLogo();

    final resolvedPageFormat = pageFormat ?? PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: resolvedPageFormat,
          theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) =>
            _buildHeader(context, schoolName, adminRegion, ttf, boldTtf, logo),
        footer: (context) => _buildFooter(context, footerText, ttf),
        build: (context) => [
          _buildReportTitle(title, subTitle, dateFrom, dateTo, boldTtf),
          pw.SizedBox(height: 20),
          if (contentWidgets != null)
            ...contentWidgets,
          _buildTable(tableHeaders, tableData, ttf, boldTtf),
          if (includeSignatures) ...[
            pw.SizedBox(height: 40),
            _buildSignatures(ttf, boldTtf),
          ],
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
    final now = DateTime.now();
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(now);
    final weekdayStr = intl.DateFormat.EEEE('ar').format(now);

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
                      : "اسم الإدارة العامة للتعليم",
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                if (schoolName.isNotEmpty)
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
              ],
            ),
            // Center: Vision 2030 / ministry logo
            pw.Column(
              children: [
                if (logo != null)
                  pw.Container(width: 80, height: 80, child: pw.Image(logo))
                else
                  pw.SizedBox(width: 80, height: 80),
              ],
            ),
            // Left side: date / day / number
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "اليوم: $weekdayStr",
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  "التاريخ: $dateStr",
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  "الرقم: ____________",
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    String footerText,
    pw.Font font,
  ) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "تاريخ الطباعة: ${DateTime.now().toString().split(' ')[0]}",
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(footerText, style: pw.TextStyle(font: font, fontSize: 8)),
            pw.Text(
              "صفحة ${context.pageNumber} من ${context.pagesCount}",
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildReportTitle(
    String title,
    String subTitle,
    String? from,
    String? to,
    pw.Font boldFont,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 18,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        if (from != null && to != null)
          pw.Text(
            "الفترة من: $from إلى: $to",
            style: pw.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  static pw.Widget _buildTable(
    List<String> headers,
    List<List<String>> data,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(width: 0.5),
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      columnWidths: {
        0: const pw.FixedColumnWidth(30), // Serial Number
        // Add more specific widths if needed
      },
    );
  }

  static pw.Widget _buildSignatures(pw.Font font, pw.Font boldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Text(
              "وكيل الشؤون المدرسية",
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
        pw.Column(
          children: [
            pw.Text("الختم", style: pw.TextStyle(font: boldFont)),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                shape: pw.BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
