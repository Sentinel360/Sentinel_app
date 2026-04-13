import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles showing local notification banners on the device.
///
/// Used in two situations:
///   1. App is FOREGROUND — FCM doesn't auto-show banners on Android, so
///      onMessage calls [showSafetyCheck] to surface one manually.
///   2. App is BACKGROUND/KILLED — the OS shows the FCM notification
///      automatically (because sendSafetyPrompt sends a notification payload).
///      When the user taps it, the app opens and SafetyCheckListener takes over.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'sentinel360_safety';
  static const _channelName = 'Safety Alerts';
  static const _channelDesc =
      'Urgent safety check prompts during active trips.';

  /// Call once at app startup before runApp.
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Ensure the high-importance channel exists on Android 8+.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

    debugPrint('NotificationService: initialised');
  }

  /// Shows a safety check banner — used when FCM arrives while app is open.
  static Future<void> showSafetyCheck({
    required String title,
    required String body,
    required int attempt,
  }) async {
    await _local.show(
      // Use attempt as ID so repeated prompts update rather than stack.
      attempt,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Safety check',
          icon: '@mipmap/ic_launcher',
          // Auto-cancel so tapping it dismisses the banner.
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
