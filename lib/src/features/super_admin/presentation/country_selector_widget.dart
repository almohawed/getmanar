import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/country_profile.dart';
import '../../../core/services/country_profile_service.dart';

/// Widget اختيار الدولة — قابل للاستخدام في أي شاشة
class CountrySelectorWidget extends ConsumerStatefulWidget {
  final String selectedCode;
  final ValueChanged<String> onChanged;
  final bool showLabel;

  const CountrySelectorWidget({
    super.key,
    required this.selectedCode,
    required this.onChanged,
    this.showLabel = true,
  });

  @override
  ConsumerState<CountrySelectorWidget> createState() =>
      _CountrySelectorWidgetState();
}

class _CountrySelectorWidgetState
    extends ConsumerState<CountrySelectorWidget> {
  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(supportedCountriesProvider);

    return countriesAsync.when(
      data: (countries) => _buildSelector(countries),
      loading: () => _buildLoadingSelector(),
      error: (_, __) => _buildFallbackSelector(),
    );
  }

  Widget _buildSelector(List<Map<String, dynamic>> countries) {
    // Group by region
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final c in countries) {
      final region = c['region'] as String? ?? 'other';
      grouped.putIfAbsent(region, () => []).add(c);
    }

    final regionOrder = ['gulf', 'arab', 'europe', 'americas', 'asia', 'africa', 'other'];
    final regionNames = {
      'gulf': 'الخليج العربي',
      'arab': 'الوطن العربي',
      'europe': 'أوروبا',
      'americas': 'الأمريكتان',
      'asia': 'آسيا',
      'africa': 'أفريقيا',
      'other': 'أخرى',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text('الدولة',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
        ],
        GestureDetector(
          onTap: () => _showCountryPicker(context, grouped, regionOrder, regionNames),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.white38, size: 18),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildSelectedCountry(countries),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.white38),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCountry(List<Map<String, dynamic>> countries) {
    if (widget.selectedCode.isEmpty) {
      return Text('اختر الدولة',
          style: TextStyle(color: Colors.white38, fontSize: 13.sp));
    }
    final country = countries.firstWhere(
      (c) => c['code'] == widget.selectedCode,
      orElse: () => {'code': widget.selectedCode, 'nameAr': widget.selectedCode, 'flag': '🌍'},
    );
    return Row(
      children: [
        Text(country['flag'] ?? '🌍', style: TextStyle(fontSize: 18.sp)),
        SizedBox(width: 8.w),
        Text(
          country['nameAr'] ?? widget.selectedCode,
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
        ),
      ],
    );
  }

  Future<void> _showCountryPicker(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> grouped,
    List<String> regionOrder,
    Map<String, String> regionNames,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B2A4A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.symmetric(vertical: 10.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text('اختر الدولة',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp)),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: regionOrder
                    .where((r) => grouped.containsKey(r))
                    .map((region) {
                  final regionCountries = grouped[region]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Text(
                          regionNames[region] ?? region,
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      ...regionCountries.map((c) => _buildCountryTile(ctx, c)),
                      SizedBox(height: 8.h),
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

  Widget _buildCountryTile(BuildContext ctx, Map<String, dynamic> country) {
    final code = country['code'] as String;
    final isSelected = widget.selectedCode == code;

    return GestureDetector(
      onTap: () {
        widget.onChanged(code);
        Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1565C0).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(country['flag'] ?? '🌍',
                style: TextStyle(fontSize: 20.sp)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country['nameAr'] ?? code,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    country['nameEn'] ?? '',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 10.sp),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: const Color(0xFF42A5F5), size: 18.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16.w,
            height: 16.h,
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white38),
          ),
          SizedBox(width: 10.w),
          Text('جاري التحميل...',
              style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildFallbackSelector() {
    // Fallback: dropdown بسيط للدول الخليجية
    final gulfCountries = [
      {'code': 'SA', 'nameAr': 'السعودية', 'flag': '🇸🇦'},
      {'code': 'AE', 'nameAr': 'الإمارات', 'flag': '🇦🇪'},
      {'code': 'QA', 'nameAr': 'قطر', 'flag': '🇶🇦'},
      {'code': 'KW', 'nameAr': 'الكويت', 'flag': '🇰🇼'},
      {'code': 'BH', 'nameAr': 'البحرين', 'flag': '🇧🇭'},
      {'code': 'OM', 'nameAr': 'عُمان', 'flag': '🇴🇲'},
    ];

    return DropdownButtonFormField<String>(
      value: widget.selectedCode.isEmpty ? 'SA' : widget.selectedCode,
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF1B2A4A),
      decoration: InputDecoration(
        labelText: 'الدولة',
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.public, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
      ),
      items: gulfCountries
          .map((c) => DropdownMenuItem(
                value: c['code'],
                child: Text('${c['flag']} ${c['nameAr']}'),
              ))
          .toList(),
      onChanged: (v) => widget.onChanged(v ?? 'SA'),
    );
  }
}

/// Widget عرض معلومات الدولة المختارة
class CountryProfileInfoWidget extends ConsumerWidget {
  final String countryCode;

  const CountryProfileInfoWidget({super.key, required this.countryCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (countryCode.isEmpty) return const SizedBox.shrink();

    final profileAsync = ref.watch(countryProfileProvider(countryCode));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return _buildInfo(profile);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfo(CountryProfile profile) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(profile.flag, style: TextStyle(fontSize: 20.sp)),
              SizedBox(width: 8.w),
              Text(
                profile.nameAr,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp),
              ),
              const Spacer(),
              _featureBadge(_behaviorLabel(profile.behaviorSystem),
                  const Color(0xFF42A5F5)),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: [
              if (profile.features.tracks)
                _featureBadge('مسارات', const Color(0xFF26A69A)),
              if (profile.features.parentSms)
                _featureBadge('SMS', const Color(0xFF2E7D32)),
              if (profile.features.counseling)
                _featureBadge('إرشاد', const Color(0xFF6A1B9A)),
              _featureBadge(
                  _gradingLabel(profile.gradingSystem), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10.sp, fontWeight: FontWeight.w600)),
    );
  }

  String _behaviorLabel(BehaviorSystem s) {
    switch (s) {
      case BehaviorSystem.levels: return 'نظام الدرجات';
      case BehaviorSystem.points: return 'نظام النقاط';
      case BehaviorSystem.guidance: return 'نظام الإرشاد';
      case BehaviorSystem.gpa: return 'نظام GPA';
      case BehaviorSystem.warnings: return 'نظام الإنذارات';
      case BehaviorSystem.custom: return 'نظام مرن';
    }
  }

  String _gradingLabel(GradingSystem g) {
    switch (g) {
      case GradingSystem.percentage: return 'تقييم %';
      case GradingSystem.gpa4: return 'GPA 4.0';
      case GradingSystem.gpa5: return 'GPA 5.0';
      case GradingSystem.letters: return 'تقييم A-F';
      case GradingSystem.french20: return 'تقييم /20';
      case GradingSystem.scale10: return 'تقييم /10';
      case GradingSystem.custom: return 'تقييم مخصص';
    }
  }
}
