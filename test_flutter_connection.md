# ✅ تم ربط Flutter بـ Backend V2

## التحديثات المنفذة

### 1. تحديث URL الأساسي
```dart
// lib/src/features/schedule/services/schedule_config.dart
static const String ORTOOLS_BACKEND_URL = 
  'https://schedule-solver-979291699789.us-central1.run.app/api/v2';
```

### 2. تحديث Endpoints
- من: `/api/v2/simple_generate` → إلى: `/generate`
- من: `/generate_schedule` → إلى: `/generate`
- Precheck: `/precheck` ✓
- Health: `/health` ✓

### 3. تحديث تنسيق البيانات
تم تحديث البيانات المرسلة لتتطابق مع Backend V2:

```dart
{
  'schoolId': schoolId,
  'schoolType': 'middle',
  'classes': [
    {
      'id': 'class1',
      'name': 'الصف الأول',
      'grade': '1',
      'track': null
    }
  ],
  'teachers': [
    {
      'id': 't1',
      'name': 'معلم 1',
      'subjects': ['math'],
      'maxWeeklyLoad': 24
    }
  ],
  'assignments': [
    {
      'teacherId': 't1',
      'classId': 'class1',
      'subjectId': 'math',
      'subjectName': 'رياضيات',
      'weeklyHours': 5,
      'allowDouble': false
    }
  ],
  'manualConstraints': [],
  'saveToFirebase': true
}
```

### 4. تحديث معالجة الاستجابة
الآن Flutter يستقبل:
- `success`: حالة النجاح
- `message`: رسالة النتيجة
- `diagnostics`: معلومات التشخيص (solverStatus, executionTime, totalLessonsPlaced)
- `precheckReport`: تقرير الفحص المسبق
- `classSchedules`: جداول الفصول
- `teacherSchedules`: جداول المعلمين
- `lessons`: قائمة الحصص
- `scheduleId`: معرف الجدول في Firebase

## الملفات المحدثة
1. ✅ `lib/src/features/schedule/services/schedule_config.dart`
2. ✅ `lib/src/features/schedule/services/ortools_schedule_service.dart`
3. ✅ `lib/src/features/ortools_schedule/data/schedule_api_service.dart`
4. ✅ `lib/src/features/ortools_v2/data/schedule_api_v2.dart`

## خطوات الاختبار

### 1. اختبار الاتصال
```bash
# من المتصفح أو Postman
https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
```

يجب أن تحصل على:
```json
{
  "status": "healthy",
  "name": "School Schedule Solver V2",
  "version": "2.0.0"
}
```

### 2. اختبار من Flutter
1. شغّل التطبيق
2. اذهب إلى شاشة توليد الجدول
3. اضغط "توليد الجدول"
4. راقب Console logs:
   ```
   🚀 Using OR-Tools API: https://schedule-solver-979291699789.us-central1.run.app/api/v2
   📊 Data: X classes, Y teachers, Z subjects, W assignments
   📤 Sending request to Backend V2...
   📡 Response status: 200
   ✅ Backend V2 succeeded!
   ```

### 3. التحقق من النتائج
- يجب أن يظهر الجدول بدون تعارضات
- يجب أن تكون جميع الحصص موزعة
- يجب حفظ الجدول في Firebase تلقائياً

## المميزات الجديدة
- ✅ استخدام OR-Tools CP-SAT الحقيقي
- ✅ Precheck قبل التوليد
- ✅ Diagnostics واضحة
- ✅ توليد أسرع (~0.2 ثانية)
- ✅ ضمان عدم التعارضات
- ✅ حفظ تلقائي في Firebase

## ملاحظات مهمة
- Backend V2 يضمن الالتزام بالقيود إذا كانت البيانات قابلة للجدولة
- إذا كانت البيانات غير قابلة للجدولة، سيعيد `success: false` مع تقرير تفصيلي
- Timeout: 120 ثانية (كافي لمعظم الحالات)
