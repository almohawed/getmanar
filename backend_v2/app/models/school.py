from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

SchoolType = Literal["primary", "middle", "secondary"]

class ClassRoom(BaseModel):
    id: str
    name: str
    grade: Optional[str] = None
    track: Optional[str] = None

class Teacher(BaseModel):
    id: str
    name: str
    subjects: List[str] = Field(default_factory=list)
    maxWeeklyLoad: int = 24

class Assignment(BaseModel):
    classId: str
    teacherId: str
    subjectId: str
    subjectName: Optional[str] = None
    weeklyHours: int = Field(ge=1, le=35)
    allowDouble: bool = False

class GenerationRequest(BaseModel):
    schoolId: str
    schoolType: SchoolType = "middle"
    classes: List[ClassRoom]
    teachers: List[Teacher]
    assignments: List[Assignment]
    manualConstraints: List[Dict[str, Any]] = Field(default_factory=list)
    saveToFirebase: bool = True
