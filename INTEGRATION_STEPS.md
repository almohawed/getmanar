# خطوات التكامل - ملخص حمل المعلم

## 📋 الملفات المضافة

### 1. مكون الملخص (Widget)
```
lib/src/features/schedule/presentation/widgets/teacher_load_summary_widget.dart
```
- مكون Flutter قابل لإعادة الاستخدام
- يعرض الحصص المطلوبة والمجدولة والفترات الحرة
- تصميم احترافي مع ألوان ديناميكية

### 2. شاشة جدول المعلم المحسّنة
```
lib/src/features/schedule/presentation/teacher_schedule_with_summary_screen.dart
```
- شاشة كاملة تعرض جدول المعلم مع الملخص
- تجميع البيانات من Firestore
- عرض جدول تفاعلي

### 3. تحديث خدمة PDF
```
lib/src/features/schedule/services/pdf_export_service.dart
```
- إضافة دوال لحساب ملخص الحمل
- إضافة عنصر الملخص في PDF
- تحسين تقارير المعلمين

## 🔧 خطوات التكامل

### الخطوة 1: التحقق من الملفات
تأكد من وجود الملفات الثلاثة:
```bash
✓ lib/src/features/schedule/presentation/widgets/teacher_load_summary_widget.dart
✓ lib/src/features/schedule/presentation/teacher_schedule_with_summary_screen.dart
✓ lib/src/features/schedule/services/pdf_export_service.dart (محدّث)
```

### الخطوة 2: تحديث التوجيه (Routing)
في ملف التوجيه الرئيسي (مثل `lib/main.dart` أو `lib/config/router.dart`):

```dart
// أضف المسار الجديد
GoRoute(
  path: '/teacher-schedule-summary',
  builder: (context, state) {
    final teacherId = state.pathParameters['teacherId'] ?? '';
    final schoolId = state.pathParameters['schoolId'] ?? '';
    
    return TeacherScheduleWithSummaryScreen(
      teacherId: teacherId,
      schoolId: schoolId,
    );
  },
),
```

### الخطوة 3: تحديث الروابط في التطبيق
في `lib/src/features/dashboard/presentation/teacher_dashboard.dart`:

```dart
// استبدل الرابط القديم
_buildMenuCard(
  context,
  'جدولي',
  Icons.calendar_today,
  Colors.teal,
  () => context.push('/teacher-schedule-summary?teacherId=$teacherId&schoolId=$schoolId'),
),
```

### الخطوة 4: استخدام المكون في أماكن أخرى
يمكنك استخدام `TeacherLoadSummaryWidget` في أي شاشة:

```dart
import 'package:your_app/features/schedule/presentation/widgets/teacher_load_summary_widget.dart';

// في أي شاشة
TeacherLoadSummaryWidget(
  teacherName: teacherName,
  requiredLessons: requiredLessons,
  actualLessons: actualLessons,
  freePeriods: freePeriods,
  totalPeriods: totalPeriods,
)
```

### الخطوة 5: اختبار تصدير PDF
```dart
// في أي مكان في التطبيق
await PdfExportService.exportTeacherSchedules(schoolId);
```

## 📊 البيانات المطلوبة

### من Firestore - Teachers Collection:
```json
{
  "name": "أحمد محمد",
  "requiredLessons": 24,
  ...
}
```

### من Firestore - Schedules Collection:
```json
{
  "className": "الصف الأول",
  "schedule": {
    "الأحد": [
      {
        "teacherId": "teacher123",
        "subjectName": "الرياضيات",
        "className": "الصف الأول"
      },
      ...
    ],
    ...
  }
}
```

## 🎨 التخصيص

### تغيير الألوان:
في `teacher_load_summary_widget.dart`:
```dart
// غيّر الألوان حسب الحاجة
color: Colors.green,  // اللون الأساسي
isComplete ? Colors.green.shade50 : Colors.orange.shade50,  // لون الخلفية
```

### تغيير الرسالة الموضحة:
في `pdf_export_service.dart`:
```dart
pw.Text(
  'رسالتك الخاصة هنا',  // غيّر الرسالة
  style: pw.TextStyle(...),
)
```

## ✅ قائمة التحقق

- [ ] تم نسخ الملفات الثلاثة
- [ ] تم تحديث ملف التوجيه
- [ ] تم تحديث روابط التطبيق
- [ ] تم اختبار الشاشة الجديدة
- [ ] تم اختبار تصدير PDF
- [ ] تم التحقق من البيانات في Firestore
- [ ] تم اختبار على أجهزة مختلفة

## 🚀 الاختبار

### اختبار الشاشة:
1. افتح التطبيق
2. انتقل إلى جدول المعلم
3. تحقق من ظهور ملخص الحمل
4. تحقق من صحة الأرقام

### اختبار PDF:
1. اضغط على تصدير PDF
2. افتح الملف
3. تحقق من ظهور ملخص الحمل في الأعلى
4. تحقق من صحة الإحصائيات

## 📝 ملاحظات مهمة

1. **البيانات**: تأكد من أن `requiredLessons` موجود في بيانات المعلم
2. **الأداء**: الشاشة تستخدم StreamBuilder للبيانات الحية
3. **التوافقية**: الكود متوافق مع Flutter 3.0+
4. **الاستجابة**: التصميم متجاوب على جميع الأجهزة

## 🔗 الملفات ذات الصلة

- `lib/src/features/dashboard/presentation/teacher_dashboard.dart` - لوحة تحكم المعلم
- `lib/src/features/schedule/services/pdf_export_service.dart` - خدمة PDF
- `lib/src/features/simple_schedule/presentation/my_schedule_screen.dart` - جدول بسيط

## 💡 نصائح

1. استخدم `TeacherLoadSummaryWidget` في أي مكان تريد عرض ملخص الحمل
2. يمكنك تخصيص الألوان والرسائل حسب احتياجاتك
3. الملخص يُحدّث تلقائياً عند تغيير البيانات
4. PDF يتضمن الملخص تلقائياً عند التصدير

---

**تم إنشاء جميع الملفات وهي جاهزة للاستخدام الفوري!**
