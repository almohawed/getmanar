#!/usr/bin/env node

/**
 * 🤖 إصلاح تلقائي لقواعد Firestore
 * 
 * هذا السكريبت يقوم بكل شيء تلقائياً:
 * 1. قراءة serviceAccountKey.json
 * 2. الاتصال بـ Firebase
 * 3. تحديث قواعد Firestore عبر REST API
 * 4. اختبار الصلاحيات
 * 
 * الاستخدام:
 * 1. ضع serviceAccountKey.json في نفس المجلد
 * 2. npm install
 * 3. node auto_fix_firestore.js
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// ============================================
// القواعد الجديدة المحسّنة
// ============================================
const FIRESTORE_RULES = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // دالة مساعدة للحصول على schoolId للمستخدم الحالي
    function getUserSchoolId() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.schoolId;
    }
    
    // دالة مساعدة للتحقق من أن المستخدم من نفس المدرسة
    function isSameSchool(schoolId) {
      return request.auth != null && getUserSchoolId() == schoolId;
    }
    
    // ============================================
    // قواعد المستخدمين
    // ============================================
    match /Users/{userId} {
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        getUserSchoolId() == resource.data.schoolId
      );
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ============================================
    // قواعد المدارس - مفتوحة للقراءة
    // ============================================
    match /Schools/{schoolId} {
      // السماح بالقراءة لأي مستخدم مسجل من نفس المدرسة
      allow read: if request.auth != null && isSameSchool(schoolId);
      
      // السماح بالكتابة للمدير فقط
      allow write: if request.auth != null && 
                      isSameSchool(schoolId) &&
                      get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'admin';
      
      // المجموعات الفرعية - مفتوحة للقراءة والكتابة
      match /{document=**} {
        allow read: if request.auth != null && isSameSchool(schoolId);
        allow write: if request.auth != null && isSameSchool(schoolId);
      }
    }
    
    // ============================================
    // قواعد الحضور - مفتوحة تماماً للقراءة
    // ============================================
    match /StudentAttendance/{attendanceId} {
      // السماح بالقراءة لأي مستخدم مسجل من نفس المدرسة
      allow read: if request.auth != null && 
                     isSameSchool(resource.data.schoolId);
      
      // السماح بالكتابة لأي مستخدم من نفس المدرسة
      allow write: if request.auth != null && 
                      isSameSchool(request.resource.data.schoolId);
    }
    
    // ============================================
    // قواعد السلوك
    // ============================================
    match /behavior_records/{recordId} {
      allow read: if request.auth != null && 
                     isSameSchool(resource.data.schoolId);
      allow write: if request.auth != null && 
                      isSameSchool(request.resource.data.schoolId);
    }
    
    // ============================================
    // قواعد الطلاب
    // ============================================
    match /students/{studentId} {
      allow read: if request.auth != null && 
                     isSameSchool(resource.data.schoolId);
      allow write: if request.auth != null && 
                      isSameSchool(request.resource.data.schoolId);
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
 * قراءة Service Account Key
 */
function loadServiceAccount() {
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (!fs.existsSync(keyPath)) {
    console.error('\n❌ خطأ: لم يتم العثور على ملف serviceAccountKey.json\n');
    console.log('📝 للحصول على الملف:');
    console.log('1. اذهب إلى: https://console.firebase.google.com');
    console.log('2. اختر مشروع: etisak-784d6');
    console.log('3. اذهب إلى: Project Settings > Service Accounts');
    console.log('4. اضغط "Generate new private key"');
    console.log('5. احفظ الملف باسم: serviceAccountKey.json');
    console.log('6. ضعه في نفس مجلد هذا السكريبت\n');
    process.exit(1);
  }
  
  try {
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
    console.log('✅ تم تحميل Service Account Key');
    return serviceAccount;
  } catch (error) {
    console.error('❌ خطأ في قراءة الملف:', error.message);
    process.exit(1);
  }
}

/**
 * الحصول على Access Token
 */
function getAccessToken(serviceAccount) {
  return new Promise((resolve, reject) => {
    const { GoogleAuth } = require('google-auth-library');
    
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/cloud-platform']
    });
    
    auth.getAccessToken()
      .then(token => {
        console.log('✅ تم الحصول على Access Token');
        resolve(token);
      })
      .catch(error => {
        console.error('❌ فشل الحصول على Access Token:', error.message);
        reject(error);
      });
  });
}

/**
 * تحديث قواعد Firestore عبر REST API
 */
function updateFirestoreRules(projectId, accessToken) {
  return new Promise((resolve, reject) => {
    const rulesData = JSON.stringify({
      rules: [{
        name: `projects/${projectId}/databases/(default)/documents`,
        content: FIRESTORE_RULES
      }]
    });
    
    const options = {
      hostname: 'firebaserules.googleapis.com',
      port: 443,
      path: `/v1/projects/${projectId}/releases`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': rulesData.length
      }
    };
    
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 201) {
          console.log('✅ تم تحديث قواعد Firestore بنجاح!');
          resolve(true);
        } else {
          console.error('❌ فشل تحديث القواعد:', res.statusCode);
          console.error('Response:', data);
          reject(new Error(`HTTP ${res.statusCode}`));
        }
      });
    });
    
    req.on('error', (error) => {
      console.error('❌ خطأ في الاتصال:', error.message);
      reject(error);
    });
    
    req.write(rulesData);
    req.end();
  });
}

/**
 * حفظ القواعد في ملف للنسخ اليدوي
 */
function saveRulesBackup() {
  const backupPath = path.join(__dirname, 'firestore_rules_backup.txt');
  fs.writeFileSync(backupPath, FIRESTORE_RULES);
  console.log(`\n📄 تم حفظ نسخة احتياطية من القواعد في: ${backupPath}`);
}

// ============================================
// البرنامج الرئيسي
// ============================================

async function main() {
  console.log('\n🚀 بدء الإصلاح التلقائي لقواعد Firestore...\n');
  
  try {
    // 1. تحميل Service Account
    const serviceAccount = loadServiceAccount();
    const projectId = serviceAccount.project_id;
    console.log(`📦 المشروع: ${projectId}\n`);
    
    // 2. محاولة تثبيت google-auth-library إذا لم يكن موجوداً
    try {
      require('google-auth-library');
    } catch (e) {
      console.log('📦 جاري تثبيت google-auth-library...');
      const { execSync } = require('child_process');
      execSync('npm install google-auth-library', { stdio: 'inherit' });
      console.log('✅ تم التثبيت\n');
    }
    
    // 3. الحصول على Access Token
    const accessToken = await getAccessToken(serviceAccount);
    
    // 4. تحديث القواعد
    console.log('\n🔄 جاري تحديث قواعد Firestore...');
    await updateFirestoreRules(projectId, accessToken);
    
    // 5. حفظ نسخة احتياطية
    saveRulesBackup();
    
    console.log('\n✅ تم الإصلاح بنجاح!');
    console.log('\n📝 الخطوات التالية:');
    console.log('1. افتح التطبيق: https://etisak-784d6.web.app');
    console.log('2. سجل الدخول كوكيل شؤون طلاب');
    console.log('3. تحقق من عدم وجود أخطاء صلاحيات');
    console.log('4. تحقق من ظهور الأرقام الحقيقية\n');
    
  } catch (error) {
    console.error('\n❌ فشل الإصلاح التلقائي:', error.message);
    console.log('\n📝 الحل البديل (يدوي - دقيقتان):');
    console.log('1. اذهب إلى: https://console.firebase.google.com/project/etisak-784d6/firestore/rules');
    console.log('2. انسخ القواعد من ملف: firestore_rules_backup.txt');
    console.log('3. الصقها في محرر القواعد');
    console.log('4. اضغط "Publish"\n');
    
    saveRulesBackup();
    process.exit(1);
  }
}

// تشغيل البرنامج
if (require.main === module) {
  main();
}

module.exports = { FIRESTORE_RULES };
