import 'package:flutter/material.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';

enum HaruButtonVariant { primary, secondary, utility, ghost, link, onNight }

enum HaruButtonSize { sm, md, lg }

/// Design-system `Button` (components/core/Button.jsx).
///
/// Pill variants (primary / secondary / onNight) scale to `--press-scale` 0.9
/// on press; utility / ghost use an 8px radius and change fill instead.
class HaruButton extends StatefulWidget {
  const HaruButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = HaruButtonVariant.primary,
    this.size = HaruButtonSize.md,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final HaruButtonVariant variant;
  final HaruButtonSize size;
  final bool fullWidth;
  final IconData? icon;
  final bool loading;

  /// Overrides the label color (e.g. the red "삭제" text button).
  final Color? color;

  bool get _enabled => onPressed != null && !loading;

  @override
  State<HaruButton> createState() => _HaruButtonState();
}

class _HaruButtonState extends State<HaruButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!widget._enabled || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final isPill = v == HaruButtonVariant.primary ||
        v == HaruButtonVariant.secondary ||
        v == HaruButtonVariant.onNight;

    // Utility buttons always use the `sm` metrics.
    final size = v == HaruButtonVariant.utility ? HaruButtonSize.sm : widget.size;
    final EdgeInsets padding;
    final double fontSize;
    switch (size) {
      case HaruButtonSize.sm:
        padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4);
        fontSize = 15;
      case HaruButtonSize.md:
        padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8);
        fontSize = 16;
      case HaruButtonSize.lg:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        fontSize = 16;
    }

    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadow;
    switch (v) {
      case HaruButtonVariant.primary:
        bg = _pressed ? HaruColors.primaryActive : HaruColors.primary;
        fg = HaruColors.onPrimary;
      case HaruButtonVariant.secondary:
        bg = HaruColors.surface;
        fg = HaruColors.dsInk;
        shadow = HaruShadows.s1;
      case HaruButtonVariant.utility:
        bg = _pressed ? HaruColors.canvasSoft : HaruColors.surface;
        fg = HaruColors.dsInk;
        border = Border.all(color: HaruColors.hairline);
      case HaruButtonVariant.ghost:
        bg = _pressed ? HaruColors.fillTranslucent : Colors.transparent;
        fg = HaruColors.dsInk;
      case HaruButtonVariant.link:
        bg = Colors.transparent;
        fg = HaruColors.primary;
      case HaruButtonVariant.onNight:
        bg = HaruColors.surface;
        fg = HaruColors.dsInk;
        shadow = HaruShadows.s2;
    }
    if (widget.color != null) fg = widget.color!;

    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: haruText(fontSize, weight: FontWeight.w500, color: fg),
    );

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
      );
    } else if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      );
    } else {
      content = label;
    }

    final box = AnimatedContainer(
      duration: HaruMotion.fast,
      curve: HaruMotion.standard,
      constraints: BoxConstraints(
        minHeight: size == HaruButtonSize.lg ? 48 : 0,
        minWidth: widget.fullWidth ? double.infinity : 0,
      ),
      padding: v == HaruButtonVariant.link ? EdgeInsets.zero : padding,
      decoration: BoxDecoration(
        color: bg,
        border: border ?? Border.all(color: Colors.transparent),
        borderRadius:
            BorderRadius.circular(isPill ? HaruRadius.full : HaruRadius.md),
        boxShadow: shadow,
      ),
      alignment: widget.fullWidth ? Alignment.center : null,
      child: content,
    );

    return Semantics(
      button: true,
      enabled: widget._enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget._enabled ? widget.onPressed : null,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: Opacity(
          opacity: widget.onPressed == null ? 0.4 : 1,
          child: AnimatedScale(
            scale: _pressed && isPill ? 0.9 : 1,
            duration: HaruMotion.fast,
            curve: HaruMotion.standard,
            child: widget.fullWidth
                ? SizedBox(width: double.infinity, child: box)
                : box,
          ),
        ),
      ),
    );
  }
}

enum HaruIconButtonVariant { ghost, translucent, onNight, surface }

/// Design-system `IconButton` (components/core/IconButton.jsx).
class HaruIconButton extends StatefulWidget {
  const HaruIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.variant = HaruIconButtonVariant.ghost,
    this.size = 40,
    this.iconSize,
    this.color,
    this.pressScale = 0.9,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final HaruIconButtonVariant variant;
  final double size;

  /// Defaults to half of [size] like the DS component; VER2 custom headers
  /// pass 24 inside a 40 box.
  final double? iconSize;
  final Color? color;
  final double pressScale;

  @override
  State<HaruIconButton> createState() => _HaruIconButtonState();
}

class _HaruIconButtonState extends State<HaruIconButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onPressed == null || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    List<BoxShadow>? shadow;
    switch (widget.variant) {
      case HaruIconButtonVariant.ghost:
        bg = _pressed ? HaruColors.fillTranslucent : Colors.transparent;
        fg = HaruColors.dsInk;
      case HaruIconButtonVariant.translucent:
        bg = HaruColors.fillTranslucent;
        fg = HaruColors.dsInk;
      case HaruIconButtonVariant.onNight:
        bg = Colors.white.withValues(alpha: 0.6);
        fg = HaruColors.onSecondary;
      case HaruIconButtonVariant.surface:
        bg = HaruColors.surface;
        fg = HaruColors.dsInk;
        shadow = HaruShadows.s1;
    }
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _pressed ? widget.pressScale : 1,
          duration: HaruMotion.fast,
          curve: HaruMotion.standard,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: shadow,
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize ?? (widget.size * 0.5).roundToDouble(),
              color: widget.color ?? fg,
            ),
          ),
        ),
      ),
    );
  }
}
