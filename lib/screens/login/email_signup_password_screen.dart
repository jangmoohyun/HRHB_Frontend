import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';

import 'auth_form_widgets.dart';
import 'login_screen.dart';

class EmailSignupPasswordScreen extends StatefulWidget {
  const EmailSignupPasswordScreen({
    super.key,
    required this.email,
    required this.signupToken,
  });

  final String email;
  final String signupToken;

  @override
  State<EmailSignupPasswordScreen> createState() =>
      _EmailSignupPasswordScreenState();
}

class _EmailSignupPasswordScreenState extends State<EmailSignupPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailAuth = EmailAuthService();
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 8) {
      _showMessage('비밀번호는 8자 이상이어야 해요.');
      return;
    }
    if (password != confirm) {
      _showMessage('비밀번호 확인이 일치하지 않아요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _emailAuth.register(
        signupToken: widget.signupToken,
        password: password,
        passwordConfirm: confirm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료됐어요. 로그인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('회원가입에 실패했습니다.\n$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: '비밀번호 설정',
      subtitle: '${widget.email}\n로그인에 사용할 비밀번호를 입력해주세요.',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _passwordController,
            hintText: '비밀번호 (8자 이상)',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _confirmController,
            hintText: '비밀번호 확인',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: '확인',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
