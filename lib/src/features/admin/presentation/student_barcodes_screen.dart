import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../academic/presentation/students_provider.dart';
import '../../../core/domain/models/user.dart';

class StudentBarcodesScreen extends ConsumerWidget {
  const StudentBarcodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('باركود الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              studentsAsync.whenData((students) {
                if (students.isNotEmpty) {
                  _generateAndPrintPdf(context, students);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يوجد طلاب لتصديرهم')),
                  );
                }
              });
            },
            tooltip: 'تحميل باركود الطلاب PDF',
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return const Center(child: Text('لا يوجد طلاب'));
          }
          return GridView.builder(
            padding: EdgeInsets.all(16.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.h,
              childAspectRatio: 0.8,
            ),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Expanded(
                        child: Center(
                          child: QrImageView(
                            data: student.identityNumber ?? '',
                            version: QrVersions.auto,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        student.identityNumber ?? 'بدون اسم مستخدم',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Future<void> _generateAndPrintPdf(
    BuildContext context,
    List<User> students,
  ) async {
    final pdf = pw.Document();
    
    // Arabic font handling would ideally require loading a font
    // For now, we'll try to use standard fonts or load one if available in assets
    // Since we can't easily load assets without async setup, we will use a fallback
    // However, `printing` package usually handles system fonts or we need to provide one.
    // We will use a simple layout.

    // Group students into chunks of 6 or 8 per page
    const itemsPerPage = 6;
    final chunks = <List<User>>[];
    for (var i = 0; i < students.length; i += itemsPerPage) {
      chunks.add(
        students.sublist(
          i,
          i + itemsPerPage > students.length ? students.length : i + itemsPerPage,
        ),
      );
    }
    
    // Load a font that supports Arabic
    final font = await PdfGoogleFonts.cairoRegular();

    for (final chunk in chunks) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: chunk.map((student) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        student.name,
                        style: const pw.TextStyle(fontSize: 18),
                        textAlign: pw.TextAlign.center,
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 10),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: student.identityNumber ?? '',
                        width: 100,
                        height: 100,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        student.identityNumber ?? '',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'student_barcodes.pdf',
    );
  }
}
