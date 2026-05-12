// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';

// ─── نماذج البيانات ───────────────────────────────────────────────────────────

class _BehaviorItem {
  final String title;
  final int points;
  const _BehaviorItem(this.title, this.points);
}

// سلوكيات التميز (20% من الدرجة)
const _meritBehaviors = [
  _BehaviorItem('مساعدة زميل', 2),
  _BehaviorItem('مبادرة مميزة', 2),
  _BehaviorItem('تفوق في اختبار', 2),
  _BehaviorItem('نظافة ومواظبة', 3),
  _BehaviorItem('إجابة صحيحة في الحصة', 2),
  _BehaviorItem('المشاركة في أنشطة المهارات الرقمية', 4),
  _BehaviorItem('الالتحاق ببرنامج أو دورة تدريبية', 6),
  _BehaviorItem('المشاركة في مسابقات أو جوائز', 4),
  _BehaviorItem('عرض تجارب شخصية ناجحة أمام الزملاء', 6),
  _BehaviorItem('التعاون مع الزملاء والمعلمين والإدارة', 3),
  _BehaviorItem('المشاركة في الخدمة المجتمعية خارج المدرسة', 6),
  _BehaviorItem('كتابة رسالة شكر للوطن أو القيادة أو المعلم', 5),
  _BehaviorItem('تقديم فعالية حوارية', 6),
  _BehaviorItem('المشاركة في حملة توعوية', 6),
  _BehaviorItem('عرض تجارب شخصية ناجحة', 6),
  _BehaviorItem('العمل الجماعي', 4),
  _BehaviorItem('التعلم بالاقران', 4),
  _BehaviorItem('المشاركة في الإذاعة', 2),
];

// سلوكيات التعويض (استعادة الدرجات المحسومة من السلوك الإيجابي)
const _compensationBehaviors = [
  _BehaviorItem('القيام بتنظيم دخول الطلاب في الفصول', 3),
  _BehaviorItem('المشاركة في الخدمة المجتمعية خارج المدرسة (إحضار مايثبت) 6 درجات', 5),
  _BehaviorItem('المشاركة في برامج إرشادية', 3),
  _BehaviorItem('تكليفات تربوية مناسبة', 2),
  _BehaviorItem('تنفيذ نشاط توعوي', 4),
  _BehaviorItem('إعداد ملخص للدرس وتسليمه (في حال كانت المخالفة عدم تنفيذ الواجبات)', 2),
  _BehaviorItem('المشاركة في توعية المحافظة على الممتلكات', 5),
];

// ─── الشاشة الرئيسية ──────────────────────────────────────────────────────────

class MeritCompensationScreen extends ConsumerStatefulWidget {
  const MeritCompensationScreen({super.key});

  @override
  ConsumerState<MeritCompensationScreen> createState() =>
      _MeritCompensationScreenState();
}

class _MeritCompensationScreenState
    extends ConsumerState<MeritCompensationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isTeacher = user?.role == UserRole.teacher;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2E45),
          title: const Text(
            'التميز والتعويض السلوكي',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.star, color: Colors.amber), text: 'تميز'),
              Tab(icon: Icon(Icons.refresh, color: Colors.green), text: 'تعويض'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _BehaviorTab(
              type: 'merit',
              behaviors: _meritBehaviors,
              color: Colors.amber,
              maxPoints: 20,
              description: 'رصد سلوك التميز — النقاط تُضاف لرصيد التميز (سقف العرض 20 نقطة).\nيُرسل إشعار لولي الأمر والوكيل والإداري فور التسجيل.',
              buttonText: 'تسجيل سلوك التميز وإشعار ولي الأمر',
              isTeacher: isTeacher,
              user: user,
            ),
            _BehaviorTab(
              type: 'compensation',
              behaviors: _compensationBehaviors,
              color: Colors.green,
              maxPoints: 80,
              description: 'رصد السلوك التعويضي — النقاط تُعاد لرصيد السلوك الإيجابي.\nيُرسل إشعار لولي الأمر وتقرير للوكيل والإداري فور التسجيل.',
              buttonText: 'تسجيل السلوك التعويضي وإشعار ولي الأمر',
              isTeacher: isTeacher,
              user: user,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── تبويب السلوك ─────────────────────────────────────────────────────────────

class _BehaviorTab extends ConsumerStatefulWidget {
  final String type;
  final List<_BehaviorItem> behaviors;
  final Color color;
  final int maxPoints;
  final String description;
  final String buttonText;
  final bool isTeacher;
  final AppUser? user;

  const _BehaviorTab({
    required this.type,
    required this.behaviors,
    required this.color,
    required this.maxPoints,
    required this.description,
    required this.buttonText,
    required this.isTeacher,
    required this.user,
  });

  @override
  ConsumerState<_BehaviorTab> createState() => _BehaviorTabState();
}

class _BehaviorTabState extends ConsumerState<_BehaviorTab> {
  int? _selectedBehaviorIndex;
  final Set<String> _selectedStudents = {};
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _selectedClass;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final schoolId = widget.user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    try {
      // للمعلم: جلب فصوله فقط
      if (widget.isTeacher) {
        final teacherId = widget.user?.id ?? '';
        final snap = await FirebaseFirestore.instance
            .collection('Schools/$schoolId/Schedule')
            .where('teacherId', isEqualTo: teacherId)
            .get();

        final classSet = <String>{};
        for (final doc in snap.docs) {
          final cls = doc.data()['className'] as String?;
          if (cls != null) classSet.add(cls);
        }
        setState(() {
          _classes = classSet.map((c) => {'name': c, 'id': c}).toList();
        });
      } else {
        // للوكيل والمرشد: جميع الفصول
        final snap = await FirebaseFirestore.instance
            .collection('Schools/$schoolId/Classes')
            .get();
        setState(() {
          _classes = snap.docs
              .map((d) => {'name': d.data()['name'] ?? d.id, 'id': d.id})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadStudents(String className) async {
    final schoolId = widget.user?.schoolId ?? '';
    if (schoolId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Students')
          .where('className', isEqualTo: className)
          .orderBy('name')
          .get();

      setState(() {
        _students = snap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'name': data['name'] ?? '',
            'behaviorScore': (data['behaviorScore'] ?? 80.0).toDouble(),
            'meritScore': (data['meritScore'] ?? 0.0).toDouble(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  Future<void> _submit() async {
    if (_selectedBehaviorIndex == null) {
      _showSnack('يرجى اختيار نوع السلوك');
      return;
    }
    if (_selectedStudents.isEmpty) {
      _showSnack('يرجى اختيار طالب واحد على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final behavior = widget.behaviors[_selectedBehaviorIndex!];
      final schoolId = widget.user?.schoolId ?? '';
      final teacherId = widget.user?.id ?? '';
      final teacherName = widget.user?.name ?? '';
      final batch = FirebaseFirestore.instance.batch();

      for (final studentId in _selectedStudents) {
        final student = _students.firstWhere((s) => s['id'] == studentId);
        final studentName = student['name'] as String;

        // سجل السلوك
        final recordRef = FirebaseFirestore.instance
            .collection('Schools/$schoolId/BehaviorRecords')
            .doc();

        batch.set(recordRef, {
          'studentId': studentId,
          'studentName': studentName,
          'className': _selectedClass,
          'type': widget.type, // 'merit' or 'compensation'
          'behaviorTitle': behavior.title,
          'points': behavior.points,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'notes': _notesController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'schoolId': schoolId,
        });

        // تحديث درجة الطالب
        final studentRef = FirebaseFirestore.instance
            .collection('Schools/$schoolId/Students')
            .doc(studentId);

        if (widget.type == 'merit') {
          batch.update(studentRef, {
            'meritScore': FieldValue.increment(behavior.points),
          });
        } else {
          batch.update(studentRef, {
            'behaviorScore': FieldValue.increment(behavior.points),
          });
        }

        // إشعار لولي الأمر
        final notifRef = FirebaseFirestore.instance
            .collection('Schools/$schoolId/Notifications')
            .doc();

        final typeLabel = widget.type == 'merit' ? 'تميز' : 'تعويض';
        batch.set(notifRef, {
          'title': 'سلوك $typeLabel - ${behavior.title}',
          'body': 'حصل $studentName على ${behavior.points} نقطة $typeLabel بسبب: ${behavior.title}',
          'studentId': studentId,
          'studentName': studentName,
          'type': 'behavior_${widget.type}',
          'points': behavior.points,
          'teacherName': teacherName,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'schoolId': schoolId,
        });
      }

      await batch.commit();

      setState(() {
        _selectedBehaviorIndex = null;
        _selectedStudents.clear();
        _notesController.clear();
        _isLoading = false;
      });

      _showSnack('✅ تم التسجيل وإرسال الإشعارات بنجاح', success: true);
      await _loadStudents(_selectedClass ?? '');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('حدث خطأ: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // وصف
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(widget.type == 'merit' ? Icons.star : Icons.refresh,
                    color: widget.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.description,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // اختيار الفصل
          _buildSectionTitle('🏫 اختيار الفصل'),
          const SizedBox(height: 8),
          if (_classes.isEmpty)
            const Center(
              child: Text('جاري تحميل الفصول...',
                  style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classes.map((cls) {
                final isSelected = _selectedClass == cls['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedClass = cls['name'];
                      _selectedStudents.clear();
                    });
                    _loadStudents(cls['name']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.color : const Color(0xFF1A2E45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? widget.color : Colors.white24,
                      ),
                    ),
                    child: Text(
                      cls['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // اختيار نوع السلوك
          _buildSectionTitle(
              widget.type == 'merit' ? '⭐ نوع سلوك التميز (اختر واحداً)' : '🔄 نوع السلوك التعويضي (اختر واحداً)'),
          const SizedBox(height: 8),
          ...widget.behaviors.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            final isSelected = _selectedBehaviorIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedBehaviorIndex = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.color.withOpacity(0.2)
                      : const Color(0xFF1A2E45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? widget.color : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.title,
                        style: TextStyle(
                          color: isSelected ? widget.color : Colors.white,
                          fontFamily: 'Cairo',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: widget.color),
                      ),
                      child: Text(
                        '+${b.points} نقطة',
                        style: TextStyle(
                          color: widget.color,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // اختيار الطلاب
          if (_selectedClass != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('👥 الطلاب'),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedStudents.addAll(_students.map((s) => s['id'] as String));
                      }),
                      child: Text('تحديد الكل',
                          style: TextStyle(color: widget.color, fontFamily: 'Cairo')),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedStudents.clear()),
                      child: const Text('إلغاء الكل',
                          style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ],
            ),
            if (_selectedStudents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'تم تحديد ${_selectedStudents.length} طالب',
                  style: TextStyle(
                    color: widget.color,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_students.isEmpty)
              const Center(
                child: Text('جاري تحميل الطلاب...',
                    style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _students.length,
                itemBuilder: (context, i) {
                  final s = _students[i];
                  final id = s['id'] as String;
                  final isSelected = _selectedStudents.contains(id);
                  final score = widget.type == 'merit'
                      ? s['meritScore'] as double
                      : s['behaviorScore'] as double;

                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedStudents.remove(id);
                      } else {
                        _selectedStudents.add(id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.color.withOpacity(0.2)
                            : const Color(0xFF1A2E45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? widget.color : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => setState(() {
                              if (isSelected) {
                                _selectedStudents.remove(id);
                              } else {
                                _selectedStudents.add(id);
                              }
                            }),
                            activeColor: widget.color,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          Expanded(
                            child: Text(
                              s['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Cairo',
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${score.toStringAsFixed(1)}/${widget.maxPoints}',
                            style: TextStyle(
                              color: widget.color,
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
          ],

          // ملاحظات
          _buildSectionTitle('📝 ملاحظات (اختياري)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'تفاصيل إضافية...',
              hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
              filled: true,
              fillColor: const Color(0xFF1A2E45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // زر التسجيل
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    widget.type == 'merit' ? Icons.star : Icons.refresh,
                    color: Colors.white,
                  ),
            label: Text(
              widget.buttonText,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Cairo',
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}
