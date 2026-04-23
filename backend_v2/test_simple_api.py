#!/usr/bin/env python3
"""
اختبار بسيط لـ API
"""
import requests
import json

# عنوان الخادم
BASE_URL = "https://schedule-solver-979291699789.us-central1.run.app"

# بيانات تجريبية
test_data = {
    "schoolId": "test_school",
    "classes": [
        {
            "id": "class1",
            "name": "الصف الأول أ",
            "gradeLevel": 1,
            "schoolType": "middle"
        },
        {
            "id": "class2",
            "name": "الصف الأول ب",
            "gradeLevel": 1,
            "schoolType": "middle"
        }
    ],
    "teachers": [
        {
            "id": "teacher1",
            "name": "أحمد محمد",
            "subjects": [],
            "assignedClassIds": [],
            "maxWeeklyLoad": 30
        },
        {
            "id": "teacher2",
            "name": "فاطمة علي",
            "subjects": [],
            "assignedClassIds": [],
            "maxWeeklyLoad": 30
        }
    ],
    "assignments": [
        {
            "teacherId": "teacher1",
            "classId": "class1",
            "subjectId": "رياضيات",
            "weeklyHours": 5
        },
        {
            "teacherId": "teacher1",
            "classId": "class2",
            "subjectId": "رياضيات",
            "weeklyHours": 5
        },
        {
            "teacherId": "teacher2",
            "classId": "class1",
            "subjectId": "لغة عربية",
            "weeklyHours": 6
        },
        {
            "teacherId": "teacher2",
            "classId": "class2",
            "subjectId": "لغة عربية",
            "weeklyHours": 6
        }
    ]
}

def test_health():
    """اختبار صحة الخادم"""
    print("🔍 Testing health endpoint...")
    response = requests.get(f"{BASE_URL}/api/v2/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    print()

def test_simple_generate():
    """اختبار توليد الجدول"""
    print("🔍 Testing simple_generate endpoint...")
    print(f"Sending data: {json.dumps(test_data, ensure_ascii=False, indent=2)}")
    print()
    
    response = requests.post(
        f"{BASE_URL}/api/v2/simple_generate",
        json=test_data,
        headers={"Content-Type": "application/json"}
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Success!")
        print(f"Response: {json.dumps(result, ensure_ascii=False, indent=2)}")
    else:
        print(f"❌ Error!")
        print(f"Response: {response.text}")
    print()

if __name__ == "__main__":
    print("=" * 60)
    print("اختبار OR-Tools Backend API")
    print("=" * 60)
    print()
    
    test_health()
    test_simple_generate()
    
    print("=" * 60)
    print("انتهى الاختبار")
    print("=" * 60)
