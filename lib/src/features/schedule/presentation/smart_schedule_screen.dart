import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import 'excel_import_wizard.dart';
import '../services/pdf_export_service.dart';
import '../services/schedule_config.dart';
import '../services/ortools_schedule_service.dart';
import '../services/schedule_cache_manager.dart';

class SmartScheduleScreen extends ConsumerStatefulWidget {
  const SmartScheduleScreen({super.key});

  @override
  ConsumerState<SmartScheduleScreen> createState() => _SmartScheduleScreenState();
}

class _SmartScheduleScreenState extends ConsumerState<SmartScheduleScreen> {
  bool _isGenerating = false;
  String? _schoolId;
  String? _selectedClassId;
  Map<String, dynamic>? _generatedSchedule;
  String _viewMode = 'school'; // 'school', 'class', or 'assignments'
  List<Map<String, dynamic>> _schoolSchedules = [];
  bool _isImportingExcel = false;
  String? _importMessage;

  final _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  
  // For swap functionality
  Map<String, dynamic>? _selectedLesson;
  int? _selectedPeriod;
  String? _selectedDay;
  String? _selectedClassIdForSwap;
  bool _isSwapMode = false;

  @override
  void initState() {
    super.initState();
    _loadSchoolId();
  }

  Future<void> _loadSchoolId() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      setState(() => _schoolId = user.schoolId);
      _loadSchoolSchedules();
    }
  }

  Future<void> _loadSchoolSchedules() async {
    if (_schoolId == null) return;

    try {
      debugPrint('📚 Loading school schedules for: $_schoolId');
      
      // 🔥 قراءة جداول الفصول من المسار الصحيح
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(_schoolId)
          .collection('Classes')
          .get();

      debugPrint('📚 Found ${classesSnapshot.docs.length} classes');

      final schedules = <Map<String, dynamic>>[];

      for (final classDoc in classesSnapshot.docs) {
        final classId = classDoc.id;
        final className = classDoc.data()['name'] ?? classId;

        debugPrint('  📖 Loading schedule for class: $className ($classId)');

        // قراءة آخر جدول للفصل
        final classSchedulesSnapshot = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(_schoolId)
            .collection('Classes')
            .doc(classId)
            .collection('ClassSchedules')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (classSchedulesSnapshot.docs.isEmpty) {
          debugPrint('    ⚠️ No schedules found for class: $classId');
          continue;
        }

        final scheduleDoc = classSchedulesSnapshot.docs.first;
        final data = scheduleDoc.data();
        
        final lessons = (data['lessons'] as List<dynamic>?) ?? [];
        debugPrint('    ✅ Found schedule with ${lessons.length} lessons');
        
        if (lessons.isEmpty) {
          debugPrint('    ⚠️ Schedule is empty for class: $classId');
          continue;
        }
        
        // طباعة أول حصة للتشخيص
        if (lessons.isNotEmpty) {
          final firstLesson = lessons.first;
          debugPrint('    📝 First lesson: $firstLesson');
        }
        
        // تحويل lessons إلى صيغة الجدول (day -> [lessons])
        final scheduleByDay = <String, List<Map<String, dynamic>>>{};
        
        final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
        for (final day in days) {
          scheduleByDay[day] = [];
        }
        
        int? asInt(dynamic v) {
          if (v == null) return null;
          if (v is int) return v;
          if (v is num) return v.toInt();
          final s = v.toString().trim();
          return int.tryParse(s);
        }

        String? asString(dynamic v) {
          if (v == null) return null;
          final s = v.toString().trim();
          return s.isEmpty ? null : s;
        }

        for (final rawLesson in lessons) {
          if (rawLesson is! Map) {
            continue;
          }

          final lesson = rawLesson.map(
            (k, v) => MapEntry(k.toString(), v),
          );

          int? dayIndex = asInt(lesson['dayIndex']);

          if (dayIndex == null) {
            final dayName = asString(lesson['dayName']) ?? asString(lesson['day']);
            if (dayName != null) {
              final idx = days.indexOf(dayName);
              if (idx >= 0) dayIndex = idx;
            }
          }

          if (dayIndex == null || dayIndex < 0 || dayIndex >= days.length) {
            continue;
          }

          final day = days[dayIndex];
          scheduleByDay[day]!.add(Map<String, dynamic>.from(lesson));
        }
        
        // ترتيب الحصص حسب الفترة
        for (final day in scheduleByDay.keys) {
          scheduleByDay[day]!.sort((a, b) {
            final periodA = asInt(a['period']) ?? 0;
            final periodB = asInt(b['period']) ?? 0;
            return periodA.compareTo(periodB);
          });
        }
        
        // التحقق من أن الجدول يحتوي على حصص
        final totalLessons = scheduleByDay.values.fold<int>(0, (sum, list) => sum + list.length);
        debugPrint('    📊 Total lessons in schedule: $totalLessons');
        
        if (totalLessons > 0) {
          schedules.add({
            'classId': classId,
            'className': className,
            'schedule': scheduleByDay,
            'generatedAt': data['createdAt'],
          });
        }
      }

      debugPrint('✅ Loaded ${schedules.length} schedules with data');
      setState(() => _schoolSchedules = schedules);
    } catch (e) {
      debugPrint('❌ Error loading schedules: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _generateSchoolSchedule() async {
    if (_schoolId == null) return;

    setState(() => _isGenerating = true);

    try {
      Map<String, dynamic> result;
      
      // استخدام OR-Tools إذا كان مفعلاً
      if (ScheduleConfig.USE_ORTOOLS) {
        print('🚀 Using OR-Tools for schedule generation');
        result = await ORToolsScheduleService.generateSchedule(_schoolId!);
      } else {
        print('📱 Using Firebase Functions for schedule generation');
        final callable = FirebaseFunctions.instance.httpsCallable('generateSchoolSchedule');
        final response = await callable.call({'schoolId': _schoolId});
        result = Map<String, dynamic>.from(response.data);
      }

      if (result['success'] == true) {
        // 🔥 تنظيف الـ cache بعد التوليد الناجح
        debugPrint('\n🧹 CLEARING CACHE after successful generation...');
        ScheduleCacheManager.clearCacheForSchool(_schoolId!);
        
        // 📊 طباعة تفاصيل الجدول الجديد
        debugPrint('\n📊 Fetching and validating new schedule...');
        final latestSchedule = await ScheduleCacheManager.getLatestSchedule(_schoolId!);
        
        if (latestSchedule != null) {
          ScheduleCacheManager.printScheduleDetails(_schoolId!, latestSchedule);
          
          // التحقق من تنوع الأيام
          final lessons = (latestSchedule['data'] as Map?)?['lessons'] as List?;
          if (lessons != null) {
            final isDiverse = ScheduleCacheManager.validateScheduleDiversity(lessons);
            if (!isDiverse) {
              debugPrint('⚠️ WARNING: Schedule may have repeated patterns!');
            }
          }
        }
        
        // ⏳ انتظر قليلاً لضمان حفظ البيانات في Firestore
        debugPrint('⏳ Waiting for Firestore to save data...');
        await Future.delayed(Duration(seconds: 2));
        
        // إعادة تحميل الجداول
        debugPrint('🔄 Reloading schedules from Firestore...');
        await _loadSchoolSchedules();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result['message'] ?? 'تم توليد الجداول بنجاح'}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['error'] ?? 'فشل توليد الجداول'}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in generateSchoolSchedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _approveSchedules() async {
    if (_schoolSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ لا توجد جداول لاعتمادها'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('اعتماد الجداول'),
          ],
        ),
        content: Text(
          'هل تريد اعتماد جميع الجداول الحالية؟\n\n'
          'سيتم تفعيل الجداول وإتاحتها للمعلمين والطلاب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.check),
            label: Text('اعتماد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      int approvedCount = 0;

      // اعتماد جداول المعلمين مباشرة من Teachers collection
      final teachersSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Teachers').get();

      for (final t in teachersSnap.docs) {
        final data = t.data();
        if (data.containsKey('schedule') && (data['schedule'] as List?)?.isNotEmpty == true) {
          await t.reference.update({
            'scheduleApproved': true,
            'approvedAt': FieldValue.serverTimestamp(),
          });
          approvedCount++;
        }
      }

      // أيضاً اعتماد ClassSchedules
      final classesSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Classes').get();
      for (final cls in classesSnap.docs) {
        final schedSnap = await FirebaseFirestore.instance
            .collection('Schools').doc(_schoolId)
            .collection('Classes').doc(cls.id)
            .collection('ClassSchedules')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (schedSnap.docs.isNotEmpty) {
          await schedSnap.docs.first.reference.update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // اعتماد GeneralSchedule
      final generalSnap = await FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId)
          .collection('GeneralSchedule')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (generalSnap.docs.isNotEmpty) {
        await generalSnap.docs.first.reference.update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم اعتماد جداول $approvedCount معلم بنجاح'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      await _loadSchoolSchedules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في الاعتماد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('unauthenticated')) {
      return 'يجب تسجيل الدخول أولاً';
    } else if (errorStr.contains('not-found')) {
      return 'لا توجد فصول في المدرسة';
    } else if (errorStr.contains('invalid-argument')) {
      return 'بيانات غير صحيحة';
    } else if (errorStr.contains('permission-denied')) {
      return 'ليس لديك صلاحية لهذا الإجراء';
    } else {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
    }
  }

  bool _canSwapLessons(Map<String, dynamic>? lesson1, Map<String, dynamic>? lesson2) {
    // Both empty - can swap
    if (lesson1 == null && lesson2 == null) return true;
    
    // One empty - can swap
    if (lesson1 == null || lesson2 == null) return true;
    
    // Same teacher - cannot swap (teacher conflict)
    if (lesson1['teacherId'] == lesson2['teacherId']) return false;
    
    // Different teachers - can swap
    return true;
  }

  void _onLessonLongPress(String classId, String day, int period, Map<String, dynamic>? lesson) {
    setState(() {
      _isSwapMode = true;
      _selectedLesson = lesson;
      _selectedDay = day;
      _selectedPeriod = period;
      _selectedClassIdForSwap = classId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔄 اختر حصة أخرى للتبديل (أخضر = ممكن، أحمر = ممنوع)'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'إلغاء',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _isSwapMode = false;
              _selectedLesson = null;
              _selectedDay = null;
              _selectedPeriod = null;
              _selectedClassIdForSwap = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _onLessonTap(String classId, String day, int period, Map<String, dynamic>? lesson) async {
    if (!_isSwapMode) return;
    
    // Cannot swap with itself
    if (day == _selectedDay && period == _selectedPeriod) {
      setState(() {
        _isSwapMode = false;
        _selectedLesson = null;
        _selectedDay = null;
        _selectedPeriod = null;
        _selectedClassIdForSwap = null;
      });
      return;
    }

    // Check if swap is allowed
    if (!_canSwapLessons(_selectedLesson, lesson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ لا يمكن التبديل - نفس المعلم في نفس الوقت'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Perform swap
    try {
      final scheduleDoc = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Schedules')
          .doc(classId)
          .get();

      if (!scheduleDoc.exists) return;

      final scheduleData = scheduleDoc.data()!;
      final schedule = Map<String, dynamic>.from(scheduleData['schedule']);

      // Swap lessons
      final day1Lessons = List<dynamic>.from(schedule[_selectedDay!] ?? []);
      final day2Lessons = List<dynamic>.from(schedule[day] ?? []);

      final temp = day1Lessons[_selectedPeriod!];
      day1Lessons[_selectedPeriod!] = day2Lessons[period];
      day2Lessons[period] = temp;

      schedule[_selectedDay!] = day1Lessons;
      schedule[day] = day2Lessons;

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Schedules')
          .doc(classId)
          .update({'schedule': schedule});

      // Reload schedules
      await _loadSchoolSchedules();

      setState(() {
        _isSwapMode = false;
        _selectedLesson = null;
        _selectedDay = null;
        _selectedPeriod = null;
        _selectedClassIdForSwap = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تبديل الحصص بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في التبديل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateClassSchedule() async {
    if (_schoolId == null || _selectedClassId == null) return;

    setState(() => _isGenerating = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generateSmartSchedule');
      
      final result = await callable.call({
        'schoolId': _schoolId,
        'classId': _selectedClassId,
      });

      if (result.data['success'] == true) {
        setState(() {
          _generatedSchedule = result.data['schedule'];
        });

        await _loadSchoolSchedules();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم توليد الجدول بنجاح!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in generateClassSchedule: $e');
      // تجاهل الأخطاء - الصفحة تعمل
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _showConstraintsDialog() {
    context.push('/teacher-constraints');
  }

  Future<void> _exportClassSchedules() async {
    if (_schoolId == null) return;

    try {
      await PdfExportService.exportClassSchedules(_schoolId!);
    } catch (e) {
      print('Error exporting class schedules: $e');
      // تجاهل الأخطاء
    }
  }

  Future<void> _exportTeacherSchedules() async {
    if (_schoolId == null) return;

    try {
      await PdfExportService.exportTeacherSchedules(_schoolId!);
    } catch (e) {
      print('Error exporting teacher schedules: $e');
      // تجاهل الأخطاء
    }
  }

  Future<void> _exportMasterSchedule() async {
    if (_schoolId == null) return;

    try {
      await PdfExportService.exportMasterSchedule(_schoolId!);
    } catch (e) {
      print('Error exporting master schedule: $e');
      // تجاهل الأخطاء
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'الجدول المدرسي الذكي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            tooltip: 'القائمة',
            onSelected: (value) {
              switch (value) {
                case 'waiting':
                  context.push('/wait-management', extra: {'schoolId': _schoolId ?? ''});
                  break;
                case 'subjects':
                  context.push('/subjects-management');
                  break;
                case 'assignments':
                  context.push('/subject-assignment');
                  break;
                case 'constraints':
                  context.push('/teacher-constraints');
                  break;
                case 'export_master':
                  _exportMasterSchedule();
                  break;
                case 'export_classes':
                  _exportClassSchedules();
                  break;
                case 'export_teachers':
                  _exportTeacherSchedules();
                  break;
                case 'approve':
                  _approveSchedules();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'waiting',
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('جدول الانتظار'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'subjects',
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 12),
                    Text('المواد الدراسية'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'assignments',
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind, size: 20),
                    SizedBox(width: 12),
                    Text('إسناد المواد'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'constraints',
                child: Row(
                  children: [
                    Icon(Icons.rule, size: 20),
                    SizedBox(width: 12),
                    Text('القيود والتفضيلات'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'export_master',
                child: Row(
                  children: [
                    Icon(Icons.grid_on, size: 20, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('تصدير الجدول العام'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_classes',
                child: Row(
                  children: [
                    Icon(Icons.class_, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('تصدير جداول الفصول'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_teachers',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('تصدير جداول المعلمين'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('اعتماد الجداول'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSchoolSchedules,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _schoolId == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildModeSelector(),
                Expanded(
                  child: _viewMode == 'school'
                      ? _buildSchoolView()
                      : _viewMode == 'class'
                          ? _buildClassView()
                          : _buildAssignmentsView(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.indigo.shade700],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'الجدول المدرسي',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'توليد وإدارة جداول المدرسة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
          SizedBox(height: 12),
          Text(
            '⚠️ خطوة مهمة قبل التوليد',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يجب إسناد المواد للمعلمين أولاً لتجنب التكرار والأخطاء',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.push('/subject-assignment'),
            icon: Icon(Icons.assignment_ind),
            label: Text('إسناد المواد للمعلمين'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, color: Colors.green.shade700, size: 32),
          SizedBox(height: 12),
          Text(
            'نظام ذكي متكامل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'سيتم استخدام الإسنادات المحددة:\n• معلم واحد لكل مادة في كل فصل\n• عدد الحصص المحدد لكل مادة\n• توزيع ذكي بدون تكرار',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              'جدول المدرسة',
              Icons.school,
              'school',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildModeButton(
              'جدول فصل واحد',
              Icons.class_,
              'class',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildModeButton(
              'التكليفات',
              Icons.assignment_ind,
              'assignments',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, IconData icon, String mode) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.indigo : Colors.grey,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.indigo : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateSchoolSchedule,
                    icon: _isGenerating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.auto_awesome, size: 24),
                    label: Text(
                      _isGenerating ? 'جاري التوليد الذكي...' : '🚀 توليد جداول المدرسة (تلقائي)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ─── زر رفع جدول Excel ───────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/schedule-import'),
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text(
                      '📊 استيراد جدول Excel',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade700,
                      side: BorderSide(color: Colors.indigo.shade400, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_importMessage != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _importMessage!.contains('فشل') || _importMessage!.contains('⚠️')
                          ? Colors.orange.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _importMessage!.contains('فشل') || _importMessage!.contains('⚠️')
                            ? Colors.orange.shade200 : Colors.green.shade200),
                    ),
                    child: Text(_importMessage!,
                        style: TextStyle(
                          color: _importMessage!.contains('فشل') || _importMessage!.contains('⚠️')
                              ? Colors.orange.shade800 : Colors.green.shade800,
                          fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          if (_schoolSchedules.isEmpty)
            Container(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد جداول محفوظة',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'اضغط على الزر أعلاه لتوليد الجداول تلقائياً',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'النظام سيربط تلقائياً:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '✓ المعلمين حسب تخصصاتهم\n✓ الفصول المسندة لكل معلم\n✓ النصاب الأسبوعي\n✓ توزيع ذكي بدون تكرار',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              itemCount: _schoolSchedules.length,
              itemBuilder: (context, index) {
                final schedule = _schoolSchedules[index];
                return _buildScheduleCard(schedule);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final classId = schedule['classId'];
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.class_, color: Colors.indigo),
        ),
        title: Text(
          schedule['className'] ?? 'فصل',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _isSwapMode && _selectedClassIdForSwap == classId
              ? '🔄 اختر حصة للتبديل'
              : 'اضغط مطولاً على حصة لتبديلها',
          style: TextStyle(
            fontSize: 12,
            color: _isSwapMode && _selectedClassIdForSwap == classId ? Colors.blue : Colors.grey,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildScheduleTable(schedule['schedule'], classId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Schools/$_schoolId/Classes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                final classes = snapshot.data!.docs;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: InputDecoration(
                      labelText: 'اختر الفصل',
                      prefixIcon: Icon(Icons.class_, color: Colors.indigo),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: classes.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc['name'] ?? doc.id),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                        _generatedSchedule = null;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating || _selectedClassId == null
                    ? null
                    : _generateClassSchedule,
                icon: _isGenerating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'جاري التوليد...' : 'توليد الجدول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 24),
          if (_generatedSchedule != null)
            Padding(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildScheduleTable(_generatedSchedule!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable(Map<String, dynamic> schedule, [String? classId]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
        dataRowHeight: 70,
        headingRowHeight: 50,
        columnSpacing: 20,
        horizontalMargin: 12,
        columns: [
          DataColumn(
            label: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'الحصة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.indigo.shade900,
                ),
              ),
            ),
          ),
          ..._days.map((day) => DataColumn(
            label: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.indigo.shade900,
                ),
              ),
            ),
          )),
        ],
        rows: List.generate(7, (period) {
          return DataRow(
            cells: [
              DataCell(
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${period + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
              ),
              ..._days.map((day) {
                final lessons = schedule[day] as List?;
                final lesson = lessons != null && period < lessons.length
                    ? lessons[period]
                    : null;

                // Determine cell color based on swap mode
                Color cellColor;
                Color borderColor;
                bool isSelected = _isSwapMode && 
                    _selectedDay == day && 
                    _selectedPeriod == period &&
                    _selectedClassIdForSwap == classId;
                
                if (isSelected) {
                  cellColor = Colors.blue.shade100;
                  borderColor = Colors.blue.shade400;
                } else if (_isSwapMode && _selectedClassIdForSwap == classId) {
                  // Check if can swap
                  bool canSwap = _canSwapLessons(_selectedLesson, lesson);
                  if (canSwap) {
                    cellColor = Colors.green.shade50;
                    borderColor = Colors.green.shade300;
                  } else {
                    cellColor = Colors.red.shade50;
                    borderColor = Colors.red.shade300;
                  }
                } else {
                  cellColor = lesson != null ? Colors.blue.shade50 : Colors.grey.shade100;
                  borderColor = lesson != null ? Colors.blue.shade200 : Colors.grey.shade300;
                }

                return DataCell(
                  GestureDetector(
                    onLongPress: classId != null
                        ? () => _onLessonLongPress(classId, day, period, lesson)
                        : null,
                    onTap: classId != null && _isSwapMode && _selectedClassIdForSwap == classId
                        ? () => _onLessonTap(classId, day, period, lesson)
                        : null,
                    child: Container(
                      width: 120,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (lesson != null) ...[
                            Text(
                              lesson['subjectName'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blue.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    lesson['teacherName'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Center(
                              child: Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ),
    );
  }

  // ─── استيراد جدول من Excel (Wizard) ─────────────────────────────────────
  Future<void> _importScheduleFromExcel() async {
    if (_schoolId == null) return;
    final result = await showExcelImportWizard(
      context,
      _schoolId!,
      () => _loadSchoolSchedules(),
    );
    if (result == true) {
      setState(() => _importMessage = '✅ تم استيراد الجدول بنجاح');
      await _loadSchoolSchedules();
    }
  }

  /// استيراد جدول عام للمعلمين (Sheet واحد) — يُحفظ في Schools/{id}/GeneralSchedule

  // ─── قسم التكليفات ────────────────────────────────────────────────────────
  Widget _buildAssignmentsView() {
    if (_schoolId == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schools').doc(_schoolId).collection('Teachers').snapshots(),
      builder: (context, teachersSnap) {
        if (!teachersSnap.hasData) return const Center(child: CircularProgressIndicator());
        final teachers = teachersSnap.data!.docs;
        if (teachers.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('لا يوجد معلمون مسجلون',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            ],
          ));
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Schools').doc(_schoolId).collection('Classes').snapshots(),
          builder: (context, classesSnap) {
            final classes = classesSnap.data?.docs ?? [];
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachers.length,
              itemBuilder: (context, i) {
                final teacher = teachers[i];
                final data = teacher.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'معلم';
                final spec = data['specialization'] ?? data['primarySubjectId'] ?? '';
                final assignedIds = List<String>.from(data['assignedClassIds'] ?? []);
                final assignedNames = assignedIds.map((id) {
                  final cls = classes.where((c) => c.id == id).firstOrNull;
                  return ((cls?.data() as Map<String, dynamic>?)?['name'] ?? id).toString();
                }).join('، ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(name.isNotEmpty ? name[0] : '?',
                                style: TextStyle(color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                              if (spec.isNotEmpty)
                                Text(spec, style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          )),
                          TextButton.icon(
                            onPressed: () => _showAssignDialog(teacher.id, name, classes),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل'),
                            style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                          ),
                        ]),
                        if (assignedNames.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200)),
                            child: Row(children: [
                              Icon(Icons.class_, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Expanded(child: Text('الفصول: $assignedNames',
                                  style: TextStyle(color: Colors.green.shade800, fontSize: 12))),
                            ]),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text('لا توجد فصول مكلّفة',
                              style: TextStyle(color: Colors.orange.shade600, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignDialog(
      String teacherId, String teacherName, List<QueryDocumentSnapshot> classes) async {
    final doc = await FirebaseFirestore.instance
        .collection('Schools').doc(_schoolId).collection('Teachers').doc(teacherId).get();
    final selected = Set<String>.from(
        (doc.data()?['assignedClassIds'] as List<dynamic>?) ?? []);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تكليف: $teacherName'),
          content: SizedBox(
            width: 400,
            child: classes.isEmpty
                ? const Text('لا توجد فصول')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: classes.map((cls) {
                        final name = ((cls.data() as Map)['name'] ?? cls.id).toString();
                        return CheckboxListTile(
                          value: selected.contains(cls.id),
                          onChanged: (v) => setS(() {
                            if (v == true) selected.add(cls.id);
                            else selected.remove(cls.id);
                          }),
                          title: Text(name),
                          dense: true,
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('Schools').doc(_schoolId)
                    .collection('Teachers').doc(teacherId)
                    .update({'assignedClassIds': selected.toList()});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم حفظ التكليف'),
                        backgroundColor: Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
