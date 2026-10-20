import 'package:flutter/material.dart';

import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 연속 답변 시트
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showStreakSheet(BuildContext context, {StreakSummary? streak}) async {
  StreakSummary data;
  try {
    data = streak ?? await PendingApi.instance.fetchStreak();
  } catch (_) {
    if (context.mounted) HaruToast.show(context, '연속 답변을 불러오지 못했어요.');
    return;
  }
  if (!context.mounted) return;
  await showHaruSheet<void>(context, builder: (ctx) => _StreakSheet(streak: data));
}

class _StreakSheet extends StatelessWidget {
  const _StreakSheet({required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final n = streak.current;
    final best = streak.best;
    final lead = streak.answeredToday ? '오늘도 답해서 $n일째가 됐어요!' : '오늘 답하면 ${n + 1}일째가 돼요!';
    final msg = best == null ? lead : '$lead · 최고 기록 $best일';
    return Column(
      children: [
        Text('연속 답변', style: hr(21, color: HaruColors.forest)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Entrance(
              kind: EntranceKind.pop,
              delay: const Duration(milliseconds: 120),
              duration: const Duration(milliseconds: 550),
              child: Text('$n', style: hrHand(64, weight: FontWeight.w800, height: 1)),
            ),
            const SizedBox(width: 4),
            Text('일째', style: hr(20, color: HaruColors.forest)),
          ],
        ),
        const SizedBox(height: 4),
        Text(msg, textAlign: TextAlign.center, style: hr(15, color: HaruColors.inkMuted)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Column(
                  children: [
                    Entrance(
                      kind: EntranceKind.stamp,
                      delay: stagger(i, 60, 300),
                      duration: const Duration(milliseconds: 420),
                      curve: HaruMotion.out,
                      targetOpacity: _answered(i) ? 1 : .28,
                      child: Image.asset(HaruImages.greenHeart, width: 30, height: 30),
                    ),
                    const SizedBox(height: 4),
                    Text(weekdayShort[i], style: hr(14.5, color: HaruColors.inkMuted)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: '확인', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  bool _answered(int i) => i < streak.week.length && streak.week[i].answered;
}

/// After saving an answer: the first answer of today celebrates with the
/// streak sheet (prototype: 1.4s after landing on 가족 답장), else nothing more.
Future<void> afterAnswerSaved(
  BuildContext context, {
  required bool firstAnswer,
  required bool isToday,
}) async {
  HaruToast.show(context, firstAnswer ? '답장을 보냈어요. 가족 온도가 0.3°C 올라가요!' : '답장을 고쳤어요.');
  if (!(firstAnswer && isToday)) return;
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  if (!context.mounted) return;
  await showStreakSheet(context);
}

// ─────────────────────────────────────────────────────────────────────────────
// 연도 · 월 선택
// ─────────────────────────────────────────────────────────────────────────────

Future<(int, int)?> showYearMonthSheet(
  BuildContext context, {
  required int year,
  required int month,
}) {
  final now = DateTime.now();
  return showDsSheet<(int, int)>(
    context,
    title: '연도 · 월 선택',
    builder: (ctx) => MonthPicker(
      year: year,
      month: month,
      maxYear: now.year,
      maxMonth: now.month,
      onConfirm: (y, m) => Navigator.of(ctx).pop((y, m)),
    ),
  );
}
