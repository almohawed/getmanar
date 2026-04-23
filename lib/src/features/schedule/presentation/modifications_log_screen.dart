import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../application/modification_tracking_service.dart';
import '../domain/schedule_modification.dart';
import 'modifications_timeline_screen.dart';
import 'modifications_analytics_screen.dart';

// 📝 شاشة سجل التعديلات - لوحة تحكم رئيسية
class ModificationsLogScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const ModificationsLogScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  ConsumerState<ModificationsLogScreen> createState() => _ModificationsLogScreenState();
}

class _ModificationsLogScreenState extends ConsumerState<ModificationsLogScreen> {
  List<ScheduleModification>? _modifications;
  ModificationStatistics? _statistics;
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(modificationTrackingServiceProvider);
      
      final modifications = await service.getModifications(
        schoolId: widget.schoolId,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        limit: 50,
      );

      final statistics = await service.calculateStatistics(
        schoolId: widget.schoolId,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      setState(() {
        _modifications = modifications;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 سجل التعديلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'الخط الزمني',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ModificationsTimelineScreen(
                    schoolId: widget.schoolId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'التحليلات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ModificationsAnalyticsScreen(
                    schoolId: widget.schoolId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'تصفية',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('حدث خطأ: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_modifications == null || _statistics == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    if (_modifications!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'لا توجد تعديلات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم إجراء أي تعديلات على الجدول',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_dateRange != null) _buildDateRangeChip(),
            _buildStatisticsCards(),
            const SizedBox(height: 16),
            _buildQuickStats(),
            const SizedBox(height: 16),
            _buildModificationsList(),
          ],
        ),
      ),
    );
  }

  // 📅 شريحة نطاق التاريخ
  Widget _buildDateRangeChip() {
    final formatter = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Chip(
        avatar: const Icon(Icons.date_range, size: 18),
        label: Text(
          'من ${formatter.format(_dateRange!.start)} إلى ${formatter.format(_dateRange!.end)}',
        ),
        onDeleted: () {
          setState(() {
            _dateRange = null;
          });
          _loadData();
        },
      ),
    );
  }

  // 📊 بطاقات الإحصائيات
  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '📝',
            'الإجمالي',
            '${_statistics!.totalModifications}',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '⚠️',
            'كبيرة',
            '${_statistics!.majorModifications}',
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '✅',
            'صغيرة',
            '${_statistics!.minorModifications}',
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📈 إحصائيات سريعة
  Widget _buildQuickStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 إحصائيات سريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickStatRow(
              'متوسط التأثير',
              _statistics!.averageImpact.toStringAsFixed(1),
              Icons.trending_up,
              Colors.orange,
            ),
            const Divider(),
            _buildQuickStatRow(
              'أكثر نوع تعديل',
              _getMostCommonType(),
              Icons.category,
              Colors.purple,
            ),
            const Divider(),
            _buildQuickStatRow(
              'أكثر معدّل نشاطاً',
              _getMostActiveModifier(),
              Icons.person,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📝 قائمة التعديلات
  Widget _buildModificationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '📝 آخر التعديلات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              'عرض ${_modifications!.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._modifications!.map((mod) => _buildModificationCard(mod)),
      ],
    );
  }

  Widget _buildModificationCard(ScheduleModification mod) {
    final typeColor = _getTypeColor(mod.type);
    final typeIcon = _getTypeIcon(mod.type);
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showModificationDetails(mod),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: typeColor.withOpacity(0.2),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mod.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بواسطة ${mod.modifierName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mod.isMajor)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'كبير',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    formatter.format(mod.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${mod.affectedTeachers.length} معلم',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.class_, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${mod.affectedClasses.length} صف',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 دوال مساعدة
  Color _getTypeColor(ModificationType type) {
    switch (type) {
      case ModificationType.scheduleReplacement:
        return Colors.red;
      case ModificationType.bulkEdit:
        return Colors.orange;
      case ModificationType.slotSwap:
      case ModificationType.slotMove:
        return Colors.blue;
      case ModificationType.teacherChange:
      case ModificationType.classChange:
        return Colors.purple;
      case ModificationType.slotAdd:
        return Colors.green;
      case ModificationType.slotRemove:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(ModificationType type) {
    switch (type) {
      case ModificationType.scheduleReplacement:
        return Icons.refresh;
      case ModificationType.bulkEdit:
        return Icons.edit_note;
      case ModificationType.slotSwap:
        return Icons.swap_horiz;
      case ModificationType.slotMove:
        return Icons.drive_file_move;
      case ModificationType.teacherChange:
        return Icons.person_outline;
      case ModificationType.classChange:
        return Icons.class_;
      case ModificationType.slotAdd:
        return Icons.add_circle_outline;
      case ModificationType.slotRemove:
        return Icons.remove_circle_outline;
      default:
        return Icons.edit;
    }
  }

  String _getMostCommonType() {
    if (_statistics!.byType.isEmpty) return 'لا يوجد';
    
    final sorted = _statistics!.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return _getTypeLabel(sorted.first.key);
  }

  String _getMostActiveModifier() {
    if (_statistics!.byModifier.isEmpty) return 'لا يوجد';
    
    final sorted = _statistics!.byModifier.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.first.key;
  }

  String _getTypeLabel(ModificationType type) {
    switch (type) {
      case ModificationType.slotSwap:
        return 'تبديل حصص';
      case ModificationType.slotMove:
        return 'نقل حصة';
      case ModificationType.teacherChange:
        return 'تغيير معلم';
      case ModificationType.classChange:
        return 'تغيير صف';
      case ModificationType.subjectChange:
        return 'تغيير مادة';
      case ModificationType.periodChange:
        return 'تغيير وقت';
      case ModificationType.dayChange:
        return 'تغيير يوم';
      case ModificationType.slotAdd:
        return 'إضافة حصة';
      case ModificationType.slotRemove:
        return 'حذف حصة';
      case ModificationType.scheduleReplacement:
        return 'استبدال الجدول';
      case ModificationType.bulkEdit:
        return 'تعديل جماعي';
      case ModificationType.other:
        return 'أخرى';
    }
  }

  // 🔧 دوال التفاعل
  void _showFilterDialog() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (result != null) {
      setState(() {
        _dateRange = result;
      });
      _loadData();
    }
  }

  void _showModificationDetails(ScheduleModification mod) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📝 ${mod.description}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('النوع', _getTypeLabel(mod.type)),
              _buildDetailRow('التاريخ', formatter.format(mod.timestamp)),
              _buildDetailRow('المعدّل', mod.modifierName),
              _buildDetailRow('التأثير', '${mod.impactScore}'),
              _buildDetailRow('معلمون متأثرون', '${mod.affectedTeachers.length}'),
              _buildDetailRow('صفوف متأثرة', '${mod.affectedClasses.length}'),
              if (mod.reason != null) ...[
                const Divider(),
                const Text('السبب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(mod.reason!),
              ],
              const Divider(),
              const Text('قبل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(mod.before.toString(), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text('بعد:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(mod.after.toString(), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
