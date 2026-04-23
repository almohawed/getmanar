# 🚀 نشر التطبيق على Firebase Hosting

## 🎯 الهدف:
رفع التطبيق على: `https://etisak-784d6.web.app/`

---

## 📋 المتطلبات:

- ✅ Node.js مثبت
- ✅ Firebase CLI مثبت
- ✅ حساب Firebase
- ✅ المشروع متصل بـ Firebase

---

## 🚀 الخطوات:

### الخطوة 1️⃣: التحقق من Firebase CLI

```bash
firebase --version
```

إذا لم يكن مثبتاً:
```bash
npm install -g firebase-tools
```

---

### الخطوة 2️⃣: تسجيل الدخول إلى Firebase

```bash
firebase login
```

سيفتح متصفح لتسجيل الدخول. اختر الحساب المرتبط بـ `etisak-784d6`

---

### الخطوة 3️⃣: بناء التطبيق للويب

```bash
flutter build web --release
```

**النتيجة:** سيتم إنشاء مجلد `build/web/`

---

### الخطوة 4️⃣: تهيئة Firebase Hosting

```bash
firebase init hosting
```

**الخيارات:**
- What do you want to use as your public directory? → `build/web`
- Configure as a single-page app? → `y` (نعم)
- Set up automatic builds and deploys? → `n` (لا)

---

### الخطوة 5️⃣: النشر على Firebase

```bash
firebase deploy --only hosting
```

---

## ✅ النتيجة:

بعد النشر ستحصل على:
```
✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/etisak-784d6/overview
Hosting URL: https://etisak-784d6.web.app
```

---

## 🔗 الرابط النهائي:

```
https://etisak-784d6.web.app/
```

---

## 🐛 حل المشاكل:

### المشكلة: "firebase: command not found"
```bash
# الحل:
npm install -g firebase-tools
```

### المشكلة: "Permission denied"
```bash
# الحل:
firebase login --reauth
```

### المشكلة: "build/web not found"
```bash
# الحل:
flutter clean
flutter pub get
flutter build web --release
```

### المشكلة: "Project not found"
```bash
# الحل:
firebase use etisak-784d6
```

---

## 📊 الملفات المنشورة:

```
build/web/
├── index.html
├── main.dart.js
├── assets/
├── canvaskit/
└── ...
```

---

## 🔄 التحديثات المستقبلية:

لتحديث التطبيق:

```bash
# 1. تحديث الكود
git add .
git commit -m "Update"
git push

# 2. بناء الويب
flutter build web --release

# 3. النشر
firebase deploy --only hosting
```

---

## 📱 اختبار التطبيق:

1. اذهب إلى: `https://etisak-784d6.web.app/`
2. اختبر جميع الميزات
3. تأكد من عمل الأزرار الثلاثة (عرض | تعديل | حذف)

---

## 🎊 تم النشر بنجاح!

**الرابط:** `https://etisak-784d6.web.app/`

---

**شكراً! 🙏**
