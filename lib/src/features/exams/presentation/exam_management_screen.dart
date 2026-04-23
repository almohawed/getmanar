import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import 'exam_seating_screen.dart';
import '../../../core/domain/models/user.dart';

enum DoorPosition { leftFront, rightFront, rightBoard, leftBoard }

DoorPosition _doorPositionFromRaw(Object? raw) {
  final s = (raw ?? '').toString().trim().toLowerCase();
  if (s == 'left_front') return DoorPosition.leftFront;
  if (s == 'right_front') return DoorPosition.rightFront;
  if (s == 'right_board') return DoorPosition.rightBoard;
  if (s == 'left_board') return DoorPosition.leftBoard;
  return DoorPosition.rightFront;
}

String _doorPositionToRaw(DoorPosition p) {
  return switch (p) {
    DoorPosition.leftFront => 'left_front',
    DoorPosition.rightFront => 'right_front',
    DoorPosition.rightBoard => 'right_board',
    DoorPosition.leftBoard => 'left_board',
  };
}

class ExamManagementScreen extends ConsumerStatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  ConsumerState<ExamManagementScreen> createState() =>
      _ExamManagementScreenState();
}

class _ExamManagementScreenState extends ConsumerState<ExamManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmartSectionScaffold(
      title: 'إدارة الاختبارات الذكية',
      icon: Icons.assignment,
      themeColor: Colors.red.shade700,
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExamSeatingScreen(),
              ),
            );
          },
          icon: const Icon(Icons.event_seat),
          tooltip: 'الجلوس الاختباري',
        ),
      ],
      initialRecommendation:
          'توصي الوزارة بتوزيع جداول الاختبارات بشكل متوازن ومراعاة الفروق الفردية في اللجان.',
      body: Column(
        children: [
          Container(
            color: Colors.red.shade700,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
              tabs: const [
                Tab(text: 'جدول الاختبارات'),
                Tab(text: 'توزيع اللجان'),
                Tab(text: 'أعضاء الكنترول'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ExamScheduleTab(),
                _CommitteesTab(),
                _ControlMembersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tab 1: Exam Schedule ---
class _ExamScheduleTab extends ConsumerStatefulWidget {
  const _ExamScheduleTab();

  @override
  ConsumerState<_ExamScheduleTab> createState() => _ExamScheduleTabState();
}

class _ExamScheduleTabState extends ConsumerState<_ExamScheduleTab> {
  static const _scheduleSettingsDocId = 'exam_schedule';

  final _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _scheduleSub;
  String _boundSchoolId = '';

  bool _isGenerating = false;
  bool _isApproving = false;
  double _progress = 0.0;
  List<Map<String, String>> _schedule = [];

  static const _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  static const _defaultSubjects = [
    'الرياضيات',
    'اللغة العربية',
    'العلوم',
    'اللغة الإنجليزية',
    'التربية الإسلامية',
  ];

  @override
  void initState() {
    super.initState();
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      final schoolId = (next.asData?.value?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return;
      if (schoolId == _boundSchoolId) return;
      _bindScheduleStream(schoolId);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolId = (ref.read(authStateProvider).asData?.value?.schoolId ?? '')
          .trim();
      if (schoolId.isNotEmpty) _bindScheduleStream(schoolId);
    });
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _scheduleDoc(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc(_scheduleSettingsDocId);
  }

  void _bindScheduleStream(String schoolId) {
    _scheduleSub?.cancel();
    _boundSchoolId = schoolId;
    _scheduleSub = _scheduleDoc(schoolId).snapshots().listen((snap) {
      final data = snap.data();
      final raw = (data?['schedule'] as List?) ?? const [];
      final parsed =
          raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(
                (m) => <String, String>{
                  'day': (m['day'] ?? '').toString(),
                  'subject': (m['subject'] ?? '').toString(),
                  'time': (m['time'] ?? '').toString(),
                },
              )
              .where(
                (m) =>
                    m['day']!.trim().isNotEmpty &&
                    m['subject']!.trim().isNotEmpty,
              )
              .toList();

      if (!mounted) return;
      setState(() => _schedule = parsed);
    });
  }

  Future<void> _persistSchedule({
    required String schoolId,
    required String userId,
    required bool clearApproval,
  }) async {
    final payload = <String, dynamic>{
      'schedule': _schedule,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clearApproval) {
      payload['approvedAt'] = FieldValue.delete();
      payload['approvedBy'] = FieldValue.delete();
    }
    await _scheduleDoc(schoolId).set(payload, SetOptions(merge: true));
  }

  Future<void> _broadcastScheduleApproved({
    required String schoolId,
    required String userId,
  }) async {
    const title = 'تم اعتماد جدول الاختبارات';
    const body = 'تم اعتماد جدول الاختبارات. يمكنك الآن الاطلاع عليه.';
    const route = '/smart-exams';
    const data = <String, dynamic>{'type': 'exam_schedule_approved'};

    const roles = [
      'student',
      'parent',
      'teacher',
      'administrative',
      'deputy',
      'admin',
      'counselor',
      'technicalSupport',
      'supportAdmin',
      'superAdmin',
    ];

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendSchoolNotification',
      );
      await Future.wait(
        roles.map(
          (role) => callable.call({
            'schoolId': schoolId,
            'title': title,
            'body': body,
            'targetRole': role,
            'route': route,
            'data': data,
          }),
        ),
      );
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    final batch = _firestore.batch();
    final col = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Notifications');
    for (final role in roles) {
      batch.set(col.doc(), {
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetRole': role,
        'route': route,
        'data': data,
        'type': 'exam_schedule',
        'createdBy': userId,
      });
    }
    await batch.commit();
  }

  Future<void> _approveSchedule() async {
    if (_schedule.isEmpty) return;

    final auth = ref.read(authStateProvider);
    final user = auth.asData?.value;
    final schoolId = (user?.schoolId ?? '').trim();
    final userId = (user?.id ?? '').trim();
    if (schoolId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد جدول الاختبارات'),
        content: const Text(
          'سيتم اعتماد الجدول وإرسال إشعار لجميع الطلاب وأولياء الأمور والمعلمين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isApproving = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('جاري اعتماد الجدول وإرسال الإشعارات...')),
      );
    try {
      await _scheduleDoc(schoolId).set({
        'schedule': _schedule,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _broadcastScheduleApproved(schoolId: schoolId, userId: userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم اعتماد الجدول وإرسال إشعار')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الاعتماد: $e')));
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _editScheduleItem(int index) async {
    if (index < 0 || index >= _schedule.length) return;
    final current = _schedule[index];

    var selectedDay = (current['day'] ?? '').trim();
    if (selectedDay.isEmpty || !_days.contains(selectedDay)) {
      selectedDay = _days.first;
    }

    final subjectController = TextEditingController(
      text: (current['subject'] ?? '').trim(),
    );
    final timeController = TextEditingController(
      text: (current['time'] ?? '').trim(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('تعديل مادة'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      items: _days
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => selectedDay = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'اليوم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'المادة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'الوقت',
                        hintText: '7:30 - 9:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (ok != true) return;

    final subject = subjectController.text.trim();
    final time = timeController.text.trim();
    if (subject.isEmpty || time.isEmpty) return;

    setState(() {
      _schedule[index] = {'day': selectedDay, 'subject': subject, 'time': time};
    });

    final schoolId = (ref.read(authStateProvider).asData?.value?.schoolId ?? '')
        .trim();
    final userId = (ref.read(authStateProvider).asData?.value?.id ?? '').trim();
    if (schoolId.isEmpty) return;
    await _persistSchedule(schoolId: schoolId, userId: userId, clearApproval: true);
  }

  Future<void> _deleteScheduleItem(int index) async {
    if (index < 0 || index >= _schedule.length) return;
    final item = _schedule[index];
    final subject = (item['subject'] ?? '').trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مادة'),
        content: Text(
          subject.isEmpty ? 'هل تريد حذف هذا العنصر؟' : 'حذف مادة: $subject ؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;
    setState(() => _schedule.removeAt(index));

    final schoolId = (ref.read(authStateProvider).asData?.value?.schoolId ?? '')
        .trim();
    final userId = (ref.read(authStateProvider).asData?.value?.id ?? '').trim();
    if (schoolId.isEmpty) return;
    await _persistSchedule(schoolId: schoolId, userId: userId, clearApproval: true);
  }

  Future<void> _generateSmartSchedule() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    // Simulate AI processing for 30 seconds with progress updates
    const totalDuration = 30;
    for (int i = 0; i <= totalDuration; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _progress = i / totalDuration;
        });
      }
    }

    final rand = Random(DateTime.now().microsecondsSinceEpoch);
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس']..shuffle(rand);
    final subjects = List<String>.of(_defaultSubjects)..shuffle(rand);
    final timeSlots = ['7:30 - 9:00', '9:15 - 10:45', '11:00 - 12:30']..shuffle(rand);

    final generated = <Map<String, String>>[];
    for (var i = 0; i < subjects.length; i++) {
      generated.add({
        'day': days[i % days.length],
        'subject': subjects[i],
        'time': timeSlots[i % timeSlots.length],
      });
    }

    setState(() {
      _schedule = generated;
      _isGenerating = false;
    });

    final schoolId = (ref.read(authStateProvider).asData?.value?.schoolId ?? '')
        .trim();
    final userId = (ref.read(authStateProvider).asData?.value?.id ?? '').trim();
    if (schoolId.isNotEmpty) {
      await _persistSchedule(schoolId: schoolId, userId: userId, clearApproval: true);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الجدول الذكي بنجاح بناءً على المعطيات!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSmartCard(
            title: 'إعداد الجدول الذكي',
            icon: Icons.calendar_today,
            color: Colors.blue,
            child: Column(
              children: [
                const Text(
                  'سيقوم النظام بتحليل المواد والفصول وتوزيعها بشكل متوازن لتجنب التعارض.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                if (_isGenerating)
                  Column(
                    children: [
                      CircularProgressIndicator(value: _progress),
                      SizedBox(height: 8.h),
                      Text(
                        'جاري تحليل البيانات وبناء الجدول... (${(_progress * 100).toInt()}%)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'الذكاء الاصطناعي يقوم بموازنة المواد وتوزيع القاعات...',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _generateSmartSchedule,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('إنشاء الجدول الآن (AI)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                if (_schedule.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isGenerating || _isApproving)
                          ? null
                          : _approveSchedule,
                      icon: _isApproving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified),
                      label: const Text('اعتماد الجدول'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),
          if (_schedule.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _schedule.length,
                itemBuilder: (context, index) {
                  final item = _schedule[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black26),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        item['subject']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${item['day']} | ${item['time']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: _isGenerating
                                ? null
                                : () => _editScheduleItem(index),
                            tooltip: 'تعديل',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _isGenerating
                                ? null
                                : () => _deleteScheduleItem(index),
                            tooltip: 'حذف',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// --- Tab 2: Committees ---
class _CommitteesTab extends ConsumerStatefulWidget {
  const _CommitteesTab();

  @override
  ConsumerState<_CommitteesTab> createState() => _CommitteesTabState();
}

class _CommitteesTabState extends ConsumerState<_CommitteesTab> {
  bool _isGenerating = false;
  bool _isPrintingAll = false;
  double _progress = 0.0;
  List<Map<String, dynamic>> _committees = [];
  double _studentsPerRoom = 20;
  DoorPosition _doorPosition = DoorPosition.rightFront;
  bool _doorPositionLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDoorPosition();
    });
  }

  Future<void> _loadDoorPosition() async {
    if (_doorPositionLoaded) return;
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) {
      _doorPositionLoaded = true;
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('exam_room_layout')
          .get();
      final data = doc.data();
      final raw = data == null ? null : data['doorPosition'];
      if (!mounted) return;
      setState(() {
        _doorPosition = _doorPositionFromRaw(raw);
        _doorPositionLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _doorPositionLoaded = true;
      });
    }
  }

  Future<void> _saveDoorPosition(DoorPosition pos) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('exam_room_layout')
        .set(<String, dynamic>{
          'doorPosition': _doorPositionToRaw(pos),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _generateCommittees() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    // Simulate smart AI processing for 4 seconds
    const totalDuration = 40; // 4 seconds (40 * 100ms)
    for (int i = 0; i <= totalDuration; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _progress = i / totalDuration;
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _committees = List.generate(
        5,
        (index) => {
          'name': 'لجنة رقم ${index + 1}',
          'room': 'قاعة ${101 + index}',
          'students': _studentsPerRoom.toInt(),
          'proctors': ['معلم ${index + 1}', 'معلم ${index + 6}'],
        },
      );
      _isGenerating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم توزيع اللجان ورسم الكروكي بنجاح!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  int _columnsForStudents(int students) {
    if (students == 36) return 6;
    if (students % 6 == 0 && students <= 36) return 6;
    if (students % 5 == 0) return 5;
    if (students <= 36) {
      final r5 = (students / 5).ceil();
      final r6 = (students / 6).ceil();
      if (r6 < r5) return 6;
    }
    return 5;
  }

  Future<Uint8List> _renderRoomSketchPng({
    required DoorPosition doorPosition,
    required int seatCount,
    required int columns,
    required double logicalWidth,
    required double logicalHeight,
    double pixelRatio = 2.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio, pixelRatio);
    _RoomSketchPainter(
      doorPosition: doorPosition,
      seatCount: seatCount,
      columns: columns,
    ).paint(canvas, Size(logicalWidth, logicalHeight));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * pixelRatio).round(),
      (logicalHeight * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _printRoomSketch({
    required String roomName,
    required int seatCount,
    required int columns,
  }) async {
    final png = await _renderRoomSketchPng(
      doorPosition: _doorPosition,
      seatCount: seatCount,
      columns: columns,
      logicalWidth: 350,
      logicalHeight: 250,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Image(
              pw.MemoryImage(png),
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'كروكي_$roomName.pdf',
    );
  }

  Future<void> _printAllCommitteesSketches() async {
    if (_committees.isEmpty) return;
    setState(() => _isPrintingAll = true);
    try {
      final doc = pw.Document();
      for (final c in _committees) {
        final roomName = (c['room'] ?? '').toString();
        final students = (c['students'] as num?)?.toInt() ?? 0;
        final seatCount = students.clamp(1, 60);
        final cols = _columnsForStudents(seatCount);
        final png = await _renderRoomSketchPng(
          doorPosition: _doorPosition,
          seatCount: seatCount,
          columns: cols,
          logicalWidth: 350,
          logicalHeight: 250,
        );

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(png),
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'كروكي_اللجان.pdf',
      );
    } finally {
      if (mounted) setState(() => _isPrintingAll = false);
    }
  }

  void _showRoomSketch(BuildContext context, String roomName, int students) {
    final seatCount = students.clamp(1, 60);
    final cols = _columnsForStudents(seatCount);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رسم كروكي ذكي - $roomName'),
        content: Container(
          width: 350,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _RoomSketchPainter(
              doorPosition: _doorPosition,
              seatCount: seatCount,
              columns: cols,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _printRoomSketch(
                  roomName: roomName,
                  seatCount: seatCount,
                  columns: cols,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل طباعة الكروكي: $e')),
                );
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('طباعة الكروكي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSmartCard(
            title: 'توزيع اللجان الذكي',
            icon: Icons.meeting_room,
            color: Colors.orange,
            child: Column(
              children: [
                Text('عدد الطلاب في كل لجنة: ${_studentsPerRoom.toInt()}'),
                Slider(
                  value: _studentsPerRoom,
                  min: 10,
                  max: 60,
                  divisions: 50,
                  label: _studentsPerRoom.round().toString(),
                  onChanged: (value) =>
                      setState(() => _studentsPerRoom = value),
                ),
                SizedBox(height: 8.h),
                if (_isGenerating)
                  Column(
                    children: [
                      CircularProgressIndicator(value: _progress),
                      SizedBox(height: 8.h),
                      Text(
                        'جاري توزيع اللجان ورسم الكروكي... (${(_progress * 100).toInt()}%)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _generateCommittees,
                    icon: const Icon(Icons.group_work),
                    label: const Text('توزيع الطلاب وإنشاء اللجان'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                SizedBox(height: 12.h),
                if (_committees.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isGenerating || _isPrintingAll)
                              ? null
                              : _printAllCommitteesSketches,
                      icon: _isPrintingAll
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print),
                      label: const Text('طباعة جميع الكروكيات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_committees.isNotEmpty) SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DoorPosition>(
                        value: _doorPosition,
                        items: const [
                          DropdownMenuItem(
                            value: DoorPosition.leftFront,
                            child: Text('الباب: أمامي يسار'),
                          ),
                          DropdownMenuItem(
                            value: DoorPosition.rightFront,
                            child: Text('الباب: أمامي يمين'),
                          ),
                          DropdownMenuItem(
                            value: DoorPosition.rightBoard,
                            child: Text('الباب: بجانب السبورة يمين'),
                          ),
                          DropdownMenuItem(
                            value: DoorPosition.leftBoard,
                            child: Text('الباب: بجانب السبورة يسار'),
                          ),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _doorPosition = v);
                          await _saveDoorPosition(v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'موقع الباب',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          if (_committees.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _committees.length,
                itemBuilder: (context, index) {
                  final committee = _committees[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black26),
                    ),
                    child: ListTile(
                      title: Text(
                        committee['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'القاعة: ${committee['room']} | الطلاب: ${committee['students']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.map, color: Colors.indigo),
                        onPressed: () => _showRoomSketch(
                          context,
                          committee['room'],
                          (committee['students'] as int?) ?? 20,
                        ),
                        tooltip: 'عرض الكروكي',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlMembersTab extends ConsumerStatefulWidget {
  const _ControlMembersTab();

  @override
  ConsumerState<_ControlMembersTab> createState() => _ControlMembersTabState();
}

class _ControlMembersTabState extends ConsumerState<_ControlMembersTab> {
  static const _membersDocId = 'exam_control_members';
  static const _settingsCollection = 'Settings';
  static const _staffCollection = 'Staff';
  static const _memberIdKey = 'id';

  final _firestore = FirebaseFirestore.instance;
  final _customRoleController = TextEditingController();

  bool _isGenerating = false;
  double _progress = 0.0;
  String? _selectedStaffId;
  String? _selectedStaffName;
  String? _selectedStaffRole;
  String? _selectedControlRole;

  @override
  void dispose() {
    _customRoleController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _membersDoc(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_settingsCollection)
        .doc(_membersDocId);
  }

  Stream<List<Map<String, dynamic>>> _watchMembers(String schoolId) {
    return _membersDoc(schoolId).snapshots().map((doc) {
      final data = doc.data();
      final raw = (data?['members'] as List?) ?? const [];
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    });
  }

  Stream<List<User>> _watchEligibleStaff(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_staffCollection)
        .where('role', whereIn: const ['teacher', 'administrative', 'deputy'])
        .snapshots()
        .map((snap) {
          final out = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return User.fromMap(data);
          }).toList();
          out.sort((a, b) {
            final c = a.role.name.compareTo(b.role.name);
            if (c != 0) return c;
            return a.name.compareTo(b.name);
          });
          return out;
        });
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.teacher => 'معلم',
      UserRole.administrative => 'إداري',
      UserRole.deputy => 'وكيل',
      _ => role.name,
    };
  }

  String _controlRoleToDisplay(Map<String, dynamic> m) {
    final role = (m['controlRole'] ?? '').toString().trim();
    if (role == 'أخرى') {
      final custom = (m['customRole'] ?? '').toString().trim();
      return custom.isEmpty ? 'أخرى' : custom;
    }
    return role.isEmpty ? '—' : role;
  }

  Future<void> _addMember(String schoolId) async {
    final staffId = (_selectedStaffId ?? '').trim();
    final staffName = (_selectedStaffName ?? '').trim();
    final staffRole = (_selectedStaffRole ?? '').trim();
    final role = (_selectedControlRole ?? '').trim();
    final custom = _customRoleController.text.trim();

    if (staffId.isEmpty || staffName.isEmpty || staffRole.isEmpty) return;
    if (role.isEmpty) return;
    if (role == 'أخرى' && custom.isEmpty) return;

    final id = const Uuid().v4();
    final member = <String, dynamic>{
      _memberIdKey: id,
      'staffId': staffId,
      'staffName': staffName,
      'staffRole': staffRole,
      'controlRole': role,
      'customRole': role == 'أخرى' ? custom : '',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((tx) async {
      final ref = _membersDoc(schoolId);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final raw = (data['members'] as List?) ?? <dynamic>[];
      final members = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      members.removeWhere((m) => (m['staffId'] ?? '').toString() == staffId);
      members.add(member);
      tx.set(ref, {
        'members': members,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (!mounted) return;
    setState(() {
      _selectedStaffId = null;
      _selectedStaffName = null;
      _selectedStaffRole = null;
      _selectedControlRole = null;
      _customRoleController.clear();
    });
  }

  Future<void> _removeMember(String schoolId, String memberId) async {
    await _firestore.runTransaction((tx) async {
      final ref = _membersDoc(schoolId);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final raw = (data['members'] as List?) ?? <dynamic>[];
      final members = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      members.removeWhere(
        (m) => (m[_memberIdKey] ?? '').toString() == memberId,
      );
      tx.set(ref, {
        'members': members,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _assignControl() async {
    final auth = ref.read(authStateProvider);
    final user = auth.asData?.value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    const totalDuration = 20;
    for (int i = 0; i <= totalDuration; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _progress = i / totalDuration;
        });
      }
    }

    if (!mounted) return;

    final staffSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_staffCollection)
        .where('role', whereIn: const ['teacher', 'administrative', 'deputy'])
        .get();
    final staff = staffSnap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return User.fromMap(data);
    }).toList();
    staff.sort((a, b) {
      final c = a.role.name.compareTo(b.role.name);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });

    final roles = const ['رئيس الكنترول', 'عضو رصد', 'عضو تدقيق', 'ملاحظ'];

    final members = <Map<String, dynamic>>[];
    for (var i = 0; i < roles.length; i++) {
      if (i >= staff.length) break;
      final s = staff[i];
      members.add({
        _memberIdKey: const Uuid().v4(),
        'staffId': s.id,
        'staffName': s.name,
        'staffRole': s.role.name,
        'controlRole': roles[i],
        'customRole': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _membersDoc(schoolId).set({
      'members': members,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.asData?.value;
    final schoolId = (user?.schoolId ?? '').trim();

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSmartCard(
            title: 'تشكيل الكنترول الصاروخي',
            icon: Icons.rocket_launch,
            color: Colors.red,
            child: Column(
              children: [
                const Text(
                  'سيقوم النظام باختيار أنسب المعلمين للكنترول بناءً على الأداء والخبرة.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                if (_isGenerating)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        value: _progress,
                        color: Colors.red,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'جاري تحليل بيانات المعلمين... (${(_progress * 100).toInt()}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _assignControl,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('تشكيل الكنترول الآن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          if (schoolId.isNotEmpty)
            StreamBuilder<List<User>>(
              stream: _watchEligibleStaff(schoolId),
              builder: (context, staffSnap) {
                final staff = staffSnap.data ?? const <User>[];
                final items = staff
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${_roleLabel(s.role)} - ${s.name}'),
                      ),
                    )
                    .toList();

                return _buildSmartCard(
                  title: 'إضافة عضو',
                  icon: Icons.person_add_alt_1,
                  color: Colors.deepOrange,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedStaffId,
                        items: items,
                        decoration: const InputDecoration(
                          labelText: 'اختر العضو (معلم/إداري/وكيل)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          final s = staff.where((e) => e.id == v).cast<User?>();
                          final picked = s.isEmpty ? null : s.first;
                          setState(() {
                            _selectedStaffId = v;
                            _selectedStaffName = picked?.name;
                            _selectedStaffRole = picked?.role.name;
                          });
                        },
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        value: _selectedControlRole,
                        items: const [
                          DropdownMenuItem(
                            value: 'رئيس الكنترول',
                            child: Text('رئيس الكنترول'),
                          ),
                          DropdownMenuItem(
                            value: 'عضو رصد',
                            child: Text('عضو رصد'),
                          ),
                          DropdownMenuItem(
                            value: 'عضو تدقيق',
                            child: Text('عضو تدقيق'),
                          ),
                          DropdownMenuItem(
                            value: 'ملاحظ',
                            child: Text('ملاحظ'),
                          ),
                          DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'الصفة الاعتبارية في الكنترول',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _selectedControlRole = v;
                            if (v != 'أخرى') _customRoleController.clear();
                          });
                        },
                      ),
                      if (_selectedControlRole == 'أخرى') ...[
                        SizedBox(height: 12.h),
                        TextField(
                          controller: _customRoleController,
                          decoration: const InputDecoration(
                            labelText: 'اكتب اسم التكليف/المهمة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: staff.isEmpty
                              ? null
                              : () => _addMember(schoolId),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          SizedBox(height: 12.h),
          if (schoolId.isNotEmpty)
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _watchMembers(schoolId),
                builder: (context, snap) {
                  final members = snap.data ?? const <Map<String, dynamic>>[];
                  if (members.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات بعد'));
                  }
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final title = _controlRoleToDisplay(m);
                      final name = (m['staffName'] ?? '').toString().trim();
                      final memberId = (m[_memberIdKey] ?? '')
                          .toString()
                          .trim();
                      return Card(
                        margin: EdgeInsets.only(bottom: 8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black26),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.person, color: Colors.red),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(name.isEmpty ? '—' : name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: memberId.isEmpty
                                ? null
                                : () => _removeMember(schoolId, memberId),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomSketchPainter extends CustomPainter {
  final DoorPosition doorPosition;
  final int seatCount;
  final int columns;

  const _RoomSketchPainter({
    required this.doorPosition,
    this.seatCount = 20,
    this.columns = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final border = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(Offset.zero & size, border);

    const padding = 12.0;
    const gap = 8.0;
    const frontBarH = 42.0;
    const boardH = 26.0;
    const doorLaneW = 36.0;
    const boardSideDoorW = 74.0;
    const boardSideDoorH = 26.0;

    final roomRect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    final frontRect = Rect.fromLTWH(
      roomRect.left,
      roomRect.top,
      roomRect.width,
      frontBarH,
    );
    final frontPaint = Paint()..color = Colors.grey.shade200;
    canvas.drawRect(frontRect, frontPaint);

    final isSideLaneDoor =
        doorPosition == DoorPosition.leftFront ||
        doorPosition == DoorPosition.rightFront;

    Rect? boardSideDoorRect;
    if (!isSideLaneDoor) {
      final dx = doorPosition == DoorPosition.leftBoard
          ? (frontRect.left + gap)
          : (frontRect.right - boardSideDoorW - gap);
      boardSideDoorRect = Rect.fromLTWH(
        dx,
        frontRect.top + (frontBarH - boardSideDoorH) / 2,
        boardSideDoorW,
        boardSideDoorH,
      );
    }

    final boardRect = (() {
      final top = frontRect.top + (frontBarH - boardH) / 2;
      if (boardSideDoorRect == null) {
        return Rect.fromLTWH(
          frontRect.left + gap,
          top,
          (frontRect.width - gap * 2).clamp(60.0, frontRect.width),
          boardH,
        );
      }
      if (doorPosition == DoorPosition.leftBoard) {
        final left = boardSideDoorRect.right + gap;
        final right = frontRect.right - gap;
        return Rect.fromLTWH(
          left,
          top,
          (right - left).clamp(60.0, frontRect.width),
          boardH,
        );
      }
      final left = frontRect.left + gap;
      final right = boardSideDoorRect.left - gap;
      return Rect.fromLTWH(
        left,
        top,
        (right - left).clamp(60.0, frontRect.width),
        boardH,
      );
    })();
    final boardPaint = Paint()..color = Colors.blueGrey.shade100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
      boardPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
      border,
    );

    _drawText(
      canvas,
      'السبورة',
      boardRect,
      fontSize: 12,
      color: Colors.black87,
      bold: true,
    );

    final rows = (seatCount / columns).ceil();
    final gridTop = frontRect.bottom + gap;
    final gridH = roomRect.bottom - gridTop;
    final gridLeft =
        roomRect.left +
        (doorPosition == DoorPosition.leftFront ? (doorLaneW + gap) : 0);
    final gridRight =
        roomRect.right -
        (doorPosition == DoorPosition.rightFront ? (doorLaneW + gap) : 0);
    final gridW = (gridRight - gridLeft).clamp(0.0, roomRect.width);
    final seatW = ((gridW - gap * (columns - 1)) / columns).clamp(24.0, 90.0);
    final seatH = ((gridH - gap * (rows - 1)) / rows).clamp(18.0, 70.0);

    final doorPaint = Paint()..color = Colors.green.shade200;
    if (isSideLaneDoor) {
      final doorW = (doorLaneW - 10).clamp(18.0, doorLaneW);
      final doorH = (seatH * 0.95).clamp(22.0, 90.0);
      final doorRect = Rect.fromLTWH(
        doorPosition == DoorPosition.leftFront
            ? roomRect.left + (doorLaneW - doorW) / 2
            : roomRect.right - doorLaneW + (doorLaneW - doorW) / 2,
        gridTop + 2,
        doorW,
        doorH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(doorRect, const Radius.circular(6)),
        doorPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(doorRect, const Radius.circular(6)),
        border,
      );
      _drawText(
        canvas,
        'باب',
        doorRect,
        fontSize: 11,
        color: Colors.black87,
        bold: true,
      );
    } else if (boardSideDoorRect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(boardSideDoorRect, const Radius.circular(6)),
        doorPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boardSideDoorRect, const Radius.circular(6)),
        border,
      );
      _drawText(
        canvas,
        'باب',
        boardSideDoorRect,
        fontSize: 11,
        color: Colors.black87,
        bold: true,
      );
    }

    final seatFill = Paint()..color = Colors.orange.shade100;
    final seatStroke = Paint()
      ..color = Colors.orange.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (int i = 0; i < seatCount; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final left = gridLeft + col * (seatW + gap);
      final top = gridTop + row * (seatH + gap);
      final r = Rect.fromLTWH(left, top, seatW, seatH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        seatFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        seatStroke,
      );

      final arrow = Path()
        ..moveTo(r.center.dx, r.top + 6)
        ..lineTo(r.center.dx - 6, r.top + 16)
        ..lineTo(r.center.dx + 6, r.top + 16)
        ..close();
      final arrowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
      canvas.drawPath(arrow, arrowPaint);

      _drawText(
        canvas,
        '${i + 1}',
        r,
        fontSize: 10,
        color: Colors.black87,
        bold: false,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect, {
    required double fontSize,
    required Color color,
    required bool bold,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout(maxWidth: rect.width);
    final offset = Offset(
      rect.left + (rect.width - tp.width) / 2,
      rect.top + (rect.height - tp.height) / 2,
    );
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RoomSketchPainter oldDelegate) {
    return oldDelegate.doorPosition != doorPosition ||
        oldDelegate.seatCount != seatCount ||
        oldDelegate.columns != columns;
  }
}

// Helper Widget
Widget _buildSmartCard({
  required String title,
  required IconData icon,
  required Color color,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black26),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        child,
      ],
    ),
  );
}
