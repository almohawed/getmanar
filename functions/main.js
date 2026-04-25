/**
 * main.js — نقطة الدخول الرئيسية
 * يجمع index.js + seed_omar.js
 */

// استيراد كل الـ functions الأصلية
Object.assign(exports, require('./index.js'));

// استيراد seed function المؤقتة
Object.assign(exports, require('./seed_omar.js'));
