# 🏛 نظام الوارد الإداري - الهيكل الكامل

## ✅ ما تم إنجازه

### 1. Domain Models
- ✅ `lib/src/features/inbox/domain/transaction.dart`
  - Transaction (المعاملة الكاملة)
  - TransactionType (مالية، إدارية، طلابية، تعميم، شكوى)
  - TransactionStatus (5 حالات)
  - TransactionPriority (4 مستويات)
  - TransactionLog (سجل الحركة)
  - InboxStatistics (إحصائيات الوارد)
  - AdministrativeAnalysis (التحليل الإداري)
  - WorkloadMap (خريطة الضغط)
  - CycleHealthIndicator (مؤشر السلامة)

### 2. Services
- ✅ `lib/src/features/inbox/application/inbox_service.dart`
  - getTransactions() - جلب المعاملات
  - getStatistics() - الإحصائيات
  - getAnalysis() - التحليل الإداري
  - getWorkloadMap() - خريطة الضغط
  - getCycleHealth() - مؤشر السلامة
  - routeTransaction() - توجيه معاملة
  - closeTransaction() - إغلاق معاملة
  - escalateTransaction() - تصعيد معاملة
  - updateTransactionStatus() - تحديث الحالة
  - markAsViewed() - تسجيل المشاهدة

### 3. UI Components
- ✅ `lib/src/features/inbox/presentation/inbox_dashboard_screen.dart` - الشاشة الرئيسية
- ✅ `lib/src/features/inbox/presentation/widgets/flow_status_bar.dart` - شريط الحالة

## 📋 المكونات المتبقية (يجب إنشاؤها)

### 1. Transaction Flow Board (لوحة التدفق)
**الملف:** `lib/src/features/inbox/presentation/widgets/transaction_flow_board.dart`

**الوصف:** عرض أفقي مقسم إلى 5 أعمدة:
- 🔵 بانتظار توجيه المدير
- 🟡 تم التوجيه – قيد التنفيذ
- 🟠 تحتاج متابعة
- 🔴 متأخرة
- 🟢 مغلقة

**المميزات:**
- Drag & Drop بين الأعمدة
- كل معاملة = بطاقة تحتوي على:
  - رقم المعاملة
  - الجهة المرسلة
  - الموضوع المختصر
  - مدة البقاء
  - مستوى الأهمية
  - أيقونة النوع

**الكود المقترح:**
```dart
class TransactionFlowBoard extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction) onTransactionTap;
  final Function(Transaction, TransactionStatus) onStatusChange;

  // استخدام DragTarget و Draggable
  // تقسيم المعاملات حسب الحالة
  // عرض كل عمود بشكل منفصل
}
```

### 2. Sensitive Transactions Box (المعاملات الحساسة)
**الملف:** `lib/src/features/inbox/presentation/widgets/sensitive_transactions_box.dart`

**الوصف:** صندوق بارز يعرض:
- معاملات عاجلة
- معاملات زيارات إشرافية
- معاملات مالية
- معاملات شكاوى

**التصميم:**
- خلفية حمراء فاتحة
- أيقونة تحذير
- قائمة أفقية قابلة للتمرير

### 3. Administrative Analysis Panel (لوحة التحليل)
**الملف:** `lib/src/features/inbox/presentation/widgets/administrative_analysis_panel.dart`

**الوصف:** لوحة جانبية تعرض:
- أكثر جهة ترسل معاملات
- أكثر نوع معاملة يتأخر
- أيام الذروة
- تحليل سبب التأخير
- ملخص مكتوب بلغة إدارية

**مثال الملخص:**
> "لوحظ ارتفاع في معاملات الجهة الإشرافية بنسبة 18% هذا الأسبوع."

### 4. Workload Map Panel (خريطة الضغط)
**الملف:** `lib/src/features/inbox/presentation/widgets/workload_map_panel.dart`

**الوصف:** مخطط يوضح:
- الإدارات الأكثر ضغطاً (Bar Chart)
- الموظف الأكثر استلاماً
- الموظف الأكثر تأخيراً
- توزيع الحمل الإداري

**استخدام:** fl_chart package

### 5. Cycle Health Indicator (مؤشر السلامة)
**الملف:** `lib/src/features/inbox/presentation/widgets/cycle_health_indicator.dart`

**الوصف:** مؤشر دائري يعرض:
- سرعة التوجيه (30%)
- سرعة الإغلاق (30%)
- نسبة التأخير (20%)
- تراكم المعاملات (20%)
- التقييم النهائي: ممتاز / جيد / يحتاج تدخل

**التصميم:**
- Circular Progress Indicator
- ألوان: أخضر (ممتاز)، أصفر (جيد)، أحمر (يحتاج تدخل)

### 6. Transaction Details Dialog (نافذة التفاصيل)
**الملف:** `lib/src/features/inbox/presentation/widgets/transaction_details_dialog.dart`

**الوصف:** نافذة احترافية تحتوي على:
- تفاصيل كاملة
- المرفقات
- سجل الحركة
- من اطلع عليها
- من تأخر في تنفيذها
- أزرار القرار السريع:
  - توجيه الآن
  - إعادة توجيه
  - طلب توضيح
  - اعتماد الإغلاق
  - تصعيد

### 7. Route Transaction Dialog (نافذة التوجيه)
**الملف:** `lib/src/features/inbox/presentation/widgets/route_transaction_dialog.dart`

**الوصف:** نافذة لتوجيه المعاملة:
- اختيار الموظف
- إضافة ملاحظات
- تحديد الأولوية
- تحديد تاريخ الاستحقاق

## 🎨 التصميم العام

### الألوان:
- **الأساسي:** `Color(0xFF1565C0)` - أزرق إداري
- **الخلفية:** `Colors.grey.shade50`
- **الأحمر:** للمتأخر فقط
- **الأخضر:** للمغلق
- **الأصفر:** للمتابعة
- **البرتقالي:** للتوجيه

### الخطوط:
- العناوين: Bold, 18-20sp
- النصوص: Regular, 14-16sp
- الأرقام: Bold, 24-32sp

### المسافات:
- Padding: 16-20w
- Spacing: 12-16h
- Border Radius: 12

## 📊 البيانات المطلوبة في Firestore

### Collection Structure:
```
Schools/{schoolId}/Transactions/{transactionId}
  - id
  - schoolId
  - number
  - senderEntity
  - subject
  - description
  - type
  - status
  - priority
  - receivedAt
  - routedAt
  - closedAt
  - routedToUserId
  - routedToUserName
  - routedByUserId
  - routedByUserName
  - attachments[]
  - logs[]
  - viewedBy[]
  - isSensitive
  - notes
  - dueDate
  - createdAt
  - updatedAt
```

## 🚀 خطوات الإكمال

1. ✅ إنشاء Domain Models
2. ✅ إنشاء Services
3. ✅ إنشاء الشاشة الرئيسية
4. ✅ إنشاء شريط الحالة
5. ⏳ إنشاء لوحة التدفق (Transaction Flow Board)
6. ⏳ إنشاء صندوق المعاملات الحساسة
7. ⏳ إنشاء لوحة التحليل الإداري
8. ⏳ إنشاء خريطة الضغط
9. ⏳ إنشاء مؤشر السلامة
10. ⏳ إنشاء نافذة التفاصيل
11. ⏳ إنشاء نافذة التوجيه
12. ⏳ إضافة الروابط في لوحة المدير
13. ⏳ اختبار النظام

## 💡 ملاحظات مهمة

1. **Drag & Drop:** استخدم `Draggable` و `DragTarget` من Flutter
2. **Charts:** استخدم `fl_chart` package للرسوم البيانية
3. **Real-time:** استخدم `StreamBuilder` للتحديث الفوري
4. **Performance:** استخدم `ListView.builder` للقوائم الطويلة
5. **Responsive:** استخدم `flutter_screenutil` للتصميم المتجاوب

## 🎯 الهدف النهائي

عند الدخول، المدير يرى:
- ✅ حركة المدرسة بوضوح
- ✅ أين التكدس
- ✅ من تأخر
- ✅ ما يحتاج توقيعه
- ✅ يشعر أنه يتحكم في التدفق

**ليس صندوق بريد، بل نظام إدارة حركة إدارية.**

---

**الحالة:** الهيكل الأساسي جاهز - يحتاج إكمال المكونات المتبقية
**التاريخ:** 2 مارس 2026
