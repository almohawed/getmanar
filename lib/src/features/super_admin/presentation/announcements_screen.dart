import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendSystemAnnouncementToAllSchools')
          .call({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
      });
      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        _showSnack('تم إرسال الإعلان لجميع المدراء بنجاح ✅', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend(String title, String body) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendSystemAnnouncementToAllSchools')
          .call({'title': title, 'body': body});
      if (mounted) _showSnack('تمت إعادة الإرسال بنجاح ✅', Colors.green);
    } catch (e) {
      if (mounted) _showSnack('فشل إعادة الإرسال: $e', Colors.red);
    }
  }

  Future<void> _delete(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22.sp),
            SizedBox(width: 8.w),
            const Text('حذف الإعلان', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل تريد حذف هذا الإعلان نهائياً؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('SystemAnnouncements')
          .doc(docId)
          .delete();
      if (mounted) _showSnack('تم حذف الإعلان بنجاح', Colors.orange);
    } catch (e) {
      if (mounted) _showSnack('فشل الحذف: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إرسال إعلانات',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('إعلانات لجميع مدراء المدارس',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── Compose Form ─────────────────────────────────────
          Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2A4A), Color(0xFF0D1B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3949AB).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(Icons.campaign,
                            color: Colors.amber, size: 22.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إعلان جديد',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.sp)),
                          Text('سيصل لجميع مدراء المدارس',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11.sp)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),
                  _buildField(
                    controller: _titleController,
                    label: 'عنوان الإعلان',
                    icon: Icons.title,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'يرجى إدخال العنوان' : null,
                  ),
                  SizedBox(height: 12.h),
                  _buildField(
                    controller: _bodyController,
                    label: 'نص الإعلان',
                    icon: Icons.message,
                    maxLines: 4,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'يرجى إدخال النص' : null,
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3949AB),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r)),
                        elevation: 4,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 18.w,
                              height: 18.h,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.send, size: 18.sp),
                      label: Text(
                        _isLoading ? 'جاري الإرسال...' : 'إرسال للجميع',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Previous Announcements ───────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.white54, size: 16.sp),
                SizedBox(width: 8.w),
                Text('الإعلانات السابقة',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp)),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('SystemAnnouncements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined,
                            color: Colors.white24, size: 48.sp),
                        SizedBox(height: 12.h),
                        Text('لا توجد إعلانات سابقة',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14.sp)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final date =
                        (data['createdAt'] as Timestamp?)?.toDate();
                    final title = data['title'] as String? ?? '';
                    final body = data['body'] as String? ?? '';

                    return _buildAnnouncementCard(
                      docId: doc.id,
                      title: title,
                      body: body,
                      date: date,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF7986CB), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:
              const BorderSide(color: Color(0xFF3949AB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String docId,
    required String title,
    required String body,
    required DateTime? date,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3949AB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(Icons.campaign,
                      color: Colors.amber, size: 14.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              body,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                if (date != null) ...[
                  Icon(Icons.access_time,
                      color: Colors.white38, size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(date),
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11.sp),
                  ),
                ],
                const Spacer(),
                // Resend button
                _actionBtn(
                  icon: Icons.refresh,
                  color: const Color(0xFF42A5F5),
                  tooltip: 'إعادة إرسال',
                  onTap: () => _resend(title, body),
                ),
                SizedBox(width: 8.w),
                // Delete button
                _actionBtn(
                  icon: Icons.delete_outline,
                  color: Colors.red.shade400,
                  tooltip: 'حذف',
                  onTap: () => _delete(docId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(7.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 16.sp),
        ),
      ),
    );
  }
}
