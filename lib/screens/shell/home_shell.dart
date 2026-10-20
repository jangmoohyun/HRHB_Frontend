import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/app_prefs.dart';
import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_temperature.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../album/albums_screen.dart';
import '../archive/archive_screen.dart';
import '../diary/diary_screen.dart';
import '../family/family_tab_screen.dart';
import '../home/today_screen.dart';

enum HaruTab { archive, diary, home, album, family }

/// Bottom padding every scrollable tab/page ends with (prototype: 130px) so
/// the floating nav bar never covers the last row.
const double kNavClearance = 130;

/// Lets screens switch tabs or push onto a tab's navigator.
class HomeShellScope extends InheritedWidget {
  const HomeShellScope({super.key, required this.state, required super.child});

  final HomeShellState state;

  static HomeShellState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellScope>()?.state;

  static HomeShellState of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}

/// 기록 · 일지 · 홈 · 앨범 · 가족, each with its own navigator so the nav bar
/// stays on pushed pages (the prototype keeps it on every in-app page).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  HaruTab _tab = HaruTab.home;
  HaruTab get currentTab => _tab;

  final _keys = {
    for (final t in HaruTab.values) t: GlobalKey<NavigatorState>(),
  };
  final _visited = <HaruTab>{HaruTab.home};

  final _tokenStorage = TokenStorage();
  final _api = ApiClient();

  /// Bumped when data changed somewhere and tab roots should reload.
  final refreshTick = ValueNotifier<int>(0);

  /// The visible tab, for screens that replay their entrance when shown.
  final tabListenable = ValueNotifier<HaruTab>(HaruTab.home);

  @override
  void initState() {
    super.initState();
    FamilyContext.instance.ensure().ignore();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowTemperaturePopup(),
    );
  }

  @override
  void dispose() {
    refreshTick.dispose();
    tabListenable.dispose();
    super.dispose();
  }

  NavigatorState? navigatorOf(HaruTab tab) => _keys[tab]!.currentState;

  void switchTo(HaruTab tab, {bool popToRoot = true}) {
    if (popToRoot) navigatorOf(tab)?.popUntil((r) => r.isFirst);
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    tabListenable.value = tab;
  }

  /// Switch to [tab] and push [page] on its navigator.
  void pushOn(HaruTab tab, Widget page) {
    switchTo(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorOf(tab)?.push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  void notifyDataChanged() => refreshTick.value++;

  /// The prototype's nav taps always clear the page (`page: null`).
  void _onTabTap(HaruTab tab) => switchTo(tab);

  Future<void> _maybeShowTemperaturePopup() async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (await _tokenStorage.readTempPopupShownDate() == today) return;
      final temp = await AuthedCall.run(_api.fetchFamilyTemperature);
      if (!mounted) return;
      // Only a visible change earns the popup.
      final delta = temp.deltaFromYesterday;
      if (delta.abs() < 0.05) return;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await showTemperaturePopup(context, delta: delta);
      await _tokenStorage.saveTempPopupShownDate(today);
    } catch (_) {
      // Optional UX; never block home.
    }
  }

  void _handleBack() {
    final nav = navigatorOf(_tab);
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_tab != HaruTab.home) {
      switchTo(HaruTab.home, popToRoot: false);
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _rootFor(HaruTab tab) => switch (tab) {
    HaruTab.archive => const ArchiveScreen(),
    HaruTab.diary => const DiaryScreen(),
    HaruTab.home => const TodayScreen(),
    HaruTab.album => const AlbumsScreen(),
    HaruTab.family => const FamilyTabScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return HomeShellScope(
      state: this,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: HaruColors.cream,
          // The keyboard slides over the nav bar; pages pad for it themselves.
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ValueListenableBuilder<int>(
                      valueListenable: AppPrefs.fontSize,
                      builder: (context, size, child) =>
                          ZoomBox(zoom: AppPrefs.zooms[size], child: child!),
                      child: IndexedStack(
                        index: _tab.index,
                        children: [
                          for (final t in HaruTab.values)
                            _visited.contains(t)
                                ? _TabFade(
                                    active: t == _tab,
                                    // Hidden tabs stop their looping art.
                                    child: TickerMode(
                                      enabled: t == _tab,
                                      child: Navigator(
                                        key: _keys[t],
                                        onGenerateRoute: (settings) =>
                                            MaterialPageRoute<void>(
                                              settings: settings,
                                              builder: (_) => _rootFor(t),
                                            ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: _NavBar(current: _tab, onTap: _onTabTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `hrFadeUp` whenever a tab becomes active (the prototype re-mounts it).
class _TabFade extends StatefulWidget {
  const _TabFade({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: HaruMotion.screen)
    ..value = 1;

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = HaruMotion.out.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Floating pill bar: left/right 20, bottom 16, 70 tall inside a 1px
/// border, translucent mint.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onTap});

  final HaruTab current;
  final ValueChanged<HaruTab> onTap;

  static const _items = [
    (HaruTab.archive, '기록', Symbols.calendar_month_rounded),
    (HaruTab.diary, '일지', Symbols.edit_note_rounded),
    (HaruTab.home, '홈', Symbols.home_rounded),
    (HaruTab.album, '앨범', Symbols.photo_library_rounded),
    (HaruTab.family, '가족', Symbols.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // height:70px is the content box (no border-box): + 1px border = 72.
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: HaruColors.navFill,
        border: Border.all(color: HaruColors.navBorder),
        borderRadius: BorderRadius.circular(22),
        boxShadow: HaruShadows.shadow2,
      ),
      child: Row(
        children: [
          for (final (tab, label, icon) in _items)
            Expanded(
              child: Pressable(
                onTap: () => onTap(tab),
                semanticLabel: label,
                child: tab == HaruTab.home
                    ? _CenterItem(selected: current == tab)
                    : _SideItem(
                        selected: current == tab,
                        label: label,
                        icon: icon,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.selected,
    required this.label,
    required this.icon,
  });

  final bool selected;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? HaruColors.forest : HaruColors.inkMuted;
    return SizedBox(
      height: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // pill 52×32: forest + white icon when selected, translateY(-1px);
          // transition background 220ms ease, transform 300ms (.2,1.4,.4,1)
          AnimatedSlide(
            offset: Offset(0, selected ? -1 / 32 : 0),
            duration: const Duration(milliseconds: 300),
            curve: HaruMotion.pop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.ease,
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? HaruColors.forest : Colors.transparent,
                borderRadius: BorderRadius.circular(HaruRadius.full),
              ),
              child: Icon(icon, size: 25, color: selected ? Colors.white : HaruColors.inkMuted),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: hr(
              13.5,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: fg,
              letterSpacing: -.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterItem extends StatelessWidget {
  const _CenterItem({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 62px circle at top -8 with a 5px cream ring (box-shadow spread).
          Positioned(
            top: -8,
            child: AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: const Duration(milliseconds: 350),
              curve: HaruMotion.pop,
              child: AnimatedContainer(
                // transition: background 250ms (CSS default ease)
                duration: const Duration(milliseconds: 250),
                curve: Curves.ease,
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: selected ? HaruColors.forest : HaruColors.softGreen,
                  shape: BoxShape.circle,
                  // CSS paints the first shadow on top: the cream ring covers
                  // the green glow; Flutter paints in list order, so reverse.
                  boxShadow: [
                    ...HaruShadows.homeTab,
                    const BoxShadow(color: HaruColors.cream, spreadRadius: 5),
                  ],
                ),
                child: const Icon(
                  Symbols.home_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
