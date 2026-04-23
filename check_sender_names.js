// فحص أسماء المرسلين المسجلة في حساب Mobile.net.sa
const axios = require('axios');

const apiToken = 'h7VWoDJhyRjGAc0TNzyhvAWN9G1WH4URP1HCx0eJf59a988a';

async function checkSenderNames() {
    console.log('🔍 جاري فحص حساب Mobile.net.sa...\n');
    
    const headers = {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    };

    // 1. فحص معلومات الحساب
    console.log('1️⃣ فحص معلومات الحساب...');
    try {
        const r = await axios.get('https://app.mobile.net.sa/api/v1/account', { headers, timeout: 15000 });
        console.log('✅ معلومات الحساب:', JSON.stringify(r.data, null, 2));
    } catch (e) {
        console.log('❌ فشل:', e.response?.status, JSON.stringify(e.response?.data));
    }

    // 2. فحص أسماء المرسلين
    console.log('\n2️⃣ فحص أسماء المرسلين المسجلة...');
    const senderEndpoints = [
        'https://app.mobile.net.sa/api/v1/senders',
        'https://app.mobile.net.sa/api/v1/sender-names',
        'https://app.mobile.net.sa/api/v1/sender',
    ];
    for (const url of senderEndpoints) {
        try {
            const r = await axios.get(url, { headers, timeout: 10000 });
            console.log(`✅ ${url}:`, JSON.stringify(r.data, null, 2));
            break;
        } catch (e) {
            console.log(`❌ ${url}: ${e.response?.status} - ${JSON.stringify(e.response?.data)}`);
        }
    }

    // 3. فحص الرصيد
    console.log('\n3️⃣ فحص الرصيد...');
    const balanceEndpoints = [
        'https://app.mobile.net.sa/api/v1/balance',
        'https://app.mobile.net.sa/api/v1/credit',
    ];
    for (const url of balanceEndpoints) {
        try {
            const r = await axios.get(url, { headers, timeout: 10000 });
            console.log(`✅ ${url}:`, JSON.stringify(r.data, null, 2));
            break;
        } catch (e) {
            console.log(`❌ ${url}: ${e.response?.status}`);
        }
    }

    // 4. محاولة إرسال بأسماء مرسلين مختلفة
    console.log('\n4️⃣ تجربة أسماء مرسلين مختلفة...');
    const testSenders = ['SMS', 'Test', 'MASAR', 'SCHOOL', 'Masar', 'School', 'masar'];
    for (const sender of testSenders) {
        try {
            const r = await axios.post('https://app.mobile.net.sa/api/v1/send', {
                number: '966594341793',
                senderName: sender,
                sendAtOption: 'now',
                messageBody: 'اختبار'
            }, { headers, timeout: 10000 });
            console.log(`✅ نجح مع اسم المرسل: "${sender}"`);
            console.log('   الرد:', JSON.stringify(r.data));
            break;
        } catch (e) {
            const msg = e.response?.data?.message || e.response?.data?.error || JSON.stringify(e.response?.data);
            console.log(`❌ فشل "${sender}": ${e.response?.status} - ${msg}`);
        }
    }
}

checkSenderNames().catch(console.error);
