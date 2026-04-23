import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/notification_record.dart';
import 'notifications_provider.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../academic/domain/classroom.dart';

class SendAnnouncementScreen extends ConsumerStatefulWidget {
  const SendAnnouncementScreen({super.key});

  @override
  ConsumerState<SendAnnouncementScreen> createState() =>
      _SendAnnouncementScreenState();
}

class _SendAnnouncementScreenState
    extends ConsumerState<SendAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  // Teacher State
  String _teacherTargetType = 'all'; // all, classes, students
  final List<Classroom> _selectedClasses = [];
  final List<User> _selectedStudents = [];

  // Admin/Deputy State
  bool _sendToAdministrative = false; // إداريين + مدير + وكلاء
  bool _sendToTeachers = false;
  bool _sendToCounselors = false;
  bool _sendToStudents = false;
  bool _sendToParents = false;

  // Super Admin State
  bool _sendToSubscribedManagers = true;

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _toggleAdminAll() {
    setState(() {
      final newValue =
          !(_sendToAdministrative &&
              _sendToTeachers &&
              _sendToCounselors &&
              _sendToStudents &&
              _sendToParents);
      _sendToAdministrative = newValue;
      _sendToTeachers = newValue;
      _sendToCounselors = newValue;
      _sendToStudents = newValue;
      _sendToParents = newValue;
    });
  }

  String _getRoleTitle(User user) {
    if (user.role == UserRole.superAdmin) return 'إدارة التطبيق';
    if (user.role == UserRole.admin) return 'مدير المدرسة';
    if (user.role == UserRole.teacher) return 'معلم المادة';
    if (user.role == UserRole.counselor) return 'المرشد الطلابي';
    if (user.role == UserRole.deputy) {
      switch (user.deputyType) {
        case 'academic':
          return 'وكيل الشؤون التعليمية';
        case 'students':
          return 'وكيل شؤون الطلاب';
        case 'stage':
          return 'وكيل المرحلة';
        default:
          return 'وكيل المدرسة';
      }
    }
    return 'الإدارة المدرسية';
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Super Admin Bypass for schoolId check
    if (user.role != UserRole.superAdmin && user.schoolId == null) return;

    // Validation
    if (user.role == UserRole.teacher) {
      if (_teacherTargetType == 'classes' && _selectedClasses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار فصل واحد على الأقل')),
        );
        return;
      }
      if (_teacherTargetType == 'students' && _selectedStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار طالب واحد على الأقل')),
        );
        return;
      }
    } else if (user.role == UserRole.superAdmin) {
      // Always send if super admin
    } else {
      if (!_sendToAdministrative &&
          !_sendToTeachers &&
          !_sendToCounselors &&
          !_sendToStudents &&
          !_sendToParents) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار فئة واحدة على الأقل')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(notificationRepositoryProvider);
      final batch = <Future>[];
      final timestamp = DateTime.now();

      // Auto-Signature
      final signature =
          '\n\nمع تحياتي لكم\n${user.name}\n${_getRoleTitle(user)}';
      final fullBody = _bodyController.text.trim() + signature;

      // Super Admin Logic
      if (user.role == UserRole.superAdmin) {
        // Fetch all schools
        final schoolsSnapshot = await FirebaseFirestore.instance
            .collection('Schools')
            .get();

        for (final schoolDoc in schoolsSnapshot.docs) {
          // Check subscription if needed (assuming 'isSubscribed' field or similar exists, or just send to all)
          // The user said "Subscribed Only". Let's check for a subscription flag.
          // If no flag, we assume all active schools are "subscribed" or check a 'subscription' subcollection?
          // For now, let's assume we send to ALL schools found in 'Schools' collection as they are registered.
          // Ideally, we check schoolDoc.data()['subscriptionStatus'] == 'active'.

          final data = schoolDoc.data();
          // Simple check: if they have a school ID, they are "in".
          // Enhance: Check if 'isSubscribed' is true if the field exists.
          // For robust "Sheriff" mode, let's send to all present schools to ensure delivery.

          final schoolId = schoolDoc.id;

          final id = const Uuid().v4();
          final notification = NotificationRecord(
            id: id,
            title: _titleController.text.trim(),
            body: fullBody,
            timestamp: timestamp,
            schoolId: schoolId,
            targetRole: 'admin', // Target the manager specifically
            data: {
              'type': 'announcement',
              'senderId': user.id,
              'senderName': user.name,
              'senderRole': 'superAdmin',
              'isGlobal': true,
            },
          );

          // Write directly to each school's notification collection to ensure it reaches them
          batch.add(repo.sendNotification(notification));
        }
      } else {
        // School Staff Logic
        final schoolId = user.schoolId!;

        // Helper to create notification
        Future<void> send({
          String? targetRole,
          String? targetUserId,
          String? targetClassId,
        }) {
          final id = const Uuid().v4();
          final notification = NotificationRecord(
            id: id,
            title: _titleController.text.trim(),
            body: fullBody,
            timestamp: timestamp,
            schoolId: schoolId,
            targetRole: targetRole,
            userId: targetUserId,
            targetClassId: targetClassId,
            data: {
              'type': 'announcement',
              'senderId': user.id,
              'senderName': user.name,
              'senderRole': user.role.name,
            },
          );
          return repo.sendNotification(notification);
        }

        if (user.role == UserRole.teacher) {
          // Teacher Logic
          if (_teacherTargetType == 'all') {
            // All my classes -> All students + parents
            final classes =
                ref.read(classesProvider).value?.where((c) {
                  return user.assignedClassIds?.contains(c.id) ?? false;
                }).toList() ??
                [];

            for (final cls in classes) {
              // Send to Class Topic (Students)
              batch.add(send(targetClassId: cls.id));

              // Explicitly fetch students in this class to notify parents
              // This is "heavy" but ensures parents get it even if they don't subscribe to class topic
              final studentsSnapshot = await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('Students')
                  .where('classId', isEqualTo: cls.id)
                  .get();

              for (final doc in studentsSnapshot.docs) {
                final studentData = doc.data();
                final parentId = studentData['parentId'];
                if (parentId != null && parentId.toString().isNotEmpty) {
                  batch.add(send(targetUserId: parentId));
                }
              }
            }
          } else if (_teacherTargetType == 'classes') {
            for (final cls in _selectedClasses) {
              batch.add(send(targetClassId: cls.id));

              // Fetch students for parents
              final studentsSnapshot = await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('Students')
                  .where('classId', isEqualTo: cls.id)
                  .get();

              for (final doc in studentsSnapshot.docs) {
                final studentData = doc.data();
                final parentId = studentData['parentId'];
                if (parentId != null && parentId.toString().isNotEmpty) {
                  batch.add(send(targetUserId: parentId));
                }
              }
            }
          } else if (_teacherTargetType == 'students') {
            for (final student in _selectedStudents) {
              batch.add(send(targetUserId: student.id));
              if (student.parentId != null && student.parentId!.isNotEmpty) {
                batch.add(send(targetUserId: student.parentId));
              }
            }
          }
        } else {
          // Admin/Deputy Logic
          if (_sendToAdministrative) {
            batch.add(send(targetRole: 'administrative'));
            batch.add(send(targetRole: 'deputy'));
            batch.add(send(targetRole: 'admin'));
          }
          if (_sendToTeachers) batch.add(send(targetRole: 'teacher'));
          if (_sendToCounselors) batch.add(send(targetRole: 'counselor'));
          if (_sendToStudents) batch.add(send(targetRole: 'student'));
          if (_sendToParents) batch.add(send(targetRole: 'parent'));
        }
      }

      await Future.wait(batch);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الإعلان بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isTeacher = user?.role == UserRole.teacher;
    final isSuperAdmin = user?.role == UserRole.superAdmin;

    // Warm up providers for selection dialogs
    if (isTeacher) {
      ref.watch(studentsProvider);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF7B1FA2)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إرسال إعلان جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('إشعار فوري لجميع المستهدفين', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة محتوى الإعلان
              _buildFormCard(
                title: 'محتوى الإعلان',
                icon: Icons.campaign_rounded,
                color: const Color(0xFF4A148C),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'عنوان الإعلان',
                        prefixIcon: Icon(Icons.title_rounded, color: const Color(0xFF4A148C)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFF4A148C), width: 2)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: _bodyController,
                      decoration: InputDecoration(
                        labelText: 'نص الإعلان',
                        prefixIcon: Icon(Icons.message_rounded, color: const Color(0xFF4A148C)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFF4A148C), width: 2)),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 5,
                      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // بطاقة المستهدفين
              if (!isSuperAdmin)
                _buildFormCard(
                  title: 'إرسال إلى',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF1565C0),
                  child: isSuperAdmin
                      ? _buildSuperAdminTargets()
                      : isTeacher
                          ? _buildTeacherTargets(user!)
                          : _buildAdminTargets(),
                ),
              if (isSuperAdmin) _buildSuperAdminTargets(),

              SizedBox(height: 24.h),

              // زر الإرسال
              Container(
                height: 56.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [BoxShadow(color: const Color(0xFF4A148C).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.r),
                    onTap: _isLoading ? null : _send,
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.send_rounded, color: Colors.white),
                                SizedBox(width: 10.w),
                                Text(
                                  isSuperAdmin ? 'إرسال للمدراء المشتركين' : 'إرسال الإعلان',
                                  style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16.r), topRight: Radius.circular(16.r)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Container(padding: EdgeInsets.all(6.w), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.r)), child: Icon(icon, color: Colors.white, size: 16.sp)),
                SizedBox(width: 10.w),
                Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(16.w), child: child),
        ],
      ),
    );
  }

  Widget _buildSuperAdminTargets() {
    return CheckboxListTile(
      title: const Text('إرسال لجميع مدراء المدارس (المشتركين)'),
      value: _sendToSubscribedManagers,
      onChanged: (v) => setState(() => _sendToSubscribedManagers = v ?? true),
      subtitle: const Text(
        'سيتم إرسال الإعلان كإشعار لجميع مدراء المدارس في النظام',
      ),
    );
  }

  Widget _buildTeacherTargets(User user) {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('جميع طلابي'),
          value: 'all',
          groupValue: _teacherTargetType,
          onChanged: (v) => setState(() => _teacherTargetType = v!),
        ),
        RadioListTile<String>(
          title: const Text('فصول محددة'),
          value: 'classes',
          groupValue: _teacherTargetType,
          onChanged: (v) => setState(() => _teacherTargetType = v!),
        ),
        if (_teacherTargetType == 'classes')
          Padding(
            padding: EdgeInsets.only(right: 32.w),
            child: _buildClassesSelector(user),
          ),
        RadioListTile<String>(
          title: const Text('طلاب محددين'),
          value: 'students',
          groupValue: _teacherTargetType,
          onChanged: (v) => setState(() => _teacherTargetType = v!),
        ),
        if (_teacherTargetType == 'students')
          Padding(
            padding: EdgeInsets.only(right: 32.w),
            child: _buildStudentsSelector(user),
          ),
      ],
    );
  }

  Widget _buildClassesSelector(User user) {
    final classesAsync = ref.watch(classesProvider);
    return classesAsync.when(
      data: (allClasses) {
        final teacherClasses = allClasses
            .where((c) => user.assignedClassIds?.contains(c.id) ?? false)
            .toList();
        return Wrap(
          spacing: 8.w,
          children: teacherClasses.map((cls) {
            final isSelected = _selectedClasses.any((c) => c.id == cls.id);
            return FilterChip(
              label: Text(cls.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedClasses.add(cls);
                  } else {
                    _selectedClasses.removeWhere((c) => c.id == cls.id);
                  }
                });
              },
            );
          }).toList(),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('خطأ في تحميل الفصول'),
    );
  }

  Widget _buildStudentsSelector(User user) {
    // Show a button to open dialog for selection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showStudentSelectionDialog(user),
          icon: const Icon(Icons.person_add),
          label: const Text('اختيار الطلاب'),
        ),
        if (_selectedStudents.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Wrap(
              spacing: 8.w,
              children: _selectedStudents
                  .map(
                    (s) => Chip(
                      label: Text(s.name),
                      onDeleted: () {
                        setState(() {
                          _selectedStudents.removeWhere((st) => st.id == s.id);
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _showStudentSelectionDialog(User user) async {
    final studentsAsync = ref.read(studentsProvider);
    // Filter students by teacher's classes
    final allStudents = studentsAsync.value ?? [];
    final myStudents = allStudents.where((s) {
      // Check if student is in any of teacher's classes
      // Note: Student has assignedClassIds (List), Teacher has assignedClassIds (List)
      // Intersection check
      if (s.assignedClassIds == null || user.assignedClassIds == null)
        return false;
      return s.assignedClassIds!.any(
        (cid) => user.assignedClassIds!.contains(cid),
      );
    }).toList();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار الطلاب'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: myStudents.length,
                  itemBuilder: (context, index) {
                    final student = myStudents[index];
                    final isSelected = _selectedStudents.any(
                      (s) => s.id == student.id,
                    );
                    return CheckboxListTile(
                      title: Text(student.name),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          setState(() {
                            if (val == true) {
                              _selectedStudents.add(student);
                            } else {
                              _selectedStudents.removeWhere(
                                (s) => s.id == student.id,
                              );
                            }
                          });
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('تم'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminTargets() {
    return Column(
      children: [
        OutlinedButton(
          onPressed: _toggleAdminAll,
          child: const Text('الجميع'),
        ),
        CheckboxListTile(
          title: const Text('الإداريين (بما فيهم المدير والوكلاء)'),
          value: _sendToAdministrative,
          onChanged: (v) => setState(() => _sendToAdministrative = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('المعلمين'),
          value: _sendToTeachers,
          onChanged: (v) => setState(() => _sendToTeachers = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('المرشدين'),
          value: _sendToCounselors,
          onChanged: (v) => setState(() => _sendToCounselors = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('الطلاب'),
          value: _sendToStudents,
          onChanged: (v) => setState(() => _sendToStudents = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('أولياء الأمور'),
          value: _sendToParents,
          onChanged: (v) => setState(() => _sendToParents = v ?? false),
        ),
      ],
    );
  }
}
