import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict
from models import Lesson
import os

class FirebaseService:
    def __init__(self):
        if not firebase_admin._apps:
            # استخدم ملف serviceAccountKey.json
            cred_path = os.getenv('FIREBASE_CREDENTIALS', 'serviceAccountKey.json')
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        
        self.db = firestore.client()
    
    def save_schedule(self, school_id: str, lessons: List[Lesson], stats: Dict):
        """حفظ الجدول في Firestore"""
        
        schedule_ref = self.db.collection(f'Schools/{school_id}/Schedules').document()
        
        lessons_data = [lesson.dict() for lesson in lessons]
        
        schedule_ref.set({
            'createdAt': firestore.SERVER_TIMESTAMP,
            'status': 'approved',
            'lessons': lessons_data,
            'stats': stats,
            'version': 'ortools_v1.0',
            'totalLessons': len(lessons)
        })
        
        return schedule_ref.id
    
    def distribute_to_students(self, school_id: str, lessons: List[Lesson]):
        """توزيع الجدول على الطلاب"""
        
        # تجميع الحصص حسب الفصل
        lessons_by_class = {}
        for lesson in lessons:
            if lesson.classId not in lessons_by_class:
                lessons_by_class[lesson.classId] = []
            lessons_by_class[lesson.classId].append(lesson.dict())
        
        # تحديث جدول كل طالب
        students = self.db.collection(f'Schools/{school_id}/Students').stream()
        
        batch = self.db.batch()
        count = 0
        
        for student in students:
            student_data = student.to_dict()
            class_id = student_data.get('classId')
            
            if class_id and class_id in lessons_by_class:
                batch.update(student.reference, {
                    'schedule': lessons_by_class[class_id]
                })
                count += 1
                
                if count >= 500:
                    batch.commit()
                    batch = self.db.batch()
                    count = 0
        
        if count > 0:
            batch.commit()
    
    def distribute_to_teachers(self, school_id: str, lessons: List[Lesson]):
        """توزيع الجدول على المعلمين"""
        
        # تجميع الحصص حسب المعلم
        lessons_by_teacher = {}
        for lesson in lessons:
            if lesson.teacherId not in lessons_by_teacher:
                lessons_by_teacher[lesson.teacherId] = []
            lessons_by_teacher[lesson.teacherId].append(lesson.dict())
        
        # تحديث جدول كل معلم
        batch = self.db.batch()
        count = 0
        
        for teacher_id, teacher_lessons in lessons_by_teacher.items():
            teacher_ref = self.db.document(f'Schools/{school_id}/Teachers/{teacher_id}')
            batch.update(teacher_ref, {
                'schedule': teacher_lessons
            })
            count += 1
            
            if count >= 500:
                batch.commit()
                batch = self.db.batch()
                count = 0
        
        if count > 0:
            batch.commit()
