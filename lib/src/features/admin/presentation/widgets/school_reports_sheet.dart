import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class SchoolReportsSheet extends StatefulWidget {
  const SchoolReportsSheet({super.key});

  @override
  State<SchoolReportsSheet> createState() => _SchoolReportsSheetState();
}

class _SchoolReportsSheetState extends State<SchoolReportsSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تقارير المدارس',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildReportButton(
              context,
              'تقرير حالات الاعتماد (مقبولة/غير مقبولة)',
              Icons.approval,
              Colors.blue,
              _generateApprovalReport,
            ),
            SizedBox(height: 16.h),
            _buildReportButton(
              context,
              'تقرير الاشتراكات المفعلة',
              Icons.subscriptions,
              Colors.green,
              _generateSubscriptionReport,
            ),
          ],
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildReportButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Future<void> Function() onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        setState(() => _isLoading = true);
        try {
          await onTap();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      icon: Icon(icon, size: 24.sp),
      label: Text(
        title,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _generateApprovalReport() async {
    // Fetch data
    final snapshot = await FirebaseFirestore.instance
        .collection('SchoolRequests')
        .orderBy('createdAt', descending: true)
        .get();

    final requests = snapshot.docs.map((d) => d.data()).toList();
    final approved = requests.where((r) => r['status'] == 'approved').toList();
    final rejected = requests.where((r) => r['status'] == 'rejected').toList();

    final font = await PdfGoogleFonts.tajawalRegular();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Header(
                level: 0,
                child: pw.Center(
                  child: pw.Text(
                    'تقرير حالات اعتماد المدارس',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المدرسة (مقبولة)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'الحالة',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المدرسة (مرفوضة)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'الحالة',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Data
                    ...List.generate(
                      (approved.length > rejected.length
                          ? approved.length
                          : rejected.length),
                      (index) {
                        final app = index < approved.length
                            ? approved[index]
                            : null;
                        final rej = index < rejected.length
                            ? rejected[index]
                            : null;

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                app?['schoolName'] ?? '-',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                app != null ? 'مقبولة' : '-',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                rej?['schoolName'] ?? '-',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                rej != null ? 'مرفوضة' : '-',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'تم استخراج التقرير بتاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'school_approvals_report.pdf',
    );
  }

  Future<void> _generateSubscriptionReport() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Schools')
        .get();

    final schools = snapshot.docs.map((d) => d.data()).toList();
    // Filter schools that have subscription info
    final subscribed = schools
        .where(
          (s) =>
              s['subscriptionPlan'] != null && s['subscriptionPlan'] != 'free',
        )
        .toList();

    final font = await PdfGoogleFonts.tajawalRegular();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Header(
                level: 0,
                child: pw.Center(
                  child: pw.Text(
                    'تقرير الاشتراكات المفعلة',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'اسم المدرسة',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'الخطة',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'تاريخ الاشتراك',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المدة',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Data
                    ...subscribed.map((school) {
                      final plan = school['subscriptionPlan'] ?? 'N/A';

                      // Safe Date Parsing
                      DateTime? endDate;
                      try {
                        final endVal = school['subscriptionEndsAt'];
                        if (endVal is Timestamp) {
                          endDate = endVal.toDate();
                        } else if (endVal is String) {
                          endDate = DateTime.parse(endVal);
                        }
                      } catch (_) {}

                      String duration = 'غير محدد';
                      if (school['isLifetimeAccess'] == true) {
                        duration = 'مدى الحياة';
                      } else if (endDate != null) {
                        final now = DateTime.now();
                        final diff = endDate.difference(now).inDays;
                        if (diff > 0) {
                          duration = '$diff يوم متبقي';
                        } else {
                          duration = 'منتهي';
                        }
                      } else {
                        duration = 'سنوي';
                      }

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              school['name'] ?? '-',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(plan, textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              endDate != null
                                  ? intl.DateFormat(
                                      'yyyy/MM/dd',
                                    ).format(endDate)
                                  : '-',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              duration,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'school_subscriptions_report.pdf',
    );
  }
}
