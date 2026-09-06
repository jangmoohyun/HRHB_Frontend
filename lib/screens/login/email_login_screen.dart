import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';

import '../family/select/family_select_screen.dart';
import '../home/home_shell.dart';
import 'auth_form_widgets.dart';
import 'email_signup_email_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailAuth = EmailAuthService();
  final _sessionBootstrap = SessionBootstrap();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('이메일을 입력해주세요.');
      return;
    }
    if (password.isEmpty) {
      _showMessage('비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _emailAuth.login(email: email, password: password);
      if (!mounted) return;
      PushNotificationService.instance.registerCurrentDevice();
      if (result.familyId != null) {
        await _sessionBootstrap.syncFamilyProfile(
          isFamilyCreator: result.isFamilyCreator,
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (_) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const FamilySelectScreen()),
          (_) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      if (text.contains('(401)')) {
        _showMessage('이메일 또는 비밀번호가 올바르지 않아요.');
      } else {
        _showMessage('로그인에 실패했습니다.\n$error');
      }
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
      title: '이메일로 로그인',
      subtitle: '가입한 이메일과 비밀번호를 입력해주세요.',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _emailController,
            hintText: 'email@example.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _passwordController,
            hintText: '비밀번호',
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: '로그인',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EmailSignupEmailScreen(),
                ),
              );
            },
            child: const Text(
              '아직 계정이 없나요? 회원가입',
              style: TextStyle(color: bodyGrey),
            ),
          ),
        ],
      ),
    );
  }
}
