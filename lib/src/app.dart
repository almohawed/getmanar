import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router.dart';
import 'core/providers/locale_provider.dart';
import 'features/notifications/presentation/notification_listener_widget.dart';
import 'core/data/sync_service.dart';
import 'core/presentation/session_timeout_manager.dart';
import 'core/presentation/app_lock_gate.dart';

class ManarApp extends ConsumerWidget {
  const ManarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize Sync Service
    ref.watch(syncServiceProvider);
    // Watch locale
    final locale = ref.watch(localeProvider);
    final isAr = locale.languageCode == 'ar';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Smart design size: Use mobile design for narrow screens, desktop for wide
        Size designSize;
        if (constraints.maxWidth < 600) {
          designSize = const Size(375, 812);
        } else if (constraints.maxWidth < 1100) {
          designSize = const Size(834, 1194); // Tablet
        } else {
          designSize = const Size(1440, 900); // Desktop
        }

        return ScreenUtilInit(
          designSize: designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp.router(
              builder: (context, widget) {
                // Ensure proper scaling and directionality
                final wrappedWidget = NotificationListenerWidget(
                  child: widget!,
                );
                return SessionTimeoutManager(
                  child: AppLockGate(child: wrappedWidget),
                );
              },
              title: 'منصة منار - تنظيم السلوك والتعليم',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Colors.white,
                cardTheme: CardThemeData(
                  elevation: 3,
                  shadowColor: Colors.black.withOpacity(0.08),
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 0,
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF006064),
                  primary: const Color(0xFF006064),
                  surface: Colors.white,
                ),
                textTheme: GoogleFonts.cairoTextTheme(
                  Theme.of(context).textTheme,
                ),
                useMaterial3: true,
              ),
              // RTL/LTR Support
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('ar', 'SA'),
                Locale('en', 'US'),
              ],
              locale: locale,
              routerConfig: router,
            );
          },
        );
      },
    );
  }
}
