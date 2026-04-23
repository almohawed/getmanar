import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_schedule_run_repository.dart';
import '../domain/schedule_run.dart';
import '../domain/teacher_preference_entity.dart';

class TeacherSchedulePreferencesScreen extends ConsumerStatefulWidget {
  final String scheduleRunId;

  const TeacherSchedulePreferencesScreen({
    super.key,
    required this.scheduleRunId,
  });

  @override
  ConsumerState<TeacherSchedulePreferencesScreen> createState() =>
      _TeacherSchedulePreferencesScreenState();
}

class _TeacherSchedulePreferencesScreenState
    extends ConsumerState<TeacherSchedulePreferencesScreen> {
  final List<String> _days = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  static const int _periodsPerDay = 7;

  late List<List<bool>> _unavailable;
  bool _noSeventhPeriod = false;
  bool _preferConsecutive = false;
  bool _isSubmitting = false;
  bool _isRunLoading = true;
  bool _isLocked = false;
  ScheduleRun? _run;

  @override
  void initState() {
    super.initState();
    _unavailable = List.generate(
      _days.length,
      (_) => List<bool>.filled(_periodsPerDay, false),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      setState(() {
        _isRunLoading = false;
        _isLocked = true;
      });
      return;
    }

    final runRepo = ref.read(scheduleRunRepositoryProvider);
    final run = await runRepo.getScheduleRun(schoolId, widget.scheduleRunId);

    if (!mounted) return;

    bool locked = true;
    if (run != null) {
      final now = DateTime.now();
      final isExpired =
          run.collectUntil != null && now.isAfter(run.collectUntil!);
      locked = run.status != ScheduleStatus.collecting || isExpired;
    }

    setState(() {
      _run = run;
      _isLocked = locked;
      _isRunLoading = false;
    });

    if (!_isLocked) {
      await _loadExistingPreference();
    }
  }

  Future<void> _loadExistingPreference() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final teacherId = user?.id ?? '';
    if (schoolId.isEmpty || teacherId.isEmpty) {
      return;
    }

    final repo = ref.read(scheduleRunRepositoryProvider);
    final existing = await repo.getTeacherPreference(
      schoolId,
      widget.scheduleRunId,
      teacherId,
    );

    if (!mounted || existing == null) {
      return;
    }

    setState(() {
      _noSeventhPeriod = existing.noSeventhPeriod;
      _preferConsecutive = existing.preferConsecutive;
      for (final slot in existing.unavailableSlots) {
        final dayIndex = slot['dayIndex'];
        final period = slot['period'];
        if (dayIndex != null &&
            period != null &&
            dayIndex >= 0 &&
            dayIndex < _days.length &&
            period >= 1 &&
            period <= _periodsPerDay) {
          _unavailable[dayIndex][period - 1] = true;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_isLocked) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'انتهت المهلة المحددة لاستقبال الرغبات ولا يمكن الحفظ الآن',
            ),
          ),
        );
      }
      return;
    }
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final teacherId = user?.id ?? '';

    if (schoolId.isEmpty || teacherId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لم يتم العثور على بيانات المعلم أو المدرسة'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final List<Map<String, int>> unavailableSlots = [];
      for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) {
        for (var period = 1; period <= _periodsPerDay; period++) {
          if (_unavailable[dayIndex][period - 1]) {
            unavailableSlots.add({'dayIndex': dayIndex, 'period': period});
          }
        }
      }

      final preference = TeacherPreferenceEntity(
        teacherId: teacherId,
        scheduleRunId: widget.scheduleRunId,
        unavailableSlots: unavailableSlots,
        noSeventhPeriod: _noSeventhPeriod,
        preferConsecutive: _preferConsecutive,
        submitted: true,
        submittedAt: DateTime.now(),
      );

      final repo = ref.read(scheduleRunRepositoryProvider);
      await repo.saveTeacherPreference(schoolId, preference);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ تفضيلاتك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحديد أوقات التعذر')),
        body: _isRunLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLocked
                          ? 'انتهت المهلة المحددة لتعبئة الرغبات لهذه الجلسة. يمكن عرض البيانات السابقة فقط ولا يمكن تعديلها.'
                          : 'يرجى اختيار الأوقات التي يتعذر عليك فيها التدريس في هذا الأسبوع قبل انتهاء المهلة.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _days.length,
                        itemBuilder: (context, dayIndex) {
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _days[dayIndex],
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade900,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: List.generate(_periodsPerDay, (
                                      index,
                                    ) {
                                      final isBlocked =
                                          _unavailable[dayIndex][index];
                                      return FilterChip(
                                        label: Text('حصة ${index + 1}'),
                                        selected: isBlocked,
                                        onSelected: _isLocked
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  _unavailable[dayIndex][index] =
                                                      val;
                                                });
                                              },
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SwitchListTile(
                      value: _noSeventhPeriod,
                      onChanged: _isLocked
                          ? null
                          : (val) {
                              setState(() {
                                _noSeventhPeriod = val;
                              });
                            },
                      title: const Text('يفضل عدم الجدولة في الحصة السابعة'),
                    ),
                    SwitchListTile(
                      value: _preferConsecutive,
                      onChanged: _isLocked
                          ? null
                          : (val) {
                              setState(() {
                                _preferConsecutive = val;
                              });
                            },
                      title: const Text(
                        'أفضل تجميع الحصص المتتالية قدر الإمكان',
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _isLocked ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ وإرسال'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
