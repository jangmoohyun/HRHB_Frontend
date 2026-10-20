import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';

/// Watercolor assets (WebP, sized for @3x).
abstract final class HaruImages {
  static const _q = 'assets/images/todayquestionscreen';
  static const letter = '$_q/letter.webp';
  static const letterBranch = '$_q/letterbranch.webp';
  static const letterDesign = '$_q/letterdesign.webp';
  static const todayStamp = '$_q/todayquestiondisplay.webp';
  static const redLine = '$_q/redline2.webp';
  static const redHeart = '$_q/redheart.webp';
  static const dateUnderline = '$_q/dateunderline.webp';
  static const greenHeart = '$_q/greenheart1.webp';
  static const greenHeartSmall = '$_q/greenheart2.webp';
  static const grass = '$_q/grass.webp';
  static const leftBranch = '$_q/left_branch1.webp';
  static const rightBranch = '$_q/right_branch1.webp';
  static const sprout = 'assets/images/public/sprout.webp';

  static const _o = 'assets/images/familyondo';
  static const ondoBackground = '$_o/ondo_background.webp';
  static const middleHeart = '$_o/middle_heart.webp';
  static const sun = '$_o/sun.webp';
  static const leftHeart1 = '$_o/left_heart_1.webp';
  static const leftHeart2 = '$_o/left_heart_2.webp';
  static const rightHeart1 = '$_o/right_heart_1.webp';
  static const rightHeart2 = '$_o/right_heart_2.webp';

  static const _up = 'assets/images/ondo_popup/up_popup';
  static const upLeft = '$_up/ondo_left.webp';
  static const upRight = '$_up/ondo_right.webp';
  static const upThermometer = '$_up/thermometer.webp';
  static const upArrow = '$_up/arrow.webp';
  static const _down = 'assets/images/ondo_popup/down_popup';
  static const downCloud = '$_down/cloud.webp';
  static const downRain1 = '$_down/rain1.webp';
  static const downRain2 = '$_down/rain2.webp';
  static const downThermometer = '$_down/thermameter.webp';
  static const downArrow = '$_down/arrow.webp';

  static const loadingLetter = 'assets/images/loading/letter.webp';
  static const loginLetter = 'assets/images/loginpage/letter/loginletter.webp';
  static const familyLetter = 'assets/images/family/familyjoin/family_letter.webp';

  /// Every image, for precaching on launch.
  static const all = [
    letter, letterBranch, letterDesign, todayStamp, redLine, redHeart,
    dateUnderline, greenHeart, greenHeartSmall, grass, leftBranch, rightBranch,
    sprout, ondoBackground, middleHeart, sun, leftHeart1, leftHeart2,
    rightHeart1, rightHeart2, upLeft, upRight, upThermometer, upArrow,
    downCloud, downRain1, downRain2, downThermometer, downArrow,
    loadingLetter, loginLetter, familyLetter,
  ];
}

/// `SproutIcon` — the little sprout under titles.
class SproutIcon extends StatelessWidget {
  const SproutIcon({super.key, this.size = 18, this.white = false, this.opacity = 1});

  final double size;
  final double opacity;

  /// `filter: brightness(0) invert(1)` — on green buttons.
  final bool white;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(HaruImages.sprout, width: size, height: size, fit: BoxFit.contain);
    if (white) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: img,
      );
    }
    return opacity == 1 ? img : Opacity(opacity: opacity, child: img);
  }
}

/// `SideBranches variant="pair"` — watercolor branches peeking in from both
/// sides. Fills its parent; positions are fractions of the parent box.
class SideBranches extends StatelessWidget {
  const SideBranches({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -0.08 * w,
                    top: 0.12 * h,
                    width: 0.34 * w,
                    child: Image.asset(HaruImages.leftBranch),
                  ),
                  Positioned(
                    right: -0.10 * w,
                    top: 0.16 * h,
                    width: 0.36 * w,
                    child: Image.asset(HaruImages.rightBranch),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Grass strip along the bottom of 홈 (bottom: -6px, full width).
class GrassStrip extends StatelessWidget {
  const GrassStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: -6,
      child: IgnorePointer(child: Image.asset(HaruImages.grass, fit: BoxFit.fitWidth)),
    );
  }
}

/// 1.2px dashed rule: 5px dash, 4px gap (`Divider` Dash).
class DashLine extends StatelessWidget {
  const DashLine({
    super.key,
    this.color = HaruColors.softGreen,
    this.thickness = 1.2,
    this.dash = 5,
    this.gap = 4,
  });

  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(color, thickness, dash, gap)),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.thickness, this.dash, this.gap);
  final Color color;
  final double thickness, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, math.min(dash, size.width - x), thickness), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.thickness != thickness;
}

/// A dashed border box (heat-calendar future days, "남기기" weather tile,
/// font-size preview). Draws a rounded dashed outline over [child].
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.color = HaruColors.fieldBorder,
    this.radius = 12,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color, radius, strokeWidth, dash, gap),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius, this.strokeWidth, this.dash, this.gap);
  final Color color;
  final double radius, strokeWidth, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(math.max(0, radius - inset)),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// `Divider variant="heart"` — dashes with a small green heart.
class HeartDivider extends StatelessWidget {
  const HeartDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          const Expanded(child: DashLine()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Image.asset(HaruImages.greenHeartSmall, width: 16, height: 16, fit: BoxFit.contain),
          ),
          const Expanded(child: DashLine()),
        ],
      ),
    );
  }
}

/// `Divider variant="title"` — thin green rules with a heart,
/// calc(var(--hr-s)*.28) = 112.56 wide, under the 하루한번 wordmark. The row
/// is as tall as the heart (14.07 wide → 11.6 tall).
class TitleDivider extends StatelessWidget {
  const TitleDivider({super.key, this.width = 402 * .28});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: HaruColors.dividerGreen))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            // calc(var(--hr-s) * .035) at 402
            child: Image.asset(HaruImages.greenHeart, width: 14.07, height: 14.07 * 454 / 550),
          ),
          const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: HaruColors.dividerGreen))),
        ],
      ),
    );
  }
}

/// `QuestionLetter` — the letter paper with "To. ○○ 가족", the date and the
/// question. Height follows the paper's 447×558 aspect.
class QuestionLetter extends StatelessWidget {
  const QuestionLetter({
    super.key,
    required this.familyName,
    required this.date,
    required this.question,
    this.isToday = true,
    this.width = 300,
  });

  final String familyName;
  final String date;
  final String question;
  final bool isToday;
  final double width;

  static double heightFor(double width) => width * 558 / 447;

  /// dateunderline.png is 785×318.
  static const _underlineAspect = 318 / 785;

  @override
  Widget build(BuildContext context) {
    final w = width, h = heightFor(width);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Image.asset(HaruImages.letter, fit: BoxFit.fill)),
          Positioned(
            left: w * .06,
            bottom: h * .08,
            width: w * .32,
            child: Image.asset(HaruImages.letterBranch),
          ),
          Positioned(
            right: w * .14,
            bottom: h * .075,
            width: w * .48,
            child: Image.asset(HaruImages.letterDesign),
          ),
          if (isToday)
            Positioned(
              top: h * .045,
              right: w * .12,
              width: w * .2,
              height: w * .2,
              child: Image.asset(HaruImages.todayStamp, fit: BoxFit.fill),
            ),
          Positioned(
            left: w * .17,
            right: w * .19,
            top: h * .16,
            bottom: h * .28,
            // CSS lets the column overflow the box instead of clipping.
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('To. $familyName 가족', style: hrHand(w * .072)),
                  SizedBox(height: h * .02),
                  SizedBox(
                    width: w * .55,
                    height: (h * .045).clamp(10, 22).toDouble(),
                    child: Row(
                      children: [
                        Expanded(child: Image.asset(HaruImages.redLine, height: 14, fit: BoxFit.fill)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * .02),
                          child: Image.asset(HaruImages.redHeart, width: w * .048),
                        ),
                        Expanded(child: Image.asset(HaruImages.redLine, height: 14, fit: BoxFit.fill)),
                      ],
                    ),
                  ),
                  SizedBox(height: h * .025),
                  Text(date, style: hrHand(w * .074, height: .9)),
                  // margin-top: -h*.015 — the underline tucks under the date,
                  // and everything below moves up with it.
                  SizedBox(
                    height: w * .2 * _underlineAspect - h * .015,
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      maxHeight: w * .2 * _underlineAspect,
                      child: Image.asset(HaruImages.dateUnderline, width: w * .2),
                    ),
                  ),
                  SizedBox(height: h * .008),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * .04),
                    child: Text(
                      question,
                      textAlign: TextAlign.center,
                      style: hrQuestion(w * .08, color: HaruColors.inkSoft, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
