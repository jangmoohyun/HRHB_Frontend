import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';

import '../onboarding/family_select_screen.dart';
import '../shell/home_shell.dart';

/// Design-system page used by 이메일 로그인 / 가입 3단계 / 가족 생성·참여.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.children,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 40),
    this.gap = 28,
    this.showBack = true,
    this.headerTrailing,
  });

  final List<Widget> children;

  /// Centered header title (가족 생성/참여). Auth screens leave it empty.
  final String? title;
  final EdgeInsets padding;
  final double gap;
  final bool showBack;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: HaruColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      if (showBack)
                        HaruIconButton(
                          icon: LucideIcons.chevronLeft,
                          label: '뒤로',
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      else
                        const SizedBox(width: 40),
                      Expanded(
                        child: title == null
                            ? const SizedBox()
                            : Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: haruText(17, weight: FontWeight.w600, color: HaruColors.dsInk),
                              ),
                      ),
                      headerTrailing ?? const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: padding,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(height: gap),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 / 3" with three progress bars.
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({super.key, required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$step / 3', style: haruText(12, weight: FontWeight.w600, color: HaruColors.primary)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var n = 1; n <= 3; n++) ...[
              if (n > 1) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: n <= step ? HaruColors.primary : HaruColors.hairline,
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Headline + description block.
class AuthTitle extends StatelessWidget {
  const AuthTitle({super.key, required this.title, this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HaruType.headline),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(description!, style: haruText(15, height: 1.5, color: HaruColors.dsInkMuted)),
        ],
      ],
    );
  }
}

/// Vertical stack with a fixed gap (the prototype's `gap:16px` forms).
class Gap extends StatelessWidget {
  const Gap({super.key, required this.children, this.gap = 16});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

/// After a successful login: family → home, otherwise → 가족 선택.
void goAfterLogin(BuildContext context, {required bool hasFamily}) {
  PushNotificationService.instance.registerCurrentDevice();
  if (hasFamily) FamilyContext.instance.refresh().ignore();
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => hasFamily ? const HomeShell() : const FamilySelectScreen(),
    ),
    (_) => false,
  );
}

/// Link-styled text button ("이메일로 회원가입").
class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HaruButton(label: label, variant: HaruButtonVariant.link, onPressed: onTap);
  }
}
