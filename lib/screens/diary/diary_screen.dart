import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'diary_shared.dart';

/// 일지 탭 — 오늘 나의 날씨, 날짜 칩, 그날의 가족 날씨와 일지.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _api = ApiClient();
  final _today = dateOnly(DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  List<DiaryCalendarDayResult>? _days;
  DiaryDayView? _day;
  DiaryDayView? _todayView;
  bool _error = false;
  bool _savingWeather = false;
  HomeShellState? _shell;

  bool get _isThisMonth => _month.year == _today.year && _month.month == _today.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = HomeShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.refreshTick.removeListener(_load);
      _shell = shell;
      _shell?.refreshTick.addListener(_load);
    }
  }

  @override
  void dispose() {
    _shell?.refreshTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      await FamilyContext.instance.ensure();
      final cal = await AuthedCall.run(
        (t) => _api.fetchDiaryCalendar(accessToken: t, year: _month.year, month: _month.month),
      );
      final today = await DiaryDayView.load(_today);
      if (!mounted) return;
      setState(() {
        _days = cal.days;
        _todayView = today;
      });
      await _loadDay(_selected);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _loadDay(DateTime d) async {
    setState(() {
      _selected = d;
      _day = sameDay(d, _today) ? _todayView : null;
    });
    try {
      final v = await DiaryDayView.load(d);
      if (mounted && sameDay(d, _selected)) setState(() => _day = v);
    } catch (_) {}
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(_today.year, _today.month))) return;
    setState(() {
      _month = next;
      _days = null;
      _day = null;
    });
    final isThis = next.year == _today.year && next.month == _today.month;
    _selected = isThis ? _today : DateTime(next.year, next.month + 1, 0);
    await _load();
    // Past months: select the most recent day that has an entry.
    final days = _dayList();
    if (!isThis && days.isNotEmpty && mounted) _loadDay(days.first);
  }

  Future<void> _compose({HaruWeather? weather}) async {
    final mine = _todayView?.myEntry;
    final saved = await showDiaryComposeSheet(
      context,
      initialWeather: weather ?? HaruWeather.fromWire(mine?.weather),
      initialText: mine?.content ?? '',
    );
    if (saved && mounted) {
      _selected = _today;
      HomeShellScope.maybeOf(context)?.notifyDataChanged();
    }
  }

  /// Weather tile tap saves right away and selects today (prototype
  /// `quickW`: "오늘의 날씨를 남겼어요."). Without an entry yet the content is
  /// empty — the server must accept a weather-only diary (BACKEND_API_TODO).
  Future<void> _quickWeather(HaruWeather w) async {
    if (_savingWeather) return;
    setState(() => _savingWeather = true);
    try {
      final content = _todayView?.myEntry?.content ?? '';
      await AuthedCall.run(
        (t) => _api.upsertTodayDiary(accessToken: t, content: content, weather: w.wire),
      );
      if (!mounted) return;
      _selected = _today;
      HaruToast.show(context, '오늘의 날씨를 남겼어요.');
      HomeShellScope.maybeOf(context)?.notifyDataChanged();
    } catch (_) {
      if (mounted) HaruToast.show(context, '날씨를 저장하지 못했어요.');
    } finally {
      if (mounted) setState(() => _savingWeather = false);
    }
  }

  /// Days with entries this month (+ today), newest first.
  List<DateTime> _dayList() {
    final set = <DateTime>{
      for (final d in _days ?? const <DiaryCalendarDayResult>[])
        if (d.entryCount > 0) dateOnly(d.date),
      if (_isThisMonth) _today,
    };
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  DiaryCalendarDayResult? _calFor(DateTime d) =>
      (_days ?? const <DiaryCalendarDayResult>[]).where((c) => sameDay(c.date, d)).firstOrNull;

  HaruWeather? _weatherFor(DateTime d) =>
      HaruWeather.fromWire(_calFor(d)?.familyWeather) ??
      (sameDay(d, _today) ? _todayView?.composite : null) ??
      (sameDay(d, _selected) ? _day?.composite : null);

  double? _tempFor(DateTime d) =>
      _calFor(d)?.temperature ??
      (sameDay(d, _today) ? _todayView?.temperature : null);

  @override
  Widget build(BuildContext context) {
    final myW = HaruWeather.fromWire(_todayView?.myEntry?.weather);
    final hasEntry = (_todayView?.myEntry?.content ?? '').isNotEmpty;
    return RefreshIndicator(
      color: HaruColors.forest,
      backgroundColor: HaruColors.ivory,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, kNavClearance),
        children: [
          Entrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(title: '우리 가족 일지', subtitle: '하루 1개 · 가족과 함께 봐요'),
                const SizedBox(height: 14),
                HrCard(
                  radius: 22,
                  shadow: HaruShadows.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text('오늘 나의 날씨는?', style: hr(18, color: HaruColors.forest))),
                          Text('${_today.month}/${_today.day} (${dowOf(_today)})',
                              style: hrHand(16, color: HaruColors.inkMuted)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      WeatherPicker(value: myW, onPick: _quickWeather),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: hasEntry ? '오늘의 일지 수정하기' : '오늘의 일지 작성하기',
                        onPressed: _todayView == null && !_error ? null : () => _compose(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _monthNav(),
                if (_error)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Pressable(
                        onTap: _load,
                        child: Text('일지를 불러오지 못했어요. 눌러서 다시 시도해 주세요.',
                            style: hr(15, color: HaruColors.inkMuted)),
                      ),
                    ),
                  )
                else if (_days != null) ...[
                  _dayChips(),
                  const SizedBox(height: 12),
                  _selectedCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                    child: SproutHeading('이날 우리 가족의 하루', size: 15),
                  ),
                  ..._entries(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Pressable(
          onTap: () => _shiftMonth(-1),
          semanticLabel: '이전 달',
          child: const Icon(Symbols.chevron_left_rounded, size: 24, color: HaruColors.forest),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 84),
          child: Text(
            '${_month.year}.${_month.month.toString().padLeft(2, '0')}',
            textAlign: TextAlign.center,
            style: hr(17, color: HaruColors.forest),
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
          onTap: _isThisMonth ? null : () => _shiftMonth(1),
          semanticLabel: '다음 달',
          child: Icon(
            Symbols.chevron_right_rounded,
            size: 24,
            color: _isThisMonth ? HaruColors.inkFaint : HaruColors.forest,
          ),
        ),
      ],
    );
  }

  Widget _dayChips() {
    final days = _dayList();
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text('이 달에 남긴 일지가 없어요', style: hr(15, color: HaruColors.inkMuted))),
      );
    }
    // margin-top 10 + padding 2 + item padding 4 = 16 above the chips.
    return SizedBox(
      height: 102,
      child: OverflowBox(
        maxWidth: MediaQuery.sizeOf(context).width,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Entrance(
            kind: EntranceKind.pop,
            delay: stagger(i, 50),
            child: _DayChip(
              date: days[i],
              weather: _weatherFor(days[i]),
              temp: _tempFor(days[i]),
              selected: sameDay(days[i], _selected),
              onTap: () => _loadDay(days[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedCard() {
    final d = _selected;
    final view = _day;
    final w = _weatherFor(d) ?? view?.composite;
    final temp = _tempFor(d) ?? view?.temperature;
    final isToday = sameDay(d, _today);
    final key = ValueKey(d);
    return HrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Entrance(
                key: key,
                kind: EntranceKind.pop,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: w?.bg ?? HaruColors.sand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(w?.icon ?? Symbols.remove_rounded, size: 34, color: w?.color ?? HaruColors.inkFaint),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d.month}/${d.day} (${dowOf(d)}) · 가족 날씨', style: hr(14, color: HaruColors.inkMuted)),
                    Entrance(
                      key: ValueKey('l$d'),
                      kind: EntranceKind.up,
                      delay: const Duration(milliseconds: 60),
                      child: Text(w?.label ?? '기록 없음', style: hr(21, color: HaruColors.forest)),
                    ),
                  ],
                ),
              ),
              if (temp != null)
                Entrance(
                  key: ValueKey('t$d'),
                  kind: EntranceKind.up,
                  delay: const Duration(milliseconds: 120),
                  child: Text('${temp.toStringAsFixed(1)}°C', style: hrHand(28, color: tempColor(temp))),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (view == null)
            const SizedBox(height: 76)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < view.members.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _MemberWeatherTile(
                      key: ValueKey('m$d${view.members[i].member.userId}'),
                      mw: view.members[i],
                      index: i,
                      canAdd: isToday && view.members[i].member.isMe && view.members[i].weather == null,
                      onAdd: () => _compose(),
                    ),
                  ),
                ],
                // Keep 4 columns when the family is smaller.
                for (var i = view.members.length; i < 4; i++) ...[
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _entries() {
    final view = _day;
    if (view == null) return const [SizedBox(height: 60)];
    if (view.entries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Center(child: Text('아직 작성된 일지가 없어요', style: hr(15, color: HaruColors.inkMuted))),
        ),
      ];
    }
    return [
      for (var i = 0; i < view.entries.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == view.entries.length - 1 ? 0 : 10),
          child: Entrance(
            key: ValueKey('e${view.date}$i'),
            kind: EntranceKind.up,
            delay: stagger(i, 80, 260),
            child: HrCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(view.entries[i].member.displayName, style: hrHand(17))),
                      Text(ampmTime(view.entries[i].entry.createdAt.toLocal()),
                          style: hr(13.5, color: HaruColors.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(view.entries[i].entry.content, style: hr(16, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.weather,
    required this.temp,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final HaruWeather? weather;
  final double? temp;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Pressable(
      onTap: onTap,
      scale: .94,
      duration: const Duration(milliseconds: 300),
      curve: HaruMotion.pop,
      semanticLabel: '${date.month}월 ${date.day}일',
      child: AnimatedSlide(
        offset: Offset(0, selected ? -4 / 80 : 0),
        duration: const Duration(milliseconds: 300),
        curve: HaruMotion.pop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 76,
          height: 80,
          decoration: BoxDecoration(
            color: selected ? HaruColors.panelGreen : HaruColors.ivory,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? HaruColors.forest : HaruColors.hairline, width: 1.4),
            boxShadow: selected ? [cssShadow(y: 6, blur: 14, color: const Color(0x2E3A6A3F))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${date.month}/${date.day}',
                  style: hrHand(15, height: 1, color: selected ? HaruColors.forest : HaruColors.inkMuted)),
              const SizedBox(height: 2),
              FloatLoop(
                enabled: selected,
                period: const Duration(milliseconds: 2400),
                distance: 6,
                delay: const Duration(milliseconds: 300),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: w?.bg ?? HaruColors.sand, shape: BoxShape.circle),
                  child: Icon(w?.icon ?? Symbols.remove_rounded, size: 20, color: w?.color ?? HaruColors.inkFaint),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                temp == null ? '–' : '${temp!.toStringAsFixed(1)}°',
                style: hrHand(14.5, height: 1, color: temp == null ? HaruColors.inkFaint : tempColor(temp!)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberWeatherTile extends StatelessWidget {
  const _MemberWeatherTile({
    super.key,
    required this.mw,
    required this.index,
    required this.canAdd,
    required this.onAdd,
  });

  final MemberWeather mw;
  final int index;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final w = mw.weather;
    final tile = Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: w?.bg ?? HaruColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: canAdd ? null : Border.all(color: HaruColors.hairline),
      ),
      child: Icon(
        w?.icon ?? (canAdd ? Symbols.add_rounded : Symbols.remove_rounded),
        size: 24,
        color: w?.color ?? (canAdd ? HaruColors.softGreen : HaruColors.inkFaint),
      ),
    );
    final col = Column(
      children: [
        Text(mw.member.isMe ? '나' : mw.member.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: hrHand(14, color: HaruColors.ink)),
        const SizedBox(height: 5),
        Entrance(
          kind: EntranceKind.pop,
          delay: stagger(index, 60, 160),
          child: canAdd ? DashedBox(color: HaruColors.softGreen, radius: 12, child: tile) : tile,
        ),
        const SizedBox(height: 5),
        Text(
          w?.label ?? (canAdd ? '남기기' : '기록 없음'),
          maxLines: 1,
          style: hr(13, color: HaruColors.inkMuted),
        ),
      ],
    );
    return canAdd
        ? Pressable(onTap: onAdd, scale: .96, duration: Duration.zero, inlineTransition: false, child: col)
        : col;
  }
}
