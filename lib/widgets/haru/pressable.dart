import 'package:flutter/material.dart';

/// Press-scale feedback used everywhere in the prototype instead of ripples.
///
/// VER2 custom buttons use `transform: scale(0.95)` over 200ms `ease`;
/// design-system buttons use `--press-scale` 0.9 over 120ms. Callers pick.
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
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final Curve curve;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
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
        child: widget.child,
      ),
    );
    if (widget.semanticLabel == null) return child;
    return Semantics(button: true, label: widget.semanticLabel, child: child);
  }
}
