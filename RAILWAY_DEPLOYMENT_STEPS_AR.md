# 🚂 خطوات النشر على Railway - مصورة

## لماذا Railway؟

- ✅ مجاني (500 ساعة/شهر)
- ✅ سهل الاستخدام
- ✅ نشر تلقائي من GitHub
- ✅ Logs في الوقت الفعلي
- ✅ لا يحتاج بطاقة ائتمان

---

## الخطوة 1: إنشاء حساب

### 1.1 اذهب إلى Railway
```
https://railway.app
```

### 1.2 سجل دخول
- اضغط "Login"
- اختر "Login with GitHub"
- وافق على الصلاحيات

---

## الخطوة 2: إنشاء مشروع جديد

### 2.1 إنشاء Project
```
1. اضغط "New Project"
2. اختر "Deploy from GitHub repo"
3. إذا لم يظهر repo الخاص بك:
   - اضغط "Configure GitHub App"
   - اختر repository
   - احفظ
```

### 2.2 اختيار Repository
```
1. ابحث عن repository الخاص بك
2. اضغط عليه
3. انتظر التحميل
```

### 2.3 اختيار المجلد
```
Railway سيكتشف تلقائياً:
- Python project
- requirements.txt
- nixpacks.toml

إذا لم يكتشف:
1. Settings → Root Directory
2. اكتب: backend_v2
3. احفظ
```

---

## الخطوة 3: إضافة متغيرات البيئة

### 3.1 فتح Settings
```
1. اضغط على service الخاص بك
2. اضغط "Variables"
3. اضغط "New Variable"
```

### 3.2 إضافة FIREBASE_CREDENTIALS

#### الطريقة 1: من الملف
```bash
# في terminal:
cd backend_v2
cat serviceAccountKey.json
```

انسخ المحتوى كاملاً (من { إلى })

#### الطريقة 2: من Firebase Console
```
1. اذهب إلى Firebase Console
2. Project Settings → Service Accounts
3. Generate New Private Key
4. افتح الملف وانسخ المحتوى
```

### 3.3 لصق المحتوى
```
Variable Name: FIREBASE_CREDENTIALS
Variable Value: <الصق المحتوى هنا>

مثال:
{
  "type": "service_account",
  "project_id": "etisak-784d6",
  "private_key_id": "...",
  "private_key": "...",
  ...
}
```

اضغط "Add"

---

## الخطوة 4: النشر

### 4.1 النشر التلقائي
```
Railway سينشر تلقائياً بعد:
1. إضافة المتغيرات
2. اكتشاف التغييرات في GitHub

شاهد Logs:
- Deployments → Latest
- Build Logs
- Deploy Logs
```

### 4.2 التحقق من النشر
```
انتظر حتى ترى:
✅ Build successful
✅ Deploy successful

عادة يستغرق: 2-3 دقائق
```

---

## الخطوة 5: الحصول على URL

### 5.1 إنشاء Domain
```
1. Settings → Networking
2. اضغط "Generate Domain"
3. سيظهر URL مثل:
   https://backend-v2-production-xxxx.up.railway.app
```

### 5.2 حفظ URL
```
انسخ URL واحفظه
ستحتاجه في الخطوة التالية
```

---

## الخطوة 6: اختبار Backend

### 6.1 اختبار Health Check
```
افتح في المتصفح:
https://your-backend-url.railway.app/

يجب أن ترى:
{
  "message": "School Schedule Generator API v2",
  "version": "2.0.0",
  "status": "production"
}
```

### 6.2 اختبار API
```
https://your-backend-url.railway.app/api/v2/health

يجب أن ترى:
{
  "status": "healthy",
  "timestamp": "..."
}
```

---

## الخطوة 7: تحديث Flutter

### 7.1 فتح الملف
```
lib/src/features/ortools_v2/data/schedule_api_v2.dart
```

### 7.2 تحديث URL
```dart
// قبل:
static const String baseUrl = 'http://localhost:8000/api/v2';

// بعد:
static const String baseUrl = 'https://your-backend-url.railway.app/api/v2';
```

احفظ الملف

---

## الخطوة 8: نشر Flutter

### 8.1 بناء Flutter
```bash
flutter clean
flutter pub get
flutter build web --release
```

### 8.2 نشر على Firebase
```bash
firebase deploy --only hosting
```

أو استخدم:
```bash
deploy.bat
```

---

## الخطوة 9: الاختبار النهائي

### 9.1 فتح التطبيق
```
https://etisak-784d6.web.app/
```

### 9.2 تسجيل الدخول
```
سجل دخول كمدير
```

### 9.3 الوصول للنظام
```
1. الشؤون الأكاديمية
2. "الجدول الذكي V2 (Production)" 🚀
3. جرب Precheck
4. جرب Generate
```

---

## 🎉 تهانينا!

النظام الآن منشور ويعمل! 🚀

---

## 🔧 إعدادات إضافية (اختيارية)

### تفعيل Auto-Deploy
```
Settings → GitHub
✅ Enable Auto-Deploy
```

الآن كل push إلى GitHub سينشر تلقائياً!

### إضافة Custom Domain
```
Settings → Networking
Add Custom Domain
أدخل domain الخاص بك
```

### مراقبة الأداء
```
Metrics → View
- CPU Usage
- Memory Usage
- Network Traffic
```

### عرض Logs
```
Deployments → Latest → Logs
- Build Logs
- Deploy Logs
- Runtime Logs
```

---

## 🐛 استكشاف الأخطاء

### Build Failed؟
```
1. تحقق من Build Logs
2. تأكد من requirements.txt صحيح
3. تأكد من Python version (3.11)
```

### Deploy Failed؟
```
1. تحقق من Deploy Logs
2. تأكد من FIREBASE_CREDENTIALS صحيح
3. تأكد من PORT variable (تلقائي)
```

### Backend لا يستجيب؟
```
1. تحقق من Runtime Logs
2. تحقق من Health Check
3. أعد النشر:
   Deployments → Redeploy
```

---

## 💡 نصائح

### للأداء الأفضل:
- استخدم Railway Pro ($5/شهر)
- فعّل Auto-Deploy
- راقب Metrics بانتظام

### للأمان:
- لا تشارك FIREBASE_CREDENTIALS
- استخدم Environment Variables
- فعّل GitHub 2FA

### للصيانة:
- راجع Logs يومياً
- راقب Memory Usage
- احفظ نسخة احتياطية

---

## 📞 الدعم

### Railway Support:
- Discord: https://discord.gg/railway
- Docs: https://docs.railway.app
- Status: https://status.railway.app

### مشاكل شائعة:
- Build timeout: زد timeout في Settings
- Memory limit: ترقى إلى Pro
- Deploy failed: تحقق من Logs

---

## 🎯 الخلاصة

### ما تم:
✅ إنشاء حساب Railway
✅ نشر Backend
✅ إضافة Environment Variables
✅ الحصول على URL
✅ تحديث Flutter
✅ نشر Flutter
✅ اختبار النظام

### النتيجة:
🚀 Backend منشور على Railway
🌐 Flutter منشور على Firebase
✅ النظام يعمل بنجاح

---

**وقت الإنجاز**: 10 دقائق
**التكلفة**: مجاني
**الحالة**: ✅ جاهز للاستخدام
