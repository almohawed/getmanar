import requests
import json

BASE_URL = "http://localhost:8000/api/v2"

def test_precheck():
    request_data = {
        "schoolId": "test_school",
        "schoolType": "primary",
        "teachers": [
            {
                "id": "t1",
                "name": "أحمد محمد",
                "subjects": ["اللغة العربية", "التربية الإسلامية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24,
                "unavailableSlots": [],
                "preferences": {},
                "isClassTeacher": False
            },
            {
                "id": "t2",
                "name": "فاطمة علي",
                "subjects": ["الرياضيات", "العلوم"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24,
                "unavailableSlots": [],
                "preferences": {},
                "isClassTeacher": False
            },
            {
                "id": "t3",
                "name": "خالد سعيد",
                "subjects": ["اللغة الإنجليزية", "الحاسب الآلي"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24,
                "unavailableSlots": [],
                "preferences": {},
                "isClassTeacher": False
            },
            {
                "id": "t4",
                "name": "نورة حسن",
                "subjects": ["الاجتماعيات", "التربية الفنية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24,
                "unavailableSlots": [],
                "preferences": {},
                "isClassTeacher": False
            },
            {
                "id": "t5",
                "name": "عبدالله يوسف",
                "subjects": ["التربية البدنية"],
                "assignedClassIds": ["c1", "c2"],
                "maxWeeklyLoad": 24,
                "unavailableSlots": [],
                "preferences": {},
                "isClassTeacher": False
            }
        ],
        "classes": [
            {
                "id": "c1",
                "name": "الصف الأول أ",
                "gradeLevel": 1,
                "schoolType": "primary",
                "track": None,
                "classTeacherId": None
            },
            {
                "id": "c2",
                "name": "الصف الأول ب",
                "gradeLevel": 1,
                "schoolType": "primary",
                "track": None,
                "classTeacherId": None
            }
        ],
        "subjects": [
            {"id": "s1", "name": "اللغة العربية", "normalizedName": "اللغة العربية", "weeklyHours": 6, "maxPerDay": 2, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": True},
            {"id": "s2", "name": "الرياضيات", "normalizedName": "الرياضيات", "weeklyHours": 5, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": True},
            {"id": "s3", "name": "العلوم", "normalizedName": "العلوم", "weeklyHours": 5, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": True},
            {"id": "s4", "name": "اللغة الإنجليزية", "normalizedName": "اللغة الإنجليزية", "weeklyHours": 4, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False},
            {"id": "s5", "name": "التربية الإسلامية", "normalizedName": "التربية الإسلامية", "weeklyHours": 4, "maxPerDay": 2, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False},
            {"id": "s6", "name": "الاجتماعيات", "normalizedName": "الاجتماعيات", "weeklyHours": 3, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False},
            {"id": "s7", "name": "التربية البدنية", "normalizedName": "التربية البدنية", "weeklyHours": 3, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False},
            {"id": "s8", "name": "الحاسب الآلي", "normalizedName": "الحاسب الآلي", "weeklyHours": 3, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False},
            {"id": "s9", "name": "التربية الفنية", "normalizedName": "التربية الفنية", "weeklyHours": 2, "maxPerDay": 1, "canBeConsecutive": False, "avoidFirstPeriod": False, "avoidLastPeriod": False, "isHeavy": False}
        ],
        "assignments": [
            {"teacherId": "t1", "classId": "c1", "subjectId": "s1", "weeklyHours": 6},
            {"teacherId": "t1", "classId": "c1", "subjectId": "s5", "weeklyHours": 4},
            {"teacherId": "t2", "classId": "c1", "subjectId": "s2", "weeklyHours": 5},
            {"teacherId": "t2", "classId": "c1", "subjectId": "s3", "weeklyHours": 5},
            {"teacherId": "t3", "classId": "c1", "subjectId": "s4", "weeklyHours": 4},
            {"teacherId": "t3", "classId": "c1", "subjectId": "s8", "weeklyHours": 3},
            {"teacherId": "t4", "classId": "c1", "subjectId": "s6", "weeklyHours": 3},
            {"teacherId": "t4", "classId": "c1", "subjectId": "s9", "weeklyHours": 2},
            {"teacherId": "t5", "classId": "c1", "subjectId": "s7", "weeklyHours": 3},
            
            {"teacherId": "t1", "classId": "c2", "subjectId": "s1", "weeklyHours": 6},
            {"teacherId": "t1", "classId": "c2", "subjectId": "s5", "weeklyHours": 4},
            {"teacherId": "t2", "classId": "c2", "subjectId": "s2", "weeklyHours": 5},
            {"teacherId": "t2", "classId": "c2", "subjectId": "s3", "weeklyHours": 5},
            {"teacherId": "t3", "classId": "c2", "subjectId": "s4", "weeklyHours": 4},
            {"teacherId": "t3", "classId": "c2", "subjectId": "s8", "weeklyHours": 3},
            {"teacherId": "t4", "classId": "c2", "subjectId": "s6", "weeklyHours": 3},
            {"teacherId": "t4", "classId": "c2", "subjectId": "s9", "weeklyHours": 2},
            {"teacherId": "t5", "classId": "c2", "subjectId": "s7", "weeklyHours": 3}
        ],
        "manualConstraints": [],
        "daysPerWeek": 5,
        "periodsPerDay": 7,
        "softConstraintWeights": {
            "teacher_gaps": 10.0,
            "class_gaps": 5.0,
            "daily_balance": 8.0,
            "avoid_heavy_last": 7.0,
            "teacher_daily_balance": 6.0,
            "subject_distribution": 9.0
        }
    }
    
    print("=" * 60)
    print("Testing Precheck...")
    print("=" * 60)
    
    response = requests.post(f"{BASE_URL}/precheck", json=request_data, timeout=10)
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Precheck: {'يمكن التوليد' if result['canGenerate'] else 'لا يمكن التوليد'}")
        print(f"📊 الطلب الكلي: {result['totalDemand']}")
        print(f"📊 الطاقة الكلية: {result['totalCapacity']}")
        print(f"⚠️  المشاكل: {len(result['issues'])}")
        
        for issue in result['issues'][:5]:
            print(f"  - [{issue['severity']}] {issue['message']}")
        
        return result['canGenerate'], request_data
    else:
        print(f"❌ خطأ: {response.status_code}")
        print(response.text)
        return False, None

def test_generate(request_data):
    print("\n" + "=" * 60)
    print("Testing Schedule Generation...")
    print("=" * 60)
    
    response = requests.post(f"{BASE_URL}/generate_schedule", json=request_data, timeout=60)
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ النجاح: {result['success']}")
        print(f"📝 الرسالة: {result['message']}")
        
        if result['success']:
            stats = result['solverStats']
            print(f"\n📊 الإحصائيات:")
            print(f"  - الحالة: {stats['status']}")
            print(f"  - الوقت: {stats['executionTime']:.2f} ثانية")
            print(f"  - الحصص: {stats['lessonsPlaced']}/{stats['totalLessons']}")
            print(f"  - نسبة الإكمال: {stats['completionRate']:.1f}%")
            
            print(f"\n📚 الفصول: {len(result['classSchedules'])}")
            print(f"👨‍🏫 المعلمين: {len(result['teacherSchedules'])}")
            
            if result['unmetSoftConstraints']:
                print(f"\n⚠️  القيود المرنة غير المحققة:")
                for constraint in result['unmetSoftConstraints']:
                    print(f"  - {constraint['description']}: {constraint['penalty']}")
        
        return result['success']
    else:
        print(f"❌ خطأ: {response.status_code}")
        print(response.text)
        return False

if __name__ == "__main__":
    print("🧪 اختبار نظام الجدولة v2")
    print("=" * 60)
    
    can_generate, request_data = test_precheck()
    
    if can_generate and request_data:
        success = test_generate(request_data)
        
        if success:
            print("\n" + "=" * 60)
            print("✅ جميع الاختبارات نجحت!")
            print("=" * 60)
        else:
            print("\n" + "=" * 60)
            print("❌ فشل التوليد")
            print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("❌ فشل Precheck")
        print("=" * 60)
