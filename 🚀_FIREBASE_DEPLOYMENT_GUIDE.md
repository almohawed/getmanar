# 🚀 دليل النشر على Firebase Hosting

## 🎯 الهدف:
نشر التطبيق على: **https://etisak-784d6.web.app/**

---

## ⚡ الخطوات السريعة (10 دقائق):

### 1️⃣ تثبيت Firebase CLI:
```bash
npm install -g firebase-tools
```

### 2️⃣ تسجيل الدخول:
```bash
firebase login
```

### 3️⃣ بناء التطبيق:
```bash
flutter build web --release
```

### 4️⃣ تهيئة Firebase:
```bash
firebase init hosting
```

**الخيارات:**
- Public directory: `build/web`
- Single-page app: `y`
- Automatic builds: `n`

### 5️⃣ النشر:
```bash
firebase deploy --only hosting
```

---

## ✅ النتيجة:

```
✔ Deploy complete!

Hosting URL: https://etisak-784d6.web.app
```

---

## 🔗 الرابط النهائي:

```
https://etisak-784d6.web.app/
```

---

## 📋 الملفات المحدثة:

✅ `active_plans_screen.dart` - قائمة الخطط مع 3 أزرار  
✅ `plan_edit_screen.dart` - شاشة التعديل مع حذف  
✅ `plan_details_screen.dart` - عرض التفاصيل  

---

## 🎊 الميزات المنشورة:

✨ ثلاث أزرار في قائمة الخطط (عرض | تعديل | حذف)  
✨ شاشة تعديل احترافية  
✨ حذف مع تأكيد  
✨ معالجة أخطاء شاملة  

---

## 🐛 حل المشاكل:

### "firebase: command not found"
```bash
npm install -g firebase-tools
```

### "Permission denied"
```bash
firebase login --reauth
```

### "build/web not found"
```bash
flutter clean
flutter pub get
flutter build web --release
```

---

## 📱 الاختبار:

1. اذهب إلى: `https://etisak-784d6.web.app/`
2. اختبر الأزرار الثلاثة
3. تأكد من عمل الحذف والتعديل

---

## 🔄 التحديثات المستقبلية:

```bash
# 1. تحديث الكود
git add .
git commit -m "Update"

# 2. بناء الويب
flutter build web --release

# 3. النشر
firebase deploy --only hosting
```

---

## 🎉 تم النشر بنجاح!

**الرابط:** https://etisak-784d6.web.app/

---

**شكراً! 🙏**
