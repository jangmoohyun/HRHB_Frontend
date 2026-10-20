import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_controls.dart';
import 'pressable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Toast — `Snackbar` at bottom 104, forest pill, 2.2s
// ─────────────────────────────────────────────────────────────────────────────

abstract final class HaruToast {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _message = ValueNotifier<String>('');

  /// Like the prototype's `toast()`: while one is showing, a new message
  /// just swaps the text (no second entrance) and restarts the 2.2s timer.
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _message.value = message;

    var entry = _entry;
    if (entry == null || !entry.mounted) {
      entry = OverlayEntry(
        builder: (ctx) {
          final inset = MediaQuery.of(ctx).viewInsets.bottom;
          return Positioned(
            left: 20,
            right: 20,
            bottom: 104 + inset,
            child: IgnorePointer(
              child: Center(
                child: ValueListenableBuilder<String>(
                  valueListenable: _message,
                  builder: (_, m, _) => _ToastCard(message: m),
                ),
              ),
            ),
          );
        },
      );
      _entry = entry;
      overlay.insert(entry);
    }
    final shown = entry;
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (_entry == shown) {
        shown.remove();
        _entry = null;
      }
    });
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // hrToast: translateY(16px) → 0 + fade, 300ms (.33,1,.68,1)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: HaruMotion.out,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: HaruColors.forest,
            borderRadius: BorderRadius.circular(HaruRadius.md),
            boxShadow: HaruShadows.shadow2,
          ),
          child: Text(
            message,
            style: hr(15, color: Colors.white, height: 1.4, letterSpacing: -0.2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay route — the prototype's `position:absolute; inset:0` layers
// ─────────────────────────────────────────────────────────────────────────────

/// Every overlay in the prototype is a full-frame layer that fades in with
/// `hrFade [fade] ease-out` (dim *and* content, since the content is its
/// child) while the content plays its own entrance ([inner] / [innerCurve]).
class HaruOverlayRoute<T> extends PopupRoute<T> {
  HaruOverlayRoute({
    required this.builder,
    required this.dim,
    required this.inner,
    required this.innerCurve,
    required this.innerTransition,
    this.fade = HaruMotion.fade,
    this.dismissible = true,
    super.settings,
  });

  final WidgetBuilder builder;
  final Color dim;
  final Duration fade;
  final Duration inner;
  final Curve innerCurve;

  /// Builds the content's own entrance from its curved 0 → 1 animation.
  final Widget Function(Animation<double> t, Widget child) innerTransition;
  final bool dismissible;

  int get _totalMs => fade.inMilliseconds > inner.inMilliseconds ? fade.inMilliseconds : inner.inMilliseconds;

  Curve get _fadeCurve => Interval(0, fade.inMilliseconds / _totalMs, curve: Curves.easeOut);

  @override
  Duration get transitionDuration => Duration(milliseconds: _totalMs);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Color? get barrierColor => dim;

  @override
  Curve get barrierCurve => _fadeCurve;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => '닫기';

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Builder(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> innerT = inner == Duration.zero
        ? kAlwaysCompleteAnimation
        : CurvedAnimation(
            parent: animation,
            curve: Interval(0, inner.inMilliseconds / _totalMs, curve: innerCurve),
          );
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: _fadeCurve),
      child: innerTransition(innerT, child),
    );
  }
}

/// `hrSheet`/`hr-up`: translateY(100%) → none.
Widget _slideUp(Animation<double> t, Widget child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(t),
      child: child,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet — cream, radius 22, grabber, padding 12 22 40
// ─────────────────────────────────────────────────────────────────────────────

/// Dim rgba(0,0,0,.35) `hrFade 240ms ease-out`; sheet
/// `hrSheet 360ms cubic-bezier(.2,.8,.2,1)`.
Future<T?> showHaruSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsets padding = const EdgeInsets.fromLTRB(22, 12, 22, 40),
}) {
  return Navigator.of(context, rootNavigator: true).push(
    HaruOverlayRoute<T>(
      dim: HaruColors.dim,
      inner: HaruMotion.sheetIn,
      innerCurve: HaruMotion.sheet,
      innerTransition: _slideUp,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height - mq.padding.top - 12),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: HaruColors.cream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  padding: padding,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SheetGrabber(),
                        const SizedBox(height: 14),
                        Builder(builder: builder),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: HaruColors.handle,
          borderRadius: BorderRadius.circular(HaruRadius.full),
        ),
      ),
    );
  }
}

/// Centered sheet title (21, forest).
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: hr(21, color: HaruColors.forest)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, textAlign: TextAlign.center, style: HaruType.meta),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Design-system BottomSheet (연도 · 월 선택) — dim .4, radius 20
// ─────────────────────────────────────────────────────────────────────────────

/// The wrapper fades in (`hrFade 240ms ease-out`) around the DS
/// `BottomSheet`: dim rgba(0,0,0,.4), sheet
/// `hr-up var(--dur-sheet) var(--ease-out-cubic)` = 320ms (.215,.61,.355,1).
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    HaruOverlayRoute<T>(
      dim: HaruColors.dimSheet,
      inner: const Duration(milliseconds: 320),
      innerCurve: const Cubic(.215, .61, .355, 1),
      innerTransition: _slideUp,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: HaruColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetGrabber(),
                const SizedBox(height: 16),
                Text(title, style: hr(22, color: HaruColors.forest)),
                const SizedBox(height: 18),
                Builder(builder: builder),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// `MonthPicker` — year stepper + 4×3 month grid + 확인.
/// Buttons keep the browser's regular weight (`<button>` resets `font`).
/// Every enabled button is `cursor: pointer` without a transition, so it
/// gets the page-wide press (scale .95 + brightness .96 over 140ms).
class MonthPicker extends StatefulWidget {
  const MonthPicker({
    super.key,
    required this.year,
    required this.month,
    required this.maxYear,
    required this.maxMonth,
    required this.onConfirm,
    this.minYear = 2024,
  });

  final int year;
  final int month;
  final int maxYear;
  final int maxMonth;
  final int minYear;
  final void Function(int year, int month) onConfirm;

  @override
  State<MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
  late int _y = widget.year;
  late int _m = widget.month;

  Widget _press({required VoidCallback? onTap, required Widget child}) => Pressable(
        onTap: onTap,
        scale: 1,
        duration: Duration.zero,
        inlineTransition: false,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final canNext = _y < widget.maxYear;
    final canPrev = _y > widget.minYear;
    // The DS dims only the › button at the max year; it stays a pointer.
    Widget chevron(IconData icon, bool enabled, VoidCallback onTap, {bool dim = false}) => _press(
          onTap: () {
            if (enabled) onTap();
          },
          child: Opacity(
            opacity: dim && !enabled ? .35 : 1,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 24, color: HaruColors.forest),
            ),
          ),
        );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            chevron(Symbols.chevron_left_rounded, canPrev, () => setState(() => _y--)),
            Text('$_y년', style: hr(24, color: HaruColors.forest)),
            chevron(Symbols.chevron_right_rounded, canNext, () => setState(() => _y++), dim: true),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          padding: EdgeInsets.zero,
          children: [
            for (var mo = 1; mo <= 12; mo++)
              _monthCell(mo, _y == widget.maxYear && mo > widget.maxMonth),
          ],
        ),
        const SizedBox(height: 18),
        _press(
          onTap: () => widget.onConfirm(_y, _m),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: HaruColors.forest,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text('확인', style: hr(18, weight: FontWeight.w400, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _monthCell(int mo, bool disabled) {
    final sel = mo == _m;
    return _press(
      onTap: disabled ? null : () => setState(() => _m = mo),
      child: Container(
        decoration: BoxDecoration(
          color: sel
              ? HaruColors.forest
              : disabled
                  ? HaruColors.monthDisabled
                  : HaruColors.monthIdle,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '$mo월',
          style: hr(
            16,
            weight: FontWeight.w400,
            color: sel
                ? Colors.white
                : disabled
                    ? HaruColors.monthDisabledInk
                    : HaruColors.forest,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs — cream, radius 18, padding 22 20 14, pop-in 280ms
// ─────────────────────────────────────────────────────────────────────────────

/// Dim rgba(0,0,0,.35) `hrFade 240ms ease-out` (box included); the box
/// `hrPopIn 280ms cubic-bezier(.33,1,.68,1)`, centered in the full frame
/// with 32px sides.
Future<T?> _showHaruDialog<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context, rootNavigator: true).push(
    HaruOverlayRoute<T>(
      dim: HaruColors.dim,
      inner: const Duration(milliseconds: 280),
      innerCurve: HaruMotion.out,
      innerTransition: (t, child) => FadeTransition(
        opacity: t,
        child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(t), child: child),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(type: MaterialType.transparency, child: Builder(builder: builder)),
          ),
        ),
      ),
    ),
  );
}

class _DialogBox extends StatelessWidget {
  const _DialogBox({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      decoration: BoxDecoration(
        color: HaruColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction(
    this.label,
    this.color,
    this.onTap, {
    this.scale = 1,
    this.duration = Duration.zero,
    this.inlineTransition = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final double scale;
  final Duration duration;
  final bool inlineTransition;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: scale,
      duration: duration,
      inlineTransition: inlineTransition,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Text(label, style: hr(16, color: color)),
      ),
    );
  }
}

/// "가족을 나갈까요?" style confirm. Returns true when the red action is hit.
Future<bool> showHaruConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String okLabel,
  bool danger = true,
}) async {
  final ok = await _showHaruDialog<bool>(
    context,
    (ctx) => _DialogBox(
      children: [
        Text(title, style: hr(20, color: HaruColors.forest)),
        const SizedBox(height: 8),
        Text(body, style: hr(15, height: 1.5)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 취소: no transition, no style-active — the page-wide press only.
            _DialogAction('취소', HaruColors.inkMuted, () => Navigator.of(ctx).pop(false)),
            const SizedBox(width: 4),
            // style-active transform:scale(.96);filter:brightness(.96), no transition.
            _DialogAction(
              okLabel,
              danger ? HaruColors.dangerStrong : HaruColors.forest,
              () => Navigator.of(ctx).pop(true),
              scale: .96,
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// "새 앨범 만들기" style single-field dialog. Returns the trimmed text.
///
/// [reject] may return a message for a name that can't be used; it is
/// toasted and the dialog stays open (prototype: duplicate album name).
Future<String?> showHaruInputDialog(
  BuildContext context, {
  required String title,
  required String placeholder,
  required String okLabel,
  String initial = '',
  int maxLength = 20,
  String? Function(String name)? reject,
}) {
  return _showHaruDialog<String>(
    context,
    (ctx) => _InputDialog(
      title: title,
      placeholder: placeholder,
      okLabel: okLabel,
      initial: initial,
      maxLength: maxLength,
      reject: reject,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.placeholder,
    required this.okLabel,
    required this.initial,
    required this.maxLength,
    this.reject,
  });

  final String title;
  final String placeholder;
  final String okLabel;
  final String initial;
  final int maxLength;
  final String? Function(String name)? reject;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    final msg = widget.reject?.call(v);
    if (msg != null) {
      HaruToast.show(context, msg);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogBox(
      children: [
        Text(widget.title, style: hr(20, color: HaruColors.forest)),
        const SizedBox(height: 14),
        HaruTextField(
          controller: _c,
          placeholder: widget.placeholder,
          autofocus: true,
          height: 48,
          maxLength: widget.maxLength,
          borderColor: HaruColors.softGreen,
          borderWidth: 1.6,
          horizontalPadding: 14,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // transition:transform 200ms ease, style-active scale(.95).
            _DialogAction(
              '취소',
              HaruColors.inkMuted,
              () => Navigator.of(context).pop(),
              scale: .95,
              duration: const Duration(milliseconds: 200),
              inlineTransition: true,
            ),
            const SizedBox(width: 4),
            _DialogAction(
              widget.okLabel,
              HaruColors.forest,
              _submit,
              scale: .95,
              duration: const Duration(milliseconds: 200),
              inlineTransition: true,
            ),
          ],
        ),
      ],
    );
  }
}
