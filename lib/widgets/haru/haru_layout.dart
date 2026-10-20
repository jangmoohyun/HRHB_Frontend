import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_decor.dart';
import 'pressable.dart';

/// Ivory card with the hairline border (radius 16, padding 16 by default).
class HrCard extends StatelessWidget {
  const HrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.color = HaruColors.ivory,
    this.borderColor = HaruColors.hairline,
    this.borderWidth = 1,
    this.shadow,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// Tab screen title: "우리 가족 일지" (23, forest) + sprout + optional line.
/// The DS `SproutIcon` is placed without a size, so it renders at its
/// default 18 (the template's hint-size is only a placeholder hint).
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: HaruType.tabTitle),
        const SizedBox(height: 2),
        const SproutIcon(size: 18),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: hr(14.5, color: HaruColors.inkMuted)),
        ],
      ],
    );
  }
}

/// Sub-page header: 52 tall, 44px back target, centered 21px title.
///
/// The back button's press defaults to the common
/// `transition:transform 200ms ease` + `scale(.95)`; 설정 and the policy
/// pages pass their own ([BackChevron]).
class SubHeader extends StatelessWidget {
  const SubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.backScale = .95,
    this.backDuration = const Duration(milliseconds: 200),
    this.backInlineTransition = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double backScale;
  final Duration backDuration;
  final bool backInlineTransition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          BackChevron(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            scale: backScale,
            duration: backDuration,
            inlineTransition: backInlineTransition,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaruType.pageTitle,
            ),
          ),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

/// 44×44 `arrow_back_ios_new` (22, forest).
class BackChevron extends StatelessWidget {
  const BackChevron({
    super.key,
    required this.onTap,
    this.scale = .95,
    this.duration = const Duration(milliseconds: 200),
    this.inlineTransition = true,
  });

  final VoidCallback onTap;

  /// [Pressable.scale] / [Pressable.duration] / [Pressable.inlineTransition].
  final double scale;
  final Duration duration;
  final bool inlineTransition;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: scale,
      duration: duration,
      inlineTransition: inlineTransition,
      semanticLabel: '뒤로',
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Symbols.arrow_back_ios_new_rounded, size: 22, color: HaruColors.forest),
      ),
    );
  }
}

/// Group caption above a settings card: icon 17 soft green + 14 muted text.
class SectionCaption extends StatelessWidget {
  const SectionCaption({super.key, required this.icon, required this.label, this.top = 22});

  final IconData icon;
  final String label;

  /// margin-top (22, or 8 for the first group on 설정).
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: HaruColors.softGreen),
          const SizedBox(width: 6),
          Text(label, style: hr(14, color: HaruColors.inkMuted)),
        ],
      ),
    );
  }
}

/// "🌱 이번 달 참여" — sprout (DS default 18) + forest label.
class SproutHeading extends StatelessWidget {
  const SproutHeading(this.label, {super.key, this.size = 16});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SproutIcon(size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: hr(size, color: HaruColors.forest))),
      ],
    );
  }
}

/// Settings list row: 52 tall, icon 20 soft green, 16px label, hairline
/// under every row but the last.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.chevron = true,
    this.color,
    this.iconColor,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool chevron;
  final Color? color;
  final Color? iconColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      height: 52,
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: HaruColors.hairline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? HaruColors.softGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: hr(16, color: color ?? HaruColors.ink))),
          if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
          if (chevron)
            const Icon(Symbols.chevron_right_rounded, size: 18, color: HaruColors.inkMuted),
        ],
      ),
    );
    if (onTap == null) return row;
    // style-active scale(.96) + brightness(.96); the rows have no transition.
    return Pressable(
      scale: 0.96,
      duration: Duration.zero,
      inlineTransition: false,
      onTap: onTap,
      semanticLabel: label,
      child: row,
    );
  }
}

/// CSS `zoom` for the 글자 크기 setting: lays [child] out at size / [zoom]
/// and paints it scaled, so text *and* layout grow together the way the
/// prototype's `zoom` on the scroll area does.
class ZoomBox extends StatelessWidget {
  const ZoomBox({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (zoom == 1) return child;
    return LayoutBuilder(
      builder: (context, c) {
        final mq = MediaQuery.of(context);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: c.maxWidth / zoom,
            maxWidth: c.maxWidth / zoom,
            minHeight: c.maxHeight / zoom,
            maxHeight: c.maxHeight / zoom,
            child: Transform.scale(
              scale: zoom,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: mq.copyWith(
                  size: mq.size / zoom,
                  padding: mq.padding / zoom,
                  viewPadding: mq.viewPadding / zoom,
                  viewInsets: mq.viewInsets / zoom,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Left-edge swipe → back, for pages pushed inside the tab navigators (the
/// fade-up transition has no interactive back gesture of its own).
class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({super.key, required this.child, this.onBack});

  final Widget child;
  final VoidCallback? onBack;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dx = 0,
            onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
            onHorizontalDragEnd: (d) {
              if (_dx > 70 || (d.primaryVelocity ?? 0) > 600) {
                (widget.onBack ?? () => Navigator.of(context).maybePop())();
              }
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance animations (the prototype's @keyframes)
// ─────────────────────────────────────────────────────────────────────────────

enum EntranceKind {
  /// hrFadeUp — opacity + translateY(10px), 420ms (.33,1,.68,1).
  fadeUp,

  /// hrRiseIn — opacity + translateY(14px), 500ms (.2,0,0,1).
  riseIn,

  /// hrUpA — opacity + translateY(10px), 450ms (.2,0,0,1).
  up,

  /// hrPop / hrPopA — scale .6 → 1.06 (70%) → 1 with fade.
  pop,

  /// hrPopIn — opacity + scale(.94), 240–520ms (.33,1,.68,1).
  popIn,

  /// hrStamp — scale(1.9) rotate(-14deg) → none, fading to [targetOpacity].
  stamp,

  /// hrGrow — scaleX 0 → 1 from the left, 1s (.3,0,.1,1).
  grow,

  /// hrFade — opacity only.
  fade,
}

/// Plays one of the prototype's entrance keyframes once, after [delay],
/// with `animation-fill-mode: both` (hidden until it starts).
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.kind = EntranceKind.fadeUp,
    this.delay = Duration.zero,
    this.duration,
    this.curve,
    this.targetOpacity = 1,
  });

  final Widget child;
  final EntranceKind kind;
  final Duration delay;
  final Duration? duration;
  final Curve? curve;
  final double targetOpacity;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;

  Duration get _defaultDuration => switch (widget.kind) {
        EntranceKind.fadeUp => HaruMotion.screen,
        EntranceKind.riseIn => const Duration(milliseconds: 500),
        EntranceKind.up => const Duration(milliseconds: 450),
        EntranceKind.pop => const Duration(milliseconds: 450),
        EntranceKind.popIn => const Duration(milliseconds: 280),
        EntranceKind.stamp => const Duration(milliseconds: 400),
        EntranceKind.grow => const Duration(milliseconds: 1000),
        EntranceKind.fade => HaruMotion.fade,
      };

  Curve get _curve =>
      widget.curve ??
      switch (widget.kind) {
        EntranceKind.fadeUp || EntranceKind.popIn => HaruMotion.out,
        EntranceKind.grow => HaruMotion.grow,
        EntranceKind.fade => Curves.easeOut,
        _ => HaruMotion.standard,
      };

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration ?? _defaultDuration);
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// CSS applies the timing function per keyframe segment.
  double _seg(double t, double a, double b) => _curve.transform(((t - a) / (b - a)).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        switch (widget.kind) {
          case EntranceKind.fadeUp:
          case EntranceKind.riseIn:
          case EntranceKind.up:
            final e = _curve.transform(t);
            final dy = widget.kind == EntranceKind.riseIn ? 14.0 : 10.0;
            return Opacity(
              opacity: e.clamp(0, 1),
              child: Transform.translate(offset: Offset(0, dy * (1 - e)), child: child),
            );
          case EntranceKind.pop:
            final double scale, op;
            if (t <= .7) {
              final e = _seg(t, 0, .7);
              scale = .6 + (1.06 - .6) * e;
              op = e;
            } else {
              final e = _seg(t, .7, 1);
              scale = 1.06 + (1 - 1.06) * e;
              op = 1;
            }
            return Opacity(
              opacity: op.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            );
          case EntranceKind.popIn:
            final e = _curve.transform(t);
            return Opacity(
              opacity: e.clamp(0, 1),
              child: Transform.scale(scale: .94 + .06 * e, child: child),
            );
          case EntranceKind.stamp:
            final e = _curve.transform(t);
            return Opacity(
              opacity: (widget.targetOpacity * e).clamp(0, 1),
              child: Transform.rotate(
                angle: -14 * math.pi / 180 * (1 - e),
                child: Transform.scale(scale: 1.9 - .9 * e, child: child),
              ),
            );
          case EntranceKind.grow:
            final e = _curve.transform(t);
            return Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.diagonal3Values(e, 1, 1),
              child: child,
            );
          case EntranceKind.fade:
            return Opacity(opacity: _curve.transform(t).clamp(0, 1), child: child);
        }
      },
    );
  }
}

/// Stagger helper: `animation-delay: calc(i * step + base)`.
Duration stagger(int i, int stepMs, [int baseMs = 0]) =>
    Duration(milliseconds: i * stepMs + baseMs);

/// Endless vertical bob: `hrFloat` (3s, −7px) / `hrBob` (2.4s, −6px).
/// `0%,100% { none } 50% { translateY(-d) }`, ease-in-out.
class FloatLoop extends StatefulWidget {
  const FloatLoop({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 3),
    this.distance = 7,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  final Widget child;
  final Duration period;
  final double distance;
  final Duration delay;
  final bool enabled;

  @override
  State<FloatLoop> createState() => _FloatLoopState();
}

class _FloatLoopState extends State<FloatLoop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FloatLoop old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (!widget.enabled) {
      _c.stop();
      _c.value = 0;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = _c.value;
        final k = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
        return Transform.translate(offset: Offset(0, -widget.distance * k), child: child);
      },
    );
  }
}
