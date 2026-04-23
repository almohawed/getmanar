import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/behavior_data_service.dart';

/// شاشة إدارة الحالات السلوكية
class BehavioralCasesScreen extends StatefulWidget {
  const BehavioralCasesScreen({super.key});

  @override
  State<BehavioralCasesScreen> createState() => _BehavioralCasesScreenState();
}

class _BehavioralCasesScreenState extends State<BehavioralCasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Stream للحالات النشطة
  Stream<List<Map<String, dynamic>>> get _activeCasesStream =>
      FirebaseFirestore.instance
          .collection('behavioral_cases')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snap) {
            final docs = snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();
            docs.sort((a, b) {
              final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });
            return docs;
          });

  // Stream للحالات المغلقة
  Stream<List<Map<String, dynamic>>> get _closedCasesStream =>
      FirebaseFirestore.instance
          .collection('behavioral_cases')
          .where('status', isEqualTo: 'closed')
          .snapshots()
          .map((snap) {
            final docs = snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();
            docs.sort((a, b) {
              final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });
            return docs;
          });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // الشريط العلوي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade600, Colors.deepOrange.shade700],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const Expanded(
                  child: Text(
                    'الحالات السلوكية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // التبويبات - تعتمد على StreamBuilder لعدد الحالات
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _activeCasesStream,
            builder: (context, activeSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _closedCasesStream,
                builder: (context, closedSnap) {
                  final activeCount = activeSnap.data?.length ?? 0;
                  final closedCount = closedSnap.data?.length ?? 0;
                  return Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.deepOrange.shade600,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepOrange.shade600,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.pending_actions, size: 20),
                              const SizedBox(width: 8),
                              Text('النشطة ($activeCount)'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text('المغلقة ($closedCount)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // المحتوى
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // تبويب الحالات النشطة
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _activeCasesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}'));
                    }
                    final cases = snapshot.data ?? [];
                    if (cases.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا توجد حالات نشطة حالياً'),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cases.length,
                      itemBuilder: (context, index) =>
                          _buildCaseCard(cases[index], isActive: true),
                    );
                  },
                ),

                // تبويب الحالات المغلقة
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _closedCasesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}'));
                    }
                    final cases = snapshot.data ?? [];
                    if (cases.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.archive, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا توجد حالات مغلقة'),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cases.length,
                      itemBuilder: (context, index) =>
                          _buildCaseCard(cases[index], isActive: false),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCaseDialog(),
        backgroundColor: Colors.deepOrange.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> caseData, {required bool isActive}) {
    final priority = caseData['priority'] ?? 'متوسط';
    final studentName = caseData['studentName'] ?? 'غير محدد';
    final caseType = caseData['caseType'] ?? 'غير محدد';
    final description = caseData['description'] ?? '';
    final createdAt = (caseData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final assignedTo = caseData['assignedTo'] ?? 'غير محدد';

    Color priorityColor;
    IconData priorityIcon;
    
    switch (priority) {
      case 'عالي':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'متوسط':
        priorityColor = Colors.orange;
        priorityIcon = Icons.remove;
        break;
      case 'منخفض':
        priorityColor = Colors.green;
        priorityIcon = Icons.low_priority;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(priorityIcon, color: priorityColor, size: 20),
        ),
        title: Text(
          studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caseType, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(createdAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: isActive
            ? PopupMenuButton<String>(
                onSelected: (value) => _handleCaseAction(caseData, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16),
                        SizedBox(width: 8),
                        Text('إغلاق الحالة'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : const Icon(Icons.archive, color: Colors.grey),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  const Text(
                    'الوصف:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                ],
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المسؤول:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(assignedTo, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تاريخ الإنشاء:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(DateFormat('dd/MM/yyyy - HH:mm').format(createdAt), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (isActive) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _addFollowUp(caseData),
                    icon: const Icon(Icons.add_comment, size: 16),
                    label: const Text('إضافة متابعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCaseDialog() {
    final studentNameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'متوسط';
    String selectedType = 'سلوكي';
    String assignedTo = 'المرشد الطلابي';
    bool isSubmitting = false;
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إنشاء حالة سلوكية جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: studentNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطالب',
                    hintText: 'أدخل اسم الطالب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الحالة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'سلوكي', child: Text('سلوكي')),
                    DropdownMenuItem(value: 'أكاديمي', child: Text('أكاديمي')),
                    DropdownMenuItem(value: 'اجتماعي', child: Text('اجتماعي')),
                    DropdownMenuItem(value: 'نفسي', child: Text('نفسي')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'الأولوية',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'منخفض', child: Text('منخفض')),
                    DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                    DropdownMenuItem(value: 'عالي', child: Text('عالي')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedPriority = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'وصف الحالة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'المسؤول',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'المرشد الطلابي', child: Text('المرشد الطلابي')),
                    DropdownMenuItem(value: 'وكيل الطلاب', child: Text('وكيل الطلاب')),
                    DropdownMenuItem(value: 'مدير المدرسة', child: Text('مدير المدرسة')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => assignedTo = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (studentNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(outerContext).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال اسم الطالب')),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await BehaviorDataService.addBehavioralCase(
                          studentName: studentNameController.text.trim(),
                          studentId: '',
                          caseType: selectedType,
                          priority: selectedPriority,
                          description: descriptionController.text.trim(),
                          assignedTo: assignedTo,
                          studentGrade: '',
                          studentClass: '',
                        );
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(outerContext).showSnackBar(
                          const SnackBar(
                            content: Text('تم إنشاء الحالة بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(outerContext).showSnackBar(
                          SnackBar(content: Text('خطأ: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade600,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCaseAction(Map<String, dynamic> caseData, String action) {
    switch (action) {
      case 'edit':
        _editCase(caseData);
        break;
      case 'close':
        _closeCase(caseData);
        break;
      case 'delete':
        _deleteCase(caseData);
        break;
    }
  }

  void _editCase(Map<String, dynamic> caseData) {
    // TODO: تنفيذ تعديل الحالة
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ تعديل الحالة قريباً')),
    );
  }

  Future<void> _closeCase(Map<String, dynamic> caseData) async {
    final reasonController = TextEditingController();
    final outerContext = context;
    
    final confirmed = await showDialog<bool>(
      context: outerContext,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد من إغلاق هذه الحالة؟'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإغلاق',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BehaviorDataService.closeBehavioralCase(
          caseData['id'],
          reasonController.text.trim().isEmpty ? 'تم الحل' : reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            const SnackBar(
              content: Text('تم إغلاق الحالة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          // الانتقال تلقائياً لتبويب المغلقة
          _tabController.animateTo(1);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            SnackBar(content: Text('خطأ في إغلاق الحالة: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCase(Map<String, dynamic> caseData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحالة'),
        content: const Text('هل أنت متأكد من حذف هذه الحالة؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('behavioral_cases')
            .doc(caseData['id'])
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحالة بنجاح')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حذف الحالة: $e')),
        );
      }
    }
  }

  void _addFollowUp(Map<String, dynamic> caseData) {
    final followUpController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة متابعة'),
        content: TextField(
          controller: followUpController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'نص المتابعة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (followUpController.text.trim().isNotEmpty) {
                try {
                  // استخدام الخدمة المركزية لإضافة المتابعة
                  await BehaviorDataService.addCaseFollowUp(
                    caseData['id'],
                    followUpController.text.trim(),
                    'المستخدم الحالي', // TODO: استخدام المستخدم الحقيقي
                  );

                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة المتابعة بنجاح')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في إضافة المتابعة: $e')),
                  );
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _viewCaseDetails(Map<String, dynamic> caseData) {
    // TODO: تنفيذ عرض تفاصيل الحالة
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ عرض التفاصيل قريباً')),
    );
  }
}