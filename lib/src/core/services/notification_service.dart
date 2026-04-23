import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform
import 'package:hive_flutter/hive_flutter.dart';
import '../../../firebase_options.dart';
import '../data/offline_storage_service.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Hive and check settings
  if (!kIsWeb) {
    try {
      await OfflineStorageService().init();
      final box = Hive.box(kSettingsBox);
      final bool enabled = box.get('notifications_enabled', defaultValue: true);
      if (!enabled) {
        debugPrint(
          "Notifications disabled by user. Suppressing background message.",
        );
        return;
      }
    } catch (e) {
      debugPrint("Error checking notification settings in background: $e");
    }
  }

  // If you need to access other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");

  // If the message is data-only (no notification payload), we must show it manually
  if (message.notification == null) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Note: In background, we might not be able to handle callbacks, so we pass null/empty
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'main_channel_high_importance',
          'Main Channel',
          channelDescription: 'Main channel for app notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public, // Show on lock screen
          category: AndroidNotificationCategory.message,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Extract title/body from data if available
    final String title = message.data['title'] ?? 'New Notification';
    final String body = message.data['body'] ?? 'You have a new message';

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();

    // 2. Setup Local Notifications
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
              // Handle notification tap
            },
      );
    }

    // Request permissions for Android 13+ (Local)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    // 3. Setup Firebase Messaging (FCM)
    try {
      await _setupFCM();
    } catch (e) {
      debugPrint("FCM Setup Failed: $e");
    }
  }

  Future<void> _setupFCM() async {
    final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    Future<void> saveToken(String token) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final db = FirebaseFirestore.instance;
        final globalDoc =
            await db.collection('GlobalUsers').doc(user.uid).get();
        if (!globalDoc.exists) {
          debugPrint(
            "PROOF_LOG: GlobalUsers doc not found for ${user.uid}, cannot save token yet.",
          );
          return;
        }

        final data = globalDoc.data()!;
        final schoolId = data['schoolId'];
        final role = data['role'];

        if (schoolId == null || role == null) return;

        String collection = '';
        if ([
          'admin',
          'deputy',
          'principal',
          'manager',
          'school_admin',
        ].contains(role)) {
          collection = 'Staff';
        } else if (role == 'teacher') {
          collection = 'Teachers';
        } else if (role == 'student') {
          collection = 'Students';
        } else if (role == 'parent') {
          collection = 'Parents';
        }

        if (collection.isEmpty) {
          debugPrint("PROOF_LOG: Unknown role mapping for $role");
          return;
        }

        await db
            .collection('Schools')
            .doc(schoolId)
            .collection(collection)
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        debugPrint(
          "PROOF_LOG: FCM Token saved to Schools/$schoolId/$collection/${user.uid}",
        );
      } catch (e) {
        debugPrint("PROOF_LOG: Error saving FCM token: $e");
      }
    }

    // Request permission (iOS / Web / Android 13+)
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      return;
    }

    // Get Token
    try {
      String? token;
      if (kIsWeb) {
        // On Web, getToken requires a VAPID key. If not provided, it might fail.
        // We wrap it to prevent app crash.
        try {
          token = await firebaseMessaging.getToken(
            vapidKey: "YOUR_VAPID_KEY_HERE", // Add your VAPID Key for Web Push
          );
        } catch (e) {
          debugPrint("FCM Web Token Error: $e");
        }
      } else {
        token = await firebaseMessaging.getToken();
      }

      debugPrint("FCM Token: $token");

      if (token != null) {
        await saveToken(token);
      }
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }

    firebaseMessaging.onTokenRefresh.listen((token) async {
      await saveToken(token);
    });

    // Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );

        // Show as local notification
        showNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'No Title',
          body: message.notification?.body ?? 'No Body',
          payload: message.data['recordId'], // Example payload
        );
      }
    });

    // Background handler is set in main.dart usually, or we can ensure it's registered
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      // Local notifications on web require different setup or service worker.
      // For now, we skip showing local notification on web to prevent errors.
      debugPrint("Web Notification received: $title - $body");
      return;
    }

    const AndroidNotificationDetails
    androidNotificationDetails = AndroidNotificationDetails(
      'main_channel_high_importance', // Updated channel ID to ensure fresh settings
      'Main Channel',
      channelDescription: 'Main channel for app notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public, // Show on lock screen
      category: AndroidNotificationCategory.message,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
