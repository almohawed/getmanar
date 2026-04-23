import requests
import json

# قراءة البيانات
with open('test_request.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# إرسال الطلب
print("=" * 50)
print("  اختبار توليد الجدول")
print("=" * 50)
print()

try:
    response = requests.post(
        'http://127.0.0.1:8080/api/v2/generate',
        json=data,
        timeout=60
    )
    
    result = response.json()
    
    print(f"Success: {result.get('success')}")
    print(f"Message: {result.get('message')}")
    print()
    
    diagnostics = result.get('diagnostics', {})
    print(f"Solver Status: {diagnostics.get('solverStatus')}")
    print(f"Total Lessons Placed: {diagnostics.get('totalLessonsPlaced')}")
    print(f"Execution Time: {diagnostics.get('executionTimeSeconds'):.2f} seconds")
    print()
    
    if result.get('success'):
        print("✅ الجدول تم توليده بنجاح!")
        print()
        print(f"عدد الحصص: {len(result.get('lessons', []))}")
        print(f"عدد جداول الفصول: {len(result.get('classSchedules', []))}")
        print(f"عدد جداول المعلمين: {len(result.get('teacherSchedules', []))}")
        print()
        
        # عرض عينة من الحصص
        lessons = result.get('lessons', [])
        if lessons:
            print("عينة من الحصص الأولى:")
            for lesson in lessons[:5]:
                print(f"  - {lesson['dayName']} الحصة {lesson['period']}: {lesson['subjectId']} (معلم: {lesson['teacherId']})")
    else:
        print("❌ فشل التوليد")
        issues = result.get('precheckReport', {}).get('issues', [])
        if issues:
            print("\nالمشاكل:")
            for issue in issues:
                print(f"  - {issue.get('message')}")
    
    print()
    print("=" * 50)
    
except requests.exceptions.ConnectionError:
    print("❌ خطأ: لا يمكن الاتصال بالخادم")
    print("تأكد من أن الخادم يعمل على http://127.0.0.1:8080")
except Exception as e:
    print(f"❌ خطأ: {e}")
