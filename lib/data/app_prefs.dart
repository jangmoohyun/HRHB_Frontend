import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hrhb_frontend/services/push_notification_service.dart';

/// Device-local preferences.
abstract final class AppPrefs {
  static const _storage = FlutterSecureStorage();
  static const _notifyKey = 'hrhb_notify_enabled';
  static const _fontKey = 'hrhb_font_size';

  /// Whether this device should receive pushes at all — true while any
  /// notification category is on. Defaults to on.
  static Future<bool> notificationsEnabled() async =>
      (await _storage.read(key: _notifyKey)) != 'false';

  /// Persists the master flag and actually registers or removes this
  /// device's push token (`/api/me/device-tokens`).
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final before = await notificationsEnabled();
    // Write first: registerCurrentDevice() checks this flag.
    await _storage.write(key: _notifyKey, value: enabled ? 'true' : 'false');
    if (before == enabled) return;
    if (enabled) {
      await PushNotificationService.instance.registerCurrentDevice();
    } else {
      await PushNotificationService.instance.unregisterCurrentDevice();
    }
  }

  /// 글자 크기: 0 작게 · 1 보통 · 2 크게 · 3 아주 크게.
  static final fontSize = ValueNotifier<int>(1);

  /// The prototype's `zoom` per 글자 크기 step.
  static const zooms = [0.92, 1.0, 1.1, 1.2];

  static double get zoom => zooms[fontSize.value];

  static Future<void> loadFontSize() async {
    final raw = int.tryParse(await _storage.read(key: _fontKey) ?? '');
    if (raw != null && raw >= 0 && raw < zooms.length) fontSize.value = raw;
  }

  static Future<void> setFontSize(int index) async {
    fontSize.value = index;
    await _storage.write(key: _fontKey, value: '$index');
  }
}
