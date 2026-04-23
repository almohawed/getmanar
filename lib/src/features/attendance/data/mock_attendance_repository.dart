import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/teacher_attendance.dart';
import 'attendance_repository.dart';

class MockAttendanceRepository implements AttendanceRepository {
  // In-memory list
  final List<TeacherAttendance> _attendance = [];
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _attendance.clear();
        _attendance.addAll(
          jsonList.map((e) => TeacherAttendance.fromMap(e)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error initializing attendance: $e');
    }
    _isInitialized = true;
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance.json');
      final jsonList = _attendance.map((a) => a.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }
  }

  Future<void> _syncToFirebase(List<TeacherAttendance> records) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final record in records) {
          final docRef = FirebaseFirestore.instance
              .collection('attendance')
              .doc(record.id);
          batch.set(docRef, record.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Attendance): $e');
    }
  }

  @override
  Future<List<TeacherAttendance>> getAttendance(String day, int period) async {
    await _init();
    return _attendance
        .where((a) => a.day == day && a.period == period)
        .toList();
  }

  @override
  Future<void> saveAttendance(List<TeacherAttendance> attendanceList) async {
    await _init();
    if (attendanceList.isNotEmpty) {
      final day = attendanceList.first.day;
      final period = attendanceList.first.period;
      // Remove existing for this slot
      _attendance.removeWhere((a) => a.day == day && a.period == period);
      // Add new
      _attendance.addAll(attendanceList);

      // Persist
      await _saveToDisk();

      // Sync (Fire and forget)
      _syncToFirebase(attendanceList);
    }
  }
}
