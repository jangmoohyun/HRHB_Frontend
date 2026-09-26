import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';

import '../home/home_sheets.dart';
import '../shell/home_shell.dart';
import 'day_answers.dart';
import 'question_ref.dart';
import 'write_answer_page.dart';

/// 15 가족 답변 보기.
class FamilyAnswersPage extends StatefulWidget {
  const FamilyAnswersPage({super.key, required this.question});

  final QuestionRef question;

  @override
  State<FamilyAnswersPage> createState() => _FamilyAnswersPageState();
}

class _FamilyAnswersPageState extends State<FamilyAnswersPage> {
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
    final firstAnswer = mine == null;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteAnswerPage(
          question: widget.question,
          initialContent: mine?.raw.content,
          initialImageUrl: mine?.raw.imageUrl,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
    if (!mounted) return;
    await afterAnswerSaved(
      context,
      firstAnswer: firstAnswer,
      isToday: widget.question.isToday,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final fam = FamilyContext.instance.value;
    final data = _data;
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HaruSubHeader(title: '답변 보기'),
            Expanded(
              child: _error
                  ? HaruErrorState(onRetry: _load)
                  : RefreshIndicator(
                      color: HaruColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, kTabBarClearance),
                        children: [
                          _QuestionCard(question: q, familyName: fam?.name ?? '우리 가족'),
                          const SizedBox(height: 12),
                          if (data == null)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(color: HaruColors.primary),
                              ),
                            )
                          else if (data.answers.isEmpty)
                            const HaruEmptyState(
                              icon: LucideIcons.mailOpen,
                              title: '아직 작성된 답변이 없어요',
                              description: '먼저 답변을 남겨볼까요?',
                              tileRadius: 26,
                              iconColor: HaruColors.dsInkMuted,
                            )
                          else ...[
                            for (final a in data.answers) ...[
                              _AnswerTile(answer: a),
                              const SizedBox(height: 12),
                            ],
                            if (data.pending.isNotEmpty) _PendingRow(pending: data.pending),
                          ],
                          const SizedBox(height: 20),
                          if (q.isReady)
                            HaruButton(
                              label: data?.mine == null ? '답변하기' : '내 답변 수정하기',
                              size: HaruButtonSize.lg,
                              fullWidth: true,
                              onPressed: data == null ? null : _openWrite,
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
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.familyName});

  final QuestionRef question;
  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaruColors.surface,
        borderRadius: BorderRadius.circular(HaruRadius.lg),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 8,
            color: question.isEmotional ? HaruColors.accentPink : HaruColors.accentGreen,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'To. $familyName',
                        style: haruText(12, weight: FontWeight.w600, color: HaruColors.dsInkMuted),
                      ),
                    ),
                    Text(
                      fullDate(question.date),
                      style: haruText(12, color: HaruColors.dsInkFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question.content,
                  style: haruText(
                    20,
                    weight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: -0.2,
                    color: HaruColors.dsInk,
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

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.answer});

  final AnswerView answer;

  @override
  Widget build(BuildContext context) {
    final m = answer.member;
    final image = answer.raw.imageUrl;
    return HaruOutlineCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShortAvatar(text: m.short, tint: m.tint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.label,
                            style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk),
                          ),
                        ),
                        if (m.isMe) ...[
                          const SizedBox(width: 6),
                          const HaruBadge('나'),
                        ],
                      ],
                    ),
                    if (answer.timeLabel.isNotEmpty)
                      Text(answer.timeLabel, style: haruText(12, color: HaruColors.dsInkFaint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            answer.raw.content,
            style: haruText(16, height: 1.6, color: HaruColors.dsInk),
          ),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(HaruRadius.md),
              child: SizedBox(
                height: 180,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: m.tint,
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.image, size: 28, color: HaruColors.dsInkSecondary),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.pending});

  final List<MemberLook> pending;

  @override
  Widget build(BuildContext context) {
    final names = pending.map((m) => m.label).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          HaruAvatarStack(
            overlap: 6,
            itemSize: 30, // 26 + 2px ring each side
            children: [
              for (final m in pending)
                ShortAvatar(
                  text: m.short,
                  tint: m.tint,
                  size: 26,
                  fontSize: 9,
                  ringColor: HaruColors.canvasSoft,
                  opacity: 0.6,
                ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$names의 답변을 기다리고 있어요',
              style: haruText(14, color: HaruColors.dsInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
