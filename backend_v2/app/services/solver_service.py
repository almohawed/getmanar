import time
from collections import defaultdict
from typing import Dict, List, Tuple

from ortools.sat.python import cp_model

from app.config import settings
from app.models.school import Assignment, GenerationRequest
from app.models.schedule import (
    ClassSchedule,
    Diagnostics,
    GenerationResponse,
    ScheduledLesson,
    TeacherSchedule,
)
from app.services.precheck_service import DAY_NAMES, run_precheck
from app.services.firebase_service import save_schedule

def _manual_teacher_blocked(manual_constraints: list[dict], teacher_id: str, day_idx: int, period: int) -> bool:
    for c in manual_constraints:
        ctype = c.get("type")
        if ctype == "teacher_unavailable" and c.get("teacherId") == teacher_id:
            if c.get("dayIndex") == day_idx and c.get("period") == period:
                return True
        if ctype == "teacher_no_seventh" and c.get("teacherId") == teacher_id and period == 7:
            return True
    return False

def _subject_blocked(manual_constraints: list[dict], subject_id: str, period: int) -> bool:
    for c in manual_constraints:
        ctype = c.get("type")
        if c.get("subjectId") != subject_id:
            continue
        if ctype == "subject_not_first" and period == 1:
            return True
        if ctype == "subject_not_last" and period == settings.periods_per_day:
            return True
    return False

def generate_schedule(req: GenerationRequest) -> GenerationResponse:
    start = time.time()
    precheck = run_precheck(req)
    
    if not precheck.feasible:
        return GenerationResponse(
            success=False,
            message="فشل الفحص الأولي. أصلح البيانات ثم أعد المحاولة.",
            precheckReport=precheck,
            diagnostics=Diagnostics(
                solverStatus="PRECHECK_FAILED",
                executionTimeSeconds=time.time() - start,
                notes=["تم إيقاف التوليد لأن البيانات الأساسية غير قابلة للجدولة."],
            ),
        )
    
    model = cp_model.CpModel()
    
    days = list(range(settings.days_per_week))
    periods = list(range(1, settings.periods_per_day + 1))
    
    class_ids = [c.id for c in req.classes]
    teacher_ids = [t.id for t in req.teachers]
    
    # assignment map per class
    assignments_by_class: Dict[str, List[Assignment]] = defaultdict(list)
    assignments_by_teacher: Dict[str, List[Assignment]] = defaultdict(list)
    for a in req.assignments:
        assignments_by_class[a.classId].append(a)
        assignments_by_teacher[a.teacherId].append(a)
    
    # متغيرات المادة/المعلم/الفصل/اليوم/الحصة
    x: Dict[Tuple[str, str, str, int, int], cp_model.IntVar] = {}
    
    for a in req.assignments:
        for d in days:
            for p in periods:
                if _manual_teacher_blocked(req.manualConstraints, a.teacherId, d, p):
                    continue
                if _subject_blocked(req.manualConstraints, a.subjectId, p):
                    continue
                key = (a.classId, a.teacherId, a.subjectId, d, p)
                x[key] = model.NewBoolVar(f"x_{a.classId}_{a.teacherId}_{a.subjectId}_{d}_{p}")
    
    # 1) كل فصل لديه حصة واحدة بالضبط في كل خانة
    for class_id in class_ids:
        for d in days:
            for p in periods:
                vars_here = [
                    var for (cid, _tid, _sid, dd, pp), var in x.items()
                    if cid == class_id and dd == d and pp == p
                ]
                model.Add(sum(vars_here) == 1)
    
    # 2) المعلم لا يدرس حصتين في نفس الوقت
    for teacher_id in teacher_ids:
        for d in days:
            for p in periods:
                vars_here = [
                    var for (cid, tid, sid, dd, pp), var in x.items()
                    if tid == teacher_id and dd == d and pp == p
                ]
                if vars_here:
                    model.Add(sum(vars_here) <= 1)
    
    # 3) عدد الحصص الأسبوعية لكل إسناد (يجب أن يكون بالضبط weeklyHours)
    for a in req.assignments:
        vars_for_assignment = [
            var for (cid, tid, sid, d, p), var in x.items()
            if cid == a.classId and tid == a.teacherId and sid == a.subjectId
        ]
        # يجب أن يكون عدد الحصص بالضبط = weeklyHours
        model.Add(sum(vars_for_assignment) == a.weeklyHours)
    
    # 3b) التأكد من أن كل معلم يأخذ نصابه الكامل
    for teacher_id in teacher_ids:
        teacher_assignments = assignments_by_teacher[teacher_id]
        total_required = sum(a.weeklyHours for a in teacher_assignments)
        vars_for_teacher = [
            var for (cid, tid, sid, d, p), var in x.items()
            if tid == teacher_id
        ]
        if vars_for_teacher:
            model.Add(sum(vars_for_teacher) == total_required)
    
    # 4) عدم تكرار نفس المادة في نفس اليوم للفصل (إلا إذا كانت allowDouble)
    for a in req.assignments:
        if not a.allowDouble:  # فقط إذا لم يكن مسموح بالحصص المزدوجة
            for d in days:
                vars_same_day = [
                    var for (cid, tid, sid, dd, p), var in x.items()
                    if cid == a.classId and sid == a.subjectId and dd == d
                ]
                if vars_same_day:
                    model.Add(sum(vars_same_day) <= 1)
    
    # 4b) توزيع عادل للمواد عبر الأيام - منع تكرار نفس الجدول
    # لكل فصل، نضمن أن كل يوم له توزيع مختلف من المواد
    for class_id in class_ids:
        class_assignments = assignments_by_class[class_id]
        
        # منع تكرار نفس المادة في نفس الحصة عبر أيام مختلفة
        for a in class_assignments:
            for p in periods:
                vars_same_period = [
                    var for (cid, tid, sid, d, pp), var in x.items()
                    if cid == class_id and sid == a.subjectId and pp == p
                ]
                if vars_same_period and len(vars_same_period) > 1:
                    model.Add(sum(vars_same_period) <= 1)
        
        # توزيع متوازن للمواد عبر الأيام
        # كل مادة يجب أن توزع بشكل متساوٍ قدر الإمكان عبر الأيام
        for a in class_assignments:
            if a.weeklyHours >= 2:  # فقط للمواد التي لها أكثر من حصة
                lessons_per_day = []
                for d in days:
                    vars_this_day = [
                        var for (cid, tid, sid, dd, p), var in x.items()
                        if cid == class_id and sid == a.subjectId and dd == d
                    ]
                    if vars_this_day:
                        day_count = model.NewIntVar(0, settings.periods_per_day, f"day_count_{class_id}_{a.subjectId}_{d}")
                        model.Add(day_count == sum(vars_this_day))
                        lessons_per_day.append(day_count)
                
                # منع تركيز كل الحصص في يوم واحد (إلا إذا كان allowDouble)
                if not a.allowDouble and lessons_per_day:
                    for day_count in lessons_per_day:
                        model.Add(day_count <= 1)
    
    # 4c) تشجيع التنوع: منع تكرار نفس تسلسل المواد عبر الأيام
    # نضيف penalty لكل حالة تتكرر فيها نفس المادة في نفس الموضع عبر يومين
    diversity_penalties: list[cp_model.IntVar] = []
    for class_id in class_ids:
        for p in periods:
            for d1 in range(len(days) - 1):
                for d2 in range(d1 + 1, len(days)):
                    # للحصة p في اليومين d1 و d2
                    for a in assignments_by_class[class_id]:
                        var_d1 = x.get((class_id, a.teacherId, a.subjectId, d1, p))
                        var_d2 = x.get((class_id, a.teacherId, a.subjectId, d2, p))
                        if var_d1 is not None and var_d2 is not None:
                            # إذا كانت نفس المادة في نفس الحصة في يومين مختلفين
                            both_same = model.NewBoolVar(f"same_{class_id}_{a.subjectId}_{p}_{d1}_{d2}")
                            model.Add(var_d1 + var_d2 == 2).OnlyEnforceIf(both_same)
                            model.Add(var_d1 + var_d2 < 2).OnlyEnforceIf(both_same.Not())
                            diversity_penalties.append(both_same)
    
    # penalties
    penalties: list[cp_model.IntVar] = []
    penalties.extend(diversity_penalties)
    
    # 5) تقليل الحصة السابعة للمعلمين
    for teacher_id in teacher_ids:
        vars_seventh = [
            var for (cid, tid, sid, d, p), var in x.items()
            if tid == teacher_id and p == settings.periods_per_day
        ]
        if vars_seventh:
            seventh_count = model.NewIntVar(0, settings.days_per_week, f"seventh_{teacher_id}")
            model.Add(seventh_count == sum(vars_seventh))
            penalties.append(seventh_count)
    
    # 6) تقليل وضع نفس المعلم في أول وآخر اليوم معًا
    for teacher_id in teacher_ids:
        for d in days:
            first_vars = [
                var for (cid, tid, sid, dd, p), var in x.items()
                if tid == teacher_id and dd == d and p == 1
            ]
            last_vars = [
                var for (cid, tid, sid, dd, p), var in x.items()
                if tid == teacher_id and dd == d and p == settings.periods_per_day
            ]
            if first_vars and last_vars:
                both_edge = model.NewBoolVar(f"both_edge_{teacher_id}_{d}")
                model.Add(sum(first_vars) + sum(last_vars) <= 1).OnlyEnforceIf(both_edge.Not())
                # عند عدم القدرة على المنع الكامل، تصبح penalty
                penalties.append(both_edge)
    
    model.Minimize(sum(penalties) if penalties else 0)
    
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = float(settings.max_solver_seconds)
    solver.parameters.num_search_workers = 8
    
    status = solver.Solve(model)
    elapsed = time.time() - start
    
    status_name = solver.StatusName(status)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return GenerationResponse(
            success=False,
            message=f"تعذر إيجاد حل صالح. الحالة: {status_name}",
            precheckReport=precheck,
            diagnostics=Diagnostics(
                solverStatus=status_name,
                executionTimeSeconds=elapsed,
                notes=["تم اجتياز الفحص الأولي لكن solver لم يجد حلاً صالحًا."],
            ),
        )
    
    lessons: List[ScheduledLesson] = []
    for (cid, tid, sid, d, p), var in x.items():
        if solver.Value(var) == 1:
            lessons.append(ScheduledLesson(
                classId=cid,
                teacherId=tid,
                subjectId=sid,
                dayIndex=d,
                dayName=DAY_NAMES[d],
                period=p,
            ))
    
    # Post-solve validation: التحقق من اكتمال نصاب المعلمين
    required_by_teacher = defaultdict(int)
    for a in req.assignments:
        required_by_teacher[a.teacherId] += a.weeklyHours
    
    actual_by_teacher = defaultdict(int)
    for lesson in lessons:
        actual_by_teacher[lesson.teacherId] += 1
    
    teacher_mismatches = []
    for teacher_id, required in required_by_teacher.items():
        actual = actual_by_teacher.get(teacher_id, 0)
        if actual != required:
            teacher_mismatches.append({
                "teacherId": teacher_id,
                "required": required,
                "actual": actual,
            })
    
    if teacher_mismatches:
        return GenerationResponse(
            success=False,
            message="فشل التحقق النهائي: عدد حصص بعض المعلمين في الحل لا يطابق المطلوب.",
            precheckReport=precheck,
            diagnostics=Diagnostics(
                solverStatus="POST_SOLVE_VALIDATION_FAILED",
                executionTimeSeconds=elapsed,
                totalLessonsPlaced=len(lessons),
                notes=[
                    f"Teacher load mismatch detected: {teacher_mismatches}"
                ],
            ),
        )
    
    # Post-solve validation: التحقق من اكتمال كل إسناد
    required_by_assignment = {}
    for a in req.assignments:
        key = (a.classId, a.teacherId, a.subjectId)
        required_by_assignment[key] = a.weeklyHours
    
    actual_by_assignment = defaultdict(int)
    for lesson in lessons:
        key = (lesson.classId, lesson.teacherId, lesson.subjectId)
        actual_by_assignment[key] += 1
    
    assignment_mismatches = []
    for key, required in required_by_assignment.items():
        actual = actual_by_assignment.get(key, 0)
        if actual != required:
            assignment_mismatches.append({
                "classId": key[0],
                "teacherId": key[1],
                "subjectId": key[2],
                "required": required,
                "actual": actual,
            })
    
    if assignment_mismatches:
        return GenerationResponse(
            success=False,
            message="فشل التحقق النهائي: بعض الإسنادات لم تُنفذ بعدد الحصص المطلوب.",
            precheckReport=precheck,
            diagnostics=Diagnostics(
                solverStatus="POST_SOLVE_ASSIGNMENT_VALIDATION_FAILED",
                executionTimeSeconds=elapsed,
                totalLessonsPlaced=len(lessons),
                notes=[
                    f"Assignment mismatch detected: {assignment_mismatches}"
                ],
            ),
        )
    
    # إنشاء ملخص نصاب المعلمين مع الفترات الحرة
    teacher_load_summary = []
    for teacher_id in teacher_ids:
        required = required_by_teacher.get(teacher_id, 0)
        actual = actual_by_teacher.get(teacher_id, 0)
        total_periods = settings.days_per_week * settings.periods_per_day
        teacher_load_summary.append({
            "teacherId": teacher_id,
            "required": required,
            "actual": actual,
            "freePeriods": total_periods - actual,
        })
    
    # تحضير بيانات للـ logs
    logger_data = {
        item["teacherId"]: {
            "required": item["required"],
            "actual": item["actual"],
            "freePeriods": item["freePeriods"],
        }
        for item in teacher_load_summary
    }
    
    # ترتيب الحصص
    lessons = sorted(lessons, key=lambda x: (x.dayIndex, x.period, x.classId, x.teacherId, x.subjectId))
    
    class_schedules: List[ClassSchedule] = []
    for class_id in class_ids:
        class_schedules.append(ClassSchedule(
            classId=class_id,
            lessons=[l for l in lessons if l.classId == class_id],
        ))
    
    teacher_schedules: List[TeacherSchedule] = []
    for teacher_id in teacher_ids:
        teacher_lessons = sorted(
            [l for l in lessons if l.teacherId == teacher_id],
            key=lambda x: (x.dayIndex, x.period)
        )
        teacher_schedules.append(
            TeacherSchedule(
                teacherId=teacher_id,
                lessons=teacher_lessons,
            )
        )
    
    diagnostics = Diagnostics(
        solverStatus=status_name,
        objectiveValue=int(solver.ObjectiveValue()) if penalties else 0,
        executionTimeSeconds=elapsed,
        totalLessonsPlaced=len(lessons),
        notes=[
            "تم توليد الجدول بنجاح باستخدام OR-Tools CP-SAT.",
            "تم تطبيق القيود الصلبة قبل التحسينات المرنة.",
            f"Teacher load summary: {logger_data}",
        ],
    )
    
    schedule_id = None
    if req.saveToFirebase:
        schedule_id = save_schedule(
            school_id=req.schoolId,
            lessons=lessons,
            diagnostics=diagnostics.model_dump(),
        )
    
    return GenerationResponse(
        success=True,
        message=f"تم توليد الجدول بنجاح في {elapsed:.2f} ثانية",
        precheckReport=precheck,
        classSchedules=class_schedules,
        teacherSchedules=teacher_schedules,
        lessons=lessons,
        diagnostics=diagnostics,
        scheduleId=schedule_id,
        teacherLoadSummary=teacher_load_summary,
    )
