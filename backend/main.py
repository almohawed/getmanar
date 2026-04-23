from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from models import ScheduleRequest, ScheduleResponse
from scheduler import SchoolScheduler
from firebase_service import FirebaseService
import time

app = FastAPI(title="School Schedule Generator API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

firebase_service = FirebaseService()

@app.get("/")
def root():
    return {"message": "School Schedule Generator API", "version": "1.0.0"}

@app.post("/generate_schedule", response_model=ScheduleResponse)
async def generate_schedule(request: ScheduleRequest):
    """
    توليد جدول مدرسي كامل باستخدام OR-Tools
    """
    try:
        start_time = time.time()
        
        # 1. إنشاء المجدول
        scheduler = SchoolScheduler(request)
        
        # 2. حل المشكلة
        success, lessons, stats = scheduler.solve()
        
        if not success:
            raise HTTPException(
                status_code=400,
                detail=f"فشل في توليد الجدول. الحالة: {stats.get('status', 'unknown')}"
            )
        
        execution_time = time.time() - start_time
        
        # 3. حفظ في Firebase
        schedule_id = firebase_service.save_schedule(
            school_id=request.schoolId,
            lessons=lessons,
            stats=stats
        )
        
        # 4. توزيع على الطلاب والمعلمين
        firebase_service.distribute_to_students(request.schoolId, lessons)
        firebase_service.distribute_to_teachers(request.schoolId, lessons)
        
        return ScheduleResponse(
            success=True,
            message=f"تم توليد الجدول بنجاح في {execution_time:.2f} ثانية",
            lessons=lessons,
            stats={
                **stats,
                'scheduleId': schedule_id,
                'totalExecutionTime': execution_time
            },
            executionTime=execution_time
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
