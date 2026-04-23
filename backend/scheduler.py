from ortools.sat.python import cp_model
from models import ScheduleRequest, Lesson, Teacher, ClassInfo
from typing import List, Dict, Tuple
import time

class SchoolScheduler:
    def __init__(self, request: ScheduleRequest):
        self.request = request
        self.model = cp_model.CpModel()
        self.days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس']
        self.periods = list(range(1, request.periodsPerDay + 1))
        
        # Variables
        self.lessons = {}
        self.teacher_vars = {}
        self.class_vars = {}
        
    def build_model(self):
        """بناء نموذج CP-SAT"""
        
        # 1. إنشاء المتغيرات
        for class_info in self.request.classes:
            for day in self.days:
                for period in self.periods:
                    for teacher in self.request.teachers:
                        for subject in teacher.subjects:
                            var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                            self.lessons[var_name] = self.model.NewBoolVar(var_name)
        
        # 2. القيد: كل فصل له حصة واحدة فقط في كل فترة
        for class_info in self.request.classes:
            for day in self.days:
                for period in self.periods:
                    vars_for_slot = []
                    for teacher in self.request.teachers:
                        for subject in teacher.subjects:
                            var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                            if var_name in self.lessons:
                                vars_for_slot.append(self.lessons[var_name])
                    if vars_for_slot:
                        self.model.Add(sum(vars_for_slot) == 1)
        
        # 3. القيد: المعلم لا يدرس حصتين في نفس الوقت
        for teacher in self.request.teachers:
            for day in self.days:
                for period in self.periods:
                    vars_for_teacher = []
                    for class_info in self.request.classes:
                        for subject in teacher.subjects:
                            var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                            if var_name in self.lessons:
                                vars_for_teacher.append(self.lessons[var_name])
                    if vars_for_teacher:
                        self.model.Add(sum(vars_for_teacher) <= 1)
        
        # 4. القيد: عدد الحصص المطلوبة لكل مادة في كل فصل
        for class_info in self.request.classes:
            requirements = self.request.subjectRequirements.get(str(class_info.gradeLevel), [])
            for req in requirements:
                subject = req.subject
                weekly_hours = req.weeklyHours
                
                vars_for_subject = []
                for day in self.days:
                    for period in self.periods:
                        for teacher in self.request.teachers:
                            if subject in teacher.subjects:
                                var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                                if var_name in self.lessons:
                                    vars_for_subject.append(self.lessons[var_name])
                
                if vars_for_subject:
                    self.model.Add(sum(vars_for_subject) == weekly_hours)
        
        # 5. القيد: منع تكرار المادة في نفس اليوم (ماعدا العربي والإسلامية)
        for class_info in self.request.classes:
            for day in self.days:
                for teacher in self.request.teachers:
                    for subject in teacher.subjects:
                        if subject not in ['اللغة العربية', 'التربية الإسلامية']:
                            vars_for_subject_day = []
                            for period in self.periods:
                                var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                                if var_name in self.lessons:
                                    vars_for_subject_day.append(self.lessons[var_name])
                            if vars_for_subject_day:
                                self.model.Add(sum(vars_for_subject_day) <= 1)
                        else:
                            # العربي والإسلامية: حد أقصى 2 في اليوم
                            vars_for_subject_day = []
                            for period in self.periods:
                                var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                                if var_name in self.lessons:
                                    vars_for_subject_day.append(self.lessons[var_name])
                            if vars_for_subject_day:
                                self.model.Add(sum(vars_for_subject_day) <= 2)
        
        # 6. القيد: نصاب المعلم الأسبوعي
        for teacher in self.request.teachers:
            teacher_lessons = []
            for class_info in self.request.classes:
                for day in self.days:
                    for period in self.periods:
                        for subject in teacher.subjects:
                            var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                            if var_name in self.lessons:
                                teacher_lessons.append(self.lessons[var_name])
            if teacher_lessons:
                self.model.Add(sum(teacher_lessons) <= teacher.maxWeeklyLoad)
        
        # 7. القيد: المعلم يدرس فقط الفصول المسندة له
        for teacher in self.request.teachers:
            if teacher.assignedClassIds:
                for class_info in self.request.classes:
                    if class_info.id not in teacher.assignedClassIds:
                        for day in self.days:
                            for period in self.periods:
                                for subject in teacher.subjects:
                                    var_name = f"c{class_info.id}_d{day}_p{period}_t{teacher.id}_s{subject}"
                                    if var_name in self.lessons:
                                        self.model.Add(self.lessons[var_name] == 0)
    
    def solve(self) -> Tuple[bool, List[Lesson], Dict]:
        """حل النموذج"""
        start_time = time.time()
        
        self.build_model()
        
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = 30.0
        solver.parameters.num_search_workers = 8
        
        status = solver.Solve(self.model)
        
        execution_time = time.time() - start_time
        
        lessons = []
        stats = {
            'status': solver.StatusName(status),
            'executionTime': execution_time,
            'totalLessons': 0,
            'conflicts': 0
        }
        
        if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
            # استخراج الحل
            for var_name, var in self.lessons.items():
                if solver.Value(var) == 1:
                    # تحليل اسم المتغير
                    parts = var_name.split('_')
                    class_id = parts[0].replace('c', '')
                    day = parts[1].replace('d', '')
                    period = int(parts[2].replace('p', ''))
                    teacher_id = parts[3].replace('t', '')
                    subject = parts[4].replace('s', '')
                    
                    # البحث عن بيانات الفصل والمعلم
                    class_info = next((c for c in self.request.classes if c.id == class_id), None)
                    teacher = next((t for t in self.request.teachers if t.id == teacher_id), None)
                    
                    if class_info and teacher:
                        lessons.append(Lesson(
                            classId=class_id,
                            className=class_info.name,
                            day=day,
                            period=period,
                            teacherId=teacher_id,
                            teacherName=teacher.name,
                            subject=subject
                        ))
            
            stats['totalLessons'] = len(lessons)
            return True, lessons, stats
        else:
            return False, [], stats
