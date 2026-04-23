# 🚀 دليل تشغيل نظام الجدولة الذكي

## نظرة عامة

نظام متكامل لتوليد الجداول المدرسية باستخدام:
- **Python + Google OR-Tools**: محرك الجدولة
- **FastAPI**: API Backend
- **Flutter**: واجهة المستخدم
- **Firebase**: قاعدة البيانات والمصادقة

## ⚡ التشغيل السريع

### 1. Backend Setup

```bash
cd backend
pip install -r requirements.txt
python main.py
```

### 2. Flutter Setup

أضف في `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

ثم:
```bash
flutter pub get
```

### 3. إضافة المسار في Router

في `lib/src/core/router.dart`:
```dart
GoRoute(
  path: '/ortools-schedule',
  builder: (context, state) => const ORToolsScheduleScreen(),
),
```

### 4. إضافة زر في Dashboard

```dart
ElevatedButton.icon(
  onPressed: () => context.go('/ortools-schedule'),
  icon: Icon(Icons.auto_awesome),
  label: Text('الجدول الذكي'),
)
```

## 🔧 الإعدادات

### تغيير رابط API

في `lib/src/features/ortools_schedule/data/schedule_api_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000';
```

### Firebase Credentials

ضع ملف `serviceAccountKey.json` في مجلد `backend/`

## 📊 كيف يعمل النظام

1. **المستخدم يضغط "توليد الجدول"**
2. **Flutter يجمع البيانات** من Firestore (معلمين، فصول)
3. **يرسل طلب POST** إلى `/generate_schedule`
4. **Python + OR-Tools يحل المشكلة** (أقل من 30 ثانية)
5. **يحفظ النتيجة** في Firebase
6. **يوزع الجدول** على الطلاب والمعلمين
7. **Flutter يعرض الجدول** مباشرة

## ✅ المميزات

- ✨ توليد كامل في ثوانٍ
- 🚫 بدون تعارضات (مضمون رياضياً)
- 📱 توزيع تلقائي للطلاب والمعلمين
- 🎨 واجهة احترافية
- ⚡ سريع جداً (OR-Tools محسّن)
- 🔒 آمن (Firebase Auth)

## 🎯 القيود المطبقة

1. ✅ 7 حصص يومياً
2. ✅ 5 أيام (الأحد - الخميس)
3. ✅ لا حصص فارغة
4. ✅ لا تكرار مادة في نفس اليوم
5. ✅ لا تعارض معلمين
6. ✅ احترام نصاب المعلم
7. ✅ المعلم يدرس فقط فصوله المسندة
8. ✅ عدد الحصص حسب الخطة الدراسية

## 🚀 Deploy على Production

### Backend (Railway / Render / Heroku)

```bash
# Procfile
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

### Flutter Web

```bash
flutter build web --release
firebase deploy --only hosting
```

## 📝 ملاحظات مهمة

- OR-Tools يحتاج Python 3.8+
- الحد الأقصى للوقت: 30 ثانية
- يستخدم 8 threads للمعالجة
- النتائج مضمونة رياضياً (OPTIMAL أو FEASIBLE)

## 🆘 حل المشاكل

### Backend لا يعمل
```bash
pip install --upgrade ortools
```

### Flutter لا يتصل بالـ API
- تأكد من تشغيل Backend
- تحقق من رابط API في `schedule_api_service.dart`
- تأكد من CORS مفعّل

### الجدول غير مكتمل
- تحقق من عدد المعلمين
- تأكد من إسناد المواد للمعلمين
- راجع الخطة الدراسية

## 📞 الدعم

إذا واجهت مشكلة، تحقق من:
1. Logs في Backend
2. Console في Flutter
3. Firebase Console
