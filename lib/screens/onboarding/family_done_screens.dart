import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/auth_scaffold.dart';
import '../shell/home_shell.dart';

void _enterHome(BuildContext context) {
  PushNotificationService.instance.registerCurrentDevice();
  FamilyContext.instance.refresh().ignore();
  final nav = Navigator.of(context, rootNavigator: true);
  nav.pushAndRemoveUntil(flowRoute<void>(const HomeShell()), (_) => false);
  HaruToast.show(nav.context, '오늘의 질문이 기다리고 있어요.');
}

/// Text sent with "공유하기" / "초대 링크 보내기".
String inviteMessage(String familyName, String code) =>
    '하루한번에서 ‘$familyName’ 가족과 매일 편지를 나눠요.\n앱에서 ‘가족 참여하기’를 누르고 코드 $code 를 입력해 주세요.';

/// Opens the system share sheet; [toast] shows once something was sent
/// (prototype: "가족 코드를 공유했어요." / "초대 링크를 보냈어요.").
Future<void> shareInvite(BuildContext context, String familyName, String code, String toast) async {
  final box = context.findRenderObject() as RenderBox?;
  final r = await SharePlus.instance.share(
    ShareParams(
      text: inviteMessage(familyName, code),
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
  if (r.status == ShareResultStatus.success && context.mounted) HaruToast.show(context, toast);
}

/// The floating family letter at the top of both completion screens.
class _FamilyLetter extends StatelessWidget {
  const _FamilyLetter();

  @override
  Widget build(BuildContext context) {
    return Entrance(
      kind: EntranceKind.popIn,
      duration: const Duration(milliseconds: 520),
      child: FloatLoop(
        delay: const Duration(milliseconds: 600),
        // Explicit height: RenderImage's intrinsic height uses the available
        // width, which would make the IntrinsicHeight column overshoot.
        child: SizedBox(
          width: 210,
          height: 210 * 1122 / 1402,
          child: Image.asset(HaruImages.familyLetter, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// 만들기 완료 — the family code to pass around.
class FamilyCreatedScreen extends StatelessWidget {
  const FamilyCreatedScreen({super.key, required this.familyName, required this.code});

  final String familyName;
  final String code;

  @override
  Widget build(BuildContext context) {
    final title = '$familyName 가족';
    return PopScope(
      canPop: false,
      child: FlowScaffold(
        builder: (context, minHeight, shift) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 100 + shift, 28, 40),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _FamilyLetter(),
                  const SizedBox(height: 18),
                  Text(
                    // "가족" ends with a final consonant, so it is always 이.
                    '‘$title’이\n만들어졌어요!',
                    textAlign: TextAlign.center,
                    style: hr(29, color: HaruColors.forest, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아래 코드를 가족에게 보내면\n같은 편지를 함께 받을 수 있어요',
                    textAlign: TextAlign.center,
                    style: hr(15, color: HaruColors.inkMuted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  HrCard(
                    padding: const EdgeInsets.all(18),
                    radius: 18,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Text('가족 코드', style: hr(14.5, color: HaruColors.inkMuted)),
                          const SizedBox(height: 2),
                          Text(code, style: hrHand(37, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: CopyCodeButton(code: code)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (ctx) => Pressable(
                                    onTap: () => shareInvite(ctx, familyName, code, '가족 코드를 공유했어요.'),
                                    semanticLabel: '공유하기',
                                    child: Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: HaruColors.mint,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Symbols.share_rounded, size: 18, color: HaruColors.forest),
                                          const SizedBox(width: 4),
                                          Text('공유하기', style: hr(15, color: HaruColors.forest)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  PrimaryButton(label: '♥ 시작하기 ♥', onPressed: () => _enterHome(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 참여 완료 — welcome card with the members.
class FamilyJoinedScreen extends StatefulWidget {
  const FamilyJoinedScreen({super.key, required this.familyName});

  final String familyName;

  @override
  State<FamilyJoinedScreen> createState() => _FamilyJoinedScreenState();
}

class _FamilyJoinedScreenState extends State<FamilyJoinedScreen> {
  FamilySnapshot? _fam;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await FamilyContext.instance.refresh();
      if (mounted) setState(() => _fam = f);
    } catch (_) {
      // The welcome card works without the member row.
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _fam?.members ?? const [];
    return PopScope(
      canPop: false,
      child: FlowScaffold(
        builder: (context, minHeight, shift) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 110 + shift, 28, 40),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _FamilyLetter(),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HaruColors.welcome,
                      border: Border.all(color: HaruColors.hairline),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text('${widget.familyName} 가족', textAlign: TextAlign.center, style: hrHand(28)),
                        const SizedBox(height: 4),
                        Text('에 오신 걸 환영해요!', textAlign: TextAlign.center, style: hr(20)),
                        if (members.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final m in members)
                                Container(
                                  decoration: m.isMe
                                      ? BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: const [
                                            BoxShadow(color: HaruColors.forest, spreadRadius: 3.5),
                                            BoxShadow(color: HaruColors.cream, spreadRadius: 2),
                                          ],
                                        )
                                      : null,
                                  child: MemberAvatar(member: m, size: 44, fontSize: 15, hand: true),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          '오늘 03:00에 도착한 질문부터 함께 답해요',
                          textAlign: TextAlign.center,
                          style: hr(14, color: HaruColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  PrimaryButton(label: '♥ 시작하기 ♥', onPressed: () => _enterHome(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
