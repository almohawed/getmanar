# 🔧 حل مشكلة التعليق على شاشة التحميل

## 🐛 المشكلة:
الموقع معلق على شاشة التحميل ولا يفتح التطبيق.

---

## ✅ الحلول:

### الحل 1️⃣: تحديث index.html (الأكثر شيوعاً)

**الملف:** `web/index.html`

ابحث عن هذا السطر:
```html
<script src="flutter.js" defer></script>
```

واستبدله بـ:
```html
<script>
  window.addEventListener('load', function(ev) {
    _flutter.loader.loadEntrypoint({
      serviceWorker: {
        serviceWorkerVersion: serviceWorkerVersion,
      },
      onEntrypointLoaded: function(engineInitializer) {
        engineInitializer.initializeEngine().then(function(appRunner) {
          appRunner.runApp();
        });
      }
    });
  });
</script>
```

---

### الحل 2️⃣: تعطيل CanvasKit

**الأمر:**
```bash
flutter build web --release --web-renderer html
```

بدلاً من:
```bash
flutter build web --release
```

---

### الحل 3️⃣: تحديث firebase.json

**الملف:** `firebase.json`

تأكد من وجود:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|woff2|woff|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

---

### الحل 4️⃣: مسح الكاش

**الأوامر:**
```bash
# 1. مسح كاش Flutter
flutter clean

# 2. مسح كاش Firebase
firebase hosting:channel:delete preview

# 3. إعادة البناء
flutter build web --release --web-renderer html

# 4. إعادة النشر
firebase deploy --only hosting
```

---

### الحل 5️⃣: تحديث pubspec.yaml

تأكد من عدم وجود مشاكل في المكتبات:

```bash
flutter pub get
flutter pub upgrade
flutter clean
flutter build web --release
```

---

## 🚀 الحل السريع (جرب هذا أولاً):

```bash
# 1. تنظيف
flutter clean

# 2. بناء بـ HTML renderer
flutter build web --release --web-renderer html

# 3. النشر
firebase deploy --only hosting
```

---

## 🔍 التشخيص:

افتح Console في المتصفح (F12) وشاهد الأخطاء:

1. اضغط F12
2. اذهب إلى Console
3. أعد تحميل الصفحة
4. شاهد الأخطاء

الأخطاء الشائعة:
- `Failed to load wasm`
- `CanvasKit initialization failed`
- `Service worker error`

---

## 📝 ملاحظات:

- استخدم `--web-renderer html` بدلاً من `canvaskit` للتوافق الأفضل
- تأكد من أن Firebase Hosting مفعّل
- تأكد من أن الملفات في `build/web` موجودة

---

**جرب الحل السريع أولاً، ثم أخبرني بالنتيجة!** 🚀
