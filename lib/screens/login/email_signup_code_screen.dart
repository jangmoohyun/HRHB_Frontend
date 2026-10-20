import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import 'auth_scaffold.dart';
import 'email_login_screen.dart';
import 'email_signup_password_screen.dart';

/// 가입 2 · 인증 코드.
class EmailSignupCodeScreen extends StatefulWidget {
  const EmailSignupCodeScreen({
    super.key,
    required this.email,
    this.expiresInSeconds = 600,
  });

  final String email;
  final int expiresInSeconds;

  @override
  State<EmailSignupCodeScreen> createState() => _EmailSignupCodeScreenState();
}

class _EmailSignupCodeScreenState extends State<EmailSignupCodeScreen> {
  final _code = TextEditingController();
  final _auth = EmailAuthService();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  late DateTime _expiresAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTimer(widget.expiresInSeconds);
  }

  void _startTimer(int seconds) {
    _expiresAt = DateTime.now().add(Duration(seconds: seconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  String get _remaining {
    final left = _expiresAt.difference(DateTime.now());
    if (left.isNegative) return '0:00';
    final s = left.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _auth.verifySignupCode(email: widget.email, code: code);
      if (!mounted) return;
      await Navigator.of(context).push(
        flowRoute<void>(EmailSignupPasswordScreen(email: r.email, signupToken: r.signupToken)),
      );
      // Back from the password step is the prototype's sendCode: a new code
      // and an empty field.
      if (!mounted) return;
      _code.clear();
      _resend(sentToast: '인증 코드를 보냈어요.');
    } catch (e) {
      if (!mounted) return;
      final t = e.toString();
      setState(() => _error = t.contains('expired')
          ? '코드가 만료됐어요. 다시 받아주세요.'
          : '코드가 맞지 않아요. 다시 확인해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend({String sentToast = '인증 코드를 다시 보냈어요.'}) async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final r = await _auth.sendSignupCode(widget.email);
      if (!mounted) return;
      _startTimer(r.expiresInSeconds);
      final debug = r.debugCode;
      HaruToast.show(
        context,
        debug != null && debug.isNotEmpty ? '인증 코드: $debug' : sentToast,
      );
    } catch (_) {
      if (mounted) setState(() => _error = '코드를 다시 보내지 못했어요.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop(), step: 1),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('메일로 받은\n6자리 코드를 입력해주세요', style: HaruType.headline),
          const SizedBox(height: 8),
          Text(widget.email, style: hr(15, color: HaruColors.inkMuted)),
          const SizedBox(height: 28),
          HaruTextField(
            controller: _code,
            placeholder: '000000',
            height: 64,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: hrHand(34, weight: FontWeight.w400, letterSpacing: 14),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) FieldError(_error!),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('남은 시간 $_remaining', style: hr(14, color: HaruColors.inkMuted)),
              Pressable(
                onTap: () => _resend(),
                child: Text('다시 보내기', style: hr(14, color: HaruColors.forest)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: '확인',
            loading: _loading,
            onPressed: _code.text.trim().length == 6 ? _verify : null,
          ),
        ],
      ),
    );
  }
}
