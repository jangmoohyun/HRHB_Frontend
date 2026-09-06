import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Assembled letter paper that grows with [child] height.
/// Uses denser `_2` strips so the body tiles more frequently.
class ExpandableLetterPaper extends StatelessWidget {
  const ExpandableLetterPaper({
    super.key,
    required this.width,
    required this.child,
    this.padding,
  });

  final double width;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const topAsset = 'assets/images/answerscreen/letter_top_2.png';
  static const bodyAsset = 'assets/images/answerscreen/letter_body_2.png';
  static const bottomAsset = 'assets/images/answerscreen/letter_bottom_2.png';

  // Paper content boxes inside each `_2` PNG (transparent canvas cropped out).
  // Horizontal crop differs per asset so stretched edges line up.
  static const _top = _PaperRect(
    srcW: 866,
    srcH: 288,
    left: 22,
    top: 118,
    width: 827,
    height: 76,
  );
  static const _body = _PaperRect(
    srcW: 866,
    srcH: 288,
    left: 10,
    top: 91,
    width: 844,
    height: 107,
  );
  static const _bottom = _PaperRect(
    srcW: 866,
    srcH: 288,
    left: 17,
    top: 108,
    width: 836,
    height: 71,
  );

  static const _bodySeamOverlap = 2.0;
  static const _topSeamOverlap = 1.0;
  /// Body tucks under bottom by this many px only.
  static const _bottomSeamOverlap = 1.0;
  /// Top/bottom stick out slightly on the left vs body — inset to match.
  static const _capLeftInset = 3.0;

  @override
  Widget build(BuildContext context) {
    final topH = _top.displayHeight(width);
    final bottomH = _bottom.displayHeight(width);

    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          width * 0.12,
          math.max(topH * 0.3, width * 0.02),
          width * 0.07,
          math.max(bottomH * 0.55, width * 0.04),
        );

    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: _SeamlessLetterBackground(width: width),
          ),
          Padding(
            padding: resolvedPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PaperRect {
  const _PaperRect({
    required this.srcW,
    required this.srcH,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double srcW;
  final double srcH;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Height when [width] of paper content is stretched to [displayWidth].
  double displayHeight(double displayWidth) => displayWidth * height / width;
}

class _SeamlessLetterBackground extends StatelessWidget {
  const _SeamlessLetterBackground({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final tileH = ExpandableLetterPaper._body.displayHeight(width);
    const bodyOverlap = ExpandableLetterPaper._bodySeamOverlap;
    const topOverlap = ExpandableLetterPaper._topSeamOverlap;
    const bottomOverlap = ExpandableLetterPaper._bottomSeamOverlap;
    const capInset = ExpandableLetterPaper._capLeftInset;
    final capW = width - capInset;
    final topH = ExpandableLetterPaper._top.displayHeight(capW);
    final bottomH = ExpandableLetterPaper._bottom.displayHeight(capW);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (!h.isFinite || h <= 0) {
          return const SizedBox.shrink();
        }

        final bodyTop = math.max(0.0, topH - topOverlap);
        // Only 1px under the bottom cap.
        final bodyBottom = math.max(
          bodyTop + tileH,
          h - bottomH + bottomOverlap,
        );
        final bodySpan = math.max(tileH, bodyBottom - bodyTop);
        final step = math.max(1.0, tileH - bodyOverlap);
        final count = math.max(1, ((bodySpan - tileH) / step).ceil() + 1);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Clip body so leftover tile height can't paint under the bottom.
            Positioned(
              top: bodyTop,
              left: 0,
              width: width,
              height: math.max(0.0, bodyBottom - bodyTop),
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (var i = 0; i < count; i++)
                      Positioned(
                        top: i * step,
                        left: 0,
                        width: width,
                        height: tileH,
                        child: _CroppedAssetStrip(
                          asset: ExpandableLetterPaper.bodyAsset,
                          width: width,
                          rect: ExpandableLetterPaper._body,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: capInset,
              width: capW,
              height: topH,
              child: _CroppedAssetStrip(
                asset: ExpandableLetterPaper.topAsset,
                width: capW,
                rect: ExpandableLetterPaper._top,
              ),
            ),
            Positioned(
              bottom: 0,
              left: capInset,
              width: capW,
              height: bottomH,
              child: _CroppedAssetStrip(
                asset: ExpandableLetterPaper.bottomAsset,
                width: capW,
                rect: ExpandableLetterPaper._bottom,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CroppedAssetStrip extends StatelessWidget {
  const _CroppedAssetStrip({
    required this.asset,
    required this.width,
    required this.rect,
  });

  final String asset;
  final double width;
  final _PaperRect rect;

  @override
  Widget build(BuildContext context) {
    final scale = width / rect.width;
    final fullW = rect.srcW * scale;
    final fullH = rect.srcH * scale;
    final h = rect.height * scale;

    return SizedBox(
      width: width,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: fullW,
          maxWidth: fullW,
          minHeight: fullH,
          maxHeight: fullH,
          child: Transform.translate(
            offset: Offset(-rect.left * scale, -rect.top * scale),
            child: Image.asset(
              asset,
              width: fullW,
              height: fullH,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
