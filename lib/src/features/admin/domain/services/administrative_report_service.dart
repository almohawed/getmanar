import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

class AdministrativeReportService {
  Future<void> generateAndOpenReport({
    required String schoolName,
    required String managerName,
    required int totalTransactions,
    required double avgProcessingTime,
    required double completionRate,
    required List<String> keyChallenges,
  }) async {
    final pdf = pw.Document();

    // Load Arabic Font
    final fontData = await PdfGoogleFonts.cairoRegular();
    final fontBoldData = await PdfGoogleFonts.cairoBold();
    
    final theme = pw.ThemeData.withFont(
      base: fontData,
      bold: fontBoldData,
    );

    pdf.addPage(
      pw.Page(
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('التقرير الإداري التنفيذي', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(intl.DateFormat('yyyy-MM-dd').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Executive Summary
              pw.Text('ملخص الأداء الإداري', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('إجمالي المعاملات', '$totalTransactions'),
                    _buildMetric('متوسط زمن المعالجة', '${avgProcessingTime.toStringAsFixed(1)} ساعة'),
                    _buildMetric('نسبة الإنجاز', '${completionRate.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Key Challenges
              pw.Text('أبرز التحديات الحالية', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              pw.SizedBox(height: 10),
              ...keyChallenges.map((challenge) => pw.Bullet(text: challenge, style: pw.TextStyle(fontSize: 14))),

              pw.SizedBox(height: 50),
              
              // Footer
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('مدير المدرسة: $managerName'),
                  pw.Text('تاريخ الطباعة: ${intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Administrative_Report_${DateTime.now().toIso8601String()}.pdf',
    );
  }

  pw.Widget _buildMetric(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
      ],
    );
  }
}
