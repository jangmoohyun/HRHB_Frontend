import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'diary_shared.dart';

/// 23 가족 일지 탭.
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
      final today = _isThisMonth ? await DiaryDayView.load(_today) : _todayView;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text('일지', style: HaruType.screenTitle)),
                    Text('하루 1개 · 가족과 함께 봐요', style: haruText(12, color: HaruColors.inkSecondary)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _error
                  ? HaruErrorState(onRetry: _load)
                  : _days == null
                      ? const HaruSkeleton()
                      : RefreshIndicator(
                          color: HaruColors.primary,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, kTabBarClearance),
                            children: [
                              if (_isThisMonth) ...[
                                HaruRise(
                                  duration: const Duration(milliseconds: 450),
                                  child: _MyWeatherCard(
                                    today: _todayView,
                                    onPick: (w) => _compose(weather: w),
                                    onEdit: () => _compose(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _monthNav(),
                              _dayStrip(),
                              const SizedBox(height: 12),
                              ..._selectedDay(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthNav() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _navBtn(LucideIcons.chevronLeft, '이전 달', () => _shiftMonth(-1)),
          Expanded(
            child: Text(
              '${_month.year}년 ${_month.month}월',
              textAlign: TextAlign.center,
              style: haruText(16, weight: FontWeight.w700),
            ),
          ),
          Opacity(
            opacity: _isThisMonth ? 0.3 : 1,
            child: _navBtn(LucideIcons.chevronRight, '다음 달', _isThisMonth ? null : () => _shiftMonth(1)),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: HaruColors.ink),
        ),
      );

  Widget _dayStrip() {
    final days = _dayList();
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
        child: Text('이 달에 저장된 일지가 없어요', style: haruText(13, color: HaruColors.inkSecondary)),
      );
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final cal = _calFor(d);
          final w = HaruWeather.fromWire(cal?.familyWeather) ??
              (sameDay(d, _today) ? _todayView?.composite : null);
          final sel = sameDay(d, _selected);
          final sub = sel ? Colors.white.withValues(alpha: 0.72) : HaruColors.inkTertiary;
          return HaruRise(
            delay: Duration(milliseconds: i * 40),
            duration: const Duration(milliseconds: 400),
            child: Pressable(
              onTap: () => _loadDay(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? HaruColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(HaruRadius.xl),
                  boxShadow: HaruShadows.s1,
                ),
                child: Column(
                  children: [
                    Text(sameDay(d, _today) ? '오늘' : dowOf(d), style: haruText(11, color: sub)),
                    const SizedBox(height: 6),
                    Text(
                      '${d.day}',
                      style: haruText(18, weight: FontWeight.w700, color: sel ? Colors.white : HaruColors.ink, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    WeatherTile(
                      weather: w,
                      size: 28,
                      radius: 8,
                      iconSize: 16,
                      iconColor: HaruColors.ink,
                      emptyColor: HaruColors.fillTranslucent,
                      emptyBorder: Colors.transparent,
                      emptyIconColor: HaruColors.ink,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cal == null ? '–' : '${cal.temperature.toStringAsFixed(1)}°',
                      style: haruText(11, color: sub),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _selectedDay() {
    if (!_isThisMonth && _dayList().isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: HaruColors.ceramic,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(LucideIcons.notebook, size: 26, color: HaruColors.inkSecondary),
              const SizedBox(height: 6),
              Text('이 달의 일지가 없어요', style: haruText(15, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('일지는 오늘 날짜에만 쓸 수 있어요.', style: haruText(13, color: HaruColors.inkSecondary)),
            ],
          ),
        ),
      ];
    }
    final day = _day;
    final composite = day?.composite;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '${_selected.month}월 ${_selected.day}일 ${dowOf(_selected)}요일',
          style: HaruType.sectionTitle,
        ),
      ),
      const SizedBox(height: 12),
      if (day == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: HaruColors.primary)),
        )
      else ...[
        HaruRise(
          duration: const Duration(milliseconds: 450),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(HaruRadius.xl),
              boxShadow: HaruShadows.s1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    WeatherTile(
                      weather: composite,
                      size: 52,
                      radius: 14,
                      iconSize: 26,
                      iconColor: HaruColors.ink,
                      emptyColor: HaruColors.fillTranslucent,
                      emptyBorder: Colors.transparent,
                      emptyIconColor: HaruColors.ink,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('그날의 가족 날씨', style: haruText(12, color: HaruColors.inkSecondary)),
                        const SizedBox(height: 2),
                        Text(composite?.label ?? '아직 몰라요', style: haruText(17, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '가족 온도 ${day.temperature.toStringAsFixed(1)}°C',
                          style: haruText(13, color: HaruColors.inkSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MembersWeatherGrid(
                  members: day.members,
                  isToday: sameDay(day.date, _today),
                  onAddMine: () => _compose(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final e in day.entries) ...[
          HaruRise(
            delay: const Duration(milliseconds: 80),
            duration: const Duration(milliseconds: 450),
            child: DiaryEntryCard(member: e.member, entry: e.entry),
          ),
          const SizedBox(height: 12),
        ],
        if (day.entries.isEmpty) const CeramicNote('이 날 남긴 일지가 없어요'),
      ],
    ];
  }
}

class _MyWeatherCard extends StatelessWidget {
  const _MyWeatherCard({required this.today, required this.onPick, required this.onEdit});

  final DiaryDayView? today;
  final ValueChanged<HaruWeather> onPick;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final mine = today?.myEntry;
    final myWeather = HaruWeather.fromWire(mine?.weather);
    final others = today?.members.where((m) => !m.member.isMe).toList() ??
        [
          for (final m in FamilyContext.instance.value?.members ?? const <MemberLook>[])
            if (!m.isMe) MemberWeather(member: m, weather: null),
        ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('오늘 나의 날씨는?', style: haruText(17, weight: FontWeight.w700))),
              Text('가족 일지 · 하루 1개', style: haruText(12, color: HaruColors.inkSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          if (mine == null || myWeather == null)
            Row(
              children: [
                for (final w in HaruWeather.values) ...[
                  if (w != HaruWeather.values.first) const SizedBox(width: 6),
                  Expanded(
                    child: Pressable(
                      onTap: () => onPick(w),
                      child: Column(
                        children: [
                          WeatherTile(weather: w, size: 50, radius: 14, iconSize: 22, iconColor: HaruColors.ink),
                          const SizedBox(height: 6),
                          Text(
                            w.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: haruText(12, color: HaruColors.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeatherTile(weather: myWeather, size: 50, radius: 14, iconSize: 22, iconColor: HaruColors.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 나의 날씨 · ${myWeather.label}',
                        style: haruText(13, weight: FontWeight.w600, color: HaruColors.inkSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(mine.content, style: haruText(15, height: 1.5)),
                    ],
                  ),
                ),
                Pressable(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text('수정', style: haruText(14, weight: FontWeight.w600, color: HaruColors.house)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          const SizedBox(height: 1, child: ColoredBox(color: HaruColors.inkDivider)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text('가족의 날씨', style: haruText(13, color: HaruColors.inkSecondary))),
              for (final m in others) ...[
                const SizedBox(width: 12),
                Column(
                  children: [
                    WeatherTile(
                      weather: m.weather,
                      size: 32,
                      radius: 9,
                      iconSize: 16,
                      iconColor: HaruColors.ink,
                      emptyColor: Colors.white,
                      emptyBorder: HaruColors.inkLineSoft,
                      emptyIconColor: HaruColors.inkChevron,
                    ),
                    const SizedBox(height: 4),
                    Text(m.member.short, style: haruText(11, color: HaruColors.inkSecondary)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
