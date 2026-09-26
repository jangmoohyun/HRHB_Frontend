import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';

/// Design-system `Avatar` — tinted circle with one initial and an optional
/// answered dot (components/core/Avatar.jsx).
class HaruAvatar extends StatelessWidget {
  const HaruAvatar({
    super.key,
    required this.initial,
    required this.tint,
    this.size = 36,
    this.answered,
    this.ringColor,
    this.ringWidth = 2,
  });

  final String initial;
  final Color tint;
  final double size;

  /// null hides the dot; true = green, false = faint.
  final bool? answered;

  /// Stacked avatars in the prototype draw `box-shadow: 0 0 0 Npx <bg>`.
  final Color? ringColor;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.3 < 10 ? 10.0 : size * 0.3;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial.characters.take(1).toString(),
        style: haruText(
          (size * 0.4).roundToDouble(),
          weight: FontWeight.w700,
          color: HaruColors.dsInkSecondary,
          height: 1,
          letterSpacing: size * 0.4 * -0.02,
        ),
      ),
    );
    return Container(
      decoration: ringColor == null
          ? null
          : BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor!, width: ringWidth),
            ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circle,
            if (answered != null)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: answered!
                        ? HaruColors.statusPositive
                        : HaruColors.dsInkFaint,
                    border: Border.all(color: HaruColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping avatars (CSS `margin-left: -Npx`). Later children draw on top,
/// matching DOM order. [itemSize] is each child's outer width incl. any ring.
class HaruAvatarStack extends StatelessWidget {
  const HaruAvatarStack({
    super.key,
    required this.children,
    required this.overlap,
    required this.itemSize,
  });

  final List<Widget> children;
  final double overlap;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final step = itemSize - overlap;
    return SizedBox(
      width: itemSize + step * (children.length - 1),
      height: itemSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < children.length; i++)
            Positioned(left: step * i, top: 0, child: children[i]),
        ],
      ),
    );
  }
}

/// Circle with a short role word ("아빠", "딸") — used on the answer list and
/// the join-complete card.
class ShortAvatar extends StatelessWidget {
  const ShortAvatar({
    super.key,
    required this.text,
    required this.tint,
    this.size = 32,
    this.fontSize = 10,
    this.ringColor,
    this.opacity = 1,
  });

  final String text;
  final Color tint;
  final double size;
  final double fontSize;
  final Color? ringColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size + (ringColor == null ? 0 : 4),
        height: size + (ringColor == null ? 0 : 4),
        decoration: BoxDecoration(
          color: tint,
          shape: BoxShape.circle,
          border: ringColor == null
              ? null
              : Border.all(color: ringColor!, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: haruText(
            fontSize,
            weight: FontWeight.w700,
            color: HaruColors.dsInkSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

enum HaruBadgeTone { primary, neutral, solid, night }

/// Design-system `Badge` (components/core/Badge.jsx).
class HaruBadge extends StatelessWidget {
  const HaruBadge(this.text, {super.key, this.tone = HaruBadgeTone.primary});

  final String text;
  final HaruBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (tone) {
      HaruBadgeTone.primary =>
        (HaruColors.surface, HaruColors.primary, HaruColors.hairline),
      HaruBadgeTone.neutral =>
        (HaruColors.canvasSoft, HaruColors.dsInkMuted, Colors.transparent),
      HaruBadgeTone.solid =>
        (HaruColors.primary, HaruColors.onPrimary, Colors.transparent),
      HaruBadgeTone.night =>
        (HaruColors.surface, HaruColors.primary, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(HaruRadius.full),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: haruText(
          12,
          weight: FontWeight.w600,
          color: fg,
          height: 1.33,
          letterSpacing: 0.125,
        ),
      ),
    );
  }
}

/// Design-system `Switch` — 36×20 track, 16px knob.
class HaruSwitch extends StatelessWidget {
  const HaruSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Opacity(
          opacity: onChanged == null ? 0.5 : 1,
          child: AnimatedContainer(
            duration: HaruMotion.base,
            width: 36,
            height: 20,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? HaruColors.primary : const Color(0x1F000000),
              borderRadius: BorderRadius.circular(HaruRadius.full),
            ),
            child: AnimatedAlign(
              duration: HaruMotion.base,
              curve: HaruMotion.standard,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: HaruShadows.s1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The prototype's input: 48px tall, 4px radius, `--input-border`, and on
/// focus a primary border plus `--shadow-1`.
class HaruTextField extends StatefulWidget {
  const HaruTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.height = 48,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
    this.letterSpacing,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.helper,
    this.helperIcon,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.fillColor,
    this.textColor,
    this.forceFocusStyle = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;

  /// null lets multiline fields grow with [minLines]/[maxLines].
  final double? height;
  final double fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String? helper;
  final IconData? helperIcon;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final Color? fillColor;
  final Color? textColor;

  /// Dialog inputs are drawn already-focused in the prototype.
  final bool forceFocusStyle;

  @override
  State<HaruTextField> createState() => _HaruTextFieldState();
}

class _HaruTextFieldState extends State<HaruTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus || widget.forceFocusStyle;
    final multiline = widget.maxLines == null || widget.maxLines! > 1;
    final field = AnimatedContainer(
      duration: HaruMotion.fast,
      height: multiline ? null : widget.height,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: multiline ? 12 : 0,
      ),
      alignment: multiline ? null : Alignment.center,
      decoration: BoxDecoration(
        color: widget.fillColor ?? HaruColors.surface,
        borderRadius: BorderRadius.circular(HaruRadius.xs),
        border: Border.all(
          color: focused ? HaruColors.primary : HaruColors.inputBorder,
        ),
        boxShadow: focused ? HaruShadows.s1 : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        maxLength: widget.maxLength,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        minLines: widget.minLines,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textAlign: widget.textAlign,
        cursorColor: HaruColors.primary,
        style: haruText(
          widget.fontSize,
          weight: widget.fontWeight,
          color: widget.textColor ?? HaruColors.dsInk,
          height: multiline ? 1.6 : 1.2,
          letterSpacing: widget.letterSpacing,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          counterText: '',
          hintText: widget.hint,
          hintStyle: haruText(
            widget.fontSize,
            weight: widget.fontWeight,
            color: HaruColors.dsInkFaint,
            height: multiline ? 1.6 : 1.2,
            letterSpacing: widget.letterSpacing,
          ),
        ),
      ),
    );

    if (widget.label == null && widget.helper == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: HaruType.fieldLabel),
          const SizedBox(height: 6),
        ],
        field,
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.helperIcon != null) ...[
                Icon(widget.helperIcon, size: 14, color: HaruColors.dsInkMuted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.helper!,
                  style: haruText(13, color: HaruColors.dsInkMuted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Inline validation message: 14px `--status-attention` with circle-alert.
class HaruFieldError extends StatelessWidget {
  const HaruFieldError(this.message, {super.key, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: HaruColors.statusAttention),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: haruText(14, color: HaruColors.statusAttention),
          ),
        ),
      ],
    );
  }
}

/// A button styled like an input that opens a picker ("나의 역할", "출생 순서").
class HaruSelectField extends StatelessWidget {
  const HaruSelectField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    required this.trailingIcon,
    this.label,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: HaruColors.surface,
          borderRadius: BorderRadius.circular(HaruRadius.xs),
          border: Border.all(color: HaruColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: haruText(
                  16,
                  color: value == null ? HaruColors.dsInkFaint : HaruColors.dsInk,
                ),
              ),
            ),
            Icon(trailingIcon, size: 20, color: HaruColors.dsInkMuted),
          ],
        ),
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label!, style: HaruType.fieldLabel),
        const SizedBox(height: 6),
        box,
      ],
    );
  }
}
