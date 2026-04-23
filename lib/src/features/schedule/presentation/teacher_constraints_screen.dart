import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

class TeacherConstraintsScreen extends ConsumerStatefulWidget {
  const TeacherConstraintsScreen({super.key});

  @override
  ConsumerState<TeacherConstraintsScreen> createState() => _TeacherConstraintsScreenState();
}

class _TeacherConstraintsScreenState extends ConsumerState<TeacherConstraintsScreen> {
  String? _schoolId;
  String? _selectedTeacherId;
  List<Map<String, dynamic>> _teachers = [];
  Map<String, Map<int, String>> _constraints = {}; // day -> {period -> preference}
  bool _isLoading = true;
  bool _isSaving = false;

  final _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final _periods = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _schoolId = user.schoolId;
      _isLoading = true;
    });

    try {
      // Load teachers
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/Teachers')
          .get();

      _teachers = teachersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'معلم',
          'specialization': data['specialization'] ?? 'غير محدد',
        };
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherConstraints(String teacherId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/TeacherConstraints')
          .doc(teacherId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final constraints = data['constraints'] as Map<String, dynamic>?;
        
        if (constraints != null) {
          _constraints = {};
          constraints.forEach((day, periods) {
            _constraints[day] = {};
            (periods as Map<String, dynamic>).forEach((period, preference) {
              _constraints[day]![int.parse(period)] = preference as String;
            });
          });
        } else {
          _constraints = {};
        }
      } else {
        _constraints = {};
      }

      setState(() {});
    } catch (e) {
      print('Error loading constraints: $e');
    }
  }

  Future<void> _saveConstraints() async {
    if (_selectedTeacherId == null) return;

    setState(() => _isSaving = true);

    try {
      // Convert constraints to Firestore format
      final constraintsData = <String, Map<String, String>>{};
      _constraints.forEach((day, periods) {
        constraintsData[day] = {};
        periods.forEach((period, preference) {
          constraintsData[day]![period.toString()] = preference;
        });
      });

      await FirebaseFirestore.instance
          .collection('Schools/$_schoolId/TeacherConstraints')
          .doc(_selectedTeacherId)
          .set({
        'teacherId': _selectedTeacherId,
        'teacherName': _teachers.firstWhere((t) => t['id'] == _selectedTeacherId)['name'],
        'constraints': constraintsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم حفظ القيود بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toggleConstraint(String day, int period) {
    if (!_constraints.containsKey(day)) {
      _constraints[day] = {};
    }

    final current = _constraints[day]![period];
    
    if (current == null) {
      _constraints[day]![period] = 'preferred'; // مرغوب
    } else if (current == 'preferred') {
      _constraints[day]![period] = 'avoided'; // غير مرغوب
    } else {
      _constraints[day]!.remove(period);
    }

    setState(() {});
  }

  Color _getCellColor(String day, int period) {
    final preference = _constraints[day]?[period];
    if (preference == 'preferred') {
      return Colors.green.shade100;
    } else if (preference == 'avoided') {
      return Colors.red.shade100;
    }
    return Colors.grey.shade50;
  }

  Color _getCellBorderColor(String day, int period) {
    final preference = _constraints[day]?[period];
    if (preference == 'preferred') {
      return Colors.green.shade400;
    } else if (preference == 'avoided') {
      return Colors.red.shade400;
    }
    return Colors.grey.shade300;
  }

  IconData? _getCellIcon(String day, int period) {
    final preference = _constraints[day]?[period];
    if (preference == 'preferred') {
      return Icons.check_circle;
    } else if (preference == 'avoided') {
      return Icons.cancel;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('القيود والتفضيلات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          if (_selectedTeacherId != null)
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.save),
              onPressed: _isSaving ? null : _saveConstraints,
              tooltip: 'حفظ',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildTeacherSelector(),
                if (_selectedTeacherId != null) ...[
                  _buildLegend(),
                  Expanded(child: _buildConstraintsTable()),
                ],
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.rule, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'إدارة قيود المعلمين',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'حدد الحصص المرغوبة والممنوعة لكل معلم',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSelector() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedTeacherId,
        decoration: InputDecoration(
          labelText: 'اختر المعلم',
          prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
          border: InputBorder.none,
        ),
        items: _teachers.map((teacher) {
          return DropdownMenuItem<String>(
            value: teacher['id'] as String,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(teacher['name'] as String),
                Text(
                  teacher['specialization'] as String,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedTeacherId = value;
            if (value != null) {
              _loadTeacherConstraints(value);
            }
          });
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Icons.check_circle, 'مرغوب', Colors.green),
          _buildLegendItem(Icons.cancel, 'غير مرغوب', Colors.red),
          _buildLegendItem(Icons.circle_outlined, 'عادي', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildConstraintsTable() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.deepPurple.shade50),
            dataRowHeight: 60,
            headingRowHeight: 50,
            columnSpacing: 20,
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: Text(
                  'الحصة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
              ),
              ..._days.map((day) => DataColumn(
                label: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
              )),
            ],
            rows: List.generate(_periods, (period) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${period + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                    ),
                  ),
                  ..._days.map((day) {
                    final icon = _getCellIcon(day, period);
                    return DataCell(
                      InkWell(
                        onTap: () => _toggleConstraint(day, period),
                        child: Container(
                          width: 80,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getCellColor(day, period),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getCellBorderColor(day, period),
                              width: 2,
                            ),
                          ),
                          child: icon != null
                              ? Icon(
                                  icon,
                                  color: icon == Icons.check_circle
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  size: 28,
                                )
                              : Center(
                                  child: Text(
                                    'اضغط',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
