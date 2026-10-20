import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'email_login_screen.dart';
import 'email_signup_code_screen.dart';
import 'login_screen.dart';

/// 가입 1 · 이메일.
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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _text => _email.text.trim();
  bool get _emailBad => _text.length > 3 && !isValidEmail(_text);

  Future<void> _send() async {
    final email = _text;
    if (!isValidEmail(email) || _loading) return;
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
          setState(() => _error = '이미 가입된 이메일이에요. 로그인해주세요.');
          return;
        case 'RECOVERABLE':
          final ok = await showHaruConfirm(
            context,
            title: '삭제 예정인 계정이에요',
            body: '탈퇴 신청 후 30일이 지나지 않았어요. 계정을 복구하고 로그인할까요?',
            okLabel: '복구하기',
            danger: false,
          );
          if (!ok || !mounted) return;
          await _auth.restoreAccount(email);
          if (!mounted) return;
          final nav = Navigator.of(context, rootNavigator: true);
          nav.pushAndRemoveUntil(
            flowRoute<void>(LoginScreen(prefillEmail: email)),
            (_) => false,
          );
          HaruToast.show(nav.context, '계정을 복구했어요. 로그인해주세요.');
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
        debug != null && debug.isNotEmpty ? '인증 코드: $debug' : '인증 코드를 보냈어요.',
      );
      await Navigator.of(context).push(
        flowRoute<void>(EmailSignupCodeScreen(email: r.email, expiresInSeconds: r.expiresInSeconds)),
      );
      // Back from the code step is the prototype's goSignup: a fresh email step.
      if (mounted) setState(_email.clear);
    } catch (e) {
      if (!mounted) return;
      final t = e.toString();
      setState(() => _error = t.contains('EMAIL_ALREADY_REGISTERED') || t.contains('already registered')
          ? '이미 가입된 이메일이에요. 로그인해주세요.'
          : '요청하지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop(), step: 0),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('이메일을\n알려주세요', style: HaruType.headline),
          const SizedBox(height: 8),
          Text('가입 확인용 코드를 보내드릴게요', style: hr(15, color: HaruColors.inkMuted)),
          const SizedBox(height: 28),
          HaruTextField(
            controller: _email,
            placeholder: 'haru@family.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _send(),
          ),
          if (_emailBad) const FieldError('이메일 형식을 확인해주세요.'),
          if (_error != null) FieldError(_error!),
          const SizedBox(height: 28),
          PrimaryButton(
            label: '인증 코드 받기',
            loading: _loading,
            onPressed: isValidEmail(_text) ? _send : null,
          ),
        ],
      ),
    );
  }
}
