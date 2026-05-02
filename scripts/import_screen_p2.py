import pathlib
p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

dart = """
  // ─── Upload Step ─────────────────────────────────────────────────────────
  Widget _buildUpload() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const SizedBox(height: 8),
        // Drop zone
        GestureDetector(
          onTap: _pickFile,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: double.infinity, height: 200,
              decoration: BoxDecoration(
                color: _P.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _P.violet.withOpacity(0.25 + _glowAnim.value * 0.2), width: 1.5),
                boxShadow: [BoxShadow(color: _P.violet.withOpacity(_glowAnim.value * 0.06), blurRadius: 40)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_P.violet.withOpacity(0.2), _P.sky.withOpacity(0.1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(color: _P.violet.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: _P.violet.withOpacity(_glowAnim.value * 0.3), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: _P.violetLt, size: 34),
                ),
                const SizedBox(height: 16),
                const Text('اسحب الملف هنا أو اضغط للاختيار',
                    style: TextStyle(color: _P.text, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('يدعم .xlsx و .xls', style: const TextStyle(color: _P.muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Format guide
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _P.card, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _P.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 3, height: 18, decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_P.violet, _P.sky], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('الصيغة المدعومة: الجدول الذكي — جدول المعلمين',
                  style: TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 14),
            _fmtRow('B', 'المعلمون في العمود B من الصف 4', _P.muted),
            _fmtRow('C-I', 'الأحد: C-I', _P.sky),
            _fmtRow('J-P', 'الاثنين: J-P', _P.sky),
            _fmtRow('Q-W', 'الثلاثاء: Q-W', _P.sky),
            _fmtRow('X-AD', 'الأربعاء: X-AD', _P.sky),
            _fmtRow('Af-AK', 'الخميس: Af-AK', _P.sky),
            const SizedBox(height: 8),
            _fmtRow('●', 'كل خلية: رقم الصف / رقم الفصل + المادة', _P.amber),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: _btn('اختيار ملف Excel', Icons.folder_open_rounded, _pickFile, _P.violet)),
      ]),
    );
  }

  Widget _fmtRow(String tag, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Container(
          width: 32, height: 22,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Center(child: Text(tag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Text(desc, style: const TextStyle(color: _P.muted, fontSize: 12)),
      ]),
    );
  }

  // ─── Analyze Step ─────────────────────────────────────────────────────────
  Widget _buildAnalyze() {
    final total = _subjectStats.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: _P.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border)),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_rounded, color: _P.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_fileName, style: const TextStyle(color: _P.text, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _P.emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('تم التحليل', style: TextStyle(color: _P.emerald, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          _statTile(total.toString(), 'مادة مكتشفة', _P.sky, Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          _statTile(_knownCount.toString(), 'معروفة', _P.emerald, Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _statTile(_unknownCount.toString(), 'تحتاج مراجعة',
              _unknownCount > 0 ? _P.amber : _P.emerald, Icons.pending_rounded),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('المواد المكتشفة'),
        const SizedBox(height: 10),
        ..._subjectStats.entries.map((e) => _subjectRow(e.key, SubjectMatcher.match(e.key), e.value)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: _btn(
          _reviewLessons.isEmpty ? 'متابعة للاستيراد' : 'مراجعة المواد غير المعروفة',
          Icons.arrow_forward_rounded,
          () {
            if (_reviewLessons.isEmpty) { _executeImport(); }
            else { setState(() => _step = _ImportStep.review); }
          }, _P.violet)),
      ]),
    );
  }

  Widget _statTile(String value, String label, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 10)])),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 10), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _subjectRow(String raw, SubjectMatchResult result, int count) {
    Color color; String badge; IconData icon;
    if (result.confidence == MatchConfidence.high) { color = _P.emerald; badge = 'معروفة'; icon = Icons.check_circle_rounded; }
    else if (result.confidence == MatchConfidence.medium) { color = _P.amber; badge = 'مقترحة'; icon = Icons.help_rounded; }
    else { color = _P.rose; badge = 'غير معروفة'; icon = Icons.error_rounded; }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _P.card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(raw, style: const TextStyle(color: _P.text, fontWeight: FontWeight.w600, fontSize: 13)),
          if (result.matched != null)
            Text('→ ' + result.matched!.officialName, style: TextStyle(color: color, fontSize: 11)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Text(count.toString() + ' حصة', style: const TextStyle(color: _P.muted, fontSize: 10)),
      ]),
    );
  }
"""

p.write_text(c + dart, encoding='utf-8')
print('part2 ok')
