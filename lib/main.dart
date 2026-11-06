import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'config/env.dart';
import 'screens/loading/loading_screen.dart';
import 'services/app_settings.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  await PushNotificationService.instance.initialize();
  await AppSettings.instance.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HrhbApp());
}

bool _isAuthCallbackRoute(String name) {
  return name.contains('code=') ||
      name.contains('error=') ||
      name.startsWith('/?') ||
      name.startsWith('kakao');
}

Route<dynamic> _noopRoute(RouteSettings settings) {
  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    },
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

class HrhbApp extends StatefulWidget {
  const HrhbApp({super.key});

  @override
  State<HrhbApp> createState() => _HrhbAppState();
}

class _HrhbAppState extends State<HrhbApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하루한번',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A6A3F),
          surface: const Color(0xFFFDFBF0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF0),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final system = mq.textScaler.scale(14) / 14.0;
        final factor = system * AppSettings.instance.textScaleFactor;
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(factor.clamp(1.0, 1.45)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LoadingScreen(),
      // Kakao OAuth redirect arrives as "/?code=..." and is not an app route.
      // Swallow it so WidgetsApp doesn't assert (SDK still consumes the token).
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (_isAuthCallbackRoute(name)) {
          return _noopRoute(settings);
        }
        return null;
      },
      onUnknownRoute: (settings) => _noopRoute(settings),
    );
  }
}
