"""
اختبار بسيط للـ API
"""
import requests
import json

BASE_URL = "http://localhost:8000"

def test_health():
    """اختبار صحة السيرفر"""
    response = requests.get(f"{BASE_URL}/health")
    print(f"✅ Health Check: {response.json()}")
    return response.status_code == 200

def test_generate_schedule():
    """اختبار توليد جدول بسيط"""
    
    # بيانات تجريبية
    request_data = {
        "schoolId": "test_school_123",
        "schoolType": "primary",
        "teachers": [
            {
                "id": "t1",
                "name": "أحمد محمد",
                "subjects": ["اللغة العربية", "التربية الإسلامية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24
            },
            {
                "id": "t2",
                "name": "فاطمة علي",
                "subjects": ["الرياضيات", "العلوم"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24
            },
            {
                "id": "t3",
                "name": "خالد سعيد",
                "subjects": ["اللغة الإنجليزية", "الحاسب الآلي"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24
            },
            {
                "id": "t4",
                "name": "نورة حسن",
                "subjects": ["الاجتماعيات", "التربية الفنية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24
            },
            {
                "id": "t5",
                "name": "عبدالله يوسف",
                "subjects": ["التربية البدنية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24
            }
        ],
        "classes": [
            {
                "id": "c1",
                "name": "الصف الأول أ",
                "gradeLevel": 1
            },
            {
                "id": "c2",
                "name": "الصف الأول ب",
                "gradeLevel": 1
            }
        ],
        "subjectRequirements": {
            "1": [
                {"subject": "اللغة العربية", "weeklyHours": 6},
                {"subject": "الرياضيات", "weeklyHours": 5},
                {"subject": "العلوم", "weeklyHours": 5},
                {"subject": "اللغة الإنجليزية", "weeklyHours": 4},
                {"subject": "التربية الإسلامية", "weeklyHours": 4},
                {"subject": "الاجتماعيات", "weeklyHours": 3},
                {"subject": "التربية البدنية", "weeklyHours": 3},
                {"subject": "الحاسب الآلي", "weeklyHours": 3},
                {"subject": "التربية الفنية", "weeklyHours": 2}
            ]
        },
        "daysPerWeek": 5,
        "periodsPerDay": 7
    }
    
    print("\n🚀 إرسال طلب توليد الجدول...")
    print(f"عدد المعلمين: {len(request_data['teachers'])}")
    print(f"عدد الفصول: {len(request_data['classes'])}")
    print(f"الحصص المطلوبة: {2 * 35} حصة")
    
    try:
        response = requests.post(
            f"{BASE_URL}/generate_schedule",
            json=request_data,
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"\n✅ نجح التوليد!")
            print(f"⏱️  الوقت: {result['executionTime']:.2f} ثانية")
            print(f"📊 عدد الحصص: {len(result['lessons'])}")
            print(f"📈 الحالة: {result['stats'].get('status', 'N/A')}")
            
            # عرض بعض الحصص
            print(f"\n📋 أول 5 حصص:")
            for i, lesson in enumerate(result['lessons'][:5], 1):
                print(f"  {i}. {lesson['className']} - {lesson['day']} - الحصة {lesson['period']} - {lesson['subject']} - {lesson['teacherName']}")
            
            return True
        else:
            print(f"\n❌ فشل: {response.status_code}")
            print(response.text)
            return False
            
    except Exception as e:
        print(f"\n❌ خطأ: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("🧪 اختبار API نظام الجدولة الذكي")
    print("=" * 60)
    
    # 1. اختبار الصحة
    print("\n1️⃣ اختبار صحة السيرفر...")
    if not test_health():
        print("❌ السيرفر لا يعمل! تأكد من تشغيل: python main.py")
        exit(1)
    
    # 2. اختبار التوليد
    print("\n2️⃣ اختبار توليد الجدول...")
    if test_generate_schedule():
        print("\n" + "=" * 60)
        print("✅ جميع الاختبارات نجحت!")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("❌ فشل الاختبار")
        print("=" * 60)
