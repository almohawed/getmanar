import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import 'students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:html' as html;
import '../providers/academic_providers.dart';
import '../domain/performance_stats.dart';

class SuccessRatesReportScreen extends ConsumerStatefulWidget {
  const SuccessRatesReportScreen({super.key});

  @override
  ConsumerState<SuccessRatesReportScreen> createState() => _SuccessRatesReportScreenState();
}

class _SuccessRatesReportScreenState extends ConsumerState<SuccessRatesReportScreen> {
  
  Future<void> _generatePDF(BuildContext context, PerformanceStats stats) async {
    try {
      final pdf = pw.Document();
      
      // تحميل الخطوط العربية (Regular و Bold)
      final fontDataRegular = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final fontDataBold = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      final arabicFontRegular = pw.Font.ttf(fontDataRegular);
      final arabicFontBold = pw.Font.ttf(fontDataBold);
      
      // تحميل الشعار
      final logoData = await rootBundle.load('assets/logokshuf.webp');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      
      // الحصول على معلومات المدرسة من المستخدم
      final user = ref.read(authStateProvider).value;
      final schoolName = 'مدرسة النموذجية'; // يمكن استبداله بـ user?.schoolName
      final region = 'الرياض'; // يمكن استبداله بـ user?.region
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: arabicFontRegular,
            bold: arabicFontBold,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 🎯 الكليشة الرسمية
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    children: [
                      // السطر الأول
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // اليسار - معلومات المدرسة
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  '          المملكة العربية السعودية',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  '                وزارة التعليم',
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  '    الإدارة العامة للتعليم بمنطقة $region',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  '            مدرسة $schoolName',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          
                          // الوسط - الشعار
                          pw.Expanded(
                            flex: 2,
                            child: pw.Center(
                              child: pw.Container(
                                width: 100,
                                height: 100,
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ),
                          
                          // اليمين - الرقم والتاريخ
                          pw.Expanded(
                            flex: 2,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.end,
                                  children: [
                                    pw.Text('الرقم: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                                    pw.Container(
                                      width: 120,
                                      decoration: const pw.BoxDecoration(
                                        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                                      ),
                                      child: pw.SizedBox(height: 15),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 10),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.end,
                                  children: [
                                    pw.Text('التاريخ: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                                    pw.Container(
                                      width: 120,
                                      decoration: const pw.BoxDecoration(
                                        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                                      ),
                                      child: pw.SizedBox(height: 15),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      pw.SizedBox(height: 15),
                      
                      // الخط الفاصل
                      pw.Container(
                        width: double.infinity,
                        height: 2,
                        color: PdfColors.black,
                      ),
                      
                      pw.SizedBox(height: 15),
                      
                      // عنوان التقرير
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue700,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'كشف توزيع نسب النجاح',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      pw.SizedBox(height: 10),
                      
                      // معلومات التقرير
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'تاريخ التقرير: ${DateTime.now().toString().split(' ')[0]}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            'العام الدراسي: 1447 هـ',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      
                      pw.SizedBox(height: 5),
                      
                      // الخط الفاصل السفلي
                      pw.Container(
                        width: double.infinity,
                        height: 3,
                        color: PdfColors.black,
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 25),
                
                // 📊 الإحصائيات الرئيسية
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الإحصائيات الرئيسية',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildPdfStatBox('نسبة التحسن', '+${stats.improvementRate.toStringAsFixed(0)}%', PdfColors.teal700),
                          _buildPdfStatBox('نسبة التميز', '${stats.excellenceRate.toStringAsFixed(0)}%', PdfColors.amber700),
                          _buildPdfStatBox('نسبة النجاح', '${stats.overallSuccessRate.toStringAsFixed(0)}%', PdfColors.green700),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // 📋 توزيع المستويات
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'توزيع مستويات الأداء',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                            children: [
                              _buildPdfTableCell('المستوى', isHeader: true, align: pw.TextAlign.right),
                              _buildPdfTableCell('النسبة', isHeader: true, align: pw.TextAlign.center),
                            ],
                          ),
                          pw.TableRow(children: [
                            _buildPdfTableCell('ممتاز', align: pw.TextAlign.right),
                            _buildPdfTableCell('${stats.performanceLevels['excellent']?.toStringAsFixed(0) ?? '0'}%', align: pw.TextAlign.center),
                          ]),
                          pw.TableRow(children: [
                            _buildPdfTableCell('جيد جداً', align: pw.TextAlign.right),
                            _buildPdfTableCell('${stats.performanceLevels['veryGood']?.toStringAsFixed(0) ?? '0'}%', align: pw.TextAlign.center),
                          ]),
                          pw.TableRow(children: [
                            _buildPdfTableCell('جيد', align: pw.TextAlign.right),
                            _buildPdfTableCell('${stats.performanceLevels['good']?.toStringAsFixed(0) ?? '0'}%', align: pw.TextAlign.center),
                          ]),
                          pw.TableRow(children: [
                            _buildPdfTableCell('مقبول', align: pw.TextAlign.right),
                            _buildPdfTableCell('${stats.performanceLevels['acceptable']?.toStringAsFixed(0) ?? '0'}%', align: pw.TextAlign.center),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // 💡 التوصيات
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'التوصيات',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _buildBulletPoint('نسبة النجاح ${stats.overallSuccessRate.toStringAsFixed(1)}% ${stats.overallSuccessRate >= 80 ? 'ممتازة وتفوق المعدل الوطني' : 'تحتاج تحسين'}'),
                      _buildBulletPoint('${stats.excellenceRate.toStringAsFixed(0)}% من الطلاب حققوا مستوى الامتياز'),
                      _buildBulletPoint('التحسن بنسبة ${stats.improvementRate.toStringAsFixed(0)}% مقارنة بالفصل السابق'),
                      _buildBulletPoint('إجمالي الطلاب: ${stats.totalStudents} طالب، الناجحون: ${stats.successfulStudents}'),
                    ],
                  ),
                ),
                
                pw.Spacer(),
                
                // 📝 التذييل
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'تم إنشاء هذا التقرير آلياً - نظام منار',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'التوقيع: _______________',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    
      // حفظ وعرض معاينة PDF
      final bytes = await pdf.save();
      
      if (kIsWeb) {
        // للويب: فتح في نافذة جديدة للمعاينة والطباعة
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        html.Url.revokeObjectUrl(url);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم فتح معاينة التقرير'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // للموبايل: استخدام Printing
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'تقرير_نسب_النجاح_${DateTime.now().toString().split(' ')[0]}.pdf',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في إنشاء التقرير: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, right: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 13 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final performanceStatsAsync = ref.watch(performanceStatsProvider);
    
    return performanceStatsAsync.when(
      data: (stats) => _buildContent(context, stats),
      loading: () => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير نسب النجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.blue.shade700,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير نسب النجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.blue.shade700,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              SizedBox(height: 16),
              Text('حدث خطأ في تحميل البيانات', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              SizedBox(height: 8),
              Text('$error', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context, PerformanceStats stats) {
    final successRate = stats.overallSuccessRate.round();
    final excellenceRate = stats.excellenceRate.round();
    final improvementRate = stats.improvementRate.round();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('تقرير نسب النجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _generatePDF(context, stats),
            tooltip: 'تحميل PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 بطاقة الإحصائيات الرئيسية
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.percent, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'نسب النجاح الإجمالية',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('نسبة النجاح', '$successRate%', Icons.check_circle, Colors.green),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem('نسبة التميز', '$excellenceRate%', Icons.star, Colors.amber),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem('نسبة التحسن', '+$improvementRate%', Icons.trending_up, Colors.lightGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📈 رسم بياني دائري
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, color: Colors.blue.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'توزيع مستويات الأداء',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 250.h,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  value: stats.performanceLevels['excellent'] ?? 0,
                                  title: 'ممتاز',
                                  color: Colors.green.shade600,
                                  radius: 60,
                                  titleStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.performanceLevels['veryGood'] ?? 0,
                                  title: 'جيد جداً',
                                  color: Colors.blue.shade600,
                                  radius: 60,
                                  titleStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.performanceLevels['good'] ?? 0,
                                  title: 'جيد',
                                  color: Colors.orange.shade600,
                                  radius: 60,
                                  titleStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.performanceLevels['acceptable'] ?? 0,
                                  title: 'مقبول',
                                  color: Colors.red.shade600,
                                  radius: 60,
                                  titleStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 20.w),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem('ممتاز', '${stats.performanceLevels['excellent']?.toStringAsFixed(0) ?? '0'}%', Colors.green.shade600),
                              _buildLegendItem('جيد جداً', '${stats.performanceLevels['veryGood']?.toStringAsFixed(0) ?? '0'}%', Colors.blue.shade600),
                              _buildLegendItem('جيد', '${stats.performanceLevels['good']?.toStringAsFixed(0) ?? '0'}%', Colors.orange.shade600),
                              _buildLegendItem('مقبول', '${stats.performanceLevels['acceptable']?.toStringAsFixed(0) ?? '0'}%', Colors.red.shade600),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 💡 بطاقة التوصيات الذكية
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تحليل ذكي للنتائج',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildRecommendation('نسبة النجاح ${stats.overallSuccessRate.toStringAsFixed(1)}% ${stats.overallSuccessRate >= 80 ? 'ممتازة وتفوق المعدل الوطني' : 'تحتاج تحسين'}'),
                  _buildRecommendation('${stats.excellenceRate.toStringAsFixed(0)}% من الطلاب حققوا مستوى الامتياز ${stats.excellenceRate >= 40 ? '- نتيجة رائعة' : '- يمكن تحسينها'}'),
                  _buildRecommendation('التحسن بنسبة ${stats.improvementRate.toStringAsFixed(0)}% مقارنة بالفصل السابق'),
                  _buildRecommendation('إجمالي الطلاب: ${stats.totalStudents} طالب، الناجحون: ${stats.successfulStudents} طالب'),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📋 تفاصيل حسب الفصول
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.class_, color: Colors.blue.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'نسب النجاح حسب الفصول',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  if (stats.successRatesByClass.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Text(
                          'لا توجد فصول متاحة',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stats.successRatesByClass.length,
                      itemBuilder: (context, index) {
                        final className = stats.successRatesByClass.keys.elementAt(index);
                        final classSuccessRate = stats.successRatesByClass[className]!.round();
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10.w),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Icon(
                                          Icons.class_,
                                          color: Colors.blue.shade700,
                                          size: 24.sp,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              className,
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'نسبة النجاح: $classSuccessRate%',
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: classSuccessRate >= 85 
                                              ? Colors.green.shade100 
                                              : classSuccessRate >= 70 
                                                  ? Colors.blue.shade100 
                                                  : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Text(
                                          '$classSuccessRate%',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                            color: classSuccessRate >= 85 
                                                ? Colors.green.shade700 
                                                : classSuccessRate >= 70 
                                                    ? Colors.blue.shade700 
                                                    : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  LinearProgressIndicator(
                                    value: classSuccessRate / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      classSuccessRate >= 85 
                                          ? Colors.green 
                                          : classSuccessRate >= 70 
                                              ? Colors.blue 
                                              : Colors.orange,
                                    ),
                                    minHeight: 8.h,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 16.w,
            height: 16.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendation(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.blue.shade700, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
