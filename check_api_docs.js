// فحص API endpoints المتاحة في Mobile.net.sa
const axios = require('axios');

const apiToken = 'h7VWoDJhyRjGAc0TNzyhvAWN9G1WH4URP1HCx0eJf59a988a';
const headers = {
    'Authorization': `Bearer ${apiToken}`,
    'Content-Type': 'application/json',
    'Accept': 'application/json'
};

async function checkAllEndpoints() {
    console.log('🔍 فحص جميع endpoints المحتملة...\n');

    const endpoints = [
        // v1
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v1/user' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v1/profile' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v1/me' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v1/messages' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v1/contacts' },
        // v2
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v2/senders' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v2/user' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/v2/send' },
        // بدون إصدار
        { method: 'GET', url: 'https://app.mobile.net.sa/api/senders' },
        { method: 'GET', url: 'https://app.mobile.net.sa/api/user' },
    ];

    for (const ep of endpoints) {
        try {
            const r = await axios({ method: ep.method, url: ep.url, headers, timeout: 8000 });
            console.log(`✅ ${ep.method} ${ep.url}`);
            console.log('   الرد:', JSON.stringify(r.data).substring(0, 200));
        } catch (e) {
            const status = e.response?.status;
            if (status !== 404) {
                // أي رد غير 404 مثير للاهتمام
                console.log(`⚠️  ${ep.method} ${ep.url}: ${status} - ${JSON.stringify(e.response?.data)}`);
            }
        }
    }

    // فحص الـ token نفسه - هل هو صالح؟
    console.log('\n🔑 فحص صلاحية الـ Token...');
    try {
        const r = await axios.post('https://app.mobile.net.sa/api/v1/send', {
            number: '966594341793',
            senderName: 'X',
            sendAtOption: 'now',
            messageBody: 'test'
        }, { headers, timeout: 10000 });
        console.log('الرد:', JSON.stringify(r.data));
    } catch (e) {
        console.log('Status:', e.response?.status);
        console.log('Data:', JSON.stringify(e.response?.data, null, 2));
        
        if (e.response?.status === 401) {
            console.log('\n❌ الـ Token غير صالح أو منتهي الصلاحية!');
        } else if (e.response?.status === 422) {
            console.log('\n✅ الـ Token صالح - المشكلة فقط في اسم المرسل');
            console.log('💡 يجب تسجيل الدخول إلى https://app.mobile.net.sa ومعرفة اسم المرسل المسجل');
        }
    }
}

checkAllEndpoints().catch(console.error);
