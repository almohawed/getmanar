from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

class PrecheckIssue(BaseModel):
    code: str
    message: str
    severity: str = "error"
    meta: Dict[str, Any] = Field(default_factory=dict)

class PrecheckReport(BaseModel):
    feasible: bool
    issues: List[PrecheckIssue] = Field(default_factory=list)
    totalDemandByTeacher: Dict[str, int] = Field(default_factory=dict)
    totalDemandByClass: Dict[str, int] = Field(default_factory=dict)
    totalDemandBySubject: Dict[str, int] = Field(default_factory=dict)

class ScheduledLesson(BaseModel):
    classId: str
    teacherId: str
    subjectId: str
    dayIndex: int
    dayName: str
    period: int

class ClassSchedule(BaseModel):
    classId: str
    lessons: List[ScheduledLesson]

class TeacherSchedule(BaseModel):
    teacherId: str
    lessons: List[ScheduledLesson]

class Diagnostics(BaseModel):
    solverStatus: str
    objectiveValue: Optional[int] = None
    executionTimeSeconds: float
    totalLessonsPlaced: int = 0
    notes: List[str] = Field(default_factory=list)

class GenerationResponse(BaseModel):
    success: bool
    message: str
    precheckReport: PrecheckReport
    classSchedules: List[ClassSchedule] = Field(default_factory=list)
    teacherSchedules: List[TeacherSchedule] = Field(default_factory=list)
    lessons: List[ScheduledLesson] = Field(default_factory=list)
    diagnostics: Diagnostics
    scheduleId: Optional[str] = None
    teacherLoadSummary: List[Dict[str, Any]] = Field(default_factory=list)
