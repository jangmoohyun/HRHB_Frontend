import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../answers/day_answers.dart';
import '../answers/family_answers_page.dart';
import '../answers/question_ref.dart';
import '../answers/write_answer_page.dart';
import '../family/temperature_screen.dart';
import '../shell/home_shell.dart';
import 'home_sheets.dart';
import 'notifications_screen.dart';

/// 14 홈 (오늘의 질문).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
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
  bool _loading = true;
  bool _error = false;
  HomeShellState? _shell;

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
      _shell = shell;
      _shell?.refreshTick.addListener(_onDataChanged);
    }
  }

  @override
  void dispose() {
    _shell?.refreshTick.removeListener(_onDataChanged);
    super.dispose();
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

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await FamilyContext.instance.ensure();
      await _ensureMonths(_week);
      await Future.wait([_loadAnswers(), _refreshSide()]);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Loads question months covering [days] (a week can span two months).
  Future<void> _ensureMonths(List<DateTime> days) async {
    final months = {for (final d in days) (d.year, d.month)}
      ..removeWhere(_loadedMonths.contains);
    for (final (y, m) in months) {
      final res = await AuthedCall.run(
        (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m),
      );
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
    await Future.wait([
      _quietly(() async => _temp = await AuthedCall.run(_api.fetchFamilyTemperature)),
      _quietly(() async => _streak = await PendingApi.instance.fetchStreak()),
      _quietly(() async =>
          _unread = (await PendingApi.instance.fetchNotifications()).unreadCount > 0),
      _ensureStatus(_week),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _ensureStatus(List<DateTime> days) async {
    final months = {for (final d in days) (d.year, d.month)}
      ..removeWhere(_statusMonths.contains);
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
      setState(() => _answers = a);
      // Keep the week-strip dot in sync with what we just loaded.
      final me = FamilyContext.instance.value?.me?.userId;
      if (me != null) {
        _status[target] = {...?_status[target], ...a.answeredIds};
      }
    } catch (_) {
      if (mounted && target == _cur) setState(() => _answers = DayAnswers.empty);
    }
  }

  Future<void> _select(DateTime day) async {
    setState(() {
      _cur = dateOnly(day);
      _answers = null;
    });
    try {
      await _ensureMonths(_week);
      await _ensureStatus(_week);
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    await _loadAnswers();
  }

  Future<void> _pickYearMonth() async {
    final picked = await showYearMonthSheet(context, year: _cur.year, month: _cur.month);
    if (picked == null) return;
    final (y, m) = picked;
    final isThisMonth = y == _today.year && m == _today.month;
    await _select(isThisMonth ? _today : DateTime(y, m, 1));
  }

  Future<void> _openWrite() async {
    final q = _question;
    if (!q.isReady) return;
    final mine = _answers?.mine;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteAnswerPage(
          question: q,
          initialContent: mine?.raw.content,
          initialImageUrl: mine?.raw.imageUrl,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await Future.wait([_loadAnswers(), _refreshSide()]);
    if (!mounted) return;
    await afterAnswerSaved(context, firstAnswer: mine == null, isToday: q.isToday);
    if (mounted) _refreshSide();
  }

  Future<void> _openAnswers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: _question)),
    );
    if (mounted) _loadAnswers();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) _refreshSide();
  }

  void _openTemperature() {
    HomeShellScope.of(context).pushOn(HaruTab.family, const TemperatureScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HaruColors.primary,
          onRefresh: () async {
            _loadedMonths.clear();
            _statusMonths.clear();
            await _ensureMonths(_week);
            await Future.wait([_loadAnswers(), _refreshSide()]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kTabBarClearance),
            children: [
              _header(),
              _monthRow(),
              _weekStrip(),
              if (_loading)
                const Padding(padding: EdgeInsets.only(top: 8), child: HaruSkeleton())
              else if (_error)
                HaruErrorState(onRetry: _loadAll)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      HaruRise(
                        delay: const Duration(milliseconds: 40),
                        child: _QuestionHero(
                          question: _question,
                          answers: _answers,
                          onWrite: _openWrite,
                          onBrowse: _openAnswers,
                        ),
                      ),
                      const SizedBox(height: 12),
                      HaruRise(
                        delay: const Duration(milliseconds: 160),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _TempMiniCard(temp: _temp, onTap: _openTemperature)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StreakMiniCard(
                                streak: _streak,
                                onTap: () => showStreakSheet(context, streak: _streak),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_question.isReady)
                        HaruRise(
                          delay: const Duration(milliseconds: 220),
                          child: _FirstAnswerCard(answers: _answers, onTap: _openAnswers),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
        child: Row(
          children: [
            Expanded(child: Text('하루한번', style: haruLogo(26).copyWith(height: 1))),
            if (_streak != null)
              Pressable(
                onTap: () => showStreakSheet(context, streak: _streak),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                    boxShadow: HaruShadows.s1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.flame, size: 16, color: HaruColors.streak),
                      const SizedBox(width: 4),
                      Text('${_streak!.current}일째', style: haruText(14, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Pressable(
              onTap: _openNotifications,
              semanticLabel: '알림',
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(LucideIcons.bell, size: 22, color: HaruColors.ink),
                    if (_unread)
                      Positioned(
                        top: 7,
                        right: 8,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: HaruColors.streak,
                            shape: BoxShape.circle,
                            border: Border.all(color: HaruColors.canvas, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthRow() {
    final notToday = !sameDay(_cur, _today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Pressable(
              onTap: _pickYearMonth,
              child: Row(
                children: [
                  Text(
                    '${_cur.year}년 ${_cur.month}월',
                    style: haruText(15, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronDown, size: 16, color: HaruColors.ink),
                ],
              ),
            ),
            const Spacer(),
            if (notToday)
              Pressable(
                onTap: () => _select(_today),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: HaruColors.inkLine),
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                  ),
                  child: Text('오늘로', style: haruText(13, weight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekStrip() {
    final me = FamilyContext.instance.value?.me?.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final d in _week)
            Expanded(
              child: _WeekDay(
                date: d,
                selected: sameDay(d, _cur),
                isToday: sameDay(d, _today),
                future: d.isAfter(_today),
                mine: me != null && (_status[d]?.contains(me) ?? false),
                onTap: () => _select(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.future,
    required this.mine,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool future;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : future
            ? HaruColors.inkDisabled
            : HaruColors.ink;
    const d = Duration(milliseconds: 220);
    return Pressable(
      onTap: future ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(dowOf(date), style: haruText(12, color: HaruColors.inkSecondary, height: 1.3)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: d,
              curve: Curves.ease,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? HaruColors.ink : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(color: HaruColors.house, width: 1.5)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: haruText(16, weight: FontWeight.w600, color: fg, height: 1.2),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: mine ? HaruColors.house : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionHero extends StatelessWidget {
  const _QuestionHero({
    required this.question,
    required this.answers,
    required this.onWrite,
    required this.onBrowse,
  });

  final QuestionRef question;
  final DayAnswers? answers;
  final VoidCallback onWrite;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final fam = FamilyContext.instance.value;
    final members = fam?.members ?? const <MemberLook>[];
    final answered = answers?.answeredIds ?? const <int>{};
    final mine = answers?.mine != null;
    final badge = q.isToday ? '오늘의 질문' : '지난 질문';
    final number = q.sequenceNumber == null ? '' : '#${q.sequenceNumber} ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: HaruColors.house,
        borderRadius: BorderRadius.circular(HaruRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$number$badge',
                  style: haruText(13, color: Colors.white.withValues(alpha: 0.72)),
                ),
              ),
              if ((q.category ?? '').isNotEmpty)
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                  ),
                  child: Text(
                    q.category!,
                    style: haruText(12, weight: FontWeight.w600, color: Colors.white, height: 1.2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q.isReady ? q.content : q.waitingMessage!,
            style: haruQuestion(23, height: 1.42),
          ),
          const SizedBox(height: 18),
          if (q.isReady) ...[
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: HaruAvatarStack(
                    overlap: 6,
                    itemSize: 40,
                    children: [
                      for (final m in members)
                        HaruAvatar(
                          initial: m.initial,
                          tint: m.tint,
                          size: 36,
                          answered: answered.contains(m.userId),
                          ringColor: HaruColors.house,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${answered.length}/${members.length}명 답했어요',
                  style: haruText(14, color: Colors.white.withValues(alpha: 0.70)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!mine)
              Row(
                children: [
                  Expanded(
                    child: _HeroButton(
                      label: '답변 남기기',
                      filled: true,
                      onTap: answers == null ? null : onWrite,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: _HeroButton(label: '둘러보기', filled: false, onTap: onBrowse),
                  ),
                ],
              )
            else
              _HeroButton(label: '가족 답변 보기', filled: false, onTap: onBrowse),
          ],
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.label, required this.filled, this.onTap});

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(HaruRadius.full),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Text(
          label,
          style: haruText(
            16,
            weight: FontWeight.w600,
            color: filled ? HaruColors.logo : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// White mini card with a "제목 ›" header (가족 온도 / 연속 답변).
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.onTap, required this.children});

  final String title;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HaruRadius.xl),
          boxShadow: HaruShadows.s1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: haruText(13, weight: FontWeight.w600, color: HaruColors.inkSecondary),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: HaruColors.inkSecondary),
              ],
            ),
            for (final c in children) ...[const SizedBox(height: 10), c],
          ],
        ),
      ),
    );
  }
}

class _TempMiniCard extends StatelessWidget {
  const _TempMiniCard({required this.temp, required this.onTap});

  final FamilyTemperatureResult? temp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = temp;
    final d = t?.deltaFromYesterday ?? 0;
    final deltaText = '${d > 0 ? '+' : d < 0 ? '−' : '±'}${d.abs().toStringAsFixed(1)}°';
    final deltaColor = d > 0
        ? HaruColors.tempRiseText
        : d < 0
            ? HaruColors.tempDropText
            : HaruColors.inkQuiet;
    return _MiniCard(
      title: '가족 온도',
      onTap: onTap,
      children: [
        Center(
          child: HalfGauge(
            percent: t?.temperature ?? 0,
            color: HaruColors.tempRise,
            label: t == null ? '–' : '${t.temperature.toStringAsFixed(1)}°',
          ),
        ),
        Text.rich(
          TextSpan(
            text: '어제보다 ',
            style: haruText(13, color: HaruColors.inkSecondary),
            children: [
              TextSpan(
                text: t == null ? '–' : deltaText,
                style: haruText(13, weight: FontWeight.w700, color: deltaColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakMiniCard extends StatelessWidget {
  const _StreakMiniCard({required this.streak, required this.onTap});

  final StreakSummary? streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = streak;
    return _MiniCard(
      title: '연속 답변',
      onTap: onTap,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const Icon(LucideIcons.flame, size: 26, color: HaruColors.streak),
              const SizedBox(width: 6),
              Text(
                s == null ? '–' : '${s.current}',
                style: haruText(34, weight: FontWeight.w800, letterSpacing: -1, height: 1.1),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('일째', style: haruText(14, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (s != null) StreakWeekDots(streak: s),
      ],
    );
  }
}

class _FirstAnswerCard extends StatelessWidget {
  const _FirstAnswerCard({required this.answers, required this.onTap});

  final DayAnswers? answers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final others = answers?.othersByArrival ?? const <AnswerView>[];
    final first = others.isEmpty ? null : others.first;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HaruRadius.xl),
          boxShadow: HaruShadows.s1,
        ),
        child: Row(
          children: [
            if (first != null) ...[
              HaruAvatar(initial: first.member.initial, tint: first.member.tint, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('먼저 도착한 답변', style: haruText(12, color: HaruColors.inkSecondary)),
                        const SizedBox(width: 6),
                        Text(first.member.label, style: haruHand(17)),
                        if (others.length > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '외 ${others.length - 1}명',
                            style: haruText(12, color: HaruColors.inkSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      first.raw.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: haruText(15, height: 1.4),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HaruColors.ceramic,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.mailOpen, size: 20, color: HaruColors.inkSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  answers == null
                      ? '답변을 불러오고 있어요'
                      : '아직 도착한 답변이 없어요. 가장 먼저 남겨 보세요.',
                  style: haruText(14, height: 1.45, color: HaruColors.inkSecondary),
                ),
              ),
            ],
            const SizedBox(width: 12),
            const Icon(LucideIcons.chevronRight, size: 20, color: HaruColors.inkSecondary),
          ],
        ),
      ),
    );
  }
}
