import 'dart:typed_data';
import '../domain/ministry_pdf_template.dart';
import '../../maintenance/domain/models/maintenance_report.dart';
import '../../counselor/domain/models/student_case.dart';
import '../../counselor/domain/models/counselor_session.dart';
import '../../counselor/domain/models/behavior_plan.dart';

class PdfReportsGenerator {
  // 1. Maintenance Report (General)
  static Future<Uint8List> generateMaintenanceReport({
    required String schoolName,
    required List<MaintenanceReport> reports,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف بلاغات الصيانة",
      subTitle: "تقرير شامل للبلاغات",
      schoolName: schoolName,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: [
        'م',
        'رقم البلاغ',
        'الموقع',
        'العنوان',
        'الأولوية',
        'الحالة',
        'التاريخ',
        'ملاحظات',
      ],
      tableData: reports.asMap().entries.map<List<String>>((entry) {
        final index = entry.key + 1;
        final report = entry.value;
        return <String>[
          index.toString(),
          '${report.id.substring(0, 8)}',
          '${report.location}',
          '${report.title}',
          '${report.priority.name}',
          '${report.status.name}',
          '${report.createdAt.toString().split(' ')[0]}',
          report.description.length > 20
              ? '${report.description.substring(0, 20)}...'
              : '${report.description}',
        ];
      }).toList(),
      footerText: "نظام منار - إدارة الصيانة",
    );
    return pdf.save();
  }

  static Future<Uint8List> generateCounselorActiveCases({
    required String schoolName,
    required List<StudentCase> cases,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الحالات النشطة للمرشد",
      subTitle: "Student Counseling Active Cases",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'اسم الطالب',
        'العنوان',
        'الأولوية',
        'الحالة',
        'تاريخ الإنشاء',
        'المكلف',
        'الشواهد',
      ],
      tableData: cases
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key + 1;
            final c = entry.value;
            return [
              index.toString(),
              c.studentName,
              c.title,
              _mapCasePriority(c.priority),
              _mapCaseStatus(c.status),
              c.createdAt.toString().split(' ')[0],
              c.assignedTo ?? '—',
              c.evidenceCount.toString(),
            ];
          })
          .toList()
          .cast<List<String>>(),
      footerText: "نظام منار - الإرشاد الطلابي",
    );
    return pdf.save();
  }

  static Future<Uint8List> generateCounselorTodaySessions({
    required String schoolName,
    required List<CounselorSession> sessions,
  }) async {
    final today = DateTime.now().toString().split(' ')[0];
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف جلسات الإرشاد اليوم ($today)",
      subTitle: "Scheduled Counseling Sessions",
      schoolName: schoolName,
      dateFrom: today,
      dateTo: today,
      tableHeaders: [
        'م',
        'العنوان',
        'النوع',
        'الوقت',
        'المدة (د)',
        'الحالة',
        'عدد الحضور',
        'الشواهد',
      ],
      tableData: sessions
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key + 1;
            final s = entry.value;
            final timeStr = s.scheduledAt.toString().substring(11, 16);
            return [
              index.toString(),
              s.title,
              _mapSessionType(s.type),
              timeStr,
              s.durationMinutes.toString(),
              _mapSessionStatus(s.status),
              s.attendeeIds.length.toString(),
              s.evidenceCount.toString(),
            ];
          })
          .toList()
          .cast<List<String>>(),
      footerText: "نظام منار - الإرشاد الطلابي",
    );
    return pdf.save();
  }

  static Future<Uint8List> generateCounselorActivePlans({
    required String schoolName,
    required List<BehaviorPlan> plans,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الخطط السلوكية النشطة",
      subTitle: "Active Behavior Plans",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'اسم الطالب',
        'عنوان الخطة',
        'الأهداف',
        'الحالة',
        'تاريخ البدء',
        'موعد المراجعة',
        'الشواهد',
      ],
      tableData: plans
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key + 1;
            final p = entry.value;
            final goals = p.goals.isNotEmpty
                ? (p.goals.length > 2
                      ? '${p.goals.take(2).join('، ')}...'
                      : p.goals.join('، '))
                : '—';
            return [
              index.toString(),
              p.studentName,
              p.title,
              goals,
              _mapPlanStatus(p.status),
              p.startDate.toString().split(' ')[0],
              p.reviewAt?.toString().split(' ')[0] ?? '—',
              p.evidenceCount.toString(),
            ];
          })
          .toList()
          .cast<List<String>>(),
      footerText: "نظام منار - الإرشاد الطلابي",
    );
    return pdf.save();
  }

  static String _mapCaseStatus(CaseStatus s) {
    switch (s) {
      case CaseStatus.open:
        return 'مفتوحة';
      case CaseStatus.in_progress:
        return 'قيد المعالجة';
      case CaseStatus.resolved:
        return 'تم الحل';
      case CaseStatus.closed:
        return 'مغلقة';
    }
  }

  static String _mapCasePriority(CasePriority p) {
    switch (p) {
      case CasePriority.low:
        return 'منخفضة';
      case CasePriority.medium:
        return 'متوسطة';
      case CasePriority.high:
        return 'عالية';
      case CasePriority.urgent:
        return 'عاجلة';
    }
  }

  static String _mapSessionStatus(SessionStatus s) {
    switch (s) {
      case SessionStatus.scheduled:
        return 'مجدولة';
      case SessionStatus.completed:
        return 'منفذة';
      case SessionStatus.cancelled:
        return 'ملغاة';
      case SessionStatus.no_show:
        return 'لم يحضر';
    }
  }

  static String _mapSessionType(SessionType t) {
    switch (t) {
      case SessionType.individual:
        return 'فردية';
      case SessionType.group:
        return 'جماعية';
      case SessionType.family:
        return 'اجتماع ولي أمر';
      case SessionType.teacher_meeting:
        return 'اجتماع مع المعلم';
    }
  }

  static String _mapPlanStatus(PlanStatus s) {
    switch (s) {
      case PlanStatus.active:
        return 'نشطة';
      case PlanStatus.completed:
        return 'مكتملة';
      case PlanStatus.dropped:
        return 'متوقفة';
      case PlanStatus.review_needed:
        return 'تحتاج مراجعة';
    }
  }

  // 2. Overdue Report
  static Future<Uint8List> generateOverdueReport({
    required String schoolName,
    required List<MaintenanceReport> reports,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف البلاغات المتأخرة",
      subTitle: "SLA Violations",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0], // Current Snapshot
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'رقم البلاغ',
        'الموقع',
        'العنوان',
        'الأولوية',
        'تاريخ البلاغ',
        'تاريخ الاستحقاق',
        'التأخير (ساعة)',
      ],
      tableData: reports.asMap().entries.map<List<String>>((entry) {
        final index = entry.key + 1;
        final report = entry.value;
        final dueAt = report.dueAt ?? DateTime.now();
        final delay = DateTime.now().difference(dueAt).inHours;

        return <String>[
          index.toString(),
          '${report.id.substring(0, 8)}',
          '${report.location}',
          '${report.title}',
          '${report.priority.name}',
          '${report.createdAt.toString().split(' ')[0]}',
          '${dueAt.toString().split(' ')[0]}',
          '${delay}',
        ];
      }).toList(),
      footerText: "نظام منار - متابعة الأداء",
    );
    return pdf.save();
  }

  // 4. Safety Checklist
  static Future<Uint8List> generateSafetyChecklist({
    required String schoolName,
    required String responsibleName,
  }) async {
    final items = [
      'فحص طفايات الحريق',
      'سلامة مخارج الطوارئ',
      'إنارة الطوارئ',
      'حقيبة الإسعافات الأولية',
      'سلامة التمديدات الكهربائية',
      'نظافة دورات المياه',
      'جاهزية الساحات والممرات',
      'سلامة البوابات',
      'سجل الزوار',
    ];

    final pdf = await MinistryPdfTemplate.generateReport(
      title: "قائمة تحقق الأمن والسلامة اليومية",
      subTitle: "المسؤول: $responsibleName",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: ['م', 'البند', 'الحالة (✓ / ✗)', 'الملاحظات'],
      tableData: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        return [
          index.toString(),
          entry.value,
          '', // Empty for manual check
          '', // Empty for notes
        ];
      }).toList(),
      footerText: "نظام منار - الأمن والسلامة",
    );
    return pdf.save();
  }

  // 3. Completed Maintenance Report
  static Future<Uint8List> generateCompletedReport({
    required String schoolName,
    required List<MaintenanceReport> reports,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الصيانة المنجزة",
      subTitle: "Completed Maintenance Tasks",
      schoolName: schoolName,
      dateFrom: dateFrom.toString().split(' ')[0],
      dateTo: dateTo.toString().split(' ')[0],
      tableHeaders: [
        'م',
        'رقم البلاغ',
        'الموقع',
        'العنوان',
        'تاريخ البلاغ',
        'مدة المعالجة',
        'المنفذ',
        'الشواهد',
      ],
      tableData: reports.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final report = entry.value;
        // Calculate duration if closedAt existed, for now just use placeholder
        return [
          index.toString(),
          report.id.substring(0, 8),
          report.location,
          report.title,
          report.createdAt.toString().split(' ')[0],
          '--', // Duration placeholder
          report.assignedTo ?? 'غير محدد',
          report.evidenceCount.toString(),
        ];
      }).toList(),
      footerText: "نظام منار - الصيانة المنجزة",
    );
    return pdf.save();
  }

  // 5. Inventory Audit
  static Future<Uint8List> generateInventoryAudit({
    required String schoolName,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الجرد الإلكتروني",
      subTitle: "Inventory Audit",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'الصنف',
        'الكمية الحالية',
        'الحد الأدنى',
        'الموقع',
        'آخر تحديث',
      ],
      tableData: items.asMap().entries.map<List<String>>((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        return <String>[
          index.toString(),
          '${item['name'] ?? ''}',
          '${item['quantity']?.toString() ?? '0'}',
          '${item['minQuantity']?.toString() ?? '0'}',
          '${item['location'] ?? ''}',
          '${item['updatedAt']?.toString().split(' ')[0] ?? ''}',
        ];
      }).toList(),
      footerText: "نظام منار - المستودع",
    );
    return pdf.save();
  }

  // 6. Material Requests
  static Future<Uint8List> generateMaterialRequests({
    required String schoolName,
    required List<Map<String, dynamic>> requests,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف طلبات المواد",
      subTitle: "Material Requests",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'رقم الطلب',
        'الصنف',
        'الكمية',
        'مقدم الطلب',
        'الحالة',
      ],
      tableData: requests.asMap().entries.map<List<String>>((entry) {
        final index = entry.key + 1;
        final req = entry.value;
        return <String>[
          index.toString(),
          '${req['id']?.substring(0, 8) ?? ''}',
          '${req['itemName'] ?? ''}',
          '${req['quantity']?.toString() ?? '0'}',
          '${req['requesterName'] ?? ''}',
          '${req['status'] ?? ''}',
        ];
      }).toList(),
      footerText: "نظام منار - المشتريات",
    );
    return pdf.save();
  }

  // 7. Inbound/Outbound
  static Future<Uint8List> generateInboundOutbound({
    required String schoolName,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = await MinistryPdfTemplate.generateReport(
      title: "كشف الصادر والوارد",
      subTitle: "Inbound/Outbound Log",
      schoolName: schoolName,
      dateFrom: DateTime.now().toString().split(' ')[0],
      dateTo: DateTime.now().toString().split(' ')[0],
      tableHeaders: [
        'م',
        'رقم المعاملة',
        'النوع',
        'الجهة',
        'الموضوع',
        'التاريخ',
        'الإجراء',
      ],
      tableData: transactions.asMap().entries.map<List<String>>((entry) {
        final index = entry.key + 1;
        final tx = entry.value;
        return <String>[
          index.toString(),
          '${tx['id'] ?? ''}',
          '${tx['type'] == 'inbound' ? 'وارد' : 'صادر'}',
          '${tx['source'] ?? ''}',
          '${tx['subject'] ?? ''}',
          '${tx['date']?.toString().split(' ')[0] ?? ''}',
          '${tx['action'] ?? ''}',
        ];
      }).toList(),
      footerText: "نظام منار - الاتصالات الإدارية",
    );
    return pdf.save();
  }
}


