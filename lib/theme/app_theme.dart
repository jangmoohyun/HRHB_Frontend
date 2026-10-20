import 'package:flutter/material.dart';

import 'text.dart';
import 'tokens.dart';

/// App-wide [ThemeData] wired to the VER3 tokens.
///
/// Widgets pass explicit styles, but anything that falls back to the theme —
/// default [Text], text fields, selection handles — resolves to the brand
/// font and the forest palette instead of Material blue + Roboto.
ThemeData buildHaruTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: HaruFonts.brand);

  return base.copyWith(
    scaffoldBackgroundColor: HaruColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HaruColors.forest,
      primary: HaruColors.forest,
      onPrimary: Colors.white,
      secondary: HaruColors.cta,
      surface: HaruColors.cream,
      onSurface: HaruColors.ink,
      error: HaruColors.danger,
    ),
    // The prototype gives feedback with a press-scale, not an ink ripple.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: base.textTheme
        .apply(
          fontFamily: HaruFonts.brand,
          bodyColor: HaruColors.ink,
          displayColor: HaruColors.ink,
        )
        .copyWith(bodyMedium: hr(16)),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: HaruColors.forest,
      selectionColor: HaruColors.softGreen.withValues(alpha: 0.35),
      selectionHandleColor: HaruColors.forest,
    ),
    iconTheme: const IconThemeData(color: HaruColors.forest, size: 24),
    dividerColor: HaruColors.hairline,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: FadeUpTransitionsBuilder(),
        TargetPlatform.android: FadeUpTransitionsBuilder(),
      },
    ),
  );
}

/// The prototype's screen entrance `hrFadeUp`: opacity 0 → 1 and
/// translateY(10px) → 0 with cubic-bezier(.33,1,.68,1).
class FadeUpTransitionsBuilder extends PageTransitionsBuilder {
  const FadeUpTransitionsBuilder();

  /// `hrFadeUp 420ms` (MaterialPageRoute reads its duration from here).
  @override
  Duration get transitionDuration => HaruMotion.screen;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _HideWhenCovered(
        secondary: secondaryAnimation,
        child: fadeUp(animation, child),
      );
}

/// The prototype swaps screens instead of stacking them: the old page is gone
/// the moment the new one starts fading in. Hide a page while a route is
/// being pushed over it, and show it again as soon as that route pops.
class _HideWhenCovered extends StatelessWidget {
  const _HideWhenCovered({required this.secondary, required this.child});

  final Animation<double> secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: secondary,
      builder: (_, c) {
        final covered = secondary.status == AnimationStatus.forward ||
            secondary.status == AnimationStatus.completed;
        return Visibility(
          visible: !covered,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: c!,
        );
      },
      child: child,
    );
  }
}

Widget fadeUp(Animation<double> animation, Widget child) {
  final t = CurvedAnimation(parent: animation, curve: HaruMotion.out);
  return FadeTransition(
    opacity: t,
    child: AnimatedBuilder(
      animation: t,
      builder: (_, c) =>
          Transform.translate(offset: Offset(0, 10 * (1 - t.value)), child: c),
      child: child,
    ),
  );
}
