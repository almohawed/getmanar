import pathlib

p = pathlib.Path('lib/src/features/schedule/services/subject_matcher.dart')
c = p.read_text(encoding='utf-8')

# Fix 1: Add 'life_skills' aliases to include 'حياتية' and 'حياتيه'
old_life = (
    "    SubjectMaster(\n"
    "      id: 'life_skills',\n"
    "      officialName: 'مهارات الحياة',\n"
    "      category: 'مهارات',\n"
    "      aliases: [\n"
    "        'مهارات حياتية', 'مهارات الحياة', 'مهارات', 'life skills',\n"
    "        'مهارات حياه', 'مهاره',\n"
    "      ],\n"
    "    ),"
)
new_life = (
    "    SubjectMaster(\n"
    "      id: 'life_skills',\n"
    "      officialName: 'مهارات الحياة',\n"
    "      category: 'مهارات',\n"
    "      aliases: [\n"
    "        'مهارات حياتية', 'مهارات الحياة', 'مهارات', 'life skills',\n"
    "        'مهارات حياه', 'مهاره', 'حياتية', 'حياتيه', 'مهارات حياتيه',\n"
    "        'الحياة', 'مهارات الحياه', 'تنمية مهارات',\n"
    "      ],\n"
    "    ),"
)
c = c.replace(old_life, new_life)

# Fix 2: Fix _clean to filter out Excel formulas and invalid content
old_clean = (
    "  /// تنظيف اسم المادة\n"
    "  static String _clean(String raw) {\n"
    "    var s = raw.trim();\n"
    "    // حذف كلمة \"مادة\" في البداية\n"
    "    s = s.replaceAll(RegExp(r'^مادة\\s*'), '');\n"
    "    // حذف الأرقام في النهاية\n"
    "    s = s.replaceAll(RegExp(r'\\s*\\d+"
)
# Find the actual clean function
idx = c.find("  /// تنظيف اسم المادة")
if idx == -1:
    print("Could not find _clean function")
else:
    # Find end of function
    end = c.find("\n  }", idx) + 4
    old_fn = c[idx:end]
    new_fn = (
        "  /// تنظيف اسم المادة\n"
        "  static String _clean(String raw) {\n"
        "    var s = raw.trim();\n"
        "    // تجاهل صيغ Excel والقيم الرقمية البحتة\n"
        "    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||\n"
        "        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) {\n"
        "      return '';\n"
        "    }\n"
        "    // تجاهل القيم الرقمية البحتة\n"
        "    if (RegExp(r'^[\\d\\s\\.\\,]+\$').hasMatch(s)) return '';\n"
        "    // تجاهل النصوص القصيرة جداً (حرف أو حرفان)\n"
        "    if (s.length <= 2) return '';\n"
        "    // حذف كلمة \"مادة\" في البداية\n"
        "    s = s.replaceAll(RegExp(r'^مادة\\s*'), '');\n"
        "    // حذف الأرقام في النهاية\n"
        "    s = s.replaceAll(RegExp(r'\\s*\\d+\$'), '');\n"
        "    return s.trim();\n"
        "  }"
    )
    c = c[:idx] + new_fn + c[end:]
    print("Fixed _clean function")

# Fix 3: Fix _similarityScore to be stricter - require minimum length match
old_sim = (
    "  /// حساب درجة التشابه\n"
    "  static int _similarityScore(String key, SubjectMaster subject) {\n"
    "    int score = 0;\n"
    "    final allNames = [\n"
    "      subject.officialName,\n"
    "      subject.category,\n"
    "      ...subject.aliases,\n"
    "    ];\n"
    "\n"
    "    for (final name in allNames) {\n"
    "      final nk = _normalizeKey(name);\n"
    "      if (nk.contains(key) || key.contains(nk)) {\n"
    "        score += nk.length == key.length ? 6 : 3;\n"
    "      }\n"
    "      // تطابق جزئي بالأحرف\n"
    "      final overlap = _charOverlap(key, nk);\n"
    "      if (overlap > score) score = overlap;\n"
    "    }\n"
    "    return score;\n"
    "  }"
)
new_sim = (
    "  /// حساب درجة التشابه — صارم لتجنب المطابقة الخاطئة\n"
    "  static int _similarityScore(String key, SubjectMaster subject) {\n"
    "    // لا نطابق إذا كان الاسم قصيراً جداً\n"
    "    if (key.length < 3) return 0;\n"
    "    int score = 0;\n"
    "    final allNames = [\n"
    "      subject.officialName,\n"
    "      subject.category,\n"
    "      ...subject.aliases,\n"
    "    ];\n"
    "\n"
    "    for (final name in allNames) {\n"
    "      final nk = _normalizeKey(name);\n"
    "      if (nk.isEmpty) continue;\n"
    "      // تطابق تام\n"
    "      if (nk == key) { score = 10; break; }\n"
    "      // تطابق جزئي — يجب أن يكون الجزء المشترك >= 4 أحرف\n"
    "      if (key.length >= 4 && nk.contains(key)) {\n"
    "        score = score < 5 ? 5 : score;\n"
    "      } else if (nk.length >= 4 && key.contains(nk)) {\n"
    "        score = score < 4 ? 4 : score;\n"
    "      }\n"
    "      // تطابق بداية الكلمة فقط (أول 4 أحرف)\n"
    "      if (key.length >= 4 && nk.length >= 4 && key.substring(0, 4) == nk.substring(0, 4)) {\n"
    "        score = score < 6 ? 6 : score;\n"
    "      }\n"
    "    }\n"
    "    return score;\n"
    "  }"
)
if old_sim in c:
    c = c.replace(old_sim, new_sim)
    print("Fixed _similarityScore")
else:
    print("Could not find _similarityScore - trying partial match")
    idx2 = c.find("  static int _similarityScore")
    if idx2 != -1:
        end2 = c.find("\n  }", idx2) + 4
        c = c[:idx2] + new_sim + c[end2:]
        print("Fixed _similarityScore via index")

p.write_text(c, encoding='utf-8')
print("Done")
