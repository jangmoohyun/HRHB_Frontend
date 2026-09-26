import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'email_signup_code_screen.dart';
import 'login_screen.dart';

/// 05 가입 ① 이메일.
class EmailSignupEmailScreen extends StatefulWidget {
  const EmailSignupEmailScreen({super.key});

  @override
  State<EmailSignupEmailScreen> createState() => _EmailSignupEmailScreenState();
}

class _EmailSignupEmailScreenState extends State<EmailSignupEmailScreen> {
  final _email = TextEditingController();
  final _auth = EmailAuthService();
  bool _loading = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = '이메일 형식을 확인해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _auth.checkSignupStatus(email);
      if (!mounted) return;
      switch (status.status) {
        case 'REGISTERED':
          setState(() => _error = '이미 가입된 이메일이에요. 로그인해 주세요.');
          return;
        case 'RECOVERABLE':
          final ok = await showHaruConfirm(
            context,
            title: '삭제 예정인 계정이에요',
            body: '탈퇴 신청 후 30일이 지나지 않았어요.\n계정을 복구하고 로그인할까요?',
            confirmLabel: '복구하기',
          );
          if (!ok || !mounted) return;
          await _auth.restoreAccount(email);
          if (!mounted) return;
          final nav = Navigator.of(context, rootNavigator: true);
          nav.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => LoginScreen(prefillEmail: email)),
            (_) => false,
          );
          HaruToast.show(nav.context, '계정을 복구했어요. 로그인해 주세요');
          return;
        case 'AVAILABLE':
          break;
        default:
          setState(() => _error = '이메일 상태를 확인하지 못했어요.');
          return;
      }
      final r = await _auth.sendSignupCode(email);
      if (!mounted) return;
      final debug = r.debugCode;
      HaruToast.show(
        context,
        debug != null && debug.isNotEmpty ? '인증번호: $debug' : '인증번호를 이메일로 보냈어요',
        icon: LucideIcons.mail,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EmailSignupCodeScreen(email: r.email)),
      );
    } catch (e) {
      if (!mounted) return;
      final t = e.toString();
      setState(() => _error = t.contains('EMAIL_ALREADY_REGISTERED') || t.contains('already registered')
          ? '이미 가입된 이메일이에요. 로그인해 주세요.'
          : '요청하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      children: [
        const AuthStepIndicator(step: 1),
        const AuthTitle(title: '가입할 이메일을\n알려 주세요', description: '인증번호를 보내 드릴게요.'),
        Gap(children: [
          HaruTextField(
            label: '이메일',
            controller: _email,
            hint: 'email@example.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _send(),
          ),
          if (_error != null) HaruFieldError(_error!, icon: LucideIcons.circleAlert),
          HaruButton(
            label: '인증번호 받기',
            size: HaruButtonSize.lg,
            fullWidth: true,
            loading: _loading,
            onPressed: _email.text.trim().isEmpty ? null : _send,
          ),
        ]),
      ],
    );
  }
}
