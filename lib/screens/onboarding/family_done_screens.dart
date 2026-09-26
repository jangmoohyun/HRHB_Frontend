import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import '../shell/home_shell.dart';

void _enterHome(BuildContext context) {
  PushNotificationService.instance.registerCurrentDevice();
  FamilyContext.instance.refresh().ignore();
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    (_) => false,
  );
}

/// 10 가족 코드 안내.
class FamilyCreatedScreen extends StatelessWidget {
  const FamilyCreatedScreen({super.key, required this.familyName, required this.code});

  final String familyName;
  final String code;

  @override
  Widget build(BuildContext context) {
    const steps = [
      '가족에게 코드를 보내요.',
      "가족이 앱에서 '초대 코드로 참여하기'를 눌러요.",
      '코드를 입력하면 함께할 수 있어요.',
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HaruColors.canvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            children: [
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: HaruColors.accentGreen, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check, size: 28, color: HaruColors.dsInkSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${quotedWithSubjectParticle(familyName)} 만들어졌어요',
                    textAlign: TextAlign.center,
                    style: haruText(26, weight: FontWeight.w700, letterSpacing: -0.5, color: HaruColors.dsInk),
                  ),
                  const SizedBox(height: 12),
                  Text('아래 코드를 가족에게 보내 주세요.', style: haruText(15, color: HaruColors.dsInkMuted)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: HaruColors.surface,
                  borderRadius: BorderRadius.circular(HaruRadius.xl),
                  boxShadow: HaruShadows.s1,
                ),
                child: Column(
                  children: [
                    Text('가족 코드', style: haruText(12, weight: FontWeight.w600, color: HaruColors.dsInkMuted)),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        code,
                        style: haruText(37, weight: FontWeight.w700, letterSpacing: 8, color: HaruColors.dsInk),
                      ),
                    ),
                    const SizedBox(height: 16),
                    HaruButton(
                      label: '복사하기',
                      icon: LucideIcons.copy,
                      variant: HaruButtonVariant.utility,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          HaruToast.show(context, '가족 코드가 복사되었어요', icon: LucideIcons.copy);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              HaruOutlineCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가족이 참여하는 방법',
                      style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk),
                    ),
                    for (var i = 0; i < steps.length; i++) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: HaruColors.canvasSoft,
                              shape: BoxShape.circle,
                              border: Border.all(color: HaruColors.hairline),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: haruText(12, weight: FontWeight.w700, color: HaruColors.dsInk, height: 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: haruText(15, height: 1.5, color: HaruColors.dsInkSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: HaruColors.fillTranslucent,
                  borderRadius: BorderRadius.circular(HaruRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.lightbulb, size: 18, color: HaruColors.dsInkSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      // Prototype says "홈의 가족 정보"; in VER2 the code lives on the 가족 tab.
                      child: Text(
                        '코드는 가족 탭에서 언제든 다시 볼 수 있어요.',
                        style: haruText(14, color: HaruColors.dsInkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              HaruButton(
                label: '확인',
                size: HaruButtonSize.lg,
                fullWidth: true,
                onPressed: () => _enterHome(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 12 참여 완료.
class FamilyJoinedScreen extends StatefulWidget {
  const FamilyJoinedScreen({super.key, required this.familyName, required this.roleLabel});

  final String familyName;
  final String roleLabel;

  @override
  State<FamilyJoinedScreen> createState() => _FamilyJoinedScreenState();
}

class _FamilyJoinedScreenState extends State<FamilyJoinedScreen> {
  FamilySnapshot? _fam;

  @override
  void initState() {
    super.initState();
    FamilyContext.instance.refresh().then((f) {
      if (mounted) setState(() => _fam = f);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final members = _fam?.members ?? const [];
    Widget kv(String k, String v) => Row(
          children: [
            Expanded(child: Text(k, style: haruText(14, color: HaruColors.dsInkMuted))),
            Text(v, style: haruText(14, weight: FontWeight.w600, color: HaruColors.dsInk)),
          ],
        );
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HaruColors.canvas,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 72),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(color: HaruColors.accentButter, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.partyPopper, size: 30, color: HaruColors.dsInkSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "'${widget.familyName}'에\n참여했어요",
                          textAlign: TextAlign.center,
                          style: haruText(26, weight: FontWeight.w700, letterSpacing: -0.5, color: HaruColors.dsInk),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '오늘 밤 첫 질문이 도착하면 알려 드릴게요.',
                          style: haruText(15, color: HaruColors.dsInkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    HaruOutlineCard(
                      child: Column(
                        children: [
                          kv('가족 이름', widget.familyName),
                          const SizedBox(height: 14),
                          kv('나의 역할', widget.roleLabel),
                          const SizedBox(height: 14),
                          const SizedBox(height: 1, child: ColoredBox(color: HaruColors.hairline)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              HaruAvatarStack(
                                overlap: 8,
                                itemSize: 36,
                                children: [
                                  for (final m in members)
                                    ShortAvatar(text: m.short, tint: m.tint, ringColor: HaruColors.surface),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fam?.countText ?? '',
                                style: haruText(14, color: HaruColors.dsInkMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    HaruButton(
                      label: '시작하기',
                      size: HaruButtonSize.lg,
                      fullWidth: true,
                      onPressed: () => _enterHome(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
