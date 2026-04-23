import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/mock_wait_repository.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class WaitManagementScreen extends ConsumerStatefulWidget {
  const WaitManagementScreen({super.key});

  @override
  ConsumerState<WaitManagementScreen> createState() =>
      _WaitManagementScreenState();
}

class _WaitManagementScreenState extends ConsumerState<WaitManagementScreen> {
  int _absentTeachersCount = 1;
  final List<String?> _selectedAbsentTeacherIds = [null];
  List<Map<String, dynamic>>? _generatedSchedule;
  bool _isGenerating = false;
  String _selectedDay = 'الأحد';
  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  // Teachers list will be loaded from mock data
  List<Map<String, String>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final teachers = await ref
        .read(mockTeacherRepositoryProvider)
        .getTeachers();
    if (mounted) {
      setState(() {
        _teachers = teachers.map((t) => {'id': t.id, 'name': t.name}).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockWaitRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('إدارة الانتظار')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Settings (Count & Day)
            Text(
              'إعدادات الانتظار',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                // Count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عدد المعلمين',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          value: _absentTeachersCount,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: List.generate(10, (index) => index + 1).map((
                            count,
                          ) {
                            return DropdownMenuItem(
                              value: count,
                              child: Text('$count معلمين'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _absentTeachersCount = value;
                                // Adjust list size
                                if (_selectedAbsentTeacherIds.length < value) {
                                  _selectedAbsentTeacherIds.addAll(
                                    List.filled(
                                      value - _selectedAbsentTeacherIds.length,
                                      null,
                                    ),
                                  );
                                } else {
                                  _selectedAbsentTeacherIds.length = value;
                                }
                                _generatedSchedule = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                // Day
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اليوم',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedDay,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _days.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedDay = value;
                                _generatedSchedule = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // 2. Select Absent Teachers
            Text(
              'تحديد المعلمين المتغيبين',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            ...List.generate(_absentTeachersCount, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: DropdownButtonFormField<String>(
                  value: _selectedAbsentTeacherIds[index],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_off),
                    labelText: 'المعلم الغائب ${index + 1}',
                  ),
                  items: _teachers.map((t) {
                    return DropdownMenuItem(
                      value: t['id'],
                      child: Text(t['name']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAbsentTeacherIds[index] = value;
                      _generatedSchedule = null;
                    });
                  },
                ),
              );
            }),
            SizedBox(height: 24.h),

            // 3. Generate Button
            ElevatedButton.icon(
              onPressed:
                  _selectedAbsentTeacherIds.contains(null) || _isGenerating
                  ? null
                  : () async {
                      setState(() => _isGenerating = true);
                      try {
                        final allSchedules = <Map<String, dynamic>>[];
                        for (var teacherId in _selectedAbsentTeacherIds) {
                          if (teacherId != null) {
                            final user = ref.read(authStateProvider).value;
                            final schoolId = user?.schoolId ?? '';
                            if (schoolId.isEmpty) continue;

                            final schedule = await repo.generateWaitSchedule(
                              schoolId,
                              teacherId,
                              _selectedDay,
                            );
                            allSchedules.addAll(schedule);
                          }
                        }
                        setState(() {
                          _generatedSchedule = allSchedules;
                        });
                      } finally {
                        setState(() => _isGenerating = false);
                      }
                    },
              icon: _isGenerating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('إضافة الغياب وإنشاء جدول الانتظار'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 32.h),

            // 3. Results
            if (_generatedSchedule != null) ...[
              Text(
                'الجدول المقترح',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 8.h),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _generatedSchedule!.length,
                itemBuilder: (context, index) {
                  final item = _generatedSchedule![index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text('${item['period']}'),
                      ),
                      title: Text(
                        'الحصة ${item['period']} - فصل ${item['class']}',
                      ),
                      subtitle: Text(
                        'المعلم البديل: ${item['assignedTeacherName']} (${item['type']} - نصاب: ${item['nisab']})',
                      ),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () async {
                  final user = ref.read(authStateProvider).value;
                  final schoolId = user?.schoolId ?? '';
                  if (schoolId.isEmpty) return;

                  await repo.confirmSchedule(
                    schoolId,
                    _generatedSchedule!,
                    _selectedDay,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم اعتماد جدول الانتظار وإرسال التنبيهات للمعلمين',
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                ),
                child: const Text('اعتماد الجدول'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
