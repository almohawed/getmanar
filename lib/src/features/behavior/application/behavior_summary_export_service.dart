import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../reports/domain/ministry_pdf_template.dart';
import 'behavior_dashboard_service.dart';

class BehaviorSummaryExportService {
  ExcelColor _color(String hex) {
    final raw = hex.replaceAll('#', '').toUpperCase();
    final argb = raw.length == 6 ? 'FF$raw' : raw;
    return ExcelColor.fromHexString(argb);
  }

  Uint8List buildExcel({
    required String schoolName,
    required String adminRegion,
    required BehaviorDashboardStats stats,
    required DateTime snapshotDate,
  }) {
    final excel = Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final sheet = excel['تقرير السلوك'];
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(snapshotDate);

    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#1B5E20'),
      fontColorHex: _color('#FFFFFF'),
    );

    final titleStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 18,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#2E7D32'),
      fontColorHex: _color('#FFFFFF'),
    );

    final kpiLabelStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#E8F5E9'),
      fontColorHex: _color('#1B5E20'),
    );

    final kpiValueStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#FFFFFF'),
      fontColorHex: _color('#0D0D0D'),
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#424242'),
      fontColorHex: _color('#FFFFFF'),
    );

    final cellStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final levelColors = <String, String>{
      'ممتاز': '#C8E6C9',
      'جيد جداً': '#BBDEFB',
      'جيد': '#FFF9C4',
      'مقبول': '#FFE0B2',
      'ضعيف': '#FFCDD2',
    };

    final total = stats.totalStudents.clamp(0, 1 << 30);
    String pct(int count) =>
        total == 0 ? '0%' : '${((count / total) * 100).round()}%';

    final distribution = <Map<String, String>>[
      {
        'level': 'ممتاز',
        'range': '90 - 100',
        'count': '${stats.excellentCount}',
        'pct': pct(stats.excellentCount),
      },
      {
        'level': 'جيد جداً',
        'range': '80 - 89',
        'count': '${stats.veryGoodCount}',
        'pct': pct(stats.veryGoodCount),
      },
      {
        'level': 'جيد',
        'range': '70 - 79',
        'count': '${stats.goodCount}',
        'pct': pct(stats.goodCount),
      },
      {
        'level': 'مقبول',
        'range': '60 - 69',
        'count': '${stats.acceptableCount}',
        'pct': pct(stats.acceptableCount),
      },
      {
        'level': 'ضعيف',
        'range': 'أقل من 60',
        'count': '${stats.weakCount}',
        'pct': pct(stats.weakCount),
      },
    ];

    const columns = 8;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: 0),
    );
    final titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = TextCellValue('تقرير السلوك');
    titleCell.cellStyle = titleStyle;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: 1),
    );
    final sub = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    );
    sub.value = TextCellValue('$schoolName - $adminRegion - $dateStr');
    sub.cellStyle = headerStyle;

    final kpi = <List<String>>[
      ['عدد الطلاب', '${stats.totalStudents}'],
      ['المتوسط', stats.averageScore.toStringAsFixed(1)],
      ['أعلى', '${stats.highestScore}'],
      ['أدنى', '${stats.lowestScore}'],
    ];

    int row = 3;
    for (int i = 0; i < kpi.length; i++) {
      final baseCol = i * 2;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: baseCol + 1, rowIndex: row),
      );
      final labelCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: row),
      );
      labelCell.value = TextCellValue(kpi[i][0]);
      labelCell.cellStyle = kpiLabelStyle;

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: row + 1),
        CellIndex.indexByColumnRow(columnIndex: baseCol + 1, rowIndex: row + 1),
      );
      final valueCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: baseCol, rowIndex: row + 1),
      );
      valueCell.value = TextCellValue(kpi[i][1]);
      valueCell.cellStyle = kpiValueStyle;
    }

    row += 3;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: row),
    );
    final section = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    section.value = TextCellValue('الإحصائيات التفصيلية');
    section.cellStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: _color('#E3F2FD'),
      fontColorHex: _color('#0D47A1'),
    );

    row += 1;
    final headers = ['المستوى', 'النطاق', 'عدد الطلاب', 'النسبة'];
    for (int i = 0; i < headers.length; i++) {
      final c = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
      );
      c.value = TextCellValue(headers[i]);
      c.cellStyle = tableHeaderStyle;
    }

    for (int i = 0; i < distribution.length; i++) {
      final r = row + 1 + i;
      final item = distribution[i];
      final level = item['level']!;
      final bg = levelColors[level] ?? '#FFFFFF';
      final rowStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: _color(bg),
      );

      final values = [level, item['range']!, item['count']!, item['pct']!];
      for (int j = 0; j < values.length; j++) {
        final c = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: r),
        );
        c.value = TextCellValue(values[j]);
        c.cellStyle = rowStyle;
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  Future<Uint8List> buildPdf({
    required String schoolName,
    required String adminRegion,
    required BehaviorDashboardStats stats,
    required DateTime snapshotDate,
  }) async {
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(snapshotDate);
    final total = stats.totalStudents.clamp(0, 1 << 30);
    String pct(int count) =>
        total == 0 ? '0%' : '${((count / total) * 100).round()}%';

    PdfColor bg(int argb) => PdfColor.fromInt(argb);

    pw.Widget kpiCard({
      required String label,
      required String value,
      required PdfColor border,
      required PdfColor fill,
    }) {
      return pw.Container(
        width: 170,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: fill,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: border, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }

    PdfColor levelColor(String level) {
      switch (level) {
        case 'ممتاز':
          return PdfColors.green800;
        case 'جيد جداً':
          return PdfColors.blue800;
        case 'جيد':
          return PdfColors.amber800;
        case 'مقبول':
          return PdfColors.orange800;
        case 'ضعيف':
          return PdfColors.red800;
      }
      return PdfColors.grey700;
    }

    PdfColor levelBg(String level) {
      switch (level) {
        case 'ممتاز':
          return bg(0xFFE8F5E9);
        case 'جيد جداً':
          return bg(0xFFE3F2FD);
        case 'جيد':
          return bg(0xFFFFFDE7);
        case 'مقبول':
          return bg(0xFFFFF3E0);
        case 'ضعيف':
          return bg(0xFFFFEBEE);
      }
      return bg(0xFFF5F5F5);
    }

    final rows = <List<String>>[
      [
        'ممتاز',
        '100 - 90',
        '${stats.excellentCount}',
        pct(stats.excellentCount),
      ],
      [
        'جيد جداً',
        '89 - 80',
        '${stats.veryGoodCount}',
        pct(stats.veryGoodCount),
      ],
      ['جيد', '79 - 70', '${stats.goodCount}', pct(stats.goodCount)],
      [
        'مقبول',
        '69 - 60',
        '${stats.acceptableCount}',
        pct(stats.acceptableCount),
      ],
      ['ضعيف', 'أقل من 60', '${stats.weakCount}', pct(stats.weakCount)],
    ];

    final pdf = await MinistryPdfTemplate.generateReport(
      title: 'تقرير السلوك',
      subTitle: 'ملخص سلوكي على مستوى المدرسة',
      schoolName: schoolName,
      adminRegion: adminRegion,
      dateFrom: dateStr,
      dateTo: dateStr,
      tableHeaders: const ['—'],
      tableData: const [],
      contentWidgets: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            kpiCard(
              label: 'عدد الطلاب',
              value: '${stats.totalStudents}',
              border: PdfColors.green800,
              fill: bg(0xFFE8F5E9),
            ),
            kpiCard(
              label: 'المتوسط العام',
              value: stats.averageScore.toStringAsFixed(1),
              border: PdfColors.blue800,
              fill: bg(0xFFE3F2FD),
            ),
            kpiCard(
              label: 'أعلى / أدنى',
              value: '${stats.highestScore} / ${stats.lowestScore}',
              border: PdfColors.orange800,
              fill: bg(0xFFFFF3E0),
            ),
            kpiCard(
              label: 'بحاجة دعم',
              value: '${stats.weakCount}',
              border: PdfColors.red800,
              fill: bg(0xFFFFEBEE),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'الإحصائيات التفصيلية',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1.0),
            2: const pw.FlexColumnWidth(0.8),
            3: const pw.FlexColumnWidth(0.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey700),
              children: [
                for (final h in const [
                  'المستوى',
                  'النطاق',
                  'عدد الطلاب',
                  'النسبة',
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            ),
            for (final r in rows)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: levelBg(r[0])),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      r[0],
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: levelColor(r[0]),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r[1], textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r[2], textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r[3], textAlign: pw.TextAlign.center),
                  ),
                ],
              ),
          ],
        ),
        if (stats.topRecommendations.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: bg(0xFFE3F2FD),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'توصيات ذكية',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...stats.topRecommendations
                    .take(4)
                    .map(
                      (t) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• '),
                            pw.Expanded(
                              child: pw.Text(
                                t,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
      footerText: 'نظام منار - شؤون الطلاب',
      pageFormat: PdfPageFormat.a4.landscape,
      includeSignatures: true,
    );
    return pdf.save();
  }
}
