import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';

import 'auth_form_widgets.dart';
import 'email_signup_code_screen.dart';
import 'login_screen.dart';

class EmailSignupEmailScreen extends StatefulWidget {
  const EmailSignupEmailScreen({super.key});

  @override
  State<EmailSignupEmailScreen> createState() => _EmailSignupEmailScreenState();
}

class _EmailSignupEmailScreenState extends State<EmailSignupEmailScreen> {
  final _emailController = TextEditingController();
  final _emailAuth = EmailAuthService();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('올바른 이메일을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final status = await _emailAuth.checkSignupStatus(email);
      if (!mounted) return;

      switch (status.status) {
        case 'REGISTERED':
          _showMessage('이미 가입된 이메일입니다.');
          return;
        case 'RECOVERABLE':
          final restore = await _confirmRestore();
          if (!mounted) return;
          if (restore != true) return;
          await _emailAuth.restoreAccount(email);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('계정이 복구 되었습니다.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            (_) => false,
          );
          return;
        case 'AVAILABLE':
          break;
        default:
          _showMessage('이메일 상태를 확인할 수 없습니다.');
          return;
      }

      final result = await _emailAuth.sendSignupCode(email);
      if (!mounted) return;
      if (result.debugCode != null && result.debugCode!.isNotEmpty) {
        _showMessage('인증번호: ${result.debugCode}');
      } else {
        _showMessage('인증번호를 이메일로 보냈어요.');
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmailSignupCodeScreen(email: result.email),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirmRestore() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '계정 복구',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              color: titleGreen,
            ),
          ),
          content: const Text(
            '이 이메일은 삭제될 예정입니다.\n계정을 복구하시겠습니까?',
            style: TextStyle(color: bodyGrey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: mutedGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '복구하기',
                style: TextStyle(
                  color: titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('EMAIL_ALREADY_REGISTERED') ||
        text.contains('already registered')) {
      return '이미 가입된 이메일입니다.';
    }
    return '요청에 실패했습니다.\n$error';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: '이메일로 회원가입',
      subtitle: '가입에 사용할 이메일을 입력해주세요.',
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
