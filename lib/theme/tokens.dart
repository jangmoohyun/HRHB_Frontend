import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens for 하루한번 VER3.
///
/// Values come straight from the VER3 design mockups (402×874 frame) and the
/// 하루한번 design system's tokens/colors.css; CSS px map 1:1 to Flutter
/// logical pixels.
abstract final class HaruColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const forest = Color(0xFF3A6A3F); // --hr-forest · titles, selection
  static const softGreen = Color(0xFF7FA87A); // --hr-soft-green · icons, focus
  static const cta = Color(0xFF2F8F4E); // --hr-cta-home · buttons, check
  static const ctaDisabled = Color(0x732F8F4E); // rgba(47,143,78,.45)
  static const fieldBorder = Color(0xFFC5D9B8); // --hr-field-border
  static const dividerGreen = Color(0xFFB7C7B4); // --hr-divider-green

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const cream = Color(0xFFFDFBF0); // --hr-cream · canvas
  static const ivory = Color(0xFFFFFCF6); // --hr-ivory · cards
  static const panelGreen = Color(0xFFEAF3E4); // --hr-panel-green
  static const hairline = Color(0xFFE8E0D4); // --hr-hairline
  static const lineGrey = Color(0xFFD8D8D8); // --hr-line-grey · switch off
  static const gaugeTrack = Color(0xFFEDE6D8); // --hr-gauge-track
  static const waiting = Color(0xFFF4F1E6); // "기다리는 중" rows
  static const handle = Color(0xFFD7E0D4); // sheet grabber

  // ── Text ───────────────────────────────────────────────────────────────
  static const ink = Color(0xFF2F2F2F); // --hr-ink-strong · body
  static const inkSoft = Color(0xFF4A4A4A); // --hr-ink · letter question
  static const inkMuted = Color(0xFF5F5F5F); // --hr-ink-onb · secondary
  static const inkFaint = Color(0xFF8A8A8A); // --hr-ink-muted · chevrons
  static const placeholder = Color(0xFF757575); // browser ::placeholder

  // ── Decorative (member tints, icon tiles) ──────────────────────────────
  static const mint = Color(0xFFE8F0E4); // --hr-deco-mint
  static const orange = Color(0xFFF5E2CF); // --hr-deco-orange
  static const orangeInk = Color(0xFFE8A05A); // --hr-deco-orange-ink
  static const yellow = Color(0xFFFFF1B8); // --hr-deco-yellow
  static const lavender = Color(0xFFF0EAF6); // --hr-deco-lavender
  static const sand = Color(0xFFEDE6D8);
  static const welcome = Color(0xCCFFF8E8); // rgba(255,248,232,.8)

  // ── Semantic ───────────────────────────────────────────────────────────
  static const danger = Color(0xFFD96050); // --hr-danger
  static const dangerStrong = Color(0xFFC45C5C); // --hr-danger-strong
  static const dangerBorder = Color(0xFFE0C4C4); // --hr-danger-border
  static const badge = Color(0xFFE86A4A); // --hr-badge · unread dot
  static const tempRise = Color(0xFFE08A8A); // --hr-temp-rise
  static const tempDrop = Color(0xFF6A9BC8); // --hr-temp-drop
  static const tempDelta = Color(0xFF5B8FD9); // --hr-temp-delta
  static const tempText = Color(0xFFC9C24F); // home temperature figure
  static const warmIcon = Color(0xFFF09A4A); // device_thermostat tile

  // ── Overlays / chrome ──────────────────────────────────────────────────
  static const dim = Color(0x59000000); // rgba(0,0,0,.35)
  static const dimSheet = Color(0x66000000); // rgba(0,0,0,.4)
  static const dimPopup = Color(0x73000000); // rgba(0,0,0,.45)
  static const navFill = Color(0xEBE8F0E4); // rgba(232,240,228,.92)
  static const navBorder = Color(0x99C5D5C0); // rgba(197,213,192,.6)
  static const monthIdle = Color(0xFFE4EDE2);
  static const monthDisabled = Color(0xFFECEFEA);
  static const monthDisabledInk = Color(0xFFA0A89F);
  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoLabel = Color(0xD9000000); // rgba(0,0,0,.85)
  static const googleBorder = Color(0xFFDADCE0);
  static const googleLabel = Color(0xFF1F1F1F);

  /// Thermal ramp (--hr-thermal-1 … 8).
  static const thermal = [
    Color(0xFF7EC8F5),
    Color(0xFF8FD4C8),
    Color(0xFFB8E07A),
    Color(0xFFE8E05A),
    Color(0xFFF5C04A),
    Color(0xFFF09A4A),
    Color(0xFFE8785A),
    Color(0xFFE85A55),
  ];

  /// Heat calendar levels for 0 … 4 members answered.
  static const heat = [
    Color(0xFFEDE6D8),
    Color(0xFFE8F0E4),
    Color(0xFFC5D9B8),
    Color(0xFF7FA87A),
    Color(0xFF3A6A3F),
  ];

  /// Avatar / photo placeholder cycle (prototype `PHOTO_TINTS`).
  static const tints = [
    mint,
    orange,
    lavender,
    yellow,
    panelGreen,
    sand,
  ];
}

/// The prototype's `tempColor(t)`: thermal ramp at t/100, darkened to 86 %.
/// Used for day temperatures and participation bars.
Color tempColor(double t) {
  final s = t.clamp(0, 100) / 100 * 7;
  final i = math.min(6, s.floor());
  final l = s - i;
  final a = HaruColors.thermal[i], b = HaruColors.thermal[i + 1];
  int ch(double x, double y) => ((x + (y - x) * l) * 0.86).round();
  return Color.fromARGB(
    255,
    ch(a.r * 255, b.r * 255),
    ch(a.g * 255, b.g * 255),
    ch(a.b * 255, b.b * 255),
  );
}

/// The design system's `lerp(t)` for the gauge arc (no darkening).
Color thermalAt(double t) {
  final c = HaruColors.thermal;
  final s = t.clamp(0.0, 1.0) * (c.length - 1);
  final i = math.min(c.length - 2, s.floor());
  return Color.lerp(c[i], c[i + 1], s - i)!;
}

abstract final class HaruRadius {
  static const sm = 12.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 18.0;
  static const sheet = 22.0;
  static const full = 999.0;
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
  /// `--shadow-card` 0 6 16 rgba(0,0,0,.086)
  static final card = [cssShadow(y: 6, blur: 16, color: const Color(0x16000000))];

  /// `--shadow-1` 0 4 12 rgba(0,0,0,.08) — family select cards.
  static final soft = [cssShadow(y: 4, blur: 12, color: const Color(0x14000000))];

  /// `--shadow-1` 0 4 10 rgba(0,0,0,.08) — email button.
  static final shadow1 = [cssShadow(y: 4, blur: 10, color: const Color(0x14000000))];

  /// `--shadow-2` 0 6 18 rgba(0,0,0,.10) — nav bar, snackbar.
  static final shadow2 = [cssShadow(y: 6, blur: 18, color: const Color(0x1A000000))];

  /// `--shadow-3` 0 5 12 rgba(0,0,0,.13) — filled pills ("보내기", "사진 올리기").
  static final shadow3 = [cssShadow(y: 5, blur: 12, color: const Color(0x21000000))];

  /// Answer card 0 2 8 rgba(58,106,63,.06).
  static final answer = [cssShadow(y: 2, blur: 8, color: const Color(0x0F3A6A3F))];

  /// Raised 홈 tab: 5px cream ring + 0 8 16 rgba(58,106,63,.3).
  static final homeTab = [cssShadow(y: 8, blur: 16, color: const Color(0x4D3A6A3F))];

  /// Temperature popup 0 16 40 rgba(0,0,0,.18).
  static final popup = [cssShadow(y: 16, blur: 40, color: const Color(0x2E000000))];

  /// Switch knob 0 1 3 rgba(0,0,0,.15).
  static final knob = [cssShadow(y: 1, blur: 3, color: const Color(0x26000000))];

  /// Letter glow while opening: drop-shadow(0 10px 18px rgba(58,106,63,.25)).
  static final letterGlow = [cssShadow(y: 10, blur: 18, color: const Color(0x403A6A3F))];
}

abstract final class HaruMotion {
  /// Screen entrance `hrFadeUp`/`hrRiseIn` cubic-bezier(.33,1,.68,1).
  static const out = Cubic(0.33, 1, 0.68, 1);

  /// `cubic-bezier(.2,0,0,1)` — staggered list/pop entrances.
  static const standard = Cubic(0.2, 0, 0, 1);

  /// Overshoot `cubic-bezier(.2,1.4,.4,1)` — nav pills, week chips, weather.
  static const pop = Cubic(0.2, 1.4, 0.4, 1);

  /// Bottom sheet `cubic-bezier(.2,.8,.2,1)`.
  static const sheet = Cubic(0.2, 0.8, 0.2, 1);

  /// Growth bars `cubic-bezier(.3,0,.1,1)`.
  static const grow = Cubic(0.3, 0, 0.1, 1);

  static const press = Duration(milliseconds: 200);
  static const screen = Duration(milliseconds: 420);
  static const sheetIn = Duration(milliseconds: 360);
  static const fade = Duration(milliseconds: 240);
}
