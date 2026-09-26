import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'login_screen.dart';

/// 07 가입 ③ 비밀번호.
class EmailSignupPasswordScreen extends StatefulWidget {
  const EmailSignupPasswordScreen({super.key, required this.email, required this.signupToken});

  final String email;
  final String signupToken;

  @override
  State<EmailSignupPasswordScreen> createState() => _EmailSignupPasswordScreenState();
}

class _EmailSignupPasswordScreenState extends State<EmailSignupPasswordScreen> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _auth = EmailAuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  bool get _lenOk => _pw.text.length >= 8;
  bool get _sameOk => _pw.text.isNotEmpty && _pw.text == _pw2.text;

  Future<void> _register() async {
    if (!_lenOk || !_sameOk) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.register(
        signupToken: widget.signupToken,
        password: _pw.text,
        passwordConfirm: _pw2.text,
      );
      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => LoginScreen(prefillEmail: widget.email)),
        (_) => false,
      );
      HaruToast.show(nav.context, '가입을 마쳤어요. 로그인해 주세요');
    } catch (_) {
      if (mounted) setState(() => _error = '가입하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _rule(String label, bool ok) => Row(
        children: [
          Icon(LucideIcons.check, size: 16, color: ok ? HaruColors.statusPositive : HaruColors.dsInkFaint),
          const SizedBox(width: 6),
          Text(label, style: haruText(14, color: ok ? HaruColors.statusPositive : HaruColors.dsInkFaint)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      children: [
        const AuthStepIndicator(step: 3),
        const AuthTitle(title: '비밀번호를 정해 주세요', description: '로그인할 때 사용해요.'),
        Gap(children: [
          HaruTextField(
            label: '비밀번호',
            controller: _pw,
            hint: '8자 이상',
            obscure: true,
            onChanged: (_) => setState(() {}),
          ),
          HaruTextField(
            label: '비밀번호 확인',
            controller: _pw2,
            hint: '한 번 더 입력',
            obscure: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _register(),
          ),
          Column(
            children: [
              _rule('8자 이상', _lenOk),
              const SizedBox(height: 6),
              _rule('두 비밀번호가 같아요', _sameOk),
            ],
          ),
          if (_error != null) HaruFieldError(_error!, icon: LucideIcons.circleAlert),
          HaruButton(
            label: '가입 완료',
            size: HaruButtonSize.lg,
            fullWidth: true,
            loading: _loading,
            onPressed: _lenOk && _sameOk ? _register : null,
          ),
        ]),
      ],
    );
  }
}
