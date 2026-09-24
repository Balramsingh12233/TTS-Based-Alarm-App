import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all essential permissions for reliable alarm execution
  static Future<bool> requestAlarmPermissions() async {
    try {
      // 1. Notification Permission (Required for Android 13+)
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. Exact Alarm Permission (Required for Android 12+)
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (!exactAlarmStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }

      // 3. Ignore Battery Optimizations (Required to avoid Doze mode delays)
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // 4. System Alert Window (Allows alarm popup over lock screen & other apps when awake)
      // This is the key permission for full-screen alarm on unlocked/awake screen
      final overlayStatus = await Permission.systemAlertWindow.status;
      if (!overlayStatus.isGranted) {
        await Permission.systemAlertWindow.request();
      }

      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if Battery Optimization is currently disabled
  static Future<bool> isBatteryOptimizationIgnored() async {
    return Permission.ignoreBatteryOptimizations.isGranted;
  }
}
