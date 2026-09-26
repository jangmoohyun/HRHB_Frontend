import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/config/env.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/kakao_auth_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import 'auth_scaffold.dart';
import 'email_login_screen.dart';
import 'email_signup_email_screen.dart';
import 'policy_document_screen.dart';

/// 02 로그인.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillEmail});

  /// Carried into 이메일 로그인 right after signing up.
  final String? prefillEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _kakao = KakaoAuthService();
  final _session = SessionBootstrap();
  bool _busy = false;

  void _error(String m) => HaruToast.show(
        context,
        m,
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );

  Future<void> _kakaoLogin() async {
    if (_busy) return;
    if (!Env.hasKakaoKey) {
      _error('카카오 앱 키가 설정되지 않았어요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _kakao.login();
      if (!mounted) return;
      if (r.familyId != null) {
        await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
      }
      if (!mounted) return;
      if (r.restored) HaruToast.show(context, '계정을 복구했어요');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } catch (_) {
      if (mounted) _error('카카오 로그인에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _appleLogin() async {
    if (_busy) return;
    try {
      final r = await PendingApi.instance.loginWithApple();
      if (!mounted) return;
      if (r.familyId != null) {
        await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
      }
      if (mounted) goAfterLogin(context, hasFamily: r.familyId != null);
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message, icon: LucideIcons.info, iconColor: HaruColors.dsInkMuted);
    } catch (_) {
      if (mounted) _error('Apple 로그인에 실패했어요.');
    }
  }

  void _policy(String title, String asset) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PolicyDocumentScreen(title: title, assetPath: asset)),
      );

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS;
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: _DriftingDots()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: Column(
                children: [
                  HaruRise(
                    delay: const Duration(milliseconds: 50),
                    duration: const Duration(milliseconds: 700),
                    child: Column(
                      children: [
                        Text('하루한번', style: haruLogo(56)),
                        const SizedBox(height: 8),
                        Text('가족을 잇는 감성 커뮤니케이션', style: haruText(15, color: HaruColors.dsInkMuted)),
                      ],
                    ),
                  ),
                  const Expanded(child: _Stage()),
                  HaruRise(
                    delay: const Duration(milliseconds: 450),
                    duration: const Duration(milliseconds: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PillButton(
                          color: HaruColors.kakaoYellow,
                          onTap: _kakaoLogin,
                          leading: const _KakaoSymbol(),
                          label: '카카오 로그인',
                          labelColor: HaruColors.kakaoLabel,
                        ),
                        if (showApple) ...[
                          const SizedBox(height: 10),
                          _PillButton(
                            color: Colors.black,
                            onTap: _appleLogin,
                            leading: const Text('', style: TextStyle(fontSize: 19, height: 1, color: Colors.white)),
                            label: 'Apple로 로그인',
                            labelColor: Colors.white,
                          ),
                        ],
                        const SizedBox(height: 10),
                        HaruButton(
                          label: '이메일로 로그인',
                          icon: LucideIcons.mail,
                          size: HaruButtonSize.lg,
                          fullWidth: true,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EmailLoginScreen(prefillEmail: widget.prefillEmail),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
                          child: Center(
                            child: AuthLink(
                              label: '이메일로 회원가입',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const EmailSignupEmailScreen()),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(
                            style: haruText(12, height: 1.5, color: HaruColors.dsInkMuted),
                            children: [
                              const TextSpan(text: '로그인하면 '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _policy('이용약관', PolicyDocumentScreen.termsAsset),
                                  child: Text(
                                    '이용약관',
                                    style: haruText(12, height: 1.5, color: HaruColors.primary, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' 및 '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _policy('개인정보 처리방침', PolicyDocumentScreen.privacyAsset),
                                  child: Text(
                                    '개인정보 처리방침',
                                    style: haruText(12, height: 1.5, color: HaruColors.primary, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '에 동의하게 돼요.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator(color: HaruColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.color,
    required this.onTap,
    required this.leading,
    required this.label,
    required this.labelColor,
  });

  final Color color;
  final VoidCallback onTap;
  final Widget leading;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(HaruRadius.full)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(label, style: haruText(16, weight: FontWeight.w600, color: labelColor)),
          ],
        ),
      ),
    );
  }
}

/// Kakao speech-bubble symbol (20×17 black ellipse with a tail).
class _KakaoSymbol extends StatelessWidget {
  const _KakaoSymbol();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 20, height: 21, child: CustomPaint(painter: _KakaoPainter()));
}

class _KakaoPainter extends CustomPainter {
  const _KakaoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    canvas.drawOval(const Rect.fromLTWH(0, 0, 20, 17), p);
    canvas.drawPath(
      Path()
        ..moveTo(4, 14)
        ..lineTo(11, 14)
        ..lineTo(7, 20)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(_KakaoPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Background drift (hxDrift1 / hxDrift2)
// ─────────────────────────────────────────────────────────────────────────────

class _DriftingDots extends StatefulWidget {
  const _DriftingDots();

  @override
  State<_DriftingDots> createState() => _DriftingDotsState();
}

class _DriftingDotsState extends State<_DriftingDots> with SingleTickerProviderStateMixin {
  // One slow master clock; each dot derives its own phase.
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 88))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// drift1: (0,0) → (-18,14); drift2: (0,0) → (16,-12). Ease-in-out, yoyo.
  Offset _drift(bool one, double periodSec, double delaySec) {
    final t = (_c.value * 88 - delaySec) / periodSec;
    final k = (1 - math.cos(2 * math.pi * t)) / 2;
    return one ? Offset(-18 * k, 14 * k) : Offset(16 * k, -12 * k);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _dot(top: -90, right: -100, size: 300, color: HaruColors.meadow, offset: _drift(true, 9, 0)),
          _dot(
            top: 250,
            left: -80,
            size: 190,
            color: HaruColors.accentSky.withValues(alpha: 0.55),
            offset: _drift(false, 11, 0),
          ),
          _dot(top: 470, right: -40, size: 120, color: HaruColors.streakTile, offset: _drift(true, 8, 1)),
          _dot(top: 150, left: 48, size: 14, color: HaruColors.accentButter, offset: _drift(false, 6, 0)),
          _dot(top: 210, right: 56, size: 10, color: HaruColors.accentPink, offset: _drift(true, 7, 0)),
        ],
      ),
    );
  }

  Widget _dot({
    required double top,
    double? left,
    double? right,
    required double size,
    required Color color,
    required Offset offset,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage: floating question chips + animated envelope
// ─────────────────────────────────────────────────────────────────────────────

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 360),
      child: LayoutBuilder(builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: 34,
              left: 0,
              child: _QuestionChip(text: '어릴 때 가장 좋아했던 반찬은?', delayMs: 350, left: true),
            ),
            const Positioned(
              top: 96,
              right: -6,
              child: _QuestionChip(text: '요즘 가장 자주 듣는 노래는?', delayMs: 550, left: false),
            ),
            const Positioned(
              bottom: 30,
              left: 10,
              child: _QuestionChip(text: '처음 가족 여행은 어디였나요?', delayMs: 750, left: false),
            ),
            Positioned(
              left: c.maxWidth / 2 - 90,
              top: 176,
              child: const _PopOnce(delayMs: 200, durationMs: 700, child: _Envelope()),
            ),
          ],
        );
      }),
    );
  }
}

class _PopOnce extends StatelessWidget {
  const _PopOnce({required this.child, required this.delayMs, required this.durationMs});
  final Widget child;
  final int delayMs;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final total = delayMs + durationMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: HaruMotion.pop),
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: c),
      ),
      child: child,
    );
  }
}

class _QuestionChip extends StatefulWidget {
  const _QuestionChip({required this.text, required this.delayMs, required this.left});
  final String text;
  final int delayMs;
  final bool left;

  @override
  State<_QuestionChip> createState() => _QuestionChipState();
}

class _QuestionChipState extends State<_QuestionChip> with SingleTickerProviderStateMixin {
  /// hxSwayL/R 5.5s ease-in-out, starting when the pop finishes.
  late final _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 2750));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs + 700), () {
      if (mounted) _sway.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: HaruShadows.s1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Q.', style: haruText(13, weight: FontWeight.w800, color: HaruColors.house)),
          const SizedBox(width: 6),
          Text(widget.text, style: haruQuestion(13, color: HaruColors.ink, height: 1.5)),
        ],
      ),
    );
    // L: y 0→-8, rotate -7°→-4°; R: y 0→-10, rotate 6°→3°.
    final (dy, r0, r1) = widget.left ? (-8.0, -7.0, -4.0) : (-10.0, 6.0, 3.0);
    return _PopOnce(
      delayMs: widget.delayMs,
      durationMs: 600,
      child: AnimatedBuilder(
        animation: _sway,
        builder: (_, child) {
          final k = Curves.easeInOut.transform(_sway.value);
          return Transform.translate(
            offset: Offset(0, dy * k),
            child: Transform.rotate(angle: (r0 + (r1 - r0) * k) * math.pi / 180, child: child),
          );
        },
        child: chip,
      ),
    );
  }
}

/// 180×120 envelope: flap flips open (hxFlap), the letter rises (hxLetter),
/// hearts float up (hxHeart). 4.5s loop after 1s.
class _Envelope extends StatefulWidget {
  const _Envelope();

  @override
  State<_Envelope> createState() => _EnvelopeState();
}

class _EnvelopeState extends State<_Envelope> with TickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
  late final _hearts = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) _loop.repeat();
    });
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) _hearts.repeat();
    });
  }

  @override
  void dispose() {
    _loop.dispose();
    _hearts.dispose();
    super.dispose();
  }

  static const _curve = HaruMotion.standard;

  /// Piecewise keyframes over the 4.5s loop.
  double _flapAngle(double t) {
    if (t < 0.14) return math.pi * _curve.transform(t / 0.14);
    if (t < 0.86) return math.pi;
    return math.pi * (1 - _curve.transform((t - 0.86) / 0.14));
  }

  double _letterY(double t) {
    if (t < 0.18) return 0;
    if (t < 0.40) return -62 * _curve.transform((t - 0.18) / 0.22);
    if (t < 0.70) return -62;
    if (t < 0.85) return -62 * (1 - _curve.transform((t - 0.70) / 0.15));
    return 0;
  }

  Widget _heart(double phaseShift, double left, Color color) {
    final t = (_hearts.value - phaseShift) % 1;
    final eased = Curves.easeOut.transform(t);
    final opacity = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
    return Positioned(
      left: left,
      top: 10 - 96 * eased,
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: 0.5 + 0.55 * eased,
          child: Icon(LucideIcons.heart, size: 16, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loop, _hearts]),
      builder: (_, _) {
        final t = _loop.isAnimating ? _loop.value : 0.0;
        final angle = _flapAngle(t);
        final flap = Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 72,
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 1 / 600)
              ..rotateX(angle),
            child: ClipPath(
              clipper: const _TriangleClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  color: HaruColors.accentButter,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
          ),
        );
        final letter = Positioned(
          left: 15,
          right: 15,
          top: 10 + _letterY(t),
          height: 100,
          child: Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(HaruRadius.md),
              boxShadow: [cssShadow(y: 1, blur: 3, color: const Color(0x1F2B2016))],
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.heart, size: 20, color: HaruColors.streak),
                const SizedBox(height: 7),
                _bar(90),
                const SizedBox(height: 7),
                _bar(70),
              ],
            ),
          ),
        );
        final front = Positioned.fill(
          child: ClipPath(
            clipper: const _FrontClipper(),
            child: Container(
              decoration: BoxDecoration(
                color: HaruColors.accentPink,
                borderRadius: BorderRadius.circular(HaruRadius.lg),
              ),
            ),
          ),
        );
        final flapBehind = angle > math.pi / 2;
        return SizedBox(
          width: 180,
          height: 120,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: HaruColors.accentOrange,
                    borderRadius: BorderRadius.circular(HaruRadius.lg),
                  ),
                ),
              ),
              if (flapBehind) flap,
              letter,
              front,
              if (!flapBehind) flap,
              if (_hearts.isAnimating) ...[
                _heart(0, 52, HaruColors.streak),
                _heart(0.4 / 3, 92, HaruColors.tempRise),
                _heart(0.8 / 3, 126, HaruColors.house),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double w) => Container(
        width: w,
        height: 5,
        decoration: BoxDecoration(
          color: HaruColors.ceramic,
          borderRadius: BorderRadius.circular(HaruRadius.full),
        ),
      );
}

class _TriangleClipper extends CustomClipper<Path> {
  const _TriangleClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width / 2, s.height)
    ..close();
  @override
  bool shouldReclip(_TriangleClipper oldClipper) => false;
}

class _FrontClipper extends CustomClipper<Path> {
  const _FrontClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width / 2, s.height * 0.56)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_FrontClipper oldClipper) => false;
}
