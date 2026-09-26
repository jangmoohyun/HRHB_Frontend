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
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../answers/question_ref.dart';
import '../answers/write_answer_page.dart';
import '../home/home_sheets.dart';
import '../shell/home_shell.dart';
import 'answer_photos_screen.dart';
import 'day_detail_screen.dart';

enum _ArchiveTab { list, photos, report }

/// 기록 — 날짜별 / 사진 / 리포트.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  _ArchiveTab _tab = _ArchiveTab.list;
  bool? _todayMine;
  QuestionRef? _todayQuestion;
  HomeShellState? _shell;
  final _listKey = GlobalKey<_DateListState>();

  @override
  void initState() {
    super.initState();
    _checkToday();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = HomeShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.refreshTick.removeListener(_checkToday);
      _shell = shell;
      _shell?.refreshTick.addListener(_checkToday);
    }
  }

  @override
  void dispose() {
    _shell?.refreshTick.removeListener(_checkToday);
    super.dispose();
  }

  /// Drives the floating "오늘의 답변 남기기" button.
  Future<void> _checkToday() async {
    try {
      final api = ApiClient();
      final today = QuestionRef.fromResult(await AuthedCall.run(api.fetchTodayDailyQuestion));
      var mine = true;
      if (today.isReady) {
        final list = await AuthedCall.run(
          (t) => api.fetchDailyAnswers(accessToken: t, dailyQuestionId: today.dailyQuestionId!),
        );
        mine = list.answers.any((a) => a.isMe);
      }
      if (mounted) {
        setState(() {
          _todayQuestion = today;
          _todayMine = mine;
        });
      }
    } catch (_) {}
  }

  Future<void> _writeToday() async {
    final q = _todayQuestion;
    if (q == null || !q.isReady) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WriteAnswerPage(question: q)),
    );
    if (saved != true || !mounted) return;
    await _checkToday();
    _listKey.currentState?.reload();
    if (!mounted) return;
    await afterAnswerSaved(context, firstAnswer: true, isToday: true);
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _todayMine == false && (_todayQuestion?.isReady ?? false);
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('기록', style: HaruType.screenTitle),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: PillSegment<_ArchiveTab>(
                    items: const [
                      (_ArchiveTab.list, '날짜별'),
                      (_ArchiveTab.photos, '사진'),
                      (_ArchiveTab.report, '리포트'),
                    ],
                    selected: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab.index,
                    children: [
                      _DateList(key: _listKey),
                      const _PhotosPane(),
                      const _ReportPane(),
                    ],
                  ),
                ),
              ],
            ),
            if (showFab)
              Positioned(
                right: 16,
                bottom: 100,
                child: _PopFab(onTap: _writeToday),
              ),
          ],
        ),
      ),
    );
  }
}

class _PopFab extends StatelessWidget {
  const _PopFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: const Interval(0.44, 1, curve: HaruMotion.pop),
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: c),
      ),
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          decoration: BoxDecoration(
            color: HaruColors.ink,
            borderRadius: BorderRadius.circular(HaruRadius.full),
            boxShadow: HaruShadows.fab,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.pencilLine, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('오늘의 답변 남기기', style: haruText(16, weight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 날짜별
// ─────────────────────────────────────────────────────────────────────────────

class _DateRow {
  const _DateRow({
    required this.date,
    required this.question,
    required this.answered,
    required this.weather,
    required this.delta,
  });

  final DateTime date;
  final String question;
  final Set<int> answered;
  final HaruWeather? weather;
  final double? delta;
}

class _DateList extends StatefulWidget {
  const _DateList({super.key});

  @override
  State<_DateList> createState() => _DateListState();
}

class _DateListState extends State<_DateList> {
  final _api = ApiClient();
  final _today = dateOnly(DateTime.now());
  late int _y = _today.year;
  late int _m = _today.month;
  List<_DateRow>? _rows;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _error = false;
      _rows = null;
    });
    try {
      await FamilyContext.instance.ensure();
      final y = _y, m = _m;
      final questionsF = AuthedCall.run(
        (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m),
      );
      final statusF = PendingApi.instance
          .fetchAnswerStatus(year: y, month: m)
          .catchError((_) => <AnswerStatusDay>[]);
      final calendarF = AuthedCall.run(
        (t) => _api.fetchDiaryCalendar(accessToken: t, year: y, month: m),
      ).then<DiaryCalendarResult?>((v) => v).catchError((_) => null);
      final tempF = AuthedCall.run(_api.fetchFamilyTemperature)
          .then<FamilyTemperatureResult?>((v) => v)
          .catchError((_) => null);

      final questions = await questionsF;
      final status = {for (final s in await statusF) s.date: s.answeredUserIds};
      final calendar = await calendarF;
      final temp = await tempF;
      final weather = {
        for (final d in calendar?.days ?? const <DiaryCalendarDayResult>[])
          dateOnly(d.date): HaruWeather.fromWire(d.familyWeather),
      };
      final deltas = {
        for (final c in temp?.recentChanges ?? const <FamilyTemperatureChangeResult>[])
          dateOnly(c.date): c.delta,
      };
      final rows = <_DateRow>[
        for (final q in questions.items)
          if (q.isReady && !dateOnly(q.date).isAfter(_today))
            _DateRow(
              date: dateOnly(q.date),
              question: q.content ?? '',
              answered: status[dateOnly(q.date)] ?? const {},
              weather: weather[dateOnly(q.date)],
              delta: deltas[dateOnly(q.date)],
            ),
      ]..sort((a, b) => b.date.compareTo(a.date));
      if (mounted && y == _y && m == _m) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showYearMonthSheet(context, year: _y, month: _m);
    if (picked == null) return;
    final (y, m) = picked;
    setState(() {
      _y = y;
      _m = m;
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final fam = FamilyContext.instance.value;
    final members = fam?.members ?? const <MemberLook>[];
    final rows = _rows;
    return RefreshIndicator(
      color: HaruColors.primary,
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, kTabBarClearance),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Pressable(
                    onTap: _pickMonth,
                    child: Row(
                      children: [
                        Text('$_y년 $_m월', style: haruText(15, weight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown, size: 16, color: HaruColors.ink),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('질문 · 일지 · 온도', style: haruText(12, color: HaruColors.inkSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_error)
            HaruErrorState(onRetry: reload)
          else if (rows == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: HaruColors.primary)),
            )
          else if (rows.isEmpty)
            const CeramicNote('이 달에는 도착한 질문이 없어요')
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(HaruRadius.xl),
                boxShadow: HaruShadows.s1,
              ),
              child: Column(
                children: [
                  for (var k = 0; k < rows.length; k++)
                    HaruRise(
                      delay: Duration(milliseconds: (k.clamp(0, 12)) * 30),
                      duration: const Duration(milliseconds: 400),
                      child: _row(rows[k], members, first: k == 0),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(_DateRow r, List<MemberLook> members, {required bool first}) {
    final d = r.delta;
    final deltaText = d == null ? '' : '${d > 0 ? '+' : d < 0 ? '−' : '±'}${d.abs().toStringAsFixed(1)}°';
    final deltaColor = d == null || d == 0
        ? HaruColors.inkQuiet
        : d > 0
            ? HaruColors.tempRiseText
            : HaruColors.tempDropText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DayDetailScreen(date: r.date)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: first ? Colors.transparent : HaruColors.hairline),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text('${r.date.day}', style: haruText(18, weight: FontWeight.w700, height: 1.3)),
                  Text(
                    sameDay(r.date, _today) ? '오늘' : dowOf(r.date),
                    style: haruText(11, color: HaruColors.inkSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: haruText(15, weight: FontWeight.w500, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final m in members) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r.answered.contains(m.userId) ? HaruColors.house : HaruColors.dotIdle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                        child: Text(
                          '${r.answered.length}/${members.length}',
                          style: haruText(12, color: HaruColors.inkSecondary, height: 1.2),
                        ),
                      ),
                      if (r.weather != null)
                        WeatherTile(
                          weather: r.weather,
                          size: 22,
                          radius: 6,
                          iconSize: 13,
                          iconColor: HaruColors.ink,
                        ),
                      if (deltaText.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          deltaText,
                          style: haruText(12, weight: FontWeight.w700, color: deltaColor, height: 1.2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Icon(LucideIcons.chevronRight, size: 18, color: HaruColors.inkChevron),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 사진
// ─────────────────────────────────────────────────────────────────────────────

class _PhotosPane extends StatefulWidget {
  const _PhotosPane();

  @override
  State<_PhotosPane> createState() => _PhotosPaneState();
}

class _PhotosPaneState extends State<_PhotosPane> {
  final _feed = AnswerPhotoFeed();
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await _feed.reset();
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _more() async {
    try {
      await _feed.more();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: HaruColors.primary));
    }
    if (_error) return HaruErrorState(onRetry: _load);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) _more();
        return false;
      },
      child: RefreshIndicator(
        color: HaruColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, kTabBarClearance),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '답변에 첨부된 사진 ${_feed.total}장',
                      style: haruText(14, color: HaruColors.inkSecondary),
                    ),
                  ),
                  Pressable(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AnswerPhotosScreen(startSelecting: true),
                      ),
                    ),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: HaruColors.inkLine),
                        borderRadius: BorderRadius.circular(HaruRadius.full),
                      ),
                      child: Text('선택', style: haruText(13, weight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_feed.items.isEmpty)
              const CeramicNote('아직 답변에 첨부된 사진이 없어요')
            else
              PhotoGrid(
                items: _feed.items,
                captions: true,
                captionStyleVer2: true,
                gap: 8,
                radius: 12,
                onTap: (i) => PhotoViewerPage.open(
                  context,
                  items: _feed.items,
                  index: i,
                  onSave: (item) => saveToDevice(context, [item.url]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 리포트
// ─────────────────────────────────────────────────────────────────────────────

enum _ReportMode { week, month }

class _ReportPane extends StatefulWidget {
  const _ReportPane();

  @override
  State<_ReportPane> createState() => _ReportPaneState();
}

class _ReportPaneState extends State<_ReportPane> {
  _ReportMode _mode = _ReportMode.week;
  WeeklyReport? _week;
  MonthlyReport? _month;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _monday {
    final t = dateOnly(DateTime.now());
    return t.subtract(Duration(days: t.weekday - 1));
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      await FamilyContext.instance.ensure();
      if (_mode == _ReportMode.week) {
        final r = await PendingApi.instance.fetchWeeklyReport(weekStart: _monday);
        if (mounted) setState(() => _week = r);
      } else {
        final now = DateTime.now();
        final r = await PendingApi.instance.fetchMonthlyReport(year: now.year, month: now.month);
        if (mounted) setState(() => _month = r);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _diffText(int rate, int? prev, String than) {
    if (prev == null) return '';
    final d = rate - prev;
    return '$than ${d.abs()}%p ${d >= 0 ? '올랐어요' : '내렸어요'}';
  }

  @override
  Widget build(BuildContext context) {
    final isWeek = _mode == _ReportMode.week;
    final now = DateTime.now();
    final end = _monday.add(const Duration(days: 6));
    final period = isWeek
        ? '${_monday.month}.${_monday.day} – ${end.month}.${end.day}'
        : '${now.year}년 ${now.month}월';
    final ready = isWeek ? _week != null : _month != null;

    return RefreshIndicator(
      color: HaruColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, kTabBarClearance),
        children: [
          Row(
            children: [
              SizedBox(
                width: 150,
                child: PillSegment<_ReportMode>(
                  items: const [(_ReportMode.week, '주간'), (_ReportMode.month, '월간')],
                  selected: _mode,
                  onChanged: (m) {
                    setState(() => _mode = m);
                    if ((m == _ReportMode.week ? _week : _month) == null) _load();
                  },
                ),
              ),
              const Spacer(),
              Text(period, style: haruText(14, weight: FontWeight.w600, color: HaruColors.inkSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_error)
            HaruErrorState(onRetry: _load)
          else if (!ready)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: HaruColors.primary)),
            )
          else
            ..._content(isWeek),
        ],
      ),
    );
  }

  List<Widget> _content(bool isWeek) {
    final fam = FamilyContext.instance.value;
    final rate = isWeek ? _week!.answerRate : _month!.answerRate;
    final prev = isWeek ? _week!.previousAnswerRate : _month!.previousAnswerRate;
    final monthNo = _month?.month ?? DateTime.now().month;
    final prevMonth = monthNo == 1 ? 12 : monthNo - 1;
    final temps = isWeek ? _week!.temperatureChanges : _month!.temperatureChanges;
    final sum = isWeek ? _week!.temperatureSum : _month!.temperatureSum;
    final highlights = isWeek ? _week!.highlights : _month!.highlights;

    return [
      _card(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isWeek ? '이번 주 답변율 $rate%' : '$monthNo월 답변율 $rate%',
            style: haruText(21, weight: FontWeight.w700, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text(
            _diffText(rate, prev, isWeek ? '지난주보다' : '$prevMonth월보다'),
            style: haruText(13, color: HaruColors.inkSecondary),
          ),
          const SizedBox(height: 16),
          if (isWeek)
            _WeekMatrix(report: _week!, family: fam)
          else
            _MonthHeatmap(report: _month!),
        ],
      ),
      const SizedBox(height: 12),
      _card(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  isWeek ? '이번 주 온도 변화' : '$monthNo월 온도 변화',
                  style: haruText(16, weight: FontWeight.w700),
                ),
              ),
              Text(
                '합계 ${sum >= 0 ? '+' : '−'}${sum.abs().toStringAsFixed(1)}°C',
                style: haruText(12, color: HaruColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TempBarChart(
            values: [for (final t in temps) t.delta],
            labels: [for (final t in temps) '${t.date.month}/${t.date.day}'],
          ),
        ],
      ),
      for (final h in highlights) ...[
        const SizedBox(height: 12),
        _card(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: switch (h.type) {
                      'FIRST_RESPONDER' => HaruColors.accentButter,
                      'LONGEST_ANSWER' => HaruColors.accentPink,
                      _ => HaruColors.accentTeal,
                    },
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    switch (h.type) {
                      'FIRST_RESPONDER' => LucideIcons.zap,
                      'LONGEST_ANSWER' => LucideIcons.messageCircleHeart,
                      _ => LucideIcons.star,
                    },
                    size: 20,
                    color: HaruColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.title, style: haruText(15, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        h.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: haruText(13, color: HaruColors.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ];
  }

  Widget _card({required EdgeInsets padding, required List<Widget> children}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HaruRadius.xl),
          boxShadow: HaruShadows.s1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _WeekMatrix extends StatelessWidget {
  const _WeekMatrix({required this.report, required this.family});

  final WeeklyReport report;
  final FamilySnapshot? family;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget label, List<Widget> cells) => Row(
          children: [
            SizedBox(width: 36, child: label),
            for (final c in cells) ...[
              const SizedBox(width: 6),
              Expanded(child: c),
            ],
          ],
        );
    return Column(
      children: [
        row(const SizedBox(), [
          for (final d in weekdayShort)
            Text(d, textAlign: TextAlign.center, style: haruText(11, color: HaruColors.inkSecondary)),
        ]),
        for (var ri = 0; ri < report.rows.length; ri++) ...[
          const SizedBox(height: 6),
          row(
            Text(
              family?.byUserId(report.rows[ri].userId)?.short ?? '',
              style: haruText(12, weight: FontWeight.w600, color: HaruColors.inkSecondary),
            ),
            [
              for (var ci = 0; ci < 7; ci++)
                _Pop(
                  delay: Duration(milliseconds: (ri + ci) * 40),
                  child: _cell(ci < report.rows[ri].days.length ? report.rows[ri].days[ci] : null),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(bool? answered) {
    if (answered == null) {
      return CustomPaint(
        painter: _DashedRRect(),
        child: const SizedBox(height: 28),
      );
    }
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: answered ? HaruColors.house : HaruColors.ceramic,
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HaruColors.handle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(7),
      ).deflate(0.5));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect oldDelegate) => false;
}

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(report.year, report.month, 1);
    final lead = first.weekday - 1; // Monday-first
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(height: 34),
      for (var i = 0; i < report.days.length; i++)
        _Pop(delay: Duration(milliseconds: i * 12), child: _day(report.days[i])),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  weekdayShort[i],
                  textAlign: TextAlign.center,
                  style: haruText(11, color: HaruColors.inkSecondary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 6 * 6) / 7;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final cell in cells) SizedBox(width: w, child: cell)],
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('적음', style: haruText(11, color: HaruColors.inkSecondary)),
            for (final c in HaruColors.heatmap) ...[
              const SizedBox(width: 4),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
              ),
            ],
            const SizedBox(width: 4),
            Text('많음', style: haruText(11, color: HaruColors.inkSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _day(ReportDayCount d) {
    final n = d.answeredCount;
    if (n == null) {
      return SizedBox(
        height: 34,
        child: Center(
          child: Text(
            '${d.date.day}',
            style: haruText(11, weight: FontWeight.w600, color: const Color(0x4D2B2016)),
          ),
        ),
      );
    }
    final members = report.memberCount == 0 ? 4 : report.memberCount;
    final level = (n / members * 4).round().clamp(0, 4);
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaruColors.heatmap[level],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${d.date.day}',
        style: haruText(
          11,
          weight: FontWeight.w600,
          color: level >= 3 ? Colors.white : HaruColors.inkSecondary,
        ),
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const dur = Duration(milliseconds: 380);
    final total = delay + dur;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: HaruMotion.pop),
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: c),
      ),
      child: child,
    );
  }
}
