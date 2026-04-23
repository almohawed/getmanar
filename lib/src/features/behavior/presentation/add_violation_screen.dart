import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../data/violation_data.dart';
import '../domain/models/behavior_violation_type.dart';
import '../domain/models/violation.dart';
import 'sent_violations_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/services/audit_service.dart';

class AddViolationScreen extends ConsumerStatefulWidget {
  const AddViolationScreen({super.key});

  @override
  ConsumerState<AddViolationScreen> createState() => _AddViolationScreenState();
}

class _AddViolationScreenState extends ConsumerState<AddViolationScreen>
    with SingleTickerProviderStateMixin {
  User? _selectedStudent;
  BehaviorViolationType? _selectedViolation;
  final TextEditingController _notesController = TextEditingController();
  late TabController _tabController;
  final List<int> _levels = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل مخالفة سلوكية'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildStudentSelector(),
          Expanded(
            child: _selectedStudent == null
                ? const Center(child: Text('الرجاء اختيار الطالب أولاً'))
                : _buildViolationSelector(),
          ),
          if (_selectedStudent != null && _selectedViolation != null)
            _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildStudentSelector() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الطالب', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          InkWell(
            onTap: () => _showStudentSearchDialog(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.grey.shade600),
                  SizedBox(width: 12.w),
                  Text(
                    _selectedStudent?.name ?? 'اختر الطالب...',
                    style: TextStyle(
                      color: _selectedStudent == null
                          ? Colors.grey
                          : Colors.black,
                      fontSize: 16.sp,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationSelector() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.red.shade800,
            unselectedLabelColor: Colors.grey,
            isScrollable: true,
            tabs: _levels.map((l) => Tab(text: 'المستوى $l')).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _levels
                .map((level) => _buildViolationList(level))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildViolationList(int level) {
    final violations = predefinedViolations
        .where((v) => v.level == level)
        .toList();
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: violations.length,
      itemBuilder: (context, index) {
        final violation = violations[index];
        final isSelected = _selectedViolation == violation;
        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: isSelected
                ? BorderSide(color: Colors.red.shade800, width: 2)
                : BorderSide.none,
          ),
          margin: EdgeInsets.only(bottom: 12.h),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedViolation = violation;
              });
            },
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.text,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'خصم: ${violation.deduction} درجات',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Colors.red.shade800),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitViolation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'تسجيل المخالفة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => SelectStudentDialog(
        onStudentSelected: (student) {
          setState(() {
            _selectedStudent = student;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _submitViolation() async {
    if (_selectedStudent == null || _selectedViolation == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    // 1. Calculate Escalation (Mock Logic)
    // In a real app, we would query Firestore for previous violations of this type
    // and decide whether to issue a Warning, Pledge, or Committee referral.
    // For now, we'll assume "Warning" for Level 1-3, "Pledge" for 4, "Committee" for 5.
    String actionTaken = 'إنذار شفهي';
    if (_selectedViolation!.level == 4) actionTaken = 'تعهد خطي';
    if (_selectedViolation!.level == 5)
      actionTaken = 'إحالة للجنة التوجيه الطلابي';

    final violation = Violation(
      id: const Uuid().v4(),
      studentId: _selectedStudent!.id, // Store ID, not name
      teacherId: currentUser.id,
      type: _mapLevelToType(_selectedViolation!.level),
      description: _selectedViolation!.text,
      timestamp: DateTime.now(),
      status: ViolationStatus.active, // Auto-approved since Deputy created it
      pointsDeducted: _selectedViolation!.deduction,
    );

    // 2. Save to Provider/Firestore
    ref.read(sentViolationsProvider.notifier).addViolation(violation);

    // 3. Log Audit
    ref
        .read(auditServiceProvider)
        .logAction(
          action: 'create_violation',
          description: 'Deputy created violation for ${_selectedStudent!.name}',
          metadata: {
            'violation_text': _selectedViolation!.text,
            'level': _selectedViolation!.level,
            'student_id': _selectedStudent!.id,
            'action_taken': actionTaken,
          },
        );

    // 4. Show Success & Close
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تسجيل المخالفة بنجاح: $actionTaken'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  ViolationType _mapLevelToType(int level) {
    if (level <= 2) return ViolationType.minor;
    if (level <= 4) return ViolationType.moderate;
    return ViolationType.major;
  }
}

class SelectStudentDialog extends ConsumerStatefulWidget {
  final Function(User) onStudentSelected;

  const SelectStudentDialog({super.key, required this.onStudentSelected});

  @override
  ConsumerState<SelectStudentDialog> createState() =>
      _SelectStudentDialogState();
}

class _SelectStudentDialogState extends ConsumerState<SelectStudentDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allStudentsAsync = ref.watch(studentsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: 500.h),
        child: Column(
          children: [
            Text(
              'اختر الطالب',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث عن طالب',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: allStudentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('خطأ: $e')),
                data: (students) {
                  final filtered = students
                      .where(
                        (s) =>
                            s.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            s.identityNumber?.contains(_searchQuery) == true,
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('لا يوجد نتائج'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            student.name.isNotEmpty ? student.name[0] : '?',
                          ),
                        ),
                        title: Text(student.name),
                        subtitle: Text(
                          student.identityNumber ?? 'بدون اسم مستخدم',
                        ),
                        onTap: () => widget.onStudentSelected(student),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
