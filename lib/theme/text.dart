import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font families registered in pubspec.yaml.
abstract final class HaruFonts {
  /// `--font-brand` — every UI string (Gaegu 400/700).
  static const brand = 'Gaegu';

  /// `--font-hand` — dates, names, numbers (나눔손글씨 다시시작해).
  static const hand = 'FamilyNameDate';

  /// `--font-question` — question text (나눔펜체).
  static const question = 'Question';
}

/// Text style mirroring the prototype's CSS.
///
/// The phone frame sets `font-weight: 700` on everything, so that is the
/// default. Gaegu ships 400 and 700; the handwriting fonts ship a single
/// weight and are emboldened the same way the browser does. [height] null means CSS
/// `line-height: normal`. When a height is given, [TextLeadingDistribution.even]
/// splits the extra leading above and below the glyphs the way CSS does.
TextStyle hr(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = HaruColors.ink,
  double? height,
  double letterSpacing = 0,
  String family = HaruFonts.brand,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    leadingDistribution: height == null ? null : TextLeadingDistribution.even,
    letterSpacing: letterSpacing,
    decoration: decoration,
    decorationColor: color,
  );
}

/// `--font-hand` (dates, names, figures).
TextStyle hrHand(
  double size, {
  Color color = HaruColors.forest,
  FontWeight weight = FontWeight.w700,
  double? height,
  double letterSpacing = 0,
}) =>
    hr(
      size,
      family: HaruFonts.hand,
      color: color,
      weight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

/// `--font-question` (question text).
TextStyle hrQuestion(
  double size, {
  Color color = HaruColors.ink,
  double? height,
}) =>
    hr(size, family: HaruFonts.question, color: color, height: height);

/// Recurring styles.
abstract final class HaruType {
  /// Tab title "우리 가족 일지" — 23 / forest.
  static TextStyle get tabTitle => hr(23, color: HaruColors.forest);

  /// Sub-page header "가족 답장" — 21 / forest.
  static TextStyle get pageTitle => hr(21, color: HaruColors.forest);

  /// Onboarding headline "이메일로 로그인해요" — 31 / 1.25 / forest.
  static TextStyle get headline => hr(31, color: HaruColors.forest, height: 1.25);

  /// Form label "이메일" — 15 / forest.
  static TextStyle get fieldLabel => hr(15, color: HaruColors.forest);

  /// Helper / meta text — 14 / muted.
  static TextStyle get meta => hr(14, color: HaruColors.inkMuted);

  /// Inline error — 14.5 / danger.
  static TextStyle get error => hr(14.5, color: HaruColors.danger);
}
