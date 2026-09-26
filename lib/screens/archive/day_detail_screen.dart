import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';

import '../answers/day_answers.dart';
import '../answers/question_ref.dart';
import '../answers/write_answer_page.dart';
import '../diary/diary_shared.dart';
import '../home/home_sheets.dart';
import '../shell/home_shell.dart';

/// 기록 · 하루 상세 — the day's question, answers and diary.
class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  final _api = ApiClient();

  QuestionRef? _question;
  DayAnswers? _answers;
  DiaryDayView? _diary;
  double? _delta;
  bool _loading = true;
  bool _error = false;

  DateTime get _date => dateOnly(widget.date);
  bool get _isToday => sameDay(_date, DateTime.now());

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
      final month = await AuthedCall.run(
        (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: _date.year, month: _date.month),
      );
      final hit = month.items.where((i) => sameDay(i.date, _date)).firstOrNull;
      QuestionRef q = hit == null ? QuestionRef.waiting(_date) : QuestionRef.fromResult(hit);
      if (_isToday && !q.isReady) {
        q = QuestionRef.fromResult(await AuthedCall.run(_api.fetchTodayDailyQuestion));
      }
      final answersF = q.dailyQuestionId == null
          ? Future.value(DayAnswers.empty)
          : DayAnswers.load(q.dailyQuestionId!);
      final diaryF = DiaryDayView.load(_date).then<DiaryDayView?>((v) => v).catchError((_) => null);
      final tempF = AuthedCall.run(_api.fetchFamilyTemperature)
          .then<FamilyTemperatureResult?>((v) => v)
          .catchError((_) => null);
      final answers = await answersF;
      final diary = await diaryF;
      final temp = await tempF;
      if (!mounted) return;
      setState(() {
        _question = q;
        _answers = answers;
        _diary = diary;
        _delta = temp?.recentChanges
            .where((c) => sameDay(c.date, _date))
            .firstOrNull
            ?.delta;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _openWrite() async {
    final q = _question;
    if (q == null || !q.isReady) return;
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
    await _load();
    if (!mounted) return;
    await afterAnswerSaved(context, firstAnswer: mine == null, isToday: q.isToday);
  }

  Future<void> _openCompose() async {
    final mine = _diary?.myEntry;
    final saved = await showDiaryComposeSheet(
      context,
      initialWeather: HaruWeather.fromWire(mine?.weather),
      initialText: mine?.content ?? '',
    );
    if (saved && mounted) {
      HomeShellScope.maybeOf(context)?.notifyDataChanged();
      _load();
    }
  }

  String _fmtDelta(double v) =>
      '${v > 0 ? '+' : v < 0 ? '−' : '±'}${v.abs().toStringAsFixed(1)}°';

  Color _deltaColor(double v) => v > 0
      ? HaruColors.tempRiseText
      : v < 0
          ? HaruColors.tempDropText
          : HaruColors.inkQuiet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HaruSubHeader(
              title: '${_date.month}월 ${_date.day}일 ${dowOf(_date)}요일',
              ver2: true,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: HaruColors.primary))
                  : _error
                      ? HaruErrorState(onRetry: _load)
                      : RefreshIndicator(
                          color: HaruColors.primary,
                          onRefresh: _load,
                          child: _body(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required List<Widget> children, EdgeInsets? padding}) => Container(
        height: 32,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HaruRadius.full),
          boxShadow: HaruShadows.s1,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _body() {
    final q = _question!;
    final answers = _answers ?? DayAnswers.empty;
    final diary = _diary;
    final composite = diary?.composite;
    final temp = diary?.temperature;
    final chipStyle = haruText(13, weight: FontWeight.w600);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, kTabBarClearance),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(children: [
              const Icon(LucideIcons.thermometer, size: 14, color: HaruColors.tempRiseText),
              const SizedBox(width: 6),
              Text('가족 온도 ${temp == null ? '–' : '${temp.toStringAsFixed(1)}°C'}', style: chipStyle),
              if (_delta != null) ...[
                const SizedBox(width: 4),
                Text(
                  _fmtDelta(_delta!),
                  style: haruText(13, weight: FontWeight.w700, color: _deltaColor(_delta!)),
                ),
              ],
            ]),
            if (composite != null)
              _chip(
                padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
                children: [
                  WeatherTile(weather: composite, size: 22, radius: 11, iconSize: 13),
                  const SizedBox(width: 6),
                  Text(composite.label, style: chipStyle),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HaruColors.house,
            borderRadius: BorderRadius.circular(HaruRadius.hero),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (q.sequenceNumber != null) '#${q.sequenceNumber}',
                  if ((q.category ?? '').isNotEmpty) q.category!,
                ].join(' · '),
                style: haruText(13, color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 8),
              Text(q.isReady ? q.content : q.waitingMessage!, style: haruQuestion(21)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (q.isReady && answers.answers.isEmpty)
          const CeramicNote('이 날은 아직 아무도 답하지 않았어요.'),
        for (final a in answers.answers) ...[
          _AnswerCard(answer: a),
          const SizedBox(height: 12),
        ],
        if (answers.answers.isNotEmpty && answers.pending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${answers.pending.map((m) => m.label).join(', ')}의 답변을 기다리고 있어요',
              style: haruText(13, color: HaruColors.inkSecondary),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (q.isReady) ...[
          const SizedBox(height: 0),
          HaruButton(
            label: answers.mine == null ? '답변하기' : '내 답변 수정하기',
            size: HaruButtonSize.lg,
            fullWidth: true,
            onPressed: _openWrite,
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
          child: Text('그날의 일지', style: HaruType.sectionTitle),
        ),
        if (diary == null)
          const CeramicNote('이 날 남긴 일지가 없어요')
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(HaruRadius.xl),
              boxShadow: HaruShadows.s1,
            ),
            child: MembersWeatherGrid(
              members: diary.members,
              isToday: _isToday,
              onAddMine: _openCompose,
            ),
          ),
          const SizedBox(height: 12),
          for (final e in diary.entries) ...[
            DiaryEntryCard(member: e.member, entry: e.entry),
            const SizedBox(height: 12),
          ],
          if (diary.entries.isEmpty) ...[
            const CeramicNote('이 날 남긴 일지가 없어요'),
            const SizedBox(height: 12),
          ],
          if (_isToday)
            HaruButton(
              label: diary.myEntry == null ? '오늘의 일지 작성하기' : '오늘의 일지 수정하기',
              icon: LucideIcons.pencil,
              variant: HaruButtonVariant.secondary,
              size: HaruButtonSize.lg,
              fullWidth: true,
              onPressed: _openCompose,
            ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AnswerView answer;

  @override
  Widget build(BuildContext context) {
    final m = answer.member;
    final image = answer.raw.imageUrl;
    return Container(
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
              HaruAvatar(initial: m.initial, tint: m.tint, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label, style: haruHand(20)),
                    if (answer.timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(answer.timeLabel, style: haruText(13, color: HaruColors.inkSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(answer.raw.content, style: haruText(16, height: 1.55)),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(HaruRadius.lg),
              child: SizedBox(height: 180, child: HaruNetImage(url: image, tint: m.tint)),
            ),
          ],
        ],
      ),
    );
  }
}
