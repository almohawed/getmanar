# 🔧 إصلاح مشكلة Precheck

## المشكلة
Backend V2 كان يرفض البيانات إذا لم يكن مجموع الحصص = 35 حصة بالضبط (5 أيام × 7 حصص)

## الإصلاح
تم تعديل `precheck_service.py` ليكون أكثر مرونة:
- ✅ يسمح بأقل من 35 حصة (تحذير فقط)
- ✅ يرفض فقط إذا تجاوز 35 حصة (خطأ)
- ✅ لا يتحقق من مواد المعلم إذا كانت القائمة فارغة

## النشر

### من Cloud Shell
```bash
cd ~/almadrasah/backend_v2
gcloud run deploy schedule-solver \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --timeout 300 \
  --memory 2Gi \
  --cpu 2
```

### من Windows (إذا كان gcloud مثبت)
```powershell
cd C:\Users\asus\my\almadrasah\backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated --timeout 300 --memory 2Gi --cpu 2
```

## البديل: استخدام Cloud Shell Editor
1. افتح: https://console.cloud.google.com/cloudshell/editor
2. ارفع ملف `precheck_service.py` المحدث
3. نفذ الأمر أعلاه

## الاختبار بعد النشر
```bash
# اختبار Health
curl https://schedule-solver-979291699789.us-central1.run.app/api/v2/health

# اختبار Precheck (من Python)
python backend_v2/test_system.py
```

## التغييرات في الكود

### قبل:
```python
if demand != class_capacity:
    issues.append(PrecheckIssue(
        code="CLASS_CAPACITY_MISMATCH",
        message=f"الفصل {class_id} يحتاج {demand} حصة أسبوعيًا بينما السعة المتاحة {class_capacity}",
        meta={"classId": class_id, "demand": demand, "capacity": class_capacity},
    ))
```

### بعد:
```python
if demand > class_capacity:
    issues.append(PrecheckIssue(
        code="CLASS_CAPACITY_EXCEEDED",
        message=f"الفصل {class_id} يحتاج {demand} حصة أسبوعيًا ويتجاوز السعة المتاحة {class_capacity}",
        severity="error",
        meta={"classId": class_id, "demand": demand, "capacity": class_capacity},
    ))
elif demand < class_capacity:
    issues.append(PrecheckIssue(
        code="CLASS_CAPACITY_UNDERUSED",
        message=f"الفصل {class_id} يحتاج {demand} حصة فقط من أصل {class_capacity} متاحة",
        severity="warning",
        meta={"classId": class_id, "demand": demand, "capacity": class_capacity},
    ))
```

---

**ملاحظة**: بعد النشر، Flutter سيعمل تلقائياً لأنه يستخدم نفس الـ URL
