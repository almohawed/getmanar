import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../domain/announcement.dart';

class CreateAnnouncementDialog extends StatefulWidget {
  final Function(Announcement) onSave;
  final String? creatorName;

  const CreateAnnouncementDialog({
    super.key,
    required this.onSave,
    this.creatorName,
  });

  @override
  State<CreateAnnouncementDialog> createState() => _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<CreateAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  TargetAudience _audience = TargetAudience.all;
  AnnouncementType _type = AnnouncementType.general;
  String _content = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 600.w,
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إنشاء إعلان جديد',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                _buildTextField(
                  label: 'عنوان الإعلان',
                  hint: 'مثال: فعالية يوم اللغة العربية',
                  onSaved: (v) => _title = v ?? '',
                  validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<TargetAudience>(
                        label: 'الفئة المستهدفة',
                        value: _audience,
                        items: TargetAudience.values,
                        onChanged: (v) => setState(() => _audience = v!),
                        itemLabel: (v) => Announcement.getAudienceLabel(v),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildDropdown<AnnouncementType>(
                        label: 'نوع الإعلان',
                        value: _type,
                        items: AnnouncementType.values,
                        onChanged: (v) => setState(() => _type = v!),
                        itemLabel: (v) => Announcement.getTypeLabel(v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _buildTextField(
                  label: 'محتوى الإعلان',
                  hint: 'اكتب تفاصيل الإعلان هنا...',
                  maxLines: 5,
                  onSaved: (v) => _content = v ?? '',
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          
                          final newAnnouncement = Announcement(
                            id: const Uuid().v4(),
                            title: _title,
                            content: _content,
                            targetAudience: _audience,
                            type: _type,
                            status: AnnouncementStatus.active,
                            publishDate: DateTime.now(),
                            viewCount: 0,
                            creatorName: (widget.creatorName ?? '').trim(),
                          );

                          widget.onSave(newAnnouncement);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      icon: const Icon(Icons.campaign, color: Colors.white),
                      label: const Text('نشر الإعلان', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
        SizedBox(height: 8.h),
        TextFormField(
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
          maxLines: maxLines,
          onSaved: onSaved,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
        SizedBox(height: 8.h),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
        ),
      ],
    );
  }
}
