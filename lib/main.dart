import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/services/notification_service.dart';
import 'src/core/utils/reloader.dart';
import 'src/core/data/offline_storage_service.dart'; // Import Offline Service
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  // Cache Buster: 2026-04-18-22:30:00
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
        final message = details.exceptionAsString();
        if (kIsWeb &&
            message.contains('FIRESTORE') &&
            message.contains('INTERNAL ASSERTION FAILED: Unexpected state')) {
          reloadApp();
        }
      };

      // Initialize Offline Storage (Hive) first
      final offlineService = OfflineStorageService();
      try {
        await offlineService.init();
      } catch (e) {
        debugPrint('Failed to initialize offline storage: $e');
      }

      // Initialize Date Formatting
      try {
        await initializeDateFormatting('ar', null);
        timeago.setLocaleMessages('ar', timeago.ArMessages());
        timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());
        timeago.setLocaleMessages('en', timeago.EnMessages());
        timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
      } catch (e) {
        debugPrint('Failed to initialize date formatting: $e');
      }

      bool firebaseInitialized = false;
      String? firebaseError;

      // Initialize Firebase with timeout to prevent hanging
      try {
        if (kIsWeb) {
          // Short timeout for web to detect misconfiguration quickly
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 10));
        } else {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        firebaseInitialized = true;
        debugPrint('Firebase initialized successfully');

        // Initialize App Check
        const kRecaptchaSiteKey = '6LdJf2osAAAAAFBtDqC9hJ5WoZ0jFE4ZkyNiwSZN';

        try {
          if (kDebugMode) {
            // Debug Mode: Use Debug Providers to avoid ReCaptcha issues on localhost/emulators
            await FirebaseAppCheck.instance.activate(
              androidProvider: AndroidProvider.debug,
              appleProvider: AppleProvider.debug,
              // For Web Debug: You must add "localhost" to your ReCaptcha allowed domains
              // OR use a Debug Token in your browser console (self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;)
              webProvider: ReCaptchaV3Provider(kRecaptchaSiteKey),
            );
          } else {
            // Production Mode
            await FirebaseAppCheck.instance.activate(
              androidProvider: AndroidProvider.playIntegrity,
              appleProvider: AppleProvider.deviceCheck,
              webProvider: ReCaptchaV3Provider(kRecaptchaSiteKey),
            );
          }
          debugPrint('Firebase App Check activated');
        } catch (e) {
          debugPrint('Firebase App Check activation failed (Non-critical): $e');
        }
      } catch (e) {
        debugPrint('Firebase initialization failed or timed out: $e');
        firebaseError = e.toString();
      }

      // Initialize Notification Service (FCM + Local) only if Firebase is ready
      if (firebaseInitialized) {
        try {
          // Fire and forget or short timeout
          // Use a safe wrapper to prevent app crash
          NotificationService()
              .init()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  debugPrint("NotificationService init timed out - skipping");
                },
              )
              .catchError((e) {
                debugPrint("NotificationService init failed: $e");
              });
        } catch (e) {
          debugPrint("NotificationService init error: $e");
        }
      }

      // Custom Error Widget to prevent Red Screen of Death
      ErrorWidget.builder = (FlutterErrorDetails details) {
        // في production mode، لا نعرض أي شيء
        if (kReleaseMode) {
          return const SizedBox.shrink();
        }
        
        // في debug mode فقط، نعرض التفاصيل
        return Material(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "خطأ في التطوير",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: Text(
                        details.exception.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        reloadApp();
                      },
                      child: const Text('تحديث الصفحة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      };

      if (!firebaseInitialized) {
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                      const SizedBox(height: 20),
                      const Text(
                        'فشل الاتصال بالخادم',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'يرجى التحقق من اتصال الإنترنت.\n${kDebugMode ? firebaseError : ""}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          reloadApp();
                        },
                        child: const Text('حاول مرة أخرى'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // Remove loader even if failed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (kIsWeb) reloadApp();
        });
        return;
      }

      // Remove web loading indicator immediately after runApp to ensure it doesn't hang
      // (web-only, no-op on iOS/Android)

      runApp(
        ProviderScope(
          overrides: [offlineStorageProvider.overrideWithValue(offlineService)],
          child: const ManarApp(),
        ),
      );
    },
    (error, stack) {
      final message = error.toString();
      debugPrint('Global Error Caught: $message');
      debugPrint(stack.toString());
      if (kIsWeb &&
          message.contains('FIRESTORE') &&
          message.contains('INTERNAL ASSERTION FAILED: Unexpected state')) {
        reloadApp();
      }
    },
  );
}

// Helper to run code safely without crashing
void runSafe(Function action) {
  try {
    action();
  } catch (e) {
    debugPrint("Safe execution failed: $e");
  }
}
