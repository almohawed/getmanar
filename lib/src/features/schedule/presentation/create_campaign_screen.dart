import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../application/campaign_service.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String userId;

  const CreateCampaignScreen({
    Key? key,
    required this.schoolId,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<CreateCampaignScreen> createState() =>
      _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customMessageController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedMessage = 'message1'; // Default message
  bool _sendReminder = true;
  bool _autoClose = true;
  bool _dailySummary = true;
  bool _isCreating = false;

  // رسائل جاهزة بصيغة رسمية تناسب وزارة التعليم السعودي
  final Map<String, String> _predefinedMessages = {
    'message1': 'السلام عليكم ورحمة الله وبركاته\n\nنأمل من سعادتكم التكرم بتعبئة تفضيلاتكم للجدول الدراسي للفصل الدراسي القادم، وذلك لضمان توزيع عادل ومناسب للحصص الدراسية.\n\nشاكرين لكم حسن تعاونكم.',
    'message2': 'تحية طيبة وبعد،\n\nيسرنا دعوتكم للمشاركة في إعداد الجدول الدراسي من خلال تحديد الأوقات المفضلة لديكم، مما يساهم في تحسين بيئة العمل التعليمية.\n\nنقدر لكم تعاونكم المستمر.',
    'message3': 'السادة المعلمين الأفاضل،\n\nفي إطار حرصنا على مراعاة ظروفكم واحتياجاتكم، نرجو منكم تحديد تفضيلاتكم للجدول الدراسي القادم عبر النظام.\n\nمع خالص التقدير والاحترام.',
    'message4': 'بسم الله الرحمن الرحيم\n\nنود إفادتكم بأنه تم فتح باب استقبال تفضيلات الجدول الدراسي، نأمل المبادرة بالتسجيل في أقرب وقت ممكن.\n\nوفقكم الله وسدد خطاكم.',
    'custom': '', // للرسالة المخصصة
  };

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  Future<void> _createCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار تاريخ البداية والنهاية')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final service = ref.read(campaignServiceProvider);
      
      // تحديد الرسالة النهائية
      String? finalMessage;
      if (_selectedMessage == 'custom') {
        finalMessage = _customMessageController.text.trim().isEmpty
            ? null
            : _customMessageController.text.trim();
      } else {
        finalMessage = _predefinedMessages[_selectedMessage];
      }

      final campaign = await service.createCampaign(
        schoolId: widget.schoolId,
        startDate: _startDate!,
        endDate: _endDate!,
        responseTime: const Duration(days: 3), // قيمة افتراضية
        createdBy: widget.userId,
        message: finalMessage,
        settings: {
          'sendReminder': _sendReminder,
          'autoClose': _autoClose,
          'dailySummary': _dailySummary,
        },
      );

      // إطلاق الحملة مباشرة
      await service.launchCampaign(campaign.id, widget.schoolId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 تم إطلاق الحملة بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, campaign);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 إطلاق حملة جدول تشاركي'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildDateSection(),
            SizedBox(height: 20.h),
            _buildMessageSection(),
            SizedBox(height: 20.h),
            _buildAdvancedOptions(),
            SizedBox(height: 30.h),
            _buildLaunchButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 المدة الزمنية للحملة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: 'من',
                    date: _startDate,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildDatePicker(
                    label: 'إلى',
                    date: _endDate,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              date != null
                  ? '${date.year}/${date.month}/${date.day}'
                  : 'اختر التاريخ',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📝 رسالة للمعلمين',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            
            // الرسالة الأولى
            _buildMessageOption(
              'message1',
              'رسالة رسمية - نموذج 1',
              _predefinedMessages['message1']!,
            ),
            
            // الرسالة الثانية
            _buildMessageOption(
              'message2',
              'رسالة رسمية - نموذج 2',
              _predefinedMessages['message2']!,
            ),
            
            // الرسالة الثالثة
            _buildMessageOption(
              'message3',
              'رسالة رسمية - نموذج 3',
              _predefinedMessages['message3']!,
            ),
            
            // الرسالة الرابعة
            _buildMessageOption(
              'message4',
              'رسالة رسمية - نموذج 4',
              _predefinedMessages['message4']!,
            ),
            
            // خيار أخرى
            RadioListTile<String>(
              title: const Text('✍️ أخرى (كتابة رسالة مخصصة)'),
              value: 'custom',
              groupValue: _selectedMessage,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMessage = value);
                }
              },
            ),
            
            // حقل الرسالة المخصصة
            if (_selectedMessage == 'custom') ...[
              SizedBox(height: 12.h),
              TextFormField(
                controller: _customMessageController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك المخصصة هنا...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (_selectedMessage == 'custom' && 
                      (value == null || value.trim().isEmpty)) {
                    return 'الرجاء كتابة رسالة مخصصة';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageOption(String value, String title, String preview) {
    return Column(
      children: [
        RadioListTile<String>(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                preview,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          value: value,
          groupValue: _selectedMessage,
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _selectedMessage = newValue);
            }
          },
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 خيارات متقدمة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            CheckboxListTile(
              title: const Text('إرسال تذكير تلقائي بعد 12 ساعة'),
              value: _sendReminder,
              onChanged: (value) {
                setState(() => _sendReminder = value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('إغلاق الحملة تلقائياً عند انتهاء المدة'),
              value: _autoClose,
              onChanged: (value) {
                setState(() => _autoClose = value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('إرسال ملخص يومي للوكيل'),
              value: _dailySummary,
              onChanged: (value) {
                setState(() => _dailySummary = value ?? true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchButton() {
    return ElevatedButton(
      onPressed: _isCreating ? null : _createCampaign,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white, // لون النص أبيض
      ),
      child: _isCreating
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              '🚀 إطلاق الحملة الآن',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white, // تأكيد اللون الأبيض
              ),
            ),
    );
  }
}
