import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_family.dart';
import 'haru_layout.dart';
import 'haru_overlays.dart';
import 'pressable.dart';

/// `Button variant="primary"` — 48.9 tall, radius 16, CTA green,
/// `--fs-body` 16.884 / 700.
///
/// Disabled turns the fill to rgba(47,143,78,.45) like the design system.
/// [loading] puts the prototype's spinner in front of the label.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 48.9,
    this.color = HaruColors.cta,
    this.radius = 16,
    this.fontSize = 16.884,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final Color color;
  final double radius;
  final double fontSize;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final bg = disabled ? HaruColors.ctaDisabled : widget.color;
    // HTML collapses runs of spaces ("♥  시작하기  ♥" renders one space).
    final label = widget.label.replaceAll(RegExp(r'\s+'), ' ');
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapUp: _enabled ? (_) => _set(false) : null,
        onTapCancel: _enabled ? () => _set(false) : null,
        onTap: _enabled ? widget.onPressed : null,
        // The page-wide `[style*="cursor: pointer"]:active { scale: .95 }`
        // (beats `button:active { scale: .97 }`); the button's own
        // transition doesn't list `scale`, so it snaps.
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: Duration.zero,
          // The runtime wraps every x-import in `.sc-host-x`, so the page's
          // `.sc-host-x>button:active { transform: scale(.96) }` applies too,
          // eased by the button's own `transform 120ms`.
          child: AnimatedScale(
            scale: _down ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.ease,
            // onPointerDown → filter: brightness(.94), transition
            // filter var(--dur-ui) var(--ease-out-cubic).
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _down ? 0.94 : 1),
              duration: const Duration(milliseconds: 280),
              curve: const Cubic(.215, .61, .355, 1),
              builder: (_, b, c) => ColorFiltered(colorFilter: brightnessFilter(b), child: c),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.loading) ...[
                      const HaruSpinner(),
                      // span margin-right 8 + the button's flex gap 8
                      const SizedBox(width: 16),
                    ],
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: hr(widget.fontSize, color: Colors.white)),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
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

/// The prototype's inline spinner: a 16px content box with a 2.4px
/// rgba(255,255,255,.4) border (content-box, so 20.8 outside) and a white
/// top border, `hrSpin` 700ms linear.
class HaruSpinner extends StatefulWidget {
  const HaruSpinner({super.key, this.size = 20.8, this.color = Colors.white});

  /// Outer size including the border.
  final double size;
  final Color color;

  @override
  State<HaruSpinner> createState() => _HaruSpinnerState();
}

class _HaruSpinnerState extends State<HaruSpinner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _RingPainter(widget.color)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.4;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, 6.283, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: 0.4));
    canvas.drawArc(r, -2.356, 1.571, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

/// The 44×26 switch: `transition: background 200ms` (ease); the knob jumps
/// (justify-content isn't animatable). Pressed: style-active
/// scale(.96) + brightness(.96) with no transform transition.
class HaruSwitch extends StatelessWidget {
  const HaruSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        scale: 0.96,
        duration: Duration.zero,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? HaruColors.cta : HaruColors.lineGrey,
            borderRadius: BorderRadius.circular(HaruRadius.full),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: HaruShadows.knob,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field: 52 tall, ivory, 1.4px #C5D9B8 border, radius 14, focus border
/// 1.6px #7FA87A. Inputs keep the browser's regular weight (400).
class HaruTextField extends StatefulWidget {
  const HaruTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.height = 52,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.focusNode,
    this.borderColor = HaruColors.fieldBorder,
    this.borderWidth = 1.4,
    this.autofillHints,
    this.maxLength,
    this.horizontalPadding = 16,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final double height;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final FocusNode? focusNode;
  final Color borderColor;
  final double borderWidth;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  /// `padding: 0 16px` (the 새 앨범 dialog input uses 14).
  final double horizontalPadding;

  @override
  State<HaruTextField> createState() => _HaruTextFieldState();
}

class _HaruTextFieldState extends State<HaruTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final style = widget.style ?? hr(17, weight: FontWeight.w400);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: HaruColors.ivory,
        borderRadius: BorderRadius.circular(HaruRadius.md),
        border: Border.all(
          color: focused ? HaruColors.softGreen : widget.borderColor,
          width: focused ? 1.6 : widget.borderWidth,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
      alignment: Alignment.center,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        inputFormatters: [
          if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
          ...?widget.inputFormatters,
        ],
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        textAlign: widget.textAlign,
        style: style,
        cursorColor: HaruColors.forest,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.placeholder,
          hintStyle: style.copyWith(color: HaruColors.placeholder),
        ),
      ),
    );
  }
}

/// Multi-line field (답장, 문의, 일지). Same look as [HaruTextField].
class HaruTextArea extends StatefulWidget {
  const HaruTextArea({
    super.key,
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.minHeight = 130,
    this.maxLength,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.fontSize = 16,
    this.lineHeight = 1.5,
    this.focusNode,
    this.overlay,
    this.fixedHeight = false,
    this.borderColor = HaruColors.fieldBorder,
    this.borderWidth = 1.4,
  });

  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final double minHeight;
  final int? maxLength;
  final EdgeInsets padding;
  final double fontSize;
  final double lineHeight;
  final FocusNode? focusNode;

  /// Decoration drawn inside the field (the sprout in 답장 쓰기).
  final Widget? overlay;

  /// `height` instead of `min-height` (문의하기 textarea is 130 fixed).
  final bool fixedHeight;

  /// Idle border (일지 sheet uses 1.6px #7FA87A all the time).
  final Color borderColor;
  final double borderWidth;

  @override
  State<HaruTextArea> createState() => _HaruTextAreaState();
}

class _HaruTextAreaState extends State<HaruTextArea> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final style = hr(widget.fontSize, weight: FontWeight.w400, height: widget.lineHeight);
    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      maxLines: widget.fixedHeight ? null : null,
      expands: widget.fixedHeight,
      minLines: widget.fixedHeight ? null : 1,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      inputFormatters: [
        if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: style,
      cursorColor: HaruColors.forest,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: HaruColors.placeholder),
      ),
    );
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Container(
        constraints: widget.fixedHeight
            ? BoxConstraints.tightFor(height: widget.minHeight)
            : BoxConstraints(minHeight: widget.minHeight),
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          borderRadius: BorderRadius.circular(HaruRadius.md),
          border: Border.all(
            color: focused ? HaruColors.softGreen : widget.borderColor,
            width: focused ? 1.6 : widget.borderWidth,
          ),
        ),
        child: Stack(
          children: [
            if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
            Padding(padding: widget.padding, child: field),
          ],
        ),
      ),
    );
  }
}

/// Selectable chip (role, birth order, inquiry category, archive segment …).
///
/// Selected: forest fill + white text. Idle: ivory + forest text +
/// #C5D9B8 border. Role chips: `transition: background 200ms` (border and
/// text colour switch instantly), style-active scale(.96) + brightness(.96)
/// with no transform transition. Birth-order chips pass
/// [animateBackground] false, [pressScale] .95 and [pressDuration] 200ms
/// (`transition: transform 200ms ease`, style-active scale(.95)).
class ChoiceChipBox extends StatelessWidget {
  const ChoiceChipBox({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 46,
    this.radius = 14,
    this.fontSize = 17,
    this.padding = EdgeInsets.zero,
    this.expand = true,
    this.pressScale = 0.96,
    this.pressDuration = Duration.zero,
    this.animateBackground = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final EdgeInsets padding;
  final bool expand;
  final double pressScale;
  final Duration pressDuration;
  final bool animateBackground;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Pressable(
      scale: pressScale,
      duration: pressDuration,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(
            color: selected ? HaruColors.forest : HaruColors.fieldBorder,
            width: 1.4,
          ),
        ),
        child: AnimatedContainer(
          duration: animateBackground ? const Duration(milliseconds: 200) : Duration.zero,
          curve: Curves.ease,
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? HaruColors.forest : HaruColors.ivory,
            borderRadius: r,
          ),
          alignment: expand ? Alignment.center : null,
          // Not expanded: hug the label's width, still centred vertically.
          child: Center(
            widthFactor: expand ? null : 1,
            child: Text(
              label,
              style: hr(fontSize, color: selected ? Colors.white : HaruColors.forest),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round member avatar showing the role word ("아빠", "나").
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 34,
    this.fontSize = 13.5,
    this.hand = false,
    this.border,
    this.ring,
  });

  final MemberLook member;
  final double size;
  final double fontSize;

  /// Names in the family card/member list use `--font-hand`.
  final bool hand;
  final Border? border;

  /// box-shadow ring (0 0 0 2px #FFFCF6).
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: member.tint,
        shape: BoxShape.circle,
        border: border,
        boxShadow: ring == null ? null : [BoxShadow(color: ring!, spreadRadius: 2)],
      ),
      alignment: Alignment.center,
      child: Text(
        member.short,
        maxLines: 1,
        style: hand ? hrHand(fontSize) : hr(fontSize, color: HaruColors.forest),
      ),
    );
  }
}

/// "코드 복사" — copies, then turns green with a check for 1.6s
/// (prototype `cp`). Used on 만들기 완료, 가족 초대하기 and the 가족 tab.
///
/// Pill (가족 tab): `transition: background/color/border-color 250ms ease,
/// transform 200ms ease`, style-active scale(.92). 만들기 완료:
/// `transform 200ms ease, background 220ms, color 220ms`, scale(.95).
/// 가족 초대하기 sheet: `background 220ms, color 220ms` and scale(.96) with no
/// transform transition — pass [pressScale] .96 and [pressDuration] zero.
class CopyCodeButton extends StatefulWidget {
  const CopyCodeButton({
    super.key,
    required this.code,
    this.height = 42,
    this.radius = 14,
    this.fontSize = 15,
    this.iconSize = 18,
    this.pill = false,
    this.idleColor = HaruColors.ivory,
    this.onCopied,
    this.pressScale,
    this.pressDuration,
  });

  final String code;
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;

  /// The 가족 tab's outlined pill (min-width 76, heart floats up).
  final bool pill;
  final Color idleColor;

  /// Lets the caller highlight the code while "복사됐어요" shows.
  final ValueChanged<bool>? onCopied;

  /// style-active scale (default .92 pill / .95) and its transition
  /// (default 200ms ease).
  final double? pressScale;
  final Duration? pressDuration;

  @override
  State<CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<CopyCodeButton> {
  bool _on = false;
  int _tick = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _on = true;
      _tick++;
    });
    widget.onCopied?.call(true);
    HaruToast.show(context, '가족 코드가 복사되었어요.');
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _on = false);
      widget.onCopied?.call(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = _on ? Colors.white : HaruColors.forest;
    final colorDur = Duration(milliseconds: widget.pill ? 250 : 220);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The icon gets its colour inline, so it switches instantly.
        Entrance(
          key: ValueKey(_tick),
          kind: _on ? EntranceKind.pop : EntranceKind.fade,
          duration: _on ? const Duration(milliseconds: 420) : Duration.zero,
          child: Icon(
            _on ? Symbols.check_rounded : Symbols.content_copy_rounded,
            size: widget.iconSize,
            color: fg,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedDefaultTextStyle(
          duration: colorDur,
          curve: Curves.ease,
          style: hr(widget.fontSize, color: fg),
          child: Text(_on ? '복사됐어요' : '코드 복사'),
        ),
      ],
    );
    return Pressable(
      onTap: _copy,
      scale: widget.pressScale ?? (widget.pill ? .92 : .95),
      duration: widget.pressDuration ?? const Duration(milliseconds: 200),
      semanticLabel: '가족 코드 복사',
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: colorDur,
            curve: Curves.ease,
            height: widget.height,
            constraints: widget.pill ? const BoxConstraints(minWidth: 76) : null,
            padding: widget.pill ? const EdgeInsets.symmetric(horizontal: 12) : null,
            decoration: BoxDecoration(
              color: _on ? HaruColors.cta : widget.idleColor,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.pill
                  ? Border.all(color: _on ? HaruColors.cta : HaruColors.fieldBorder)
                  : null,
            ),
            alignment: Alignment.center,
            child: content,
          ),
          if (_on && widget.pill)
            Positioned(
              top: -6,
              child: _RisingHeart(key: ValueKey('h$_tick')),
            ),
        ],
      ),
    );
  }
}

/// hrRise 1.2s cubic-bezier(.33,1,.68,1): `0% { opacity 0; translateY(6px) }
/// 18% { opacity 1 } 100% { opacity 0; translateY(-34px) }`. The timing
/// function runs per keyframe segment, so opacity eases over 0–18% and
/// 18–100% while the transform eases once over the whole run.
class _RisingHeart extends StatelessWidget {
  const _RisingHeart({super.key});

  @override
  Widget build(BuildContext context) {
    const curve = HaruMotion.out;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      builder: (_, u, c) {
        final op = u < .18 ? curve.transform(u / .18) : 1 - curve.transform((u - .18) / .82);
        return Opacity(
          opacity: op.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, 6 - 40 * curve.transform(u)), child: c),
        );
      },
      child: SizedBox(
        width: 40,
        child: Text('♥', textAlign: TextAlign.center, style: hr(12, color: HaruColors.cta)),
      ),
    );
  }
}
