import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/school_repository.dart';
import '../data/student_attendance_repository.dart';
import '../domain/student_attendance.dart';
import '../../auth/presentation/auth_controller.dart';

class StudentAttendanceSheet extends ConsumerStatefulWidget {
  final String classId;
  final List<User> students;

  const StudentAttendanceSheet({
    super.key,
    required this.classId,
    required this.students,
  });

  @override
  ConsumerState<StudentAttendanceSheet> createState() =>
      _StudentAttendanceSheetState();
}

class _StudentAttendanceSheetState
    extends ConsumerState<StudentAttendanceSheet> {
  final Map<String, StudentAttendanceStatus> _statusMap = {};
  bool _isLoading = false;
  String? _schoolStartTime;
  int _selectedPeriod = 1;
  List<StudentAttendance> _dailyAttendance = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).value;
    if (user?.schoolId != null) {
      final school = await ref
          .read(schoolRepositoryProvider)
          .getSchool(user!.schoolId!);
      if (school != null) {
        _schoolStartTime = school.startTime;
      }
    }

    final repo = ref.read(studentAttendanceRepositoryProvider);
    _dailyAttendance = await repo.getStudentAttendance(
      widget.classId,
      DateTime.now(),
    );

    _updateStatusMap();
    setState(() => _isLoading = false);
  }

  void _updateStatusMap() {
    final user = ref.read(authStateProvider).value;
    for (final student in widget.students) {
      final record = _dailyAttendance.firstWhere(
        (r) => r.studentId == student.id && r.period == _selectedPeriod,
        orElse: () => StudentAttendance(
          id: '',
          schoolId: user?.schoolId ?? '',
          studentId: student.id,
          studentName: student.name,
          classId: widget.classId,
          date: DateTime.now(),
          status: StudentAttendanceStatus.present, // Placeholder
          recordedBy: '',
          period: _selectedPeriod,
        ),
      );
      
      if (record.id.isNotEmpty) {
        _statusMap[student.id] = record.status;
      } else {
        _statusMap[student.id] = _calculateDefaultStatus();
      }
    }
  }

  StudentAttendanceStatus _calculateDefaultStatus() {
    if (_schoolStartTime != null && _selectedPeriod == 1) {
      // Only check late status for first period based on start time
      final now = TimeOfDay.now();
      final parts = _schoolStartTime!.split(':');
      if (parts.length == 2) {
        final startHour = int.parse(parts[0]);
        final startMinute = int.parse(parts[1]);

        final startMinutes = startHour * 60 + startMinute;
        final nowMinutes = now.hour * 60 + now.minute;

        if (nowMinutes > startMinutes) {
          return StudentAttendanceStatus.late;
        }
      }
    }
    return StudentAttendanceStatus.present;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(studentAttendanceRepositoryProvider);
    final now = DateTime.now();

    final List<StudentAttendance> list = [];
    for (final student in widget.students) {
      final status = _statusMap[student.id] ?? StudentAttendanceStatus.present;
      
      // Check if record exists to update it or create new
      final existingIndex = _dailyAttendance.indexWhere(
        (r) => r.studentId == student.id && r.period == _selectedPeriod
      );
      
      final id = existingIndex != -1 
          ? _dailyAttendance[existingIndex].id 
          : const Uuid().v4();

      list.add(
        StudentAttendance(
          id: id,
          schoolId: user?.schoolId ?? '',
          studentId: student.id,
          studentName: student.name,
          classId: widget.classId,
          date: now,
          status: status,
          arrivalTime: now,
          recordedBy: user?.id ?? 'unknown',
          period: _selectedPeriod,
        ),
      );
    }

    await repo.saveStudentAttendance(list);
    
    // Refresh local data
    _dailyAttendance = await repo.getStudentAttendance(
      widget.classId,
      DateTime.now(),
    );
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التحضير')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      padding: EdgeInsets.all(16.w),
      height: 0.8.sh,
      child: Column(
        children: [
          Text(
            'تحضير الطلاب',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          
          // Period Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('الحصة:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 16.w),
              DropdownButton<int>(
                value: _selectedPeriod,
                items: List.generate(8, (index) => index + 1)
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('$p'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPeriod = val;
                      _updateStatusMap();
                    });
                  }
                },
              ),
            ],
          ),
          
          if (_schoolStartTime != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'وقت الدوام: $_schoolStartTime',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.students.length,
              itemBuilder: (context, index) {
                final student = widget.students[index];
                final status =
                    _statusMap[student.id] ?? StudentAttendanceStatus.present;
                return ListTile(
                  title: Text(student.name),
                  trailing: DropdownButton<StudentAttendanceStatus>(
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: StudentAttendanceStatus.present,
                        child: Text(
                          'حاضر',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      DropdownMenuItem(
                        value: StudentAttendanceStatus.late,
                        child: Text(
                          'متأخر',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      DropdownMenuItem(
                        value: StudentAttendanceStatus.absent,
                        child: Text(
                          'غائب',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      DropdownMenuItem(
                        value: StudentAttendanceStatus.excused,
                        child: Text(
                          'معذور',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _statusMap[student.id] = val);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50.h),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
