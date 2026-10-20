import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_temperature.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'settings_page.dart';



/// 가족 탭 — family card, temperature gauge, this month's participation;
/// ⚙ opens 설정.
class FamilyTabScreen extends StatefulWidget {
  const FamilyTabScreen({super.key});

  @override
  State<FamilyTabScreen> createState() => _FamilyTabScreenState();
}

class _FamilyTabScreenState extends State<FamilyTabScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  FamilySnapshot? _fam;
  FamilyTemperatureResult? _temp;
  Map<DateTime, Set<int>>? _status;
  bool _codeLit = false;
  HomeShellState? _shell;
  bool _visible = false;

  // The prototype swaps pages: coming back from 설정 remounts the tab, so
  // its hrFadeUp plays again (tab switches get theirs from the shell).
  bool _covered = false;
  int _entry = 0;

  // Gauge count-up from 20° (1.6s after 300ms) whenever the tab shows.
  late final _gaugeC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  Timer? _gaugeDelay;

  @override
  void initState() {
    super.initState();
    _fam = FamilyContext.instance.value;
    FamilyContext.instance.addListener(_onFamily);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = HomeShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.tabListenable.removeListener(_syncVisibility);
      _shell?.refreshTick.removeListener(_load);
      _shell = shell;
      _shell?.tabListenable.addListener(_syncVisibility);
      _shell?.refreshTick.addListener(_load);
    }
    ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
  }

  @override
  void dispose() {
    FamilyContext.instance.removeListener(_onFamily);
    _shell?.tabListenable.removeListener(_syncVisibility);
    _shell?.refreshTick.removeListener(_load);
    _gaugeDelay?.cancel();
    _gaugeC.dispose();
    super.dispose();
  }

  void _onFamily() {
    if (mounted) setState(() => _fam = FamilyContext.instance.value);
  }

  void _syncVisibility() {
    if (!mounted) return;
    final onTab = _shell?.tabListenable.value == HaruTab.family;
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final visible = onTab && current;
    if (!onTab) _covered = false;
    if (visible == _visible) return;
    _visible = visible;
    if (onTab && !current) _covered = true;
    if (!visible) return;
    if (_covered) {
      _covered = false;
      setState(() => _entry++);
    }
    _runGauge();
  }

  void _runGauge() {
    _gaugeDelay?.cancel();
    _gaugeC.value = 0;
    _gaugeDelay = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _gaugeC.forward(from: 0);
    });
  }

  Future<void> _load() async {
    try {
      final fam = await FamilyContext.instance.refresh();
      if (mounted) setState(() => _fam = fam);
    } catch (_) {}
    final now = DateTime.now();
    final hadTemp = _temp != null;
    await Future.wait([
      () async {
        try {
          _temp = await AuthedCall.run(_api.fetchFamilyTemperature);
        } catch (_) {}
      }(),
      () async {
        try {
          final days = await PendingApi.instance.fetchAnswerStatus(year: now.year, month: now.month);
          _status = {for (final d in days) dateOnly(d.date): d.answeredUserIds};
        } catch (_) {}
      }(),
    ]);
    if (!mounted) return;
    setState(() {});
    if (!hadTemp && _temp != null && _visible) _runGauge();
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fam = _fam;
    return RefreshIndicator(
      color: HaruColors.forest,
      backgroundColor: HaruColors.ivory,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, kNavClearance),
        children: [
          Entrance(
            key: ValueKey(_entry),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(child: TabHeader(title: '우리 가족')),
                    Positioned(
                      right: -8,
                      top: -2,
                      child: _GearButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (fam != null) _familyCard(fam),
                const SizedBox(height: 10),
                Center(child: _gauge()),
                const SizedBox(height: 12),
                if (fam != null) _participation(fam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyCard(FamilySnapshot fam) {
    final days = fam.daysTogether;
    return HrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fam.name} 가족', style: hrHand(30, height: 1.05)),
                    const SizedBox(height: 4),
                    Text(
                      '구성원 ${fam.members.length}명${days == null ? '' : ' · 함께한 지 $days일'}',
                      style: hr(14.5, color: HaruColors.inkMuted),
                    ),
                  ],
                ),
              ),
              // Every avatar (the first too) has margin-left -6.
              SizedBox(
                width: fam.members.length * 26.0,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < fam.members.length; i++)
                      Positioned(
                        left: i * 26.0 - 6,
                        child: MemberAvatar(
                          member: fam.members[i],
                          size: 32,
                          fontSize: 14.5,
                          hand: true,
                          ring: HaruColors.ivory,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: HaruColors.mint, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('가족 코드', style: hr(13.5, color: HaruColors.inkMuted)),
                      Transform.translate(
                        offset: const Offset(-4, 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.ease,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _codeLit ? const Color(0x597FA87A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(fam.code, style: hrHand(22, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CopyCodeButton(
                  code: fam.code,
                  pill: true,
                  height: 34,
                  radius: HaruRadius.full,
                  fontSize: 14,
                  iconSize: 16,
                  onCopied: (on) => setState(() => _codeLit = on),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gauge() {
    final t = _temp;
    return AnimatedBuilder(
      animation: _gaugeC,
      builder: (_, _) {
        final target = t?.temperature ?? 36.5;
        final e = Curves.easeOutCubic.transform(_gaugeC.value);
        final shown = ((20 + (target - 20) * e) * 10).round() / 10;
        return TemperatureGauge(
          temperature: t == null ? 36.5 : shown,
          statusLabel: t?.statusLabel.isNotEmpty == true ? t!.statusLabel : '따뜻해요',
          bubbleText: t?.bubbleText.isNotEmpty == true ? t!.bubbleText : '가족이 따뜻한 하루를 나눴어요!',
          delta: t?.deltaFromYesterday ?? 0,
          accent: parseHex(t?.colorHex) ?? HaruColors.warmIcon,
          width: 362,
          height: 380,
        );
      },
    );
  }

  Widget _participation(FamilySnapshot fam) {
    final today = dateOnly(DateTime.now());
    final status = _status;
    return HrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SproutHeading('이번 달 참여'),
          const SizedBox(height: 12),
          for (var i = 0; i < fam.members.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            () {
              final m = fam.members[i];
              final n = status == null
                  ? 0
                  : status.entries
                      .where((e) => !e.key.isAfter(today) && e.value.contains(m.userId))
                      .length;
              final total = today.day;
              return Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: hrHand(15, color: HaruColors.ink)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                      child: Container(
                        height: 10,
                        color: HaruColors.gaugeTrack,
                        alignment: Alignment.centerLeft,
                        child: status == null
                            ? null
                            : FractionallySizedBox(
                                widthFactor: (n / total).clamp(0.0, 1.0),
                                child: Entrance(
                                  key: ValueKey('p${m.userId}$n'),
                                  kind: EntranceKind.grow,
                                  delay: stagger(i, 90, 300),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: tempColor(20 + n * 4.2),
                                      borderRadius: BorderRadius.circular(HaruRadius.full),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    child: Text(
                      status == null ? '–' : '$n/$total일',
                      textAlign: TextAlign.right,
                      style: hr(14.5, color: HaruColors.inkMuted),
                    ),
                  ),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }
}

/// ⚙ 44×44: `style-active` rotate(60deg) scale(.92), 300ms (.2,1.4,.4,1).
class _GearButton extends StatefulWidget {
  const _GearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '설정',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        // Plus the frame's `cursor: pointer` `:active` (scale .95,
        // brightness .96), instant since the element has a transition.
        child: Transform.scale(
          scale: _down ? .95 : 1,
          child: ColorFiltered(
            colorFilter: brightnessFilter(_down ? .96 : 1),
            child: AnimatedRotation(
              turns: _down ? 60 / 360 : 0,
              duration: const Duration(milliseconds: 300),
              curve: HaruMotion.pop,
              child: AnimatedScale(
                scale: _down ? .92 : 1,
                duration: const Duration(milliseconds: 300),
                curve: HaruMotion.pop,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Symbols.settings_rounded, size: 26, color: HaruColors.forest),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
