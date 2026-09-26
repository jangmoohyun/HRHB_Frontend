import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_basics.dart';
import 'haru_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Toast — replaces the 101 unstyled SnackBars (design-system Toast.jsx).
// ─────────────────────────────────────────────────────────────────────────────

abstract final class HaruToast {
  /// Incremented while the home tab bar is on screen so toasts clear it
  /// (prototype: `toastBottom` 96px with tab bar, 40px without).
  static int tabBarDepth = 0;

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = LucideIcons.check,
    Color iconColor = HaruColors.statusPositive,
    double? bottom,
  }) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;
    _timer?.cancel();
    _entry?.remove();

    final resolvedBottom = bottom ?? (tabBarDepth > 0 ? 96.0 : 40.0);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 16,
        right: 16,
        bottom: resolvedBottom,
        child: IgnorePointer(
          child: Center(
            child: _ToastCard(message: message, icon: icon, iconColor: iconColor),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.iconColor,
  });

  final String message;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    // hxToast: translateY(16px)→0 + fade, .32s cubic-bezier(.2,1.4,.4,1)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: HaruMotion.pop,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: HaruColors.surface,
            borderRadius: BorderRadius.circular(HaruRadius.lg),
            boxShadow: HaruShadows.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(message, style: haruText(15, color: HaruColors.dsInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheets
// ─────────────────────────────────────────────────────────────────────────────

enum HaruSheetStyle {
  /// Titled sheet: surface, top radius 16, handle 36×4 (일지 작성 등).
  standard,

  /// Streak celebration: white, top radius 24, handle 40×4.
  streak,

  /// Year/month picker: canvas background, top radius 12.
  yearMonth,

  /// Option list ("나는 우리 가족의?"): surface, top radius 16.
  picker,
}

Future<T?> showHaruSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  HaruSheetStyle style = HaruSheetStyle.standard,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: HaruColors.dim,
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      curve: HaruMotion.sheet,
      reverseDuration: Duration(milliseconds: 240),
    ),
    builder: (ctx) => _HaruSheetFrame(style: style, title: title, builder: builder),
  );
}

class _HaruSheetFrame extends StatelessWidget {
  const _HaruSheetFrame({
    required this.style,
    required this.title,
    required this.builder,
  });

  final HaruSheetStyle style;
  final String? title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final (Color bg, double radius, EdgeInsets pad, double handleW, Color handleC,
        double handleGap, List<BoxShadow>? shadow) = switch (style) {
      HaruSheetStyle.standard => (
          HaruColors.surface,
          16.0,
          const EdgeInsets.fromLTRB(20, 8, 20, 36),
          36.0,
          HaruColors.hairline,
          8.0,
          HaruShadows.s2,
        ),
      HaruSheetStyle.streak => (
          Colors.white,
          24.0,
          const EdgeInsets.fromLTRB(24, 10, 24, 36),
          40.0,
          HaruColors.handle,
          0.0,
          null,
        ),
      HaruSheetStyle.yearMonth => (
          HaruColors.canvas,
          12.0,
          const EdgeInsets.fromLTRB(20, 10, 20, 36),
          40.0,
          HaruColors.handleYm,
          4.0,
          null,
        ),
      HaruSheetStyle.picker => (
          HaruColors.surface,
          16.0,
          const EdgeInsets.fromLTRB(12, 8, 12, 36),
          36.0,
          HaruColors.hairline,
          12.0,
          HaruShadows.s2,
        ),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            boxShadow: shadow,
          ),
          child: SingleChildScrollView(
            padding: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: handleW,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleC,
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                    ),
                  ),
                ),
                SizedBox(height: handleGap),
                if (style == HaruSheetStyle.standard && title != null) ...[
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: haruText(
                              20,
                              weight: FontWeight.w700,
                              color: HaruColors.dsInk,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        HaruIconButton(
                          icon: LucideIcons.x,
                          label: '닫기',
                          size: 36,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                builder(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Option list sheet. Returns the chosen index.
Future<int?> showHaruPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  int? selected,
}) {
  return showHaruSheet<int>(
    context,
    style: HaruSheetStyle.picker,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(
            title,
            style: haruText(18, weight: FontWeight.w700, color: HaruColors.dsInk),
          ),
        ),
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(i),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        options[i],
                        style: haruText(
                          16,
                          weight: i == selected ? FontWeight.w600 : FontWeight.w400,
                          color: i == selected ? HaruColors.primary : HaruColors.dsInk,
                        ),
                      ),
                    ),
                    if (i == selected)
                      const Icon(LucideIcons.check, size: 20, color: HaruColors.primary),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────────────────────────────────────

/// Shared entry animation (hxDialog): scale .92→1 + fade, .3s pop curve.
Future<T?> _showHaruModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsets padding = const EdgeInsets.all(24),
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: '닫기',
    barrierColor: HaruColors.dim,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(type: MaterialType.transparency, child: builder(ctx)),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: HaruMotion.pop);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showHaruModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsets padding = const EdgeInsets.all(24),
  bool barrierDismissible = true,
}) =>
    _showHaruModal<T>(
      context,
      builder: builder,
      padding: padding,
      barrierDismissible: barrierDismissible,
    );

/// Confirm dialog. Returns true when the confirm button was pressed.
Future<bool> showHaruConfirm(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool danger = false,
  bool showCancel = true,
}) async {
  final result = await _showHaruModal<bool>(
    context,
    builder: (ctx) => _DialogCard(
      title: title,
      body: body,
      actions: [
        if (showCancel)
          HaruButton(
            label: '취소',
            variant: HaruButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        if (showCancel) const SizedBox(width: 8),
        danger
            ? _DangerButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              )
            : HaruButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-input dialog ("새 앨범", "앨범 이름 바꾸기", "가족 이름 바꾸기").
/// Returns the trimmed text, or null when cancelled.
Future<String?> showHaruInputDialog(
  BuildContext context, {
  required String title,
  String? body,
  String initialValue = '',
  String hint = '',
  required String confirmLabel,
  int? maxLength,
}) {
  return _showHaruModal<String>(
    context,
    builder: (ctx) => _InputDialog(
      title: title,
      body: body,
      initialValue: initialValue,
      hint: hint,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.body,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
    required this.maxLength,
  });

  final String title;
  final String? body;
  final String initialValue;
  final String hint;
  final String confirmLabel;
  final int? maxLength;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _controller.text.trim().isEmpty;
    return _DialogCard(
      title: widget.title,
      body: widget.body,
      input: HaruTextField(
        controller: _controller,
        hint: widget.hint,
        autofocus: true,
        forceFocusStyle: true,
        maxLength: widget.maxLength,
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
        },
      ),
      actions: [
        HaruButton(
          label: '취소',
          variant: HaruButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        HaruButton(
          label: widget.confirmLabel,
          onPressed:
              empty ? null : () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.title,
    this.body,
    this.input,
    required this.actions,
  });

  final String title;
  final String? body;
  final Widget? input;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HaruColors.surface,
        borderRadius: BorderRadius.circular(HaruRadius.lg),
        boxShadow: HaruShadows.s2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: haruText(
              20,
              weight: FontWeight.w700,
              color: HaruColors.dsInk,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 12),
            Text(
              body!,
              style: haruText(15, color: HaruColors.dsInkSecondary, height: 1.55),
            ),
          ],
          if (input != null) ...[
            const SizedBox(height: 12),
            input!,
          ],
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaruColors.statusAttention,
          borderRadius: BorderRadius.circular(HaruRadius.full),
        ),
        child: Text(
          label,
          style: haruText(16, weight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }
}
