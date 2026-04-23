// اختبار مباشر لـ Mobile.net.sa API
const axios = require('axios');

async function testMobileNetSA() {
    const apiUrl = 'https://app.mobile.net.sa/api/v1/send';
    const userName = 'h7VWoDJhyRjGAc0TNzyhvAWN9G1WH4URP1HCx0eJf59a988a';  // API Token الصحيح
    const phoneNumber = '966566110830';  // رقم الاختبار (بدون +)
    const message = 'رسالة اختبار من منار';
    const senderName = 'المدرسة';

    console.log('🔍 اختبار Mobile.net.sa API...\n');
    console.log('📊 البيانات المرسلة:');
    console.log('  - API URL:', apiUrl);
    console.log('  - userName:', userName);
    console.log('  - numbers:', phoneNumber);
    console.log('  - userSender:', senderName);
    console.log('  - msg:', message);
    console.log('\n⏳ جاري الإرسال...\n');

    try {
        const response = await axios.post(apiUrl, {
            userName: userName,
            numbers: phoneNumber,
            userSender: senderName,
            msg: message,
            msgEncoding: 'UTF8'
        }, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: 30000
        });

        console.log('✅ نجح الإرسال!');
        console.log('\n📥 الرد من Mobile.net.sa:');
        console.log(JSON.stringify(response.data, null, 2));
        
        if (response.data.code === '100' || response.data.code === 100) {
            console.log('\n🎉 الرسالة أُرسلت بنجاح!');
        } else {
            console.log('\n⚠️ تحذير: الكود ليس 100');
            console.log('الكود المستلم:', response.data.code);
            console.log('الرسالة:', response.data.message || response.data.msg);
        }

    } catch (error) {
        console.log('❌ فشل الإرسال!');
        console.log('\n🔍 تفاصيل الخطأ:');
        
        if (error.response) {
            console.log('  - Status:', error.response.status);
            console.log('  - Status Text:', error.response.statusText);
            console.log('  - Data:', JSON.stringify(error.response.data, null, 2));
            
            if (error.response.status === 401) {
                console.log('\n⚠️ خطأ 401: Unauthenticated');
                console.log('💡 الحلول المحتملة:');
                console.log('  1. تحقق من أن userName صحيح: ' + userName);
                console.log('  2. تحقق من أن الحساب مفعل في Mobile.net.sa');
                console.log('  3. تحقق من صلاحيات API');
                console.log('  4. جرب تسجيل الدخول إلى Mobile.net.sa للتأكد');
            }
        } else if (error.request) {
            console.log('  - لم يتم استلام رد من الخادم');
            console.log('  - تحقق من الاتصال بالإنترنت');
        } else {
            console.log('  - Error:', error.message);
        }
    }
}

// تشغيل الاختبار
testMobileNetSA();
