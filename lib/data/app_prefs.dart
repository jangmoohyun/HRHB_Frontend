import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hrhb_frontend/services/push_notification_service.dart';

/// Device-local preferences.
abstract final class AppPrefs {
  static const _storage = FlutterSecureStorage();
  static const _notifyKey = 'hrhb_notify_enabled';

  /// "질문 도착 알림" — defaults to on.
  static Future<bool> notificationsEnabled() async =>
      (await _storage.read(key: _notifyKey)) != 'false';

  /// v1's toggle only changed on-screen state, so pushes kept arriving and the
  /// switch reset on reopen. Here it is persisted and actually registers or
  /// removes this device's push token (`/api/me/device-tokens`).
  static Future<void> setNotificationsEnabled(bool enabled) async {
    // Write first: registerCurrentDevice() checks this flag.
    await _storage.write(key: _notifyKey, value: enabled ? 'true' : 'false');
    if (enabled) {
      await PushNotificationService.instance.registerCurrentDevice();
    } else {
      await PushNotificationService.instance.unregisterCurrentDevice();
    }
  }
}
