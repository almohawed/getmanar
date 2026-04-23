# 📖 دليل الكليشة السعودية في PDF

## 🎯 نظرة سريعة

هذا الدليل يشرح كيفية عمل الكليشة السعودية الرسمية في جميع تقارير PDF في النظام.

---

## 📋 المحتويات

1. [ما هي الكليشة السعودية؟](#ما-هي-الكليشة-السعودية)
2. [كيف تعمل؟](#كيف-تعمل)
3. [الملفات المستخدمة](#الملفات-المستخدمة)
4. [كيفية الاستخدام](#كيفية-الاستخدام)
5. [التخصيص](#التخصيص)
6. [حل المشاكل](#حل-المشاكل)

---

## ما هي الكليشة السعودية؟

الكليشة السعودية هي التنسيق الرسمي المعتمد للوثائق الحكومية في المملكة العربية السعودية.

### تتكون من:

1. **الرأسية (Header):**
   - شعار المملكة/المدرسة
   - معلومات الوزارة
   - معلومات الفصل/الوثيقة
   - عنوان التقرير

2. **المحتوى:**
   - الجداول والبيانات
   - بتنسيق احترافي

3. **التذييل (Footer):**
   - خانات التوقيع
   - المعلم/المسؤول
   - مدير المدرسة

---

## كيف تعمل؟

### 1. تحميل الخط العربي

```dart
// يتم تحميل الخط من الملفات المحلية
final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
final font = pw.Font.ttf(fontData);
```

### 2. بناء الرأسية

```dart
final header = await _buildOfficialHeader(
  title: 'كشف أسماء الطلاب',
  className: 'الأول أ',
  semester: 'الثاني 1447',
  grade: 'الأول الابتدائي',
  schoolName: 'مدرسة الاختبار',
);
```

### 3. بناء المحتوى

```dart
pw.Table(
  children: [
    // الرأسية
    pw.TableRow(children: headers),
    // البيانات
    ...data.map((row) => pw.TableRow(children: row)),
  ],
)
```

### 4. بناء التذييل

```dart
final footer = await _buildOfficialFooter(
  teacherName: 'أحمد محمد',
  principalName: 'خالد علي',
);
```

---

## الملفات المستخدمة

### الخطوط:
```
assets/fonts/Cairo-Regular.ttf
```

### الشعارات:
```
images/logokshuf.webp  (أساسي)
images/mylogo.png      (احتياطي)
```

### الكود:
```
lib/src/features/common/services/pdf_export_service.dart
lib/src/features/schedule/services/pdf_export_service.dart
```

---

## كيفية الاستخدام

### 1. استخدام بسيط

```dart
// إنشاء خدمة PDF
final pdfService = PdfExportService(
  schoolName: 'مدرسة الاختبار',
  teacherName: 'أحمد محمد',
  principalName: 'خالد علي',
);

// تصدير تقرير
await pdfService.printStudentNamesLog(
  students,
  'الأول أ',
);
```

### 2. استخدام متقدم

```dart
// مع خيارات مخصصة
final pdfService = PdfExportService(
  schoolName: 'مدرسة الاختبار',
  teacherName: 'أحمد محمد',
  principalName: 'خالد علي',
  signerTitle: 'المرشد الطلابي',  // تخصيص العنوان
  managerOnlyFooter: false,         // إظهار كلا التوقيعين
  defaultShowClassInfo: true,       // إظهار معلومات الفصل
);
```

### 3. تقرير مخصص

```dart
await pdfService._printGenericReport(
  title: 'تقرير مخصص',
  columns: ['م', 'الاسم', 'الملاحظات'],
  data: [
    ['1', 'أحمد', 'ممتاز'],
    ['2', 'خالد', 'جيد جداً'],
  ],
  filenameSuffix: 'CustomReport',
  className: 'الأول أ',
  landscape: false,  // أو true للأفقي
);
```

---

## التخصيص

### 1. تغيير الشعار

```dart
// في _buildOfficialHeader()
try {
  final data = await rootBundle.load('images/your_logo.png');
  logo = pw.MemoryImage(data.buffer.asUint8List());
} catch (e) {
  // fallback
}
```

### 2. تغيير الألوان

```dart
// الرأسية
decoration: pw.BoxDecoration(
  border: pw.Border.all(
    width: 2.5,
    color: PdfColors.blue,  // غير اللون هنا
  ),
),

// العنوان
decoration: pw.BoxDecoration(
  color: PdfColors.blue50,  // غير الخلفية هنا
),
```

### 3. تغيير الخط

```dart
// استخدم خط مختلف
final fontData = await rootBundle.load('assets/fonts/YourFont.ttf');
final font = pw.Font.ttf(fontData);
```

### 4. تخصيص التذييل

```dart
// توقيع واحد فقط
final pdfService = PdfExportService(
  managerOnlyFooter: true,  // مدير فقط
);

// أو تغيير العنوان
final pdfService = PdfExportService(
  signerTitle: 'المرشد الطلابي',  // بدلاً من "المعلم"
);
```

---

## حل المشاكل

### المشكلة 1: الشعار لا يظهر

**الأعراض:**
- مربع فارغ بدلاً من الشعار

**الحل:**
```bash
# تحقق من وجود الملف
ls images/logokshuf.webp

# إذا لم يكن موجوداً، أضفه
cp your_logo.webp images/logokshuf.webp
```

---

### المشكلة 2: الخط غير واضح

**الأعراض:**
- نصوص مربعات أو غير مقروءة

**الحل:**
```bash
# تحقق من الخط
ls assets/fonts/Cairo-Regular.ttf

# أعد التشغيل
flutter clean
flutter pub get
flutter run
```

---

### المشكلة 3: الكليشة لا تظهر

**الأعراض:**
- PDF فارغ أو بدون كليشة

**الحل:**
```dart
// تحقق من console logs
// ابحث عن:
// ✅ تم تحميل خط Cairo بنجاح
// ⚠️ فشل تحميل خط Cairo
// ⚠️ تعذر تحميل الشعار
```

---

### المشكلة 4: خطأ في التحميل

**الأعراض:**
```
Error: Unable to load asset
```

**الحل:**
```yaml
# تحقق من pubspec.yaml
flutter:
  assets:
    - images/
    - assets/fonts/
```

---

## 🎨 أمثلة

### مثال 1: تقرير طلاب

```dart
final pdfService = PdfExportService(
  schoolName: 'مدرسة النور الابتدائية',
  teacherName: 'أحمد محمد',
  principalName: 'خالد علي',
);

await pdfService.printStudentNamesLog(
  students,
  'الأول أ',
);
```

**النتيجة:**
- كشف أسماء الطلاب
- بالكليشة السعودية الكاملة
- جاهز للطباعة

---

### مثال 2: تقرير حضور

```dart
await pdfService.printDailyAttendanceLog(
  students,
  'الأول أ',
  attendanceRecords: records,
);
```

**النتيجة:**
- كشف الحضور اليومي
- مع علامات الحضور/الغياب
- بالكليشة الرسمية

---

### مثال 3: تقرير سلوك

```dart
await pdfService.printBehaviorLog(
  students,
  'الأول أ',
  records: behaviorRecords,
  filled: true,
);
```

**النتيجة:**
- كشف السلوك والملاحظات
- مع البيانات الفعلية
- بالكليشة الاحترافية

---

## 📚 المراجع

### الملفات التوثيقية:
1. `✅_تم_إصلاح_الكليشة_السعودية_PDF.md` - الشرح التفصيلي
2. `🧪_اختبار_الكليشة_السعودية.md` - دليل الاختبار
3. `📊_مقارنة_قبل_وبعد_الإصلاح.md` - المقارنة الشاملة
4. `🎯_الملخص_التنفيذي_النهائي.md` - الملخص التنفيذي

### الكود:
- `lib/src/features/common/services/pdf_export_service.dart`
- `lib/src/features/schedule/services/pdf_export_service.dart`

---

## 🎯 النصائح

### للمطورين:

1. **استخدم الملفات المحلية:**
   ```dart
   // ✅ جيد
   final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
   
   // ❌ تجنب
   final font = await PdfGoogleFonts.cairoRegular();
   ```

2. **تحقق من الأخطاء:**
   ```dart
   try {
     final logo = await rootBundle.load('images/logo.png');
   } catch (e) {
     print('⚠️ فشل تحميل الشعار: $e');
     // استخدم fallback
   }
   ```

3. **وثق كل شيء:**
   ```dart
   /// Builds the official Saudi header for PDF reports
   /// 
   /// Parameters:
   /// - [title]: Report title
   /// - [className]: Class name
   /// - [semester]: Semester name
   /// - [grade]: Grade level
   /// - [schoolName]: School name
   Future<pw.Widget> _buildOfficialHeader(...) async {
     // ...
   }
   ```

---

### للمستخدمين:

1. **اختبر قبل الطباعة:**
   - افتح PDF
   - تحقق من الكليشة
   - تأكد من البيانات

2. **احفظ نسخة احتياطية:**
   - احفظ PDF
   - قبل الطباعة
   - للرجوع إليه

3. **أبلغ عن المشاكل:**
   - إذا وجدت خطأ
   - أبلغ فوراً
   - مع لقطة شاشة

---

## ✅ قائمة التحقق

قبل استخدام الكليشة، تأكد من:

- [ ] الخط موجود في `assets/fonts/Cairo-Regular.ttf`
- [ ] الشعار موجود في `images/logokshuf.webp`
- [ ] `pubspec.yaml` محدث
- [ ] تم تنفيذ `flutter pub get`
- [ ] لا توجد أخطاء في الكود
- [ ] تم اختبار التقرير

---

## 🎉 الخلاصة

الكليشة السعودية الآن:
- ✅ احترافية 100%
- ✅ سهلة الاستخدام
- ✅ قابلة للتخصيص
- ✅ موثوقة تماماً

---

**استمتع بالتقارير الاحترافية! 🎊**
