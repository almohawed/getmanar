# 🔗 ربط Flutter App بـ Backend V2

## ✅ Backend جاهز ويعمل

**URL:** https://schedule-solver-979291699789.us-central1.run.app

---

## 📝 الخطوات

### 1. ابحث عن ملف API configuration

ابحث في مشروع Flutter عن ملف يحتوي على base URL، مثل:
- `lib/config/api_config.dart`
- `lib/services/api_service.dart`
- `lib/constants/api_constants.dart`

أو ابحث عن النص:
```
baseUrl
```

### 2. غير الـ URL

غير من:
```dart
static const String baseUrl = 'OLD_URL';
```

إلى:
```dart
static const String baseUrl = 'https://schedule-solver-979291699789.us-central1.run.app/api/v2';
```

### 3. تأكد من الـ endpoints

Backend V2 يستخدم:
- `POST /generate` (بدلاً من `/generate_schedule`)
- `POST /precheck`
- `GET /health`

---

## 🔍 إذا لم تجد ملف API config

ابحث في الكود عن:
```
schedule-solver
```
أو
```
us-central1.run.app
```

---

## 🧪 اختبار

بعد التغيير:
1. أعد تشغيل Flutter app
2. اضغط "توليد الجدول"
3. تحقق من النتائج

---

## 📊 API Endpoints الجديدة

**Base URL:**
```
https://schedule-solver-979291699789.us-central1.run.app/api/v2
```

**Endpoints:**
- `GET /health` - فحص الخدمة
- `POST /precheck` - فحص البيانات
- `POST /generate` - توليد الجدول

---

## ✅ بعد الربط

Backend V2 سيوفر:
- ✅ توليد أسرع (~0.2 ثانية)
- ✅ جداول كاملة بدون تعارضات
- ✅ OR-Tools CP-SAT حقيقي
- ✅ Precheck قبل التوليد
- ✅ Diagnostics واضحة

---

هل تريد مساعدة في إيجاد ملف API config في Flutter؟
