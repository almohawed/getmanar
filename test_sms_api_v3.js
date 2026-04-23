// اختبار Mobile.net.sa API - النسخة الصحيحة!
const axios = require('axios');

const apiToken = 'h7VWoDJhyRjGAc0TNzyhvAWN9G1WH4URP1HCx0eJf59a988a';
const apiUrl = 'https://app.mobile.net.sa/api/v1/send';

console.log('🎯 اختبار مع الحقول الصحيحة...\n');

async function testCorrectFormat() {
    try {
        const response = await axios.post(apiUrl, {
            number: '966566110830',  // number بدلاً من numbers
            senderName: 'Schooli',    // اسم المرسل الصحيح من الصورة
            sendAtOption: 'now',      // خيار وقت الإرسال
            messageBody: 'رسالة اختبار من منار'  // messageBody بدلاً من msg
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiToken}`
            },
            timeout: 30000
        });
        
        console.log('✅ نجح الإرسال!');
        console.log('\n📥 الرد من Mobile.net.sa:');
        console.log(JSON.stringify(response.data, null, 2));
        
        return true;
    } catch (error) {
        console.log('❌ فشل الإرسال!');
        console.log('Status:', error.response?.status);
        console.log('Data:', JSON.stringify(error.response?.data, null, 2));
        return false;
    }
}

testCorrectFormat();
