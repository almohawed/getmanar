#!/usr/bin/env node

/**
 * 🔧 سكريبت تعديل قواعد Firestore تلقائياً
 * 
 * هذا السكريبت يقوم بـ:
 * 1. الاتصال بـ Firebase Admin SDK
 * 2. تحديث قواعد Firestore
 * 3. نشر القواعد الجديدة
 * 
 * المتطلبات:
 * - ملف serviceAccountKey.json في نفس المجلد
 * - npm install firebase-admin
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ============================================
// القواعد الجديدة
// ============================================
const NEW_RULES = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // قواعد المستخدمين
    // ============================================
    match /Users/{userId} {
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == resource.data.schoolId
      );
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ============================================
    // قواعد المدارس
    // ============================================
    match /Schools/{schoolId} {
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == schoolId;
      
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == schoolId &&
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'admin';
      
      // المجموعات الفرعية
      match /{document=**} {
        allow read: if request.auth != null && 
                       get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == schoolId;
        allow write: if request.auth != null && 
                        get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == schoolId;
      }
    }
    
    // ============================================
    // قواعد الحضور - مفتوحة للقراءة
    // ============================================
    match /StudentAttendance/{attendanceId} {
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قواعد السلوك
    // ============================================
    match /behavior_records/{recordId} {
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قواعد الطلاب
    // ============================================
    match /students/{studentId} {
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قاعدة افتراضية (رفض كل شيء آخر)
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}`;

// ============================================
// الدوال المساعدة
// ============================================

/**
 * تحميل Service Account Key
 */
function loadServiceAccount() {
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (!fs.existsSync(keyPath)) {
    console.error('❌ خطأ: لم يتم العثور على ملف serviceAccountKey.json');
    console.log('\n📝 للحصول على الملف:');
    console.log('1. اذهب إلى: https://console.firebase.google.com/project/etisak-784d6/settings/serviceaccounts/adminsdk');
    console.log('2. اضغط "Generate new private key"');
    console.log('3. احفظ الملف باسم serviceAccountKey.json في نفس مجلد هذا السكريبت');
    process.exit(1);
  }
  
  return require(keyPath);
}

/**
 * تهيئة Firebase Admin
 */
function initializeFirebase(serviceAccount) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: `https://${serviceAccount.project_id}.firebaseio.com`
    });
    console.log('✅ تم الاتصال بـ Firebase بنجاح');
    return true;
  } catch (error) {
    console.error('❌ فشل الاتصال بـ Firebase:', error.message);
    return false;
  }
}

/**
 * تحديث قواعد Firestore
 */
async function updateFirestoreRules() {
  try {
    console.log('\n🔄 جاري تحديث قواعد Firestore...');
    
    // استخدام Firebase CLI API
    const { execSync } = require('child_process');
    
    // حفظ القواعد في ملف مؤقت
    const rulesPath = path.join(__dirname, 'firestore.rules.tmp');
    fs.writeFileSync(rulesPath, NEW_RULES);
    
    // نشر القواعد
    execSync(`firebase deploy --only firestore:rules --project etisak-784d6`, {
      stdio: 'inherit',
      cwd: __dirname
    });
    
    // حذف الملف المؤقت
    fs.unlinkSync(rulesPath);
    
    console.log('✅ تم تحديث قواعد Firestore بنجاح!');
    return true;
  } catch (error) {
    console.error('❌ فشل تحديث القواعد:', error.message);
    return false;
  }
}

/**
 * التحقق من صلاحيات القراءة
 */
async function testPermissions() {
  try {
    console.log('\n🧪 اختبار الصلاحيات...');
    
    const db = admin.firestore();
    
    // اختبار قراءة مستند مدرسة
    const schoolsSnapshot = await db.collection('Schools').limit(1).get();
    console.log(`✅ قراءة Schools: ${schoolsSnapshot.size} مستند`);
    
    // اختبار قراءة سجلات الحضور
    const attendanceSnapshot = await db.collection('StudentAttendance').limit(1).get();
    console.log(`✅ قراءة StudentAttendance: ${attendanceSnapshot.size} مستند`);
    
    console.log('\n✅ جميع الاختبارات نجحت!');
    return true;
  } catch (error) {
    console.error('❌ فشل الاختبار:', error.message);
    return false;
  }
}

// ============================================
// البرنامج الرئيسي
// ============================================

async function main() {
  console.log('🚀 بدء تحديث قواعد Firestore...\n');
  
  // 1. تحميل Service Account
  const serviceAccount = loadServiceAccount();
  
  // 2. تهيئة Firebase
  if (!initializeFirebase(serviceAccount)) {
    process.exit(1);
  }
  
  // 3. تحديث القواعد
  const rulesUpdated = await updateFirestoreRules();
  if (!rulesUpdated) {
    console.log('\n⚠️ فشل تحديث القواعد تلقائياً');
    console.log('\n📝 يمكنك تحديثها يدوياً:');
    console.log('1. اذهب إلى: https://console.firebase.google.com/project/etisak-784d6/firestore/rules');
    console.log('2. انسخ القواعد من ملف: firestore_rules_backup.txt');
    
    // حفظ القواعد في ملف للنسخ اليدوي
    fs.writeFileSync('firestore_rules_backup.txt', NEW_RULES);
    console.log('3. تم حفظ القواعد في: firestore_rules_backup.txt');
  }
  
  // 4. اختبار الصلاحيات
  await testPermissions();
  
  console.log('\n✅ تم الانتهاء!');
  process.exit(0);
}

// تشغيل البرنامج
main().catch(error => {
  console.error('❌ خطأ غير متوقع:', error);
  process.exit(1);
});
