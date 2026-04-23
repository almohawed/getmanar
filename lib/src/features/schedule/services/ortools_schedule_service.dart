import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'schedule_config.dart';

class ORToolsScheduleService {
  /// توليد الجدول باستخدام OR-Tools
  static Future<Map<String, dynamic>> generateSchedule(String schoolId) async {
    try {
      print('🚀 Using OR-Tools API: ${ScheduleConfig.ORTOOLS_BACKEND_URL}');
      
      // جلب البيانات من Firestore
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Classes')
          .get();
      
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Teachers')
          .get();
      
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/SubjectAssignments')
          .get();
      
      // تحضير البيانات بالصيغة الصحيحة
      final classes = classesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? doc.id,
          'grade': data['grade']?.toString() ?? '1', // Backend V2 يتوقع grade كـ string
          'track': data['track'], // المسار (اختياري)
        };
      }).toList();
      
      final teachers = teachersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'subjects': (data['subjects'] as List<dynamic>?)?.cast<String>() ?? [],
          'maxWeeklyLoad': data['maxWeeklyLoad'] ?? 24,
        };
      }).toList();
      
      // تجميع المواد الفريدة
      final subjectsMap = <String, Map<String, dynamic>>{};
      final assignments = <Map<String, dynamic>>[];
      
      for (var doc in assignmentsSnapshot.docs) {
        final data = doc.data();
        final subjectName = data['subjectName'] ?? '';
        final weeklyHours = data['weeklyHours'] ?? 2;
        final teacherId = data['teacherId'] ?? '';
        final classId = data['classId'] ?? '';
        
        // تخطي الإسنادات غير الكاملة
        if (subjectName.isEmpty || teacherId.isEmpty || classId.isEmpty) {
          print('⚠️ Skipping incomplete assignment: $data');
          continue;
        }
        
        // إضافة المادة إذا لم تكن موجودة
        if (!subjectsMap.containsKey(subjectName)) {
          subjectsMap[subjectName] = {
            'id': subjectName,
            'name': subjectName,
            'normalizedName': subjectName,
            'weeklyHours': weeklyHours,
            'maxPerDay': 2,
          };
        }
        
        // إضافة الإسناد
        assignments.add({
          'teacherId': teacherId,
          'classId': classId,
          'subjectId': subjectName,
          'subjectName': subjectName, // Backend V2 يتوقع subjectName أيضاً
          'weeklyHours': weeklyHours,
          'allowDouble': data['allowDouble'] ?? false, // السماح بحصص مزدوجة
        });
      }
      
      final subjects = subjectsMap.values.toList();
      
      print('📊 Data: ${classes.length} classes, ${teachers.length} teachers, ${subjects.length} subjects, ${assignments.length} assignments');
      
      // التحقق من وجود بيانات كافية
      if (classes.isEmpty) {
        return {
          'success': false,
          'error': 'لا توجد فصول دراسية',
        };
      }
      
      if (teachers.isEmpty) {
        return {
          'success': false,
          'error': 'لا يوجد معلمون',
        };
      }
      
      if (assignments.isEmpty) {
        return {
          'success': false,
          'error': 'لا توجد إسنادات للمواد',
        };
      }
      
      final requestBody = {
        'schoolId': schoolId,
        'schoolType': 'middle', // نوع المدرسة (يمكن تخصيصه لاحقاً)
        'classes': classes,
        'teachers': teachers,
        'assignments': assignments,
        'manualConstraints': [], // قيود يدوية (فارغة حالياً)
        'saveToFirebase': true, // حفظ النتائج في Firebase
      };
      
      print('📤 Request body summary:');
      print('  - Classes: ${classes.length}');
      print('  - Teachers: ${teachers.length}');
      print('  - Assignments: ${assignments.length}');
      print('  - Total hours by class:');
      final hoursByClass = <String, int>{};
      for (var a in assignments) {
        hoursByClass[a['classId']] = (hoursByClass[a['classId']] ?? 0) + (a['weeklyHours'] as int);
      }
      hoursByClass.forEach((classId, hours) {
        print('    $classId: $hours hours');
      });
      
      print('📤 Sending request to OR-Tools Backend V2...');
      
      // إرسال الطلب إلى Backend V2
      final response = await http.post(
        Uri.parse('${ScheduleConfig.ORTOOLS_BACKEND_URL}/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 120));
      
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          print('✅ Backend V2 succeeded!');
          print('📊 Diagnostics: ${result['diagnostics']}');
          
          return {
            'success': true,
            'message': result['message'] ?? 'تم توليد الجداول بنجاح',
            'diagnostics': result['diagnostics'],
            'precheckReport': result['precheckReport'],
            'classSchedules': result['classSchedules'],
            'teacherSchedules': result['teacherSchedules'],
            'lessons': result['lessons'],
            'scheduleId': result['scheduleId'],
            'method': 'ortools-v2',
          };
        } else {
          print('❌ Backend V2 failed: ${result['message']}');
          print('📋 Precheck Report: ${result['precheckReport']}');
          
          // عرض تفاصيل المشاكل
          if (result['precheckReport'] != null && result['precheckReport']['issues'] != null) {
            print('🔍 Issues found:');
            for (var issue in result['precheckReport']['issues']) {
              print('  - ${issue['code']}: ${issue['message']} (severity: ${issue['severity']})');
            }
          }
          
          return {
            'success': false,
            'error': result['message'] ?? 'فشل التوليد',
            'precheckReport': result['precheckReport'],
            'diagnostics': result['diagnostics'],
          };
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        print('Response: ${response.body}');
        return {
          'success': false,
          'error': 'خطأ في الاتصال بالخادم: ${response.statusCode}\n${response.body}',
        };
      }
    } catch (e) {
      print('❌ Exception: $e');
      return {
        'success': false,
        'error': 'خطأ: $e',
      };
    }
  }
}
