import 'package:flutter/material.dart';

/// Design tokens for 하루한번 VER2.
///
/// Values come straight from the VER2 design mockups; CSS px map 1:1 to
/// Flutter logical pixels.
abstract final class HaruColors {
  // ── VER2 screen palette ────────────────────────────────────────────────
  static const canvas = Color(0xFFF5EFE4); // bg.canvas — screen background
  static const card = Color(0xFFFFFFFF); // bg.card
  static const ceramic = Color(0xFFECE4D6); // empty cards, segment/gauge track
  static const meadow = Color(0xFFE3EED8); // family band, positive pill
  static const house = Color(0xFF62763A); // question hero, selected chips
  static const logo = Color(0xFF4D6428); // wordmark
  static const accentName = Color(0xFF5E7A2E); // answerer name (Gaegu)
  static const ink = Color(0xFF2B2016); // ink.95 in VER2 screens
  static const inkSecondary = Color(0x9E2B2016); // rgba(43,32,22,.62)
  static const inkTertiary = Color(0x8C2B2016); // rgba(43,32,22,.55)
  static const inkQuiet = Color(0x732B2016); // rgba(43,32,22,.45)
  static const inkChevron = Color(0x592B2016); // rgba(43,32,22,.35)
  static const inkDisabled = Color(0x472B2016); // rgba(43,32,22,.28)
  static const inkLine = Color(0x242B2016); // rgba(43,32,22,.14)
  static const inkLineSoft = Color(0x1F2B2016); // rgba(43,32,22,.12)
  static const inkDivider = Color(0x142B2016); // rgba(43,32,22,.08)
  static const handle = Color(0x2E2B2016); // rgba(43,32,22,.18)
  static const handleYm = Color(0x332B2016); // rgba(43,32,22,.2)
  static const dotIdle = Color(0xFFDDD5C6);

  // ── Temperature / streak / warning ─────────────────────────────────────
  static const tempRise = Color(0xFFE08A8A);
  static const tempRiseText = Color(0xFFC4553A);
  static const tempDrop = Color(0xFF6A9BC8);
  static const tempDropText = Color(0xFF4E7BA6);
  static const streak = Color(0xFFE0784A);
  static const streakTile = Color(0xFFFBE3D6);
  static const streakTrack = Color(0xFFF0EAE0);
  static const warn = Color(0xFFE0A14A);
  static const warnPill = Color(0xFFFBEBD3);
  static const warnText = Color(0xFF8A5210);
  static const positivePillText = Color(0xFF3F5E22);
  static const heatmap = [
    Color(0xFFECE4D6),
    Color(0xFFD9E2C4),
    Color(0xFFB5C790),
    Color(0xFF8CA35F),
    Color(0xFF62763A),
  ];

  // ── Design system: brand (tokens/colors.css) ───────────────────────────
  static const primary = Color(0xFF4F8A5B);
  static const primaryActive = Color(0xFF3D7049);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFE3EED8);
  static const onSecondary = Color(0xFF2A3320);

  // Sticker palette — decoration only
  static const accentSky = Color(0xFFC7E0F2);
  static const accentPurple = Color(0xFFE4D8F3);
  static const accentPurpleDeep = Color(0xFF4B3A66);
  static const accentPink = Color(0xFFF7D0DC);
  static const accentOrange = Color(0xFFFBD9C4);
  static const accentOrangeDeep = Color(0xFF8A4A2A);
  static const accentTeal = Color(0xFFBFE3DC);
  static const accentGreen = Color(0xFFB9DCB0);
  static const accentBrown = Color(0xFF523410);
  static const accentButter = Color(0xFFFBEEB0);

  /// Avatar / photo placeholder cycle (prototype `T` list).
  static const tints = [
    accentSky,
    accentGreen,
    accentPink,
    accentButter,
    accentOrange,
    accentTeal,
    accentPurple,
  ];

  // Surface
  static const surface = Color(0xFFFFFFFF);
  static const canvasSoft = Color(0xFFFAF8F2);
  static const hairline = Color(0xFFEBE7DC);
  static const inputBorder = Color(0xFFDDD8CC);
  static const fillHover = Color(0x0A000000); // rgba(0,0,0,.04)
  static const fillTranslucent = Color(0x0D000000); // rgba(0,0,0,.05)

  // Text (design-system screens: auth, onboarding, answers, albums, temp)
  static const dsInk = Color(0xF2000000); // --ink-95
  static const dsInkSecondary = Color(0xFF33372F);
  static const dsInkMuted = Color(0xFF62675D);
  static const dsInkFaint = Color(0xFFA3A697);

  static const statusPositive = Color(0xFF3F8A4F);
  static const statusAttention = Color(0xFFC4692F);

  static const dim = Color(0x80000000); // modal dim rgba(0,0,0,.5)
  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoLabel = Color(0xD9000000); // rgba(0,0,0,.85)
}

abstract final class HaruRadius {
  static const xs = 4.0;
  static const sm = 5.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const hero = 20.0;
  static const sheet = 24.0;
  static const full = 9999.0;
}

abstract final class HaruSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 28.0;
  static const xxl = 32.0;
  static const tapMin = 44.0;
}

/// Converts a CSS `box-shadow` blur length to a Flutter [BoxShadow.blurRadius].
///
/// CSS renders blur B as a Gaussian with σ = B / 2, while Flutter derives
/// σ = r × 0.57735 + 0.5 from blurRadius r. Passing the CSS number straight
/// through would make every shadow noticeably softer than the design.
double cssBlur(double blur) {
  final r = (blur / 2 - 0.5) / 0.57735;
  return r < 0 ? 0 : r;
}

BoxShadow cssShadow({
  double x = 0,
  required double y,
  required double blur,
  double spread = 0,
  required Color color,
}) {
  return BoxShadow(
    color: color,
    offset: Offset(x, y),
    blurRadius: cssBlur(blur),
    spreadRadius: spread,
  );
}

abstract final class HaruShadows {
  /// `--shadow-1`
  static final s1 = [
    cssShadow(y: 0.175, blur: 1.041, color: const Color(0x03000000)),
    cssShadow(y: 0.8, blur: 2.925, color: const Color(0x05000000)),
    cssShadow(y: 2.025, blur: 7.847, color: const Color(0x07000000)),
    cssShadow(y: 4, blur: 18, color: const Color(0x0A000000)),
  ];

  /// `--shadow-2`
  static final s2 = [
    cssShadow(y: 1, blur: 3, color: const Color(0x03000000)),
    cssShadow(y: 3, blur: 7, color: const Color(0x05000000)),
    cssShadow(y: 7, blur: 15, color: const Color(0x05000000)),
    cssShadow(y: 14, blur: 28, color: const Color(0x0A000000)),
    cssShadow(y: 23, blur: 52, color: const Color(0x0D000000)),
  ];

  /// Bottom tab bar.
  static final tabBar = [
    cssShadow(y: -1, blur: 0, color: const Color(0x0D2B2016)),
    cssShadow(y: -8, blur: 24, color: const Color(0x122B2016)),
  ];

  /// Floating "오늘의 답변 남기기" button.
  static final fab = [
    cssShadow(y: 8, blur: 24, color: const Color(0x472B2016)),
  ];

  /// Raised center "홈" tab button.
  static final homeTab = [
    cssShadow(y: 12, blur: 24, color: const Color(0x524D6428)),
  ];
}

abstract final class HaruMotion {
  /// `--ease-standard` cubic-bezier(0.2, 0, 0, 1)
  static const standard = Cubic(0.2, 0, 0, 1);

  /// Pop-in used for chips/cells: cubic-bezier(.2, 1.4, .4, 1)
  static const pop = Cubic(0.2, 1.4, 0.4, 1);

  /// Bottom sheet slide: cubic-bezier(.2, .8, .2, 1)
  static const sheet = Cubic(0.2, 0.8, 0.2, 1);

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const push = Duration(milliseconds: 340);
  static const fade = Duration(milliseconds: 380);
}
