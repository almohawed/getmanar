import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../auth/presentation/auth_controller.dart';

class ExamSeatingScreen extends ConsumerStatefulWidget {
  const ExamSeatingScreen({super.key});

  @override
  ConsumerState<ExamSeatingScreen> createState() => _ExamSeatingScreenState();
}

class _ExamSeatingScreenState extends ConsumerState<ExamSeatingScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _sessionId = '';
  bool _loading = false;
  String _error = '';
  pw.Font? _arabicFont;

  int _classroomCapacity = 35;
  int _labCapacity = 55;
  bool _preserveHomeClassroom = true;
  bool _mixOverflowStudents = true;
  bool _useLabsBeforeOverflow = true;
  bool _overflowEnabled = true;
  bool _distributeOnlyExcessStudents = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadOrCreateSession();
      await _loadPolicy();
    });
  }

  String get _schoolId {
    final user = ref.read(authStateProvider).value;
    return (user?.schoolId ?? '').trim();
  }

  Future<void> _loadOrCreateSession() async {
    final schoolId = _schoolId;
    if (schoolId.isEmpty) return;
    try {
      final settingsRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('exam_seating');
      final doc = await settingsRef.get();
      final existing = (doc.data()?['activeSessionId'] ?? '').toString().trim();
      if (existing.isNotEmpty) {
        setState(() => _sessionId = existing);
        return;
      }
      final newId = const Uuid().v4().replaceAll('-', '');
      await _firestore.collection('examSessions').doc(newId).set({
        'id': newId,
        'schoolId': schoolId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await settingsRef.set({
        'activeSessionId': newId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() => _sessionId = newId);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadPolicy() async {
    final schoolId = _schoolId;
    if (schoolId.isEmpty) return;
    final ref = _firestore.collection('examSeatingPolicy').doc(schoolId);
    final doc = await ref.get();
    final data = doc.data() ?? const <String, dynamic>{};
    setState(() {
      _classroomCapacity = (data['classroomCapacity'] as num?)?.toInt() ?? 35;
      _labCapacity = (data['labCapacity'] as num?)?.toInt() ?? 55;
      _preserveHomeClassroom = (data['preserveHomeClassroom'] as bool?) ?? true;
      _mixOverflowStudents = (data['mixOverflowStudents'] as bool?) ?? true;
      _useLabsBeforeOverflow = (data['useLabsBeforeOverflow'] as bool?) ?? true;
      _overflowEnabled = (data['overflowEnabled'] as bool?) ?? true;
      _distributeOnlyExcessStudents =
          (data['distributeOnlyExcessStudents'] as bool?) ?? true;
    });
  }

  Future<void> _savePolicy() async {
    final schoolId = _schoolId;
    if (schoolId.isEmpty) return;
    await _firestore.collection('examSeatingPolicy').doc(schoolId).set({
      'schoolId': schoolId,
      'preserveHomeClassroom': _preserveHomeClassroom,
      'classroomCapacity': _classroomCapacity,
      'labCapacity': _labCapacity,
      'overflowEnabled': _overflowEnabled,
      'mixOverflowStudents': _mixOverflowStudents,
      'useLabsBeforeOverflow': _useLabsBeforeOverflow,
      'distributeOnlyExcessStudents': _distributeOnlyExcessStudents,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureArabicFont() async {
    if (_arabicFont != null) return;
    try {
      _arabicFont = await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      _arabicFont = await PdfGoogleFonts.notoSansRegular();
    }
  }

  Future<void> _exportSeatNumbersPdf() async {
    if (_sessionId.isEmpty) return;
    final schoolId = _schoolId;
    if (schoolId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _ensureArabicFont();

      final seatSnap = await _firestore
          .collection('examSeatNumbers')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .get();

      final assignmentSnap = await _firestore
          .collection('examSeatAssignments')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .get();

      final roomNameByStudentId = <String, String>{};
      for (final d in assignmentSnap.docs) {
        final a = d.data();
        final sid = (a['studentId'] ?? '').toString().trim();
        if (sid.isEmpty) continue;
        final rn = (a['roomName'] ?? a['committeeId'] ?? '').toString().trim();
        if (rn.isEmpty) continue;
        roomNameByStudentId[sid] = rn;
      }

      final rows = seatSnap.docs.map((d) => d.data()).toList();
      rows.sort((a, b) {
        final sa =
            (a['seatNumber'] as num?)?.toInt() ??
            int.tryParse('${a['seatNumber']}') ??
            0;
        final sb =
            (b['seatNumber'] as num?)?.toInt() ??
            int.tryParse('${b['seatNumber']}') ??
            0;
        if (sa != sb) return sa.compareTo(sb);
        return (a['studentName'] ?? '').toString().compareTo(
          (b['studentName'] ?? '').toString(),
        );
      });

      if (rows.isEmpty) {
        throw Exception('لا توجد أرقام جلوس لتصديرها');
      }

      final items = rows.map((r) {
        final sid = (r['studentId'] ?? '').toString().trim();
        final seat = (r['seatNumber'] ?? '').toString().trim();
        final fullName = (r['studentName'] ?? '').toString().trim();
        final cls = (r['className'] ?? r['classId'] ?? '').toString().trim();
        final committee =
            roomNameByStudentId[sid] ??
            (r['committeeId'] ?? '').toString().trim();
        final parts = _splitArabicName(fullName);
        return <String, String>{
          'firstName': parts.$1,
          'fatherName': parts.$2,
          'lastName': parts.$3,
          'className': cls,
          'committee': committee,
          'seatNumber': seat,
        };
      }).toList();

      final pdf = pw.Document();
      const perPage = 14;
      for (var i = 0; i < items.length; i += perPage) {
        final pageItems = items.skip(i).take(perPage).toList();
        while (pageItems.length < perPage) {
          pageItems.add(const <String, String>{});
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            margin: pw.EdgeInsets.only(
              left: 7 * PdfPageFormat.mm,
              right: 7 * PdfPageFormat.mm,
              top: 7 * PdfPageFormat.mm,
              bottom: 2 * PdfPageFormat.mm,
            ),
            theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicFont),
            build: (context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Padding(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: 0 * PdfPageFormat.mm,
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (int r = 0; r < 7; r++)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(
                            bottom: r == 6 ? 0 : 0.6 * PdfPageFormat.mm,
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: _seatCard(pageItems[r * 2 + 1]),
                              ),
                              pw.SizedBox(width: 3 * PdfPageFormat.mm),
                              pw.Expanded(child: _seatCard(pageItems[r * 2])),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'ارقام_الجلوس_${_sessionId}.pdf',
      );
    } catch (e) {
      setState(() => _error = 'فشل تصدير PDF: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  pw.Widget _seatCard(Map<String, String> data) {
    final firstName = (data['firstName'] ?? '').trim();
    final fatherName = (data['fatherName'] ?? '').trim();
    final lastName = (data['lastName'] ?? '').trim();
    final className = (data['className'] ?? '').trim();
    final committee = (data['committee'] ?? '').trim();
    final seatNumber = (data['seatNumber'] ?? '').trim();
    final fullName = [
      firstName,
      fatherName,
      lastName,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    final textStyle = pw.TextStyle(fontSize: 12, height: 1.0);

    pw.Widget line(String value) {
      return pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          value,
          style: textStyle,
          textAlign: pw.TextAlign.right,
          textDirection: pw.TextDirection.rtl,
        ),
      );
    }

    pw.Widget lineNoWrap(String value) {
      return pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          value,
          style: textStyle,
          textAlign: pw.TextAlign.right,
          textDirection: pw.TextDirection.rtl,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      );
    }

    pw.Widget committeeAndSeatRow() {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'اللجنة / $committee',
                style: textStyle,
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),
          pw.SizedBox(width: 1.2 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'رقم الجلوس / $seatNumber',
                style: textStyle,
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),
        ],
      );
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        height: 94,
        width: double.infinity,
        margin: pw.EdgeInsets.all(0.6 * PdfPageFormat.mm),
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
        ),
        child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.max,
            children: [
              lineNoWrap('اسم الطالب / $fullName'),
              pw.SizedBox(height: 2),
              line('الفصل / $className'),
              pw.SizedBox(height: 2),
              committeeAndSeatRow(),
            ],
          ),
        ),
      ),
    );
  }

  (String, String, String) _splitArabicName(String fullName) {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return ('', '', '');
    if (parts.length == 1) return (parts[0], '', '');
    if (parts.length == 2) return (parts[0], '', parts[1]);
    return (parts[0], parts[1], parts.last);
  }

  String _stageFromGrade(int gradeLevel) {
    if (gradeLevel >= 1 && gradeLevel <= 6) return 'primary';
    if (gradeLevel >= 7 && gradeLevel <= 9) return 'middle';
    if (gradeLevel >= 10 && gradeLevel <= 12) return 'secondary';
    return 'unknown';
  }

  int _stageYear(int gradeLevel) {
    final stage = _stageFromGrade(gradeLevel);
    if (stage == 'primary') return gradeLevel.clamp(1, 6);
    if (stage == 'middle') return (gradeLevel - 6).clamp(1, 3);
    if (stage == 'secondary') return (gradeLevel - 9).clamp(1, 3);
    return 1;
  }

  int _seatStart(int gradeLevel) => _stageYear(gradeLevel) * 1000 + 1;

  int _chooseColumns(int n) {
    if (n == 36) return 6;
    if (n <= 36 && n % 6 == 0) return 6;
    if (n % 5 == 0) return 5;
    if (n <= 36) {
      final r5 = (n / 5).ceil();
      final r6 = (n / 6).ceil();
      if (r6 < r5) return 6;
    }
    return 5;
  }

  Future<List<_StudentRec>> _loadStudents() async {
    final schoolId = _schoolId;
    final classesSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .get();
    final classById = <String, Map<String, dynamic>>{};
    final classNameToId = <String, String>{};
    final fallbackStudentIds = <String>{};
    for (final d in classesSnap.docs) {
      final data = d.data();
      final id = (data['id'] ?? d.id).toString().trim();
      if (id.isEmpty) continue;
      classById[id] = {...data, 'id': id};
      final name = (data['name'] ?? data['displayName'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        classNameToId[name] = id;
        classNameToId[name.replaceAll('  ', ' ')] = id;
      }
      final ids =
          (data['studentIds'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      for (final sid in ids) {
        final s = sid.trim();
        if (s.isNotEmpty) fallbackStudentIds.add(s);
      }
    }

    final studentsSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .get();

    final out = <_StudentRec>[];
    final seen = <String>{};

    if (studentsSnap.docs.isNotEmpty) {
      for (final d in studentsSnap.docs) {
        final data = d.data();
        final sid = d.id.toString().trim();
        if (sid.isEmpty) continue;

        String classId = '';
        final assigned =
            (data['assignedClassIds'] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];
        if (assigned.isNotEmpty) {
          classId = assigned.first;
        } else {
          classId = (data['classId'] ?? '').toString().trim();
        }

        if (classId.isEmpty) {
          final cn = (data['className'] ?? data['class'] ?? '')
              .toString()
              .trim();
          if (cn.isNotEmpty) {
            classId =
                classNameToId[cn] ??
                classNameToId[cn.replaceAll('  ', ' ')] ??
                '';
          }
        }

        if (classId.isEmpty) continue;
        if (seen.contains(sid)) continue;

        final c = classById[classId];
        final className =
            (c?['name'] ?? c?['displayName'] ?? data['className'] ?? classId)
                .toString();
        final grade =
            (c?['gradeLevel'] as num?)?.toInt() ??
            (data['gradeLevel'] as num?)?.toInt() ??
            int.tryParse('${data['gradeLevel']}') ??
            0;
        if (grade <= 0) continue;
        final name = (data['name'] ?? sid).toString();
        out.add(
          _StudentRec(
            studentId: sid,
            studentName: name,
            classId: classId,
            className: className,
            gradeLevel: grade,
          ),
        );
        seen.add(sid);
      }
    } else if (fallbackStudentIds.isNotEmpty) {
      final studentsById = <String, Map<String, dynamic>>{};
      final idsList = fallbackStudentIds.toList()..sort();
      for (var i = 0; i < idsList.length; i += 400) {
        final chunk = idsList.skip(i).take(400).toList();
        final futures = chunk.map((sid) async {
          final doc = await _firestore
              .collection('Schools')
              .doc(schoolId)
              .collection('Students')
              .doc(sid)
              .get();
          if (!doc.exists) return;
          studentsById[sid] = doc.data() ?? const <String, dynamic>{};
        }).toList();
        await Future.wait(futures);
      }

      for (final entry in classById.entries) {
        final c = entry.value;
        final cid = entry.key;
        final className = (c['name'] ?? c['displayName'] ?? cid).toString();
        final grade = (c['gradeLevel'] as num?)?.toInt() ?? 0;
        if (grade <= 0) continue;
        final ids =
            (c['studentIds'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
        for (final sid in ids) {
          if (sid.trim().isEmpty) continue;
          if (seen.contains(sid)) continue;
          final sdoc = studentsById[sid] ?? const <String, dynamic>{};
          final name = (sdoc['name'] ?? sid).toString();
          out.add(
            _StudentRec(
              studentId: sid,
              studentName: name,
              classId: cid,
              className: className,
              gradeLevel: grade,
            ),
          );
          seen.add(sid);
        }
      }
    }

    if (out.isEmpty) {
      throw Exception('no_students');
    }

    out.sort((a, b) {
      final c = a.gradeLevel.compareTo(b.gradeLevel);
      if (c != 0) return c;
      final c2 = a.className.compareTo(b.className);
      if (c2 != 0) return c2;
      final c3 = a.studentName.compareTo(b.studentName);
      if (c3 != 0) return c3;
      return a.studentId.compareTo(b.studentId);
    });
    return out;
  }

  Future<void> _generateSeatNumbers() async {
    if (_sessionId.isEmpty) return;
    final schoolId = _schoolId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _savePolicy();
      final students = await _loadStudents();
      final byGrade = <int, List<_StudentRec>>{};
      for (final s in students) {
        byGrade.putIfAbsent(s.gradeLevel, () => <_StudentRec>[]).add(s);
      }

      final batchChunks = <List<MapEntry<String, Map<String, dynamic>>>>[];
      final pending = <MapEntry<String, Map<String, dynamic>>>[];
      for (final entry
          in byGrade.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
        final grade = entry.key;
        final group = entry.value
          ..sort((a, b) => a.studentName.compareTo(b.studentName));
        var cur = _seatStart(grade);
        for (final s in group) {
          final docId = '${_sessionId}_${s.studentId}';
          pending.add(
            MapEntry(docId, {
              'id': docId,
              'schoolId': schoolId,
              'sessionId': _sessionId,
              'studentId': s.studentId,
              'studentName': s.studentName,
              'classId': s.classId,
              'className': s.className,
              'gradeLevel': s.gradeLevel,
              'stage': _stageFromGrade(s.gradeLevel),
              'seatNumber': cur,
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            }),
          );
          cur++;
          if (pending.length >= 450) {
            batchChunks.add(List.of(pending));
            pending.clear();
          }
        }
      }
      if (pending.isNotEmpty) batchChunks.add(List.of(pending));

      for (final chunk in batchChunks) {
        final batch = _firestore.batch();
        for (final e in chunk) {
          batch.set(
            _firestore.collection('examSeatNumbers').doc(e.key),
            e.value,
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }

      await _firestore.collection('examSessions').doc(_sessionId).set({
        'schoolId': schoolId,
        'seatNumbersGeneratedAt': FieldValue.serverTimestamp(),
        'seatNumbersCount': students.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد أرقام الجلوس: ${students.length}')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<_RoomRec>> _loadRooms(List<_ClassRec> classes) async {
    final schoolId = _schoolId;
    final snap = await _firestore
        .collection('examRoomLayouts')
        .where('schoolId', isEqualTo: schoolId)
        .get();
    final rooms = <_RoomRec>[];
    for (final d in snap.docs) {
      final data = d.data();
      final roomId = (data['roomId'] ?? d.id).toString().trim();
      final roomName = (data['roomName'] ?? roomId).toString();
      final roomType = (data['roomType'] ?? 'classroom').toString();
      final cap = (data['examCapacity'] as num?)?.toInt();
      final pr = (data['priority'] as num?)?.toInt() ?? 1000;
      final avail = (data['availableForExam'] as bool?) ?? true;
      if (roomId.isEmpty || !avail) continue;
      final fallbackCap = roomType == 'lab' ? _labCapacity : _classroomCapacity;
      rooms.add(
        _RoomRec(
          roomId: roomId,
          roomName: roomName,
          roomType: roomType,
          examCapacity: (cap == null || cap <= 0) ? fallbackCap : cap,
          priority: pr,
          availableForExam: avail,
        ),
      );
    }
    if (rooms.isNotEmpty) {
      rooms.sort((a, b) {
        final c = a.priority.compareTo(b.priority);
        if (c != 0) return c;
        final c2 = a.roomType.compareTo(b.roomType);
        if (c2 != 0) return c2;
        return a.roomName.compareTo(b.roomName);
      });
      return rooms;
    }
    final generated = classes
        .map(
          (c) => _RoomRec(
            roomId: c.classId,
            roomName: c.className,
            roomType: 'classroom',
            examCapacity: _classroomCapacity,
            priority: 100,
            availableForExam: true,
          ),
        )
        .toList();
    generated.sort((a, b) => a.roomName.compareTo(b.roomName));
    return generated;
  }

  Future<void> _generateCommittees() async {
    if (_sessionId.isEmpty) return;
    final schoolId = _schoolId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _savePolicy();
      final students = await _loadStudents();
      final byClass = <String, List<_StudentRec>>{};
      final classes = <_ClassRec>[];
      final classSeen = <String>{};
      for (final s in students) {
        byClass.putIfAbsent(s.classId, () => <_StudentRec>[]).add(s);
        if (!classSeen.contains(s.classId)) {
          classSeen.add(s.classId);
          classes.add(
            _ClassRec(
              classId: s.classId,
              className: s.className,
              gradeLevel: s.gradeLevel,
            ),
          );
        }
      }
      for (final e in byClass.entries) {
        e.value.sort((a, b) => a.studentName.compareTo(b.studentName));
      }
      classes.sort((a, b) {
        final c = a.gradeLevel.compareTo(b.gradeLevel);
        if (c != 0) return c;
        return a.className.compareTo(b.className);
      });
      final rooms = await _loadRooms(classes);
      final classroomRooms = rooms
          .where((r) => r.roomType == 'classroom')
          .toList();
      final labRooms = rooms.where((r) => r.roomType == 'lab').toList();
      final overflowRooms = rooms
          .where((r) => r.roomType == 'overflow')
          .toList();

      _RoomRec? roomForClass(_ClassRec c) {
        for (final r in classroomRooms) {
          if (r.roomId == c.classId) return r;
        }
        for (final r in classroomRooms) {
          if (r.roomName.contains(c.className)) return r;
        }
        return null;
      }

      final committees = <Map<String, dynamic>>[];
      final excess = <_StudentRec>[];

      Map<String, dynamic> makeCommittee(_RoomRec r, List<_StudentRec> list) {
        final id = const Uuid().v4().replaceAll('-', '');
        final home = list.map((e) => e.classId).toSet().toList()..sort();
        return {
          'id': id,
          'committeeId': id,
          'schoolId': schoolId,
          'sessionId': _sessionId,
          'roomId': r.roomId,
          'roomName': r.roomName,
          'roomType': r.roomType,
          'examCapacity': r.examCapacity,
          'priority': r.priority,
          'studentIds': list.map((e) => e.studentId).toList(),
          'homeClassIds': home,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      if (_preserveHomeClassroom) {
        for (final c in classes) {
          final group = byClass[c.classId] ?? const <_StudentRec>[];
          if (group.isEmpty) continue;
          final r =
              roomForClass(c) ??
              _RoomRec(
                roomId: c.classId,
                roomName: c.className,
                roomType: 'classroom',
                examCapacity: _classroomCapacity,
                priority: 100,
                availableForExam: true,
              );
          final cap = r.examCapacity > 0 ? r.examCapacity : _classroomCapacity;
          final keep = _distributeOnlyExcessStudents
              ? group.take(cap).toList()
              : group;
          final move = _distributeOnlyExcessStudents
              ? group.skip(cap).toList()
              : const <_StudentRec>[];
          if (keep.isNotEmpty) committees.add(makeCommittee(r, keep));
          excess.addAll(move);
        }
      } else {
        excess.addAll(students);
      }

      void allocRooms(List<_RoomRec> target, bool allowMix) {
        if (excess.isEmpty) return;
        if (allowMix) {
          var remaining = List<_StudentRec>.from(excess);
          excess.clear();
          for (final r in target) {
            if (remaining.isEmpty) break;
            final take = remaining.take(r.examCapacity).toList();
            remaining = remaining.skip(r.examCapacity).toList();
            committees.add(makeCommittee(r, take));
          }
          excess.addAll(remaining);
          return;
        }
        final byc = <String, List<_StudentRec>>{};
        for (final s in excess) {
          byc.putIfAbsent(s.classId, () => <_StudentRec>[]).add(s);
        }
        excess.clear();
        for (final entry in byc.entries) {
          var remaining = entry.value;
          for (final r in target) {
            if (remaining.isEmpty) break;
            final take = remaining.take(r.examCapacity).toList();
            remaining = remaining.skip(r.examCapacity).toList();
            committees.add(makeCommittee(r, take));
          }
          excess.addAll(remaining);
        }
      }

      if (excess.isNotEmpty) {
        if (_useLabsBeforeOverflow && labRooms.isNotEmpty) {
          allocRooms(labRooms, _mixOverflowStudents);
        }
        if (excess.isNotEmpty && _overflowEnabled) {
          final targets = overflowRooms.isNotEmpty
              ? overflowRooms
              : [
                  _RoomRec(
                    roomId: 'overflow_1',
                    roomName: 'قاعة إضافية',
                    roomType: 'overflow',
                    examCapacity: _classroomCapacity,
                    priority: 900,
                    availableForExam: true,
                  ),
                ];
          allocRooms(targets, _mixOverflowStudents);
        }
      }

      final existing = await _firestore
          .collection('examCommittees')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .get();
      for (var i = 0; i < existing.docs.length; i += 450) {
        final chunk = existing.docs.skip(i).take(450).toList();
        final batch = _firestore.batch();
        for (final d in chunk) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      for (var i = 0; i < committees.length; i += 450) {
        final chunk = committees.skip(i).take(450).toList();
        final batch = _firestore.batch();
        for (final c in chunk) {
          batch.set(_firestore.collection('examCommittees').doc(c['id']), c);
        }
        await batch.commit();
      }

      await _firestore.collection('examSessions').doc(_sessionId).set({
        'schoolId': schoolId,
        'committeesGeneratedAt': FieldValue.serverTimestamp(),
        'committeesCount': committees.length,
        'unassignedStudents': excess.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _assignSeats() async {
    if (_sessionId.isEmpty) return;
    final schoolId = _schoolId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final committeesSnap = await _firestore
          .collection('examCommittees')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .get();
      final committees = committeesSnap.docs.map((d) => d.data()).toList();
      committees.sort((a, b) {
        final pa = (a['priority'] as num?)?.toInt() ?? 1000;
        final pb = (b['priority'] as num?)?.toInt() ?? 1000;
        final c = pa.compareTo(pb);
        if (c != 0) return c;
        return (a['roomName'] ?? '').toString().compareTo(
          (b['roomName'] ?? '').toString(),
        );
      });

      final assignments = <Map<String, dynamic>>[];
      final seatUpdates = <MapEntry<String, Map<String, dynamic>>>[];
      for (final c in committees) {
        final studentIds =
            (c['studentIds'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const <String>[];
        if (studentIds.isEmpty) continue;
        final cols = _chooseColumns(studentIds.length);
        for (var i = 0; i < studentIds.length; i++) {
          final sid = studentIds[i];
          final seatIndex = i + 1;
          final rowIndex = i ~/ cols;
          final columnIndex = i % cols;
          final id = '${_sessionId}_$sid';
          assignments.add({
            'id': id,
            'schoolId': schoolId,
            'sessionId': _sessionId,
            'studentId': sid,
            'committeeId': (c['committeeId'] ?? c['id']).toString(),
            'roomId': (c['roomId'] ?? '').toString(),
            'roomName': (c['roomName'] ?? '').toString(),
            'roomType': (c['roomType'] ?? '').toString(),
            'seatIndex': seatIndex,
            'rowIndex': rowIndex,
            'columnIndex': columnIndex,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          seatUpdates.add(
            MapEntry(id, {
              'committeeId': (c['committeeId'] ?? c['id']).toString(),
              'seatIndex': seatIndex,
              'rowIndex': rowIndex,
              'columnIndex': columnIndex,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
          );
        }
      }

      final existing = await _firestore
          .collection('examSeatAssignments')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .get();
      for (var i = 0; i < existing.docs.length; i += 450) {
        final chunk = existing.docs.skip(i).take(450).toList();
        final batch = _firestore.batch();
        for (final d in chunk) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      for (var i = 0; i < assignments.length; i += 450) {
        final chunk = assignments.skip(i).take(450).toList();
        final batch = _firestore.batch();
        for (final a in chunk) {
          batch.set(
            _firestore.collection('examSeatAssignments').doc(a['id']),
            a,
          );
        }
        await batch.commit();
      }

      for (var i = 0; i < seatUpdates.length; i += 450) {
        final chunk = seatUpdates.skip(i).take(450).toList();
        final batch = _firestore.batch();
        for (final u in chunk) {
          batch.set(
            _firestore.collection('examSeatNumbers').doc(u.key),
            u.value,
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }

      await _firestore.collection('examSessions').doc(_sessionId).set({
        'schoolId': schoolId,
        'seatAssignmentsGeneratedAt': FieldValue.serverTimestamp(),
        'seatAssignmentsCount': assignments.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _regenerate() async {
    if (_sessionId.isEmpty) return;
    final schoolId = _schoolId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      for (final col in [
        'examSeatAssignments',
        'examSeatNumbers',
        'examCommittees',
      ]) {
        final snap = await _firestore
            .collection(col)
            .where('schoolId', isEqualTo: schoolId)
            .where('sessionId', isEqualTo: _sessionId)
            .get();
        for (var i = 0; i < snap.docs.length; i += 450) {
          final chunk = snap.docs.skip(i).take(450).toList();
          final batch = _firestore.batch();
          for (final d in chunk) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }
      await _generateSeatNumbers();
      await _generateCommittees();
      await _assignSeats();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = _schoolId;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الجلوس الاختباري')),
        body: schoolId.isEmpty
            ? const Center(child: Text('schoolId غير متوفر'))
            : SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      SizedBox(height: 12.h),
                    ],
                    if (_sessionId.isNotEmpty)
                      Text('Session: $_sessionId', textAlign: TextAlign.left),
                    if (_error.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    ],
                    SizedBox(height: 12.h),
                    _buildSessionSummary(),
                    SizedBox(height: 12.h),
                    _buildSettingsCard(),
                    SizedBox(height: 12.h),
                    _buildActions(),
                    SizedBox(height: 12.h),
                    _buildSeatNumbersPreview(),
                    SizedBox(height: 12.h),
                    _buildCommitteesList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _classroomCapacity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعة الفصل',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n == null) return;
                setState(() => _classroomCapacity = n.clamp(1, 1000));
              },
            ),
            SizedBox(height: 10.h),
            TextFormField(
              initialValue: _labCapacity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعة المعمل',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n == null) return;
                setState(() => _labCapacity = n.clamp(1, 1000));
              },
            ),
            SizedBox(height: 10.h),
            SwitchListTile(
              value: _preserveHomeClassroom,
              onChanged: (v) => setState(() => _preserveHomeClassroom = v),
              title: const Text('إبقاء كل فصل في فصله'),
            ),
            SwitchListTile(
              value: _distributeOnlyExcessStudents,
              onChanged: (v) =>
                  setState(() => _distributeOnlyExcessStudents = v),
              title: const Text('نقل الفائض فقط'),
            ),
            SwitchListTile(
              value: _useLabsBeforeOverflow,
              onChanged: (v) => setState(() => _useLabsBeforeOverflow = v),
              title: const Text('استخدم المعامل قبل القاعات الإضافية'),
            ),
            SwitchListTile(
              value: _overflowEnabled,
              onChanged: (v) => setState(() => _overflowEnabled = v),
              title: const Text('تمكين القاعات الإضافية'),
            ),
            SwitchListTile(
              value: _mixOverflowStudents,
              onChanged: (v) => setState(() => _mixOverflowStudents = v),
              title: const Text('خلط فائض عدة فصول'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        ElevatedButton(
          onPressed: _loading ? null : _generateSeatNumbers,
          child: const Text('توليد أرقام الجلوس'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _exportSeatNumbersPdf,
          child: const Text('PDF أرقام الجلوس'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _generateCommittees,
          child: const Text('توزيع اللجان'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _assignSeats,
          child: const Text('توزيع المقاعد'),
        ),
        OutlinedButton(
          onPressed: _loading ? null : _regenerate,
          child: const Text('إعادة التوليد'),
        ),
      ],
    );
  }

  Widget _buildSessionSummary() {
    if (_sessionId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('examSessions').doc(_sessionId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final seatNumbersCount =
            (data['seatNumbersCount'] as num?)?.toInt() ?? 0;
        final committeesCount = (data['committeesCount'] as num?)?.toInt() ?? 0;
        final assignmentsCount =
            (data['seatAssignmentsCount'] as num?)?.toInt() ?? 0;
        final unassigned = (data['unassignedStudents'] as num?)?.toInt() ?? 0;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'النتائج',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text('أرقام الجلوس: $seatNumbersCount'),
                Text('اللجان: $committeesCount'),
                Text('توزيع المقاعد: $assignmentsCount'),
                if (unassigned > 0) Text('غير موزعين: $unassigned'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeatNumbersPreview() {
    if (_sessionId.isEmpty) return const SizedBox.shrink();
    final schoolId = _schoolId;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('examSeatNumbers')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .limit(80)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final rows = docs.map((d) => d.data()).toList();
        rows.sort((a, b) {
          final sa =
              (a['seatNumber'] as num?)?.toInt() ??
              int.tryParse('${a['seatNumber']}') ??
              0;
          final sb =
              (b['seatNumber'] as num?)?.toInt() ??
              int.tryParse('${b['seatNumber']}') ??
              0;
          if (sa != sb) return sa.compareTo(sb);
          return (a['studentName'] ?? '').toString().compareTo(
            (b['studentName'] ?? '').toString(),
          );
        });
        final count = snapshot.data == null ? 0 : rows.length;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أرقام الجلوس (عرض ${count > 0 ? count : 0})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                if (rows.isEmpty)
                  const Text('لا توجد بيانات بعد')
                else
                  ...rows.take(30).map((r) {
                    final seat = (r['seatNumber'] ?? '').toString();
                    final name = (r['studentName'] ?? '').toString();
                    final cls = (r['className'] ?? r['classId'] ?? '')
                        .toString();
                    return ListTile(
                      dense: true,
                      title: Text('$seat - $name'),
                      subtitle: Text(cls),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommitteesList() {
    if (_sessionId.isEmpty) return const SizedBox.shrink();
    final schoolId = _schoolId;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('examCommittees')
          .where('schoolId', isEqualTo: schoolId)
          .where('sessionId', isEqualTo: _sessionId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final committees = docs.map((d) => d.data()).toList();
        committees.sort((a, b) {
          final pa = (a['priority'] as num?)?.toInt() ?? 1000;
          final pb = (b['priority'] as num?)?.toInt() ?? 1000;
          final c = pa.compareTo(pb);
          if (c != 0) return c;
          return (a['roomName'] ?? '').toString().compareTo(
            (b['roomName'] ?? '').toString(),
          );
        });
        return Card(
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اللجان: ${committees.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                ...committees.take(50).map((c) {
                  final students = (c['studentIds'] as List?)?.length ?? 0;
                  final room = (c['roomName'] ?? c['roomId'] ?? '').toString();
                  return ListTile(
                    title: Text(room),
                    subtitle: Text('الطلاب: $students'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudentRec {
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final int gradeLevel;

  const _StudentRec({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.gradeLevel,
  });
}

class _ClassRec {
  final String classId;
  final String className;
  final int gradeLevel;

  const _ClassRec({
    required this.classId,
    required this.className,
    required this.gradeLevel,
  });
}

class _RoomRec {
  final String roomId;
  final String roomName;
  final String roomType;
  final int examCapacity;
  final int priority;
  final bool availableForExam;

  const _RoomRec({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.examCapacity,
    required this.priority,
    required this.availableForExam,
  });
}
