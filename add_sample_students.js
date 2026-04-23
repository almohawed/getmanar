// ملف لإضافة بيانات طلاب تجريبية إلى Firebase
// استخدم هذا الملف مع Firebase CLI أو Cloud Functions

const admin = require('firebase-admin');

// تهيئة Firebase
admin.initializeApp();

const db = admin.firestore();

// بيانات الطلاب التجريبية
const sampleStudents = [
  {
    name: 'أحمد محمد علي',
    grade: 'الصف الأول',
    className: 'أ',
    email: 'ahmed@school.com',
    phone: '0501234567',
  },
  {
    name: 'فاطمة عبدالله حسن',
    grade: 'الصف الأول',
    className: 'أ',
    email: 'fatima@school.com',
    phone: '0501234568',
  },
  {
    name: 'محمد سالم إبراهيم',
    grade: 'الصف الأول',
    className: 'ب',
    email: 'mohammad@school.com',
    phone: '0501234569',
  },
  {
    name: 'نور علي محمود',
    grade: 'الصف الثاني',
    className: 'أ',
    email: 'noor@school.com',
    phone: '0501234570',
  },
  {
    name: 'سارة خالد عمر',
    grade: 'الصف الثاني',
    className: 'ب',
    email: 'sarah@school.com',
    phone: '0501234571',
  },
  {
    name: 'علي حسن محمد',
    grade: 'الصف الثالث',
    className: 'أ',
    email: 'ali@school.com',
    phone: '0501234572',
  },
  {
    name: 'ليلى محمد أحمد',
    grade: 'الصف الثالث',
    className: 'ب',
    email: 'layla@school.com',
    phone: '0501234573',
  },
  {
    name: 'عمر إبراهيم علي',
    grade: 'الصف الرابع',
    className: 'أ',
    email: 'omar@school.com',
    phone: '0501234574',
  },
];

async function addSampleStudents() {
  try {
    console.log('🔄 جاري إضافة بيانات الطلاب التجريبية...');
    
    for (const student of sampleStudents) {
      const docRef = await db.collection('students').add({
        ...student,
        createdAt: admin.firestore.Timestamp.now(),
        behaviorStats: {
          violationCount: 0,
          positiveCount: 0,
          casesCount: 0,
          violationPoints: 0,
          positivePoints: 0,
          netScore: 0,
          behaviorCategory: 'جيد',
          lastUpdated: admin.firestore.Timestamp.now(),
        },
      });
      
      console.log(`✅ تم إضافة الطالب: ${student.name} (${docRef.id})`);
    }
    
    console.log(`✅ تم إضافة ${sampleStudents.length} طالب بنجاح`);
    process.exit(0);
  } catch (error) {
    console.error('❌ خطأ في إضافة البيانات:', error);
    process.exit(1);
  }
}

// تشغيل الدالة
addSampleStudents();
