import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/country_profile.dart';

/// خدمة تحميل وإدارة ملفات تعريف الدول
/// تعمل بنظام Cache لتجنب إعادة التحميل
class CountryProfileService {
  static final CountryProfileService _instance =
      CountryProfileService._internal();
  factory CountryProfileService() => _instance;
  CountryProfileService._internal();

  final Map<String, CountryProfile> _cache = {};
  List<Map<String, dynamic>>? _indexCache;

  static const String _basePath = 'assets/config/country_profiles';

  /// تحميل ملف تعريف دولة بالرمز ISO
  Future<CountryProfile?> loadProfile(String countryCode) async {
    final code = countryCode.toUpperCase();

    // من الـ Cache أولاً
    if (_cache.containsKey(code)) return _cache[code];

    try {
      final jsonStr =
          await rootBundle.loadString('$_basePath/$code.json');
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final profile = CountryProfile.fromMap(map);
      _cache[code] = profile;
      return profile;
    } catch (e) {
      // إذا لم يوجد ملف للدولة، نرجع الملف الافتراضي
      return _buildDefaultProfile(code);
    }
  }

  /// تحميل قائمة الدول المدعومة
  Future<List<Map<String, dynamic>>> loadCountriesIndex() async {
    if (_indexCache != null) return _indexCache!;
    try {
      final jsonStr =
          await rootBundle.loadString('$_basePath/index.json');
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      _indexCache =
          List<Map<String, dynamic>>.from(map['countries'] ?? []);
      return _indexCache!;
    } catch (_) {
      return _defaultCountriesIndex();
    }
  }

  /// تحميل قائمة المناطق
  Future<List<Map<String, dynamic>>> loadRegions() async {
    try {
      final jsonStr =
          await rootBundle.loadString('$_basePath/index.json');
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(map['regions'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// الحصول على ملف تعريف من الـ Cache (sync)
  CountryProfile? getCached(String countryCode) =>
      _cache[countryCode.toUpperCase()];

  /// مسح الـ Cache
  void clearCache() {
    _cache.clear();
    _indexCache = null;
  }

  // ─── Default Profile ────────────────────────────────────────────────────────

  /// ملف تعريف افتراضي لأي دولة غير مدعومة
  CountryProfile _buildDefaultProfile(String countryCode) {
    return CountryProfile(
      countryCode: countryCode,
      nameAr: countryCode,
      nameEn: countryCode,
      flag: '🌍',
      region: 'other',
      primaryLanguage: 'ar',
      textDirection: TextDirection.rtl,
      currency: '',
      timezone: 'UTC',
      behaviorSystem: BehaviorSystem.custom,
      gradingSystem: GradingSystem.percentage,
      calendarSystem: CalendarSystem.twoSemesters,
      tracksEnabled: false,
      defaultTracks: [],
      stages: _defaultStages(),
      smsImportant: false,
      emailPrimary: true,
      messagingAppsCommon: false,
      features: const CountryFeatures(),
      allowSchoolCustomization: true,
    );
  }

  List<SchoolStageConfig> _defaultStages() => const [
        SchoolStageConfig(
          key: 'primary',
          nameAr: 'الابتدائية',
          nameEn: 'Primary',
          fromGrade: 1,
          toGrade: 6,
          fromAge: 6,
          toAge: 12,
        ),
        SchoolStageConfig(
          key: 'middle',
          nameAr: 'المتوسطة',
          nameEn: 'Middle',
          fromGrade: 7,
          toGrade: 9,
          fromAge: 12,
          toAge: 15,
        ),
        SchoolStageConfig(
          key: 'secondary',
          nameAr: 'الثانوية',
          nameEn: 'Secondary',
          fromGrade: 10,
          toGrade: 12,
          fromAge: 15,
          toAge: 18,
        ),
      ];

  List<Map<String, dynamic>> _defaultCountriesIndex() => [
        {'code': 'SA', 'nameAr': 'السعودية', 'nameEn': 'Saudi Arabia', 'flag': '🇸🇦', 'region': 'gulf', 'supported': true},
        {'code': 'AE', 'nameAr': 'الإمارات', 'nameEn': 'UAE', 'flag': '🇦🇪', 'region': 'gulf', 'supported': true},
        {'code': 'QA', 'nameAr': 'قطر', 'nameEn': 'Qatar', 'flag': '🇶🇦', 'region': 'gulf', 'supported': true},
        {'code': 'KW', 'nameAr': 'الكويت', 'nameEn': 'Kuwait', 'flag': '🇰🇼', 'region': 'gulf', 'supported': true},
        {'code': 'BH', 'nameAr': 'البحرين', 'nameEn': 'Bahrain', 'flag': '🇧🇭', 'region': 'gulf', 'supported': true},
        {'code': 'OM', 'nameAr': 'عُمان', 'nameEn': 'Oman', 'flag': '🇴🇲', 'region': 'gulf', 'supported': true},
      ];
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final countryProfileServiceProvider = Provider<CountryProfileService>((ref) {
  return CountryProfileService();
});

/// Provider لتحميل ملف تعريف دولة محددة
final countryProfileProvider =
    FutureProvider.family<CountryProfile?, String>((ref, countryCode) async {
  if (countryCode.isEmpty) return null;
  final service = ref.read(countryProfileServiceProvider);
  return service.loadProfile(countryCode);
});

/// Provider لقائمة الدول المدعومة
final supportedCountriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(countryProfileServiceProvider);
  return service.loadCountriesIndex();
});

/// Provider للدول مجمّعة حسب المنطقة
final countriesByRegionProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final countries = await ref.watch(supportedCountriesProvider.future);
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  for (final c in countries) {
    final region = c['region'] as String? ?? 'other';
    grouped.putIfAbsent(region, () => []).add(c);
  }
  return grouped;
});
