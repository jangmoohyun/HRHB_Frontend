import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_button.dart';
import 'pressable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Headers
// ─────────────────────────────────────────────────────────────────────────────

/// Pushed-screen header: back button, centered title, optional trailing.
///
/// [ver2] = VER2 screens (알림, 하루 상세): 56px tall, 24px chevron in #2B2016.
/// Otherwise the design-system header (답변 보기, 앨범 상세…): min 52px,
/// DS IconButton with a 20px chevron.
class HaruSubHeader extends StatelessWidget {
  const HaruSubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.ver2 = false,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? trailing;
  final bool ver2;

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.of(context).maybePop();
    if (ver2) {
      return SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              HaruIconButton(
                icon: LucideIcons.chevronLeft,
                label: '뒤로',
                iconSize: 24,
                color: HaruColors.ink,
                pressScale: 0.95,
                onPressed: back,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaruType.headerTitle,
                ),
              ),
              if (trailing == null) const SizedBox(width: 40) else ...trailing!,
            ],
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            HaruIconButton(
              icon: LucideIcons.chevronLeft,
              label: '뒤로',
              onPressed: back,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: haruText(17, weight: FontWeight.w600, color: HaruColors.dsInk),
              ),
            ),
            const SizedBox(width: 4),
            if (trailing == null) const SizedBox(width: 40) else ...trailing!,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surfaces
// ─────────────────────────────────────────────────────────────────────────────

/// White card with `--shadow-1` (VER2 cards: radius 16).
class HaruCard extends StatelessWidget {
  const HaruCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = HaruRadius.xl,
    this.color = HaruColors.card,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: HaruShadows.s1,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, child: box);
  }
}

/// Bordered card (design-system screens): surface + 1px hairline, radius 12.
class HaruOutlineCard extends StatelessWidget {
  const HaruOutlineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = HaruRadius.lg,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: HaruColors.surface,
        border: Border.all(color: HaruColors.hairline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Muted placeholder box: ceramic fill, radius 14 ("이 날 남긴 일지가 없어요").
class CeramicNote extends StatelessWidget {
  const CeramicNote(this.text, {super.key, this.padding = const EdgeInsets.all(20)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: HaruColors.ceramic,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: haruText(14, color: HaruColors.inkSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segment control
// ─────────────────────────────────────────────────────────────────────────────

/// Ceramic track with a white selected pill (기록 탭, 리포트 주간/월간).
class PillSegment<T> extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HaruColors.ceramic,
        borderRadius: BorderRadius.circular(HaruRadius.full),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Pressable(
                onTap: () => onChanged(items[i].$1),
                child: AnimatedContainer(
                  duration: HaruMotion.base,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: items[i].$1 == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                    boxShadow: items[i].$1 == selected ? HaruShadows.s1 : null,
                  ),
                  child: Text(
                    items[i].$2,
                    style: haruText(
                      14,
                      weight: items[i].$1 == selected ? FontWeight.w700 : FontWeight.w500,
                      color: items[i].$1 == selected
                          ? HaruColors.ink
                          : HaruColors.inkTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Half gauge
// ─────────────────────────────────────────────────────────────────────────────

/// Semicircle gauge with a centered value (홈 온도 미니카드, 가족 참여 카드).
///
/// The prototype draws a conic-gradient ring 11px thick and reveals it with
/// `hxSweep` 1.1s cubic-bezier(.3,0,.1,1) after .3s.
class HalfGauge extends StatelessWidget {
  const HalfGauge({
    super.key,
    required this.percent,
    required this.color,
    required this.label,
    this.width = 104,
    this.thickness = 11,
  });

  final double percent; // 0–100
  final Color color;
  final String label;
  final double width;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final h = width / 2;
    return SizedBox(
      width: width,
      height: h + 4,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: h,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: const Interval(0.21, 1, curve: Cubic(0.3, 0, 0.1, 1)),
              builder: (_, t, _) => CustomPaint(
                painter: _HalfGaugePainter(
                  fraction: (percent / 100).clamp(0, 1) * t,
                  color: color,
                  thickness: thickness,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: haruText(18, weight: FontWeight.w700, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfGaugePainter extends CustomPainter {
  _HalfGaugePainter({
    required this.fraction,
    required this.color,
    required this.thickness,
  });

  final double fraction;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(
      center: Offset(r, r),
      radius: r - thickness / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = HaruColors.ceramic;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = color;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    if (fraction > 0) canvas.drawArc(rect, math.pi, math.pi * fraction, false, fill);
  }

  @override
  bool shouldRepaint(_HalfGaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error / loading
// ─────────────────────────────────────────────────────────────────────────────

/// Centered empty state: tinted tile + title + description (+ action).
class HaruEmptyState extends StatelessWidget {
  const HaruEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.tint = HaruColors.fillTranslucent,
    this.iconColor = HaruColors.dsInkSecondary,
    this.tileSize = 52,
    this.tileRadius = 12,
    this.iconSize = 24,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
    this.titleSize = 16,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color tint;
  final Color iconColor;
  final double tileSize;
  final double tileRadius;
  final double iconSize;
  final Widget? action;
  final EdgeInsets padding;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(tileRadius),
            ),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: haruText(titleSize, weight: FontWeight.w600, color: HaruColors.dsInk),
          ),
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: haruText(14, color: HaruColors.dsInkMuted, height: 1.5),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

/// "불러오지 못했어요" with a secondary 다시 시도 button.
class HaruErrorState extends StatelessWidget {
  const HaruErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HaruEmptyState(
      icon: LucideIcons.cloudOff,
      title: '불러오지 못했어요',
      titleSize: 17,
      description: '네트워크 연결을 확인하고\n다시 시도해 주세요.',
      tileSize: 56,
      tileRadius: 28,
      iconSize: 26,
      iconColor: HaruColors.dsInkMuted,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      action: HaruButton(
        label: '다시 시도',
        icon: LucideIcons.rotateCw,
        variant: HaruButtonVariant.secondary,
        onPressed: onRetry,
      ),
    );
  }
}

/// Pulsing skeleton used while a tab's first load is in flight (hxPulse 1.4s).
class HaruSkeleton extends StatefulWidget {
  const HaruSkeleton({super.key});

  @override
  State<HaruSkeleton> createState() => _HaruSkeletonState();
}

class _HaruSkeletonState extends State<HaruSkeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double widthFactor, double h) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: HaruColors.fillTranslucent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: 1 - 0.5 * math.sin(_c.value * math.pi),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Container(
              height: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HaruColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: HaruShadows.s1,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bar(0.4, 12),
                  const SizedBox(height: 12),
                  _bar(0.85, 22),
                  const SizedBox(height: 12),
                  _bar(0.65, 22),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: HaruColors.fillTranslucent,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.6,
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: HaruColors.fillTranslucent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry animations used across the prototype.
///
/// hxRise: translateY(14px)→0 + fade; hxFade: translateY(8px)→0 + fade.
class HaruRise extends StatelessWidget {
  const HaruRise({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: HaruMotion.standard),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}
