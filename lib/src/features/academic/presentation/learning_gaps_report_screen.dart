import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:html' as html;
import '../providers/academic_providers.dart';
import '../domain/performance_stats.dart';

class LearningGapsReportScreen extends ConsumerStatefulWidget {
  const LearningGapsReportScreen({super.key});

  @override
  ConsumerState<LearningGapsReportScreen> createState() => _LearningGapsReportScreenState();
}

class _LearningGapsReportScreenState extends ConsumerState<LearningGapsReportScreen> {
  
  Future<void> _generatePDF(BuildContext context, GapStats gapStats) async {
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
      final schoolName = 'مدرسة النموذجية';
      final region = 'الرياض';
      
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
                        color: PdfColors.orange700,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'تقرير الفجوات التعليمية',
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
              
              // الإحصائيات الرئيسية
              pw.Text(
                'إحصائيات الفجوات',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatBox('فجوات مكتشفة', '${gapStats.totalGaps}', PdfColors.amber),
                  _buildPdfStatBox('حرجة', '${gapStats.criticalGaps}', PdfColors.red),
                  _buildPdfStatBox('تم معالجتها', '${gapStats.resolvedGaps}', PdfColors.green),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // الفجوات المكتشفة
              pw.Text(
                'الفجوات المكتشفة',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                    children: [
                      _buildPdfTableCell('المادة والصف', isHeader: true),
                      _buildPdfTableCell('الوصف', isHeader: true),
                      _buildPdfTableCell('الطلاب', isHeader: true),
                      _buildPdfTableCell('الأولوية', isHeader: true),
                    ],
                  ),
                  ...gapStats.gaps.take(10).map((gap) => pw.TableRow(children: [
                    _buildPdfTableCell('${gap.subject} - ${gap.className}'),
                    _buildPdfTableCell(gap.description),
                    _buildPdfTableCell('${gap.affectedStudents}'),
                    _buildPdfTableCell(gap.priority),
                  ])).toList(),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // خطة المعالجة
              pw.Text(
                'خطة المعالجة المقترحة',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Bullet(text: '1. تقييم شامل: إجراء اختبارات تشخيصية لتحديد مستوى كل طالب'),
              pw.Bullet(text: '2. تصنيف الطلاب: تقسيم الطلاب إلى مجموعات حسب مستوى الفجوة'),
              pw.Bullet(text: '3. خطط علاجية: إنشاء خطط علاجية مخصصة لكل مجموعة'),
              pw.Bullet(text: '4. التنفيذ والمتابعة: تنفيذ الخطط مع متابعة دورية كل أسبوعين'),
              pw.Bullet(text: '5. التقييم النهائي: قياس التحسن وتوثيق النتائج'),
              
              pw.Spacer(),
              
              // التذييل
              pw.Divider(),
              pw.Text(
                'تم إنشاء هذا التقرير آلياً بواسطة نظام منار',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
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
          name: 'تقرير_الفجوات_التعليمية_${DateTime.now().toString().split(' ')[0]}.pdf',
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
  
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 14 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final gapStatsAsync = ref.watch(gapStatsProvider);
    
    return gapStatsAsync.when(
      data: (gapStats) => _buildContent(context, gapStats),
      loading: () => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير الفجوات التعليمية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.orange.shade700,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير الفجوات التعليمية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.orange.shade700,
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
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context, GapStats gapStats) {
    final gapsCount = gapStats.totalGaps;
    final criticalGaps = gapStats.criticalGaps;
    final resolvedGaps = gapStats.resolvedGaps;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('تقرير الفجوات التعليمية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _generatePDF(context, gapStats),
            tooltip: 'تحميل PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 بطاقة الإحصائيات
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
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
                        child: Icon(Icons.compare_arrows, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'إحصائيات الفجوات',
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
                        child: _buildStatItem('فجوات مكتشفة', '$gapsCount', Icons.warning, Colors.amber),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem('حرجة', '$criticalGaps', Icons.error, Colors.red),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem('تم معالجتها', '$resolvedGaps', Icons.check_circle, Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 💡 بطاقة التوصيات الذكية
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.orange.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تحليل ذكي للفجوات',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (gapStats.gaps.isNotEmpty) ...[
                    _buildRecommendation('الفجوة الأكبر: ${gapStats.gaps.first.subject} - ${gapStats.gaps.first.className} (${gapStats.gaps.first.affectedStudents} طالب متأثر)'),
                    _buildRecommendation('التوصية: ${gapStats.gaps.first.priority == 'حرجة' ? 'إنشاء خطة علاجية فورية' : 'متابعة دورية'}'),
                    if (gapStats.gaps.length > 1)
                      _buildRecommendation('الفجوة الثانية: ${gapStats.gaps[1].subject} - ${gapStats.gaps[1].className} (${gapStats.gaps[1].affectedStudents} طلاب)'),
                    _buildRecommendation('الإجراء المقترح: حصص تقوية مكثفة لمدة 4 أسابيع'),
                  ] else
                    _buildRecommendation('لا توجد فجوات تعليمية مكتشفة حالياً - أداء ممتاز!'),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📋 قائمة الفجوات التعليمية
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
                      Icon(Icons.list_alt, color: Colors.orange.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'الفجوات المكتشفة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  if (gapStats.gaps.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.h),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle, size: 64.sp, color: Colors.green.shade300),
                            SizedBox(height: 16.h),
                            Text(
                              'لا توجد فجوات تعليمية مكتشفة',
                              style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...gapStats.gaps.map((gap) {
                      final severityColor = gap.priority == 'حرجة' 
                          ? Colors.red 
                          : gap.priority == 'متوسطة' 
                              ? Colors.orange 
                              : Colors.amber;
                      final icon = gap.subject.contains('رياضيات') 
                          ? Icons.calculate 
                          : gap.subject.contains('إنجليزية') 
                              ? Icons.language 
                              : gap.subject.contains('علوم') 
                                  ? Icons.science 
                                  : Icons.text_fields;
                      
                      return _buildGapCard(
                        '${gap.subject} - ${gap.className}',
                        gap.description,
                        gap.affectedStudents,
                        gap.priority,
                        severityColor,
                        icon,
                      );
                    }).toList(),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // 📈 خطة المعالجة المقترحة
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
                      Icon(Icons.medical_services, color: Colors.green.shade700, size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'خطة المعالجة المقترحة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  _buildActionStep(
                    '1',
                    'تقييم شامل',
                    'إجراء اختبارات تشخيصية لتحديد مستوى كل طالب',
                    Colors.blue,
                  ),
                  _buildActionStep(
                    '2',
                    'تصنيف الطلاب',
                    'تقسيم الطلاب إلى مجموعات حسب مستوى الفجوة',
                    Colors.purple,
                  ),
                  _buildActionStep(
                    '3',
                    'خطط علاجية',
                    'إنشاء خطط علاجية مخصصة لكل مجموعة',
                    Colors.teal,
                  ),
                  _buildActionStep(
                    '4',
                    'التنفيذ والمتابعة',
                    'تنفيذ الخطط مع متابعة دورية كل أسبوعين',
                    Colors.orange,
                  ),
                  _buildActionStep(
                    '5',
                    'التقييم النهائي',
                    'قياس التحسن وتوثيق النتائج',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGapCard(
    String title,
    String description,
    int affectedStudents,
    String severity,
    Color severityColor,
    IconData icon,
  ) {
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
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    icon,
                    color: severityColor,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        description,
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
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.people, size: 16.sp, color: Colors.grey.shade600),
                SizedBox(width: 4.w),
                Text(
                  '$affectedStudents طالب متأثر',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionStep(
    String number,
    String title,
    String description,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  
  Widget _buildRecommendation(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.orange.shade700, size: 18.sp),
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
