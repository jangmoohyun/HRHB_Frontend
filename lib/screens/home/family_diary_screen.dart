import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/linkable_text.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _ink = Color(0xFF2F3A2C);
const _hairline = Color(0xFFE5E8E0);
const _fillSoft = Color(0xFFF3F6EF);

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// Wire emoji ↔ label / tint / icon (renewal HaruWeather, Material icons).
enum _Weather {
  sun('☀️', '맑음', Icons.wb_sunny_rounded, Color(0xFFF5E6A8)),
  partly('⛅', '구름 조금', Icons.wb_cloudy_rounded, Color(0xFFF5C9A8)),
  cloud('☁️', '흐림', Icons.cloud_rounded, Color(0xFFB8D4D0)),
  rain('🌧️', '비', Icons.umbrella_rounded, Color(0xFFB8D4E8)),
  storm('⛈️', '천둥번개', Icons.thunderstorm_rounded, Color(0xFFD4C4E8));

  const _Weather(this.wire, this.label, this.icon, this.tint);
  final String wire;
  final String label;
  final IconData icon;
  final Color tint;

  static _Weather? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final w in values) {
      if (w.wire == value) return w;
    }
    final stripped = value.replaceAll('️', '');
    for (final w in values) {
      if (w.wire.replaceAll('️', '') == stripped) return w;
    }
    return null;
  }

  static _Weather? mode(Iterable<_Weather?> list) {
    final counts = <_Weather, int>{};
    for (final w in list) {
      if (w != null) counts[w] = (counts[w] ?? 0) + 1;
    }
    _Weather? best;
    for (final e in counts.entries) {
      if (best == null || e.value > counts[best]!) best = e.key;
    }
    return best;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _needsTokenRefresh(ApiException e) {
  if (e.statusCode == 401 || e.statusCode == 403) return true;
  return e.message.contains('(401)') || e.message.contains('(403)');
}

String _ampmTime(DateTime date) {
  final local = date.toLocal();
  final isAm = local.hour < 12;
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${isAm ? '오전' : '오후'} $hour12:$minute';
}

String _shortRole(String roleLabel) {
  if (roleLabel.contains('할아버지') || roleLabel == 'GRANDFATHER') {
    return '할아버지';
  }
  if (roleLabel.contains('할머니') || roleLabel == 'GRANDMOTHER') {
    return '할머니';
  }
  if (roleLabel.contains('아빠') || roleLabel == 'FATHER') return '아빠';
  if (roleLabel.contains('엄마') || roleLabel == 'MOTHER') return '엄마';
  if (roleLabel.contains('아들') || roleLabel == 'SON') return '아들';
  if (roleLabel.contains('딸') || roleLabel == 'DAUGHTER') return '딸';
  return roleLabel.length <= 3 ? roleLabel : roleLabel.substring(0, 2);
}

class FamilyDiaryScreen extends StatefulWidget {
  const FamilyDiaryScreen({
    super.key,
    this.bottomNavClearance = 0,
  });

  final double bottomNavClearance;

  @override
  State<FamilyDiaryScreen> createState() => _FamilyDiaryScreenState();
}

class _FamilyDiaryScreenState extends State<FamilyDiaryScreen> {
  final _api = ApiClient();
  final _tokens = TokenStorage();

  final _today = _dateOnly(DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  List<DiaryCalendarDayResult>? _days;
  DiaryDayResult? _day;
  DiaryDayResult? _todayView;
  bool _loading = true;
  String? _error;

  bool get _isThisMonth =>
      _month.year == _today.year && _month.month == _today.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    var access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      return await action(access);
    } on ApiException catch (e) {
      if (!_needsTokenRefresh(e)) rethrow;
      final refresh = await _tokens.readRefreshToken();
      final userId = await _tokens.readUserId();
      if (refresh == null || userId == null) rethrow;
      final pair = await _api.refresh(refresh);
      await _tokens.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return action(pair.accessToken);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cal = await _withAuth(
        (t) => _api.fetchDiaryCalendar(
          accessToken: t,
          year: _month.year,
          month: _month.month,
        ),
      );
      DiaryDayResult? today;
      if (_isThisMonth) {
        today = await _withAuth(
          (t) => _api.fetchDiaryDay(accessToken: t, date: _today),
        );
      } else {
        today = _todayView;
      }
      if (!mounted) return;
      setState(() {
        _days = cal.days;
        _todayView = today;
        _loading = false;
      });
      await _loadDay(_selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadDay(DateTime d) async {
    final date = _dateOnly(d);
    setState(() {
      _selected = date;
      _day = _sameDay(date, _today) ? _todayView : null;
    });
    try {
      final v = await _withAuth(
        (t) => _api.fetchDiaryDay(accessToken: t, date: date),
      );
      if (!mounted || !_sameDay(date, _selected)) return;
      setState(() {
        _day = v;
        if (_sameDay(date, _today)) _todayView = v;
      });
    } catch (_) {}
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(_today.year, _today.month))) return;
    setState(() {
      _month = next;
      _days = null;
      _day = null;
      _loading = true;
    });
    final isThis = next.year == _today.year && next.month == _today.month;
    _selected = isThis ? _today : DateTime(next.year, next.month + 1, 0);
    await _load();
    final days = _dayList();
    if (!isThis && days.isNotEmpty && mounted) {
      await _loadDay(days.first);
    }
  }

  List<DateTime> _dayList() {
    final set = <DateTime>{
      for (final d in _days ?? const <DiaryCalendarDayResult>[])
        if (d.entryCount > 0) _dateOnly(d.date),
      if (_isThisMonth) _today,
    };
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  DiaryCalendarDayResult? _calFor(DateTime d) {
    for (final c in _days ?? const <DiaryCalendarDayResult>[]) {
      if (_sameDay(c.date, d)) return c;
    }
    return null;
  }

  Future<void> _compose({DateTime? forDate, _Weather? weather}) async {
    final target = _dateOnly(forDate ?? _selected);
    if (target.isAfter(_today)) return;

    final mine = _sameDay(target, _today)
        ? _todayView?.myEntry
        : (_sameDay(target, _day?.date ?? _selected) ? _day?.myEntry : null);
    final beforeFamily = _day != null && _sameDay(_day!.date, target)
        ? _Weather.mode(
            _day!.members.map((m) => _Weather.fromWire(m.weather)),
          )
        : null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiaryComposeSheet(
        date: target,
        isToday: _sameDay(target, _today),
        initialWeather: weather ?? _Weather.fromWire(mine?.weather),
        initialText: mine?.content ?? '',
        onSave: (content, wire) async {
          await _withAuth(
            (t) => _api.upsertTodayDiary(
              accessToken: t,
              content: content,
              weather: wire,
              date: target,
            ),
          );
        },
      ),
    );
    if (saved == true && mounted) {
      _selected = target;
      await _load();
      if (!mounted) return;
      final afterFamily = _day != null && _sameDay(_day!.date, target)
          ? _Weather.mode(
              _day!.members.map((m) => _Weather.fromWire(m.weather)),
            )
          : null;
      final changed = beforeFamily?.wire != afterFamily?.wire;
      final familyBit = afterFamily == null
          ? '가족 날씨에 반영돼요'
          : changed
              ? '가족 날씨 → ${afterFamily.label}'
              : '가족 날씨(${afterFamily.label})에 반영됐어요';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내 기분을 저장했어요 · $familyBit'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomClearance = widget.bottomNavClearance > 0
        ? widget.bottomNavClearance
        : MediaQuery.paddingOf(context).bottom + shortest * 0.22 + 4;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SideBranches(),
          Positioned(
            left: 0,
            right: 0,
            bottom: -6,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/todayquestionscreen/grass.png',
                width: size.width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: size.height * 0.01),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.05),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '일지',
                          style: TextStyle(
                            fontSize: shortest * 0.065,
                            fontWeight: FontWeight.w800,
                            color: _titleGreen,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      Text(
                        '기분 날씨 · 하루 1개',
                        style: TextStyle(
                          fontSize: shortest * 0.028,
                          color: _mutedGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: size.height * 0.008),
                Expanded(
                  child: _error != null
                      ? _ErrorPane(
                          message: _error!,
                          onRetry: _load,
                        )
                      : _loading && _days == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _titleGreen,
                              ),
                            )
                          : RefreshIndicator(
                              color: _titleGreen,
                              onRefresh: _load,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  bottomClearance,
                                ),
                                children: [
                                  _monthNav(),
                                  _dayStrip(),
                                  const SizedBox(height: 12),
                                  ..._selectedDaySection(),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthNav() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: _ink),
            tooltip: '이전 달',
          ),
          Expanded(
            child: Text(
              '${_month.year}년 ${_month.month}월',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          Opacity(
            opacity: _isThisMonth ? 0.3 : 1,
            child: IconButton(
              onPressed: _isThisMonth ? null : () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right_rounded, color: _ink),
              tooltip: '다음 달',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayStrip() {
    final days = _dayList();
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 14, 4, 14),
        child: Text(
          '이 달에 저장된 일지가 없어요',
          style: TextStyle(fontSize: 13, color: _mutedGrey),
        ),
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final cal = _calFor(d);
          final w = _Weather.fromWire(cal?.familyWeather) ??
              (_sameDay(d, _today)
                  ? _Weather.mode(
                      (_todayView?.members ?? const []).map(
                        (m) => _Weather.fromWire(m.weather),
                      ),
                    )
                  : null);
          final sel = _sameDay(d, _selected);
          final sub = sel
              ? Colors.white.withValues(alpha: 0.72)
              : _mutedGrey;
          return GestureDetector(
            onTap: () => _loadDay(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: sel ? _ink : _cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _sameDay(d, _today) ? '오늘' : _weekdays[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _ink,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _WeatherTile(
                      weather: w,
                      size: 22,
                      radius: 6,
                      iconSize: 13,
                      emptyColor: _fillSoft,
                      emptyBorder: Colors.transparent,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cal == null
                          ? '–'
                          : '${cal.temperature.toStringAsFixed(1)}°',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: sub,
                      ),
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

  List<Widget> _selectedDaySection() {
    if (!_isThisMonth && _dayList().isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: _fillSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              Icon(Icons.menu_book_outlined, size: 26, color: _mutedGrey),
              SizedBox(height: 6),
              Text(
                '이 달의 일지가 없어요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                '아직 이 달에 남긴 일지가 없어요.',
                style: TextStyle(fontSize: 13, color: _mutedGrey),
              ),
            ],
          ),
        ),
      ];
    }

    final day = _day;
    final composite = day == null
        ? null
        : _Weather.mode(
            day.members.map((m) => _Weather.fromWire(m.weather)),
          );

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '${_selected.month}월 ${_selected.day}일 ${_weekdays[_selected.weekday - 1]}요일',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _titleGreen,
            letterSpacing: -0.4,
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (day == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: _titleGreen),
          ),
        )
      else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey(composite?.wire ?? 'empty'),
                      child: _WeatherTile(
                        weather: composite,
                        size: 52,
                        radius: 14,
                        iconSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sameDay(day.date, _today)
                              ? '오늘의 가족 날씨'
                              : '그날의 가족 날씨',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mutedGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          composite?.label ?? '아직 몰라요',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          composite == null
                              ? '모두의 기분이 모이면 보여요'
                              : '가족 온도 ${day.temperature.toStringAsFixed(1)}°C · 기분 평균',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mutedGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '우리 마음 날씨',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _titleGreen,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '개인 기분이 모여 위 가족 날씨가 돼요',
                      style: TextStyle(fontSize: 12, color: _mutedGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MembersWeatherGrid(
                members: day.members,
                canWrite: !day.date.isAfter(_today),
                onAddMine: () => _compose(forDate: day.date),
                onEditMine: () => _compose(forDate: day.date),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!day.date.isAfter(_today) && day.myEntry == null) ...[
          _WriteTodayCard(
            isToday: _sameDay(day.date, _today),
            onWrite: () => _compose(forDate: day.date),
          ),
          const SizedBox(height: 12),
        ],
        for (final e in day.entries) ...[
          _DiaryEntryCard(
            entry: e,
            onEdit: e.isMe && !day.date.isAfter(_today)
                ? () => _compose(forDate: day.date)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (day.entries.isEmpty &&
            !(!day.date.isAfter(_today) && day.myEntry == null))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: _fillSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '이 날 남긴 일지가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _mutedGrey),
            ),
          ),
      ],
    ];
  }
}

// ── widgets ─────────────────────────────────────────────────────────────────

class _WeatherTile extends StatelessWidget {
  const _WeatherTile({
    required this.weather,
    this.size = 46,
    this.radius = 14,
    this.iconSize = 20,
    this.emptyIcon = Icons.remove,
    this.emptyColor = _fillSoft,
    this.emptyBorder = _hairline,
    this.emptyIconColor = _mutedGrey,
  });

  final _Weather? weather;
  final double size;
  final double radius;
  final double iconSize;
  final IconData emptyIcon;
  final Color emptyColor;
  final Color emptyBorder;
  final Color emptyIconColor;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: w?.tint ?? emptyColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: w == null ? emptyBorder : Colors.transparent,
        ),
      ),
      child: Icon(
        w?.icon ?? emptyIcon,
        size: iconSize,
        color: w == null ? emptyIconColor : _ink,
      ),
    );
  }
}

class _WriteTodayCard extends StatelessWidget {
  const _WriteTodayCard({
    required this.onWrite,
    this.isToday = true,
  });

  final VoidCallback onWrite;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: const Color(0x14000000),
      child: InkWell(
        onTap: onWrite,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD7E3D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.edit_outlined, color: _titleGreen, size: 22),
              const SizedBox(height: 8),
              Text(
                isToday ? '나의 기분 남기기' : '나의 기분 · 일지 남기기',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _titleGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '내 기분이 가족 날씨에 반영돼요',
                style: TextStyle(fontSize: 12, color: _mutedGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersWeatherGrid extends StatelessWidget {
  const _MembersWeatherGrid({
    required this.members,
    required this.canWrite,
    this.onAddMine,
    this.onEditMine,
  });

  final List<DiaryMemberWeatherResult> members;
  final bool canWrite;
  final VoidCallback? onAddMine;
  final VoidCallback? onEditMine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 6 * 3) / 4;
        return Wrap(
          spacing: 6,
          runSpacing: 10,
          children: [
            for (final m in members)
              SizedBox(
                width: w,
                child: _MemberTile(
                  member: m,
                  canAdd: canWrite &&
                      m.isMe &&
                      (m.weather == null || m.weather!.isEmpty),
                  canEdit: canWrite &&
                      m.isMe &&
                      m.weather != null &&
                      m.weather!.isNotEmpty,
                  onAdd: onAddMine,
                  onEdit: onEditMine,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canAdd,
    required this.canEdit,
    this.onAdd,
    this.onEdit,
  });

  final DiaryMemberWeatherResult member;
  final bool canAdd;
  final bool canEdit;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tile = _WeatherTile(
      weather: _Weather.fromWire(member.weather),
      size: 46,
      radius: 14,
      iconSize: 20,
      emptyIcon: canAdd ? Icons.add : Icons.remove,
      emptyIconColor: canAdd ? _titleGreen : const Color(0xFFC5C9BE),
    );
    final mood = _Weather.fromWire(member.weather);
    final col = Column(
      children: [
        tile,
        const SizedBox(height: 6),
        Text(
          member.isMe ? '나' : _shortRole(member.roleLabel),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          canAdd
              ? '기분 쓰기'
              : (mood?.label ?? '대기'),
          style: TextStyle(
            fontSize: 11,
            color: canAdd ? _titleGreen : _mutedGrey,
            fontWeight: canAdd ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
    if (canAdd) return GestureDetector(onTap: onAdd, child: col);
    if (canEdit) return GestureDetector(onTap: onEdit, child: col);
    return col;
  }
}

class _DiaryEntryCard extends StatelessWidget {
  const _DiaryEntryCard({required this.entry, this.onEdit});

  final DiaryEntryResult entry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final w = _Weather.fromWire(entry.weather);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  entry.isMe
                      ? '나'
                      : (entry.roleLabel.isNotEmpty
                          ? entry.roleLabel.substring(0, 1)
                          : '?'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _titleGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.roleLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                w?.icon ?? Icons.remove,
                size: 16,
                color: _mutedGrey,
              ),
              if (w != null) ...[
                const SizedBox(width: 4),
                Text(
                  w.label,
                  style: const TextStyle(fontSize: 12, color: _mutedGrey),
                ),
              ],
              const Spacer(),
              Text(
                _ampmTime(entry.createdAt),
                style: const TextStyle(fontSize: 12, color: _mutedGrey),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: _titleGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '수정',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LinkableText(
            entry.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: _bodyGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryComposeSheet extends StatefulWidget {
  const _DiaryComposeSheet({
    required this.date,
    required this.isToday,
    required this.initialWeather,
    required this.initialText,
    required this.onSave,
  });

  final DateTime date;
  final bool isToday;
  final _Weather? initialWeather;
  final String initialText;
  final Future<void> Function(String content, String weather) onSave;

  @override
  State<_DiaryComposeSheet> createState() => _DiaryComposeSheetState();
}

class _DiaryComposeSheetState extends State<_DiaryComposeSheet> {
  late _Weather? _w = widget.initialWeather;
  late final _text = TextEditingController(text: widget.initialText);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final w = _w;
    final text = _text.text.trim();
    if (w == null || text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(text, w.wire);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일지를 저장하지 못했어요. 다시 시도해 주세요.\n$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final invalid = _w == null || _text.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isToday
                    ? '오늘의 기분 · 일지'
                    : '${widget.date.month}월 ${widget.date.day}일 기분 · 일지',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _titleGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '기분을 고르면 가족 날씨에도 반영돼요. 하루 1개, 다시 쓰면 수정돼요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _mutedGrey, height: 1.35),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isToday ? '오늘의 기분 (날씨)' : '그날의 기분 (날씨)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _titleGreen,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final w in _Weather.values) ...[
                    if (w != _Weather.values.first) const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _w = w),
                        child: Column(
                          children: [
                            AnimatedScale(
                              scale: _w == w ? 1.08 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: w.tint,
                                  borderRadius: BorderRadius.circular(14),
                                  border: _w == w
                                      ? Border.all(
                                          color: _titleGreen,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(w.icon, size: 24, color: _ink),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              w.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _w == w
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _w == w ? _ink : _mutedGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.isToday ? '오늘의 한 줄' : '그날의 한 줄',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _titleGreen,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLines: 5,
                minLines: 5,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: _bodyGrey,
                ),
                decoration: InputDecoration(
                  hintText: widget.isToday
                      ? '오늘 기분은 어땠나요? 짧게 남겨 보세요.'
                      : '그날의 기분을 짧게 남겨 보세요.',
                  hintStyle: const TextStyle(color: _mutedGrey, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _softGreen, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: invalid || _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _titleGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _titleGreen.withValues(alpha: 0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving ? '저장 중…' : '저장하기',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(color: _titleGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideBranches extends StatelessWidget {
  const _SideBranches();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -size.width * 0.08,
            top: size.height * 0.12,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.34,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.16,
            child: Image.asset(
              'assets/images/todayquestionscreen/right_branch1.png',
              width: size.width * 0.36,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
