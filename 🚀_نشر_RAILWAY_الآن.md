# 🚀 نشر OR-Tools على Railway - خطوة بخطوة

## الخطوة 1: إنشاء حساب Railway

1. افتح: **https://railway.app**
2. اضغط **"Login"**
3. اختر **"Login with GitHub"**
4. وافق على الصلاحيات

---

## الخطوة 2: إنشاء مشروع جديد

1. اضغط **"New Project"**
2. اختر **"Deploy from GitHub repo"**
3. ابحث عن repository: **almadrasah** (أو اسم المشروع)
4. اختره

---

## الخطوة 3: تكوين المشروع

### 3.1 تحديد المجلد:
- في **Settings** → **Service**
- ابحث عن **"Root Directory"**
- اكتب: `backend_v2`
- احفظ

### 3.2 إضافة Firebase Credentials:

**الطريقة الأولى (الأسهل):**
1. اذهب إلى Firebase Console: https://console.firebase.google.com
2. اختر مشروعك: **etisak-784d6**
3. اذهب إلى **Project Settings** (⚙️)
4. تبويب **Service Accounts**
5. اضغط **"Generate new private key"**
6. سيتم تنزيل ملف JSON
7. افتح الملف بـ Notepad
8. انسخ المحتوى كاملاً

**في Railway:**
1. اذهب إلى **Variables**
2. اضغط **"New Variable"**
3. **Variable Name**: `FIREBASE_CREDENTIALS`
4. **Value**: الصق محتوى ملف JSON كاملاً
5. اضغط **"Add"**

---

## الخطوة 4: النشر

1. Railway سينشر تلقائياً!
2. انتظر 2-3 دقائق
3. ستظهر رسالة **"Success"** ✅

---

## الخطوة 5: الحصول على URL

1. في صفحة المشروع، اضغط على **Settings**
2. ابحث عن **"Domains"**
3. اضغط **"Generate Domain"**
4. ستحصل على URL مثل:
   ```
   https://backend-v2-production-xxxx.up.railway.app
   ```
5. **انسخ هذا URL** - سنحتاجه!

---

## الخطوة 6: اختبار Backend

افتح في المتصفح:
```
https://your-railway-url.railway.app/api/v2/health
```

يجب أن ترى:
```json
{
  "status": "healthy",
  "version": "2.0.0"
}
```

✅ إذا رأيت هذا، Backend يعمل!

---

## الخطوة 7: أعطني URL

**أرسل لي URL الذي حصلت عليه** وسأكمل الربط بالواجهة!

---

## 🆘 مشاكل شائعة:

### Build فشل؟
- تحقق من أن Root Directory = `backend_v2`
- تحقق من logs في Railway

### FIREBASE_CREDENTIALS خطأ؟
- تأكد من نسخ JSON كاملاً (من { إلى })
- لا تنسى الأقواس!

### لا يوجد Domain؟
- اذهب Settings → Networking
- اضغط "Generate Domain"

---

**جاهز؟** ابدأ من الخطوة 1 وأخبرني عند الوصول للخطوة 7!
