# وثيقة تصميم تطبيق "مسار" (Masar)

## 1. نبذة عن التطبيق
**الاسم المقترح:** مسار (Masar)
**الوصف:** منصة تعليمية ذكية لمتابعة السلوك والتحصيل الدراسي في المدارس، تربط بين الإدارة والمعلم والطالب وولي الأمر.

## 2. الهيكلية التقنية (Architecture)
سنعتمد **Clean Architecture** لضمان قابلية التوسع والصيانة، مع **Riverpod** لإدارة الحالة.

### الطبقات (Layers):
1.  **Presentation Layer (العرض):**
    *   تحتوي على الشاشات (Screens) والودجت (Widgets).
    *   تتواصل مع الـ Logic عبر الـ Controllers/Providers.
2.  **Domain Layer (النطاق):**
    *   تحتوي على الكيانات (Entities) وقواعد العمل (Use Cases).
    *   مستقلة تمامًا عن أي مكتبات خارجية أو قواعد بيانات.
3.  **Data Layer (البيانات):**
    *   تحتوي على النماذج (Models) ومصادر البيانات (Data Sources: API/Firebase).
    *   المستودعات (Repositories) التي تنفذ الواجهات المعرفة في الـ Domain.

```
lib/
├── src/
│   ├── core/           # المكونات المشتركة (Theme, Utils, Constants)
│   ├── features/       # الميزات مقسمة حسب الوظيفة
│   │   ├── auth/       # المصادقة
│   │   ├── dashboard/  # لوحات التحكم
│   │   ├── behavior/   # السلوك والمتابعة
│   │   ├── academic/   # التحصيل والاختبارات
│   │   └── communication/ # التواصل والإشعارات
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   └── main.dart
```

## 3. تصميم قاعدة البيانات (Database Schema)
سنستخدم هيكلية علائقية (Relational) سواء عبر SQL أو NoSQL (مع مراجع).

### الجداول الرئيسية (Entities):

1.  **Users (المستخدمون):**
    *   `id`: UUID
    *   `name`: String
    *   `role`: Enum (admin, teacher, student, parent)
    *   `email/phone`: String
    *   `password_hash`: String

2.  **Classes (الفصول):**
    *   `id`: UUID
    *   `name`: String (e.g., 1/A)
    *   `grade_level`: Int

3.  **Subjects (المواد):**
    *   `id`: UUID
    *   `name`: String (e.g., Math)

4.  **Schedule (الجدول الدراسي):**
    *   `id`: UUID
    *   `class_id`: FK -> Classes
    *   `teacher_id`: FK -> Users
    *   `subject_id`: FK -> Subjects
    *   `day_of_week`: Enum
    *   `period_number`: Int
    *   `start_time`: Time
    *   `end_time`: Time

5.  **Attendance (الحضور والغياب):**
    *   `id`: UUID
    *   `student_id`: FK -> Users
    *   `date`: Date
    *   `status`: Enum (present, absent, late)
    *   `arrival_time`: Timestamp (للمتأخرين)

6.  **BehaviorRecords (سجل السلوك):**
    *   `id`: UUID
    *   `student_id`: FK -> Users
    *   `teacher_id`: FK -> Users
    *   `type`: Enum (positive, negative, bathroom, escape)
    *   `description`: String
    *   `points`: Int (+/-)
    *   `timestamp`: DateTime
    *   `bathroom_exit_time`: DateTime? (لحالات الخروج)
    *   `bathroom_return_time`: DateTime?

7.  **Assignments/Exams (الواجبات والاختبارات):**
    *   `id`: UUID
    *   `teacher_id`: FK -> Users
    *   `class_id`: FK -> Classes
    *   `title`: String
    *   `type`: Enum (homework, quiz, midterm, final)
    *   `due_date`: DateTime

## 4. المنطق التلقائي (Business Logic)

### أ. التأخير الصباحي (Morning Lateness)
*   **المدخل:** وقت تسجيل الدخول عند البوابة (QR Code أو يدوي).
*   **القاعدة:** إذا كان `arrival_time` > `school_start_time`:
    *   الحالة = "Late".
    *   يتم خصم نقاط من "شريط السلوك".
    *   إشعار لولي الأمر: "ابنك وصل متأخرًا في الساعة X".

### ب. الخروج لدورة المياه (Bathroom Pass)
*   **الإجراء:** المعلم يضغط "خروج طالب".
*   **النظام:**
    1.  يسجل `bathroom_exit_time` = `Now()`.
    2.  يبدأ عداد (Timer) في الخلفية (أو يعتمد على فرق الوقت عند العودة).
*   **العودة:** المعلم يضغط "عودة طالب".
    *   يحسب الفرق: `duration` = `Now()` - `bathroom_exit_time`.
    *   إذا `duration` > 5 دقائق:
        *   يسجل مخالفة تلقائية "تأخر في دورة المياه".
        *   يخصم نقاط.
    *   إذا `duration` <= 5 دقائق:
        *   سجل عادي (بدون خصم).

### ج. الهروب من الحصة (Class Escape)
*   **الشرط:** طالب خرج لدورة المياه ولم يعد خلال 15 دقيقة، أو انتهت الحصة وهو لم يعد.
*   **النظام:** وظيفة مجدولة (Scheduled Job) أو فحص عند نهاية الحصة.
*   **الإجراء:**
    *   تغيير الحالة إلى "هروب".
    *   خصم نقاط كبير (مثلاً -10).
    *   إشعار فوري لولي الأمر والإدارة.
    *   تلوين الحالة بالأحمر في لوحة المعلم.

## 5. واجهة المستخدم وتجربة المستخدم (UI/UX)

### الألوان المقترحة:
*   **الأساسي:** الأزرق الداكن (Professional/Trust) - للإدارة والمعلمين.
*   **الثانوي:** البرتقالي/الأصفر (Energy/Warning) - للتنبيهات.
*   **الطلاب:** ألوان فاتحة ومحفزة (Gamification style).
*   **شريط السلوك:** متدرج (أخضر -> أصفر -> أحمر).

### الشاشات (Screens):
*   **Admin:** Dashboard (Stats), Users Management, Schedule Builder.
*   **Teacher:** Class View (Grid of students), Student Profile (Quick Action Buttons: Behavior, Bathroom), Exams Creator.
*   **Student:** Home (Behavior Bar), Assignments List, Exams.
*   **Parent:** Kids List, Child Dashboard (Reports), Chat.

## 6. مراحل التنفيذ (Roadmap)

### Phase 1: MVP (الحد الأدنى للمنتج)
*   تسجيل الدخول والأدوار.
*   إدارة الفصول والطلاب (Admin).
*   رصد السلوك والحضور (Teacher).
*   لوحة الطالب (عرض النقاط).

### Phase 2: Communication & Academics
*   الواجبات والاختبارات.
*   الشات بين الولي والمعلم.
*   الإشعارات (Push Notifications).

### Phase 3: Advanced Automation
*   المنطق التلقائي المعقد (Timer دورة المياه، الهروب).
*   التقارير التحليلية والرسوم البيانية.
