import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/academic/data/school_repository.dart';

class MasaratTracksScreen extends ConsumerStatefulWidget {
  const MasaratTracksScreen({super.key});

  @override
  ConsumerState<MasaratTracksScreen> createState() =>
      _MasaratTracksScreenState();
}

class _MasaratTracksScreenState extends ConsumerState<MasaratTracksScreen> {
  List<String> _tracks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _schoolId = '';
  final _newTrackController = TextEditingController();

  // المسارات الافتراضية الرسمية
  static const _defaultTracks = [
    'عام',
    'علوم الحاسب والهندسة',
    'صحي',
    'إدارة الأعمال',
    'شرعي',
  ];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _newTrackController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final user = ref.read(authStateProvider).value;
    _schoolId = user?.schoolId ?? '';
    if (_schoolId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(_schoolId)
          .get();
      final data = doc.data();
      final raw = data?['enabledTracks'];
      if (raw is List && raw.isNotEmpty) {
        _tracks = raw.map((e) => e.toString()).toList();
      } else {
        _tracks = List.from(_defaultTracks);
      }
    } catch (_) {
      _tracks = List.from(_defaultTracks);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (_schoolId.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(_schoolId)
          .update({'enabledTracks': _tracks});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('تم حفظ المسارات بنجاح ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addTrack() {
    final name = _newTrackController.text.trim();
    if (name.isEmpty) return;
    if (_tracks.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('هذا المسار موجود بالفعل'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _tracks.add(name);
      _newTrackController.clear();
    });
  }

  void _removeTrack(String track) {
    setState(() => _tracks.remove(track));
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تعيين المسارات'),
        content: const Text(
            'هل تريد إعادة تعيين المسارات إلى القائمة الرسمية الافتراضية؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _tracks = List.from(_defaultTracks));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة مسارات الثانوية',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp)),
            Text('إضافة وحذف المسارات الدراسية',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _resetToDefault,
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            icon: Icon(Icons.restore, size: 16.sp),
            label: Text('افتراضي', style: TextStyle(fontSize: 11.sp)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // Info banner
                Container(
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: const Color(0xFF42A5F5), size: 18.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'المسارات الخمسة الرسمية للثانوية العامة. يمكنك إضافة مسارات جديدة أو حذف المسارات غير المفعّلة في مدرستك.',
                          style: TextStyle(
                              color: const Color(0xFF42A5F5), fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tracks list
                Expanded(
                  child: _tracks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.route,
                                  color: Colors.white24, size: 48.sp),
                              SizedBox(height: 12.h),
                              Text('لا توجد مسارات',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 14.sp)),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: _tracks.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _tracks.removeAt(oldIndex);
                              _tracks.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (ctx, i) {
                            final track = _tracks[i];
                            final isDefault = _defaultTracks.contains(track);
                            return _buildTrackTile(track, i, isDefault);
                          },
                        ),
                ),

                // Add new track
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newTrackController,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _addTrack(),
                              decoration: InputDecoration(
                                hintText: 'اسم المسار الجديد...',
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                prefixIcon: const Icon(Icons.add_road,
                                    color: Colors.white38),
                                filled: true,
                                fillColor:
                                    Colors.white.withValues(alpha: 0.07),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton(
                            onPressed: _addTrack,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3949AB),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: Icon(Icons.add, size: 20.sp),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            elevation: 4,
                          ),
                          icon: _isSaving
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.h,
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.save, size: 18.sp),
                          label: Text(
                            _isSaving ? 'جاري الحفظ...' : 'حفظ المسارات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTrackTile(String track, int index, bool isDefault) {
    return Container(
      key: ValueKey(track),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDefault
              ? const Color(0xFF3949AB).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: const Color(0xFF3949AB).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                  color: const Color(0xFF7986CB),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp),
            ),
          ),
        ),
        title: Text(
          track,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp),
        ),
        subtitle: isDefault
            ? Text('مسار رسمي',
                style: TextStyle(
                    color: const Color(0xFF7986CB), fontSize: 10.sp))
            : Text('مسار مخصص',
                style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Icon(Icons.drag_handle, color: Colors.white24, size: 20.sp),
            SizedBox(width: 8.w),
            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade300, size: 18.sp),
              onPressed: () => _confirmDelete(track),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المسار'),
        content: Text('هل تريد حذف مسار "$track"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) _removeTrack(track);
  }
}
