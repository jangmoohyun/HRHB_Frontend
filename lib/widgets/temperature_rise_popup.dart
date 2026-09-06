import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _softMint = Color(0xFFE8F0E4);
const _buttonGreen = Color(0xFF3A6A3F);
const _risePink = Color(0xFFE08A8A);
const _markerGreen = Color(0xFFB7D39A);

/// Daily popup shown on home when family temperature rose vs yesterday.
class TemperatureRisePopup extends StatelessWidget {
  const TemperatureRisePopup({
    super.key,
    required this.deltaFromYesterday,
    required this.bubbleText,
  });

  final double deltaFromYesterday;
  final String bubbleText;

  static const _paper = 'assets/images/ondo_popup/up_popup/paper.png';
  static const _grass = 'assets/images/ondo_popup/up_popup/grass.png';
  static const _thermometer =
      'assets/images/ondo_popup/up_popup/thermometer.png';
  static const _balloon = 'assets/images/ondo_popup/up_popup/text_balloon.png';
  static const _arrow = 'assets/images/ondo_popup/up_popup/arrow.png';
  static const _ondoLeft = 'assets/images/ondo_popup/up_popup/ondo_left.png';
  static const _ondoRight = 'assets/images/ondo_popup/up_popup/ondo_right.png';
  static const _sun = 'assets/images/familyondo/sun.png';
  static const _heartPurple =
      'assets/images/ondo_popup/up_popup/left_heart_1.png';
  static const _heartPink =
      'assets/images/ondo_popup/up_popup/left_heart_2.png';
  static const _heartRight1 =
      'assets/images/ondo_popup/up_popup/right_heart_1.png';
  static const _heartRight2 =
      'assets/images/ondo_popup/up_popup/right_heart_2.png';

  static Future<void> show(
    BuildContext context, {
    required double deltaFromYesterday,
    required String bubbleText,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'temperature-rise-popup',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TemperatureRisePopup(
          deltaFromYesterday: deltaFromYesterday,
          bubbleText: bubbleText,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = math.min(size.width, size.height);
    // 0.9× previous paper size.
    final popupW = math.min(size.width * 0.94, shortest * 0.94) * 0.9;
    final popupH = math.min(size.height * 0.88, popupW * 1.55);
    final deltaAbs = deltaFromYesterday.abs().toStringAsFixed(1);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: popupW,
          height: popupH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: _PaperBackground(),
                ),
                // Grass raised; bottom edge soft-faded into paper.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: popupH * 0.24,
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                          stops: [0.0, 0.62, 1.0],
                        ).createShader(bounds);
                      },
                      child: Image.asset(
                        _grass,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: popupH * 0.048,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SproutIcon(size: popupW * 0.048),
                  ),
                ),
                Positioned(
                  top: popupH * 0.09,
                  left: 0,
                  right: 0,
                  child: Text(
                    '어제보다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NanumDasiSijakhae',
                      fontSize: popupW * 0.081,
                      color: _titleGreen,
                      height: 1.05,
                    ),
                  ),
                ),
                Positioned(
                  top: popupH * 0.15,
                  left: popupW * 0.06,
                  right: popupW * 0.06,
                  child: _HighlightedTitle(
                    deltaAbs: deltaAbs,
                    shortest: popupW,
                  ),
                ),
                Positioned(
                  top: popupH * 0.26,
                  left: popupW * 0.055,
                  right: popupW * 0.055,
                  height: popupH * 0.36,
                  child: _IllustrationStage(
                    shortest: popupW,
                  ),
                ),
                Positioned(
                  top: popupH * 0.63,
                  left: popupW * 0.18,
                  right: popupW * 0.18,
                  child: _ChangeSummaryCard(
                    deltaAbs: deltaAbs,
                    shortest: popupW,
                  ),
                ),
                Positioned(
                  left: popupW * 0.17,
                  right: popupW * 0.17,
                  bottom: popupH * 0.07,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '오늘도 따뜻한 하루 보내세요 ❤️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: popupW * 0.044,
                          fontWeight: FontWeight.w700,
                          color: _bodyGrey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: popupH * 0.09,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _buttonGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '확인',
                                style: TextStyle(
                                  fontFamily: 'Cafe24Oneprettynight',
                                  fontSize: popupW * 0.045,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: popupW * 0.02),
                              Image.asset(
                                'assets/images/public/sprout.png',
                                width: popupW * 0.042,
                                height: popupW * 0.042,
                                color: Colors.white,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: popupH * 0.04,
                  right: popupW * 0.04,
                  child: _CloseChip(
                    size: popupW * 0.085,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperBackground extends StatelessWidget {
  const _PaperBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      TemperatureRisePopup._paper,
      fit: BoxFit.cover,
    );
  }
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({
    required this.deltaAbs,
    required this.shortest,
  });

  final String deltaAbs;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: shortest * 0.02,
          right: shortest * 0.02,
          bottom: shortest * 0.002,
          height: shortest * 0.06,
          child: CustomPaint(
            painter: _MarkerStrokePainter(color: _markerGreen),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$deltaAbs°C ',
                style: TextStyle(
                  fontFamily: 'FamilyNameDate',
                  fontSize: shortest * 0.15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                  color: const Color(0xFF7CB85A),
                ),
              ),
              TextSpan(
                text: '올랐어요!',
                style: TextStyle(
                  fontFamily: 'BMYeonsung',
                  fontSize: shortest * 0.098,
                  color: const Color(0xFF2F2F2F),
                  height: 1.05,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MarkerStrokePainter extends CustomPainter {
  const _MarkerStrokePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(w * 0.02, h * 0.55);
    path.cubicTo(w * 0.18, h * 0.1, w * 0.35, h * 0.95, w * 0.52, h * 0.45);
    path.cubicTo(w * 0.68, h * 0.05, w * 0.82, h * 0.9, w * 0.98, h * 0.4);
    path.lineTo(w * 0.97, h * 0.85);
    path.cubicTo(w * 0.8, h * 1.05, w * 0.65, h * 0.35, w * 0.5, h * 0.9);
    path.cubicTo(w * 0.32, h * 1.15, w * 0.16, h * 0.35, w * 0.02, h * 0.75);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Layout matches design:
/// left balloon · center thermometer (+ sparks/hearts) · right sun
class _IllustrationStage extends StatelessWidget {
  const _IllustrationStage({
    required this.shortest,
  });

  final double shortest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Balloon — mid-left, beside thermometer body
            Positioned(
              left: -w * 0.04,
              top: h * 0.3,
              width: w * 0.4,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    TemperatureRisePopup._balloon,
                    width: w * 0.4,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      w * 0.04,
                      h * 0.02,
                      w * 0.04,
                      h * 0.045,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '가족의 온도가',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.036,
                            color: _bodyGrey,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '따뜻해졌어요 ❤️',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.036,
                            color: _bodyGrey,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // left_heart_2 — above balloon, 1.3×
                  Positioned(
                    left: w * 0.02,
                    top: -h * 0.16,
                    child: Image.asset(
                      TemperatureRisePopup._heartPink,
                      width: w * 0.104,
                    ),
                  ),
                  // left_heart_1 — bottom-right of balloon, 1.3×
                  Positioned(
                    right: -w * 0.02,
                    bottom: -h * 0.02,
                    child: Image.asset(
                      TemperatureRisePopup._heartPurple,
                      width: w * 0.091,
                    ),
                  ),
                ],
              ),
            ),

            // Sun — upper-right of thermometer
            Positioned(
              right: w * 0.02,
              top: h * 0.1,
              width: w * 0.26,
              height: w * 0.26,
              child: Image.asset(
                TemperatureRisePopup._sun,
                width: w * 0.26,
                height: w * 0.26,
                fit: BoxFit.contain,
              ),
            ),

            // right_heart_2 — same spot, updated asset
            Positioned(
              right: -w * 0.01,
              top: h * 0.48,
              child: Image.asset(
                TemperatureRisePopup._heartRight2,
                width: w * 0.111,
              ),
            ),

            // Thermometer + ondo marks — nudged slightly left together
            Align(
              alignment: const Alignment(-0.08, 0.12),
              child: SizedBox(
                width: w * 0.36,
                height: h * 0.8,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      TemperatureRisePopup._thermometer,
                      height: h * 0.74,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      left: -w * 0.02,
                      top: h * 0.0,
                      child: Image.asset(
                        TemperatureRisePopup._ondoLeft,
                        width: w * 0.105,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      right: -w * 0.02,
                      top: h * 0.0,
                      child: Image.asset(
                        TemperatureRisePopup._ondoRight,
                        width: w * 0.11,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // right_heart_1 — right side of thermometer
                    Positioned(
                      right: -w * 0.18,
                      top: h * 0.38,
                      child: Image.asset(
                        TemperatureRisePopup._heartRight1,
                        width: w * 0.21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CloseChip extends StatelessWidget {
  const _CloseChip({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            size: size * 0.78,
            color: _titleGreen,
          ),
        ),
      ),
    );
  }
}

class _ChangeSummaryCard extends StatelessWidget {
  const _ChangeSummaryCard({
    required this.deltaAbs,
    required this.shortest,
  });

  final String deltaAbs;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: shortest * 0.02,
        vertical: shortest * 0.042,
      ),
      decoration: BoxDecoration(
        color: _softMint.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: shortest * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 변화',
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.042,
                      color: _titleGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '(어제 대비)',
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.028,
                      color: _mutedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: shortest * 0.11,
            margin: EdgeInsets.symmetric(horizontal: shortest * 0.01),
            child: CustomPaint(painter: _DashedVLinePainter()),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    fontFamily: 'FamilyNameDate',
                    fontSize: shortest * 0.0928,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: _risePink,
                  ),
                ),
                SizedBox(width: shortest * 0.012),
                Text(
                  '$deltaAbs°C',
                  style: TextStyle(
                    fontFamily: 'FamilyNameDate',
                    fontSize: shortest * 0.0928,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.5,
                    color: _risePink,
                  ),
                ),
                SizedBox(width: shortest * 0.008),
                Image.asset(
                  TemperatureRisePopup._arrow,
                  width: shortest * 0.07,
                  height: shortest * 0.07,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedVLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB7C7B2)
      ..strokeWidth = 1.2;
    const dash = 3.0;
    const gap = 2.5;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dash).clamp(0, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
