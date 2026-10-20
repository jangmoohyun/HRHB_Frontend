import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';

import '../onboarding/family_select_screen.dart';
import '../shell/home_shell.dart';

/// Shared frame for the sign-in / family-connect flow (the prototype's `fl`
/// layer): cream canvas, branches from both sides, content scrolling over
/// the full screen.
///
/// The prototype lays these screens out from the very top of a 874-tall frame
/// whose status bar is 54px; [FlowScaffold.shift] is how much taller this
/// device's status bar is, so the absolute offsets still clear it.
///
/// Like the prototype, the branches stay put and only the page content plays
/// `hrFadeUp` — on arrival and again when a flow page above it is popped
/// (the prototype re-mounts the page it goes back to).
class FlowScaffold extends StatefulWidget {
  const FlowScaffold({
    super.key,
    required this.builder,
    this.back,
    this.entrance = true,
  });

  /// Gets the minimum content height (one screen) and the top shift.
  final Widget Function(BuildContext context, double minHeight, double shift) builder;

  /// Back row pinned at top 54 (form screens).
  final Widget? back;
  final bool entrance;

  static double shiftOf(BuildContext context) =>
      math.max(0, MediaQuery.of(context).padding.top - 54);

  @override
  State<FlowScaffold> createState() => _FlowScaffoldState();
}

class _FlowScaffoldState extends State<FlowScaffold> {
  _FlowRoute<dynamic>? _route;
  int _gen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    final route = r is _FlowRoute ? r : null;
    if (route == _route) return;
    _route?.returned.removeListener(_replay);
    _route = route;
    _route?.returned.addListener(_replay);
  }

  void _replay() {
    if (mounted) setState(() => _gen++);
  }

  @override
  void dispose() {
    _route?.returned.removeListener(_replay);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shift = FlowScaffold.shiftOf(context);
    return Scaffold(
      backgroundColor: HaruColors.cream,
      body: LayoutBuilder(
        builder: (context, c) {
          final page = SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                widget.builder(context, c.maxHeight, shift),
                if (widget.back != null)
                  Positioned(left: 16, right: 28, top: 54 + shift, height: 52, child: widget.back!),
              ],
            ),
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Stack(
                children: [
                  // Branches cover the first screen, behind the content.
                  SizedBox(
                    height: c.maxHeight,
                    width: double.infinity,
                    child: const Stack(children: [SideBranches()]),
                  ),
                  widget.entrance ? Entrance(key: ValueKey(_gen), child: page) : page,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Back chevron + optional step dots on the right ("가입 1 · 2 · 3").
class FlowBackRow extends StatelessWidget {
  const FlowBackRow({super.key, required this.onBack, this.step, this.steps = 3});

  final VoidCallback onBack;

  /// 0-based current step; null hides the dots.
  final int? step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackChevron(onTap: onBack),
        const Spacer(),
        if (step != null)
          Row(
            children: [
              for (var i = 0; i < steps; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Container(
                  width: i == step ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == step
                        ? HaruColors.forest
                        : i < step!
                            ? HaruColors.softGreen
                            : HaruColors.fieldBorder,
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Form screens: padding 110 28 70, vertically centered in one screen.
class FlowForm extends StatelessWidget {
  const FlowForm({
    super.key,
    required this.minHeight,
    required this.shift,
    required this.children,
  });

  final double minHeight;
  final double shift;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 110 + shift, 28, 70),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Flow pages swap instantly, like the prototype's `flowTo` (the old page is
/// gone at once and the new one plays its own `hrFadeUp`).
Route<T> flowRoute<T>(Widget page) => _FlowRoute<T>(page);

class _FlowRoute<T> extends PageRouteBuilder<T> {
  _FlowRoute(Widget page)
      : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => page,
        );

  /// Ticks when a flow page pushed above this one is popped.
  final returned = ValueNotifier<int>(0);

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    if (nextRoute is _FlowRoute) returned.value++;
  }
}

/// After any successful sign-in: register for pushes, warm the family cache
/// and replace the whole stack with 홈 or 가족 선택.
void goAfterLogin(BuildContext context, {required bool hasFamily}) {
  PushNotificationService.instance.registerCurrentDevice();
  if (hasFamily) FamilyContext.instance.refresh().ignore();
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    flowRoute<void>(hasFamily ? const HomeShell() : const FamilySelectScreen()),
    (_) => false,
  );
}
