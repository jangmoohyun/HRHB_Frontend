import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hrhb_frontend/config/env.dart';
import 'package:hrhb_frontend/services/kakao_auth_service.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/widgets/auth_branch_background.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../family/select/family_select_screen.dart';
import '../home/home_shell.dart';
import 'email_login_screen.dart';
import 'email_signup_email_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF5F5F5F);
const _mutedGrey = Color(0xFF8F8F8F);
const _emailGreen = Color(0xFF4DB980);

const _termsOfUseUrl =
    'https://app.notion.com/p/Privacy-Policy-2aa108cdc90280c5b22ff1426aebd7cf';
const _privacyPolicyUrl =
    'https://app.notion.com/p/Term-of-use-2aa108cdc90280fc878dd37b1745f239';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final KakaoAuthService _kakaoAuthService = KakaoAuthService();
  final SessionBootstrap _sessionBootstrap = SessionBootstrap();
  bool _isLoggingIn = false;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openPolicyUrl(_termsOfUseUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openPolicyUrl(_privacyPolicyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _openPolicyUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage('페이지를 열 수 없습니다.');
    }
  }

  void _goToFamilySelect() {
    PushNotificationService.instance.registerCurrentDevice();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const FamilySelectScreen()),
    );
  }

  void _goToHome() {
    PushNotificationService.instance.registerCurrentDevice();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  Future<void> _onKakaoLogin() async {
    if (_isLoggingIn) return;

    if (!Env.hasKakaoKey) {
      _showMessage('카카오 Native App Key를 설정해 주세요. (KAKAO_SETUP.md 참고)');
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      final result = await _kakaoAuthService.login();
      if (!mounted) return;

      if (result.restored) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: _cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                '계정 복구',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  color: _titleGreen,
                ),
              ),
              content: const Text(
                '계정이 복구되었습니다.',
                style: TextStyle(color: _bodyGrey, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: _titleGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
      }

      if (result.familyId != null) {
        await _sessionBootstrap.syncFamilyProfile(
          isFamilyCreator: result.isFamilyCreator,
        );
        if (!mounted) return;
        _goToHome();
      } else {
        _goToFamilySelect();
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('카카오 로그인에 실패했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Letter sits under every branch image.
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.22,
            bottom: size.height * 0.24,
            child: Align(
              alignment: const Alignment(0, 0.08),
              child: Image.asset(
                'assets/images/loginpage/letter/loginletter.png',
                width: size.width * 1.03,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Branches render above the letter.
          const Positioned.fill(
            child: AuthBranchBackground(),
          ),
          // Title / buttons stay on top for readability and taps.
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.06),
                      Text(
                        '하루한번',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: shortest * 0.105,
                          height: 1.05,
                          color: _titleGreen,
                        ),
                      ),
                      SizedBox(height: size.height * 0.012),
                      Text(
                        '가족을 잇는 감성 커뮤니케이션',
                        style: TextStyle(
                          fontSize: shortest * 0.035,
                          height: 1.3,
                          letterSpacing: -0.3,
                          color: _mutedGrey,
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),
                      const SproutDivider(),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                  child: Builder(
                    builder: (context) {
                      final buttonWidth =
                          size.width - (shortest * 0.08 * 2);
                      // Match Kakao asset ratio (300 x 45).
                      final buttonHeight = buttonWidth * (45 / 300);
                      final buttonRadius = buttonHeight * 0.15;
                      final iconSize = buttonHeight * 0.42;
                      final labelSize = buttonHeight * 0.36;

                      return Column(
                        children: [
                          SizedBox(height: size.height * 0.014),
                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                                onTap: _isLoggingIn ? null : _onKakaoLogin,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      'assets/images/loginpage/kakaologin/kakao_login.png',
                                      width: buttonWidth,
                                      height: buttonHeight,
                                      fit: BoxFit.fill,
                                    ),
                                    if (_isLoggingIn)
                                      const ColoredBox(
                                        color: Color(0x66FDFBF0),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: _titleGreen,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.012),
                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _emailGreen,
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x15000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(buttonRadius),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const EmailLoginScreen(),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      SizedBox(width: buttonWidth * 0.06),
                                      Icon(
                                        Icons.mail_outline_rounded,
                                        color: Colors.white,
                                        size: iconSize,
                                      ),
                                      Expanded(
                                        child: Text(
                                          '이메일로 로그인',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: labelSize,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: buttonWidth * 0.06 + iconSize,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const EmailSignupEmailScreen(),
                                ),
                              );
                            },
                            child: Text(
                              '이메일로 회원가입',
                              style: TextStyle(
                                color: _bodyGrey,
                                fontSize: shortest * 0.034,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    _bodyGrey.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.03),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: shortest * 0.04,
                              vertical: size.height * 0.014,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: _mutedGrey,
                                  fontSize: shortest * 0.025,
                                  height: 1.4,
                                ),
                                children: [
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 5),
                                      child: Icon(
                                        Icons.verified_user_outlined,
                                        size: 13,
                                        color: _titleGreen,
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: '로그인을 진행하시면 '),
                                  TextSpan(
                                    text: '이용약관',
                                    style: const TextStyle(
                                      color: _titleGreen,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _titleGreen,
                                    ),
                                    recognizer: _termsTap,
                                  ),
                                  const TextSpan(text: ' 및 '),
                                  TextSpan(
                                    text: '개인정보 처리방침',
                                    style: const TextStyle(
                                      color: _titleGreen,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _titleGreen,
                                    ),
                                    recognizer: _privacyTap,
                                  ),
                                  const TextSpan(text: '에 동의하게 됩니다.'),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.012),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
