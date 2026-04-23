import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../academic/data/school_repository.dart';
import '../../domain/administrative_assignment.dart';

class AssignmentDashboardScreen extends ConsumerWidget {
  final AdministrativeAssignment assignment;

  const AssignmentDashboardScreen({super.key, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = _getTabsForType(assignment.type);
    final user = ref.watch(authStateProvider).value;
    final schoolAsync = ref.watch(
      schoolProvider(user?.schoolId ?? ''),
    );

    return Scaffold(
      appBar: AppBar(
        title: schoolAsync.when(
          data: (school) => Column(
            children: [
              Text(
                school != null
                    ? 'منصة منار | ${school.name}'
                    : 'منصة منار',
              ),
              Text(
                'لوحة ${assignment.type.label}',
                style: TextStyle(fontSize: 12.sp, color: Colors.white70),
              ),
            ],
          ),
          loading: () => const Text('منصة منار'),
          error: (_, __) => const Text('منصة منار'),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return _buildTabContent(context, tab);
        },
      ),
    );
  }

  List<DashboardTab> _getTabsForType(AssignmentType type) {
    switch (type) {
      case AssignmentType.healthGuide:
        return [
          DashboardTab(
            title: 'البيانات الصحية',
            sheets: ['كشف الحالات المزمنة', 'سجل الطلاب للمتابعة'],
          ),
          DashboardTab(
            title: 'الحالات المرضية',
            sheets: ['كشف الحالات اليومية', 'الإحالات'],
          ),
          DashboardTab(
            title: 'الإسعافات الأولية',
            sheets: ['سجل الأدوات', 'استهلاك المواد'],
          ),
          DashboardTab(
            title: 'المتابعة الصحية',
            sheets: ['سجل الزيارات', 'الفحص الدوري'],
          ),
          DashboardTab(title: 'التقارير', sheets: ['تقرير شهري', 'تقرير سنوي']),
        ];
      case AssignmentType.safetyOfficer:
        return [
          DashboardTab(
            title: 'سلامة المبنى',
            sheets: ['كشف جولات السلامة', 'الملاحظات الفنية'],
          ),
          DashboardTab(
            title: 'خطط الإخلاء',
            sheets: ['سجل تنفيذ الخطط', 'تقييم الإخلاء'],
          ),
          DashboardTab(title: 'الحوادث', sheets: ['كشف الحوادث', 'الإصابات']),
          DashboardTab(
            title: 'المتابعة الدورية',
            sheets: ['كشف طفايات الحريق', 'مخارج الطوارئ'],
          ),
          DashboardTab(
            title: 'التقارير',
            sheets: ['تقرير السلامة', 'بلاغات الدفاع المدني'],
          ),
        ];
      case AssignmentType.activityLeader:
        return [
          DashboardTab(
            title: 'الأنشطة المدرسية',
            sheets: ['كشف الأنشطة المنفذة', 'خطة النشاط'],
          ),
          DashboardTab(
            title: 'المشاركات',
            sheets: ['الطلاب المشاركين', 'المسابقات'],
          ),
          DashboardTab(
            title: 'الفعاليات',
            sheets: ['سجل الفعاليات', 'الاحتفالات'],
          ),
          DashboardTab(title: 'الإنجاز', sheets: ['سجل المنجزات', 'الجوائز']),
          DashboardTab(
            title: 'التقارير',
            sheets: ['تقرير النشاط', 'الإحصائيات'],
          ),
        ];
      case AssignmentType.classLeader:
        return [
          DashboardTab(
            title: 'متابعة الطلاب',
            sheets: ['كشف الغياب والتأخر', 'قائمة الفصل'],
          ),
          DashboardTab(
            title: 'السلوك',
            sheets: ['السلوكيات الإيجابية', 'المخالفات'],
          ),
          DashboardTab(
            title: 'التواصل',
            sheets: ['سجل تواصل الأولياء', 'رسائل الجوال'],
          ),
          DashboardTab(
            title: 'التقارير',
            sheets: ['تقرير حالة الفصل', 'المستوى التحصيلي'],
          ),
        ];
      case AssignmentType.deputy:
        return [
          DashboardTab(
            title: 'المتابعة الإدارية',
            sheets: ['سجل الملاحظات', 'التعاميم'],
          ),
          DashboardTab(
            title: 'شؤون المعلمين',
            sheets: ['كشف الانتظار', 'الإشراف اليومي'],
          ),
          DashboardTab(
            title: 'شؤون الطلاب',
            sheets: ['الغياب اليومي', 'المخالفات'],
          ),
          DashboardTab(
            title: 'التنظيم',
            sheets: ['الخطة التشغيلية', 'المناوبات'],
          ),
          DashboardTab(
            title: 'التقارير',
            sheets: ['تقرير الوكيل', 'الإحصاء العام'],
          ),
        ];
      case AssignmentType.stageDeputy:
        return [
          DashboardTab(
            title: 'متابعة الحصص',
            sheets: ['جدول الحصص', 'الانتظار', 'المناوبة'],
          ),
          DashboardTab(
            title: 'المعلمين',
            sheets: ['الغياب والتأخر', 'الاستئذان'],
          ),
          DashboardTab(
            title: 'الطلاب',
            sheets: ['المخالفات السلوكية', 'طلبات الاستئذان', 'الغياب'],
          ),
          DashboardTab(
            title: 'الملاحظات',
            sheets: ['ملاحظات يومية', 'تقارير المرحلة'],
          ),
        ];
      case AssignmentType.committee:
        return [
          DashboardTab(
            title: 'أعضاء اللجنة',
            sheets: ['كشف الأعضاء', 'توزيع المهام'],
          ),
          DashboardTab(
            title: 'المهام',
            sheets: ['سجل المهام', 'متابعة الإنجاز'],
          ),
          DashboardTab(
            title: 'الاجتماعات',
            sheets: ['محاضر الاجتماعات', 'التوصيات'],
          ),
          DashboardTab(title: 'الإنجاز', sheets: ['نسب الإنجاز', 'المخرجات']),
          DashboardTab(title: 'التقارير', sheets: ['التقرير الختامي']),
        ];
    }
  }

  Widget _buildTabContent(BuildContext context, DashboardTab tab) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _buildSectionHeader(tab.title),
        ...tab.sheets.map((sheet) => _buildSheetCard(context, sheet)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(width: 4.w, height: 24.h, color: Colors.indigo),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetCard(BuildContext context, String title) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(Icons.table_chart, color: Colors.blue.shade700),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        subtitle: Text(
          'سجل رسمي معتمد',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16.sp,
          color: Colors.grey,
        ),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('سيتم فتح $title قريباً')));
        },
      ),
    );
  }
}

class DashboardTab {
  final String title;
  final List<String> sheets;

  DashboardTab({required this.title, required this.sheets});
}
