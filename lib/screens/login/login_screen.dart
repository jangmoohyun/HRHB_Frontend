import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/config/env.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/kakao_auth_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import 'auth_scaffold.dart';
import 'email_login_screen.dart';
import 'email_signup_email_screen.dart';
import 'policy_document_screen.dart';

/// 로그인 — wordmark, floating letter, 카카오 · Google · (Apple) · 이메일.
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

  /// Which button is working ('kakao' | 'google' | 'apple').
  String? _busy;

  Future<void> _finish(AuthResult r, String toast) async {
    if (r.familyId != null) {
      await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
    }
    if (!mounted) return;
    HaruToast.show(context, r.restored ? '계정을 복구했어요.' : toast);
    goAfterLogin(context, hasFamily: r.familyId != null);
  }

  Future<void> _run(String key, Future<AuthResult> Function() login, String toast, String fail) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      final r = await login();
      if (!mounted) return;
      await _finish(r, toast);
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message);
    } catch (_) {
      if (mounted) HaruToast.show(context, fail);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _kakaoLogin() {
    if (!Env.hasKakaoKey) {
      HaruToast.show(context, '카카오 앱 키가 설정되지 않았어요.');
      return;
    }
    _run('kakao', _kakao.login, '카카오 계정으로 로그인했어요.', '카카오 로그인에 실패했어요. 다시 시도해 주세요.');
  }

  void _googleLogin() => _run(
        'google',
        PendingApi.instance.loginWithGoogle,
        'Google 계정으로 로그인했어요.',
        'Google 로그인에 실패했어요. 다시 시도해 주세요.',
      );

  void _appleLogin() => _run(
        'apple',
        PendingApi.instance.loginWithApple,
        'Apple 계정으로 로그인했어요.',
        'Apple 로그인에 실패했어요. 다시 시도해 주세요.',
      );

  void _policy(String title, String asset) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PolicyDocumentScreen(title: title, assetPath: asset)),
      );

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      builder: (context, minHeight, shift) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 96 + shift, 32, 40),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Text('하루한번', style: hr(42, color: HaruColors.forest, height: 1.05)),
                const SizedBox(height: 6),
                const TitleDivider(),
                const SizedBox(height: 22),
                FloatLoop(
                  period: const Duration(milliseconds: 3400),
                  child: _sized(HaruImages.loginLetter, 300, 1390 / 1132),
                ),
                const Spacer(),
                _LoginButton(
                  color: HaruColors.kakaoYellow,
                  leading: SvgPicture.string(_kakaoSvg, width: 20, height: 20),
                  label: '카카오로 시작하기',
                  labelColor: HaruColors.kakaoLabel,
                  busy: _busy == 'kakao',
                  onTap: _kakaoLogin,
                ),
                const SizedBox(height: 10),
                _LoginButton(
                  color: Colors.white,
                  border: HaruColors.googleBorder,
                  leading: SvgPicture.string(_googleSvg, width: 20, height: 20),
                  label: 'Google로 시작하기',
                  labelColor: HaruColors.googleLabel,
                  busy: _busy == 'google',
                  onTap: _googleLogin,
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 10),
                  _LoginButton(
                    color: Colors.black,
                    leading: SvgPicture.string(_appleSvg, width: 20, height: 20),
                    label: 'Apple로 시작하기',
                    labelColor: Colors.white,
                    busy: _busy == 'apple',
                    onTap: _appleLogin,
                  ),
                ],
                const SizedBox(height: 10),
                _LoginButton(
                  color: HaruColors.cta,
                  shadow: HaruShadows.shadow1,
                  leadingLeft: 18,
                  leading: const Icon(Symbols.mail_rounded, size: 22, color: Colors.white),
                  label: '이메일로 시작하기',
                  labelColor: Colors.white,
                  onTap: () => Navigator.of(context).push(
                    flowRoute<void>(EmailLoginScreen(prefillEmail: widget.prefillEmail)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('아직 계정이 없나요?', style: hr(15, color: HaruColors.inkMuted)),
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: () => Navigator.of(context).push(
                        flowRoute<void>(const EmailSignupEmailScreen()),
                      ),
                      child: Text('이메일로 가입하기', style: hr(15, color: HaruColors.forest)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: hr(13.5, color: HaruColors.inkMuted, height: 1.5),
                    children: [
                      const TextSpan(text: '시작하면 '),
                      TextSpan(
                        text: '이용약관',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _policy('이용약관', PolicyDocumentScreen.termsAsset),
                      ),
                      const TextSpan(text: ' 및 '),
                      TextSpan(
                        text: '개인정보처리방침',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              _policy('개인정보처리방침', PolicyDocumentScreen.privacyAsset),
                      ),
                      const TextSpan(text: '에 동의하게 돼요'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 52 tall, radius 12; icon pinned 20px from the left, label centered.
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.color,
    required this.leading,
    required this.label,
    required this.labelColor,
    required this.onTap,
    this.border,
    this.shadow,
    this.busy = false,
    this.leadingLeft = 20,
  });

  final Color color;
  final Widget leading;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final Color? border;
  final List<BoxShadow>? shadow;
  final bool busy;
  final double leadingLeft;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .97,
      semanticLabel: label,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: border == null ? null : Border.all(color: border!),
          boxShadow: shadow,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: leadingLeft, child: leading),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  HaruSpinner(color: labelColor),
                  const SizedBox(width: 8),
                ],
                Text(label, style: hr(18, color: labelColor, letterSpacing: -.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _kakaoSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<path fill="#000000" d="M12 3C6.48 3 2 6.58 2 11c0 2.85 1.86 5.35 4.66 6.77l-.95 3.48c-.08.3.26.54.52.37l4.15-2.75c.53.06 1.07.09 1.62.09 5.52 0 10-3.58 10-8S17.52 3 12 3z"/>'
    '</svg>';

const _googleSvg = '<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// Apple logo (Apple's sign-in button glyph).
const _appleSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<path fill="#FFFFFF" d="M16.37 12.6c-.02-2.23 1.82-3.3 1.9-3.35-1.04-1.52-2.65-1.72-3.22-1.75-1.37-.14-2.67.8-3.37.8-.69 0-1.76-.78-2.9-.76-1.49.02-2.87.87-3.63 2.2-1.55 2.69-.4 6.67 1.11 8.85.74 1.07 1.62 2.27 2.77 2.22 1.11-.04 1.53-.72 2.88-.72 1.34 0 1.72.72 2.9.7 1.2-.02 1.96-1.08 2.69-2.16.85-1.24 1.2-2.44 1.22-2.5-.03-.01-2.33-.9-2.35-3.53zM14.16 6.06c.61-.74 1.02-1.77.91-2.8-.88.04-1.94.59-2.57 1.32-.56.65-1.06 1.7-.92 2.7.98.08 1.97-.5 2.58-1.22z"/>'
    '</svg>';

/// Image with an explicit height: RenderImage reports its intrinsic height
/// for the *available* width, which would make IntrinsicHeight overshoot.
Widget _sized(String asset, double width, double aspect) =>
    SizedBox(width: width, height: width * aspect, child: Image.asset(asset, fit: BoxFit.contain));
