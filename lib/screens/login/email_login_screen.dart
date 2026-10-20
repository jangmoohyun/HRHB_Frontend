import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import 'auth_scaffold.dart';
import 'email_signup_email_screen.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String v) => _emailPattern.hasMatch(v);

/// 이메일 로그인.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key, this.prefillEmail});

  final String? prefillEmail;

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  late final _email = TextEditingController(text: widget.prefillEmail ?? '');
  final _pw = TextEditingController();
  final _auth = EmailAuthService();
  final _session = SessionBootstrap();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  String get _emailText => _email.text.trim();
  bool get _emailBad => _emailText.length > 3 && !isValidEmail(_emailText);
  bool get _canSubmit => isValidEmail(_emailText) && _pw.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    final email = _emailText, pw = _pw.text;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _auth.login(email: email, password: pw);
      if (!mounted) return;
      if (r.familyId != null) await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
      if (!mounted) return;
      HaruToast.show(context, r.restored ? '계정을 복구했어요.' : '다시 만나서 반가워요!');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_SCHEDULED_FOR_DELETION' || e.message.contains('scheduled for deletion')) {
        await _offerRestore(email, pw);
      } else if (e.statusCode == 401 || e.message.contains('(401)')) {
        setState(() => _error = '이메일 또는 비밀번호가 맞지 않아요. 다시 확인해주세요.');
      } else {
        setState(() => _error = '로그인하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '로그인하지 못했어요. 네트워크를 확인해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _offerRestore(String email, String pw) async {
    final ok = await showHaruConfirm(
      context,
      title: '삭제 예정인 계정이에요',
      body: '탈퇴 신청 후 30일이 지나지 않았어요. 계정을 복구하고 로그인할까요?',
      okLabel: '복구하기',
      danger: false,
    );
    if (!ok || !mounted) return;
    try {
      await _auth.restoreAccount(email);
      final r = await _auth.login(email: email, password: pw);
      if (!mounted) return;
      if (r.familyId != null) await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
      if (!mounted) return;
      HaruToast.show(context, '계정을 복구했어요.');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } catch (_) {
      if (mounted) setState(() => _error = '계정을 복구하지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop()),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('이메일로\n로그인해요', style: HaruType.headline),
          const SizedBox(height: 8),
          Text('가입한 이메일과 비밀번호를 입력해주세요', style: hr(15, color: HaruColors.inkMuted)),
          const SizedBox(height: 28),
          FieldLabel('이메일'),
          HaruTextField(
            controller: _email,
            placeholder: 'haru@family.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_emailBad) const FieldError('이메일 형식을 확인해주세요.'),
          const SizedBox(height: 18),
          FieldLabel('비밀번호'),
          HaruTextField(
            controller: _pw,
            placeholder: '비밀번호',
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) FieldError(_error!),
          const SizedBox(height: 28),
          PrimaryButton(
            label: '로그인',
            loading: _loading,
            onPressed: _canSubmit ? _submit : null,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Pressable(
                onTap: () => HaruToast.show(context, '비밀번호 재설정은 준비 중이에요.'),
                child: Text('비밀번호를 잊으셨나요?', style: hr(14, color: HaruColors.inkMuted)),
              ),
              const SizedBox(width: 16),
              Pressable(
                onTap: () => Navigator.of(context).pushReplacement(
                  flowRoute<void>(const EmailSignupEmailScreen()),
                ),
                child: Text('회원가입', style: hr(14, color: HaruColors.forest)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Form label (15, forest) with the prototype's `margin: … 2px 8px`.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(text, style: HaruType.fieldLabel),
    );
  }
}

/// Inline error under a field (14.5, danger, margin 6 2 0).
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(text, style: HaruType.error),
    );
  }
}
