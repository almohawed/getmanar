import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/school_config_service.dart';
import '../../../core/services/country_profile_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';

// ─── Provider: هل أكمل المدير الإعداد؟ ──────────────────────────────────────
final setupCompletedProvider = FutureProvider.family<bool, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return true;
  final doc = await FirebaseFirestore.instance.collection('Schools').doc(schoolId).get();
  if (!doc.exists) return true;
  return doc.data()?['setupCompleted'] == true;
});

// ─── Wizard Steps ─────────────────────────────────────────────────────────────
enum _WizardStep { country, schoolType, features, done }

class SchoolSetupWizard extends ConsumerStatefulWidget {
  final String schoolId;
  const SchoolSetupWizard({super.key, required this.schoolId});

  @override
  ConsumerState<SchoolSetupWizard> createState() => _SchoolSetupWizardState();
}

class _SchoolSetupWizardState extends ConsumerState<SchoolSetupWizard>
    with SingleTickerProviderStateMixin {
  _WizardStep _step = _WizardStep.country;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Selections
  String _countryCode = 'SA';
  String _schoolType = 'government';
  String _schoolStage = 'الابتدائية';
  Map<String, bool> _featureOverrides = {};
  bool _saving = false;

  // Country profile loaded
  Map<String, dynamic>? _loadedProfile;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
    _loadSchoolData();
  }

  Future<void> _loadSchoolData() async {
    final doc = await FirebaseFirestore.instance
        .collection('Schools').doc(widget.schoolId).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _countryCode = data['countryCode'] ?? 'SA';
        _schoolType  = data['type'] ?? 'government';
        _schoolStage = data['stage'] ?? 'الابتدائية';
      });
      await _loadProfile(_countryCode);
    }
  }

  Future<void> _loadProfile(String code) async {
    final profile = await ref.read(countryProfileServiceProvider).loadProfile(code);
    if (profile != null && mounted) {
      setState(() {
        _loadedProfile = profile.toMap();
        // تهيئة Feature Overrides من الـ profile
        _featureOverrides = {
          'parentSms':      profile.features.parentSms,
          'schoolBroadcast':profile.features.schoolBroadcast,
          'counseling':     profile.features.counseling,
          'healthTracking': profile.features.healthTracking,
          'smartSchedule':  profile.features.smartSchedule,
          'tracks':         profile.features.tracks,
          'leaveRequests':  profile.features.leaveRequests,
          'exams':          profile.features.exams,
        };
      });
    }
  }

  void _nextStep() {
    _animCtrl.reverse().then((_) {
      setState(() {
        _step = _WizardStep.values[_step.index + 1];
      });
      _animCtrl.forward();
    });
  }

  void _prevStep() {
    _animCtrl.reverse().then((_) {
      setState(() {
        _step = _WizardStep.values[_step.index - 1];
      });
      _animCtrl.forward();
    });
  }

  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    try {
      await ref.read(schoolConfigServiceProvider).updateOverrides(
        widget.schoolId,
        {'features': _featureOverrides},
      );
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .update({
        'type': _schoolType,
        'setupCompleted': true,
        'setupCompletedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _step = _WizardStep.done);
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final steps = _WizardStep.values.where((s) => s != _WizardStep.done).length;
    final current = _step == _WizardStep.done ? steps : _step.index;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('إعداد المدرسة',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              const Spacer(),
              Text('$current / $steps',
                  style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: current / steps,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF42A5F5)),
              minHeight: 4.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      _WizardStep.country    => _buildCountryStep(),
      _WizardStep.schoolType => _buildSchoolTypeStep(),
      _WizardStep.features   => _buildFeaturesStep(),
      _WizardStep.done       => _buildDoneStep(),
    };
  }

  // ─── Step 1: Country ────────────────────────────────────────────────────────
  Widget _buildCountryStep() {
    final countries = [
      {'code': 'SA', 'nameAr': 'السعودية',  'flag': '🇸🇦', 'behavior': 'نظام الدرجات'},
      {'code': 'AE', 'nameAr': 'الإمارات',  'flag': '🇦🇪', 'behavior': 'نظام الإرشاد'},
      {'code': 'QA', 'nameAr': 'قطر',       'flag': '🇶🇦', 'behavior': 'نظام النقاط'},
      {'code': 'KW', 'nameAr': 'الكويت',    'flag': '🇰🇼', 'behavior': 'نظام مرن'},
      {'code': 'BH', 'nameAr': 'البحرين',   'flag': '🇧🇭', 'behavior': 'نظام مرن'},
      {'code': 'OM', 'nameAr': 'عُمان',     'flag': '🇴🇲', 'behavior': 'نظام مرن'},
      {'code': 'US', 'nameAr': 'أمريكا',    'flag': '🇺🇸', 'behavior': 'نظام GPA'},
      {'code': 'GB', 'nameAr': 'بريطانيا',  'flag': '🇬🇧', 'behavior': 'نظام الإنذارات'},
      {'code': 'FR', 'nameAr': 'فرنسا',     'flag': '🇫🇷', 'behavior': 'نظام الإنذارات'},
      {'code': 'ES', 'nameAr': 'إسبانيا',   'flag': '🇪🇸', 'behavior': 'نظام الإنذارات'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.public,
            title: 'اختر دولة المدرسة',
            subtitle: 'سيتكيّف النظام تلقائياً مع أنظمة هذه الدولة',
          ),
          SizedBox(height: 24.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.6,
            ),
            itemCount: countries.length,
            itemBuilder: (_, i) {
              final c = countries[i];
              final isSelected = _countryCode == c['code'];
              return GestureDetector(
                onTap: () async {
                  setState(() => _countryCode = c['code']!);
                  await _loadProfile(c['code']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1565C0).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF42A5F5) : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c['flag']!, style: TextStyle(fontSize: 28.sp)),
                      SizedBox(height: 4.h),
                      Text(c['nameAr']!,
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold)),
                      Text(c['behavior']!,
                          style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 32.h),
          _buildNextButton('التالي', _nextStep),
        ],
      ),
    );
  }

  // ─── Step 2: School Type ────────────────────────────────────────────────────
  Widget _buildSchoolTypeStep() {
    final types = [
      {'key': 'government',    'label': 'حكومي',    'icon': Icons.account_balance,    'color': const Color(0xFF1565C0)},
      {'key': 'private',       'label': 'أهلي',     'icon': Icons.business,           'color': const Color(0xFF6A1B9A)},
      {'key': 'international', 'label': 'عالمي',    'icon': Icons.language,           'color': const Color(0xFF00695C)},
    ];
    final stages = [
      {'key': 'الابتدائية', 'label': 'ابتدائي',  'icon': Icons.child_care},
      {'key': 'المتوسطة',   'label': 'متوسط',    'icon': Icons.school},
      {'key': 'الثانوية',   'label': 'ثانوي',    'icon': Icons.account_balance_wallet},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.school,
            title: 'نوع المدرسة والمرحلة',
            subtitle: 'يؤثر على الميزات والأنظمة المتاحة',
          ),
          SizedBox(height: 24.h),
          Text('نوع المدرسة',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 12.h),
          Row(
            children: types.map((t) {
              final isSelected = _schoolType == t['key'];
              final color = t['color'] as Color;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _schoolType = t['key'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: t != types.last ? 8.w : 0),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(t['icon'] as IconData, color: isSelected ? color : Colors.white38, size: 24.sp),
                        SizedBox(height: 6.h),
                        Text(t['label'] as String,
                            style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),
          Text('المرحلة الدراسية',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 12.h),
          Row(
            children: stages.map((s) {
              final isSelected = _schoolStage == s['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _schoolStage = s['key'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: s != stages.last ? 8.w : 0),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF26A69A).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: isSelected ? const Color(0xFF26A69A) : Colors.white12,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(s['icon'] as IconData,
                            color: isSelected ? const Color(0xFF26A69A) : Colors.white38,
                            size: 24.sp),
                        SizedBox(height: 6.h),
                        Text(s['label'] as String,
                            style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 32.h),
          Row(
            children: [
              _buildBackButton(),
              SizedBox(width: 12.w),
              Expanded(child: _buildNextButton('التالي', _nextStep)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Features ───────────────────────────────────────────────────────
  Widget _buildFeaturesStep() {
    final featureItems = [
      {'key': 'parentSms',       'label': 'رسائل SMS لأولياء الأمور', 'icon': Icons.sms,              'color': const Color(0xFF26A69A)},
      {'key': 'schoolBroadcast', 'label': 'الإذاعة المدرسية',         'icon': Icons.mic,              'color': const Color(0xFF1565C0)},
      {'key': 'counseling',      'label': 'الإرشاد الطلابي',          'icon': Icons.psychology,       'color': const Color(0xFF6A1B9A)},
      {'key': 'healthTracking',  'label': 'الصحة المدرسية',           'icon': Icons.health_and_safety,'color': const Color(0xFF00695C)},
      {'key': 'smartSchedule',   'label': 'الجدول الذكي',             'icon': Icons.auto_awesome,     'color': Colors.orange},
      {'key': 'tracks',          'label': 'المسارات الدراسية',        'icon': Icons.route,            'color': Colors.deepPurple},
      {'key': 'leaveRequests',   'label': 'طلبات الاستئذان',          'icon': Icons.exit_to_app,      'color': Colors.teal},
      {'key': 'exams',           'label': 'إدارة الاختبارات',         'icon': Icons.quiz,             'color': Colors.red},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.tune,
            title: 'الميزات المفعّلة',
            subtitle: 'مُعدَّة تلقائياً حسب الدولة — يمكنك التعديل',
          ),
          SizedBox(height: 8.h),
          if (_loadedProfile != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF42A5F5), size: 16),
                  SizedBox(width: 8.w),
                  Text(
                    'الإعدادات مُحمَّلة من ملف تعريف ${_loadedProfile!['nameAr'] ?? _countryCode}',
                    style: TextStyle(color: const Color(0xFF42A5F5), fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16.h),
          ...featureItems.map((f) {
            final key = f['key'] as String;
            final enabled = _featureOverrides[key] ?? true;
            final color = f['color'] as Color;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: enabled ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                    color: enabled ? color.withValues(alpha: 0.4) : Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(f['icon'] as IconData,
                      color: enabled ? color : Colors.white24, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(f['label'] as String,
                        style: TextStyle(
                            color: enabled ? Colors.white : Colors.white38,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500)),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) => setState(() => _featureOverrides[key] = v),
                    activeColor: color,
                    inactiveThumbColor: Colors.white24,
                    inactiveTrackColor: Colors.white10,
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 24.h),
          Row(
            children: [
              _buildBackButton(),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAndFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    elevation: 6,
                  ),
                  icon: _saving
                      ? SizedBox(width: 18.w, height: 18.h,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.check_circle, size: 20.sp),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ وإنهاء الإعداد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                ),
              ),
            ],
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ─── Step 4: Done ───────────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w, height: 100.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF26A69A), Color(0xFF1565C0)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.4),
                    blurRadius: 30, spreadRadius: 5)],
              ),
              child: Icon(Icons.check, color: Colors.white, size: 50.sp),
            ),
            SizedBox(height: 32.h),
            Text('تم إعداد المدرسة بنجاح! 🎉',
                style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 12.h),
            Text('النظام جاهز ومُهيَّأ حسب إعدادات دولتك',
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                textAlign: TextAlign.center),
            SizedBox(height: 48.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 8,
                ),
                icon: Icon(Icons.dashboard, size: 22.sp),
                label: Text('انتقل إلى لوحة التحكم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildStepHeader({required IconData icon, required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Icon(icon, color: const Color(0xFF42A5F5), size: 28.sp),
        ),
        SizedBox(height: 16.h),
        Text(title,
            style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 6.h),
        Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
      ],
    );
  }

  Widget _buildNextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          elevation: 6,
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp)),
      ),
    );
  }

  Widget _buildBackButton() {
    return OutlinedButton(
      onPressed: _prevStep,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white24),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      ),
      child: const Icon(Icons.arrow_forward_ios),
    );
  }
}
