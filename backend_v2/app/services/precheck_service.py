from collections import defaultdict

from app.config import settings
from app.models.school import GenerationRequest
from app.models.schedule import PrecheckIssue, PrecheckReport

DAY_NAMES = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس"]

def run_precheck(req: GenerationRequest) -> PrecheckReport:
    issues: list[PrecheckIssue] = []
    
    class_ids = {c.id for c in req.classes}
    teacher_map = {t.id: t for t in req.teachers}
    
    total_demand_by_teacher = defaultdict(int)
    total_demand_by_class = defaultdict(int)
    total_demand_by_subject = defaultdict(int)
    
    if not req.classes:
        issues.append(PrecheckIssue(code="NO_CLASSES", message="لا توجد فصول"))
    if not req.teachers:
        issues.append(PrecheckIssue(code="NO_TEACHERS", message="لا يوجد معلمون"))
    if not req.assignments:
        issues.append(PrecheckIssue(code="NO_ASSIGNMENTS", message="لا توجد إسنادات"))
    
    for a in req.assignments:
        total_demand_by_teacher[a.teacherId] += a.weeklyHours
        total_demand_by_class[a.classId] += a.weeklyHours
        total_demand_by_subject[a.subjectId] += a.weeklyHours
        
        if a.classId not in class_ids:
            issues.append(PrecheckIssue(
                code="INVALID_CLASS",
                message=f"الإسناد يحتوي فصل غير موجود: {a.classId}",
                meta={"classId": a.classId},
            ))
        
        teacher = teacher_map.get(a.teacherId)
        if teacher is None:
            issues.append(PrecheckIssue(
                code="INVALID_TEACHER",
                message=f"الإسناد يحتوي معلم غير موجود: {a.teacherId}",
                severity="error",
                meta={"teacherId": a.teacherId},
            ))
        else:
            # فقط تحقق من المواد إذا كانت قائمة المواد محددة
            if teacher.subjects and len(teacher.subjects) > 0 and a.subjectId not in teacher.subjects:
                issues.append(PrecheckIssue(
                    code="UNAUTHORIZED_SUBJECT",
                    message=f"المعلم {teacher.name} غير مخول بمادة {a.subjectId}",
                    severity="warning",
                    meta={"teacherId": a.teacherId, "subjectId": a.subjectId},
                ))
    
    # تحقق من سعة الفصل
    class_capacity = settings.days_per_week * settings.periods_per_day
    for class_id, demand in total_demand_by_class.items():
        if demand > class_capacity:
            issues.append(PrecheckIssue(
                code="CLASS_CAPACITY_EXCEEDED",
                message=f"الفصل {class_id} يحتاج {demand} حصة أسبوعيًا ويتجاوز السعة المتاحة {class_capacity}",
                severity="error",
                meta={"classId": class_id, "demand": demand, "capacity": class_capacity},
            ))
        elif demand < class_capacity:
            issues.append(PrecheckIssue(
                code="CLASS_CAPACITY_UNDERUSED",
                message=f"الفصل {class_id} يحتاج {demand} حصة فقط من أصل {class_capacity} متاحة",
                severity="warning",
                meta={"classId": class_id, "demand": demand, "capacity": class_capacity},
            ))
    
    # تحقق من نصاب المعلم
    for teacher_id, demand in total_demand_by_teacher.items():
        teacher = teacher_map.get(teacher_id)
        if teacher and demand > teacher.maxWeeklyLoad:
            issues.append(PrecheckIssue(
                code="TEACHER_OVERLOAD",
                message=f"المعلم {teacher.name} مطلوب منه {demand} حصة ويتجاوز نصابه {teacher.maxWeeklyLoad}",
                meta={"teacherId": teacher_id, "demand": demand, "maxWeeklyLoad": teacher.maxWeeklyLoad},
            ))
    
    feasible = len([i for i in issues if i.severity == "error"]) == 0
    
    return PrecheckReport(
        feasible=feasible,
        issues=issues,
        totalDemandByTeacher=dict(total_demand_by_teacher),
        totalDemandByClass=dict(total_demand_by_class),
        totalDemandBySubject=dict(total_demand_by_subject),
    )
