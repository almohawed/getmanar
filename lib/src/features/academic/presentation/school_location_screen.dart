import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/location_service.dart';
import '../../subscription/domain/subscription_logic.dart';
import '../../subscription/presentation/subscription_plans_screen.dart';
import '../data/school_repository.dart';

class SchoolLocationScreen extends ConsumerStatefulWidget {
  const SchoolLocationScreen({super.key});

  @override
  ConsumerState<SchoolLocationScreen> createState() =>
      _SchoolLocationScreenState();
}

class _SchoolLocationScreenState extends ConsumerState<SchoolLocationScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    // In a real app, we'd get the current school ID from auth/state
    final school = await ref.read(schoolRepositoryProvider).getSchool('school_1');
    if (school != null && school.latitude != null && school.longitude != null) {
      _latController.text = school.latitude.toString();
      _lngController.text = school.longitude.toString();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final hasPermission = await locationService.requestPermission();
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى منح صلاحية الموقع')),
          );
        }
        return;
      }

      final position = await locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e')),
        );
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _saveLocation() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال إحداثيات صحيحة')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(schoolRepositoryProvider).updateSchoolLocation(
        'school_1', // Mock school ID
        lat,
        lng,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ موقع المدرسة بنجاح'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check Feature Access
    final hasAccess = ref.watch(
      featureAccessProvider(AppFeature.geofenceArrival),
    );

    if (!hasAccess) {
      return _buildUpgradeView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تحديد موقع المدرسة')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.location_on,
              size: 80.sp,
              color: Colors.indigo,
            ),
            SizedBox(height: 16.h),
            Text(
              'إحداثيات المدرسة',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'قم بتحديد موقع المدرسة بدقة لتفعيل نظام التتبع الجغرافي لأولياء الأمور.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'خط العرض (Latitude)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'خط الطول (Longitude)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 24.h),
            OutlinedButton.icon(
              onPressed: _isLocating ? null : _getCurrentLocation,
              icon: _isLocating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('استخدام موقعي الحالي'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ الإحداثيات'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeView() {
    return Scaffold(
      appBar: AppBar(title: const Text('ميزة حصرية')),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 100.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 24.h),
            Text(
              'هذه الميزة غير متوفرة في باقتك الحالية',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'للحصول على خدمة التتبع الجغرافي وتنبيهات الوصول الذكية، يرجى ترقية باقتك إلى "التميز" (Elite).',
              style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPlansScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF6C00),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              ),
              child: const Text('ترقية الباقة الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
