import 'dart:typed_data';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../presentation/providers/attendance_stats_providers.dart';

class ExecutiveReportService {
  Future<Uint8List> generateReport({
    required FrequentAbsenceAnalysis absenceAnalysis,
    required TardinessAnalysisModel tardinessAnalysis,
    required NotificationStatsAnalysis notificationAnalysis,
    required String schoolName,
  }) async {
    final pdf = pw.Document();

    // Load Arabic Font (assuming it's available, otherwise fallback to standard)
    // Note: For real production, we need a .ttf file in assets.
    // I will use a standard font or try to load one if possible.
    // Since I cannot guarantee assets, I will assume a standard font that supports Arabic
    // or use a theme that might be available.
    // However, 'pdf' package default font doesn't support Arabic well without a custom font.
    // I'll try to use a Google Font if 'printing' package supports it easily,
    // or just assume the system handles it.
    // BETTER APPROACH: Use `PdfGoogleFonts` from `printing` package.
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final dateStr = intl.DateFormat('yyyy-MM-dd', 'en').format(DateTime.now());

    // Generate Smart Summary Text
    final summaryText = _generateSmartSummary(
      absenceAnalysis,
      tardinessAnalysis,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'تقرير الانضباط التنفيذي',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      dateStr,
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                    ),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // Executive Summary Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الملخص التنفيذي',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        summaryText,
                        style: pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                        textAlign: pw.TextAlign.justify,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Key Indicators Grid
                pw.Text(
                  'مؤشرات الأداء الرئيسية',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildKpiCard(
                      'معدل الغياب',
                      '${absenceAnalysis.absenceTrend.toStringAsFixed(1)}%',
                      absenceAnalysis.absenceTrend < 0
                          ? PdfColors.green
                          : PdfColors.red,
                    ),
                    _buildKpiCard(
                      'اتجاه التأخر',
                      '${tardinessAnalysis.tardinessTrend.toStringAsFixed(1)}%',
                      tardinessAnalysis.tardinessTrend < 0
                          ? PdfColors.green
                          : PdfColors.red,
                    ),
                    _buildKpiCard(
                      'التفاعل الأسري',
                      '${notificationAnalysis.interactionRate.toStringAsFixed(1)}%',
                      PdfColors.blue,
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Critical Insights
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'أبرز المخاطر (تأخر)',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          _buildInfoRow(
                            'اليوم الأكثر تكراراً',
                            tardinessAnalysis.mostFrequentDay,
                          ),
                          _buildInfoRow(
                            'الفصل الأكثر تأخراً',
                            tardinessAnalysis.mostCriticalClass,
                          ),
                          _buildInfoRow(
                            'نسبة التأخر الصباحي',
                            '${((tardinessAnalysis.morningTardinessCount / (tardinessAnalysis.morningTardinessCount + tardinessAnalysis.betweenClassesTardinessCount + 0.1)) * 100).toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'كفاءة المعالجة',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          _buildInfoRow(
                            'حالات عولجت هذا الأسبوع',
                            '${absenceAnalysis.closedCasesThisWeekCount}',
                          ),
                          _buildInfoRow(
                            'متوسط سرعة الاستجابة',
                            '${notificationAnalysis.averageResponseTimeMinutes} دقيقة',
                          ),
                          _buildInfoRow(
                            'تحسن بعد التنبيه',
                            '${notificationAnalysis.improvedCasesCount} طالب',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'تم إنشاء هذا التقرير تلقائياً عبر نظام إدارة المدرسة الذكي',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildKpiCard(
    String title,
    String value,
    PdfColor color, {
    String? subtitle,
  }) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 5),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey200),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _generateSmartSummary(
    FrequentAbsenceAnalysis abs,
    TardinessAnalysisModel tard,
  ) {
    final absTrend = abs.absenceTrend;
    final tardTrend = tard.tardinessTrend;

    String summary = 'تشير البيانات الحالية إلى ';

    // Overall Sentiment
    if (absTrend < 0 && tardTrend < 0) {
      summary += 'تحسن ملحوظ في الانضباط العام، ';
    } else if (absTrend > 0 || tardTrend > 0) {
      summary += 'تحديات في ضبط الانتظام خلال الفترة الحالية، ';
    } else {
      summary += 'استقرار نسبي في معدلات الحضور، ';
    }

    // Specifics - Absence
    if (absTrend > 0) {
      summary +=
          'حيث ارتفع معدل الغياب بنسبة ${absTrend.toStringAsFixed(1)}% مقارنة بالفترة السابقة. ';
    } else {
      summary +=
          'مع انخفاض معدل الغياب بنسبة ${absTrend.abs().toStringAsFixed(1)}%. ';
    }

    // Specifics - Tardiness & Class
    if (tard.mostFrequentDay != '-') {
      summary +=
          'ويتركز التأخر بشكل واضح في يوم ${tard.mostFrequentDay} (${tard.mostFrequentDayPercentage.toStringAsFixed(0)}% من الحالات)';
      if (tard.mostCriticalClass != '-') {
        summary +=
            '، ويظهر فصل "${tard.mostCriticalClass}" كأكثر الفصول تحدياً. ';
      } else {
        summary += '. ';
      }
    }

    // Recommendation
    summary += 'بناءً على ذلك، يوصى ';
    if (tardTrend > 0) {
      summary += 'بتفعيل خطة انضباط صباحي موجهة ومراجعة إجراءات الدخول، ';
    } else {
      summary += 'بالاستمرار في التحفيز الإيجابي، ';
    }

    if (tard.mostCriticalClass != '-') {
      summary +=
          'مع التركيز بشكل خاص على متابعة طلاب فصل ${tard.mostCriticalClass}.';
    } else {
      summary += 'وتعزيز التواصل مع أولياء الأمور.';
    }

    return summary;
  }
}
