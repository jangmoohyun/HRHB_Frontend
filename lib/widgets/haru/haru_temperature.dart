import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_decor.dart';
import 'haru_overlays.dart';
import 'pressable.dart';

/// Parses the server's "#RRGGBB" status color.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

// ─────────────────────────────────────────────────────────────────────────────
// TemperatureGauge (가족 탭)
// ─────────────────────────────────────────────────────────────────────────────

/// `TemperatureGauge` — meadow background, thermal arc, heart + figure,
/// speech bubble and the "어제보다 …" line. Sizes follow the design system
/// with `s` = 402.
class TemperatureGauge extends StatelessWidget {
  const TemperatureGauge({
    super.key,
    required this.temperature,
    required this.statusLabel,
    required this.bubbleText,
    required this.delta,
    this.accent = HaruColors.warmIcon,
    this.width = 362,
    this.height = 380,
  });

  final double temperature;
  final String statusLabel;
  final String bubbleText;
  final double delta;
  final Color accent;
  final double width;
  final double height;

  static const s = 402.0;

  @override
  Widget build(BuildContext context) {
    final w = width, h = height;
    final arcBoxW = w - s * .04, arcBoxH = h * .82;
    final arcSize = math.min(arcBoxW, arcBoxH);
    final down = delta < 0, flat = delta.abs() < .05;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    HaruImages.ondoBackground,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.16), // center 42%
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HaruColors.ivory,
                          Color(0x00FFFCF6),
                          Color(0x00FFFCF6),
                          Color(0x99FFFCF6),
                          HaruColors.ivory,
                        ],
                        stops: [0, .1, .78, .9, 1],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: const [
                          HaruColors.ivory,
                          Color(0x00FFFCF6),
                          Color(0x00FFFCF6),
                          HaruColors.ivory,
                        ],
                        stops: [0, s * .06 / w, 1 - s * .06 / w, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: s * .02,
            right: s * .02,
            top: h * .1,
            height: arcBoxH - h * .08,
            // display:flex; justify-content:center — the square keeps its own
            // size and overflows the box (centered) instead of stretching.
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: arcSize,
              maxWidth: arcSize,
              minHeight: arcSize,
              maxHeight: arcSize,
              child: SizedBox(
                width: arcSize,
                height: arcSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size.square(arcSize),
                      painter: _GaugeArcPainter(progress: temperature / 100),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: arcSize * .3,
                      child: Column(
                        children: [
                          Image.asset(HaruImages.middleHeart, width: s * .13),
                          SizedBox(height: s * .004),
                          Text(
                            '${temperature.toStringAsFixed(1)}°C',
                            style: hrHand(
                              s * .125,
                              color: accent,
                              weight: FontWeight.w800,
                              height: 1,
                              letterSpacing: -.5,
                            ),
                          ),
                          SizedBox(height: s * .01),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: s * .04, vertical: s * .01),
                            decoration: BoxDecoration(
                              color: const Color(0xE0FFFFFF),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: accent, width: 1.4),
                            ),
                            child: Text(statusLabel, style: hr(s * .034, color: accent)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(left: 0, top: 0, width: s * .15, child: Image.asset(HaruImages.sun)),
          Positioned(
            right: 0,
            top: s * .015,
            child: _SpeechBubble(text: bubbleText, maxWidth: s * .48),
          ),
          Positioned(
            left: 0,
            top: s * .14,
            width: s * .12,
            child: Transform.rotate(angle: .2, child: Image.asset(HaruImages.leftHeart1)),
          ),
          Positioned(
            left: s * .01,
            top: h * .66,
            width: s * .105,
            child: Image.asset(HaruImages.leftHeart2),
          ),
          Positioned(
            right: -s * .04,
            top: h * .68,
            width: s * .27,
            child: Image.asset(HaruImages.rightHeart1),
          ),
          Positioned(
            right: -s * .01,
            top: h * .18,
            width: s * .1125,
            child: Image.asset(HaruImages.rightHeart2),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: h * .1,
            child: Text.rich(
              flat
                  ? const TextSpan(text: '어제와 비슷해요')
                  : TextSpan(children: [
                      const TextSpan(text: '어제보다 '),
                      TextSpan(
                        text: '${delta.abs().toStringAsFixed(1)}°C',
                        style: const TextStyle(color: HaruColors.tempDelta),
                      ),
                      TextSpan(text: down ? ' 내려갔어요!' : ' 올라갔어요!'),
                    ]),
              textAlign: TextAlign.center,
              style: hr(s * .034, color: HaruColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  _GaugeArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sz = size.width;
    final stroke = sz * .068;
    final c = Offset(sz / 2, sz * .52);
    final r = sz * .45 - stroke * .5;
    const gap = 95 * math.pi / 180;
    const start = math.pi / 2 + gap / 2;
    const sweep = 2 * math.pi - gap;
    const n = 120;
    final rect = Rect.fromCircle(center: c, radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint.from(base)
        ..color = HaruColors.gaugeTrack
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < n; i++) {
      final t0 = i / n, t1 = (i + 1) / n;
      canvas.drawArc(
        rect,
        start + sweep * t0,
        sweep * (t1 - t0) + .004,
        false,
        Paint.from(base)
          ..color = thermalAt((t0 + t1) / 2)
          ..strokeCap = i == 0 || i == n - 1 ? StrokeCap.round : StrokeCap.butt,
      );
    }
    final a = start + sweep * progress.clamp(0.0, 1.0);
    final k = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(k, stroke * .48, Paint()..color = Colors.white);
    canvas.drawCircle(
      k,
      stroke * .48,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x21E05A45),
    );
  }

  @override
  bool shouldRepaint(_GaugeArcPainter old) => old.progress != progress;
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: _BubbleTailPainter(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
          decoration: BoxDecoration(
            color: HaruColors.yellow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: hr(maxWidth * .058, color: HaruColors.inkSoft, height: 1.1),
          ),
        ),
      ),
    );
  }
}

/// SVG tail `M22 0 L16 7 L34 0Z` in a 100×7 box stretched to the bubble.
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final path = Path()
      ..moveTo(22 * sx, size.height)
      ..lineTo(16 * sx, size.height + 7)
      ..lineTo(34 * sx, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = HaruColors.yellow);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// TemperaturePopup (온도 상승/하락)
// ─────────────────────────────────────────────────────────────────────────────

/// The prototype layer: dim rgba(0,0,0,.45) `hrFade 260ms ease-out`, the
/// popup rendered `inline` (no entrance of its own) inside it.
Future<void> showTemperaturePopup(BuildContext context, {required double delta}) {
  return Navigator.of(context, rootNavigator: true).push(
    HaruOverlayRoute<void>(
      dim: HaruColors.dimPopup,
      fade: const Duration(milliseconds: 260),
      inner: Duration.zero,
      innerCurve: Curves.linear,
      innerTransition: (_, child) => child,
      builder: (ctx) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: TemperaturePopup(
            rise: delta >= 0,
            delta: delta.abs(),
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    ),
  );
}

class TemperaturePopup extends StatefulWidget {
  const TemperaturePopup({
    super.key,
    required this.rise,
    required this.delta,
    required this.onClose,
    this.width = 340,
  });

  final bool rise;
  final double delta;
  final VoidCallback onClose;
  final double width;

  @override
  State<TemperaturePopup> createState() => _TemperaturePopupState();
}

class _TemperaturePopupState extends State<TemperaturePopup> with TickerProviderStateMixin {
  // One clock per keyframe set so the delays line up with the CSS.
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final _rain = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final _num = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _num.forward();
    });
  }

  @override
  void dispose() {
    for (final c in [_spin, _twinkle, _float, _drift, _rain, _num]) {
      c.dispose();
    }
    super.dispose();
  }

  /// `50% { … }` keyframes: 0 → 1 → 0 over the cycle, ease-in-out.
  double _wave(AnimationController c, [double delayFrac = 0]) {
    final t = (c.value - delayFrac) % 1;
    final half = t < .5 ? t * 2 : (1 - t) * 2;
    return Curves.easeInOut.transform(half);
  }

  @override
  Widget build(BuildContext context) {
    final rise = widget.rise, w = widget.width;
    final d = widget.delta.toStringAsFixed(1);
    final sign = rise ? '+' : '−';
    final acc = rise ? HaruColors.cta : const Color(0xFF4A7FB5);
    final soft = rise ? const Color(0xFFFFF4DC) : const Color(0xFFE9F0F7);
    final line = rise ? const Color(0xFFF0DDB4) : const Color(0xFFC9D9EA);
    // Positioning box of the art panel: the popup is border-box with a 1px
    // border and 20px padding; the panel is content-box (height w*.5 inside
    // its own 1px border).
    final artW = w - 2 - 40 - 2, artH = w * .5;

    Widget art() => AnimatedBuilder(
          animation: Listenable.merge([_spin, _twinkle, _float, _drift, _rain]),
          builder: (_, _) {
            Widget twinkle(String asset, double left, double phase) {
              final k = _wave(_twinkle, phase);
              return Positioned(
                left: artW * left,
                top: artH * .08,
                width: artW * .09,
                child: Opacity(
                  opacity: 1 - .65 * k,
                  child: Transform.scale(scale: 1 - .15 * k, child: Image.asset(asset)),
                ),
              );
            }

            Widget thermometer(String asset, double dy) => Positioned(
                  left: artW / 2 - w * .085,
                  top: artH * .12,
                  height: artH * .78,
                  child: Transform.translate(offset: Offset(0, dy), child: Image.asset(asset)),
                );

            Widget drop(String asset, double right, double top, double delay) {
              final t = (_rain.value - delay / 1.4) % 1;
              // ease-in per keyframe segment: opacity 0→30%→100%,
              // transform only at 0% and 100%.
              final e = Curves.easeIn.transform(t);
              final op = t < .3
                  ? Curves.easeIn.transform(t / .3)
                  : 1 - Curves.easeIn.transform((t - .3) / .7);
              return Positioned(
                right: artW * right,
                top: artH * top,
                width: artW * .06,
                child: Opacity(
                  opacity: op.clamp(0, 1),
                  child: Transform.translate(offset: Offset(0, -6 + 20 * e), child: Image.asset(asset)),
                ),
              );
            }

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: rise
                  ? [
                      Positioned(
                        right: artW * .08,
                        top: artH * .1,
                        width: artW * .22,
                        child: Transform.rotate(
                          angle: _spin.value * 2 * math.pi,
                          child: Image.asset(HaruImages.sun),
                        ),
                      ),
                      twinkle(HaruImages.upLeft, .33, 0),
                      twinkle(HaruImages.upRight, .58, .5 / 1.8),
                      Positioned(
                        left: artW * .10,
                        bottom: artH * .14,
                        width: artW * .09,
                        child: Transform.translate(
                          offset: Offset(0, -6 * _wave(_float, .4 / 3)),
                          child: Image.asset(HaruImages.rightHeart2),
                        ),
                      ),
                      thermometer(HaruImages.upThermometer, -6 * _wave(_float)),
                    ]
                  : [
                      Positioned(
                        right: artW * .06,
                        top: artH * .08,
                        width: artW * .30,
                        child: Transform.translate(
                          offset: Offset(-6 * _wave(_drift), 0),
                          child: Image.asset(HaruImages.downCloud),
                        ),
                      ),
                      drop(HaruImages.downRain1, .22, .42, 0),
                      drop(HaruImages.downRain2, .13, .48, .5),
                      thermometer(HaruImages.downThermometer, 0),
                    ],
            );
          },
        );

    return Container(
      width: w,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: HaruColors.cream,
        border: Border.all(color: HaruColors.hairline),
        borderRadius: BorderRadius.circular(24),
        boxShadow: HaruShadows.popup,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
                decoration: BoxDecoration(
                  color: HaruColors.mint,
                  borderRadius: BorderRadius.circular(HaruRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SproutIcon(size: 14),
                    const SizedBox(width: 5),
                    Text('가족 온도 소식', style: hr(14, color: HaruColors.forest)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('어제보다', style: hr(16, color: HaruColors.inkMuted)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedBuilder(
                    animation: _num,
                    builder: (_, c) {
                      final e = HaruMotion.standard.transform(_num.value);
                      return Opacity(
                        opacity: e,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - e)),
                          child: Transform.scale(scale: .9 + .1 * e, child: c),
                        ),
                      );
                    },
                    child: Text('$sign$d°C',
                        style: hr(44, color: acc, weight: FontWeight.w800, height: 1, letterSpacing: -1)),
                  ),
                  const SizedBox(width: 8),
                  Text(rise ? '올랐어요!' : '내려갔어요', style: hr(24)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: artH + 2,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: line),
                ),
                clipBehavior: Clip.antiAlias,
                child: art(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: HaruColors.ivory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HaruColors.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rise ? '온도가 따뜻해졌어요' : '오늘은 조금 조용했어요',
                              style: hr(15.5, color: HaruColors.forest)),
                          const SizedBox(height: 2),
                          Text('오늘의 변화 · 어제 대비', style: hr(13.5, color: HaruColors.inkMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$sign$d°C', style: hr(20, color: acc, weight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Image.asset(rise ? HaruImages.upArrow : HaruImages.downArrow,
                        width: 22, height: 22, fit: BoxFit.contain),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  rise ? '오늘도 따뜻한 하루 보내세요 ♥' : '오늘 가족에게 한 마디 건네볼까요?',
                  style: hr(15),
                ),
              ),
              const SizedBox(height: 12),
              // <button> with cursor:pointer and no transition: the page-wide
              // press only (scale .95 + brightness .96, 140ms).
              Pressable(
                onTap: widget.onClose,
                scale: 1,
                duration: Duration.zero,
                inlineTransition: false,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: HaruColors.forest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('확인', style: hr(17, color: Colors.white)),
                      const SizedBox(width: 6),
                      const SproutIcon(size: 15, white: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Pressable(
              onTap: widget.onClose,
              scale: 1,
              duration: Duration.zero,
              inlineTransition: false,
              semanticLabel: '닫기',
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Symbols.close_rounded, size: 24, color: HaruColors.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
