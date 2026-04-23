import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';

class SubscriptionInvoiceArgs {
  final String transactionId;
  final String planId;
  final String planName;
  final String billingCycle;
  final int amount;
  final String currency;
  final DateTime purchaseDate;
  final DateTime? subscriptionEndsAt;

  const SubscriptionInvoiceArgs({
    required this.transactionId,
    required this.planId,
    required this.planName,
    required this.billingCycle,
    required this.amount,
    required this.currency,
    required this.purchaseDate,
    required this.subscriptionEndsAt,
  });
}

class SubscriptionInvoiceScreen extends ConsumerWidget {
  final SubscriptionInvoiceArgs args;

  const SubscriptionInvoiceScreen({
    super.key,
    required this.args,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId;

    if (user == null || schoolId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('فاتورة الاشتراك'),
        ),
        body: const Center(
          child: Text('تعذر تحميل بيانات المستخدم أو المدرسة.'),
        ),
      );
    }

    final schoolAsync = ref.watch(schoolProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة الاشتراك'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: schoolAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Text('حدث خطأ أثناء تحميل بيانات المدرسة: $e'),
          ),
          data: (school) {
            if (school == null) {
              return const Center(
                child: Text('تعذر العثور على بيانات المدرسة.'),
              );
            }

            final managerNameAsync = ref.watch(
              schoolManagerNameProvider((
                userId: school.ownerId,
                schoolId: school.id,
              )),
            );

            return managerNameAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => _buildInvoiceBody(
                context,
                user,
                school,
                null,
              ),
              data: (managerName) => _buildInvoiceBody(
                context,
                user,
                school,
                managerName,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceBody(
    BuildContext context,
    User purchaser,
    School school,
    String? managerName,
  ) {
    final formatter = intl.DateFormat('yyyy/MM/dd HH:mm');
    final purchaseDateText = formatter.format(args.purchaseDate);
    final expiryText = args.subscriptionEndsAt != null
        ? formatter.format(args.subscriptionEndsAt!)
        : 'غير متوفر';
    final billingLabel =
        args.billingCycle == 'yearly' ? 'سنوي' : 'شهري';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'منصة منار للإدارة المدرسية',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'فاتورة اشتراك نظام منار',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رقم الفاتورة: ${args.transactionId}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'تاريخ الشراء: $purchaseDateText',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المدرسة: ${school.name}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'المدينة: ${school.city}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات المدير / المشتري',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _infoRow('اسم المدير', managerName ?? purchaser.name),
                  _infoRow('البريد الإلكتروني', purchaser.email),
                  _infoRow(
                    'رقم الجوال',
                    purchaser.phoneNumber ?? 'غير متوفر',
                  ),
                  _infoRow(
                    'رقم الهوية',
                    purchaser.identityNumber ?? 'غير متوفر',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل الاشتراك',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _infoRow('الباقة', args.planName),
                  _infoRow('معرف الباقة', args.planId),
                  _infoRow('دورة الفوترة', billingLabel),
                  _infoRow(
                    'المبلغ',
                    '${args.amount} ${args.currency == 'SAR' ? 'ريال سعودي' : args.currency}',
                  ),
                  _infoRow('تاريخ انتهاء الباقة', expiryText),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () async {
              await _printInvoicePdf(
                purchaser: purchaser,
                school: school,
                managerName: managerName ?? purchaser.name,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('طباعة / تحميل الفاتورة PDF'),
          ),
          SizedBox(height: 12.h),
          Text(
            'تم إصدار هذه الفاتورة آلياً من نظام "منار" ويمكن استخدامها لإثبات الاشتراك لدى الإدارة المالية.',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[700],
              height: 1.4,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13.sp),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoicePdf({
    required User purchaser,
    required School school,
    required String managerName,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();

    final formatter = intl.DateFormat('yyyy/MM/dd HH:mm');
    final purchaseDateText = formatter.format(args.purchaseDate);
    final expiryText = args.subscriptionEndsAt != null
        ? formatter.format(args.subscriptionEndsAt!)
        : 'غير متوفر';
    final billingLabel =
        args.billingCycle == 'yearly' ? 'سنوي' : 'شهري';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'منصة منار للإدارة المدرسية',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'فاتورة اشتراك نظام منار',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'رقم الفاتورة: ${args.transactionId}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'تاريخ الشراء: $purchaseDateText',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'المدرسة: ${school.name}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'المدينة: ${school.city}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'بيانات المدير / المشتري',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _pdfInfoRow('اسم المدير', managerName),
                      _pdfInfoRow('البريد الإلكتروني', purchaser.email),
                      _pdfInfoRow(
                        'رقم الجوال',
                        purchaser.phoneNumber ?? 'غير متوفر',
                      ),
                      _pdfInfoRow(
                        'رقم الهوية',
                        purchaser.identityNumber ?? 'غير متوفر',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'تفاصيل الاشتراك',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _pdfInfoRow('الباقة', args.planName),
                      _pdfInfoRow('معرف الباقة', args.planId),
                      _pdfInfoRow('دورة الفوترة', billingLabel),
                      _pdfInfoRow(
                        'المبلغ',
                        '${args.amount} ${args.currency == 'SAR' ? 'ريال سعودي' : args.currency}',
                      ),
                      _pdfInfoRow('تاريخ انتهاء الباقة', expiryText),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Text(
                  'تم إصدار هذه الفاتورة آلياً عبر نظام "منار" للإدارة المدرسية الذكية.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Manar_Subscription_Invoice_${args.transactionId}.pdf',
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

