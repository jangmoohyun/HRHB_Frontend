import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font families registered in pubspec.yaml.
abstract final class HaruFonts {
  static const sans = 'Pretendard';
  static const serif = 'GowunBatang'; // question body
  static const hand = 'Gaegu'; // answerer name
  static const logo = 'Cafe24Oneprettynight'; // wordmark only
}

/// Text style factory mirroring the prototype's CSS.
///
/// The prototype sets `letter-spacing: -0.01em` on the whole phone frame and
/// inherits `line-height: 1.5` from the design system body, so those are the
/// defaults here. [TextLeadingDistribution.even] splits extra leading above and
/// below the glyphs the way CSS does.
TextStyle haruText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = HaruColors.ink,
  double height = 1.5,
  double? letterSpacing,
  String family = HaruFonts.sans,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: letterSpacing ?? size * -0.01,
    decoration: decoration,
    decorationColor: color,
  );
}

/// Wordmark "하루한번" (Cafe24Oneprettynight, letter-spacing 0).
TextStyle haruLogo(double size) => haruText(
      size,
      family: HaruFonts.logo,
      color: HaruColors.logo,
      height: 1.1,
      letterSpacing: 0,
    );

/// Question body (Gowun Batang).
TextStyle haruQuestion(double size, {Color color = Colors.white, double height = 1.45}) =>
    haruText(size, family: HaruFonts.serif, color: color, height: height);

/// Answerer name (Gaegu Bold, letter-spacing 0).
TextStyle haruHand(double size, {Color color = HaruColors.accentName, double height = 1.1}) =>
    haruText(
      size,
      family: HaruFonts.hand,
      weight: FontWeight.w700,
      color: color,
      height: height,
      letterSpacing: 0,
    );

/// Recurring title styles.
abstract final class HaruType {
  /// Tab screen title — 24 / 700 / -0.6px
  static TextStyle get screenTitle =>
      haruText(24, weight: FontWeight.w700, letterSpacing: -0.6);

  /// Section title — 18 / 700 / -0.2px
  static TextStyle get sectionTitle =>
      haruText(18, weight: FontWeight.w700, letterSpacing: -0.2);

  /// Sub-page header title — 17 / 600
  static TextStyle get headerTitle => haruText(17, weight: FontWeight.w600);

  /// Auth/onboarding headline — 26 / 700 / 1.25 / -0.5px
  static TextStyle get headline => haruText(
        26,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.5,
        color: HaruColors.dsInk,
      );

  /// Form field label — 14 / 500 / ink-secondary
  static TextStyle get fieldLabel =>
      haruText(14, weight: FontWeight.w500, color: HaruColors.dsInkSecondary);
}
