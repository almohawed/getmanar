import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../academic/domain/classroom.dart';
import '../../academic/data/school_repository.dart';
import '../../../core/domain/models/school.dart';
import '../data/mock_class_repository.dart';
import '../data/firestore_class_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class AddClassScreen extends ConsumerStatefulWidget {
  final Classroom? classToEdit;
  const AddClassScreen({super.key, this.classToEdit});

  @override
  ConsumerState<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends ConsumerState<AddClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  String? _secondaryProgramType;
  String? _secondaryTrack;
  int? _masaratGradeLevel;
  int _masaratSectionNumber = 1;
  String? _masaratTrack;
  bool _isLoading = false;
  bool _useBulkBuilder = true;
  bool _secondaryConfigInitialized = false;
  String _schoolSecondaryStructure = 'shared_year_then_tracks';
  String _schoolSecondaryProgramType = 'masarat';
  final Set<String> _schoolEnabledTracks = <String>{};
  bool _isSavingSecondaryConfig = false;

  int _bulkGradeLevel = 10;
  int _bulkStartSectionNumber = 1;
  int _bulkSharedCount = 3;
  final Set<String> _bulkSelectedTracks = <String>{};
  final Map<String, int> _bulkCountByTrack = <String, int>{};
  String _bulkDistribution = 'round_robin';
  bool _isBulkSubmitting = false;

  bool get _isEditing => widget.classToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_maybeSyncGradeFromName);
    if (_isEditing) {
      final c = widget.classToEdit!;
      _nameController.text = c.name;
      _gradeController.text = c.gradeLevel.toString();
      _secondaryProgramType = c.secondaryProgramType;
      _secondaryTrack = c.secondaryTrack;
      _masaratGradeLevel = c.gradeLevel >= 10 ? c.gradeLevel : null;
      _masaratSectionNumber = c.sectionNumber ?? 1;
      _masaratTrack = c.secondaryTrack;
      _useBulkBuilder = false;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_maybeSyncGradeFromName);
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  void _maybeSyncGradeFromName() {
    final name = _nameController.text.trim();
    final parsed = _parseGradeFromClassName(name);
    if (parsed == null) return;
    final current = int.tryParse(_gradeController.text.trim());
    if (current == null || current <= 0) {
      _gradeController.text = '$parsed';
    }
  }

  int? _parseGradeFromClassName(String name) {
    var s = name.trim();
    if (s.isEmpty) return null;
    s = s
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    final code = RegExp(r'^([123])(\d{2})$').firstMatch(s);
    if (code != null) {
      final d = int.tryParse(code.group(1) ?? '');
      if (d != null && d >= 1 && d <= 3) return d + 9;
    }
    final match = RegExp(r'(\d{1,2})').firstMatch(s);
    if (match == null) return null;
    final g = int.tryParse(match.group(1) ?? '');
    if (g == null || g <= 0 || g > 12) return null;
    return g;
  }

  String _masaratTrackLabelAr(String key) {
    switch (key.trim()) {
      case 'general':
        return 'العام';
      case 'computer_engineering':
        return 'علوم الحاسب والهندسة';
      case 'health_life':
        return 'الصحة والحياة';
      case 'business':
        return 'إدارة الأعمال';
      case 'sharia':
        return 'الشرعي';
      default:
        return key.isEmpty ? 'مسار' : key;
    }
  }

  String _arabicSectionLetter(int n) {
    const letters = <String>[
      'أ',
      'ب',
      'ج',
      'د',
      'هـ',
      'و',
      'ز',
      'ح',
      'ط',
      'ي',
      'ك',
      'ل',
      'م',
      'ن',
      'س',
      'ع',
      'ف',
      'ص',
      'ق',
      'ر',
      'ش',
      'ت',
      'ث',
      'خ',
      'ذ',
      'ض',
      'ظ',
      'غ',
    ];
    if (n <= 0) return '';
    if (n <= letters.length) return letters[n - 1];
    return '$n';
  }

  String _masaratNameCode(int gradeLevel, int sectionNumber) {
    final digit = gradeLevel == 10 ? 1 : (gradeLevel == 11 ? 2 : 3);
    final s = sectionNumber.clamp(1, 99).toString().padLeft(2, '0');
    return '$digit$s';
  }

  String _masaratDisplayName({
    required int gradeLevel,
    required int sectionNumber,
    required String? track,
  }) {
    if (gradeLevel == 10) {
      return 'مسار مشترك $sectionNumber';
    }
    final t = (track ?? '').trim();
    final label = t.isEmpty ? 'مسار' : _masaratTrackLabelAr(t);
    final letter = _arabicSectionLetter(sectionNumber);
    return letter.isEmpty ? label : '$label ($letter)';
  }

  List<String> _defaultMasaratTrackKeys() {
    return const <String>[
      'general',
      'computer_engineering',
      'health_life',
      'business',
      'sharia',
    ];
  }

  List<_PlannedMasaratClass> _buildBulkPlan(School? school) {
    final g = _bulkGradeLevel;
    final start = _bulkStartSectionNumber.clamp(1, 99);
    if (g == 10) {
      final count = _bulkSharedCount.clamp(1, 99);
      return List<_PlannedMasaratClass>.generate(count, (i) {
        final section = (start + i).clamp(1, 99);
        final code = _masaratNameCode(g, section);
        final display = _masaratDisplayName(
          gradeLevel: g,
          sectionNumber: section,
          track: null,
        );
        return _PlannedMasaratClass(
          gradeLevel: g,
          sectionNumber: section,
          track: null,
          nameCode: code,
          displayName: display,
          secondaryPhase: 'shared',
        );
      });
    }

    final trackKeys = (school?.enabledTracks.isNotEmpty == true)
        ? school!.enabledTracks
        : _defaultMasaratTrackKeys();
    final selected = _bulkSelectedTracks
        .where((t) => trackKeys.contains(t))
        .toList();
    selected.sort();

    final tasks = <String, int>{};
    for (final t in selected) {
      final c = _bulkCountByTrack[t] ?? 0;
      if (c > 0) tasks[t] = c.clamp(1, 99);
    }
    if (tasks.isEmpty) return const <_PlannedMasaratClass>[];

    final plan = <_PlannedMasaratClass>[];
    var nextSection = start;

    if (_bulkDistribution == 'grouped') {
      for (final t in tasks.keys) {
        final count = tasks[t]!;
        for (var i = 0; i < count; i++) {
          final section = nextSection.clamp(1, 99);
          final code = _masaratNameCode(g, section);
          final display = _masaratDisplayName(
            gradeLevel: g,
            sectionNumber: section,
            track: t,
          );
          plan.add(
            _PlannedMasaratClass(
              gradeLevel: g,
              sectionNumber: section,
              track: t,
              nameCode: code,
              displayName: display,
              secondaryPhase: 'specialized',
            ),
          );
          nextSection++;
        }
      }
      return plan;
    }

    final remaining = <String, int>{...tasks};
    while (remaining.isNotEmpty) {
      final keys = remaining.keys.toList()..sort();
      var didAdd = false;
      for (final t in keys) {
        final left = remaining[t] ?? 0;
        if (left <= 0) {
          remaining.remove(t);
          continue;
        }
        final section = nextSection.clamp(1, 99);
        final code = _masaratNameCode(g, section);
        final display = _masaratDisplayName(
          gradeLevel: g,
          sectionNumber: section,
          track: t,
        );
        plan.add(
          _PlannedMasaratClass(
            gradeLevel: g,
            sectionNumber: section,
            track: t,
            nameCode: code,
            displayName: display,
            secondaryPhase: 'specialized',
          ),
        );
        remaining[t] = left - 1;
        if (remaining[t] == 0) remaining.remove(t);
        nextSection++;
        didAdd = true;
      }
      if (!didAdd) break;
    }
    return plan;
  }

  Future<void> _saveSecondaryConfig({required String schoolId}) async {
    setState(() => _isSavingSecondaryConfig = true);
    try {
      final repo = ref.read(schoolRepositoryProvider);
      final enabledTracks = _schoolEnabledTracks.toList()..sort();
      await repo.updateSecondaryConfig(
        schoolId,
        secondaryProgramType: _schoolSecondaryProgramType,
        secondaryStructure: _schoolSecondaryStructure,
        enabledTracks: enabledTracks,
      );
      ref.invalidate(schoolProvider(schoolId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الثانوي')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حفظ الإعدادات: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingSecondaryConfig = false);
    }
  }

  Future<void> _submitBulk({
    required bool isSchoolMode,
    required String schoolId,
    required School? school,
  }) async {
    if (_isBulkSubmitting) return;

    final plan = _buildBulkPlan(school);
    if (plan.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار الإعدادات لإضافة الشعب')),
        );
      }
      return;
    }

    final classes = plan
        .map(
          (p) => Classroom(
            id: const Uuid().v4(),
            name: p.nameCode,
            nameCode: p.nameCode,
            displayName: p.displayName,
            gradeLevel: p.gradeLevel,
            studentIds: const <String>[],
            secondaryProgramType: 'masarat',
            secondaryTrack: p.track,
            secondaryPhase: p.secondaryPhase,
            sectionNumber: p.sectionNumber,
          ),
        )
        .toList();

    setState(() => _isBulkSubmitting = true);
    try {
      if (isSchoolMode) {
        final repo = ref.read(firestoreClassRepositoryProvider);
        await repo.addClassesBatch(schoolId, classes);
      } else {
        final repo = ref.read(mockClassRepositoryProvider);
        await repo.addClassesBatch(classes);
      }
      ref.invalidate(classesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة ${classes.length} شعبة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBulkSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateProvider).value;
      final isSchoolMode =
          currentUser != null && (currentUser.schoolId?.isNotEmpty ?? false);

      String? inheritedProgram;
      School? school;
      if (isSchoolMode) {
        try {
          final repo = ref.read(schoolRepositoryProvider);
          final sid = currentUser.schoolId;
          if (sid != null && sid.isNotEmpty) {
            school = await repo.getSchool(sid);
            inheritedProgram = school?.secondaryProgramType;
          }
        } catch (_) {}
      }

      final effectiveProgram = (_secondaryProgramType ?? '').trim().isEmpty
          ? inheritedProgram
          : _secondaryProgramType;
      final isMasaratSecondary =
          effectiveProgram == 'masarat' &&
          ((school?.stage ?? '').contains('ثانوي') ||
              (_isEditing && widget.classToEdit!.gradeLevel >= 10));

      Classroom newClass;
      if (isMasaratSecondary) {
        final g = _masaratGradeLevel ?? 10;
        final section = _masaratSectionNumber.clamp(1, 99);
        final track = (g >= 11) ? (_masaratTrack ?? '').trim() : '';
        final code = _masaratNameCode(g, section);
        final display = _masaratDisplayName(
          gradeLevel: g,
          sectionNumber: section,
          track: track.isEmpty ? null : track,
        );
        newClass = Classroom(
          id: _isEditing ? widget.classToEdit!.id : const Uuid().v4(),
          name: code,
          nameCode: code,
          displayName: display,
          gradeLevel: g,
          studentIds: _isEditing ? widget.classToEdit!.studentIds : [],
          secondaryProgramType: 'masarat',
          secondaryTrack: g == 10 ? null : (track.isEmpty ? null : track),
          secondaryPhase: g == 10 ? 'shared' : 'specialized',
          sectionNumber: section,
        );
      } else {
        final gradeFromName = _parseGradeFromClassName(_nameController.text);
        final gradeFromField = int.parse(_gradeController.text.trim());
        final grade = gradeFromName ?? gradeFromField;
        if (gradeFromName != null && gradeFromName != gradeFromField) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تصحيح الصف تلقائياً من $gradeFromField إلى $gradeFromName بناءً على اسم الفصل',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        final allowTrack = grade >= 10 && effectiveProgram == 'masarat';
        final finalTrack =
            allowTrack && (_secondaryTrack ?? '').trim().isNotEmpty
            ? _secondaryTrack!.trim()
            : null;
        newClass = Classroom(
          id: _isEditing ? widget.classToEdit!.id : const Uuid().v4(),
          name: _nameController.text.trim(),
          gradeLevel: grade,
          studentIds: _isEditing ? widget.classToEdit!.studentIds : [],
          secondaryProgramType: (_secondaryProgramType ?? '').trim().isEmpty
              ? null
              : _secondaryProgramType!.trim(),
          secondaryTrack: finalTrack,
        );
      }

      if (isSchoolMode) {
        final repo = ref.read(firestoreClassRepositoryProvider);
        if (_isEditing) {
          await repo.updateClass(currentUser.schoolId!, newClass);
        } else {
          await repo.addClass(currentUser.schoolId!, newClass);
        }
      } else {
        final repo = ref.read(mockClassRepositoryProvider);
        if (_isEditing) {
          await repo.updateClass(newClass);
        } else {
          await repo.addClass(newClass);
        }
      }

      ref.invalidate(classesProvider); // Refresh list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'تم تحديث الفصل بنجاح' : 'تم إضافة الفصل بنجاح',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grade = int.tryParse(_gradeController.text.trim());
    final schoolId = ref.read(authStateProvider).value?.schoolId ?? '';
    final school = schoolId.isEmpty
        ? null
        : ref.watch(schoolProvider(schoolId)).value;
    final inheritedProgram = school?.secondaryProgramType;
    final effectiveProgram = (_secondaryProgramType ?? '').trim().isEmpty
        ? inheritedProgram
        : _secondaryProgramType;
    final showTrack =
        (grade != null && grade >= 10) && effectiveProgram == 'masarat';
    final isMasaratSecondary =
        effectiveProgram == 'masarat' &&
        ((school?.stage ?? '').contains('ثانوي') ||
            (grade != null && grade >= 10) ||
            (_isEditing && widget.classToEdit!.gradeLevel >= 10));
    final isSecondarySchool = (school?.stage ?? '').contains('ثانوي');
    final isSchoolMode = schoolId.isNotEmpty;

    if (!_secondaryConfigInitialized && isSecondarySchool && school != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _schoolSecondaryProgramType =
              (school.secondaryProgramType ?? 'masarat').trim().isEmpty
              ? 'masarat'
              : school.secondaryProgramType!.trim();
          _schoolSecondaryStructure =
              (school.secondaryStructure ?? '').trim().isEmpty
              ? 'shared_year_then_tracks'
              : school.secondaryStructure!.trim();
          _schoolEnabledTracks
            ..clear()
            ..addAll(
              school.enabledTracks.isNotEmpty
                  ? school.enabledTracks
                  : _defaultMasaratTrackKeys(),
            );
          _secondaryConfigInitialized = true;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل بيانات الفصل' : 'إضافة فصل جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMasaratSecondary) ...[
                if (!_isEditing && isSecondarySchool && isSchoolMode) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'إعدادات الثانوي (مسارات)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _schoolSecondaryStructure,
                            decoration: const InputDecoration(
                              labelText: 'بنية الثانوي',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_tree),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'shared_year_then_tracks',
                                child: Text('سنة مشتركة ثم مسارات'),
                              ),
                              DropdownMenuItem(
                                value: 'tracks_only',
                                child: Text('مسارات فقط (بدون سنة مشتركة)'),
                              ),
                            ],
                            onChanged: _isSavingSecondaryConfig
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(
                                      () => _schoolSecondaryStructure = v,
                                    );
                                  },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'المسارات المفعّلة:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (_defaultMasaratTrackKeys()).map((k) {
                              final selected = _schoolEnabledTracks.contains(k);
                              return FilterChip(
                                label: Text(_masaratTrackLabelAr(k)),
                                selected: selected,
                                onSelected: _isSavingSecondaryConfig
                                    ? null
                                    : (on) {
                                        setState(() {
                                          if (on) {
                                            _schoolEnabledTracks.add(k);
                                          } else {
                                            _schoolEnabledTracks.remove(k);
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _isSavingSecondaryConfig
                                ? null
                                : () =>
                                      _saveSecondaryConfig(schoolId: schoolId),
                            child: _isSavingSecondaryConfig
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('حفظ الإعدادات'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_isEditing) ...[
                  SwitchListTile(
                    value: _useBulkBuilder,
                    onChanged: (v) => setState(() => _useBulkBuilder = v),
                    title: const Text('الإضافة السريعة للشعب'),
                    subtitle: const Text(
                      'توليد أكواد 101/201 تلقائياً مع أسماء عرض واضحة',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_isEditing && _useBulkBuilder) ...[
                  DropdownButtonFormField<int>(
                    value: _bulkGradeLevel,
                    decoration: const InputDecoration(
                      labelText: 'السنة الدراسية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 (مشترك)')),
                      DropdownMenuItem(value: 11, child: Text('11 (تخصصي)')),
                      DropdownMenuItem(value: 12, child: Text('12 (تخصصي)')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _bulkGradeLevel = v;
                        if (v == 10) {
                          _bulkSelectedTracks.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '$_bulkStartSectionNumber',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رقم الشعبة البداية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      setState(
                        () => _bulkStartSectionNumber = parsed.clamp(1, 99),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_bulkGradeLevel == 10) ...[
                    TextFormField(
                      initialValue: '$_bulkSharedCount',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد الشعب (مشترك)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v.trim());
                        if (parsed == null) return;
                        setState(() => _bulkSharedCount = parsed.clamp(1, 99));
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      'اختر المسارات ثم أدخل عدد الشعب لكل مسار:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ((school?.enabledTracks.isNotEmpty == true)
                                  ? school!.enabledTracks
                                  : _defaultMasaratTrackKeys())
                              .map((k) {
                                final selected = _bulkSelectedTracks.contains(
                                  k,
                                );
                                return FilterChip(
                                  label: Text(_masaratTrackLabelAr(k)),
                                  selected: selected,
                                  onSelected: (on) {
                                    setState(() {
                                      if (on) {
                                        _bulkSelectedTracks.add(k);
                                        _bulkCountByTrack.putIfAbsent(
                                          k,
                                          () => 1,
                                        );
                                      } else {
                                        _bulkSelectedTracks.remove(k);
                                        _bulkCountByTrack.remove(k);
                                      }
                                    });
                                  },
                                );
                              })
                              .toList(),
                    ),
                    const SizedBox(height: 12),
                    ...(_bulkSelectedTracks.toList()..sort()).map((k) {
                      final current = _bulkCountByTrack[k] ?? 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          initialValue: '$current',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'عدد شعب ${_masaratTrackLabelAr(k)}',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.list_alt),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v.trim());
                            if (parsed == null) return;
                            setState(
                              () => _bulkCountByTrack[k] = parsed.clamp(1, 99),
                            );
                          },
                        ),
                      );
                    }),
                    DropdownButtonFormField<String>(
                      value: _bulkDistribution,
                      decoration: const InputDecoration(
                        labelText: 'طريقة توزيع الترقيم',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shuffle),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'round_robin',
                          child: Text('تدوير بين المسارات'),
                        ),
                        DropdownMenuItem(
                          value: 'grouped',
                          child: Text('تجميع كل مسار معاً'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _bulkDistribution = v);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Builder(
                    builder: (context) {
                      final plan = _buildBulkPlan(school);
                      if (plan.isEmpty) return const SizedBox.shrink();
                      final preview = plan.take(12).toList();
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'معاينة (${plan.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...preview.map((p) {
                                final trackLabel =
                                    (p.track ?? '').trim().isEmpty
                                    ? ''
                                    : ' • ${_masaratTrackLabelAr(p.track!)}';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${p.nameCode} — ${p.displayName}$trackLabel',
                                  ),
                                );
                              }),
                              if (plan.length > preview.length)
                                Text('... +${plan.length - preview.length}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isBulkSubmitting
                        ? null
                        : () => _submitBulk(
                            isSchoolMode: isSchoolMode,
                            schoolId: schoolId,
                            school: school,
                          ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isBulkSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('إضافة الشعب'),
                  ),
                ] else ...[
                  DropdownButtonFormField<int>(
                    value: _masaratGradeLevel,
                    decoration: const InputDecoration(
                      labelText: 'السنة الدراسية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 (مشترك)')),
                      DropdownMenuItem(value: 11, child: Text('11 (تخصصي)')),
                      DropdownMenuItem(value: 12, child: Text('12 (تخصصي)')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _masaratGradeLevel = v;
                        if (v == 10) _masaratTrack = null;
                      });
                    },
                    validator: (v) =>
                        v == null ? 'يرجى اختيار السنة الدراسية' : null,
                  ),
                  const SizedBox(height: 16),
                  if ((_masaratGradeLevel ?? 0) >= 11) ...[
                    DropdownButtonFormField<String>(
                      value: _masaratTrack,
                      decoration: const InputDecoration(
                        labelText: 'المسار',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree),
                      ),
                      items:
                          (school?.enabledTracks.isNotEmpty == true
                                  ? school!.enabledTracks
                                  : const <String>[
                                      'general',
                                      'computer_engineering',
                                      'health_life',
                                      'business',
                                      'sharia',
                                    ])
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(_masaratTrackLabelAr(k)),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _masaratTrack = v),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'يرجى اختيار المسار'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    initialValue: '$_masaratSectionNumber',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رقم الشعبة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      setState(
                        () => _masaratSectionNumber = parsed.clamp(1, 99),
                      );
                    },
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'يرجى إدخال رقم صحيح';
                      if (n <= 0) return 'يرجى إدخال رقم أكبر من صفر';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final g = _masaratGradeLevel;
                      if (g == null) return const SizedBox.shrink();
                      final code = _masaratNameCode(g, _masaratSectionNumber);
                      final display = _masaratDisplayName(
                        gradeLevel: g,
                        sectionNumber: _masaratSectionNumber,
                        track: _masaratTrack,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            initialValue: code,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'nameCode',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.code),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: display,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'displayName',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ] else ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الفصل (مثال: 1/1)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'يرجى إدخال اسم الفصل'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gradeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الصف الدراسي (رقم)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'يرجى إدخال الصف';
                    if (int.tryParse(value) == null)
                      return 'يجب إدخال رقم صحيح';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (!isMasaratSecondary) ...[
                DropdownButtonFormField<String?>(
                  value: _secondaryProgramType,
                  decoration: const InputDecoration(
                    labelText: 'نظام الثانوي (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.route),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('توريث من المدرسة'),
                    ),
                    DropdownMenuItem(value: 'general', child: Text('عام')),
                    DropdownMenuItem(value: 'masarat', child: Text('مسارات')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _secondaryProgramType = v;
                      if (v != 'masarat') _secondaryTrack = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (showTrack)
                  DropdownButtonFormField<String?>(
                    value: _secondaryTrack,
                    decoration: const InputDecoration(
                      labelText: 'مسار الثانوي',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_tree),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('غير محدد')),
                      DropdownMenuItem(value: 'general', child: Text('العام')),
                      DropdownMenuItem(
                        value: 'computer_engineering',
                        child: Text('علوم الحاسب والهندسة'),
                      ),
                      DropdownMenuItem(
                        value: 'health_life',
                        child: Text('الصحة والحياة'),
                      ),
                      DropdownMenuItem(
                        value: 'business',
                        child: Text('إدارة الأعمال'),
                      ),
                      DropdownMenuItem(value: 'sharia', child: Text('الشرعي')),
                    ],
                    onChanged: (v) => setState(() => _secondaryTrack = v),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة الفصل'),
                ),
              ] else if (_isEditing || !_useBulkBuilder) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة الشعبة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannedMasaratClass {
  final int gradeLevel;
  final int sectionNumber;
  final String? track;
  final String nameCode;
  final String displayName;
  final String secondaryPhase;

  const _PlannedMasaratClass({
    required this.gradeLevel,
    required this.sectionNumber,
    required this.track,
    required this.nameCode,
    required this.displayName,
    required this.secondaryPhase,
  });
}
