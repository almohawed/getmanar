from typing import Literal, Optional
from pydantic import BaseModel

ConstraintType = Literal[
    "teacher_unavailable",
    "teacher_no_seventh",
    "subject_not_first",
    "subject_not_last",
]

class ManualConstraint(BaseModel):
    type: ConstraintType
    teacherId: Optional[str] = None
    subjectId: Optional[str] = None
    dayIndex: Optional[int] = None  # 0..4
    period: Optional[int] = None    # 1..7
