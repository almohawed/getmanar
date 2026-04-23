# نظام الجدولة الذكي - Backend

## التثبيت

```bash
cd backend
pip install -r requirements.txt
```

## إعداد Firebase

1. احصل على ملف `serviceAccountKey.json` من Firebase Console
2. ضعه في مجلد `backend/`

## تشغيل السيرفر

```bash
python main.py
```

السيرفر سيعمل على: `http://localhost:8000`

## API Endpoints

### POST /generate_schedule
توليد جدول مدرسي كامل

**Request Body:**
```json
{
  "schoolId": "school123",
  "schoolType": "primary",
  "teachers": [...],
  "classes": [...],
  "subjectRequirements": {...}
}
```

**Response:**
```json
{
  "success": true,
  "message": "تم توليد الجدول بنجاح",
  "lessons": [...],
  "stats": {...},
  "executionTime": 12.5
}
```

### GET /health
فحص صحة السيرفر

## ملاحظات

- الحد الأقصى للوقت: 30 ثانية
- يستخدم 8 threads للمعالجة المتوازية
- يحفظ النتائج تلقائياً في Firebase
