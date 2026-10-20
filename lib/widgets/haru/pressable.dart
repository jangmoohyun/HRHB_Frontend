import 'package:flutter/material.dart';

/// Press feedback used everywhere in the prototype instead of ripples.
///
/// Two layers, exactly like the prototype's CSS:
///
/// * the element's own `style-active` transform — [scale], animated by the
///   element's `transition: transform …` ([duration] / [curve]; pass
///   [Duration.zero] when the element has no transform transition);
/// * the page-wide rule every `cursor: pointer` element gets:
///   `[style*="cursor: pointer"]:active { scale: .95; filter: brightness(.96) }`.
///   The CSS `scale` property multiplies with the transform, so a
///   `style-active="transform:scale(.95)"` element ends at .95 × .95.
///   Elements without any inline `transition` ease into it over
///   140ms cubic-bezier(.2,0,0,1); elements with one ([inlineTransition])
///   switch instantly.
///
/// [brightness] is the pressed `filter: brightness()` (.96 from the global
/// rule, or the element's own `style-active` filter).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.ease,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.brightness = 0.96,
    this.inlineTransition = true,
    this.cursorActive = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final Curve curve;
  final HitTestBehavior behavior;
  final String? semanticLabel;
  final double brightness;

  /// The element has an inline `transition` (so the global `scale`/`filter`
  /// change is instant instead of 140ms).
  final bool inlineTransition;

  /// Apply the global `cursor: pointer` `:active` rule (scale .95).
  final bool cursorActive;

  @override
  State<Pressable> createState() => _PressableState();
}

/// `filter: brightness(.96)` 140ms / `scale` 140ms cubic-bezier(.2,0,0,1).
const _activeCurve = Cubic(0.2, 0, 0, 1);
const _activeDuration = Duration(milliseconds: 140);

class _PressableState extends State<Pressable> {
  bool _down = false;
  final _childKey = GlobalKey();

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final activeDur = widget.inlineTransition ? Duration.zero : _activeDuration;
    Widget body = KeyedSubtree(key: _childKey, child: widget.child);
    body = TweenAnimationBuilder<double>(
      tween: Tween(end: _down ? widget.brightness : 1),
      duration: activeDur,
      curve: _activeCurve,
      child: body,
      builder: (_, b, c) => b == 1 ? c! : ColorFiltered(colorFilter: brightnessFilter(b), child: c),
    );
    if (widget.cursorActive) {
      body = AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: activeDur,
        curve: _activeCurve,
        child: body,
      );
    }
    final child = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: widget.duration,
        curve: widget.curve,
        child: body,
      ),
    );
    if (widget.semanticLabel == null) return child;
    return Semantics(button: true, label: widget.semanticLabel, child: child);
  }
}

/// CSS `filter: brightness(b)` — RGB × b, alpha untouched.
ColorFilter brightnessFilter(double b) => ColorFilter.matrix(<double>[
      b, 0, 0, 0, 0, //
      0, b, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
