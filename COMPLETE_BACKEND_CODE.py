"""
كود Backend كامل لنظام الجدولة المدرسية
يستخدم FastAPI + Firebase + خوارزمية Greedy للجدولة
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import firebase_admin
from firebase_admin import credentials, firestore
import time
import logging
import random

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

class Req(BaseModel):
    schoolId: str
    classes: List[Dict[str, Any]]
    teachers: List[Dict[str, Any]]
    assignments: List[Dict[str, Any]]

@app.get("/api/v2/health")
def health():
    return {"status": "healthy", "version": "9.0"}

@app.post("/api/v2/simple_generate")
def generate(req: Req):
    try:
        logger.info(f"=== Generate for school: {req.schoolId} ===")
        logger.info(f"Classes: {len(req.classes)}, Teachers: {len(req.teachers)}, Assignments: {len(req.assignments)}")
        
        # تهيئة Firebase
        if not firebase_admin._apps:
            cred = credentials.Certificate({
                "type": "service_account",
                "project_id": "etisak-784d6",
                "private_key_id": "88ba42e85386357edf8cbf4070b4225f4c514cc1",
                "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC/7grz1X8A6M3T\nOD+cK4YZp6Z7P1m7zFGwQXwVVYzyVESdsqG+Nif6OO69HuOjz7XM2aH2GfawjNDb\nET6VgVk9bd0CHEEfYNX3fFjqXe+COOoRqKSMiT5tEwqdbzaqIsTWawYEwVl7JOak\njDirHI7Ys+CFgQdx4UX6pYekSUy+kTstQ/MUP9ulk9hHrz8LzENvSr7CDeozPXg4\nA6D4gGfnalyVyQYBS6tWx8UTwCIaMwaBK45chO33dQl4biyUDhNPlm0bXXVBi+Yj\npHoArPKNfxKdvso/ogfmM7dFvn1kQThSrFt96HdI02ecjAOq+RzMSgqNb76BzpZn\nPt5lYJA3AgMBAAECggEAWrPIykXVgN0EVDMLYKby91HS7ADay9T5r+Wqmbx14Rmw\n2aPPK0CVsPtR299qrgIdxQL+tvq7KeFKXJTwMiBQR6cRYItwvT76rzw9GvkslKqH\n97NunBnJ/isXA6LIvyuyQTCPxhSH0Jn2Q8Iej8LtwPx0+TKqjYdsFlE+4oVfdtkC\nvEc2gqHX6r8tB8Tpr1cSgGFwobukX6Z9rDud9UcDnWW0L2gGOosXaH/cE3J3mGM5\nAmrRehUjKfS58hwRfbSyELflUnXe/Z5KSnUrllOgbUK1QJz02EY+gm2ZeBxc8AX4\nIzjLZcFwXQYCh4MniR2gwa3AqvPEr2WFC5zlSlRwcQKBgQDqWoeFCfmFnGYHZOqp\nMKX+TrEbbGmIc8BIH9kLjv5W5SWgEESPUQME1eCVd02wdT8W3ziiA0fk5fus0Vkg\nQfv2N0brNCEwlm16JfgG4JQrd+Mgx9YItLAXBjRkWIQeLYzPbxkB/NJAU11wI9eB\nZeyYOIXTwRW+9+bzxmilCDI0sQKBgQDRqF7uLxqHFFUsvQs8jC97wWi775Rez6/L\nvTeDgWVkzHK4xJ2jxNvHlPt3FO9tvXIO/Lx7eTeiytQOx3EycZYQgMBuvqD2ARNF\nr48uPUbl4hm+a6Xy+16pNdO9bIMpwJfiMspGIytmClUo6qEVi4qP4dGtC44z92gZ\nxta0TB5tZwKBgG75c5ciRBBrIT17IkwAB3rHVMLBsa+18GW2/xakHfiUBh8n1O9w\n01ck2HauyhE3VCrGhZDisNbJuUX61JOb626KeoDCbL0PXsQq2qqXClMTMHDDcK0q\nswAUJhcme1m3BCjuWQ9B42Ymk+aYcmKKG2Fx0p2Vn3CQ/8KMP912Zh/hAoGADN6w\nDSD5GOenntpv8SSN2aPywO6hBfzrxq7z1G/CAKEIPc1b++yerS65DQNM+0iQ0tiy\n3UWAo86dm9akXTtZweOVbHbpPJCuVS3EtUrvqjbp66WCB1tk4TA7sjoSByMab7k8\nb3fDNz1VIvDcOI1bUR/ElkHKVehPDJ4HGgQ+LesCgYApFE0/h6KdUwZTRHc6a9xH\nrJ6AgjNW4J3Ut9ZKb4gPsAfOm5Knkng7lP60PKNDqfkkX8y/qdzNMoAG0Sv+jnfo\naqaQAAibd1DEWgYYlHM8IPkKcepIUGfP3pJ/Ugwly2fthZKGBOoTcInajTHFDalh\nDzhYTicE0jyFCbWgiRXwWw==\n-----END PRIVATE KEY-----\n",
                "client_email": "firebase-adminsdk-fbsvc@etisak-784d6.iam.gserviceaccount.com",
                "client_id": "108812714482294952052",
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40etisak-784d6.iam.gserviceaccount.com"
            })
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        start = time.time()
        
        # الأيام والفترات
        days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس']
        periods = list(range(1, 8))
        
        # هياكل البيانات
        # schedule[class_id][day][period] = (teacher_id, subject_id) أو None
        schedule = {}
        for c in req.classes:
            cid = c.get('id', '')
            schedule[cid] = {}
            for d in days:
                schedule[cid][d] = {}
                for p in periods:
                    schedule[cid][d][p] = None
        
        # teacher_schedule[teacher_id][day][period] = True/False
        teacher_schedule = {}
        for t in req.teachers:
            tid = t.get('id', '')
            teacher_schedule[tid] = {}
            for d in days:
                teacher_schedule[tid][d] = {}
                for p in periods:
                    teacher_schedule[tid][d][p] = False
        
        result = []
        placed = 0
        failed = 0
        
        # توزيع الحصص
        for assignment in req.assignments:
            cid = assignment.get('classId', '')
            tid = assignment.get('teacherId', '')
            sid = assignment.get('subjectId', '')
            wh = min(assignment.get('weeklyHours', 2), 7)
            
            if not cid or not tid or not sid:
                logger.warning(f"Skipping incomplete assignment: {assignment}")
                continue
            
            placed_count = 0
            attempts = 0
            max_attempts = 200
            
            while placed_count < wh and attempts < max_attempts:
                attempts += 1
                day = random.choice(days)
                period = random.choice(periods)
                
                # تحقق من التوفر
                if schedule[cid][day][period] is None and not teacher_schedule[tid][day][period]:
                    # تحقق من عدم تكرار المادة أكثر من مرتين في اليوم
                    same_subject_count = 0
                    for p in periods:
                        slot = schedule[cid][day][p]
                        if slot and slot[1] == sid:
                            same_subject_count += 1
                    
                    if same_subject_count < 2:
                        schedule[cid][day][period] = (tid, sid)
                        teacher_schedule[tid][day][period] = True
                        result.append({
                            'classId': cid,
                            'day': day,
                            'period': period,
                            'teacherId': tid,
                            'subjectId': sid
                        })
                        placed_count += 1
                        placed += 1
            
            if placed_count < wh:
                failed += (wh - placed_count)
                logger.warning(f"Could not place all lessons for {sid} in {cid}: {placed_count}/{wh}")
        
        logger.info(f"Placed: {placed}, Failed: {failed}")
        
        if not result:
            return {"success": False, "error": "لم يتم توليد أي حصص"}
        
        # حفظ في Firestore
        ref = db.collection(f'Schools/{req.schoolId}/Schedules').document()
        ref.set({
            'createdAt': firestore.SERVER_TIMESTAMP,
            'lessons': result,
            'stats': {
                'count': len(result),
                'time': time.time() - start,
                'placed': placed,
                'failed': failed
            }
        })
        
        # توزيع على الفصول
        for c in req.classes:
            cid = c.get('id', '')
            cls_lessons = [l for l in result if l['classId'] == cid]
            if cls_lessons:
                db.collection(f'Schools/{req.schoolId}/Classes/{cid}/ClassSchedules').document(ref.id).set({
                    'lessons': cls_lessons,
                    'createdAt': firestore.SERVER_TIMESTAMP
                })
        
        # توزيع على المعلمين
        for t in req.teachers:
            tid = t.get('id', '')
            tch_lessons = [l for l in result if l['teacherId'] == tid]
            if tch_lessons:
                db.collection(f'Schools/{req.schoolId}/Teachers/{tid}/TeacherSchedules').document(ref.id).set({
                    'lessons': tch_lessons,
                    'createdAt': firestore.SERVER_TIMESTAMP
                })
        
        logger.info(f"✅ Success! Schedule ID: {ref.id}")
        
        return {
            "success": True,
            "message": f"تم توليد {len(result)} حصة بنجاح",
            "scheduleId": ref.id,
            "stats": {
                "lessonsPlaced": len(result),
                "executionTime": time.time() - start,
                "placed": placed,
                "failed": failed
            }
        }
        
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
