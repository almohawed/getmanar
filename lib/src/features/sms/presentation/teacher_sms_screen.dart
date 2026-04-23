import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/data/firestore_parent_repository.dart';
import '../data/firestore_sms_repository.dart';
import '../domain/sms_message.dart';

/// شاشة إرسال رسائل المخالفات للمعلم - تصميم احترافي
class TeacherSmsScreen extends ConsumerStatefulWidget {
  const TeacherSmsScreen({super.key});

  @override
  ConsumerState<TeacherSmsScreen> createState() => _TeacherSmsScreenState();
}

class _TeacherSmsScreenState extends ConsumerState<TeacherSmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // الخطوة الحالية
  int _step = 0; // 0: اختيار المخالفة، 1: اختيار الطالب، 2: معاينة وإرسال

  String? _selectedViolation;
  User? _selectedStudent;
  bool _isSending = false;
  String _searchQuery = '';
  int _dailyLimit = 10; // الحد الافتراضي
  int _sentToday = 0;
  bool _limitLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLimits());
  }

  Future<void> _loadLimits() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final teacherId = user?.id ?? '';
    if (schoolId.isEmpty || teacherId.isEmpty) return;

    try {
      // جلب الحد المخصص للمعلم من الوكيل
      final limitDoc = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('TeacherSmsLimits').doc(teacherId).get();

      final defaultLimit = limitDoc.data()?['dailyLimit'] ?? 10;

      // حساب عدد الرسائل المرسلة اليوم
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId)
          .collection('SmsOutbox')
          .where('createdBy', isEqualTo: teacherId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count().get();

      if (mounted) {
        setState(() {
          _dailyLimit = defaultLimit;
          _sentToday = snap.count ?? 0;
          _limitLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _limitLoaded = true);
    }
  }

  static const _violations = [
    // 🟢 الدرجة الأولى (بسيطة)
    _Violation('عدم الالتزام بالزي المدرسي', Icons.checkroom, Color(0xFF558B2F)),
    _Violation('عدم الالتزام بالمظهر العام', Icons.face, Color(0xFF558B2F)),
    _Violation('الحديث الجانبي أثناء الحصة', Icons.chat_bubble_outline, Color(0xFF558B2F)),
    _Violation('الأكل أو الشرب داخل الفصل', Icons.fastfood, Color(0xFF558B2F)),
    _Violation('النوم داخل الحصة', Icons.bedtime, Color(0xFF558B2F)),
    _Violation('الدخول/الخروج بدون استئذان', Icons.door_front_door, Color(0xFF558B2F)),
    _Violation('التأخر عن الحصة', Icons.access_time, Color(0xFF558B2F)),
    _Violation('عدم الالتزام بالاصطفاف', Icons.format_line_spacing, Color(0xFF558B2F)),
    _Violation('العبث أو عدم الانتباه', Icons.psychology_alt, Color(0xFF558B2F)),
    _Violation('إحضار أدوات غير مرتبطة', Icons.toys, Color(0xFF558B2F)),
    // 🟡 الدرجة الثانية (متوسطة)
    _Violation('الغش في الواجبات', Icons.content_copy, Color(0xFFE65100)),
    _Violation('نقل الواجبات من الآخرين', Icons.assignment_late, Color(0xFFE65100)),
    _Violation('إثارة الفوضى داخل الفصل', Icons.volume_up, Color(0xFFE65100)),
    _Violation('التلفظ بألفاظ غير لائقة', Icons.speaker_notes_off, Color(0xFFE65100)),
    _Violation('العبث بممتلكات المدرسة', Icons.broken_image, Color(0xFFE65100)),
    _Violation('إهمال الكتب والدفاتر', Icons.book_outlined, Color(0xFFE65100)),
    _Violation('الخروج من الحصة بدون إذن', Icons.exit_to_app, Color(0xFFE65100)),
    _Violation('الغياب عن الحصة بدون عذر', Icons.event_busy, Color(0xFFE65100)),
    _Violation('استخدام الجوال بدون إذن', Icons.phone_android, Color(0xFFE65100)),
    _Violation('إزعاج الآخرين أو التشويش', Icons.group_off, Color(0xFFE65100)),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _buildMessage(String studentName, String teacherName) {
    return 'عزيزي ولي أمر الطالب $studentName، نُحيطكم علماً بأن ابنكم قد سُجّلت بحقه مخالفة: ($_selectedViolation). نأمل المتابعة والتوجيه. المعلم: $teacherName';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          _buildHeader(context, user),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSendTab(user),
                _buildLogTab(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إشعار أولياء الأمور',
                            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                        Text('إرسال رسائل المخالفات',
                            style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: Colors.amber.shade300, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(user?.name ?? '', style: TextStyle(color: Colors.white, fontSize: 11.sp)),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // شريط الحد اليومي
                  if (_limitLoaded)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: (_sentToday >= _dailyLimit ? Colors.red : Colors.green).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sms, color: Colors.white, size: 12.sp),
                          SizedBox(width: 4.w),
                          Text(
                            '${_dailyLimit - _sentToday}/$_dailyLimit',
                            style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber.shade300,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.send, size: 18), text: 'إرسال إشعار'),
                Tab(icon: Icon(Icons.history, size: 18), text: 'السجل'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTab(User? user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مؤشر الخطوات
          _buildStepIndicator(),
          SizedBox(height: 20.h),

          // الخطوة 1: اختيار المخالفة
          _buildViolationStep(),
          SizedBox(height: 16.h),

          // الخطوة 2: اختيار الطالب
          if (_selectedViolation != null) ...[
            _buildStudentStep(user),
            SizedBox(height: 16.h),
          ],

          // الخطوة 3: معاينة وإرسال
          if (_selectedViolation != null && _selectedStudent != null) ...[
            _buildPreviewStep(user),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['اختر المخالفة', 'اختر الطالب', 'أرسل الإشعار'];
    final currentStep = _selectedViolation == null ? 0 : (_selectedStudent == null ? 1 : 2);

    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final done = i < currentStep;
        final active = i == currentStep;
        final color = done ? Colors.green : (active ? const Color(0xFF1A237E) : Colors.grey.shade300);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32.w, height: 32.h,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: active ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
                      ),
                      child: Center(
                        child: done
                            ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                            : Text('${i + 1}', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(e.value, style: TextStyle(fontSize: 10.sp, color: active ? const Color(0xFF1A237E) : Colors.grey.shade500, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done ? Colors.green : Colors.grey.shade300,
                    margin: EdgeInsets.only(bottom: 20.h),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildViolationStep() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Text('اختر نوع المخالفة', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
            ],
          ),
          SizedBox(height: 14.h),
          // تقسيم المخالفات لمجموعتين
          _buildViolationGroup('🟢 مخالفات الدرجة الأولى (بسيطة)', _violations.take(10).toList()),
          SizedBox(height: 10.h),
          _buildViolationGroup('🟡 مخالفات الدرجة الثانية (متوسطة)', _violations.skip(10).toList()),
        ],
      ),
    );
  }

  Widget _buildViolationGroup(String title, List<_Violation> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ),
        ...items.map((v) {
          final selected = _selectedViolation == v.label;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedViolation = v.label;
              _selectedStudent = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(bottom: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: selected ? v.color : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: selected ? v.color : v.color.withOpacity(0.25), width: selected ? 2 : 1),
                boxShadow: selected
                    ? [BoxShadow(color: v.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.w),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withOpacity(0.2) : v.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(v.icon, color: selected ? Colors.white : v.color, size: 18.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      v.label,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentStep(User? user) {
    final studentsAsync = ref.watch(studentsProvider);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: const Color(0xFF00695C), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(Icons.person_search, color: Colors.white, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Text('اختر الطالب', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF00695C))),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن طالب...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          SizedBox(height: 10.h),
          studentsAsync.when(
            data: (allStudents) {
              // فلترة طلاب المعلم فقط
              final teacherClassIds = (user?.assignedClassIds ?? []).toSet();
              final myStudents = teacherClassIds.isEmpty
                  ? allStudents
                  : allStudents.where((s) =>
                      (s.assignedClassIds ?? []).any(teacherClassIds.contains)).toList();

              final filtered = _searchQuery.isEmpty
                  ? myStudents
                  : myStudents.where((s) => s.name.contains(_searchQuery)).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.h),
                    child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                );
              }

              return SizedBox(
                height: 200.h,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final selected = _selectedStudent?.id == s.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStudent = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: EdgeInsets.only(bottom: 6.h),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF00695C) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: selected ? const Color(0xFF00695C) : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16.r,
                              backgroundColor: selected ? Colors.white.withOpacity(0.2) : const Color(0xFF00695C).withOpacity(0.1),
                              child: Text(s.name.isNotEmpty ? s.name[0] : '?',
                                  style: TextStyle(color: selected ? Colors.white : const Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 13.sp)),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(s.name,
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey.shade800)),
                            ),
                            if (selected) Icon(Icons.check_circle, color: Colors.white, size: 18.sp),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('خطأ: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(User? user) {
    final msg = _buildMessage(_selectedStudent!.name, user?.name ?? 'المعلم');
    final charCount = msg.length;
    final isOverLimit = charCount > 160;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, color: Colors.amber.shade300, size: 20.sp),
              SizedBox(width: 8.w),
              Text('معاينة الرسالة', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isOverLimit ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text('$charCount/160',
                    style: TextStyle(color: isOverLimit ? Colors.red.shade200 : Colors.green.shade200, fontSize: 11.sp)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(msg, style: TextStyle(color: Colors.white, fontSize: 12.sp, height: 1.6)),
          ),
          SizedBox(height: 16.h),
          // زر الإرسال
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : () => _send(user, msg),
              icon: _isSending
                  ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_rounded, size: 18.sp),
              label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال الإشعار لولي الأمر',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(User? user, String msg) async {
    if (user == null || _selectedStudent == null) return;
    final schoolId = user.schoolId ?? '';
    if (schoolId.isEmpty) return;

    // التحقق من الحد اليومي
    if (_sentToday >= _dailyLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لقد وصلت للحد اليومي ($_dailyLimit رسالة). تواصل مع الوكيل لزيادة الحد.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final repo = ref.read(smsRepositoryProvider);

      // التحقق من تفعيل الخدمة
      if (!await repo.isSmsEnabled(schoolId)) {
        throw Exception('خدمة الرسائل غير مفعّلة');
      }

      // جلب رقم ولي الأمر
      final parentRepo = ref.read(firestoreParentRepositoryProvider);
      final parents = await parentRepo.watchParents(schoolId).first;
      final parent = parents.where((p) => p.id == _selectedStudent!.parentId).firstOrNull;

      if (parent == null || (parent.phoneNumber ?? '').isEmpty) {
        throw Exception('لا يوجد رقم هاتف لولي أمر هذا الطالب');
      }

      await repo.queueMessages(schoolId, [
        SmsMessage(
          id: const Uuid().v4(),
          body: msg,
          recipientId: parent.id,
          phoneNumber: parent.phoneNumber!,
          status: SmsStatus.queued,
          createdAt: DateTime.now(),
          createdBy: user.id,
          metadata: {
            'senderName': user.name,
            'senderRole': 'teacher',
            'studentName': _selectedStudent!.name,
            'violationType': _selectedViolation,
            'type': 'violation_notice',
          },
        ),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              Text('تم إرسال الإشعار لولي أمر ${_selectedStudent!.name}'),
            ]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _selectedViolation = null;
          _selectedStudent = null;
          _sentToday++;
        });
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildLogTab(User? user) {
    final schoolId = user?.schoolId ?? '';
    final logAsync = ref.watch(smsLogProvider(schoolId));

    return logAsync.when(
      data: (all) {
        final mine = all.where((m) => m.createdBy == user?.id).toList();
        if (mine.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64.sp, color: Colors.grey.shade300),
                SizedBox(height: 12.h),
                Text('لا توجد رسائل مرسلة بعد', style: TextStyle(color: Colors.grey.shade500, fontSize: 15.sp)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: mine.length,
          itemBuilder: (_, i) {
            final msg = mine[i];
            final meta = msg.metadata ?? {};
            final studentName = meta['studentName'] ?? '';
            final violation = meta['violationType'] ?? '';
            final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'ar').format(msg.createdAt);

            Color statusColor;
            String statusLabel;
            switch (msg.status) {
              case SmsStatus.sent: statusColor = Colors.green; statusLabel = 'تم'; break;
              case SmsStatus.failed: statusColor = Colors.red; statusLabel = 'فشل'; break;
              default: statusColor = Colors.orange; statusLabel = 'انتظار';
            }

            return Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.person, color: const Color(0xFF1A237E), size: 16.sp),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                            if (violation.isNotEmpty)
                              Text(violation, style: TextStyle(fontSize: 11.sp, color: Colors.orange.shade700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(msg.body, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 11.sp, color: Colors.grey.shade400),
                      SizedBox(width: 4.w),
                      Text(dateStr, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade400)),
                      SizedBox(width: 8.w),
                      Icon(Icons.phone, size: 11.sp, color: Colors.grey.shade400),
                      SizedBox(width: 4.w),
                      Text(msg.phoneNumber, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade400)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}

class _Violation {
  final String label;
  final IconData icon;
  final Color color;
  const _Violation(this.label, this.icon, this.color);
}
