import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../answers/day_answers.dart';
import '../answers/family_answers_page.dart';
import '../answers/question_ref.dart';
import '../answers/write_answer_page.dart';
import '../shell/home_shell.dart';
import 'home_sheets.dart';
import 'notifications_screen.dart';

/// 홈 — 오늘의 질문 편지.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with TickerProviderStateMixin {
  final _api = ApiClient();
  final _today = dateOnly(DateTime.now());
  late DateTime _cur = _today;

  final _questions = <DateTime, QuestionRef>{};
  final _loadedMonths = <(int, int)>{};
  final _status = <DateTime, Set<int>>{};
  final _statusMonths = <(int, int)>{};

  DayAnswers? _answers;
  FamilyTemperatureResult? _temp;
  StreakSummary? _streak;
  bool _unread = false;
  bool _loaded = false;
  bool _error = false;
  HomeShellState? _shell;

  // Visibility — the prototype replays typing and the temperature count
  // every time 홈 comes back on screen.
  bool _visible = false;

  // Question typing (55ms per character after 380ms).
  int? _typed;
  Timer? _typeDelay;
  Timer? _typeTick;

  // Temperature count-up (1.1s after 300ms, ease-out cubic).
  late final _tempC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  double _tempFrom = 0;
  double? _lastSeenTemp;
  bool _tempFloat = false;
  Timer? _tempDelay;
  Timer? _floatTimer;

  // Day change slide (170ms out, 170ms in) and letter "open" on tap.
  double _cardShift = 0;
  bool _cardHidden = false;
  bool _cardAnimate = true;
  bool _changing = false;
  int _open = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = HomeShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.refreshTick.removeListener(_onDataChanged);
      _shell?.tabListenable.removeListener(_syncVisibility);
      _shell = shell;
      _shell?.refreshTick.addListener(_onDataChanged);
      _shell?.tabListenable.addListener(_syncVisibility);
    }
    // ModalRoute.of registers for isCurrent changes (a page pushed on top).
    ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
  }

  @override
  void dispose() {
    _shell?.refreshTick.removeListener(_onDataChanged);
    _shell?.tabListenable.removeListener(_syncVisibility);
    _typeDelay?.cancel();
    _typeTick?.cancel();
    _tempDelay?.cancel();
    _floatTimer?.cancel();
    _tempC.dispose();
    super.dispose();
  }

  void _syncVisibility() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final visible = (_shell?.tabListenable.value ?? HaruTab.home) == HaruTab.home && (route?.isCurrent ?? true);
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _startTyping();
      _runTemp();
    } else {
      _stopTyping();
    }
  }

  void _onDataChanged() {
    _statusMonths.clear();
    _refreshSide();
    _loadAnswers();
  }

  List<DateTime> get _week {
    final monday = _cur.subtract(Duration(days: _cur.weekday - 1));
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  QuestionRef get _question => _questions[_cur] ?? QuestionRef.waiting(_cur);

  String get _letterText {
    if (_error && _questions[_cur] == null) return '질문을 불러오지 못했어요.\n아래로 당겨서 다시 시도해 주세요.';
    if (!_loaded) return '';
    final q = _question;
    return q.isReady ? q.content : (q.waitingMessage ?? '');
  }

  // ── data ──────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _error = false);
    try {
      await FamilyContext.instance.ensure();
      await _ensureMonths(_week);
      if (mounted) setState(() => _loaded = true);
      _restartTypingIfVisible();
      await Future.wait([_loadAnswers(), _refreshSide()]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = true;
        });
      }
    }
  }

  /// Loads question months covering [days] (a week can span two months).
  Future<void> _ensureMonths(List<DateTime> days) async {
    final months = {for (final d in days) (d.year, d.month)}..removeWhere(_loadedMonths.contains);
    for (final (y, m) in months) {
      final res = await AuthedCall.run((t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m));
      for (final item in res.items) {
        _questions[dateOnly(item.date)] = QuestionRef.fromResult(item);
      }
      _loadedMonths.add((y, m));
    }
    if (days.any((d) => sameDay(d, _today)) && _questions[_today]?.isReady != true) {
      final today = await AuthedCall.run(_api.fetchTodayDailyQuestion);
      _questions[_today] = QuestionRef.fromResult(today);
    }
  }

  /// Side cards load independently; one failing never blanks the others.
  Future<void> _quietly(Future<void> Function() task) async {
    try {
      await task();
    } catch (_) {}
  }

  Future<void> _refreshSide() async {
    final hadTemp = _temp != null;
    await Future.wait([
      _quietly(() async => _temp = await AuthedCall.run(_api.fetchFamilyTemperature)),
      _quietly(() async => _streak = await PendingApi.instance.fetchStreak()),
      _quietly(() async => _unread = (await PendingApi.instance.fetchNotifications()).unreadCount > 0),
      _ensureStatus(_week),
    ]);
    if (!mounted) return;
    setState(() {});
    if (!hadTemp && _temp != null && _visible) _runTemp();
  }

  Future<void> _ensureStatus(List<DateTime> days) async {
    final months = {for (final d in days) (d.year, d.month)}..removeWhere(_statusMonths.contains);
    for (final (y, m) in months) {
      try {
        for (final s in await PendingApi.instance.fetchAnswerStatus(year: y, month: m)) {
          _status[s.date] = s.answeredUserIds;
        }
        _statusMonths.add((y, m));
      } catch (_) {}
    }
  }

  Future<void> _loadAnswers() async {
    final id = _question.dailyQuestionId;
    if (id == null) {
      if (mounted) setState(() => _answers = DayAnswers.empty);
      return;
    }
    final target = _cur;
    try {
      final a = await DayAnswers.load(id);
      if (!mounted || target != _cur) return;
      setState(() {
        _answers = a;
        // Keep the week-strip dot in sync with what we just loaded.
        _status[target] = {...?_status[target], ...a.answeredIds};
      });
    } catch (_) {
      if (mounted && target == _cur) setState(() => _answers = DayAnswers.empty);
    }
  }

  // ── animations ────────────────────────────────────────────────────────

  void _stopTyping() {
    _typeDelay?.cancel();
    _typeTick?.cancel();
  }

  void _restartTypingIfVisible() {
    if (_visible) _startTyping();
  }

  void _startTyping() {
    _stopTyping();
    final text = _letterText;
    if (text.isEmpty) {
      setState(() => _typed = null);
      return;
    }
    setState(() => _typed = 0);
    _typeDelay = Timer(const Duration(milliseconds: 380), () {
      _typeTick = Timer.periodic(const Duration(milliseconds: 55), (t) {
        if (!mounted) return t.cancel();
        final total = _letterText.characters.length;
        setState(() => _typed = math.min(total, (_typed ?? 0) + 1));
        if ((_typed ?? 0) >= total) t.cancel();
      });
    });
  }

  /// The prototype's `qTyped`: the typed prefix, padded with up to three
  /// no-break spaces so the line doesn't jump while typing.
  String get _shownQuestion {
    final chars = _letterText.characters;
    final n = _typed;
    if (n == null || n >= chars.length) return _letterText;
    return chars.take(n).toString() + ' ' * math.max(0, math.min(3, chars.length - n));
  }

  void _runTemp() {
    final temp = _temp;
    if (temp == null) return;
    final target = temp.temperature;
    final seen = _lastSeenTemp;
    final rose = seen != null && seen < target - 0.01;
    _tempFrom = rose ? seen : target - 1.4;
    _lastSeenTemp = target;
    _tempDelay?.cancel();
    _tempC.value = 0;
    setState(() => _tempFloat = rose);
    if (rose) {
      _floatTimer?.cancel();
      _floatTimer = Timer(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _tempFloat = false);
      });
    }
    _tempDelay = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _tempC.forward(from: 0);
    });
  }

  double get _tempShown {
    final temp = _temp;
    if (temp == null) return 0;
    final e = Curves.easeOutCubic.transform(_tempC.value);
    return _tempFrom + (temp.temperature - _tempFrom) * e;
  }

  // ── navigation ────────────────────────────────────────────────────────

  Future<void> _changeTo(DateTime day) async {
    final d = dateOnly(day);
    if (d == _cur || d.isAfter(_today) || _changing) return;
    _changing = true;
    final dir = d.isAfter(_cur) ? 1.0 : -1.0;
    setState(() {
      _cardAnimate = true;
      _cardShift = -dir * 36;
      _cardHidden = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (!mounted) return;
    setState(() {
      _cur = d;
      _answers = null;
      _cardAnimate = false;
      _cardShift = dir * 36;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _cardAnimate = true;
      _cardShift = 0;
      _cardHidden = false;
    });
    _changing = false;
    _restartTypingIfVisible();
    try {
      await _ensureMonths(_week);
      await _ensureStatus(_week);
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    _restartTypingIfVisible();
    await _loadAnswers();
  }

  Future<void> _pickYearMonth() async {
    final picked = await showYearMonthSheet(context, year: _cur.year, month: _cur.month);
    if (picked == null) return;
    final (y, m) = picked;
    final isThisMonth = y == _today.year && m == _today.month;
    await _changeTo(isThisMonth ? _today : DateTime(y, m, 1));
  }

  /// Letter tap: a short "open" (scale .96 → lift & fade) and then 답장 쓰기
  /// for today's unanswered question, otherwise 가족 답장.
  Future<void> _openLetter() async {
    final q = _question;
    if (!q.isReady) {
      HaruToast.show(context, q.waitingMessage ?? '아직 도착한 질문이 없어요.');
      return;
    }
    if (_open != 0) return;
    setState(() => _open = 1);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;
    setState(() => _open = 2);
    await Future<void>.delayed(const Duration(milliseconds: 390));
    if (!mounted) return;
    final writeToday = q.isToday && _answers?.mine == null;
    final nav = Navigator.of(context);
    setState(() => _open = 0);
    if (writeToday) {
      await nav.push(MaterialPageRoute<void>(builder: (_) => WriteAnswerPage(question: q)));
    } else {
      await nav.push(MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: q)));
    }
    if (mounted) _loadAnswers();
  }

  Future<void> _openAnswers() async {
    final q = _question;
    if (!q.isReady) {
      HaruToast.show(context, q.waitingMessage ?? '아직 도착한 질문이 없어요.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: q)));
    if (mounted) _loadAnswers();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
    if (mounted) _refreshSide();
  }

  Future<void> _refresh() async {
    _loadedMonths.clear();
    _statusMonths.clear();
    try {
      await _ensureMonths(_week);
      if (mounted) setState(() => _error = false);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
    _restartTypingIfVisible();
    await Future.wait([_loadAnswers(), _refreshSide()]);
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fam = FamilyContext.instance.value;
    final me = fam?.me?.userId;
    return RefreshIndicator(
      color: HaruColors.forest,
      backgroundColor: HaruColors.ivory,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Entrance(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const SideBranches(),
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _Header(
                          bellDot: _unread,
                          streak: _streak?.current,
                          onBell: _openNotifications,
                          onStreak: () => showStreakSheet(context, streak: _streak),
                        ),
                        _MonthRow(
                          label: '${_cur.year}년 ${_cur.month}월',
                          showToday: _cur != _today,
                          onMonth: _pickYearMonth,
                          onToday: () => _changeTo(_today),
                        ),
                        _WeekStrip(
                          days: _week,
                          selected: _cur,
                          today: _today,
                          mineAnswered: (d) => me != null && (_status[d]?.contains(me) ?? false),
                          onTap: _changeTo,
                        ),
                        const SizedBox(height: 4),
                        Entrance(
                          kind: EntranceKind.riseIn,
                          delay: const Duration(milliseconds: 40),
                          child: _LetterSlot(
                            maxWidth: c.maxWidth,
                            shift: _cardShift,
                            hidden: _cardHidden,
                            animate: _cardAnimate,
                            open: _open,
                            onTap: _openLetter,
                            child: (w) => QuestionLetter(
                              familyName: fam?.name ?? '우리',
                              date: '${_cur.month}/${_cur.day}',
                              question: _shownQuestion,
                              isToday: sameDay(_cur, _today),
                              width: w,
                            ),
                          ),
                        ),
                        Entrance(
                          kind: EntranceKind.riseIn,
                          delay: const Duration(milliseconds: 100),
                          child: _MembersRow(
                            members: fam?.members ?? const [],
                            answered: _answers?.answeredIds ?? const {},
                            onTap: _openAnswers,
                          ),
                        ),
                        Entrance(
                          kind: EntranceKind.riseIn,
                          delay: const Duration(milliseconds: 160),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _tempC,
                                    builder: (_, _) => _TempCard(
                                      value: _temp == null ? null : _tempShown,
                                      float: _tempFloat,
                                      rise: _temp == null ? null : _temp!.temperature - _tempFrom,
                                      onTap: () => _shell?.switchTo(HaruTab.family),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StreakCard(
                                    streak: _streak,
                                    onTap: () => showStreakSheet(context, streak: _streak),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const GrassStrip(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.bellDot, required this.streak, required this.onBell, required this.onStreak});

  final bool bellDot;
  final int? streak;
  final VoidCallback onBell;
  final VoidCallback onStreak;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text('하루한번', style: hr(27, color: HaruColors.forest, height: 1)),
                  // left: 100%, translate(4px, -55%)
                  Positioned(right: -22, top: 27 / 2 - 18 * .55, child: const SproutIcon(size: 18)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Pressable(
                  onTap: onBell,
                  semanticLabel: '알림',
                  child: SizedBox(
                    width: 84,
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Symbols.notifications_rounded, size: 27, color: HaruColors.forest),
                            if (bellDot)
                              Positioned(
                                top: 9,
                                right: 9,
                                // 9×9 + 2px border (content-box)
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: HaruColors.badge,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: HaruColors.cream, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: streak == null
                        ? const SizedBox.shrink()
                        : Pressable(
                            onTap: onStreak,
                            semanticLabel: '연속 답변 $streak일',
                            child: Container(
                              // 32 + 1px border (content-box)
                              height: 34,
                              padding: const EdgeInsets.fromLTRB(7, 0, 10, 0),
                              decoration: BoxDecoration(
                                color: HaruColors.ivory,
                                border: Border.all(color: HaruColors.hairline),
                                borderRadius: BorderRadius.circular(HaruRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _Flicker(child: Image.asset(HaruImages.greenHeart, width: 17, height: 17)),
                                  const SizedBox(width: 3),
                                  Text('$streak일', style: hr(15, color: HaruColors.forest)),
                                ],
                              ),
                            ),
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
}

/// hrFlicker 1.6s: scale(1.08) rotate(-4deg) at 50%, from 800ms.
class _Flicker extends StatefulWidget {
  const _Flicker({required this.child});

  final Widget child;

  @override
  State<_Flicker> createState() => _FlickerState();
}

class _FlickerState extends State<_Flicker> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final v = _c.value;
        final k = Curves.easeInOut.transform(v < .5 ? v * 2 : (1 - v) * 2);
        return Transform.rotate(
          angle: -4 * math.pi / 180 * k,
          child: Transform.scale(scale: 1 + .08 * k, child: child),
        );
      },
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.label, required this.showToday, required this.onMonth, required this.onToday});

  final String label;
  final bool showToday;
  final VoidCallback onMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
        child: Row(
          children: [
            Pressable(
              onTap: onMonth,
              semanticLabel: '연도와 월 고르기',
              child: Row(
                children: [
                  Text(label, style: hr(17, color: HaruColors.forest)),
                  const SizedBox(width: 2),
                  const Icon(Symbols.expand_more_rounded, size: 20, color: HaruColors.forest),
                ],
              ),
            ),
            const Spacer(),
            if (showToday)
              Entrance(
                kind: EntranceKind.popIn,
                duration: const Duration(milliseconds: 240),
                child: Pressable(
                  onTap: onToday,
                  duration: Duration.zero,
                  inlineTransition: false,
                  child: Container(
                    // 28 + 1px border (content-box)
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: HaruColors.ivory,
                      border: Border.all(color: HaruColors.fieldBorder),
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                    ),
                    alignment: Alignment.center,
                    child: Text('오늘로', style: hr(14.5, color: HaruColors.forest)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.today,
    required this.mineAnswered,
    required this.onTap,
  });

  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime) mineAnswered;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [for (final d in days) Expanded(child: _dayCell(d))]),
    );
  }

  Widget _dayCell(DateTime d) {
    final sel = d == selected;
    final future = d.isAfter(today);
    final isToday = d == today;
    final cell = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Text(dowOf(d), style: hr(14, color: HaruColors.inkMuted)),
          const SizedBox(height: 3),
          AnimatedScale(
            scale: sel ? 1.06 : 1,
            duration: const Duration(milliseconds: 300),
            curve: HaruMotion.pop,
            child: AnimatedContainer(
              // background 220ms ease, color 220ms ease
              duration: const Duration(milliseconds: 220),
              curve: Curves.ease,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sel ? HaruColors.forest : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isToday && !sel ? HaruColors.softGreen : Colors.transparent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.ease,
                style: hrHand(
                  19,
                  color: sel
                      ? Colors.white
                      : future
                      ? HaruColors.inkFaint
                      : HaruColors.ink,
                ),
                child: Text('${d.day}'),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: mineAnswered(d) ? HaruColors.softGreen : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
    if (future) return cell;
    return Pressable(
      scale: .92,
      duration: Duration.zero,
      inlineTransition: false,
      onTap: () => onTap(d),
      semanticLabel: '${d.month}월 ${d.day}일',
      child: cell,
    );
  }
}

/// The 388×484 letter slot with the prototype's −22 / −30 margins, the day
/// change slide and the tap-to-open animation.
class _LetterSlot extends StatefulWidget {
  const _LetterSlot({
    required this.maxWidth,
    required this.shift,
    required this.hidden,
    required this.animate,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final double maxWidth;
  final double shift;
  final bool hidden;
  final bool animate;
  final int open;
  final VoidCallback onTap;
  final Widget Function(double width) child;

  @override
  State<_LetterSlot> createState() => _LetterSlotState();
}

class _LetterSlotState extends State<_LetterSlot> {
  // style-active: transform scale(.96), filter brightness(.96).
  bool _down = false;

  void _press(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // 388 on a 402-wide screen; narrower phones scale it down.
    final w = math.min(388.0, widget.maxWidth * 388 / 402);
    final h = QuestionLetter.heightFor(w);
    final scale = w / 388;
    final open = widget.open;
    // transition: transform 170ms ease, opacity 170ms ease
    final slide = widget.animate ? const Duration(milliseconds: 170) : Duration.zero;
    return SizedBox(
      height: h - (22 + 30) * scale,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: h,
        child: Transform.translate(
          offset: Offset(0, -22 * scale),
          child: AnimatedSlide(
            duration: slide,
            curve: Curves.ease,
            offset: Offset(widget.shift / w, 0),
            child: AnimatedOpacity(
              duration: slide,
              curve: Curves.ease,
              opacity: widget.hidden ? 0 : 1,
              child: GestureDetector(
                onTap: widget.onTap,
                onTapDown: (_) => _press(true),
                onTapUp: (_) => _press(false),
                onTapCancel: () => _press(false),
                child: Semantics(
                  button: true,
                  label: '오늘의 질문 편지',
                  child: AnimatedOpacity(
                    // opacity 300ms ease, 120ms delay
                    duration: const Duration(milliseconds: 420),
                    curve: const Interval(120 / 420, 1, curve: Curves.ease),
                    opacity: open == 2 ? 0 : 1,
                    // The frame's `cursor: pointer` `:active { scale: .95 }`;
                    // `scale` isn't in the inline transition, so it snaps.
                    child: Transform.scale(
                      scale: _down ? .95 : 1,
                      child: AnimatedContainer(
                        // transform 380ms cubic-bezier(.33,1,.68,1)
                        duration: const Duration(milliseconds: 380),
                        curve: HaruMotion.out,
                        transformAlignment: Alignment.center,
                        transform: _down
                            ? Matrix4.diagonal3Values(.96, .96, 1)
                            : switch (open) {
                                1 => Matrix4.diagonal3Values(.96, .96, 1),
                                2 => Matrix4.translationValues(
                                  0,
                                  -14,
                                  0,
                                ).multiplied(Matrix4.diagonal3Values(1.12, 1.12, 1)),
                                _ => Matrix4.identity(),
                              },
                        // filter 300ms ease
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: _down ? .96 : 1),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (open != 0) Positioned.fill(child: _LetterGlow(child: widget.child(w))),
                              widget.child(w),
                            ],
                          ),
                          builder: (_, b, child) => b >= 1
                              ? child!
                              : ColorFiltered(
                                  colorFilter: ColorFilter.matrix([
                                    b, 0, 0, 0, 0, //
                                    0, b, 0, 0, 0, //
                                    0, 0, b, 0, 0, //
                                    0, 0, 0, 1, 0, //
                                  ]),
                                  child: child,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `filter: drop-shadow(0 10px 18px rgba(58,106,63,.25))` while the letter
/// opens, faded in over 300ms ease. The shadow follows the letter's shape.
class _LetterGlow extends StatelessWidget {
  const _LetterGlow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        child: Transform.translate(
          offset: const Offset(0, 10),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x403A6A3F), BlendMode.srcIn), child: child),
          ),
        ),
        builder: (_, t, c) => Opacity(opacity: t, child: c),
      ),
    );
  }
}

class _MembersRow extends StatelessWidget {
  const _MembersRow({required this.members, required this.answered, required this.onTap});

  final List<MemberLook> members;
  final Set<int> answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = members.where((m) => answered.contains(m.userId)).length;
    final wait = members.length - done;
    final all = members.isNotEmpty && wait == 0;
    // No style-active or transition of its own: only the frame's
    // `:active { scale: .95 }` (140ms cubic-bezier(.2,0,0,1)).
    return Pressable(
      onTap: onTap,
      scale: 1,
      duration: Duration.zero,
      inlineTransition: false,
      semanticLabel: '가족 답장 보기',
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
        child: Row(
          children: [
            // padding-left 6 + margin-left −6 per avatar → 28px steps.
            SizedBox(
              width: members.isEmpty ? 0 : 34 + (members.length - 1) * 28,
              height: 34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < members.length; i++)
                    Positioned(
                      left: i * 28.0,
                      top: 0,
                      child: Entrance(
                        kind: EntranceKind.pop,
                        delay: stagger(i, 70, 200),
                        duration: const Duration(milliseconds: 420),
                        child: _AnsweredAvatar(member: members[i], done: answered.contains(members[i].userId)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$done',
                          style: hr(19, color: HaruColors.cta),
                        ),
                        const TextSpan(text: '명이 답장했어요'),
                      ],
                    ),
                    style: hr(16, height: 1.2),
                  ),
                  if (!all)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text('$wait명을 기다리는 중', style: hr(13.5, color: HaruColors.inkMuted)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text('온 가족이 답했어요 ♥', style: hr(13.5, color: HaruColors.cta)),
                    ),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right_rounded, size: 22, color: HaruColors.forest),
          ],
        ),
      ),
    );
  }
}

class _AnsweredAvatar extends StatelessWidget {
  const _AnsweredAvatar({required this.member, required this.done});

  final MemberLook member;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 1 : .45,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: member.tint,
                shape: BoxShape.circle,
                border: Border.all(color: done ? HaruColors.cta : HaruColors.lineGrey, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(member.short, maxLines: 1, style: hr(13.5, color: HaruColors.forest)),
            ),
            if (done)
              // right −4 / bottom −3 from the padding box (inside the 2px ring)
              Positioned(
                right: -2,
                bottom: -1,
                // 15×15 + 1.5px border (content-box)
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: HaruColors.cta,
                    shape: BoxShape.circle,
                    border: Border.all(color: HaruColors.ivory, width: 1.5),
                  ),
                  child: const Icon(Symbols.check_rounded, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small 84-tall card shell (가족 온도 / 연속 답변).
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.onTap, required this.children});

  final String title;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          border: Border.all(color: HaruColors.hairline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: hr(14, color: HaruColors.inkMuted)),
                ),
                const Icon(Symbols.chevron_right_rounded, size: 15, color: HaruColors.inkFaint),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TempCard extends StatelessWidget {
  const _TempCard({required this.value, required this.float, required this.onTap, this.rise});

  final double? value;
  final bool float;

  /// How much it rose since last seen (the floating "+0.3°C ♥").
  final double? rise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final bar = v == null ? 0.0 : ((v - 30) / 15).clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _MiniCard(
          title: '가족 온도',
          onTap: onTap,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  v == null ? '–' : '${v.toStringAsFixed(1)}°',
                  style: hrHand(27, color: HaruColors.tempText, weight: FontWeight.w800, height: 1),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(HaruRadius.full),
              child: Container(
                height: 5,
                color: HaruColors.gaugeTrack,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: bar,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                      gradient: const LinearGradient(colors: [Color(0xFFB8E07A), Color(0xFFE8E05A), Color(0xFFF5C04A)]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (float && rise != null)
          // top −10 / right 6 from the padding box (inside the 1px border)
          Positioned(top: -9, right: 7, child: _RiseChip(rise: rise!)),
      ],
    );
  }
}

/// "+°C ♥" chip that floats up when the temperature rose since last seen.
class _RiseChip extends StatelessWidget {
  const _RiseChip({required this.rise});

  final double rise;

  @override
  Widget build(BuildContext context) {
    // hrRise 1.8s cubic-bezier(.33,1,.68,1); the curve runs per keyframe
    // segment (opacity 0→1 by 18%, then →0; translateY 6 → −34 throughout).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1800),
      builder: (_, t, c) {
        const e = HaruMotion.out;
        final op = t < .18 ? e.transform(t / .18) : 1 - e.transform((t - .18) / .82);
        return Opacity(
          opacity: op.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, 6 - 40 * e.transform(t)), child: c),
        );
      },
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: HaruColors.tempRise, borderRadius: BorderRadius.circular(HaruRadius.full)),
        alignment: Alignment.center,
        child: Text('+${rise.toStringAsFixed(1)}°C ♥', style: hr(13.5, color: Colors.white)),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.onTap});

  final StreakSummary? streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = streak;
    return _MiniCard(
      title: '연속 답변',
      onTap: onTap,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(s == null ? '–' : '${s.current}', style: hrHand(27, weight: FontWeight.w800, height: 1)),
              const SizedBox(width: 3),
              Text('일째', style: hr(14, color: HaruColors.forest)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              Entrance(
                kind: EntranceKind.stamp,
                delay: stagger(i, 60, 300),
                targetOpacity: s != null && i < s.week.length && s.week[i].answered ? 1 : .28,
                child: Image.asset(HaruImages.greenHeart, width: 11, height: 11),
              ),
          ],
        ),
      ],
    );
  }
}
