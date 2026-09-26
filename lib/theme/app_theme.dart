import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'text.dart';
import 'tokens.dart';

/// App-wide [ThemeData] wired to the VER2 tokens.
///
/// Widgets still pass explicit styles (the prototype varies ink colors per
/// screen), but anything that falls back to the theme — dialogs, text fields,
/// selection handles, default [Text] — now resolves to Pretendard and the
/// VER2 palette instead of Material blue + Roboto.
ThemeData buildHaruTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: HaruFonts.sans);
  final bodyDefault = haruText(16);

  return base.copyWith(
    scaffoldBackgroundColor: HaruColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HaruColors.primary,
      primary: HaruColors.primary,
      onPrimary: HaruColors.onPrimary,
      secondary: HaruColors.secondary,
      onSecondary: HaruColors.onSecondary,
      surface: HaruColors.surface,
      onSurface: HaruColors.ink,
      error: HaruColors.statusAttention,
    ),
    // The prototype gives feedback with a press-scale, not an ink ripple.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      fontFamily: HaruFonts.sans,
      bodyColor: HaruColors.ink,
      displayColor: HaruColors.ink,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: HaruColors.primary,
      selectionColor: HaruColors.primary.withValues(alpha: 0.18),
      selectionHandleColor: HaruColors.primary,
    ),
    iconTheme: const IconThemeData(color: HaruColors.ink, size: 20),
    dividerColor: HaruColors.hairline,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      },
    ),
  ).copyWith(
    textTheme: base.textTheme
        .apply(fontFamily: HaruFonts.sans)
        .copyWith(bodyMedium: bodyDefault),
  );
}
