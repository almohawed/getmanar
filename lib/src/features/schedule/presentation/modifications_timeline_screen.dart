import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../application/modification_tracking_service.dart';
import '../domain/schedule_modification.dart';

// ⏱️ شاشة الخط الزمني للتعديلات
class ModificationsTimelineScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const ModificationsTimelineScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  ConsumerState<ModificationsTimelineScreen> createState() =>
      _ModificationsTimelineScreenState();
}

class _ModificationsTimelineScreenState
    extends ConsumerState<ModificationsTimelineScreen> {
  List<ScheduleModification>? _modifications;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModifications();
  }

  Future<void> _loadModifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(modificationTrackingServiceProvider);
      final modifications = await service.getModifications(
        schoolId: widget.schoolId,
        limit: 100,
      );

      setState(() {
        _modifications = modifications;
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
        title: const Text('⏱️ الخط الزمني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModifications,
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
              onPressed: _loadModifications,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_modifications == null || _modifications!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timeline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا توجد تعديلات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم إجراء أي تعديلات بعد',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // تجميع حسب التاريخ
    final grouped = _groupByDate(_modifications!);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return _buildDateGroup(entry.key, entry.value);
      },
    );
  }

  Map<String, List<ScheduleModification>> _groupByDate(
      List<ScheduleModification> modifications) {
    final Map<String, List<ScheduleModification>> grouped = {};
    final formatter = DateFormat('dd MMMM yyyy', 'ar');

    for (final mod in modifications) {
      final dateKey = formatter.format(mod.timestamp);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(mod);
    }

    return grouped;
  }

  Widget _buildDateGroup(String date, List<ScheduleModification> modifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text('${modifications.length}'),
                backgroundColor: Colors.blue[50],
              ),
            ],
          ),
        ),
        ...modifications.asMap().entries.map((entry) {
          final index = entry.key;
          final mod = entry.value;
          final isFirst = index == 0;
          final isLast = index == modifications.length - 1;
          return _buildTimelineTile(mod, isFirst, isLast);
        }),
      ],
    );
  }

  Widget _buildTimelineTile(
    ScheduleModification mod,
    bool isFirst,
    bool isLast,
  ) {
    final typeColor = _getTypeColor(mod.type);
    final typeIcon = _getTypeIcon(mod.type);
    final timeFormatter = DateFormat('HH:mm');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 60,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: typeColor.withOpacity(0.3),
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(typeIcon, color: Colors.white, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: typeColor.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(left: 16, bottom: 16),
              elevation: 2,
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
                          Text(
                            timeFormatter.format(mod.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (mod.isMajor)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                      const SizedBox(height: 8),
                      Text(
                        mod.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            mod.modifierName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.people, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${mod.affectedTeachers.length}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.class_, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${mod.affectedClasses.length}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              _buildDetailRow('التاريخ', formatter.format(mod.timestamp)),
              _buildDetailRow('المعدّل', mod.modifierName),
              _buildDetailRow('التأثير', '${mod.impactScore}'),
              _buildDetailRow('معلمون', '${mod.affectedTeachers.length}'),
              _buildDetailRow('صفوف', '${mod.affectedClasses.length}'),
              if (mod.reason != null) ...[
                const Divider(),
                const Text('السبب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(mod.reason!),
              ],
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
            width: 80,
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
