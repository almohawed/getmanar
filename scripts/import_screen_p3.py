import pathlib
p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

dart = """
  // ─── Review Step ─────────────────────────────────────────────────────────
  Widget _buildReview() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.amber.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.amber.withOpacity(0.25))),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _P.amber.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.rate_review_rounded, color: _P.amber, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_reviewLessons.length.toString() + ' مادة تحتاج تحديد يدوي',
                style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('كل تصحيح يُحفظ تلقائياً للمرات القادمة',
                style: TextStyle(color: _P.muted, fontSize: 11)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _reviewLessons.length,
        itemBuilder: (context, i) => _reviewCard(_reviewLessons[i]),
      )),
      Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: double.infinity, child: _btn(
          'تأكيد وإكمال الاستيراد', Icons.rocket_launch_rounded, _executeImport, _P.emerald)),
      ),
    ]);
  }

  Widget _reviewCard(ImportedLesson lesson) {
    final resolved = lesson.matchResult.matched != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resolved ? _P.emerald.withOpacity(0.3) : _P.amber.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: resolved ? _P.emerald.withOpacity(0.06) : _P.amber.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Icon(resolved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: resolved ? _P.emerald : _P.amber, size: 16),
            const SizedBox(width: 8),
            Text('"' + lesson.rawSubject + '"',
                style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 14)),
            if (resolved) ...[ const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _P.muted, size: 12),
              const SizedBox(width: 4),
              Text(lesson.matchResult.matched!.officialName,
                  style: const TextStyle(color: _P.emerald, fontSize: 12))],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<String>(
            value: lesson.matchResult.matched?.id,
            dropdownColor: _P.surface,
            style: const TextStyle(color: _P.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'اختر التصنيف الصحيح',
              labelStyle: const TextStyle(color: _P.muted, fontSize: 12),
              filled: true, fillColor: _P.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P.violet, width: 1.5)),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('-- غير محدد --', style: TextStyle(color: _P.muted))),
              ...SubjectMatcher.defaultSubjects.map((s) => DropdownMenuItem(
                value: s.id, child: Text(s.officialName, style: const TextStyle(color: _P.text)))),
            ],
            onChanged: (id) {
              if (id == null) return;
              final master = SubjectMatcher.findById(id);
              if (master == null) return;
              setState(() {
                lesson.matchResult = SubjectMatchResult(rawName: lesson.rawSubject, matched: master, confidence: MatchConfidence.high);
                for (final l in _allLessons) { if (l.rawSubject == lesson.rawSubject) l.matchResult = lesson.matchResult; }
              });
              SubjectMatcher.saveAlias(_schoolId ?? '', lesson.rawSubject, id);
            },
          ),
        ),
        if (resolved)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              const Icon(Icons.bookmark_added_rounded, color: _P.emerald, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'سيُحفظ كمرادف: "' + lesson.rawSubject + '" → ' + (lesson.matchResult.matched?.officialName ?? ''),
                style: const TextStyle(color: _P.emerald, fontSize: 11))),
            ]),
          ),
      ]),
    );
  }

  // ─── Done Step ────────────────────────────────────────────────────────────
  Widget _buildDone() {
    final teacherCount = _allLessons.map((l) => l.teacherName).toSet().length;
    final subjectCount = _allLessons.map((l) => l.resolvedSubject).toSet().length;
    final classCount = _allLessons.map((l) => l.className).where((c) => c.isNotEmpty).toSet().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_P.emerald.withOpacity(0.2), Colors.transparent]),
              boxShadow: [BoxShadow(color: _P.emerald.withOpacity(_glowAnim.value * 0.35), blurRadius: 40)],
              border: Border.all(color: _P.emerald.withOpacity(0.5), width: 1.5),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _P.emerald, size: 50),
          ),
        ),
        const SizedBox(height: 20),
        const Text('تم الاستيراد بنجاح!',
            style: TextStyle(color: _P.text, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('تم حفظ الجدول وتوزيعه على المعلمين والفصول',
            style: const TextStyle(color: _P.muted, fontSize: 13)),
        const SizedBox(height: 28),
        Row(children: [
          _doneTile(Icons.people_rounded, teacherCount.toString(), 'معلم', _P.violet),
          const SizedBox(width: 10),
          _doneTile(Icons.menu_book_rounded, subjectCount.toString(), 'مادة', _P.sky),
          const SizedBox(width: 10),
          _doneTile(Icons.class_rounded, classCount.toString(), 'فصل', _P.amber),
          const SizedBox(width: 10),
          _doneTile(Icons.event_note_rounded, _allLessons.length.toString(), 'حصة', _P.emerald),
        ]),
        if (_importResult.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _P.emerald.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.emerald.withOpacity(0.2))),
            child: Text(_importResult, style: const TextStyle(color: _P.emerald, fontSize: 13, height: 1.6)),
          ),
        ],
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: _btn('استيراد جدول آخر', Icons.upload_file_rounded, _reset, _P.violet)),
          const SizedBox(width: 12),
          Expanded(child: _btn('العودة', Icons.arrow_back_rounded,
              () => Navigator.of(context).pop(), _P.muted)),
        ]),
      ]),
    );
  }

  Widget _doneTile(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _P.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 16)]),
      child: Column(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 10)),
      ]),
    ));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_P.violet, _P.sky],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: _P.text, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color == _P.muted ? _P.card : color,
        foregroundColor: color == _P.muted ? _P.muted : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: color == _P.muted ? const BorderSide(color: _P.border) : BorderSide.none),
        elevation: 0,
      ),
    );
  }
}
"""

p.write_text(c + dart, encoding='utf-8')
print('part3 ok')
