import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/login_screen.dart';
import 'family_form_screen.dart';

/// 08 가족 선택.
class FamilySelectScreen extends StatelessWidget {
  const FamilySelectScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } catch (_) {}
    await TokenStorage().clear();
    FamilyContext.instance.clear();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: HaruButton(
                    label: '로그아웃',
                    variant: HaruButtonVariant.ghost,
                    size: HaruButtonSize.sm,
                    onPressed: () => _logout(context),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('가족과 함께\n시작해 볼까요?', style: HaruType.headline),
                  const SizedBox(height: 8),
                  Text(
                    '가족 그룹을 새로 만들거나, 받은 코드로 참여해요.',
                    style: haruText(15, color: HaruColors.dsInkMuted),
                  ),
                  const SizedBox(height: 32),
                  _Choice(
                    band: HaruColors.accentGreen,
                    icon: LucideIcons.housePlus,
                    title: '새 가족 만들기',
                    description: '가족 그룹을 만들고 초대 코드를 받아요',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const FamilyFormScreen(joining: false)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Choice(
                    band: HaruColors.accentSky,
                    icon: LucideIcons.keyRound,
                    title: '초대 코드로 참여하기',
                    description: '가족에게 받은 6자리 코드를 입력해요',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const FamilyFormScreen(joining: true)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.band,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Color band;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HaruColors.surface,
          border: Border.all(color: HaruColors.hairline),
          borderRadius: BorderRadius.circular(HaruRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              height: 84,
              color: band,
              child: Center(child: Icon(icon, size: 32, color: HaruColors.dsInkSecondary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: haruText(18, weight: FontWeight.w700, color: HaruColors.dsInk)),
                        const SizedBox(height: 4),
                        Text(description, style: haruText(14, color: HaruColors.dsInkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.chevronRight, size: 20, color: HaruColors.dsInkFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
