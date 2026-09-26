import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';

import '../login/login_screen.dart';
import '../onboarding/family_select_screen.dart';
import '../shell/home_shell.dart';

/// 01 로딩 — decides where to go (12s timeout, ≥1.2s splash; unchanged logic).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  final _session = SessionBootstrap();

  /// hxFloat 3s: translateY 0 ↔ -10px.
  late final _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat(reverse: true);

  /// hxDot 1.2s loop for the three dots.
  late final _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _float.dispose();
    _dots.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
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
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: HaruMotion.standard),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('하루한번', style: haruLogo(60)),
                const SizedBox(height: 10),
                Text('가족을 잇는 감성 커뮤니케이션', style: haruText(15, color: HaruColors.dsInkMuted)),
                const SizedBox(height: 56 + 40),
                AnimatedBuilder(
                  animation: _float,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -10 * Curves.easeInOut.transform(_float.value)),
                    child: child,
                  ),
                  child: const _LoadingEnvelope(),
                ),
                const SizedBox(height: 56),
                Text.rich(
                  TextSpan(
                    text: '오늘도 ',
                    style: haruText(16, color: HaruColors.dsInkSecondary),
                    children: [
                      TextSpan(
                        text: '가족의 마음을',
                        style: haruText(16, weight: FontWeight.w600, color: HaruColors.primary),
                      ),
                      const TextSpan(text: ' 이어드릴게요.'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('따뜻한 하루를 준비하고 있어요', style: haruText(14, color: HaruColors.dsInkFaint)),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _dots,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _dot((_dots.value - i * 0.2 / 1.2) % 1),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// hxDot: opacity .35→1→.35, scale .8→1.15→.8.
  Widget _dot(double phase) {
    final k = (math.sin(phase * 2 * math.pi - math.pi / 2) + 1) / 2;
    return Opacity(
      opacity: 0.35 + 0.65 * k,
      child: Transform.scale(
        scale: 0.8 + 0.35 * k,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: HaruColors.primary, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Green envelope with a white letter peeking out (200×136).
class _LoadingEnvelope extends StatelessWidget {
  const _LoadingEnvelope();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 136,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 24,
            right: 24,
            top: -48,
            height: 124,
            child: Container(
              padding: const EdgeInsets.only(top: 22),
              alignment: Alignment.topCenter,
              decoration: BoxDecoration(
                color: HaruColors.surface,
                border: Border.all(color: HaruColors.hairline),
                borderRadius: BorderRadius.circular(HaruRadius.md),
              ),
              child: const Icon(LucideIcons.heart, size: 28, color: HaruColors.primary),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: const _NotchClipper(0.58),
              child: Container(
                decoration: BoxDecoration(
                  color: HaruColors.accentGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// clip-path: polygon(0 0, 50% N%, 100% 0, 100% 100%, 0 100%) — a V notch.
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper(this.depth);
  final double depth;

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width / 2, s.height * depth)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_NotchClipper old) => old.depth != depth;
}
