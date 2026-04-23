// اختبار Mobile.net.sa API - نسخة 2 (طرق مختلفة)
const axios = require('axios');

const apiToken = 'h7VWoDJhyRjGAc0TNzyhvAWN9G1WH4URP1HCx0eJf59a988a';
const apiUrl = 'https://app.mobile.net.sa/api/v1/send';
const phoneNumber = '966566110830';
const message = 'رسالة اختبار من منار';
const senderName = 'المدرسة';

console.log('🧪 اختبار طرق مختلفة للإرسال...\n');

// الطريقة 1: userName في Body
async function method1() {
    console.log('📌 الطريقة 1: userName في Body');
    try {
        const response = await axios.post(apiUrl, {
            userName: apiToken,
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: { 'Content-Type': 'application/json' },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// الطريقة 2: Authorization Header
async function method2() {
    console.log('\n📌 الطريقة 2: Authorization Bearer Token');
    try {
        const response = await axios.post(apiUrl, {
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiToken}`
            },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// الطريقة 3: API Key في Header
async function method3() {
    console.log('\n📌 الطريقة 3: API-Key في Header');
    try {
        const response = await axios.post(apiUrl, {
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: {
                'Content-Type': 'application/json',
                'API-Key': apiToken
            },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// الطريقة 4: token في Body
async function method4() {
    console.log('\n📌 الطريقة 4: token في Body');
    try {
        const response = await axios.post(apiUrl, {
            token: apiToken,
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: { 'Content-Type': 'application/json' },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// الطريقة 5: apiKey في Body
async function method5() {
    console.log('\n📌 الطريقة 5: apiKey في Body');
    try {
        const response = await axios.post(apiUrl, {
            apiKey: apiToken,
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: { 'Content-Type': 'application/json' },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// الطريقة 6: GET مع Query Parameters
async function method6() {
    console.log('\n📌 الطريقة 6: GET مع Query Parameters');
    try {
        const response = await axios.get(apiUrl, {
            params: {
                userName: apiToken,
                numbers: phoneNumber,
                userSender: senderName,
                msg: message,
                msgEncoding: 'UTF8'
            },
            timeout: 30000
        });
        console.log('✅ نجح!', response.data);
        return true;
    } catch (error) {
        console.log('❌ فشل:', error.response?.status, error.response?.data);
        return false;
    }
}

// تشغيل جميع الطرق
async function testAll() {
    const methods = [method1, method2, method3, method4, method5, method6];
    
    for (let i = 0; i < methods.length; i++) {
        const success = await methods[i]();
        if (success) {
            console.log(`\n🎉 الطريقة ${i + 1} نجحت! استخدم هذه الطريقة.`);
            return;
        }
        await new Promise(resolve => setTimeout(resolve, 1000)); // انتظر ثانية بين المحاولات
    }
    
    console.log('\n😔 جميع الطرق فشلت. يرجى التحقق من:');
    console.log('  1. صحة API Token');
    console.log('  2. تفعيل الحساب في Mobile.net.sa');
    console.log('  3. صلاحيات API');
    console.log('  4. الرصيد المتاح');
}

testAll();
