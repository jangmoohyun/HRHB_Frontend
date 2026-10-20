import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/media_save_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../answers/family_answers_page.dart';
import '../answers/question_ref.dart';
import '../shell/home_shell.dart';

/// 기록 — 날짜별 · 사진 · 리포트.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _MonthData {
  _MonthData({
    required this.questions,
    required this.status,
    required this.calendar,
  });

  final List<TodayDailyQuestionResult> questions;
  final Map<DateTime, Set<int>> status;
  final Map<DateTime, DiaryCalendarDayResult> calendar;
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _api = ApiClient();
  final _today = dateOnly(DateTime.now());
  int _seg = 0;
  late int _y = _today.year;
  late int _m = _today.month;

  _MonthData? _data;
  bool _error = false;
  HomeShellState? _shell;

  final _photos = <PhotoItem>[];
  int _photoTotal = 0;
  int _photoPage = 0;
  bool _photoMore = true;
  bool _photoBusy = false;
  bool _photoError = false;
  bool _photosStarted = false;

  bool get _isThisMonth => _y == _today.year && _m == _today.month;

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
      _shell?.refreshTick.removeListener(_onChanged);
      _shell = shell;
      _shell?.refreshTick.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _shell?.refreshTick.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _load();
    if (_photosStarted) _resetPhotos();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    final y = _y, m = _m;
    try {
      await FamilyContext.instance.ensure();
      final questionsF = AuthedCall.run(
        (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m),
      );
      final statusF = PendingApi.instance
          .fetchAnswerStatus(year: y, month: m)
          .catchError((Object _) => <AnswerStatusDay>[]);
      final calendarF = AuthedCall.run(
        (t) => _api.fetchDiaryCalendar(accessToken: t, year: y, month: m),
      ).then<DiaryCalendarResult?>((v) => v).catchError((Object _) => null);
      final questions = await questionsF;
      final status = {for (final s in await statusF) dateOnly(s.date): s.answeredUserIds};
      final calendar = {
        for (final d in (await calendarF)?.days ?? const <DiaryCalendarDayResult>[]) dateOnly(d.date): d,
      };
      if (!mounted || y != _y || m != _m) return;
      setState(() => _data = _MonthData(questions: questions.items, status: status, calendar: calendar));
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_y, _m + delta);
    if (next.isAfter(DateTime(_today.year, _today.month))) return;
    setState(() {
      _y = next.year;
      _m = next.month;
      _data = null;
    });
    await _load();
  }

  Future<void> _resetPhotos() async {
    _photos.clear();
    _photoPage = 0;
    _photoMore = true;
    _photoError = false;
    await _morePhotos();
  }

  Future<void> _morePhotos() async {
    if (_photoBusy || !_photoMore) return;
    _photosStarted = true;
    setState(() => _photoBusy = true);
    try {
      final page = await AuthedCall.run(
        (t) => _api.fetchGalleryAnswerPhotos(accessToken: t, page: _photoPage, size: 21),
      );
      final fam = FamilyContext.instance.value;
      for (final p in page.items) {
        final look = fam?.members
            .where((mm) =>
                mm.role == MemberLook.roleFor(p.role) &&
                (p.birthOrder == null || mm.label == p.authorLabel))
            .firstOrNull;
        _photos.add(PhotoItem(
          url: p.imageUrl,
          date: '${p.date.month}/${p.date.day}',
          who: look?.short ?? MemberLook.roleFor(p.role),
          caption: p.questionContent,
          tint: HaruColors.tints[_photos.length % HaruColors.tints.length],
        ));
      }
      _photoTotal = page.totalCount;
      _photoMore = page.hasMore;
      _photoPage++;
    } catch (_) {
      _photoError = true;
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _openDay(DateTime date, TodayDailyQuestionResult q) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: QuestionRef.fromResult(q))),
    );
  }

  Future<void> _openPhoto(int i) => PhotoViewerPage.open(
        context,
        items: _photos,
        index: i,
        onSave: (item) async {
          try {
            await const MediaSaveService().saveImageUrls([item.url]);
            if (mounted) HaruToast.show(context, '사진을 저장했어요.');
          } catch (e) {
            if (mounted) HaruToast.show(context, e is StateError ? e.message : '사진을 저장하지 못했어요.');
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (_seg == 1 && n.metrics.extentAfter < 400) _morePhotos();
        return false;
      },
      child: RefreshIndicator(
        color: HaruColors.forest,
        backgroundColor: HaruColors.ivory,
        onRefresh: () async {
          await _load();
          if (_seg == 1) await _resetPhotos();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, kNavClearance),
          children: [
            Entrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabHeader(title: '우리 가족 기록'),
                  const SizedBox(height: 14),
                  _Segment(
                    labels: const ['날짜별', '사진', '리포트'],
                    index: _seg,
                    onTap: (i) {
                      setState(() => _seg = i);
                      if (i == 1 && !_photosStarted) _resetPhotos();
                    },
                  ),
                  ...switch (_seg) {
                    0 => _list(),
                    1 => _photoGrid(),
                    _ => _report(),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthNav() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Pressable(
            onTap: () => _shiftMonth(-1),
            semanticLabel: '이전 달',
            child: const Icon(Symbols.chevron_left_rounded, size: 24, color: HaruColors.forest),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Text('$_y년 $_m월', textAlign: TextAlign.center, style: hr(17, color: HaruColors.forest)),
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
      ),
    );
  }

  Widget _message(String text, {VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Pressable(
            onTap: onTap,
            child: Text(text, textAlign: TextAlign.center, style: hr(15, color: HaruColors.inkMuted)),
          ),
        ),
      );

  // ── 날짜별 ─────────────────────────────────────────────────────────────

  List<Widget> _list() {
    final members = FamilyContext.instance.value?.members ?? const <MemberLook>[];
    final data = _data;
    final rows = data == null
        ? <TodayDailyQuestionResult>[]
        : (data.questions.where((q) => q.isReady && !dateOnly(q.date).isAfter(_today)).toList()
          ..sort((a, b) => b.date.compareTo(a.date)));
    return [
      _monthNav(),
      if (_error)
        _message('기록을 불러오지 못했어요.\n눌러서 다시 시도해 주세요.', onTap: _load)
      else if (data != null && rows.isEmpty)
        _message('이 달에 도착한 질문이 없어요')
      else
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Entrance(
              key: ValueKey('r$_y$_m$i'),
              kind: EntranceKind.riseIn,
              duration: const Duration(milliseconds: 450),
              delay: stagger(i, 45),
              child: _DateRow(
                question: rows[i],
                members: members,
                answered: data!.status[dateOnly(rows[i].date)] ?? const {},
                day: data.calendar[dateOnly(rows[i].date)],
                onTap: () => _openDay(dateOnly(rows[i].date), rows[i]),
              ),
            ),
          ),
    ];
  }

  // ── 사진 ───────────────────────────────────────────────────────────────

  List<Widget> _photoGrid() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('답변 사진 모아보기', style: hr(17, color: HaruColors.forest))),
            Text('가족이 질문에 남긴 사진 $_photoTotal장', style: hr(14.5, color: HaruColors.inkMuted)),
          ],
        ),
      ),
      if (_photoError && _photos.isEmpty)
        _message('사진을 불러오지 못했어요.\n눌러서 다시 시도해 주세요.', onTap: _resetPhotos)
      else if (!_photoBusy && _photos.isEmpty)
        _message('아직 질문에 남긴 사진이 없어요')
      else
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 12) / 3;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Entrance(
                    key: ValueKey(_photos[i].url + i.toString()),
                    kind: EntranceKind.pop,
                    delay: stagger(i % 21, 30),
                    // App-only tap (photo viewer); pressed like the album
                    // covers (scale .95, transform 200ms ease).
                    child: Pressable(
                      onTap: () => _openPhoto(i),
                      child: SizedBox(
                        width: w,
                        height: w,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              HaruNetImage(url: _photos[i].url, tint: _photos[i].tint, iconSize: 26),
                              Positioned(
                                left: 6,
                                bottom: 5,
                                child: Text(
                                  '${_photos[i].who} · ${_photos[i].date}',
                                  style: hrHand(14.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    ];
  }

  // ── 리포트 ─────────────────────────────────────────────────────────────

  List<Widget> _report() {
    final data = _data;
    if (_error) return [_monthNav(), _message('리포트를 불러오지 못했어요.\n눌러서 다시 시도해 주세요.', onTap: _load)];
    if (data == null) return [_monthNav()];
    final memberCount = FamilyContext.instance.value?.members.length ?? 4;
    final lastDay = DateTime(_y, _m + 1, 0).day;
    var replies = 0, allTogether = 0;
    for (final e in data.status.entries) {
      if (e.key.year != _y || e.key.month != _m || e.key.isAfter(_today)) continue;
      replies += e.value.length;
      if (memberCount > 0 && e.value.length >= memberCount) allTogether++;
    }
    DiaryCalendarDayResult? warmest;
    for (final d in data.calendar.values) {
      if (d.date.isAfter(_today)) continue;
      if (warmest == null || d.temperature > warmest.temperature) warmest = d;
    }
    final lead = DateTime(_y, _m, 1).weekday - 1; // Monday-first grid
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var day = 1; day <= lastDay; day++)
        _HeatCell(
          day: day,
          future: DateTime(_y, _m, day).isAfter(_today),
          count: data.status[DateTime(_y, _m, day)]?.length ?? 0,
          memberCount: memberCount,
          index: lead + day - 1,
        ),
    ];
    final warmW = warmest == null ? null : HaruWeather.fromWire(warmest.familyWeather);
    return [
      _monthNav(),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _StatCard(label: '이번 달 답장', value: '$replies', unit: '개')),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: '모두 함께 답한 날', value: '$allTogether', unit: '일')),
        ],
      ),
      const SizedBox(height: 10),
      HrCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SproutHeading('$_m월 답장 달력'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('0명', style: hr(13.5, color: HaruColors.inkMuted)),
                for (final c in HaruColors.heat) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
                const SizedBox(width: 4),
                Text('$memberCount명', style: hr(13.5, color: HaruColors.inkMuted)),
              ],
            ),
          ],
        ),
      ),
      if (warmest != null) ...[
        const SizedBox(height: 10),
        HrCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: HaruColors.yellow, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Symbols.device_thermostat_rounded, size: 28, color: HaruColors.warmIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가장 따뜻했던 날', style: hr(14.5, color: HaruColors.inkMuted)),
                    Text(
                      '${warmest.date.month}/${warmest.date.day} (${dowOf(warmest.date)})'
                      '${warmW == null ? '' : ' · ${warmW.label}'}',
                      style: hr(17, color: HaruColors.forest),
                    ),
                  ],
                ),
              ),
              Text('${warmest.temperature.toStringAsFixed(1)}°C', style: hrHand(24, color: HaruColors.tempText)),
            ],
          ),
        ),
      ],
    ];
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HaruColors.ivory,
        border: Border.all(color: HaruColors.hairline),
        borderRadius: BorderRadius.circular(HaruRadius.full),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Pressable(
                onTap: () => onTap(i),
                scale: .96,
                semanticLabel: labels[i],
                // Only `background` transitions; the pressed scale snaps.
                duration: Duration.zero,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                  height: 36,
                  decoration: BoxDecoration(
                    color: index == i ? HaruColors.forest : Colors.transparent,
                    borderRadius: BorderRadius.circular(HaruRadius.full),
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i], style: hr(16, color: index == i ? Colors.white : HaruColors.inkMuted)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.question,
    required this.members,
    required this.answered,
    required this.day,
    required this.onTap,
  });

  final TodayDailyQuestionResult question;
  final List<MemberLook> members;
  final Set<int> answered;
  final DiaryCalendarDayResult? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = dateOnly(question.date);
    final w = HaruWeather.fromWire(day?.familyWeather);
    final t = day?.temperature;
    final count = members.where((m) => answered.contains(m.userId)).length;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${d.month}월 ${d.day}일 기록',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          border: Border.all(color: HaruColors.hairline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d.month}/${d.day}', style: hrHand(19, height: 1.1)),
                  Text(dowOf(d), style: hr(13.5, color: HaruColors.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // `border-left: 1.2px dashed` sits on the text block, so the dash
            // spans that block's height (not the whole row).
            Expanded(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _VDash(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            question.content ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: hrQuestion(15, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final m in members) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: answered.contains(m.userId) ? HaruColors.forest : HaruColors.hairline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              const SizedBox(width: 4),
                              Text('$count/${members.length} 답장', style: hr(13.5, color: HaruColors.inkMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 42,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(w?.icon ?? Symbols.remove_rounded, size: 22, color: w?.color ?? HaruColors.inkFaint),
                  const SizedBox(height: 2),
                  Text(
                    t == null ? '–' : '${t.toStringAsFixed(1)}°',
                    style: hrHand(14.5, color: t == null ? HaruColors.inkFaint : tempColor(t)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `border-left: 1.2px dashed #C5D9B8`.
class _VDash extends StatelessWidget {
  const _VDash();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.2,
      child: CustomPaint(painter: _VDashPainter()),
    );
  }
}

class _VDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = HaruColors.fieldBorder;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 4), p);
    }
  }

  @override
  bool shouldRepaint(_VDashPainter old) => false;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return HrCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: hr(14.5, color: HaruColors.inkMuted)),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value),
              TextSpan(text: unit, style: hrHand(16)),
            ]),
            style: hrHand(34, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.future,
    required this.count,
    required this.memberCount,
    required this.index,
  });

  final int day;
  final bool future;
  final int count;
  final int memberCount;
  final int index;

  @override
  Widget build(BuildContext context) {
    // 0 … 4 levels, scaled for families that aren't four people.
    final level = memberCount <= 0 ? 0 : (count / memberCount * 4).round().clamp(0, 4);
    final cell = Container(
      decoration: BoxDecoration(
        color: future ? Colors.transparent : HaruColors.heat[level],
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: hrHand(14.5, color: !future && level >= 3 ? Colors.white : HaruColors.inkMuted),
      ),
    );
    return Entrance(
      kind: EntranceKind.pop,
      duration: const Duration(milliseconds: 400),
      delay: stagger(index, 14),
      child: future ? DashedBox(color: HaruColors.hairline, radius: 8, child: cell) : cell,
    );
  }
}
