import 'package:flutter/material.dart';

import 'package:hrhb_frontend/data/app_prefs.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';

import '../login/auth_scaffold.dart';
import '../login/login_screen.dart';
import '../onboarding/family_select_screen.dart';
import '../shell/home_shell.dart';

/// 로딩 — floating letter while the session is resolved
/// (12s timeout, ≥1.2s splash).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final _session = SessionBootstrap();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the watercolor art while the splash is up so the first screen
    // doesn't pop its images in one by one.
    for (final a in HaruImages.all) {
      precacheImage(AssetImage(a), context).ignore();
    }
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    // A preference must never hold up launch (secure storage can stall).
    try {
      await AppPrefs.loadFontSize().timeout(const Duration(seconds: 2));
    } catch (_) {}
    SessionDestination destination;
    try {
      destination = await _session.resolve().timeout(const Duration(seconds: 12));
    } catch (e, st) {
      debugPrint('Session bootstrap failed: $e\n$st');
      destination = SessionDestination.login;
    }
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 1200);
    if (elapsed < minSplash) await Future<void>.delayed(minSplash - elapsed);
    if (!mounted) return;
    if (destination != SessionDestination.login) {
      PushNotificationService.instance.registerCurrentDevice();
    }
    if (destination == SessionDestination.home) {
      await FamilyContext.instance.loadCached();
    }
    if (!mounted) return;
    final Widget next = switch (destination) {
      SessionDestination.home => const HomeShell(),
      SessionDestination.familySelect => const FamilySelectScreen(),
      SessionDestination.login => const LoginScreen(),
    };
    Navigator.of(context).pushReplacement(flowRoute<void>(next));
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      entrance: false,
      builder: (context, minHeight, shift) => SizedBox(
        height: minHeight,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatLoop(child: Image.asset(HaruImages.loadingLetter, width: 190)),
            const SizedBox(height: 20),
            Text('하루한번', style: hr(50, color: HaruColors.forest, height: 1.05)),
            const SizedBox(height: 10),
            const TitleDivider(),
            const SizedBox(height: 14),
            Text('하루에 한 번, 가족에게 편지를', style: hr(16, color: HaruColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
