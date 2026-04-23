import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../data/teacher_note_repository.dart';
import '../domain/teacher_note.dart';
import 'add_note_dialog.dart';

// Provider for teacher drafts (behavior)
final teacherDraftsProvider = FutureProvider.autoDispose
    .family<List<BehaviorRecord>, String>((ref, teacherId) async {
      final repo = ref.watch(behaviorRepositoryProvider);
      return repo.getTeacherDrafts(teacherId);
    });

// Provider for teacher notes
final teacherNotesProvider = FutureProvider.autoDispose
    .family<List<TeacherNote>, String>((ref, teacherId) async {
      final repo = ref.watch(teacherNoteRepositoryProvider);
      final user = ref.watch(authStateProvider).value;
      return repo.getTeacherNotes(teacherId, schoolId: user?.schoolId);
    });

class TeacherDraftsScreen extends ConsumerWidget {
  const TeacherDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final teacherId = userAsync.value?.id ?? 'unknown_teacher';

    final draftsAsync = ref.watch(teacherDraftsProvider(teacherId));
    final notesAsync = ref.watch(teacherNotesProvider(teacherId));
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF607D8B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المسودات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('ملاحظات ومسودات السلوك المعلقة', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (_) => const AddNoteDialog(),
            );
            if (result == true) {
              ref.invalidate(teacherNotesProvider(teacherId));
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: Text('تدوين ملاحظة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        ),
      ),
      body: _buildBody(
        context,
        ref,
        draftsAsync,
        notesAsync,
        studentsAsync,
        teacherId,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BehaviorRecord>> draftsAsync,
    AsyncValue<List<TeacherNote>> notesAsync,
    AsyncValue<List<User>> studentsAsync,
    String teacherId,
  ) {
    if (draftsAsync.isLoading || notesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (draftsAsync.hasError) {
      return Center(child: Text('خطأ في تحميل المسودات: ${draftsAsync.error}'));
    }
    if (notesAsync.hasError) {
      return Center(child: Text('خطأ في تحميل الملاحظات: ${notesAsync.error}'));
    }

    final drafts = draftsAsync.value ?? [];
    final notes = notesAsync.value ?? [];

    if (drafts.isEmpty && notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF37474F).withOpacity(0.08), const Color(0xFF607D8B).withOpacity(0.04)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.drafts_outlined, size: 64.sp, color: const Color(0xFF546E7A)),
            ),
            SizedBox(height: 20.h),
            Text('لا توجد مسودات أو ملاحظات', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            SizedBox(height: 8.h),
            Text('اضغط على "تدوين ملاحظة" لإضافة ملاحظة جديدة', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Merge and sort by date descending
    final allItems = <dynamic>[...drafts, ...notes];
    allItems.sort((a, b) {
      final dateA = a is BehaviorRecord
          ? a.timestamp
          : (a as TeacherNote).createdAt;
      final dateB = b is BehaviorRecord
          ? b.timestamp
          : (b as TeacherNote).createdAt;
      return dateB.compareTo(dateA);
    });

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is BehaviorRecord) {
          return _buildBehaviorCard(
            context,
            ref,
            item,
            studentsAsync.value ?? [],
          );
        } else if (item is TeacherNote) {
          return _buildNoteCard(context, ref, item, teacherId);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    WidgetRef ref,
    TeacherNote note,
    String teacherId,
  ) {
    final dateFormat = intl.DateFormat('yyyy/MM/dd hh:mm a', 'en');

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeacherNoteViewScreen(note: note, teacherId: teacherId)),
          );
          ref.refresh(teacherNotesProvider(teacherId));
        },
        child: Column(
          children: [
            // رأس البطاقة
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(18.r), topRight: Radius.circular(18.r)),
                border: Border(bottom: BorderSide(color: Colors.amber.shade100)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.orange.shade600], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 18.sp),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(note.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.brown.shade800)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.amber.shade300)),
                    child: Text('مفكرة', style: TextStyle(color: Colors.brown.shade700, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            // المحتوى
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.grey.shade200)),
                    child: Text(note.content, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, height: 1.5)),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12.sp, color: Colors.grey.shade400),
                      SizedBox(width: 4.w),
                      Text(dateFormat.format(note.createdAt), style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                      const Spacer(),
                      _actionBtn(Icons.delete_outline_rounded, 'حذف', Colors.red.shade600, () => _deleteNote(context, ref, note.id, teacherId)),
                      SizedBox(width: 8.w),
                      _actionBtn(Icons.edit_rounded, 'تعديل', const Color(0xFF1565C0), () async {
                        final result = await showDialog<bool>(context: context, builder: (_) => AddNoteDialog(noteToEdit: note));
                        if (result == true) ref.refresh(teacherNotesProvider(teacherId));
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorCard(
    BuildContext context,
    WidgetRef ref,
    BehaviorRecord draft,
    List<User> students,
  ) {
    final studentName = _getStudentName(draft.studentId, students);
    final dateFormat = intl.DateFormat('yyyy/MM/dd hh:mm a', 'en');

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A237E).withOpacity(0.06), const Color(0xFF3949AB).withOpacity(0.02)],
                begin: Alignment.centerRight, end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(18.r), topRight: Radius.circular(18.r)),
              border: Border(bottom: BorderSide(color: Colors.indigo.shade50)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.grey.shade900)),
                      Text(dateFormat.format(draft.timestamp), style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text('مسودة سلوك', style: TextStyle(color: Colors.orange.shade800, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // المحتوى
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(draft.description, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, height: 1.5)),
                ),
                if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: Colors.blue.shade100)),
                    child: Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 12.sp, color: Colors.blue.shade600),
                        SizedBox(width: 6.w),
                        Expanded(child: Text('ملاحظات: ${draft.notes}', style: TextStyle(fontSize: 11.sp, color: Colors.blue.shade700, fontStyle: FontStyle.italic))),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionBtn(Icons.delete_outline_rounded, 'حذف', Colors.red.shade600, () => _deleteDraft(context, ref, draft.id)),
                    SizedBox(width: 8.w),
                    _actionBtn(Icons.edit_rounded, 'تعديل', const Color(0xFF1565C0), () => _editDraft(context, ref, draft)),
                    SizedBox(width: 8.w),
                    Material(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(10.r),
                      child: InkWell(
                        onTap: () => _sendDraft(context, ref, draft),
                        borderRadius: BorderRadius.circular(10.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 14.sp, color: Colors.white),
                              SizedBox(width: 5.w),
                              Text('اعتماد', style: TextStyle(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.r), border: Border.all(color: color.withOpacity(0.4))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.sp, color: color),
              SizedBox(width: 4.w),
              Text(label, style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  String _getStudentName(String studentId, List<User> students) {
    if (students.isEmpty) return 'جارٍ التحميل...';

    final student = students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => User(
        id: 'unknown',
        name: 'طالب غير معروف',
        email: '',
        role: UserRole.student,
      ),
    );
    return student.name;
  }

  Future<void> _deleteDraft(
    BuildContext context,
    WidgetRef ref,
    String draftId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسودة'),
        content: const Text('هل أنت متأكد من حذف هذه المسودة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(behaviorRepositoryProvider).deleteBehaviorRecord(draftId);
      ref.invalidate(teacherDraftsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف المسودة')));
      }
    }
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    String noteId,
    String teacherId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملاحظة'),
        content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = ref.read(authStateProvider).value;
      await ref
          .read(teacherNoteRepositoryProvider)
          .deleteNote(noteId, schoolId: user?.schoolId);
      // ignore: unused_result
      ref.invalidate(teacherNotesProvider(teacherId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الملاحظة')));
      }
    }
  }

  Future<void> _editDraft(
    BuildContext context,
    WidgetRef ref,
    BehaviorRecord draft,
  ) async {
    final notesController = TextEditingController(text: draft.notes);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الملاحظات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'الملاحظات',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, notesController.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedRecord = draft.copyWith(notes: result);
      final repo = ref.read(behaviorRepositoryProvider);
      await repo.updateBehaviorRecord(updatedRecord);
      ref.invalidate(teacherDraftsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظات')));
      }
    }
  }

  Future<void> _sendDraft(
    BuildContext context,
    WidgetRef ref,
    BehaviorRecord draft,
  ) async {
    // Determine new status based on logic
    // If it's negative behavior -> Pending (send to deputy)
    // If it's academic/notes -> Approved (send to student file)
    // BUT user said: "Send directly to deputy" if pressed "Send" in dialog.
    // So if we are here, we are "Sending".

    // We assume if it requires approval (negative behavior usually), it goes to pending.
    // If it's just notes (academic), it goes to approved.

    // Simplification: Check type.
    BehaviorStatus newStatus;
    String successMsg;

    if (draft.type == BehaviorType.negative &&
        (draft.notes == null || draft.notes!.isEmpty)) {
      // Pure negative behavior (Violation) -> Pending
      newStatus = BehaviorStatus.pending;
      successMsg = 'تم إرسال المخالفة للوكيل';
    } else {
      // Academic Note or other -> Approved
      newStatus = BehaviorStatus.approved;
      successMsg = 'تم اعتماد الملاحظة في ملف الطالب';
    }

    final updatedRecord = draft.copyWith(status: newStatus);

    final repo = ref.read(behaviorRepositoryProvider);
    await repo.updateBehaviorRecord(updatedRecord);

    ref.invalidate(teacherDraftsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMsg)));
    }
  }
}

class TeacherNoteViewScreen extends ConsumerStatefulWidget {
  final TeacherNote note;
  final String teacherId;

  const TeacherNoteViewScreen({
    super.key,
    required this.note,
    required this.teacherId,
  });

  @override
  ConsumerState<TeacherNoteViewScreen> createState() =>
      _TeacherNoteViewScreenState();
}

class _TeacherNoteViewScreenState extends ConsumerState<TeacherNoteViewScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveNote(showMessage: false);
    });
  }

  Future<void> _saveNote({bool showMessage = true}) async {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
    );

    await ref.read(teacherNoteRepositoryProvider).updateNote(updatedNote);
    // ignore: unused_result
    ref.invalidate(teacherNotesProvider(widget.teacherId));
    if (!mounted || !showMessage) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظة')));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = intl.DateFormat('yyyy/MM/dd hh:mm a', 'en');

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _saveNote(showMessage: false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مفكرة المعلم'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _saveNote(showMessage: false);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('حذف الملاحظة'),
                    content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          'حذف',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final user = ref.read(authStateProvider).value;
                  await ref
                      .read(teacherNoteRepositoryProvider)
                      .deleteNote(widget.note.id, schoolId: user?.schoolId);
                  // ignore: unused_result
                  ref.invalidate(teacherNotesProvider(widget.teacherId));
                  if (!mounted) return;
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                textAlign: TextAlign.right,
                onChanged: (_) => _scheduleAutoSave(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'عنوان المذكرة',
                ),
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  dateFormat.format(widget.note.createdAt),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _contentController,
                    textAlign: TextAlign.right,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => _scheduleAutoSave(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'اكتب ملاحظتك هنا...',
                    ),
                    style: TextStyle(fontSize: 18.sp, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
