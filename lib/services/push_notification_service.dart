import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:hrhb_frontend/data/app_prefs.dart';
import 'package:hrhb_frontend/firebase_options.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Requests permission, obtains an FCM token, and syncs it with the backend.
class PushNotificationService {
  PushNotificationService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  static final PushNotificationService instance = PushNotificationService();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  bool _initialized = false;
  bool _refreshListenerAttached = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _initialized = true;
    } catch (error, stack) {
      debugPrint('Firebase init failed: $error\n$stack');
    }
  }

  /// Call after the user has a valid session (home / family select).
  Future<void> registerCurrentDevice() async {
    if (kIsWeb) return;
    // Respect "질문 도착 알림" off — otherwise every launch re-registered.
    if (!await AppPrefs.notificationsEnabled()) return;
    await initialize();
    if (!_initialized) return;

    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('Push authorizationStatus=${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission denied');
        return;
      }
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('Push permission still notDetermined');
        return;
      }

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        // FCM token is only reliable after APNs token exists.
        String? apns = await messaging.getAPNSToken();
        for (var i = 0; i < 10 && (apns == null || apns.isEmpty); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await messaging.getAPNSToken();
        }
        debugPrint('APNs token ready=${apns != null && apns.isNotEmpty}');
        if (apns == null || apns.isEmpty) {
          debugPrint('APNs token missing; skip FCM register for now');
          return;
        }
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM token is null');
        return;
      }

      await _uploadToken(accessToken: accessToken, token: token);
      _attachRefreshListener();
    } catch (error, stack) {
      debugPrint('FCM register failed: $error\n$stack');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (kIsWeb) return;

    final token = await _tokenStorage.readFcmToken();
    final accessToken = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await _apiClient.deleteDeviceToken(
          accessToken: accessToken,
          token: token,
        );
      }
    } catch (error) {
      debugPrint('FCM unregister API failed: $error');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    await _tokenStorage.clearFcmToken();
  }

  void _attachRefreshListener() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (!await AppPrefs.notificationsEnabled()) return;
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      try {
        await _uploadToken(accessToken: accessToken, token: token);
      } catch (error) {
        debugPrint('FCM token refresh upload failed: $error');
      }
    });
  }

  Future<void> _uploadToken({
    required String accessToken,
    required String token,
  }) async {
    final platform = Platform.isIOS
        ? 'IOS'
        : Platform.isAndroid
            ? 'ANDROID'
            : 'UNKNOWN';
    await _apiClient.registerDeviceToken(
      accessToken: accessToken,
      token: token,
      platform: platform,
    );
    await _tokenStorage.saveFcmToken(token);
    debugPrint('FCM token registered ($platform)');
  }
}
