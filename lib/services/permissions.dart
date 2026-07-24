import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests the permissions real alarms need on Android:
///   * POST_NOTIFICATIONS (Android 13+) — to show the alarm notification.
///   * SCHEDULE_EXACT_ALARM (Android 12) — to fire at the exact minute. On
///     Android 13+ this is granted automatically via USE_EXACT_ALARM.
///
/// Safe to call at startup; it only prompts for what isn't already granted.
class AlarmPermissions {
  static Future<void> ensure() async {
    if (!Platform.isAndroid) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }
}
