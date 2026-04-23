import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as https from 'https';
import * as querystring from 'querystring';

// Initialize if needed
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

// --- Helper: Send HTTPS Request ---
function sendSmsRequest(url: string, method: string, headers: any, body: any): Promise<any> {
    return new Promise((resolve, reject) => {
        try {
            const urlObj = new URL(url);
            const options: https.RequestOptions = {
                hostname: urlObj.hostname,
                path: urlObj.pathname + urlObj.search,
                method: method,
                headers: headers
            };

            const req = https.request(options, (res) => {
                let data = '';
                res.on('data', (chunk) => data += chunk);
                res.on('end', () => {
                    if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                        try {
                            resolve(JSON.parse(data));
                        } catch (e) {
                            resolve(data); // Return text if not JSON
                        }
                    } else {
                        reject(new Error(`HTTP Error ${res.statusCode}: ${data}`));
                    }
                });
            });

            req.on('error', (e) => reject(e));
            if (body) {
                req.write(body);
            }
            req.end();
        } catch (e) {
            reject(e);
        }
    });
}

// 1. Trigger: Send SMS on Creation
export const onSmsCreated = functions.firestore
    .document('Schools/{schoolId}/SmsOutbox/{messageId}')
    .onCreate(async (snap, context) => {
        const msg = snap.data();
        
        // Only process queued messages
        if (msg.status !== 'queued') return;

        // Retry Policy Check: If attemptCount > 3, do not try.
        const attempts = msg.attemptCount || 0;
        if (attempts > 3) {
            console.log(`Skipping SMS ${context.params.messageId}: Max attempts reached.`);
            return snap.ref.update({ status: 'failed', error: 'Max attempts reached' });
        }

        const schoolId = context.params.schoolId;
        const msgId = context.params.messageId;

        // A. Read Public Settings
        const settingsDoc = await db.doc(`Schools/${schoolId}/Settings/sms`).get();
        if (!settingsDoc.exists || !settingsDoc.data()?.enabled) {
            console.log(`SMS Disabled for School ${schoolId}`);
            return snap.ref.update({ 
                status: 'failed', 
                error: 'SMS service is disabled in settings',
                attemptCount: admin.firestore.FieldValue.increment(1) 
            });
        }
        
        const { apiBaseUrl, senderId, mode } = settingsDoc.data()!;
        // Default mode to 'json_bearer' if not set, for backward compatibility or safety
        const safeMode = mode || 'json_bearer';

        if (!apiBaseUrl) {
             return snap.ref.update({ 
                 status: 'failed', 
                 error: 'Missing apiBaseUrl', 
                 attemptCount: admin.firestore.FieldValue.increment(1) 
            });
        }

        // B. Read Private API Key
        const privateDoc = await db.doc(`Schools/${schoolId}/Private/sms`).get();
        if (!privateDoc.exists || !privateDoc.data()?.apiKey) {
             return snap.ref.update({ 
                 status: 'failed', 
                 error: 'Missing API Key', 
                 attemptCount: admin.firestore.FieldValue.increment(1) 
            });
        }
        const apiKey = privateDoc.data()!.apiKey;

        // C. Send Request based on Mode
        try {
            let requestUrl = apiBaseUrl;
            let requestMethod = 'POST';
            let requestHeaders: any = {};
            let requestBody: any = null;

            const phoneNumber = msg.phoneNumber; // Single number
            const messageBody = msg.body;

            if (safeMode === 'json_bearer') {
                // JSON Body + Bearer Token
                requestMethod = 'POST';
                requestHeaders = {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                };
                requestBody = JSON.stringify({
                    to: phoneNumber,
                    message: messageBody,
                    sender: senderId
                });

            } else if (safeMode === 'form_header') {
                // Form URL Encoded Body + Header Auth
                requestMethod = 'POST';
                requestHeaders = {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Authorization': `Bearer ${apiKey}` // Defaulting to Bearer for Header
                };
                requestBody = querystring.stringify({
                    to: phoneNumber,
                    message: messageBody,
                    sender: senderId
                });

            } else if (safeMode === 'get_query') {
                // GET with Query Params (API Key in Query)
                requestMethod = 'GET';
                const params = new URLSearchParams();
                params.append('to', phoneNumber);
                params.append('message', messageBody);
                params.append('sender', senderId);
                params.append('apiKey', apiKey); // Key in query as requested
                
                // Append to URL
                const hasQuery = requestUrl.includes('?');
                requestUrl = `${requestUrl}${hasQuery ? '&' : '?'}${params.toString()}`;
            } else {
                throw new Error(`Unsupported SMS mode: ${safeMode}`);
            }

            console.log(`Sending SMS ${msgId} to ${phoneNumber} via ${safeMode}`);
            
            const response = await sendSmsRequest(requestUrl, requestMethod, requestHeaders, requestBody);
            
            console.log(`SMS Sent:`, response);

            // D. Update Success
            await snap.ref.update({
                status: 'sent',
                sentAt: admin.firestore.Timestamp.now(),
                providerMessageId: response.id || response.messageId || 'unknown',
                attemptCount: admin.firestore.FieldValue.increment(1),
                error: null
            });

        } catch (error: any) {
            console.error(`SMS Failed ${msgId}:`, error);
            
            await snap.ref.update({
                status: 'failed',
                error: error.message || 'Unknown error',
                attemptCount: admin.firestore.FieldValue.increment(1)
            });
        }
    });

// 2. Callable: Save SMS Settings (Admin Only)
export const saveSmsSettings = functions.https.onCall(async (data, context) => {
    // A. Auth Check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const { schoolId, apiBaseUrl, senderId, enabled, apiKey, mode } = data;
    const uid = context.auth.uid;

    if (!schoolId || !apiBaseUrl || !senderId || !mode) {
         throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    if (!['json_bearer', 'form_header', 'get_query'].includes(mode)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid mode');
    }

    // B. Role Check (Admin/Manager)
    const staffDoc = await db.collection('Schools').doc(schoolId).collection('Staff').doc(uid).get();
    
    if (!staffDoc.exists) {
         throw new functions.https.HttpsError('permission-denied', 'User not found in staff');
    }
    
    const role = staffDoc.data()?.role;
    if (!['manager', 'admin', 'principal'].includes(role)) {
         throw new functions.https.HttpsError('permission-denied', 'User is not an admin');
    }

    // C. Save Public Settings
    await db.doc(`Schools/${schoolId}/Settings/sms`).set({
        apiBaseUrl,
        senderId,
        mode,
        enabled: enabled === true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid
    }, { merge: true });

    // D. Save Private API Key (Encrypted/Protected)
    if (apiKey) {
        await db.doc(`Schools/${schoolId}/Private/sms`).set({
            apiKey: apiKey,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: uid
        }, { merge: true });
    }

    return { success: true };
});

// 3. Callable: Test SMS (Admin Only)
export const testSms = functions.https.onCall(async (data, context) => {
    // A. Auth Check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const { schoolId } = data;
    const uid = context.auth.uid;

    if (!schoolId) {
         throw new functions.https.HttpsError('invalid-argument', 'Missing schoolId');
    }

    // B. Role Check & Get Phone Number
    const staffDoc = await db.collection('Schools').doc(schoolId).collection('Staff').doc(uid).get();
    if (!staffDoc.exists) {
         throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    const staffData = staffDoc.data()!;
    const role = staffData.role;

    if (!['manager', 'admin', 'principal'].includes(role)) {
         throw new functions.https.HttpsError('permission-denied', 'User is not an admin');
    }

    const phoneNumber = staffData.phoneNumber;
    if (!phoneNumber) {
        throw new functions.https.HttpsError('failed-precondition', 'User does not have a phone number');
    }

    // C. Create SMS in Outbox (This will trigger onSmsCreated)
    // We use the outbox pattern so we test the FULL flow (Trigger -> Provider)
    const messageId = db.collection('Schools').doc(schoolId).collection('SmsOutbox').doc().id;
    
    await db.collection('Schools').doc(schoolId).collection('SmsOutbox').doc(messageId).set({
        id: messageId,
        body: 'This is a test message from AlMadrasah system.',
        recipientId: uid,
        phoneNumber: phoneNumber,
        status: 'queued',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: uid,
        metadata: { type: 'test' }
    });

    return { success: true, messageId };
});
