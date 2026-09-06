import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';

import 'auth_form_widgets.dart';
import 'email_signup_password_screen.dart';

class EmailSignupCodeScreen extends StatefulWidget {
  const EmailSignupCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailSignupCodeScreen> createState() => _EmailSignupCodeScreenState();
}

class _EmailSignupCodeScreenState extends State<EmailSignupCodeScreen> {
  final _codeController = TextEditingController();
  final _emailAuth = EmailAuthService();
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('인증번호 6자리를 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _emailAuth.verifySignupCode(
        email: widget.email,
        code: code,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmailSignupPasswordScreen(
            email: result.email,
            signupToken: result.signupToken,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final result = await _emailAuth.sendSignupCode(widget.email);
      if (!mounted) return;
      if (result.debugCode != null && result.debugCode!.isNotEmpty) {
        _showMessage('인증번호: ${result.debugCode}');
      } else {
        _showMessage('인증번호를 다시 보냈어요.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('재전송에 실패했습니다.\n$error');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('expired')) return '인증번호가 만료되었어요. 다시 요청해주세요.';
    if (text.contains('Invalid')) return '인증번호가 올바르지 않아요.';
    return '인증에 실패했습니다.\n$error';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: '인증번호 확인',
      subtitle: '${widget.email}\n으로 보낸 6자리 인증번호를 입력해주세요.',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _codeController,
            hintText: '000000',
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(
                _resending ? '전송 중...' : '인증번호 재전송',
                style: const TextStyle(color: titleGreen),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
