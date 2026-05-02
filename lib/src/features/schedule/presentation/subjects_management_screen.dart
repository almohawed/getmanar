/// subjects_management_screen.dart
/// إدارة المواد الدراسية — إضافة وحذف
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0A0A0F);
const _surface = Color(0xFF10101C);
const _card    = Color(0xFF18182A);
const _violet  = Color(0xFF7C3AED);
const _violetL = Color(0xFFA78BFA);
const _emerald = Color(0xFF10B981);
const _rose    = Color(0xFFF43F5E);
const _amber   = Color(0xFFF59E0B);
const _border  = Color(0xFF252538);
const _text    = Color(0xFFF1F5F9);
const _muted   = Color(0xFF64748B);

// ─── المواد الافتراضية ────────────────────────────────────────────────────────
const _defaultSubjects = [
  'اللغة العربية', 'الرياضيات', 'العلوم', 'اللغة الإنجليزية',
  'التربية الإسلامية', 'القرآن الكريم', 'الاجتماعيات',
  'المهارات الرقمية', 'التربية البدنية', 'التربية الفنية',
  'مهارات الحياة', 'برايل', 'نشاط', 'التفكير الناقد',
  'المهارات الرقمية',
];

class SubjectsManagementScreen extends ConsumerStatefulWidget {
  const SubjectsManagementScreen({super.key});
  @override
  ConsumerState<SubjectsManagementScreen> createState() => _SubjectsManagementScreenState();
}

class _SubjectsManagementScreenState extends ConsumerState<SubjectsManagementScreen> {
  String? _schoolId;
  bool _isLoading = false;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // تحميل schoolId فوراً
    Future.microtask(() {
      final user = ref.read(authStateProvider).value;
      if (user != null && mounted) {
        setState(() => _schoolId = user.schoolId);
        // تحقق إذا كانت المواد فارغة وأضف الافتراضية تلقائياً
        _autoSeedIfEmpty(user.schoolId ?? '');
      }
    });
  }

  Future<void> _autoSeedIfEmpty(String schoolId) async {
    if (schoolId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools').doc(schoolId).collection('Subjects')
          .limit(1).get();
      if (snap.docs.isEmpty) {
        await _seedDefaults([]);
      }
    } catch (_) {}
  }

  @override
  void dispose() { _addCtrl.dispose(); super.dispose(); }

  CollectionReference? get _col => _schoolId == null ? null
      : FirebaseFirestore.instance.collection('Schools').doc(_schoolId).collection('Subjects');

  Future<void> _addSubject(String name) async {
    final n = name.trim();
    if (n.isEmpty || _col == null) return;
    setState(() => _isLoading = true);
    try {
      await _col!.doc(n).set({'name': n, 'createdAt': FieldValue.serverTimestamp(), 'isDefault': false});
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSubject(String id) async {
    if (_col == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المادة', style: TextStyle(color: _text)),
        content: Text('هل تريد حذف "$id"؟', style: const TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: _rose))),
        ],
      ),
    );
    if (ok == true) await _col!.doc(id).delete();
  }

  Future<void> _seedDefaults(List<String> existing) async {
    if (_col == null) return;
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final s in _defaultSubjects) {
        if (!existing.contains(s)) {
          batch.set(_col!.doc(s), {'name': s, 'createdAt': FieldValue.serverTimestamp(), 'isDefault': true});
        }
      }
      await batch.commit();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    _addCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إضافة مادة جديدة', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _addCtrl,
          autofocus: true,
          style: const TextStyle(color: _text),
          decoration: InputDecoration(
            hintText: 'اسم المادة',
            hintStyle: const TextStyle(color: _muted),
            filled: true, fillColor: _surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _violet, width: 1.5)),
          ),
          onSubmitted: (v) { Navigator.pop(context); _addSubject(v); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: _muted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _addSubject(_addCtrl.text); },
            style: ElevatedButton.styleFrom(backgroundColor: _violet, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildTopBar(),
        Expanded(child: _schoolId == null
            ? const Center(child: CircularProgressIndicator(color: _violetL))
            : _buildBody()),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(bottom: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: _violet.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _muted, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_violet, Color(0xFF38BDF8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _violet.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المواد الدراسية', style: TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('الجداول الدراسية', style: TextStyle(color: _muted, fontSize: 11)),
        ])),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('إضافة مادة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _violet, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _col!.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _violetL));
        }

        final docs = snap.data?.docs ?? [];
        // ترتيب محلي بدلاً من orderBy لتجنب مشكلة الـ index
        docs.sort((a, b) => a.id.compareTo(b.id));
        final names = docs.map((d) => d.id).toList();

        return Column(children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            color: _surface,
            child: Row(children: [
              _statChip(docs.length.toString(), 'مادة', _violet),
              const SizedBox(width: 12),
              _statChip(docs.where((d) => (d.data() as Map)['isDefault'] == true).length.toString(),
                  'افتراضية', _emerald),
              const SizedBox(width: 12),
              _statChip(docs.where((d) => (d.data() as Map)['isDefault'] != true).length.toString(),
                  'مضافة', _amber),
              const Spacer(),
              if (docs.isEmpty || names.length < _defaultSubjects.length)
                TextButton.icon(
                  onPressed: () => _seedDefaults(names),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                  label: const Text('إضافة المواد الافتراضية', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: _violetL),
                ),
            ]),
          ),
          // List
          Expanded(child: docs.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildSubjectCard(docs[i]),
                )),
        ]);
      },
    );
  }

  Widget _buildSubjectCard(QueryDocumentSnapshot doc) {
    final name = doc.id;
    final isDefault = (doc.data() as Map)['isDefault'] == true;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? _violet.withOpacity(0.2) : _border),
      ),
      child: Row(children: [
        Container(
          width: 4,
          decoration: BoxDecoration(
            color: isDefault ? _violet : _amber,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(isDefault ? 'افتراضية' : 'مضافة',
                style: TextStyle(color: isDefault ? _violetL : _amber, fontSize: 10)),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _rose),
          onPressed: () => _deleteSubject(name),
          tooltip: 'حذف',
          style: IconButton.styleFrom(
            backgroundColor: _rose.withOpacity(0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _violet.withOpacity(0.1), shape: BoxShape.circle,
          border: Border.all(color: _violet.withOpacity(0.3)),
        ),
        child: const Icon(Icons.menu_book_rounded, color: _violetL, size: 36),
      ),
      const SizedBox(height: 16),
      const Text('لا توجد مواد دراسية', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('أضف المواد الافتراضية أو أضف مادة جديدة', style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => _seedDefaults([]),
        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
        label: const Text('إضافة المواد الافتراضية'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _violet, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ]),
    );
  }
}
