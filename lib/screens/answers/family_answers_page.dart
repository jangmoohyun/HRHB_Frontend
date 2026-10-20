import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
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

import '../home/home_sheets.dart';
import '../shell/home_shell.dart';
import 'day_answers.dart';
import 'question_ref.dart';
import 'write_answer_page.dart';

/// 가족 답장 — the question, who replied, the replies and who is still
/// writing (with 콕 찌르기).
class FamilyAnswersPage extends StatefulWidget {
  const FamilyAnswersPage({super.key, required this.question});

  final QuestionRef question;

  @override
  State<FamilyAnswersPage> createState() => _FamilyAnswersPageState();
}

class _FamilyAnswersPageState extends State<FamilyAnswersPage> {
  /// Pokes sent this session: "$dailyQuestionId-$userId".
  static final _poked = <String>{};

  DayAnswers? _data;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.question.dailyQuestionId;
    if (id == null) {
      setState(() => _data = DayAnswers.empty);
      return;
    }
    setState(() => _error = false);
    try {
      final d = await DayAnswers.load(id);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _openWrite() async {
    final mine = _data?.mine;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteAnswerPage(
          question: widget.question,
          initialContent: mine?.raw.content,
          initialImageUrl: mine?.raw.imageUrl,
          replaceWithAnswers: false,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
    if (!mounted) return;
    await afterAnswerSaved(context, firstAnswer: mine == null, isToday: widget.question.isToday);
  }

  Future<void> _poke(MemberLook m) async {
    final id = widget.question.dailyQuestionId;
    if (id == null) return;
    try {
      await PendingApi.instance.pokeMember(dailyQuestionId: id, userId: m.userId);
      if (!mounted) return;
      setState(() => _poked.add('$id-${m.userId}'));
      HaruToast.show(context, '${m.label}에게 콕! 알림을 보냈어요.');
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message);
    } catch (_) {
      if (mounted) HaruToast.show(context, '알림을 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _openPhoto(AnswerView a) async {
    final url = a.raw.imageUrl;
    if (url == null || url.isEmpty) return;
    await PhotoViewerPage.open(
      context,
      items: [
        PhotoItem(
          url: url,
          who: a.member.label,
          date: '${widget.question.date.month}/${widget.question.date.day}',
          caption: widget.question.content,
          tint: a.member.tint,
        ),
      ],
      index: 0,
      onSave: (item) async {
        try {
          await const MediaSaveService().saveImageUrls([item.url]);
          if (mounted) HaruToast.show(context, '사진을 저장했어요.');
        } catch (e) {
          if (mounted) HaruToast.show(context, e is StateError ? e.message : '사진을 저장하지 못했어요.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final fam = FamilyContext.instance.value;
    final members = fam?.members ?? _data?.members ?? const <MemberLook>[];
    final data = _data;
    final answeredIds = data?.answeredIds ?? const <int>{};
    final byUser = {for (final a in data?.answers ?? const <AnswerView>[]) a.member.userId: a};
    // Prototype order: family order for both lists.
    final done = [for (final m in members) if (byUser[m.userId] != null) byUser[m.userId]!];
    final waiting = [for (final m in members) if (!answeredIds.contains(m.userId)) m];
    final dq = q.dailyQuestionId;

    return EdgeSwipeBack(
      child: RefreshIndicator(
        color: HaruColors.forest,
        backgroundColor: HaruColors.ivory,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, kNavClearance),
          children: [
            const SubHeader(title: '가족 답장'),
            Entrance(
              kind: EntranceKind.pop,
              duration: const Duration(milliseconds: 480),
              child: _QuestionCard(
                question: q,
                members: members,
                answered: answeredIds,
                loaded: data != null,
              ),
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Pressable(
                    onTap: _load,
                    child: Text('답장을 불러오지 못했어요. 눌러서 다시 시도해 주세요.',
                        style: hr(15, color: HaruColors.inkMuted)),
                  ),
                ),
              )
            else if (data != null) ...[
              if (done.isNotEmpty)
                _ListTitle('도착한 답장 ${done.length}', color: HaruColors.forest),
              for (var i = 0; i < done.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == done.length - 1 ? 0 : 12),
                  child: Entrance(
                    kind: EntranceKind.riseIn,
                    delay: stagger(i, 80, 120),
                    child: _AnswerCard(
                      answer: done[i],
                      onEdit: done[i].member.isMe && q.isToday ? _openWrite : null,
                      onPhoto: () => _openPhoto(done[i]),
                    ),
                  ),
                ),
              if (waiting.isNotEmpty)
                _ListTitle('기다리는 중 ${waiting.length}', color: HaruColors.inkMuted),
              for (var i = 0; i < waiting.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == waiting.length - 1 ? 0 : 10),
                  child: Entrance(
                    kind: EntranceKind.riseIn,
                    delay: stagger(i, 80, 240),
                    child: _WaitingRow(
                      member: waiting[i],
                      canPoke: !waiting[i].isMe && dq != null && !_poked.contains('$dq-${waiting[i].userId}'),
                      poked: dq != null && _poked.contains('$dq-${waiting[i].userId}'),
                      meWaiting: waiting[i].isMe && q.isToday,
                      onPoke: () => _poke(waiting[i]),
                      onWrite: _openWrite,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(text, style: hr(17, color: color)),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.members,
    required this.answered,
    required this.loaded,
  });

  final QuestionRef question;
  final List<MemberLook> members;
  final Set<int> answered;

  /// The bar's width transition only runs on changes, not on first paint.
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final d = question.date;
    final doneN = members.where((m) => answered.contains(m.userId)).length;
    final waitN = members.length - doneN;
    final pct = members.isEmpty ? 0.0 : doneN / members.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: HaruColors.ivory,
        border: Border.all(color: HaruColors.fieldBorder, width: 1.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: HaruColors.mint,
                  borderRadius: BorderRadius.circular(HaruRadius.full),
                ),
                alignment: Alignment.center,
                child: Text('${d.month}/${d.day} (${dowOf(d)})', style: hr(14, color: HaruColors.forest)),
              ),
              const SizedBox(width: 6),
              Text('오늘의 질문', style: hr(14, color: HaruColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(question.content, style: hrQuestion(22, height: 1.45)),
          const SizedBox(height: 14),
          const DashLine(color: HaruColors.fieldBorder),
          const SizedBox(height: 14),
          Row(
            children: [
              // 36px dots, margin-left −6 each (no padding): 30px steps,
              // the first one 6px into the card padding.
              SizedBox(
                width: members.length * 30.0,
                height: 36,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < members.length; i++)
                      Positioned(
                        left: i * 30.0 - 6,
                        child: Entrance(
                          kind: EntranceKind.pop,
                          delay: stagger(i, 70, 200),
                          duration: const Duration(milliseconds: 400),
                          child: _Dot(member: members[i], done: answered.contains(members[i].userId)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('$doneN명 답장 · $waitN명 기다리는 중', style: hr(16)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                      child: Container(
                        height: 6,
                        color: HaruColors.mint,
                        alignment: Alignment.centerLeft,
                        // transition: width 600ms cubic-bezier(.2,0,0,1)
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(loaded),
                          tween: Tween(begin: pct, end: pct),
                          duration: const Duration(milliseconds: 600),
                          curve: HaruMotion.standard,
                          builder: (_, v, _) => FractionallySizedBox(
                            widthFactor: v,
                            child: Container(
                              decoration: BoxDecoration(
                                color: HaruColors.cta,
                                borderRadius: BorderRadius.circular(HaruRadius.full),
                              ),
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
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.member, required this.done});

  final MemberLook member;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 1 : .35,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: member.tint,
          shape: BoxShape.circle,
          border: Border.all(color: done ? HaruColors.cta : HaruColors.lineGrey, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(member.short, maxLines: 1, style: hr(13.5, color: HaruColors.forest)),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.onEdit, required this.onPhoto});

  final AnswerView answer;
  final VoidCallback? onEdit;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final m = answer.member;
    final photo = answer.raw.imageUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HaruColors.hairline),
        borderRadius: BorderRadius.circular(18),
        boxShadow: HaruShadows.answer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: m.tint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(m.short, maxLines: 1, style: hr(15, color: HaruColors.forest)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.displayName, style: hr(18, height: 1.2)),
                    if (answer.timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(answer.timeLabel, style: hr(14, color: HaruColors.inkMuted)),
                    ],
                  ],
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 12),
                Pressable(
                  onTap: onEdit,
                  child: Container(
                    // 28 + 1px border (content-box)
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: HaruColors.fieldBorder),
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                    ),
                    alignment: Alignment.center,
                    child: Text('고치기', style: hr(14.5, color: HaruColors.forest)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(answer.raw.content, style: hr(17, height: 1.6)),
          if (photo != null && photo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: onPhoto,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: HaruNetImage(url: photo, tint: m.tint, iconSize: 32),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({
    required this.member,
    required this.canPoke,
    required this.poked,
    required this.meWaiting,
    required this.onPoke,
    required this.onWrite,
  });

  final MemberLook member;
  final bool canPoke;
  final bool poked;
  final bool meWaiting;
  final VoidCallback onPoke;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, Color bg, Color fg, VoidCallback onTap) => Pressable(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HaruRadius.full)),
            alignment: Alignment.center,
            child: Text(label, style: hr(14, color: fg)),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HaruColors.waiting,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: member.tint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(member.short, maxLines: 1, style: hr(15, color: HaruColors.forest)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: hr(17)),
                const SizedBox(height: 1),
                Text('아직 답장하지 않았어요', style: hr(14, color: HaruColors.inkMuted)),
              ],
            ),
          ),
          // flex gap 12 before the trailing pill
          if (canPoke || poked || meWaiting) const SizedBox(width: 12),
          if (canPoke) pill('콕 찌르기', HaruColors.mint, HaruColors.forest, onPoke),
          if (poked)
            Entrance(
              kind: EntranceKind.pop,
              duration: const Duration(milliseconds: 400),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Icon(Symbols.check_rounded, size: 16, color: HaruColors.cta),
                    const SizedBox(width: 3),
                    Text('찔렀어요', style: hr(14, color: HaruColors.cta)),
                  ],
                ),
              ),
            ),
          if (meWaiting) pill('답장 쓰기', HaruColors.cta, Colors.white, onWrite),
        ],
      ),
    );
  }
}
