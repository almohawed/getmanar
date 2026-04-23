import json
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import credentials, firestore

from app.config import settings
from app.models.schedule import ScheduledLesson

def get_firestore() -> Optional[firestore.Client]:
    if not settings.firebase_credentials_json:
        return None
    
    if not firebase_admin._apps:
        cred_dict = json.loads(settings.firebase_credentials_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
    
    return firestore.client()

def save_schedule(
    school_id: str,
    lessons: List[ScheduledLesson],
    diagnostics: Dict[str, Any],
) -> Optional[str]:
    db = get_firestore()
    if db is None:
        return None
    
    payload_lessons = [lesson.model_dump() for lesson in lessons]
    
    schedule_ref = db.collection("Schools").document(school_id).collection("Schedules").document()
    schedule_ref.set({
        "createdAt": firestore.SERVER_TIMESTAMP,
        "lessons": payload_lessons,
        "diagnostics": diagnostics,
    })
    
    # توزيع على الفصول
    lessons_by_class: Dict[str, List[Dict[str, Any]]] = {}
    for lesson in payload_lessons:
        lessons_by_class.setdefault(lesson["classId"], []).append(lesson)
    
    for class_id, class_lessons in lessons_by_class.items():
        db.collection("Schools").document(school_id).collection("Classes").document(class_id)\
            .collection("ClassSchedules").document(schedule_ref.id).set({
                "createdAt": firestore.SERVER_TIMESTAMP,
                "lessons": class_lessons,
            })
    
    # توزيع على المعلمين
    lessons_by_teacher: Dict[str, List[Dict[str, Any]]] = {}
    for lesson in payload_lessons:
        lessons_by_teacher.setdefault(lesson["teacherId"], []).append(lesson)
    
    for teacher_id, teacher_lessons in lessons_by_teacher.items():
        db.collection("Schools").document(school_id).collection("Teachers").document(teacher_id)\
            .collection("TeacherSchedules").document(schedule_ref.id).set({
                "createdAt": firestore.SERVER_TIMESTAMP,
                "lessons": teacher_lessons,
            })
    
    return schedule_ref.id
