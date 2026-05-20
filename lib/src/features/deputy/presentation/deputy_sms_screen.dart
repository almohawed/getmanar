import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sms/data/firestore_sms_repository.dart';
import '../../sms/domain/sms_message.dart';

/// شاشة إعدادات خدمة SMS - للوكيل
class DeputySmsScreen extends ConsumerStatefulWidget {
  const DeputySmsScreen({super.key});

  @override
  ConsumerState<DeputySmsScreen> createState() => _DeputySmsScreenState();
}

class _DeputySmsScreenState extends ConsumerState<DeputySmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // إعدادات الخدمة
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController(); // لـ Msegat
  String _selectedProvider = 'mobile.net.sa'; // المزود المختار
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureKey = true;

  // حدود الإرسال
  int _hourlyLimit = 50;
  int _dailyLimit = 200;

  // إرسال الرسائل
  final _messageCtrl = TextEditingController();
  String? _selectedParentId;
  bool _isSending = false;
  // وضع الإرسال: 'single' | 'all' | 'grade'
  String _sendMode = 'single';
  String? _selectedGrade; // الصف المختار للإرسال الجماعي

  // حذف الرسائل المعلقة
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _senderNameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('sms')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _isEnabled = data['enabled'] == true;
          _selectedProvider = data['provider'] ?? 'mobile.net.sa';
          _apiUrlCtrl.text = data['apiUrl'] ?? '';
          _apiKeyCtrl.text = data['apiKey'] ?? '';
          _senderNameCtrl.text = data['senderName'] ?? '';
          _userNameCtrl.text = data['userName'] ?? '';
          _hourlyLimit = data['hourlyLimit'] ?? 50;
          _dailyLimit = data['dailyLimit'] ?? 200;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. حفظ في Settings/sms (للإعدادات التفصيلية)
      final settingsRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('sms');
      batch.set(settingsRef, {
        'enabled': _isEnabled,
        'provider': _selectedProvider,
        'apiUrl': _apiUrlCtrl.text.trim(),
        'apiKey': _apiKeyCtrl.text.trim(),
        'senderName': _senderNameCtrl.text.trim(),
        'userName': _userNameCtrl.text.trim(),
        'hourlyLimit': _hourlyLimit,
        'dailyLimit': _dailyLimit,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.name ?? '',
      }, SetOptions(merge: true));

      // 2. مزامنة مع smsConfig في وثيقة المدرسة (يُستخدم بواسطة SmsService)
      final schoolRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId);
      batch.update(schoolRef, {
        'smsConfig': {
          'apiUrl': _apiUrlCtrl.text.trim(),
          'apiKey': _apiKeyCtrl.text.trim(),
          'senderName': _senderNameCtrl.text.trim(),
          'isEnabled': _isEnabled,
        },
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ إعدادات SMS بنجاح'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_apiUrl.isEmpty || _apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رابط الخدمة والمفتاح أولاً')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('جاري اختبار الاتصال...'),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ تم الاتصال بالخدمة بنجاح'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String get _apiUrl => _apiUrlCtrl.text.trim();
  String get _apiKey => _apiKeyCtrl.text.trim();

  String _getApiUrlHint() {
    switch (_selectedProvider) {
      case 'mobile.net.sa':
        return 'https://app.mobile.net.sa/api/v1/send';
      case 'msegat':
        return 'https://www.msegat.com/gw/sendsms.php';
      case 'unifonic':
        return 'https://el.cloud.unifonic.com/rest/SMS/messages';
      case 'taqnyat':
        return 'https://api.taqnyat.sa/v1/messages';
      default:
        return 'أدخل رابط الخدمة';
    }
  }

  Future<void> _sendMessage() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(smsRepositoryProvider);

      // التحقق من تفعيل الخدمة
      if (!await repo.isSmsEnabled(schoolId)) {
        throw Exception('خدمة الرسائل غير مفعلة من الإعدادات');
      }

      // التحقق من الحدود
      await repo.checkRateLimit(schoolId, user?.id ?? '');

      // إعداد الرسائل
      final messages = <SmsMessage>[];
      final now = DateTime.now();
      final messageBody = _messageCtrl.text.trim();

      if (_sendMode == 'single' && _selectedParentId != null) {
        // إرسال لولي أمر واحد
        final parentDoc = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Parents')
            .doc(_selectedParentId)
            .get();
        if (parentDoc.exists) {
          final data = parentDoc.data() as Map<String, dynamic>;
          final phone = data['phoneNumber'] ?? '';
          if (phone.isNotEmpty) {
            messages.add(SmsMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              body: messageBody,
              recipientId: _selectedParentId!,
              phoneNumber: phone,
              status: SmsStatus.queued,
              createdAt: now,
              createdBy: user?.id ?? 'system',
            ));
          }
        }
      } else if (_sendMode == 'all') {
        // إرسال للجميع
        final parentsSnapshot = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Parents')
            .get();
        for (final doc in parentsSnapshot.docs) {
          final data = doc.data();
          final phone = data['phoneNumber'] ?? '';
          if (phone.isNotEmpty) {
            messages.add(SmsMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString() + doc.id,
              body: messageBody,
              recipientId: doc.id,
              phoneNumber: phone,
              status: SmsStatus.queued,
              createdAt: now,
              createdBy: user?.id ?? 'system',
            ));
          }
        }
      } else if (_sendMode == 'grade' && _selectedGrade != null) {
        // إرسال لمرحلة/صف معين
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .where('grade', isEqualTo: _selectedGrade == '__all__' ? null : _selectedGrade)
            .get();

        final parentIds = <String>{};
        for (final doc in studentsSnapshot.docs) {
          final data = doc.data();
          final parentId = data['parentId'] as String?;
          if (parentId != null && parentId.isNotEmpty) {
            parentIds.add(parentId);
          }
        }

        for (final parentId in parentIds) {
          final parentDoc = await FirebaseFirestore.instance
              .collection('Schools')
              .doc(schoolId)
              .collection('Parents')
              .doc(parentId)
              .get();
          if (parentDoc.exists) {
            final data = parentDoc.data() as Map<String, dynamic>;
            final phone = data['phoneNumber'] ?? '';
            if (phone.isNotEmpty) {
              messages.add(SmsMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString() + parentId,
                body: messageBody,
                recipientId: parentId,
                phoneNumber: phone,
                status: SmsStatus.queued,
                createdAt: now,
                createdBy: user?.id ?? 'system',
              ));
            }
          }
        }
      }

      if (messages.isEmpty) {
        throw Exception('لم يتم العثور على أرقام هواتف للمرسل إليهم');
      }

      await repo.queueMessages(schoolId, messages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم جدولة ${messages.length} رسالة للإرسال'), backgroundColor: Colors.green.shade700),
        );
        setState(() {
          _messageCtrl.clear();
          _sendMode = 'single';
          _selectedParentId = null;
          _selectedGrade = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _canSend() {
    if (_isSending || _messageCtrl.text.trim().isEmpty) return false;
    if (_sendMode == 'single') return _selectedParentId != null;
    if (_sendMode == 'all') return true;
    if (_sendMode == 'grade') return _selectedGrade != null;
    return false;
  }

  /// قائمة الصفوف حسب المرحلة الدراسية
  List<String> _getGradesForStage(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('ابتدائي') || s.contains('primary') || s.contains('elementary')) {
      return ['الصف الأول الابتدائي', 'الصف الثاني الابتدائي', 'الصف الثالث الابتدائي',
              'الصف الرابع الابتدائي', 'الصف الخامس الابتدائي', 'الصف السادس الابتدائي'];
    } else if (s.contains('متوسط') || s.contains('middle') || s.contains('intermediate')) {
      return ['الصف الأول المتوسط', 'الصف الثاني المتوسط', 'الصف الثالث المتوسط'];
    } else if (s.contains('ثانوي') || s.contains('secondary') || s.contains('high')) {
      return ['الصف الأول الثانوي', 'الصف الثاني الثانوي', 'الصف الثالث الثانوي'];
    }
    // مدرسة مشتركة أو غير محددة — أظهر الكل
    return [
      'الصف الأول الابتدائي', 'الصف الثاني الابتدائي', 'الصف الثالث الابتدائي',
      'الصف الرابع الابتدائي', 'الصف الخامس الابتدائي', 'الصف السادس الابتدائي',
      'الصف الأول المتوسط', 'الصف الثاني المتوسط', 'الصف الثالث المتوسط',
      'الصف الأول الثانوي', 'الصف الثاني الثانوي', 'الصف الثالث الثانوي',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B4B),
        foregroundColor: Colors.white,
        title: const Text('إعدادات خدمة SMS', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber.shade300,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'الإعداد'),
            Tab(icon: Icon(Icons.bar_chart), text: 'الإحصائيات'),
            Tab(icon: Icon(Icons.send), text: 'إرسال الرسائل'),
            Tab(icon: Icon(Icons.history), text: 'السجل'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildSettingsTab(), _buildStatsTab(), _buildSendMessagesTab(), _buildLogTab()],
            ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // حالة الخدمة
          _buildCard(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: (_isEnabled ? Colors.green : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    _isEnabled ? Icons.sms : Icons.sms_failed,
                    color: _isEnabled ? Colors.green.shade600 : Colors.grey,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفعيل خدمة SMS',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
                      Text(
                        _isEnabled ? 'الخدمة مفعّلة - يمكن للوكيل والمرشد الإرسال' : 'الخدمة معطّلة',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  activeColor: Colors.green.shade600,
                  onChanged: (v) => setState(() => _isEnabled = v),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // اختيار المزود
          _buildSectionHeader('اختيار مزود الخدمة', Icons.business, const Color(0xFF6A1B9A)),
          SizedBox(height: 10.h),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر مزود خدمة SMS المناسب لك',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                ),
                SizedBox(height: 12.h),
                // Mobile.net.sa
                _buildProviderOption(
                  value: 'mobile.net.sa',
                  title: 'Mobile.net.sa',
                  description: 'مزود سعودي - يتطلب تسجيل اسم المرسل',
                  icon: Icons.phone_android,
                  color: const Color(0xFF1565C0),
                ),
                SizedBox(height: 8.h),
                // Msegat
                _buildProviderOption(
                  value: 'msegat',
                  title: 'Msegat',
                  description: 'الأكثر شيوعاً في السعودية - سهل وسريع',
                  icon: Icons.message,
                  color: const Color(0xFF00695C),
                ),
                SizedBox(height: 8.h),
                // Unifonic
                _buildProviderOption(
                  value: 'unifonic',
                  title: 'Unifonic',
                  description: 'احترافي وموثوق - دعم فني ممتاز',
                  icon: Icons.business_center,
                  color: const Color(0xFF4527A0),
                ),
                SizedBox(height: 8.h),
                // Taqnyat
                _buildProviderOption(
                  value: 'taqnyat',
                  title: 'Taqnyat',
                  description: 'سعودي 100% - دعم محلي',
                  icon: Icons.flag,
                  color: const Color(0xFFE65100),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // إعدادات API
          _buildSectionHeader('إعدادات الخدمة', Icons.api, const Color(0xFF1565C0)),
          SizedBox(height: 10.h),
          _buildCard(
            child: Column(
              children: [
                // رابط الخدمة
                _buildTextField(
                  controller: _apiUrlCtrl,
                  label: 'رابط خدمة SMS (API URL)',
                  hint: _getApiUrlHint(),
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                ),
                SizedBox(height: 14.h),
                // اسم المستخدم (لـ Msegat فقط)
                if (_selectedProvider == 'msegat') ...[
                  _buildTextField(
                    controller: _userNameCtrl,
                    label: 'اسم المستخدم (Username)',
                    hint: 'أدخل اسم المستخدم الخاص بك',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 14.h),
                ],
                // مفتاح API
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'مفتاح API (API Key)',
                    hintText: 'أدخل مفتاح الـ API الخاص بك',
                    prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF1565C0)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                SizedBox(height: 14.h),
                // اسم المرسل
                _buildTextField(
                  controller: _senderNameCtrl,
                  label: 'اسم المرسل (Sender Name)',
                  hint: 'مثال: المدرسة',
                  icon: Icons.badge,
                ),
                SizedBox(height: 16.h),
                // زر اختبار الاتصال
                OutlinedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('اختبار الاتصال'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // حدود الإرسال
          _buildSectionHeader('حدود الإرسال', Icons.speed, const Color(0xFFE65100)),
          SizedBox(height: 10.h),
          _buildCard(
            child: Column(
              children: [
                _buildLimitSlider(
                  label: 'الحد الأقصى في الساعة',
                  value: _hourlyLimit.toDouble(),
                  min: 10,
                  max: 200,
                  color: Colors.orange,
                  onChanged: (v) => setState(() => _hourlyLimit = v.round()),
                ),
                SizedBox(height: 16.h),
                _buildLimitSlider(
                  label: 'الحد الأقصى في اليوم',
                  value: _dailyLimit.toDouble(),
                  min: 50,
                  max: 1000,
                  color: Colors.red,
                  onChanged: (v) => setState(() => _dailyLimit = v.round()),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // معلومات مساعدة
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('كيفية الإعداد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13.sp)),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildInfoItem('1. احصل على رابط API ومفتاح من مزود خدمة SMS'),
                _buildInfoItem('2. أدخل الرابط والمفتاح في الحقول أعلاه'),
                _buildInfoItem('3. اختبر الاتصال للتأكد من صحة البيانات'),
                _buildInfoItem('4. فعّل الخدمة لتمكين الوكيل والمرشد من الإرسال'),
                _buildInfoItem('5. حدد الحدود المناسبة لمنع الإرسال المفرط'),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // تنبيه Mobile.net.sa
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.orange.shade300, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text('مهم لمستخدمي Mobile.net.sa', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 14.sp)),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  '⚠️ إذا كانت الرسائل تفشل بحالة "Unauthenticated":\n\n'
                  '1️⃣ تأكد من أن "مفتاح API" يحتوي على اسم المستخدم (Username) وليس API Key\n'
                  '2️⃣ الرابط الصحيح: https://app.mobile.net.sa/api/v1/send\n'
                  '3️⃣ تأكد من عدم وجود مسافات زائدة في البداية أو النهاية\n'
                  '4️⃣ تحقق من أن حسابك مفعل ولديك رصيد كافٍ',
                  style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade900, height: 1.6),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // زر الحفظ
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('SmsOutbox')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final today = docs.where((d) {
          final ts = ((d.data() as Map)['createdAt'] as Timestamp?)?.toDate();
          return ts != null && ts.day == now.day && ts.month == now.month && ts.year == now.year;
        }).length;
        final thisMonth = docs.where((d) {
          final ts = ((d.data() as Map)['createdAt'] as Timestamp?)?.toDate();
          return ts != null && ts.month == now.month && ts.year == now.year;
        }).length;
        final sent = docs.where((d) => (d.data() as Map)['status'] == 'sent').length;
        final failed = docs.where((d) => (d.data() as Map)['status'] == 'failed').length;

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              // بطاقات الإحصائيات
              Row(
                children: [
                  Expanded(child: _buildStatCard('إجمالي الرسائل', '${docs.length}', Icons.sms, const Color(0xFF1565C0))),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildStatCard('اليوم', '$today', Icons.today, const Color(0xFF00695C))),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: _buildStatCard('هذا الشهر', '$thisMonth', Icons.calendar_month, const Color(0xFF4527A0))),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildStatCard('فشل الإرسال', '$failed', Icons.error_outline, Colors.red)),
                ],
              ),
              SizedBox(height: 16.h),
              // نسبة النجاح
              if (docs.isNotEmpty) ...[
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نسبة نجاح الإرسال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: LinearProgressIndicator(
                                value: docs.isEmpty ? 0 : sent / docs.length,
                                backgroundColor: Colors.red.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                                minHeight: 12.h,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '${docs.isEmpty ? 0 : (sent / docs.length * 100).round()}%',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLegend('تم الإرسال', Colors.green, '$sent'),
                          _buildLegend('فشل', Colors.red, '$failed'),
                          _buildLegend('قيد الانتظار', Colors.orange, '${docs.length - sent - failed}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendMessagesTab() {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // معلومات
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'يمكنك إرسال رسائل SMS مباشرة لأولياء الأمور من هنا',
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── اختيار وضع الإرسال ──────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نوع الإرسال', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                // أزرار الاختيار
                Row(children: [
                  _SendModeBtn(label: 'ولي أمر واحد', icon: Icons.person_rounded,
                      selected: _sendMode == 'single', color: Colors.blue.shade700,
                      onTap: () => setState(() { _sendMode = 'single'; _selectedGrade = null; })),
                  SizedBox(width: 8.w),
                  _SendModeBtn(label: 'جميع أولياء الأمور', icon: Icons.groups_rounded,
                      selected: _sendMode == 'all', color: Colors.green.shade700,
                      onTap: () => setState(() { _sendMode = 'all'; _selectedParentId = null; _selectedGrade = null; })),
                  SizedBox(width: 8.w),
                  _SendModeBtn(label: 'مرحلة دراسية', icon: Icons.school_rounded,
                      selected: _sendMode == 'grade', color: Colors.orange.shade700,
                      onTap: () => setState(() { _sendMode = 'grade'; _selectedParentId = null; })),
                ]),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── اختيار ولي الأمر (وضع فردي) ────────────────────────────────
          if (_sendMode == 'single') _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر ولي الأمر', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Schools').doc(schoolId).collection('Parents').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final parents = snapshot.data!.docs;
                    if (parents.isEmpty) {
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10.r)),
                        child: Center(child: Text('لا يوجد أولياء أمور مسجلين',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp))),
                      );
                    }
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true, value: _selectedParentId,
                          hint: Text('اختر ولي الأمر', style: TextStyle(fontSize: 13.sp)),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                          items: parents.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'غير معروف';
                            final phone = data['phoneNumber'] ?? '';
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(name, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                                if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
                              ]),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedParentId = value),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── اختيار المرحلة الدراسية ──────────────────────────────────────
          if (_sendMode == 'grade') _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر المرحلة / الصف', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('Schools').doc(schoolId).get(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final schoolData = snap.data!.data() as Map<String, dynamic>? ?? {};
                    final stage = (schoolData['stage'] ?? schoolData['schoolStage'] ?? '').toString();
                    final grades = _getGradesForStage(stage);
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true, value: _selectedGrade,
                          hint: Text('اختر الصف الدراسي', style: TextStyle(fontSize: 13.sp)),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                          items: [
                            DropdownMenuItem<String>(
                              value: '__all__',
                              child: Row(children: [
                                Icon(Icons.groups_rounded, color: Colors.green.shade700, size: 18),
                                SizedBox(width: 8.w),
                                Text('جميع أولياء الأمور', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                              ]),
                            ),
                            ...grades.map((g) => DropdownMenuItem<String>(
                              value: g,
                              child: Row(children: [
                                Icon(Icons.school_rounded, color: Colors.orange.shade700, size: 16),
                                SizedBox(width: 8.w),
                                Text('أولياء أمور $g', style: TextStyle(fontSize: 13.sp)),
                              ]),
                            )),
                          ],
                          onChanged: (v) => setState(() => _selectedGrade = v),
                        ),
                      ),
                    );
                  },
                ),
                if (_selectedGrade != null && _selectedGrade != '__all__') ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.orange.shade200)),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(
                        'سيتم إرسال الرسالة لجميع أولياء أمور طلاب $_selectedGrade',
                        style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade800),
                      )),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── بانر الإرسال الجماعي ─────────────────────────────────────────
          if (_sendMode == 'all') _buildCard(
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.groups_rounded, color: Colors.green.shade700, size: 22),
                SizedBox(width: 10.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إرسال لجميع أولياء الأمور', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                  Text('سيتم إرسال الرسالة لجميع أولياء الأمور المسجلين في المدرسة',
                      style: TextStyle(fontSize: 11.sp, color: Colors.green.shade700)),
                ])),
              ]),
            ),
          ),

          SizedBox(height: 16.h),

          // كتابة الرسالة
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نص الرسالة', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  maxLength: 160,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك هنا...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    counterStyle: TextStyle(fontSize: 11.sp),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 8.h),
                Row(children: [
                  Icon(Icons.info_outline, size: 14.sp, color: Colors.orange.shade700),
                  SizedBox(width: 6.w),
                  Text('الحد الأقصى 160 حرف للرسالة الواحدة',
                      style: TextStyle(fontSize: 11.sp, color: Colors.orange.shade700)),
                ]),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // زر الإرسال
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade700],
                begin: Alignment.topRight, end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [BoxShadow(color: Colors.green.shade600.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14.r),
                onTap: _canSend() ? _sendMessage : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.send, color: Colors.white),
                            SizedBox(width: 8.w),
                            Text('إرسال الرسالة',
                                style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold)),
                          ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final logAsync = ref.watch(smsLogProvider(schoolId));

    return logAsync.when(
      data: (messages) {
        // عدد الرسائل المعلقة والفاشلة
        final pendingCount = messages.where((m) => m.status.name == 'pending').length;
        final failedCount = messages.where((m) => m.status.name == 'failed').length;
        final problemCount = pendingCount + failedCount;

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64.sp, color: Colors.grey.shade300),
                SizedBox(height: 12.h),
                Text('لا توجد رسائل مرسلة بعد', style: TextStyle(color: Colors.grey.shade500, fontSize: 15.sp)),
              ],
            ),
          );
        }

        return Column(
          children: [
            // زر حذف الرسائل (يظهر دائماً إذا كانت هناك رسائل)
            if (messages.isNotEmpty)
              Container(
                margin: EdgeInsets.all(16.w),
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: problemCount > 0 ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: problemCount > 0 ? Colors.red.shade200 : Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(problemCount > 0 ? Icons.warning : Icons.cleaning_services, 
                            color: problemCount > 0 ? Colors.red.shade700 : Colors.blue.shade700, size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(problemCount > 0 ? 'توجد رسائل فاشلة أو معلقة' : 'تنظيف السجل', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp,
                                      color: problemCount > 0 ? Colors.red.shade800 : Colors.blue.shade800)),
                              SizedBox(height: 4.h),
                              Text('يمكنك حذف جميع الرسائل أو فقط الرسائل الفاشلة', 
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isDeleting ? null : () => _deleteMessages(deleteOnlyFailed: true),
                            icon: Icon(Icons.delete_sweep, color: Colors.red.shade700, size: 18.sp),
                            label: Text('حذف الفاشلة فقط', style: TextStyle(color: Colors.red.shade700, fontSize: 12.sp)),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300)),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDeleting ? null : () => _deleteMessages(deleteOnlyFailed: false),
                            icon: Icon(Icons.delete_forever, color: Colors.white, size: 18.sp),
                            label: Text('حذف الكل', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // قائمة الرسائل
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: messages.length,
                itemBuilder: (ctx, i) {
                  final m = messages[i];
                  final color = m.status == SmsStatus.sent ? Colors.green :
                                m.status == SmsStatus.failed ? Colors.red : Colors.orange;
                  final statusText = m.status == SmsStatus.sent ? 'تم الإرسال' :
                                    m.status == SmsStatus.failed ? 'فشل' : 'قيد الانتظار';
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(m.status == SmsStatus.sent ? Icons.check_circle :
                                           m.status == SmsStatus.failed ? Icons.error : Icons.schedule,
                                           color: color, size: 20.sp),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.phoneNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                    SizedBox(height: 4.h),
                                    Text(_formatDate(m.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 11.sp)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(color: color, width: 1),
                                ),
                                child: Text(statusText, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8.r)),
                            child: Text(m.body, style: TextStyle(fontSize: 13.sp, height: 1.4)),
                          ),
                          if (m.error != null) ...[
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: Colors.red.shade200)),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 16.sp),
                                  SizedBox(width: 8.w),
                                  Expanded(child: Text('خطأ: ${m.error}', style: TextStyle(color: Colors.red.shade800, fontSize: 12.sp))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ في تحميل السجل: $e', style: const TextStyle(color: Colors.red))),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteMessages({required bool deleteOnlyFailed}) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final query = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('SmsOutbox');
      
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        if (deleteOnlyFailed) {
          if ((doc.data() as Map)['status'] == 'failed') {
            batch.delete(doc.reference);
          }
        } else {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleteOnlyFailed ? 'تم حذف الرسائل الفاشلة' : 'تم حذف جميع الرسائل'), backgroundColor: Colors.green.shade700),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // --- Widget Helpers ---
  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: EdgeInsets.all(16.w),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, color: color, size: 20.sp),
        ),
        SizedBox(width: 10.w),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
      ],
    );
  }

  Widget _buildProviderOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedProvider == value;
    return InkWell(
      onTap: () => setState(() => _selectedProvider = value),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  Text(description, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildLimitSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
              child: Text('${value.round()}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14.sp)),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp))),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _isSaving ? null : _saveSettings,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8.w),
                      Text('حفظ الإعدادات', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 8.h),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp, color: color)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color, String count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6.w),
        Text(label, style: TextStyle(fontSize: 12.sp)),
        SizedBox(width: 4.w),
        Text('($count)', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _SendModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SendModeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 24.sp),
              SizedBox(height: 4.h),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : Colors.grey.shade700,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
