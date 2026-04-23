import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProgressReportPdfService {
  static Future<Uint8List> generateProgressReport({
    required Map<String, dynamic> stats,
    required String schoolName,
    required String counselorName,
    required String reportPeriod,
  }) async {
    final pdf = pw.Document();

    // تحميل الخط العربي
    final arabicFont = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(arabicFont);

    // إنشاء الصفحة الأولى
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),
        header: (context) => _buildHeader(ttf, schoolName),
        footer: (context) => _buildFooter(ttf, context),
        build: (context) => [
          _buildTitle(ttf),
          pw.SizedBox(height: 20),
          _buildReportInfo(ttf, counselorName, reportPeriod),
          pw.SizedBox(height: 30),
          _buildExecutiveSummary(ttf, stats),
          pw.SizedBox(height: 30),
          _buildStatisticsSection(ttf, stats),
          pw.SizedBox(height: 30),
          _buildPerformanceIndicators(ttf, stats),
          pw.SizedBox(height: 30),
          _buildRecommendations(ttf, stats),
          pw.SizedBox(height: 30),
          _buildConclusion(ttf),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.Font font, String schoolName) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.purple700, PdfColors.purple500],
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'المملكة العربية السعودية',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 14,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'وزارة التعليم',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: PdfColors.white.shade(0.7),
                ),
              ),
              pw.Text(
                schoolName,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: PdfColors.white.shade(0.7),
                ),
              ),
            ],
          ),
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(30),
            ),
            child: pw.Center(
              child: pw.Text(
                'شعار\nالمدرسة',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.purple700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Font font, pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تقرير تقييم التقدم - نظام إتساق التعليمي',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'صفحة ${context.pageNumber}',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTitle(pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.indigo100, PdfColors.purple100],
        ),
        borderRadius: pw.BorderRadius.circular(15),
        border: pw.Border.all(color: PdfColors.purple300, width: 2),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'تقرير تقييم التقدم الشامل',
            style: pw.TextStyle(
              font: font,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple800,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'تحليل شامل لأداء الطلاب والخطط التعليمية',
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              color: PdfColors.purple600,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportInfo(pw.Font font, String counselorName, String reportPeriod) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'معد التقرير: $counselorName',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'المسمى الوظيفي: مرشد طلابي',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'تاريخ التقرير: ${DateFormat('yyyy/MM/dd', 'ar').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'فترة التقرير: $reportPeriod',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(pw.Font font, Map<String, dynamic> stats) {
    final progressRate = (stats['progressRate'] ?? 0.0).toStringAsFixed(1);
    final activePlans = stats['activePlans'] ?? 0;
    final successRate = (stats['successRate'] ?? 0.0).toStringAsFixed(1);

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(15),
        border: pw.Border.all(color: PdfColors.blue200, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 30,
                height: 30,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue600,
                  borderRadius: pw.BorderRadius.circular(15),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '📊',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                ),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                'الملخص التنفيذي',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            'يُظهر التحليل الشامل لأداء الطلاب خلال الفترة المحددة النتائج التالية:',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Bullet(
            text: 'معدل التقدم العام: $progressRate% مما يعكس مستوى ${_getProgressLevel(double.parse(progressRate))}',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.Bullet(
            text: 'عدد الخطط النشطة: $activePlans خطة تعليمية وإرشادية',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.Bullet(
            text: 'معدل النجاح: $successRate% من الخطط حققت أهدافها المرجوة',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.Bullet(
            text: 'التوصية العامة: ${_getGeneralRecommendation(double.parse(progressRate))}',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatisticsSection(pw.Font font, Map<String, dynamic> stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.green600, PdfColors.green400],
            ),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                '📈',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                'الإحصائيات التفصيلية',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: [
            _buildTableHeader(font),
            _buildTableRow(font, 'معدل التقدم العام', '${(stats['progressRate'] ?? 0.0).toStringAsFixed(1)}%', PdfColors.blue),
            _buildTableRow(font, 'عدد الخطط النشطة', '${stats['activePlans'] ?? 0}', PdfColors.green),
            _buildTableRow(font, 'معدل النجاح', '${(stats['successRate'] ?? 0.0).toStringAsFixed(1)}%', PdfColors.orange),
            _buildTableRow(font, 'الجلسات المكتملة', '${stats['completedSessions'] ?? 0}', PdfColors.purple),
            _buildTableRow(font, 'إجمالي المتابعات', '${stats['totalFollowups'] ?? 0}', PdfColors.teal),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _buildTableHeader(pw.Font font) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            'المؤشر',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            'القيمة',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            'التقييم',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  static pw.TableRow _buildTableRow(pw.Font font, String indicator, String value, PdfColor color) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            indicator,
            style: pw.TextStyle(font: font, fontSize: 11),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: color.shade(0.1),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              _getEvaluation(indicator, value),
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPerformanceIndicators(pw.Font font, Map<String, dynamic> stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.orange600, PdfColors.orange400],
            ),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                '🎯',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                'مؤشرات الأداء الرئيسية',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        _buildIndicatorBar(font, 'التحسن الأكاديمي', stats['academicImprovement'] ?? 0.0, PdfColors.green),
        pw.SizedBox(height: 10),
        _buildIndicatorBar(font, 'الالتزام بالجلسات', stats['sessionCommitment'] ?? 0.0, PdfColors.blue),
        pw.SizedBox(height: 10),
        _buildIndicatorBar(font, 'التفاعل الإيجابي', stats['positiveInteraction'] ?? 0.0, PdfColors.orange),
        pw.SizedBox(height: 10),
        _buildIndicatorBar(font, 'تحقيق الأهداف', stats['goalAchievement'] ?? 0.0, PdfColors.purple),
      ],
    );
  }

  static pw.Widget _buildIndicatorBar(pw.Font font, String title, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${(value * 100).toInt()}%',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            height: 8,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Container(
              width: value * 200, // Progress bar width
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRecommendations(pw.Font font, Map<String, dynamic> stats) {
    final progressRate = stats['progressRate'] ?? 0.0;
    final recommendations = _getDetailedRecommendations(progressRate);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.amber600, PdfColors.amber400],
            ),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                '💡',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                'التوصيات والمقترحات',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        ...recommendations.map((rec) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.amber200),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 20,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber600,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${recommendations.indexOf(rec) + 1}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Text(
                  rec,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  static pw.Widget _buildConclusion(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.teal100, PdfColors.teal50],
        ),
        borderRadius: pw.BorderRadius.circular(15),
        border: pw.Border.all(color: PdfColors.teal300, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '📝',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                'الخاتمة والتوقيع',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            'تم إعداد هذا التقرير بناءً على البيانات المتوفرة في نظام إتساق التعليمي، ويعكس الوضع الحالي لأداء الطلاب والخطط التعليمية. نوصي بمراجعة هذا التقرير دورياً لضمان تحقيق أفضل النتائج التعليمية.',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'التوقيع: ___________________',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'المرشد الطلابي',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'التاريخ: ${DateFormat('yyyy/MM/dd', 'ar').format(DateTime.now())}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'الختم الرسمي: ___________',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  static String _getProgressLevel(double progress) {
    if (progress >= 90) return 'ممتاز';
    if (progress >= 80) return 'جيد جداً';
    if (progress >= 70) return 'جيد';
    if (progress >= 60) return 'مقبول';
    return 'يحتاج تحسين';
  }

  static String _getGeneralRecommendation(double progress) {
    if (progress >= 80) return 'الاستمرار في النهج الحالي مع التطوير المستمر';
    if (progress >= 60) return 'تعزيز الجهود وزيادة المتابعة';
    return 'مراجعة شاملة للاستراتيجيات وتكثيف الجهود';
  }

  static String _getEvaluation(String indicator, String value) {
    final numValue = double.tryParse(value.replaceAll('%', '')) ?? 0;
    if (numValue >= 80) return 'ممتاز';
    if (numValue >= 70) return 'جيد';
    if (numValue >= 60) return 'مقبول';
    return 'يحتاج تحسين';
  }

  static List<String> _getDetailedRecommendations(double progressRate) {
    if (progressRate >= 80) {
      return [
        'الاستمرار في تطبيق الاستراتيجيات الحالية الناجحة',
        'تطوير برامج إثرائية للطلاب المتميزين',
        'مشاركة أفضل الممارسات مع المدارس الأخرى',
        'تقييم دوري للحفاظ على مستوى الأداء العالي',
      ];
    } else if (progressRate >= 60) {
      return [
        'زيادة عدد الجلسات الإرشادية للطلاب المحتاجين',
        'تفعيل برامج التعزيز الإيجابي',
        'تحسين التواصل مع أولياء الأمور',
        'مراجعة وتطوير الخطط التعليمية الحالية',
      ];
    } else {
      return [
        'إجراء تقييم شامل لجميع الخطط والبرامج',
        'زيادة عدد المرشدين أو ساعات الإرشاد',
        'تطوير برامج تدخل مكثفة للطلاب المتعثرين',
        'التعاون مع الأخصائيين النفسيين والاجتماعيين',
        'إشراك الأسر بشكل أكبر في العملية التعليمية',
      ];
    }
  }
}