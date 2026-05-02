import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Find the PE section and expand it, then add new subjects
old_pe = (
    "    // بدنية\n"
    "    if (n == 'بدنيه' || n == 'تربيه بدنيه' || n == 'رياضه' || n == 'رياضيه') return 'التربية البدنية';\n"
    "    // فنية\n"
    "    if (n == 'فنيه' || n == 'تربيه فنيه' || n == 'رسم' || n == 'فنون') return 'التربية الفنية';"
)

new_pe = (
    "    // بدنية — جميع الأشكال\n"
    "    if (n == 'بدنيه' || n == 'تربيه بدنيه' || n == 'التربيه البدنيه' ||\n"
    "        n == 'تربيه البدنيه' || n == 'البدنيه' || n == 'رياضه' || n == 'رياضيه') return 'التربية البدنية';\n"
    "    // فنية — جميع الأشكال\n"
    "    if (n == 'فنيه' || n == 'تربيه فنيه' || n == 'التربيه الفنيه' ||\n"
    "        n == 'تربيه الفنيه' || n == 'الفنيه' || n == 'رسم' || n == 'فنون') return 'التربية الفنية';\n"
    "    // تفكير ناقد — جميع الأشكال\n"
    "    if (n == 'تفكير ناقد' || n == 'التفكير الناقد' || n == 'ناقد' ||\n"
    "        n == 'تفكيرناقد' || n == 'ناقدتفكير' || n == 'الناقد') return 'التفكير الناقد';\n"
    "    // مهارات رقمية — جميع الأشكال\n"
    "    if (n == 'مهارات رقميه' || n == 'المهارات الرقميه' || n == 'مهارات الرقميه' ||\n"
    "        n == 'رقميه' || n == 'الرقميه' || n == 'تقنيه رقميه' || n == 'التقنيه الرقميه') return 'التقنية الرقمية';"
)

if old_pe in c:
    c = c.replace(old_pe, new_pe)
    print("Fixed PE/Art/Critical Thinking/Digital sections")
else:
    print("Pattern not found, searching...")
    idx = c.find("بدنيه")
    print(f"بدنيه at index: {idx}")
    if idx != -1:
        print(repr(c[max(0,idx-100):idx+300]))

# Also fix the partial search section at the bottom
old_partial_pe = "    if (n.contains('بدني')) return 'التربية البدنية';\n"
new_partial_pe = (
    "    if (n.contains('بدني') || n.contains('بدنيه')) return 'التربية البدنية';\n"
)
c = c.replace(old_partial_pe, new_partial_pe)

old_partial_art = "    if (n.contains('فني') || n.contains('رسم')) return 'التربية الفنية';\n"
new_partial_art = (
    "    if (n.contains('فني') || n.contains('فنيه') || n.contains('رسم')) return 'التربية الفنية';\n"
)
c = c.replace(old_partial_art, new_partial_art)

# Add critical thinking and digital skills to partial search
old_partial_digital = "    if (n.contains('حاسب') || n.contains('رقمي')) return 'التقنية الرقمية';\n"
new_partial_digital = (
    "    if (n.contains('حاسب') || n.contains('رقمي') || n.contains('رقميه') ||\n"
    "        n.contains('مهارات رقم')) return 'التقنية الرقمية';\n"
)
c = c.replace(old_partial_digital, new_partial_digital)

# Add critical thinking to partial search
old_partial_life = "    if (n.contains('حياتي') || n.contains('مهارات')) return 'مهارات الحياة';\n"
new_partial_life = (
    "    if (n.contains('حياتي') || n.contains('مهارات')) return 'مهارات الحياة';\n"
    "    if (n.contains('تفكير') || n.contains('ناقد')) return 'التفكير الناقد';\n"
)
c = c.replace(old_partial_life, new_partial_life)

p.write_text(c, encoding='utf-8')
print("Done")
