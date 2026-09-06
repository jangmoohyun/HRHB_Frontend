import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _softBlue = Color(0xFFE4EEF5);
const _buttonGreen = Color(0xFF3A6A3F);
const _dropBlue = Color(0xFF6A9BC8);
const _markerBlue = Color(0xFFA8C9E0);

/// Daily popup shown on home when family temperature dropped vs yesterday.
class TemperatureDropPopup extends StatelessWidget {
  const TemperatureDropPopup({
    super.key,
    required this.deltaFromYesterday,
    required this.bubbleText,
  });

  final double deltaFromYesterday;
  final String bubbleText;

  // Shared paper/grass with up popup for identical shell size.
  static const _paper = 'assets/images/ondo_popup/up_popup/paper.png';
  static const _grass = 'assets/images/ondo_popup/up_popup/grass.png';
  static const _thermometer =
      'assets/images/ondo_popup/down_popup/thermameter.png';
  static const _balloon =
      'assets/images/ondo_popup/down_popup/test_balloon.png';
  static const _arrow = 'assets/images/ondo_popup/down_popup/arrow.png';
  static const _cloud = 'assets/images/ondo_popup/down_popup/cloud.png';
  static const _heart1 = 'assets/images/ondo_popup/down_popup/heart1.png';
  static const _heart2 = 'assets/images/ondo_popup/down_popup/heart2.png';
  static const _rain1 = 'assets/images/ondo_popup/down_popup/rain1.png';
  static const _rain2 = 'assets/images/ondo_popup/down_popup/rain2.png';

  static Future<void> show(
    BuildContext context, {
    required double deltaFromYesterday,
    required String bubbleText,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'temperature-drop-popup',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TemperatureDropPopup(
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
    // Match up-popup paper size exactly.
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
      TemperatureDropPopup._paper,
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
            painter: _MarkerStrokePainter(color: _markerBlue),
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
                  color: _dropBlue,
                ),
              ),
              TextSpan(
                text: '내렸어요',
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

/// Same composition as up-popup:
/// left balloon · center thermometer · right cloud
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
            // Balloon + raindrops (move together)
            Positioned(
              left: -w * 0.04,
              top: h * 0.13,
              width: w * 0.4,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    TemperatureDropPopup._balloon,
                    width: w * 0.4,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      w * 0.035,
                      h * 0.02,
                      w * 0.035,
                      h * 0.045,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '가족의 온도가',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Question',
                            fontSize: shortest * 0.045,
                            color: _bodyGrey,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          '조금 식었어요 💙',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Question',
                            fontSize: shortest * 0.045,
                            color: _bodyGrey,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // rain1 — bottom-right of balloon, nudged left + down
                  Positioned(
                    right: w * 0.04,
                    bottom: -h * 0.15,
                    child: Image.asset(
                      TemperatureDropPopup._rain1,
                      width: w * 0.1125,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // rain2 — slightly left of previous, both rains a bit lower
                  Positioned(
                    left: w * 0.03,
                    bottom: -h * 0.1,
                    child: Image.asset(
                      TemperatureDropPopup._rain2,
                      width: w * 0.07,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),

            // Cloud — nudged left; top heart right / bottom heart lower-right
            Positioned(
              right: w * 0.06,
              top: h * 0.02,
              width: w * 0.34,
              height: h * 0.55,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    right: w * 0.02,
                    child: Image.asset(
                      TemperatureDropPopup._heart2,
                      width: w * 0.1,
                    ),
                  ),
                  Positioned(
                    top: h * 0.08,
                    child: Image.asset(
                      TemperatureDropPopup._cloud,
                      width: w * 0.34,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    right: -w * 0.02,
                    bottom: -h * 0.2,
                    child: Image.asset(
                      TemperatureDropPopup._heart1,
                      width: w * 0.11,
                    ),
                  ),
                ],
              ),
            ),

            // Thermometer — larger
            Align(
              alignment: const Alignment(-0.08, 0.12),
              child: SizedBox(
                width: w * 0.42,
                height: h * 0.92,
                child: Image.asset(
                  TemperatureDropPopup._thermometer,
                  height: h * 0.92,
                  fit: BoxFit.contain,
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
        color: _softBlue.withValues(alpha: 0.92),
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
                  '-',
                  style: TextStyle(
                    fontFamily: 'FamilyNameDate',
                    fontSize: shortest * 0.0928,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: _dropBlue,
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
                    color: _dropBlue,
                  ),
                ),
                SizedBox(width: shortest * 0.008),
                Image.asset(
                  TemperatureDropPopup._arrow,
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
