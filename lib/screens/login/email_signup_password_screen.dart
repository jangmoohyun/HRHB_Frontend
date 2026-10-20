import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'email_login_screen.dart';
import 'login_screen.dart';

/// 가입 3 · 비밀번호. Signs in right after registering, like the prototype's
/// "가입 완료 → 가족 선택".
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
  bool get _mixOk => RegExp(r'[A-Za-z]').hasMatch(_pw.text) && RegExp(r'\d').hasMatch(_pw.text);
  bool get _sameOk => _pw.text.isNotEmpty && _pw.text == _pw2.text;
  bool get _ok => _lenOk && _mixOk && _sameOk;

  Future<void> _register() async {
    if (!_ok || _loading) return;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '가입하지 못했어요. 잠시 후 다시 시도해주세요.';
        });
      }
      return;
    }
    if (!mounted) return;
    try {
      final r = await _auth.login(email: widget.email, password: _pw.text);
      if (!mounted) return;
      HaruToast.show(context, '가입을 환영해요!');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } catch (_) {
      // Registered but the automatic sign-in failed — let them log in.
      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pushAndRemoveUntil(
        flowRoute<void>(LoginScreen(prefillEmail: widget.email)),
        (_) => false,
      );
      HaruToast.show(nav.context, '가입을 마쳤어요. 로그인해주세요.');
    }
  }

  Widget _rule(String label, bool ok) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              ok ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded,
              size: 18,
              color: ok ? HaruColors.cta : HaruColors.inkFaint,
            ),
            const SizedBox(width: 6),
            Text(label, style: hr(14, color: HaruColors.inkMuted)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop(), step: 2),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('비밀번호를\n정해주세요', style: HaruType.headline),
          const SizedBox(height: 28),
          HaruTextField(
            controller: _pw,
            placeholder: '비밀번호',
            obscure: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          HaruTextField(
            controller: _pw2,
            placeholder: '비밀번호 확인',
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 14),
          _rule('8자 이상', _lenOk),
          _rule('영문과 숫자 함께', _mixOk),
          _rule('두 비밀번호가 같아요', _sameOk),
          if (_error != null) FieldError(_error!),
          const SizedBox(height: 22),
          PrimaryButton(label: '가입 완료', loading: _loading, onPressed: _ok ? _register : null),
        ],
      ),
    );
  }
}
