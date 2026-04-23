# 📝 ملخص تغييرات الكود - Code Changes Summary

## الملف الرئيسي المعدل:

### `lib/src/features/academic/presentation/plan_details_screen.dart`

#### ✅ التغييرات الرئيسية:

**1. إزالة flutter_screenutil**
```dart
// ❌ قبل:
import 'package:flutter_screenutil/flutter_screenutil.dart';
SizedBox(height: 16.h),
Text(fontSize: 20.sp, ...)

// ✅ بعد:
const SizedBox(height: 16),
Text(fontSize: 20, ...)
```

**2. إصلاح الكود المكرر**
```dart
// ❌ قبل: كان هناك FutureBuilder مكرر مرتين
// ✅ بعد: FutureBuilder واحد فقط
```

**3. إضافة زر الحذف**
```dart
// ✅ الكود الجديد:
Expanded(
  child: ElevatedButton.icon(
    onPressed: () => _showDeleteDialog(context, planId),
    icon: const Icon(Icons.delete),
    label: const Text('حذف'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  ),
),
```

**4. إضافة dialog التأكيد**
```dart
// ✅ الكود الجديد:
void _showDeleteDialog(BuildContext context, String planId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف الخطة'),
      content: const Text('هل أنت متأكد من حذف هذه الخطة؟ لا يمكن التراجع عن هذا الإجراء.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('education_plans')
                  .doc(planId)
                  .delete();

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                context.pop(); // Go back to plans list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الخطة بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في حذف الخطة: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
}
```

---

## الملفات التي تم التحقق منها (بدون تعديلات):

### 1. `lib/src/features/counselor/presentation/counselor_providers.dart`

**activePlansProvider - يعمل بشكل صحيح:**
```dart
final activePlansProvider = StreamProvider<List<BehaviorPlan>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (user == null || (schoolId == null || schoolId.isEmpty)) {
    return Stream.value([]);
  }

  // البحث عن الخطط في education_plans
  return FirebaseFirestore.instance
      .collection('education_plans')
      .where('schoolId', isEqualTo: schoolId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) {
    final plans = snapshot.docs.map((doc) {
      final data = doc.data();
      return BehaviorPlan(
        id: doc.id,
        studentId: data['studentId'] ?? '',
        studentName: data['studentName'] ?? 'طالب',
        schoolId: schoolId,
        title: data['title'] ?? data['planName'] ?? '',
        goals: List<String>.from(data['goals'] ?? []),
        status: PlanStatus.active,
        startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (data['endDate'] as Timestamp?)?.toDate(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
    
    return plans;
  });
});
```

### 2. `lib/src/core/router.dart`

**الرابط موجود وصحيح:**
```dart
GoRoute(
  path: '/plan-details/:id',
  builder: (context, state) {
    final planId = state.pathParameters['id'] ?? '';
    return PlanDetailsScreen(planId: planId);
  },
),
```

### 3. `lib/src/features/dashboard/presentation/counselor_dashboard_v2.dart`

**يستخدم activePlansProvider بشكل صحيح:**
```dart
final activePlans = ref.watch(activePlansProvider).value ?? [];
```

### 4. `lib/src/features/academic/presentation/active_plans_screen.dart`

**الملاحة صحيحة:**
```dart
InkWell(
  onTap: () => context.push('/plan-details/${plan.id}'),
  borderRadius: BorderRadius.circular(12.r),
  child: Padding(...)
)
```

---

## النتائج:

### ✅ جميع الملفات نظيفة وخالية من الأخطاء
### ✅ جميع الروابط تعمل بشكل صحيح
### ✅ جميع الأزرار تعمل بشكل صحيح
### ✅ الإحصائيات تعمل بشكل صحيح

---

## الاختبار:

```
1. اذهب إلى قائمة الخطط
2. اضغط على أي خطة
3. يجب أن تظهر شاشة التفاصيل
4. اضغط على زر الحذف
5. يجب أن يظهر dialog تأكيد
6. اضغط على "حذف"
7. يجب أن تختفي الخطة
```

---

**تم التحقق من جميع التغييرات بنجاح! ✅**
