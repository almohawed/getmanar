import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/domain/models/user.dart';
import '../domain/classroom.dart';
import 'students_provider.dart';
import '../../admin/data/mock_teacher_repository.dart' as mockTeachers;
import '../../admin/data/mock_class_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../providers/academic_providers.dart';
import '../domain/performance_stats.dart';

class TeacherPerformanceReportTab extends ConsumerWidget {
  const TeacherPerformanceReportTab({super.key});
  
  // دالة لتنظيف الإيميل من الحرفين الزائدين
  String _cleanEmail(String email) {
    if (email.toLowerCase().startsWith('tc') && email.length > 2) {
      return email.substring(2);
    }
    return email;
  }
  
  Future<void> _generatePDF(BuildContext context, List<TeacherStats> teacherStats) async {
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
      
      final avgExcellence = teacherStats.isEmpty ? 0.0 : (teacherStats.map((e) => e.avgExcellence).reduce((a, b) => a + b) / teacherStats.length);
      final avgLoad = teacherStats.isEmpty ? 0 : (teacherStats.map((e) => e.currentLoad).reduce((a, b) => a + b) / teacherStats.length).round();
      
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
                        color: PdfColors.purple700,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'تقرير أداء المعلمين',
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
                'مؤشرات أداء المعلمين',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatBox('إجمالي المعلمين', '${teacherStats.length}', PdfColors.blue),
                  _buildPdfStatBox('متوسط التميز', '${avgExcellence.toStringAsFixed(1)}', PdfColors.amber),
                  _buildPdfStatBox('متوسط الحصص', '$avgLoad', PdfColors.green),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // جدول المعلمين
              pw.Text(
                'تفاصيل أداء المعلمين',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                    children: [
                      _buildPdfTableCell('اسم المعلم', isHeader: true),
                      _buildPdfTableCell('التميز', isHeader: true),
                      _buildPdfTableCell('الحصص', isHeader: true),
                      _buildPdfTableCell('النسبة', isHeader: true),
                    ],
                  ),
                  ...teacherStats.take(10).map((stat) {
                    final loadPercent = stat.maxLoad == 0 ? 0 : ((stat.currentLoad / stat.maxLoad) * 100).round();
                    return pw.TableRow(children: [
                      _buildPdfTableCell(stat.teacherName),
                      _buildPdfTableCell('${stat.avgExcellence.toStringAsFixed(1)}'),
                      _buildPdfTableCell('${stat.currentLoad}/${stat.maxLoad}'),
                      _buildPdfTableCell('$loadPercent%'),
                    ]);
                  }).toList(),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // التوصيات
              pw.Text(
                'التوصيات',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              
              pw.Bullet(text: 'متوسط أداء المعلمين ممتاز (${avgExcellence.toStringAsFixed(1)})'),
              pw.Bullet(text: 'متوسط الحصص الأسبوعية: $avgLoad حصة'),
              pw.Bullet(text: 'التوصية: توزيع الحصص بشكل متوازن بين المعلمين'),
              pw.Bullet(text: 'التركيز على تطوير المعلمين ذوي الأداء المنخفض'),
              
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
      
      // استخدام Printing لكل المنصات
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'تقرير_أداء_المعلمين_${DateTime.now().toString().split(' ')[0]}.pdf',
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم فتح معاينة التقرير'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherStatsAsync = ref.watch(teacherStatsProvider);
    
    return teacherStatsAsync.when(
      data: (teacherStats) => _buildContent(context, ref, teacherStats),
      loading: () => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير أداء المعلمين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.purple.shade700,
          centerTitle: true,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('تقرير أداء المعلمين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.purple.shade700,
          centerTitle: true,
          elevation: 0,
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
  
  Widget _buildContent(BuildContext context, WidgetRef ref, List<TeacherStats> teacherStats) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('تقرير أداء المعلمين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.purple.shade700,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _generatePDF(context, teacherStats),
            tooltip: 'تحميل PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 📊 بطاقة الإحصائيات
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade600, Colors.purple.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
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
                          child: Icon(Icons.person, color: Colors.white, size: 28.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'مؤشرات أداء المعلمين',
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
                          child: _buildStatItem('إجمالي المعلمين', '${teacherStats.length}', Icons.people, Colors.white),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildStatItem('متوسط التميز', '${teacherStats.isEmpty ? 0 : (teacherStats.map((e) => e.avgExcellence).reduce((a, b) => a + b) / teacherStats.length).toStringAsFixed(1)}', Icons.star, Colors.amber),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildStatItem('متوسط الحصص', '${teacherStats.isEmpty ? 0 : (teacherStats.map((e) => e.currentLoad).reduce((a, b) => a + b) / teacherStats.length).toStringAsFixed(0)}', Icons.schedule, Colors.lightGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // 📋 قائمة المعلمين
              Expanded(
                child: teacherStats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64.sp, color: Colors.grey.shade300),
                            SizedBox(height: 16.h),
                            Text(
                              'لا توجد بيانات متاحة حالياً',
                              style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: teacherStats.length,
                        itemBuilder: (context, index) {
                          final stat = teacherStats[index];
                          final loadPercent = stat.maxLoad == 0
                              ? 0.0
                              : (stat.currentLoad / stat.maxLoad) * 100;
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
                                          color: Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.purple.shade700,
                                          size: 24.sp,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stat.teacherName,
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              _cleanEmail(stat.teacherEmail),
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: stat.avgExcellence >= 80 
                                              ? Colors.green.shade100 
                                              : stat.avgExcellence >= 60 
                                                  ? Colors.blue.shade100 
                                                  : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 16.sp,
                                              color: stat.avgExcellence >= 80 
                                                  ? Colors.green.shade700 
                                                  : stat.avgExcellence >= 60 
                                                      ? Colors.blue.shade700 
                                                      : Colors.orange.shade700,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              '${stat.avgExcellence.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                color: stat.avgExcellence >= 80 
                                                    ? Colors.green.shade700 
                                                    : stat.avgExcellence >= 60 
                                                        ? Colors.blue.shade700 
                                                        : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 16.sp, color: Colors.grey.shade600),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'الحصص: ${stat.currentLoad} من ${stat.maxLoad} (${loadPercent.toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  LinearProgressIndicator(
                                    value: loadPercent / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      loadPercent >= 90 ? Colors.red : loadPercent >= 70 ? Colors.orange : Colors.green,
                                    ),
                                    minHeight: 6.h,
                                    borderRadius: BorderRadius.circular(3.r),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
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
}
