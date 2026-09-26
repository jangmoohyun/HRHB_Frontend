import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/email_auth_service.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import 'auth_scaffold.dart';
import 'email_signup_email_screen.dart';

/// 04 이메일 로그인.
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

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 모두 입력해 주세요.');
      return;
    }
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
      if (r.restored) HaruToast.show(context, '계정을 복구했어요');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_SCHEDULED_FOR_DELETION' || e.message.contains('scheduled for deletion')) {
        await _offerRestore(email, pw);
      } else if (e.statusCode == 401 || e.message.contains('(401)')) {
        setState(() => _error = '이메일 또는 비밀번호가 맞지 않아요.');
      } else {
        setState(() => _error = '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '로그인하지 못했어요. 네트워크를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _offerRestore(String email, String pw) async {
    final ok = await showHaruConfirm(
      context,
      title: '삭제 예정인 계정이에요',
      body: '탈퇴 신청 후 30일이 지나지 않았어요.\n계정을 복구하고 로그인할까요?',
      confirmLabel: '복구하기',
    );
    if (!ok || !mounted) return;
    try {
      await _auth.restoreAccount(email);
      final r = await _auth.login(email: email, password: pw);
      if (!mounted) return;
      if (r.familyId != null) await _session.syncFamilyProfile(isFamilyCreator: r.isFamilyCreator);
      if (!mounted) return;
      HaruToast.show(context, '계정을 복구했어요');
      goAfterLogin(context, hasFamily: r.familyId != null);
    } catch (_) {
      if (mounted) setState(() => _error = '계정을 복구하지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      children: [
        const AuthTitle(title: '이메일로 로그인', description: '가입한 이메일과 비밀번호를 입력해 주세요.'),
        Gap(children: [
          HaruTextField(
            label: '이메일',
            controller: _email,
            hint: 'email@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          HaruTextField(
            label: '비밀번호',
            controller: _pw,
            hint: '비밀번호',
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) HaruFieldError(_error!, icon: LucideIcons.circleAlert),
          HaruButton(
            label: '로그인',
            size: HaruButtonSize.lg,
            fullWidth: true,
            loading: _loading,
            onPressed: _submit,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('처음이신가요?', style: haruText(14, color: HaruColors.dsInkMuted)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EmailSignupEmailScreen()),
                ),
                child: Text(
                  '이메일로 회원가입',
                  style: haruText(14, weight: FontWeight.w500, color: HaruColors.primary),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
