import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendSystemAnnouncementToAllSchools',
      );
      await callable.call({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الإعلان لجميع المدراء بنجاح')),
        );
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إرسال إعلان للمدارس - نسخة جديدة'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اكتب رسالة ستظهر لجميع مدراء المدارس في لوحة تحكمهم',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإعلان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'يرجى إدخال العنوان'
                    : null,
              ),
              SizedBox(height: 15.h),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'نص الإعلان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 5,
                validator: (value) =>
                    value == null || value.isEmpty ? 'يرجى إدخال النص' : null,
              ),
              SizedBox(height: 30.h),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendAnnouncement,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'جاري الإرسال...' : 'إرسال للجميع'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 20.h),
              const Divider(),
              Text(
                'الإعلانات السابقة',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('SystemAnnouncements')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد إعلانات سابقة'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final date = (data['createdAt'] as Timestamp?)
                            ?.toDate();

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 6.h),
                          child: ListTile(
                            title: Text(data['title'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['body'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (date != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      '${date.day}/${date.month}/${date.year} '
                                      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  tooltip: 'إعادة إرسال',
                                  onPressed: () async {
                                    final title =
                                        (data['title'] as String?) ?? '';
                                    final body =
                                        (data['body'] as String?) ?? '';
                                    if (title.isEmpty || body.isEmpty) return;
                                    try {
                                      final callable = FirebaseFunctions
                                          .instance
                                          .httpsCallable(
                                            'sendSystemAnnouncementToAllSchools',
                                          );
                                      await callable.call({
                                        'title': title,
                                        'body': body,
                                      });
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'تمت إعادة إرسال الإعلان لجميع المدراء',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'فشل إعادة الإرسال: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.refresh),
                                  color: Colors.indigo,
                                ),
                                IconButton(
                                  tooltip: 'حذف الإعلان',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) {
                                        return AlertDialog(
                                          title: const Text('حذف الإعلان'),
                                          content: const Text(
                                            'سيتم حذف الإعلان من قائمة الإعلانات النظامية ولن يظهر في لوحات المدراء. هل أنت متأكد؟',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('إلغاء'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'حذف',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('SystemAnnouncements')
                                          .doc(doc.id)
                                          .delete();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم حذف الإعلان بنجاح'),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('فشل حذف الإعلان: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
