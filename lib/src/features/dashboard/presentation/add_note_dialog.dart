import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/teacher_note_repository.dart';
import '../domain/teacher_note.dart';

class AddNoteDialog extends ConsumerStatefulWidget {
  final TeacherNote? noteToEdit;

  const AddNoteDialog({super.key, this.noteToEdit});

  @override
  ConsumerState<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends ConsumerState<AddNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.noteToEdit?.title);
    _contentController = TextEditingController(text: widget.noteToEdit?.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final repo = ref.read(teacherNoteRepositoryProvider);
      
      final note = TeacherNote(
        id: widget.noteToEdit?.id ?? const Uuid().v4(),
        teacherId: user.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: widget.noteToEdit?.createdAt ?? DateTime.now(),
        schoolId: user.schoolId,
      );

      if (widget.noteToEdit != null) {
        await repo.updateNote(note);
      } else {
        await repo.addNote(note);
      }

      if (mounted) {
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.noteToEdit != null ? 'تعديل المسودة' : 'إضافة مسودة جديدة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'يرجى إدخال العنوان' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'المحتوى',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'يرجى إدخال المحتوى' : null,
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('إلغاء'),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
