import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the Android foreground service that keeps the app process alive
/// while a trip is active. Without this, Android terminates the Flutter
/// isolate when the user backgrounds the app, stopping all sensor writes and
/// killing the ML pipeline — meaning no unsafe detection and no notifications.
///
/// Usage:
///   await TripForegroundService.start();   // call when trip begins
///   await TripForegroundService.stop();    // call when trip ends
class TripForegroundService {
  TripForegroundService._();

  /// Call once at app startup (before runApp).
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sentinel360_trip',
        channelName: 'Active Trip',
        channelDescription:
            'Shown while Sentinel 360 is monitoring your trip.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts the foreground service and shows the persistent notification.
  /// Android will not kill the process while this service is running.
  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 360,
      notificationTitle: 'Trip in progress',
      notificationText: 'Sentinel 360 is monitoring your safety.',
      notificationIcon: null,
      callback: _foregroundCallback,
    );
    debugPrint('TripForegroundService: started');
  }

  /// Stops the foreground service and removes the persistent notification.
  static Future<void> stop() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
    debugPrint('TripForegroundService: stopped');
  }

  /// Updates the notification text (e.g. with elapsed time or risk level).
  static Future<void> updateNotification(String text) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Trip in progress',
      notificationText: text,
    );
  }
}

/// Top-level callback required by flutter_foreground_task.
/// The main Flutter isolate stays alive as long as this service runs —
/// all existing sensor streams and Firestore listeners continue working.
@pragma('vm:entry-point')
void _foregroundCallback() {
  // Nothing needed here. The service's job is solely to prevent Android
  // from killing the process. All real work happens in the main isolate.
}
