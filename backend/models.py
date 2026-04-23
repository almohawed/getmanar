from pydantic import BaseModel
from typing import List, Dict, Optional
from enum import Enum

class SchoolType(str, Enum):
    PRIMARY = "primary"
    MIDDLE = "middle"
    SECONDARY = "secondary"

class Teacher(BaseModel):
    id: str
    name: str
    subjects: List[str]
    assignedClassIds: List[str]
    maxWeeklyLoad: int = 24

class ClassInfo(BaseModel):
    id: str
    name: str
    gradeLevel: int
    track: Optional[str] = None

class SubjectRequirement(BaseModel):
    subject: str
    weeklyHours: int

class ScheduleRequest(BaseModel):
    schoolId: str
    schoolType: SchoolType
    teachers: List[Teacher]
    classes: List[ClassInfo]
    subjectRequirements: Dict[str, List[SubjectRequirement]]
    daysPerWeek: int = 5
    periodsPerDay: int = 7

class Lesson(BaseModel):
    classId: str
    className: str
    day: str
    period: int
    teacherId: str
    teacherName: str
    subject: str

class ScheduleResponse(BaseModel):
    success: bool
    message: str
    lessons: List[Lesson]
    stats: Dict[str, any]
    executionTime: float
