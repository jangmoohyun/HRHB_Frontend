import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../album/albums_screen.dart';
import '../archive/archive_screen.dart';
import '../archive/day_detail_screen.dart';
import '../diary/diary_screen.dart';
import '../family/family_tab_screen.dart';
import '../home/today_screen.dart';
import '../home/temperature_popup.dart';

enum HaruTab { archive, diary, home, album, family }

/// Space the floating tab bar covers; scrollable tab content ends with this
/// much padding (prototype: 110px spacer).
const double kTabBarClearance = 110;

/// Lets screens switch tabs or reach the tab bar metrics.
class HomeShellScope extends InheritedWidget {
  const HomeShellScope({super.key, required this.state, required super.child});

  final HomeShellState state;

  static HomeShellState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellScope>()?.state;

  static HomeShellState of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}

/// VER2 shell: 기록 · 일지 · 홈 · 앨범 · 가족, each with its own navigator so
/// the tab bar stays visible on pushed screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  HaruTab _tab = HaruTab.home;
  HaruTab get currentTab => _tab;

  final _keys = {for (final t in HaruTab.values) t: GlobalKey<NavigatorState>()};
  final _visited = <HaruTab>{HaruTab.home};

  final _tokenStorage = TokenStorage();
  final _api = ApiClient();

  /// Bumped when data changed somewhere and tab roots should reload.
  final refreshTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    HaruToast.tabBarDepth++;
    FamilyContext.instance.ensure().ignore();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTemperaturePopup());
  }

  @override
  void dispose() {
    HaruToast.tabBarDepth--;
    refreshTick.dispose();
    super.dispose();
  }

  NavigatorState? navigatorOf(HaruTab tab) => _keys[tab]!.currentState;

  void switchTo(HaruTab tab, {bool popToRoot = true}) {
    if (popToRoot) {
      navigatorOf(tab)?.popUntil((r) => r.isFirst);
    }
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  /// Switch to [tab] and push [page] on its navigator.
  void pushOn(HaruTab tab, Widget page) {
    switchTo(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorOf(tab)?.push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  void notifyDataChanged() => refreshTick.value++;

  void _onTabTap(HaruTab tab) {
    if (tab == _tab) {
      navigatorOf(tab)?.popUntil((r) => r.isFirst);
      return;
    }
    switchTo(tab, popToRoot: false);
  }

  Future<void> _maybeShowTemperaturePopup() async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (await _tokenStorage.readTempPopupShownDate() == today) return;
      final temp = await AuthedCall.run(_api.fetchFamilyTemperature);
      if (!mounted) return;
      // Same threshold as v1: only a visible change earns the popup.
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
    return HomeShellScope(
      state: this,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: HaruColors.canvas,
          body: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab.index,
                  children: [
                    for (final t in HaruTab.values)
                      _visited.contains(t)
                          ? _TabFade(
                              active: t == _tab,
                              child: Navigator(
                                key: _keys[t],
                                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                                  settings: settings,
                                  builder: (_) => _rootFor(t),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _TabBar(current: _tab, onTap: _onTabTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// hxFade (translateY 8px → 0 + fade, .38s) whenever a tab becomes active.
class _TabFade extends StatefulWidget {
  const _TabFade({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: HaruMotion.fade)
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
        final t = HaruMotion.standard.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onTap});

  final HaruTab current;
  final ValueChanged<HaruTab> onTap;

  static const _items = [
    (HaruTab.archive, '기록', LucideIcons.calendarDays),
    (HaruTab.diary, '일지', LucideIcons.notebookPen),
    (HaruTab.home, '홈', LucideIcons.house),
    (HaruTab.album, '앨범', LucideIcons.images),
    (HaruTab.family, '가족', LucideIcons.users),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: HaruShadows.tabBar,
      ),
      child: Row(
        children: [
          for (final (tab, label, icon) in _items)
            Expanded(
              child: tab == HaruTab.home
                  ? _CenterTab(selected: current == tab, label: label, onTap: () => onTap(tab))
                  : _SideTab(
                      selected: current == tab,
                      label: label,
                      icon: icon,
                      onTap: () => onTap(tab),
                    ),
            ),
        ],
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? HaruColors.accentName : HaruColors.inkQuiet;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // translateY(-2px) scale(1.12), .3s cubic-bezier(.2,1.4,.4,1)
            AnimatedSlide(
              offset: Offset(0, selected ? -2 / 22 : 0),
              duration: const Duration(milliseconds: 300),
              curve: HaruMotion.pop,
              child: AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 300),
                curve: HaruMotion.pop,
                child: Icon(icon, size: 22, color: fg),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: haruText(
                11,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterTab extends StatelessWidget {
  const _CenterTab({required this.selected, required this.label, required this.onTap});

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // The 62px circle sits at top:-24; its 5px white ring adds 5 more.
            Positioned(
              top: -29,
              child: AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 350),
                curve: HaruMotion.pop,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 72, // 62 + 5px white ring on each side
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: HaruShadows.homeTab,
                  ),
                  padding: const EdgeInsets.all(5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: selected ? HaruColors.logo : HaruColors.house,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.house, size: 26, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the day detail for [date] on the 기록 tab (used by 홈 and 알림).
/// The prototype maps `day` to the 기록 tab, so the tab bar follows.
void openDayOnArchive(BuildContext context, DateTime date) {
  HomeShellScope.of(context)
      .pushOn(HaruTab.archive, DayDetailScreen(date: dateOnly(date)));
}
