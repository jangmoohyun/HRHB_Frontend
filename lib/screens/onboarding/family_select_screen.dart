import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/auth_scaffold.dart';
import '../login/login_screen.dart';
import 'family_form_screen.dart';

/// 가족 선택 — 가족 만들기 / 가족 참여하기.
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
      flowRoute<void>(const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: FlowScaffold(
        // Not in the mockup, but without it someone with no family has no way
        // back to the login screen.
        back: Align(
          alignment: Alignment.centerRight,
          child: Pressable(
            onTap: () => _logout(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('로그아웃', style: hr(14, color: HaruColors.inkMuted)),
            ),
          ),
        ),
        builder: (context, minHeight, shift) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 120 + shift),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Entrance(
                            kind: EntranceKind.pop,
                            duration: const Duration(milliseconds: 520),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: HaruColors.mint,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const SproutIcon(),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xEBFDFBF0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '우리 가족과\n하루한번을 시작해요',
                                  textAlign: TextAlign.center,
                                  style: hr(30, color: HaruColors.forest, height: 1.3),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '처음이라면 가족을 만들고,\n코드를 받았다면 참여해요',
                                  textAlign: TextAlign.center,
                                  style: hr(15, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _Choice(
                    tile: HaruColors.mint,
                    icon: Symbols.group_add_rounded,
                    iconColor: HaruColors.forest,
                    title: '가족 만들기',
                    description: '새 가족을 만들고 코드를 나눠요',
                    onTap: () => Navigator.of(context).push(
                      flowRoute<void>(const FamilyCreateScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Choice(
                    tile: HaruColors.orange,
                    icon: Symbols.key_rounded,
                    iconColor: HaruColors.orangeInk,
                    title: '가족 참여하기',
                    description: '받은 가족 코드로 들어가요',
                    onTap: () => Navigator.of(context).push(
                      flowRoute<void>(const FamilyJoinScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.tile,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Color tile;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .96,
      duration: Duration.zero,
      inlineTransition: false,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          border: Border.all(color: HaruColors.hairline),
          borderRadius: BorderRadius.circular(18),
          boxShadow: HaruShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: hr(20, color: HaruColors.forest)),
                  const SizedBox(height: 2),
                  Text(description, style: hr(14, color: HaruColors.inkMuted)),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right_rounded, size: 22, color: HaruColors.softGreen),
          ],
        ),
      ),
    );
  }
}
