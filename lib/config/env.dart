import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config from `.env` (preferred) or `--dart-define` fallback.
///
/// Copy `.env.example` → `.env`, then:
///   flutter run -d DEVICE_ID
class Env {
  static String get kakaoNativeAppKey {
    final fromEnv = dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment(
      'KAKAO_NATIVE_APP_KEY',
      defaultValue: '',
    );
  }

  static String get apiBaseUrl {
    final fromEnv = dotenv.env['API_BASE_URL']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    );
  }

  static bool get hasKakaoKey =>
      kakaoNativeAppKey.isNotEmpty &&
      kakaoNativeAppKey != 'YOUR_KAKAO_NATIVE_APP_KEY';
}
