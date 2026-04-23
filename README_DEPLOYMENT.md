# 🚀 نظام الجدولة الذكي V2 - دليل النشر السريع

## 📌 نظرة سريعة

نظام جدولة مدرسية ذكي يستخدم Google OR-Tools لتوليد جداول مثالية في أقل من 30 ثانية.

### المميزات الرئيسية:
- ✅ **Precheck**: فحص الجاهزية قبل التوليد
- ✅ **Hard Constraints**: قيود صلبة لا تُكسر أبداً
- ✅ **Soft Constraints**: قيود مرنة مع أوزان
- ✅ **Manual Constraints**: قيود يدوية من Firebase
- ✅ **Repair Mode**: إعادة المحاولة التلقائية
- ✅ **Multi-School Support**: دعم جميع أنواع المدارس

---

## 🎯 البدء السريع (10 دقائق)

### 1. نشر Backend على Railway

```bash
# 1. اذهب إلى https://railway.app
# 2. سجل دخول بـ GitHub
# 3. New Project → Deploy from GitHub
# 4. اختر backend_v2
# 5. أضف متغير: FIREBASE_CREDENTIALS
# 6. احفظ URL
```

### 2. تحديث Flutter

```dart
// lib/src/features/ortools_v2/data/schedule_api_v2.dart
static const String baseUrl = 'https://your-backend-url/api/v2';
```

### 3. نشر Flutter

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 📚 الوثائق الكاملة

### للمبتدئين:
1. **[QUICK_START_AR.md](QUICK_START_AR.md)** - البدء السريع
2. **[RAILWAY_DEPLOYMENT_STEPS_AR.md](RAILWAY_DEPLOYMENT_STEPS_AR.md)** - خطوات Railway مصورة
3. **[DEPLOYMENT_CHECKLIST_AR.md](DEPLOYMENT_CHECKLIST_AR.md)** - قائمة التحقق

### للمحترفين:
1. **[DEPLOYMENT_GUIDE_AR.md](DEPLOYMENT_GUIDE_AR.md)** - دليل النشر الكامل
2. **[backend_v2/README.md](backend_v2/README.md)** - وثائق Backend
3. **[✅_النظام_جاهز_للنشر.md](✅_النظام_جاهز_للنشر.md)** - ملخص الإنجاز

---

## 🏗️ البنية التقنية

### Backend (Python + FastAPI + OR-Tools)
```
backend_v2/
├── app/
│   ├── main.py              # FastAPI app
│   ├── api/routes.py        # API endpoints
│   ├── services/
│   │   ├── precheck_service.py
│   │   ├── solver_service.py
│   │   └── firebase_service.py
│   ├── solver/
│   │   └── cp_model_builder.py
│   └── models/
│       ├── school.py
│       └── schedule.py
├── requirements.txt
├── Dockerfile
└── railway.json
```

### Frontend (Flutter + Riverpod + GoRouter)
```
lib/src/features/ortools_v2/
├── presentation/
│   └── ortools_v2_screen.dart
├── data/
│   └── schedule_api_v2.dart
└── domain/
    └── schedule_models_v2.dart
```

---

## 🔌 API Endpoints

### GET /
```json
{
  "message": "School Schedule Generator API v2",
  "version": "2.0.0",
  "status": "production"
}
```

### POST /api/v2/precheck
```json
Request: {
  "school_id": "school123",
  "school_type": "middle",
  "classes": [...],
  "teachers": [...],
  "subjects": [...]
}

Response: {
  "can_generate": true,
  "issues": [],
  "warnings": [],
  "summary": {...}
}
```

### POST /api/v2/generate_schedule
```json
Request: <same as precheck>

Response: {
  "success": true,
  "schedule": {...},
  "stats": {...},
  "diagnostics": {...}
}
```

---

## 📊 الأداء

| المقياس | القيمة |
|---------|--------|
| وقت التوليد | 0.1-0.5 ثانية |
| معدل النجاح | 99%+ |
| السعة | 50+ فصل، 100+ معلم |
| الحد الأقصى | 30 ثانية |

---

## 💰 التكلفة

### Free Tier (كافي للبداية):
- **Railway**: 500 ساعة/شهر، 512 MB RAM
- **Firebase Hosting**: 10 GB تخزين، 360 MB/يوم
- **التكلفة**: $0/شهر

### Pro (للتوسع):
- **Railway Pro**: $5/شهر
- **Firebase Blaze**: Pay as you go
- **التكلفة**: ~$10-20/شهر

---

## 🧪 الاختبار

### اختبار Backend محلياً:
```bash
cd backend_v2
pip install -r requirements.txt
python -m app.main
# Server: http://localhost:8000
```

### اختبار النظام:
```bash
python backend_v2/test_system.py
# Expected: 70/70 lessons (100%) in ~0.14s
```

### اختبار Flutter محلياً:
```bash
flutter run -d chrome
# Navigate to /ortools-v2
```

---

## 🐛 استكشاف الأخطاء

### Backend لا يعمل؟
```bash
# تحقق من logs
railway logs

# تحقق من environment variables
railway variables

# أعد النشر
railway up
```

### Flutter لا يتصل؟
```dart
// تحقق من baseUrl
print(ScheduleApiV2.baseUrl);

// تحقق من CORS
// Backend يسمح بـ allow_origins=["*"]
```

### التوليد يفشل؟
```
1. شغل Precheck أولاً
2. اقرأ تقرير Precheck
3. صحح البيانات (معلمين، حصص، إلخ)
4. حاول مرة أخرى
```

---

## 🔐 الأمان

### Best Practices:
- ✅ استخدم Environment Variables للـ credentials
- ✅ لا تشارك serviceAccountKey.json
- ✅ فعّل HTTPS (تلقائي في Railway)
- ✅ راجع Firestore Rules
- ✅ فعّل 2FA على GitHub

---

## 📞 الدعم

### الوثائق:
- [Quick Start](QUICK_START_AR.md)
- [Deployment Guide](DEPLOYMENT_GUIDE_AR.md)
- [Railway Steps](RAILWAY_DEPLOYMENT_STEPS_AR.md)
- [Checklist](DEPLOYMENT_CHECKLIST_AR.md)

### الروابط:
- Railway: https://railway.app
- Firebase: https://console.firebase.google.com
- OR-Tools: https://developers.google.com/optimization

### المجتمع:
- Railway Discord: https://discord.gg/railway
- Firebase Support: https://firebase.google.com/support
- Flutter Community: https://flutter.dev/community

---

## 🎯 الخطوات التالية

### بعد النشر:
1. ✅ اختبر مع بيانات حقيقية
2. ✅ راقب الأداء والأخطاء
3. ✅ اجمع feedback من المستخدمين
4. ✅ حسّن الخوارزميات
5. ✅ أضف مميزات جديدة

### التطوير المستقبلي:
- ⏳ دعم المزيد من أنواع المدارس
- ⏳ تقارير متقدمة
- ⏳ تكامل مع أنظمة أخرى
- ⏳ تطبيق موبايل
- ⏳ AI-powered optimization

---

## 🏆 الإنجازات

### ما تم:
✅ نظام backend_v2 كامل
✅ واجهة Flutter متكاملة
✅ ملفات النشر جاهزة
✅ الوثائق كاملة
✅ الاختبارات ناجحة

### النتيجة:
🚀 نظام جدولة ذكي احترافي
⚡ توليد في أقل من 30 ثانية
🎯 دقة 99%+ مع بيانات صحيحة
💰 تكلفة صفر (Free Tier)

---

## 📄 الترخيص

Private - School Management System

---

## 🎉 شكراً!

نظام الجدولة الذكي V2 جاهز للاستخدام!

**ابدأ الآن**: [QUICK_START_AR.md](QUICK_START_AR.md)

---

**الإصدار**: 2.0.0 Production  
**التاريخ**: 20 مارس 2026  
**الحالة**: ✅ جاهز للنشر
