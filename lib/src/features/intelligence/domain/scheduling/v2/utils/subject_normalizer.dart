/// Subject Normalizer - توحيد أسماء المواد
/// 
/// هذه الدالة تقوم بتوحيد أسماء المواد لضمان التطابق بين:
/// - المواد المطلوبة في الجدول (من SaudiSubjectPlans)
/// - المواد المؤهلة عند المعلمين (من assignedSubjects)
class SubjectNormalizer {
  /// خريطة الأسماء البديلة للمواد
  static final Map<String, String> _aliasMap = {};
  
  /// خريطة أسماء المواد حسب المعرف
  static final Map<String, String> _nameById = {};
  
  /// تحميل خريطة المواد من الإعدادات
  static void loadSubjectCatalog(Map<String, dynamic>? subjectsConfig) {
    _aliasMap.clear();
    _nameById.clear();
    
    if (subjectsConfig == null) return;
    
    subjectsConfig.forEach((id, value) {
      if (id.trim().isEmpty) return;
      _aliasMap[_normalizeKey(id)] = id;
      
      if (value is Map<String, dynamic>) {
        final name = (value['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _aliasMap[_normalizeKey(name)] = id;
          _nameById[id] = name;
        } else {
          _nameById[id] = id;
        }
        
        final rawAliases = value['aliases'];
        if (rawAliases is List) {
          for (final a in rawAliases) {
            if (a == null) continue;
            final s = a.toString().trim();
            if (s.isEmpty) continue;
            _aliasMap[_normalizeKey(s)] = id;
          }
        }
      }
    });
    
    // إضافة أسماء افتراضية للمواد الأساسية
    _addDefaultAliases();
  }
  
  /// إضافة أسماء افتراضية للمواد الأساسية
  static void _addDefaultAliases() {
    // العربي
    final arabicAliases = [
      'عربي', 'اللغة العربية', 'لغة عربية', 'لغتي', 'arabic',
      'الكفايات اللغوية', 'كفايات لغوية', 'لغة عربية 1', 'لغة عربية 2',
      'لغة عربية 3', 'لغة عربية 4', 'لغة عربية 5', 'لغة عربية 6',
    ];
    for (final alias in arabicAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Arabic';
      }
    }
    
    // الرياضيات
    final mathAliases = [
      'رياضيات', 'رياضيات 1', 'رياضيات 2', 'رياضيات 3', 'رياضيات 4',
      'رياضيات 5', 'رياضيات 6', 'math', 'mathematics',
    ];
    for (final alias in mathAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Math';
      }
    }
    
    // العلوم
    final scienceAliases = [
      'علوم', 'علوم 1', 'علوم 2', 'علوم 3', 'science',
      'أحياء', 'احياء', 'biology', 'أحياء 1', 'أحياء 2', 'أحياء 3',
      'فيزياء', 'physics', 'فيزياء 1', 'فيزياء 2', 'فيزياء 3',
      'كيمياء', 'chemistry', 'كيمياء 1', 'كيمياء 2', 'كيمياء 3',
    ];
    for (final alias in scienceAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Science';
      }
    }
    
    // الإنجليزي
    final englishAliases = [
      'انجليزي', 'إنجليزي', 'انجليزية', 'إنجليزية', 'اللغة الإنجليزية',
      'لغة انجليزية', 'لغة إنجليزية', 'english', 'اللغة الانجليزية',
      'انجليزي 1', 'انجليزي 2', 'انجليزي 3', 'انجليزي 4', 'انجليزي 5',
      'mega goal', 'traveller', 'flying high',
    ];
    for (final alias in englishAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'English';
      }
    }
    
    // الإسلامية
    final islamicAliases = [
      'اسلامية', 'إسلامية', 'تربية اسلامية', 'تربية إسلامية', 'islamic',
      'دراسات اسلامية', 'دراسات إسلامية', 'الدراسات الإسلامية',
    ];
    for (final alias in islamicAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Islamic';
      }
    }
    
    // الاجتماعيات
    final socialAliases = [
      'اجتماعيات', 'إجتماعيات', 'دراسات اجتماعية', 'الاجتماعيات',
      'social', 'social studies',
    ];
    for (final alias in socialAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Social';
      }
    }
    
    // الحاسب
    final computerAliases = [
      'حاسب', 'حاسوب', 'حوسبة', 'كمبيوتر', 'تقنية رقمية', 'computer',
      'cs', 'حاسب 1', 'حاسب 2', 'حاسب 3',
    ];
    for (final alias in computerAliases) {
      if (!_aliasMap.containsKey(_normalizeKey(alias))) {
        _aliasMap[_normalizeKey(alias)] = 'Computer';
      }
    }
  }
  
  /// توحيد اسم المادة
  static String normalize(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    
    // محاولة البحث في خريطة الأسماء البديلة
    final resolved = _aliasMap[_normalizeKey(s)];
    if (resolved != null) return resolved;
    
    // إذا لم يتم العثور، استخدم القواعد الافتراضية
    final lower = s.toLowerCase();
    
    if (lower == 'general' || lower == 'عام') {
      return '';
    }
    
    if (lower.contains('عربي') || lower.contains('لغتي') || 
        lower.contains('كفايات') || lower == 'arabic') {
      return 'Arabic';
    }
    
    if (lower.contains('رياضيات') || lower == 'math') {
      return 'Math';
    }
    
    if (lower.contains('علوم') || lower.contains('أحياء') || 
        lower.contains('فيزياء') || lower.contains('كيمياء') ||
        lower.contains('biology') || lower.contains('physics') ||
        lower.contains('chemistry') || lower == 'science') {
      return 'Science';
    }
    
    if (lower.contains('اسلام') || lower.contains('إسلام') ||
        lower.contains('تربية اسلامية') || lower == 'islamic') {
      return 'Islamic';
    }
    
    if (lower.contains('قرآن') || lower.contains('قران') ||
        lower.contains('تحفيظ') || lower == 'quran') {
      return 'Quran';
    }
    
    if (lower.contains('انجليز') || lower.contains('إنجليز') ||
        lower == 'english' || lower.contains('mega') ||
        lower.contains('traveller') || lower.contains('flying')) {
      return 'English';
    }
    
    if (lower.contains('اجتماعي') || lower.contains('دراسات اجتماعية') ||
        lower.contains('الاجتماعيات') || lower == 'social') {
      return 'Social';
    }
    
    if (lower.contains('حاسب') || lower.contains('حوسبة') ||
        lower.contains('حاسوب') || lower.contains('كمبيوتر') ||
        lower.contains('تقنية رقمية') || lower == 'cs' ||
        lower.contains('computer')) {
      return 'Computer';
    }
    
    if (lower.contains('بدنية') || lower.contains('رياضية') ||
        lower.contains('رياضة') || lower == 'pe') {
      return 'PE';
    }
    
    if (lower.contains('فنية') || lower.contains('رسم') || lower == 'art') {
      return 'Art';
    }
    
    // إذا لم يتم التعرف على المادة، أرجع الاسم كما هو
    return s;
  }
  
  /// توحيد المفتاح (إزالة التشكيل والمسافات)
  static String _normalizeKey(String s) {
    var v = s.trim().toLowerCase();
    v = v
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '') // إزالة التشكيل
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ''); // إزالة المسافات والرموز
    return v;
  }
  
  /// الحصول على اسم المادة المعروض
  static String getDisplayName(String subjectId) {
    return _nameById[subjectId] ?? subjectId;
  }
  
  /// إنشاء تقرير mapping للمواد
  static Map<String, dynamic> createMappingReport(List<String> rawSubjects) {
    final mapping = <String, String>{};
    final unmapped = <String>[];
    
    for (final raw in rawSubjects) {
      final normalized = normalize(raw);
      if (normalized.isEmpty || normalized == raw) {
        unmapped.add(raw);
      } else {
        mapping[raw] = normalized;
      }
    }
    
    return {
      'mapping': mapping,
      'unmapped': unmapped,
      'totalSubjects': rawSubjects.length,
      'mappedCount': mapping.length,
      'unmappedCount': unmapped.length,
    };
  }
}
