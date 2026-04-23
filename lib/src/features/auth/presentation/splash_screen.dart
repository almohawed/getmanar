import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../data/pin_service.dart';
import 'auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;
  bool _isNavigating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('SplashScreen: initState');
    // Start safety timer to prevent infinite splash
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _isNavigating) return;

      final authState = ref.read(authStateProvider);
      authState.when(
        data: (user) {
          _navigateToNextScreen(user != null);
        },
        loading: () {
          _navigateToNextScreen(false);
        },
        error: (error, stack) {
          if (mounted) {
            setState(() {
              _errorMessage = "حدث خطأ أثناء التحقق من البيانات: $error";
            });
          }
        },
      );
    });

    // Initial check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuthCheck();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _initAuthCheck() async {
    // Artificial delay for branding (optional, keep it short)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Listen to auth state changes
    final authState = ref.read(authStateProvider);
    _handleAuthState(authState);
  }

  void _handleAuthState(AsyncValue<dynamic> authState) {
    if (_isNavigating) return;

    authState.when(
      data: (user) {
        _navigateToNextScreen(user != null);
      },
      loading: () {
        debugPrint('SplashScreen: Auth loading...');
        // Do nothing, wait for data
      },
      error: (error, stack) {
        debugPrint('SplashScreen: Auth error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = "حدث خطأ أثناء التحقق من البيانات: $error";
          });
        }
      },
    );
  }

  void _navigateToNextScreen(bool isLoggedIn) async {
    if (!mounted || _isNavigating) return;

    _isNavigating = true;
    _timeoutTimer?.cancel();

    final pinService = PinService();
    final hasPin = await pinService.hasPinSet();

    if (hasPin) {
      debugPrint('SplashScreen: PIN found, navigating to /pin-login');
      if (mounted) context.go('/pin-login');
      return;
    }

    debugPrint(
      'SplashScreen: Navigating to ${isLoggedIn ? '/dashboard' : '/login'}',
    );
    if (mounted) context.go(isLoggedIn ? '/dashboard' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to trigger navigation automatically
    ref.listen(authStateProvider, (previous, next) {
      _handleAuthState(next);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with error handling
              Image.asset(
                'images/mylogo.png',
                width: 150.w,
                height: 150.w,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('SplashScreen: Image load error: $error');
                  return Icon(Icons.school, size: 100.w, color: Colors.indigo);
                },
              ),
              SizedBox(height: 24.h),

              // App Name
              Text(
                'منار',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                  fontFamily: 'Cairo',
                ),
              ),

              SizedBox(height: 32.h),

              // Status Indicator
              if (_errorMessage != null)
                Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 40,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 14.sp),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isNavigating = false;
                        });
                        // Retry check
                        final refreshed = ref.refresh(
                          authStateProvider.notifier,
                        );
                        refreshed.build();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                const CircularProgressIndicator(color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}
