import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'config/env.dart';
import 'screens/loading/loading_screen.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  await PushNotificationService.instance.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HrhbApp());
}

class HrhbApp extends StatelessWidget {
  const HrhbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하루한번',
      debugShowCheckedModeBanner: false,
      theme: buildHaruTheme(),
      home: const LoadingScreen(),
    );
  }
}
