import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'email_signup_password_screen.dart';

/// 06 가입 ② 인증코드.
class EmailSignupCodeScreen extends StatefulWidget {
  const EmailSignupCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailSignupCodeScreen> createState() => _EmailSignupCodeScreenState();
}

class _EmailSignupCodeScreenState extends State<EmailSignupCodeScreen> {
  final _code = TextEditingController();
  final _auth = EmailAuthService();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _auth.verifySignupCode(email: widget.email, code: code);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmailSignupPasswordScreen(email: r.email, signupToken: r.signupToken),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final t = e.toString();
      setState(() => _error = t.contains('expired')
          ? '인증번호가 만료됐어요. 다시 받아 주세요.'
          : '인증번호가 맞지 않아요. 다시 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final r = await _auth.sendSignupCode(widget.email);
      if (!mounted) return;
      final debug = r.debugCode;
      HaruToast.show(
        context,
        debug != null && debug.isNotEmpty ? '인증번호: $debug' : '인증번호를 다시 보냈어요',
        icon: LucideIcons.mail,
      );
    } catch (_) {
      if (mounted) setState(() => _error = '인증번호를 다시 보내지 못했어요.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      children: [
        const AuthStepIndicator(step: 2),
        AuthTitle(
          title: '인증번호를 입력해 주세요',
          description: '${widget.email}으로\n보낸 6자리 번호예요.',
        ),
        Gap(children: [
          HaruTextField(
            controller: _code,
            hint: '000000',
            height: 64,
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 14,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) HaruFieldError(_error!, icon: LucideIcons.circleAlert),
          Row(
            children: [
              Expanded(child: Text('메일이 오지 않았나요?', style: haruText(14, color: HaruColors.dsInkMuted))),
              HaruButton(label: '다시 보내기', variant: HaruButtonVariant.link, onPressed: _resend),
            ],
          ),
          HaruButton(
            label: '확인',
            size: HaruButtonSize.lg,
            fullWidth: true,
            loading: _loading,
            onPressed: _code.text.trim().length == 6 ? _verify : null,
          ),
        ]),
      ],
    );
  }
}
