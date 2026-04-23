import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../application/campaign_service.dart';
import '../domain/schedule_campaign.dart';
import '../domain/teacher_response.dart';
import '../../auth/presentation/auth_controller.dart';

class TeacherCampaignResponseScreen extends ConsumerStatefulWidget {
  final String campaignId;
  final String schoolId;
  final String? teacherId;
  final String? teacherName;

  const TeacherCampaignResponseScreen({
    Key? key,
    required this.campaignId,
    required this.schoolId,
    this.teacherId,
    this.teacherName,
  }) : super(key: key);

  @override
  ConsumerState<TeacherCampaignResponseScreen> createState() =>
      _TeacherCampaignResponseScreenState();
}

class _TeacherCampaignResponseScreenState
    extends ConsumerState<TeacherCampaignResponseScreen> {
  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  ResponseType? _selectedResponse;
  final Set<BlockedSlot> _blockedSlots = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.read(campaignServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 حملة جدول تشاركي'),
        elevation: 0,
      ),
      body: FutureBuilder<ScheduleCampaign>(
        future: service.getCampaign(widget.campaignId, widget.schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('لا توجد بيانات'));
          }

          final campaign = snapshot.data!;

          if (campaign.isExpired) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_off, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text('انتهت مدة الحملة'),
                ],
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildCampaignInfo(campaign),
              SizedBox(height: 20.h),
              _buildResponseButtons(),
              if (_selectedResponse == ResponseType.yes) ...[
                SizedBox(height: 20.h),
                _buildSlotSelector(),
                SizedBox(height: 20.h),
                _buildStatistics(),
              ],
              SizedBox(height: 30.h),
              _buildSubmitButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampaignInfo(ScheduleCampaign campaign) {
    final remaining = campaign.timeRemaining;
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📢 الإدارة تعتزم إعداد جدول دراسي جديد',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            if (campaign.message != null) ...[
              Text(campaign.message!),
              SizedBox(height: 12.h),
            ],
            Text(
              '💡 إذا كان لديك رغبة في استبعاد بعض الحصص من جدولك، سيقوم النظام بتلبية ذلك بحسب الإمكان.',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.blue),
                  SizedBox(width: 8.w),
                  Text(
                    'الوقت المتبقي: $days يوم و $hours ساعة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseButtons() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '❓ ما هو ردك؟',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildResponseButton(
                    '✅ نعم، لدي رغبة',
                    ResponseType.yes,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildResponseButton(
                    '❌ لا، شكراً',
                    ResponseType.no,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              '💭 ملاحظة: إذا لم ترد، سيفهم النظام أنه ليس لديك مانع من توزيع الحصص.',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseButton(String label, ResponseType type, Color color) {
    final isSelected = _selectedResponse == type;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedResponse = type;
          if (type == ResponseType.no) {
            _blockedSlots.clear();
          }
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: EdgeInsets.symmetric(vertical: 16.h),
      ),
      child: Text(label),
    );
  }

  Widget _buildSlotSelector() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 اختر الحصص غير المرغوبة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '💡 اضغط على الحصص التي تفضل عدم تدريسها',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('')),
                  ...List.generate(
                    7,
                    (i) => DataColumn(
                      label: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                rows: _days.map((day) {
                  return DataRow(
                    cells: [
                      DataCell(Text(day, style: TextStyle(fontWeight: FontWeight.bold))),
                      ...List.generate(7, (period) {
                        final slot = BlockedSlot(day: day, period: period + 1);
                        final isBlocked = _blockedSlots.contains(slot);

                        return DataCell(
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isBlocked) {
                                  _blockedSlots.remove(slot);
                                } else {
                                  _blockedSlots.add(slot);
                                }
                              });
                            },
                            child: Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: isBlocked ? Colors.red.shade100 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: isBlocked ? Colors.red : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: isBlocked
                                    ? Icon(Icons.close, color: Colors.red, size: 20.sp)
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final totalSlots = 35; // 5 days × 7 periods
    final blockedCount = _blockedSlots.length;
    final percentage = (blockedCount / totalSlots * 100).toStringAsFixed(0);

    Color statusColor = Colors.green;
    String statusText = 'معقول ✅';
    if (blockedCount > 15) {
      statusColor = Colors.orange;
      statusText = 'كثير ⚠️';
    }
    if (blockedCount > 20) {
      statusColor = Colors.red;
      statusText = 'كثير جداً 🔴';
    }

    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 الإحصائيات',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الحصص المستبعدة:'),
                Text(
                  '$blockedCount حصة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('نسبة الاستبعاد:'),
                Text(
                  '$percentage% ($statusText)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التوصية:'),
                Text(
                  blockedCount < 15
                      ? 'يمكن تلبية معظم رغباتك 🎯'
                      : 'قد يصعب تلبية جميع الرغبات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _selectedResponse != null;

    return ElevatedButton(
      onPressed: canSubmit && !_isSubmitting ? _submitResponse : null,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        backgroundColor: Colors.indigo,
      ),
      child: _isSubmitting
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              '💾 حفظ الرغبات',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _submitResponse() async {
    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(campaignServiceProvider);
      
      // Get current user info if not provided
      final teacherId = widget.teacherId ?? ref.read(authStateProvider).value?.id ?? '';
      final teacherName = widget.teacherName ?? ref.read(authStateProvider).value?.name ?? '';

      await service.collectResponse(
        campaignId: widget.campaignId,
        schoolId: widget.schoolId,
        teacherId: teacherId,
        teacherName: teacherName,
        response: _selectedResponse!,
        blockedSlots: _blockedSlots.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ ردك بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
