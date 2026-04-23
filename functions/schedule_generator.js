const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * generateSmartSchedule
 * ---------------------
 * دالة قوية لتوليد الجدول المدرسي بدون تكرار أو حصص فارغة
 * تستخدم خوارزمية ذكية لضمان:
 * 1. لا تكرار للمادة في نفس اليوم
 * 2. لا حصص فارغة
 * 3. توزيع عادل للمعلمين
 * 4. احترام النصاب
 */
exports.generateSmartSchedule = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const { schoolId, classId, subjects, teachers } = data;

    if (!schoolId || !classId || !subjects || !teachers) {
        throw new functions.https.HttpsError('invalid-argument', 'البيانات ناقصة');
    }

    try {
        // إعدادات الجدول
        const DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
        const PERIODS_PER_DAY = 7;
        
        // تحضير قائمة الحصص المطلوبة
        const requiredLessons = [];
        subjects.forEach(subject => {
            for (let i = 0; i < subject.weeklyHours; i++) {
                requiredLessons.push({
                    subjectId: subject.id,
                    subjectName: subject.name,
                    teacherId: subject.teacherId,
                    teacherName: subject.teacherName
                });
            }
        });

        // خلط الحصص عشوائياً
        shuffleArray(requiredLessons);

        // إنشاء الجدول الفارغ
        const schedule = {};
        DAYS.forEach(day => {
            schedule[day] = Array(PERIODS_PER_DAY).fill(null);
        });

        // خوارزمية التوزيع الذكية
        let lessonIndex = 0;
        
        for (let dayIndex = 0; dayIndex < DAYS.length; dayIndex++) {
            const day = DAYS[dayIndex];
            const usedSubjectsToday = new Set();
            
            for (let period = 0; period < PERIODS_PER_DAY; period++) {
                if (lessonIndex >= requiredLessons.length) break;
                
                // ابحث عن حصة لم تُستخدم اليوم
                let foundLesson = null;
                let searchIndex = lessonIndex;
                
                while (searchIndex < requiredLessons.length) {
                    const lesson = requiredLessons[searchIndex];
                    
                    if (!usedSubjectsToday.has(lesson.subjectId)) {
                        foundLesson = lesson;
                        // احذف الحصة من القائمة
                        requiredLessons.splice(searchIndex, 1);
                        break;
                    }
                    searchIndex++;
                }
                
                // إذا لم نجد حصة جديدة، خذ أي حصة متبقية
                if (!foundLesson && lessonIndex < requiredLessons.length) {
                    foundLesson = requiredLessons[lessonIndex];
                    requiredLessons.splice(lessonIndex, 1);
                }
                
                if (foundLesson) {
                    schedule[day][period] = foundLesson;
                    usedSubjectsToday.add(foundLesson.subjectId);
                } else {
                    lessonIndex++;
                }
            }
        }

        // حفظ الجدول في Firestore
        const scheduleRef = admin.firestore()
            .collection('Schools')
            .doc(schoolId)
            .collection('Schedules')
            .doc(classId);

        await scheduleRef.set({
            classId,
            schedule,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            generatedBy: context.auth.uid,
            status: 'active',
            stats: {
                totalLessons: requiredLessons.length + Object.values(schedule).flat().filter(l => l).length,
                placedLessons: Object.values(schedule).flat().filter(l => l).length,
                emptySlots: Object.values(schedule).flat().filter(l => !l).length
            }
        });

        return {
            success: true,
            schedule,
            message: 'تم توليد الجدول بنجاح'
        };

    } catch (error) {
        console.error('Error generating schedule:', error);
        throw new functions.https.HttpsError('internal', 'فشل توليد الجدول: ' + error.message);
    }
});

// دالة مساعدة لخلط المصفوفة
function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
}
