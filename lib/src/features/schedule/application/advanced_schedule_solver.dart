import 'dart:math';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../../intelligence/domain/scheduling/teacher_constraints_profile.dart';
import '../domain/schedule_slot.dart';

/// Advanced Schedule Solver - نظام حل الجدول المتقدم
/// 
/// نظام قوي جداً لحل مشكلة الجدول المدرسي باستخدام:
/// - CSP (Constraint Satisfaction Problem) 
/// - Backtracking with Forward Checking
/// - Most Constrained First Heuristic
/// - Intelligent Scoring System
/// - Advanced Constraints
class AdvancedScheduleSolver {
  // Constants
  static const List<String> _days = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'
  ];
  static const int _periodsPerDay = 7;
  static const int _maxSameSubjectPerDay = 2;
  static const int _maxConsecutivePeriods = 3;

  // Core data structures
  final List<User> teachers;
  final List<String> classIds;
  final List<TeacherConstraintsProfile> profiles;
  final Map<String, Map<String, int>> classDemand;
  final int? activityPeriod;
  final Random random;

  // Solver state
  late Map<String, TeacherConstraintsProfile> _profileById;
  late Map<String, Set<String>> _teacherSubjects;
  late Map<String, List<String>> _subjectTeachers;
  late List<_Variable> _variables;
  late Map<String, _Variable> _variableIndex;
  late Map<String, List<_Variable>> _teacherVariables;
  late Map<String, List<_Variable>> _classVariables;

  // Statistics
  int _nodesExplored = 0;
  int _backtrackCount = 0;
  int _forwardCheckingPruned = 0;
  DateTime? _startTime;

  AdvancedScheduleSolver({
    required this.teachers,
    required this.classIds,
    required this.profiles,
    required this.classDemand,
    this.activityPeriod,
    int? seed,
  }) : random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  /// حل الجدول الرئيسي
  Future<AdvancedSolverResult> solve({
    int maxTimeSeconds = 30,
    int maxNodes = 100000,
  }) async {
    _startTime = DateTime.now();
    final deadline = _startTime!.add(Duration(seconds: maxTimeSeconds));
    
    debugPrint('🚀 [Advanced Solver] بدء حل الجدول...');
    debugPrint('📊 المعلمين: ${teachers.length}, الفصول: ${classIds.length}');
    
    try {
      _initializeSolver();
      
      if (_variables.isEmpty) {
        debugPrint('⚠️ [Advanced Solver] لا توجد متغيرات للحل');
        return AdvancedSolverResult(
          success: false,
          schedule: {},
          metrics: {'completionRate': 0.0, 'totalVacancies': 0},
          statistics: _getStatistics(),
          error: 'لا توجد حصص مطلوبة',
        );
      }
      
      debugPrint('🔧 تم إنشاء ${_variables.length} متغير');
      
      // محاولة الحل الكامل
      var solution = await _solveCSP(deadline, maxNodes);
      
      // إذا فشل الحل الكامل، حاول حل جزئي
      if (solution == null) {
        debugPrint('⚠️ [Advanced Solver] الحل الكامل فشل، محاولة حل جزئي...');
        solution = await _solvePartial(deadline, maxNodes);
      }
      
      if (solution != null && solution.isNotEmpty) {
        final schedule = _convertToSchedule(solution);
        final metrics = _calculateMetrics(schedule);
        
        final completionRate = metrics['completionRate'] as double;
        debugPrint('✅ [Advanced Solver] تم حل الجدول!');
        debugPrint('📈 معدل الإكمال: ${completionRate.toStringAsFixed(1)}%');
        debugPrint('📊 الحصص المملوءة: ${metrics['filledSlots']}/${metrics['totalSlots']}');
        
        return AdvancedSolverResult(
          success: completionRate >= 80.0, // نعتبر النجاح إذا كان الإكمال 80% أو أكثر
          schedule: schedule,
          metrics: metrics,
          statistics: _getStatistics(),
        );
      } else {
        debugPrint('❌ [Advanced Solver] فشل في إيجاد حل');
        return AdvancedSolverResult(
          success: false,
          schedule: {},
          metrics: {'completionRate': 0.0, 'totalVacancies': _getTotalSlots()},
          statistics: _getStatistics(),
          error: 'لم يتم العثور على حل في الوقت المحدد',
        );
      }
    } catch (e, stack) {
      debugPrint('💥 [Advanced Solver] خطأ: $e');
      debugPrint(stack.toString());
      return AdvancedSolverResult(
        success: false,
        schedule: {},
        metrics: {'completionRate': 0.0, 'totalVacancies': _getTotalSlots()},
        statistics: _getStatistics(),
        error: e.toString(),
      );
    }
  }

  /// حل جزئي - يحاول ملء أكبر عدد ممكن من الفترات
  Future<Map<String, _Assignment>?> _solvePartial(DateTime deadline, int maxNodes) async {
    final assignment = <String, _Assignment>{};
    
    // ترتيب المتغيرات حسب الأولوية
    final sortedVariables = List<_Variable>.from(_variables);
    sortedVariables.sort((a, b) {
      // أولوية للمتغيرات التي لها مادة محددة
      if (a.requiredSubject != null && b.requiredSubject == null) return -1;
      if (a.requiredSubject == null && b.requiredSubject != null) return 1;
      
      // ثم حسب حجم النطاق (الأصغر أولاً)
      return a.domain.length.compareTo(b.domain.length);
    });
    
    // محاولة إسناد كل متغير
    for (final variable in sortedVariables) {
      if (DateTime.now().isAfter(deadline)) break;
      if (_nodesExplored > maxNodes) break;
      
      _nodesExplored++;
      
      // تجربة كل قيمة في النطاق
      for (final value in variable.domain) {
        if (_isConsistent(variable, value, assignment)) {
          assignment[variable.id] = value;
          break;
        }
      }
    }
    
    return assignment.isNotEmpty ? assignment : null;
  }

  /// تهيئة المحلل
  void _initializeSolver() {
    _profileById = {for (final p in profiles) p.teacherId: p};
    _teacherSubjects = {};
    _subjectTeachers = {};
    _variables = [];
    _variableIndex = {};
    _teacherVariables = {};
    _classVariables = {};

    // بناء خريطة المواد للمعلمين
    for (final teacher in teachers) {
      final subjects = <String>{};
      
      // المادة الأساسية
      if (teacher.primarySubjectId?.isNotEmpty == true) {
        subjects.add(teacher.primarySubjectId!);
      }
      
      // المواد الإضافية
      for (final assignment in teacher.subjectAssignments ?? []) {
        if (assignment.subjectId.isNotEmpty) {
          subjects.add(assignment.subjectId);
        }
      }
      
      _teacherSubjects[teacher.id] = subjects;
      
      // بناء خريطة المعلمين للمواد
      for (final subject in subjects) {
        _subjectTeachers.putIfAbsent(subject, () => []).add(teacher.id);
      }
    }

    // إنشاء المتغيرات
    _createVariables();
    
    debugPrint('🔧 تم إنشاء ${_variables.length} متغير');
  }

  /// إنشاء متغيرات CSP
  void _createVariables() {
    // إنشاء قائمة بجميع الحصص المطلوبة لكل فصل
    final classSubjectSlots = <String, List<String>>{};
    
    for (final classId in classIds) {
      final demand = classDemand[classId] ?? {};
      final slots = <String>[];
      
      // لكل مادة، أضف عدد الحصص المطلوبة
      for (final entry in demand.entries) {
        final subject = entry.key;
        final count = entry.value;
        
        for (int i = 0; i < count; i++) {
          slots.add(subject);
        }
      }
      
      classSubjectSlots[classId] = slots;
    }
    
    // إنشاء متغير لكل فترة زمنية لكل فصل
    int slotIndex = 0;
    for (final classId in classIds) {
      final requiredSlots = classSubjectSlots[classId] ?? [];
      
      for (final day in _days) {
        for (int period = 1; period <= _periodsPerDay; period++) {
          // تجاهل فترة النشاط
          if (activityPeriod != null && period == activityPeriod) continue;
          
          // تحديد المادة المطلوبة لهذه الفترة (إذا كان هناك حصص متبقية)
          String? requiredSubject;
          if (slotIndex < requiredSlots.length) {
            requiredSubject = requiredSlots[slotIndex];
          }
          
          final variable = _Variable(
            id: '${classId}_${day}_$period',
            classId: classId,
            day: day,
            period: period,
            requiredSubject: requiredSubject,
            domain: _calculateDomain(classId, day, period, requiredSubject),
          );
          
          _variables.add(variable);
          _variableIndex[variable.id] = variable;
          
          // فهرسة المتغيرات حسب المعلم والفصل
          for (final assignment in variable.domain) {
            _teacherVariables.putIfAbsent(assignment.teacherId, () => []).add(variable);
          }
          _classVariables.putIfAbsent(classId, () => []).add(variable);
        }
      }
      
      slotIndex = 0; // إعادة تعيين للفصل التالي
    }
  }

  /// حساب النطاق المتاح لمتغير
  List<_Assignment> _calculateDomain(String classId, String day, int period, String? requiredSubject) {
    final domain = <_Assignment>[];
    
    // إذا كانت هناك مادة محددة مطلوبة
    if (requiredSubject != null && requiredSubject.isNotEmpty) {
      final teachers = _subjectTeachers[requiredSubject] ?? [];
      
      // لكل معلم يدرس هذه المادة
      for (final teacherId in teachers) {
        final profile = _profileById[teacherId];
        if (profile == null) continue;
        
        // التحقق من القيود الأساسية
        if (_isTeacherAvailable(teacherId, day, period)) {
          final score = _calculateAssignmentScore(teacherId, requiredSubject, classId, day, period);
          domain.add(_Assignment(
            teacherId: teacherId,
            subject: requiredSubject,
            score: score,
          ));
        }
      }
    } else {
      // إذا لم تكن هناك مادة محددة، جرب جميع المواد المتاحة
      for (final entry in _subjectTeachers.entries) {
        final subject = entry.key;
        final teachers = entry.value;
        
        for (final teacherId in teachers) {
          final profile = _profileById[teacherId];
          if (profile == null) continue;
          
          if (_isTeacherAvailable(teacherId, day, period)) {
            final score = _calculateAssignmentScore(teacherId, subject, classId, day, period);
            domain.add(_Assignment(
              teacherId: teacherId,
              subject: subject,
              score: score,
            ));
          }
        }
      }
    }
    
    // ترتيب النطاق حسب النقاط (الأفضل أولاً)
    domain.sort((a, b) => b.score.compareTo(a.score));
    
    return domain;
  }

  /// التحقق من توفر المعلم
  bool _isTeacherAvailable(String teacherId, String day, int period) {
    final profile = _profileById[teacherId];
    if (profile == null) return false;
    
    // التحقق من الأوقات المحجوبة
    if (profile.blockedTimeSlots.contains('$day:$period')) {
      return false;
    }
    
    return true;
  }

  /// حساب نقاط الإسناد
  double _calculateAssignmentScore(String teacherId, String subject, String classId, String day, int period) {
    double score = 100.0;
    
    final teacher = teachers.firstWhere((t) => t.id == teacherId);
    final profile = _profileById[teacherId]!;
    
    // نقاط المادة الأساسية
    if (teacher.primarySubjectId == subject) {
      score += 50.0;
    }
    
    // نقاط الفصول المخصصة
    if (teacher.assignedClassIds?.contains(classId) == true) {
      score += 30.0;
    }
    
    // تجنب الفترة السابعة إذا أمكن
    if (period == 7) {
      score -= 20.0;
    }
    
    // تفضيل الفترات الوسطى
    if (period >= 3 && period <= 5) {
      score += 10.0;
    }
    
    // عشوائية صغيرة لكسر التعادل
    score += random.nextDouble() * 5.0;
    
    return score;
  }

  /// حل CSP باستخدام Backtracking مع Forward Checking
  Future<Map<String, _Assignment>?> _solveCSP(DateTime deadline, int maxNodes) async {
    final assignment = <String, _Assignment>{};
    
    return await _backtrack(assignment, deadline, maxNodes);
  }

  /// Backtracking الرئيسي
  Future<Map<String, _Assignment>?> _backtrack(
    Map<String, _Assignment> assignment,
    DateTime deadline,
    int maxNodes,
  ) async {
    _nodesExplored++;
    
    // التحقق من الحدود
    if (_nodesExplored > maxNodes || DateTime.now().isAfter(deadline)) {
      return null;
    }
    
    // إذا تم إسناد جميع المتغيرات
    if (assignment.length == _variables.length) {
      return assignment;
    }
    
    // اختيار المتغير التالي (Most Constrained First)
    final variable = _selectUnassignedVariable(assignment);
    if (variable == null) return null;
    
    // تطبيق Forward Checking
    final filteredDomain = _forwardCheck(variable, assignment);
    
    // تجربة كل قيمة في النطاق
    for (final value in filteredDomain) {
      if (_isConsistent(variable, value, assignment)) {
        // إسناد القيمة
        assignment[variable.id] = value;
        
        // المتابعة بالتكرار
        final result = await _backtrack(assignment, deadline, maxNodes);
        if (result != null) {
          return result;
        }
        
        // إلغاء الإسناد (Backtrack)
        assignment.remove(variable.id);
        _backtrackCount++;
      }
    }
    
    return null;
  }

  /// اختيار المتغير التالي (Most Constrained First)
  _Variable? _selectUnassignedVariable(Map<String, _Assignment> assignment) {
    _Variable? bestVariable;
    int minDomainSize = 1000000;
    int maxConstraints = -1;
    
    for (final variable in _variables) {
      if (assignment.containsKey(variable.id)) continue;
      
      final domainSize = _forwardCheck(variable, assignment).length;
      final constraintCount = _countConstraints(variable);
      
      // Most Constrained First + Smallest Domain
      if (domainSize < minDomainSize || 
          (domainSize == minDomainSize && constraintCount > maxConstraints)) {
        bestVariable = variable;
        minDomainSize = domainSize;
        maxConstraints = constraintCount;
      }
    }
    
    return bestVariable;
  }

  /// Forward Checking - تصفية النطاق
  List<_Assignment> _forwardCheck(_Variable variable, Map<String, _Assignment> assignment) {
    final filtered = <_Assignment>[];
    
    for (final value in variable.domain) {
      if (_wouldBeConsistent(variable, value, assignment)) {
        filtered.add(value);
      } else {
        _forwardCheckingPruned++;
      }
    }
    
    return filtered;
  }

  /// التحقق من الاتساق
  bool _isConsistent(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    return _wouldBeConsistent(variable, value, assignment);
  }

  /// التحقق من الاتساق المحتمل
  bool _wouldBeConsistent(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    // 1. تعارض المعلم (نفس المعلم في نفس الوقت)
    if (_hasTeacherConflict(variable, value, assignment)) return false;
    
    // 2. حد المادة الواحدة في اليوم للفصل
    if (_exceedsSubjectDailyLimit(variable, value, assignment)) return false;
    
    // 3. حد الحصص المتتالية للمعلم
    if (_exceedsConsecutiveLimit(variable, value, assignment)) return false;
    
    // 4. حد النصاب الأسبوعي للمعلم
    if (_exceedsWeeklyQuota(variable, value, assignment)) return false;
    
    return true;
  }

  /// التحقق من تعارض المعلم
  bool _hasTeacherConflict(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    for (final entry in assignment.entries) {
      final otherVar = _variableIndex[entry.key]!;
      final otherValue = entry.value;
      
      // نفس المعلم في نفس الوقت
      if (otherValue.teacherId == value.teacherId &&
          otherVar.day == variable.day &&
          otherVar.period == variable.period) {
        return true;
      }
    }
    return false;
  }

  /// التحقق من حد المادة في اليوم
  bool _exceedsSubjectDailyLimit(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    int count = 0;
    
    for (final entry in assignment.entries) {
      final otherVar = _variableIndex[entry.key]!;
      final otherValue = entry.value;
      
      // نفس الفصل ونفس اليوم ونفس المادة
      if (otherVar.classId == variable.classId &&
          otherVar.day == variable.day &&
          otherValue.subject == value.subject) {
        count++;
      }
    }
    
    return count >= _maxSameSubjectPerDay;
  }

  /// التحقق من حد الحصص المتتالية
  bool _exceedsConsecutiveLimit(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    // البحث عن الحصص المتتالية للمعلم في نفس اليوم
    final teacherPeriods = <int>[];
    
    for (final entry in assignment.entries) {
      final otherVar = _variableIndex[entry.key]!;
      final otherValue = entry.value;
      
      if (otherValue.teacherId == value.teacherId && otherVar.day == variable.day) {
        teacherPeriods.add(otherVar.period);
      }
    }
    
    teacherPeriods.add(variable.period);
    teacherPeriods.sort();
    
    // التحقق من التتالي
    int consecutive = 1;
    for (int i = 1; i < teacherPeriods.length; i++) {
      if (teacherPeriods[i] == teacherPeriods[i-1] + 1) {
        consecutive++;
        if (consecutive > _maxConsecutivePeriods) {
          return true;
        }
      } else {
        consecutive = 1;
      }
    }
    
    return false;
  }

  /// التحقق من النصاب الأسبوعي
  bool _exceedsWeeklyQuota(_Variable variable, _Assignment value, Map<String, _Assignment> assignment) {
    final profile = _profileById[value.teacherId];
    if (profile == null) return false;
    
    int currentLoad = 0;
    
    for (final entry in assignment.entries) {
      final otherValue = entry.value;
      if (otherValue.teacherId == value.teacherId) {
        currentLoad++;
      }
    }
    
    return currentLoad >= profile.weeklyQuota;
  }

  /// عد القيود للمتغير
  int _countConstraints(_Variable variable) {
    // عدد المتغيرات المرتبطة (نفس المعلم، نفس الفصل، نفس اليوم)
    int count = 0;
    
    for (final other in _variables) {
      if (other.id == variable.id) continue;
      
      // نفس الفصل
      if (other.classId == variable.classId) count++;
      
      // نفس اليوم (للمعلمين المشتركين)
      if (other.day == variable.day) {
        for (final assignment in variable.domain) {
          if (other.domain.any((a) => a.teacherId == assignment.teacherId)) {
            count++;
            break;
          }
        }
      }
    }
    
    return count;
  }

  /// تحويل الحل إلى جدول
  Map<String, List<ScheduleSlot>> _convertToSchedule(Map<String, _Assignment> solution) {
    final schedule = <String, List<ScheduleSlot>>{};
    
    for (final entry in solution.entries) {
      final variable = _variableIndex[entry.key]!;
      final assignment = entry.value;
      
      final slot = ScheduleSlot(
        day: variable.day,
        period: variable.period,
        className: 'Class ${variable.classId}',
        subject: assignment.subject,
        teacherId: assignment.teacherId,
      );
      
      schedule.putIfAbsent(assignment.teacherId, () => []).add(slot);
    }
    
    return schedule;
  }

  /// حساب المقاييس
  Map<String, dynamic> _calculateMetrics(Map<String, List<ScheduleSlot>> schedule) {
    final totalSlots = _getTotalSlots();
    final filledSlots = schedule.values.fold<int>(0, (sum, slots) => sum + slots.length);
    final completionRate = (filledSlots / totalSlots * 100).round();
    
    return {
      'completionRate': completionRate.toDouble(),
      'totalSlots': totalSlots,
      'filledSlots': filledSlots,
      'totalVacancies': totalSlots - filledSlots,
      'teachersUsed': schedule.keys.length,
      'averageSlotsPerTeacher': schedule.isEmpty ? 0.0 : filledSlots / schedule.keys.length,
    };
  }

  /// الحصول على إحصائيات الحل
  Map<String, dynamic> _getStatistics() {
    final duration = _startTime != null 
        ? DateTime.now().difference(_startTime!).inMilliseconds 
        : 0;
    
    return {
      'nodesExplored': _nodesExplored,
      'backtrackCount': _backtrackCount,
      'forwardCheckingPruned': _forwardCheckingPruned,
      'durationMs': duration,
      'variablesTotal': _variables.length,
    };
  }

  /// الحصول على إجمالي الفترات
  int _getTotalSlots() {
    final periodsPerDay = activityPeriod != null ? _periodsPerDay - 1 : _periodsPerDay;
    return classIds.length * _days.length * periodsPerDay;
  }
}

/// متغير CSP
class _Variable {
  final String id;
  final String classId;
  final String day;
  final int period;
  final String? requiredSubject;
  final List<_Assignment> domain;

  _Variable({
    required this.id,
    required this.classId,
    required this.day,
    required this.period,
    this.requiredSubject,
    required this.domain,
  });
}

/// إسناد قيمة
class _Assignment {
  final String teacherId;
  final String subject;
  final double score;

  _Assignment({
    required this.teacherId,
    required this.subject,
    required this.score,
  });
}

/// نتيجة المحلل المتقدم
class AdvancedSolverResult {
  final bool success;
  final Map<String, List<ScheduleSlot>> schedule;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> statistics;
  final String? error;

  AdvancedSolverResult({
    required this.success,
    required this.schedule,
    required this.metrics,
    required this.statistics,
    this.error,
  });
}