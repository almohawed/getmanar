/// subject_matcher.dart
/// نظام مطابقة ذكية لأسماء المواد مع دعم aliases محفوظة في Firestore
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─── نموذج المادة الأساسية ────────────────────────────────────────────────────
class SubjectMaster {
  final String id;
  final String officialName;
  final String category;
  final List<String> aliases;

  const SubjectMaster({
    required this.id,
    required this.officialName,
    required this.category,
    this.aliases = const [],
  });
}

// ─── نتيجة المطابقة ───────────────────────────────────────────────────────────
enum MatchConfidence { high, medium, low, unknown }

class SubjectMatchResult {
  final String rawName;
  final SubjectMaster? matched;
  final MatchConfidence confidence;
  final String? suggestion;

  const SubjectMatchResult({
    required this.rawName,
    this.matched,
    required this.confidence,
    this.suggestion,
  });

  bool get isKnown => matched != null && confidence != MatchConfidence.unknown;
  bool get needsReview => confidence == MatchConfidence.unknown || confidence == MatchConfidence.low;
}

// ─── قاعدة المواد الافتراضية ──────────────────────────────────────────────────
class SubjectMatcher {
  static final List<SubjectMaster> _defaultSubjects = [
    SubjectMaster(
      id: 'arabic',
      officialName: 'اللغة العربية',
      category: 'عربي',
      aliases: [
        'عربي', 'لغتي', 'لغة عربية', 'اللغة العربية', 'لغتي الخالدة',
        'الكفايات اللغوية', 'كفايات لغوية', 'arabic', 'لغه عربيه',
        'عربيه', 'لغتى', 'اللغه العربيه',
      ],
    ),
    SubjectMaster(
      id: 'math',
      officialName: 'الرياضيات',
      category: 'رياضيات',
      aliases: [
        'رياضيات', 'الرياضيات', 'رياضه', 'رياضيه', 'حساب',
        'math', 'mathematics', 'رياضياتي', 'رياضيات 1', 'رياضيات 2',
      ],
    ),
    SubjectMaster(
      id: 'science',
      officialName: 'العلوم',
      category: 'علوم',
      aliases: [
        'علوم', 'العلوم', 'علوم طبيعية', 'science', 'علوم 1', 'علوم 2',
        'أحياء', 'احياء', 'فيزياء', 'كيمياء', 'biology', 'physics', 'chemistry',
      ],
    ),
    SubjectMaster(
      id: 'english',
      officialName: 'اللغة الإنجليزية',
      category: 'إنجليزي',
      aliases: [
        'انجليزي', 'إنجليزي', 'انجليزية', 'إنجليزية', 'اللغة الإنجليزية',
        'لغة انجليزية', 'لغة إنجليزية', 'english', 'اللغة الانجليزية',
        'mega goal', 'traveller', 'flying high', 'انجليزى', 'انجليش',
      ],
    ),
    SubjectMaster(
      id: 'islamic',
      officialName: 'التربية الإسلامية',
      category: 'إسلامية',
      aliases: [
        'اسلامية', 'إسلامية', 'تربية اسلامية', 'تربية إسلامية',
        'دراسات اسلامية', 'دراسات إسلامية', 'الدراسات الإسلامية',
        'islamic', 'الدراسات الاسلاميه', 'تربيه اسلاميه',
      ],
    ),
    SubjectMaster(
      id: 'quran',
      officialName: 'القرآن الكريم',
      category: 'قرآن',
      aliases: [
        'قرآن', 'قران', 'تحفيظ', 'تحفيظ قرآن', 'القرآن الكريم',
        'quran', 'قرآن كريم', 'تلاوة',
      ],
    ),
    SubjectMaster(
      id: 'social',
      officialName: 'الاجتماعيات',
      category: 'اجتماعيات',
      aliases: [
        'اجتماعيات', 'إجتماعيات', 'دراسات اجتماعية', 'الاجتماعيات',
        'social', 'social studies', 'اجتماعيه', 'الاجتماعيه',
      ],
    ),
    SubjectMaster(
      id: 'computer',
      officialName: 'التقنية الرقمية',
      category: 'رقمية',
      aliases: [
        'حاسب', 'حاسوب', 'حوسبة', 'كمبيوتر', 'تقنية رقمية', 'computer',
        'cs', 'حاسب آلي', 'تقنيه رقميه', 'رقمية', 'الرقمية',
      ],
    ),
    SubjectMaster(
      id: 'pe',
      officialName: 'التربية البدنية',
      category: 'بدنية',
      aliases: [
        'بدنية', 'تربية بدنية', 'رياضة', 'رياضية', 'pe',
        'physical education', 'تربيه بدنيه', 'بدنيه',
      ],
    ),
    SubjectMaster(
      id: 'art',
      officialName: 'التربية الفنية',
      category: 'فنية',
      aliases: [
        'فنية', 'تربية فنية', 'رسم', 'art', 'فنيه', 'تربيه فنيه',
        'فنون', 'الفنون',
      ],
    ),
    SubjectMaster(
      id: 'braille',
      officialName: 'برايل',
      category: 'برايل',
      aliases: ['برايل', 'braille', 'لغة برايل'],
    ),
    SubjectMaster(
      id: 'life_skills',
      officialName: 'مهارات الحياة',
      category: 'مهارات',
      aliases: [
        'مهارات حياتية', 'مهارات الحياة', 'مهارات', 'life skills',
        'مهارات حياه', 'مهاره', 'حياتية', 'حياتيه', 'مهارات حياتيه',
        'الحياة', 'مهارات الحياه', 'تنمية مهارات',
      ],
    ),
  ];

  // aliases المحفوظة من Firestore (تُحمَّل مرة واحدة)
  static Map<String, String> _firestoreAliases = {};
  static bool _loaded = false;

  /// تحميل aliases من Firestore
  static Future<void> loadFromFirestore(String schoolId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('SubjectAliases')
          .get();
      _firestoreAliases = {};
      for (final doc in snap.docs) {
        final alias = doc.id;
        final subjectId = (doc.data()['subjectId'] ?? '').toString();
        if (subjectId.isNotEmpty) {
          _firestoreAliases[_normalizeKey(alias)] = subjectId;
        }
      }
      _loaded = true;
      debugPrint('✅ Loaded ${_firestoreAliases.length} subject aliases from Firestore');
    } catch (e) {
      debugPrint('⚠️ Could not load subject aliases: $e');
    }
  }

  /// حفظ alias جديد في Firestore
  static Future<void> saveAlias(
      String schoolId, String alias, String subjectId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('SubjectAliases')
          .doc(alias.trim())
          .set({
        'subjectId': subjectId,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'user_correction',
      });
      _firestoreAliases[_normalizeKey(alias)] = subjectId;
      debugPrint('✅ Saved alias: $alias → $subjectId');
    } catch (e) {
      debugPrint('❌ Failed to save alias: $e');
    }
  }

  /// مطابقة اسم مادة واحدة
  static SubjectMatchResult match(String rawName) {
    final cleaned = _clean(rawName);
    if (cleaned.isEmpty) {
      return SubjectMatchResult(
          rawName: rawName, confidence: MatchConfidence.unknown);
    }

    final key = _normalizeKey(cleaned);

    // 1. بحث في Firestore aliases أولاً
    if (_firestoreAliases.containsKey(key)) {
      final subjectId = _firestoreAliases[key]!;
      final master = _findById(subjectId);
      if (master != null) {
        return SubjectMatchResult(
          rawName: rawName,
          matched: master,
          confidence: MatchConfidence.high,
        );
      }
    }

    // 2. بحث في القاعدة الافتراضية
    for (final subject in _defaultSubjects) {
      // تطابق تام مع الاسم الرسمي
      if (_normalizeKey(subject.officialName) == key) {
        return SubjectMatchResult(
          rawName: rawName,
          matched: subject,
          confidence: MatchConfidence.high,
        );
      }
      // تطابق مع aliases
      for (final alias in subject.aliases) {
        if (_normalizeKey(alias) == key) {
          return SubjectMatchResult(
            rawName: rawName,
            matched: subject,
            confidence: MatchConfidence.high,
          );
        }
      }
    }

    // 3. بحث جزئي (similarity)
    SubjectMaster? bestMatch;
    int bestScore = 0;

    for (final subject in _defaultSubjects) {
      final score = _similarityScore(key, subject);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = subject;
      }
    }

    if (bestMatch != null && bestScore >= 3) {
      return SubjectMatchResult(
        rawName: rawName,
        matched: bestMatch,
        confidence: bestScore >= 5 ? MatchConfidence.medium : MatchConfidence.low,
        suggestion: bestMatch.officialName,
      );
    }

    return SubjectMatchResult(
      rawName: rawName,
      confidence: MatchConfidence.unknown,
    );
  }

  /// مطابقة قائمة من المواد
  static List<SubjectMatchResult> matchAll(List<String> rawNames) {
    return rawNames.map(match).toList();
  }

  /// الحصول على قائمة المواد الافتراضية
  static List<SubjectMaster> get defaultSubjects => _defaultSubjects;

  /// البحث عن مادة بالـ ID
  static SubjectMaster? findById(String id) => _findById(id);

  // ─── Private helpers ──────────────────────────────────────────────────────

  static SubjectMaster? _findById(String id) {
    try {
      return _defaultSubjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// تنظيف اسم المادة
  static String _clean(String raw) {
    var s = raw.trim();
    // تجاهل صيغ Excel والقيم الرقمية البحتة
    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||
        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) {
      return '';
    }
    // تجاهل القيم الرقمية البحتة
    if (RegExp(r'^[\d\s\.\,]+\$').hasMatch(s)) return '';
    // تجاهل النصوص القصيرة جداً (حرف أو حرفان)
    if (s.length <= 2) return '';
    // حذف كلمة "مادة" في البداية
    s = s.replaceAll(RegExp(r'^مادة\s*'), '');
    // حذف الأرقام في النهاية
    s = s.replaceAll(RegExp(r'\s*\d+\$'), '');
    return s.trim();
  }

  /// توحيد المفتاح
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
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
    return v;
  }

  /// حساب درجة التشابه — صارم لتجنب المطابقة الخاطئة
  static int _similarityScore(String key, SubjectMaster subject) {
    // لا نطابق إذا كان الاسم قصيراً جداً
    if (key.length < 3) return 0;
    int score = 0;
    final allNames = [
      subject.officialName,
      subject.category,
      ...subject.aliases,
    ];

    for (final name in allNames) {
      final nk = _normalizeKey(name);
      if (nk.isEmpty) continue;
      // تطابق تام
      if (nk == key) { score = 10; break; }
      // تطابق جزئي — يجب أن يكون الجزء المشترك >= 4 أحرف
      if (key.length >= 4 && nk.contains(key)) {
        score = score < 5 ? 5 : score;
      } else if (nk.length >= 4 && key.contains(nk)) {
        score = score < 4 ? 4 : score;
      }
      // تطابق بداية الكلمة فقط (أول 4 أحرف)
      if (key.length >= 4 && nk.length >= 4 && key.substring(0, 4) == nk.substring(0, 4)) {
        score = score < 6 ? 6 : score;
      }
    }
    return score;
  }

  static int _charOverlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    int count = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) count++;
    }
    return count;
  }
}
